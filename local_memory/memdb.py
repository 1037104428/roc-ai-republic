#!/usr/bin/env python3
import argparse
import datetime as dt
import hashlib
import json
import math
import os
import re
import sqlite3
from typing import List, Tuple

DB_PATH_DEFAULT = os.path.join(os.path.dirname(__file__), "memory.db")
DIMS = 768

TOKEN_RE = re.compile(r"[\w\-\u4e00-\u9fff]+", re.UNICODE)


def now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).astimezone().isoformat(timespec="seconds")


def tokenize(text: str) -> List[str]:
    return [t.lower() for t in TOKEN_RE.findall(text)]


def embed(text: str, dims: int = DIMS) -> List[float]:
    # Lightweight local hashing embedding (no cloud/API dependency)
    vec = [0.0] * dims
    tokens = tokenize(text)
    if not tokens:
        return vec

    for tok in tokens:
        h = hashlib.blake2b(tok.encode("utf-8"), digest_size=16).digest()
        idx1 = int.from_bytes(h[0:4], "little") % dims
        idx2 = int.from_bytes(h[4:8], "little") % dims
        s1 = 1.0 if (h[8] & 1) else -1.0
        s2 = 1.0 if (h[9] & 1) else -1.0
        vec[idx1] += s1
        vec[idx2] += 0.5 * s2

    norm = math.sqrt(sum(v * v for v in vec))
    if norm > 0:
        vec = [v / norm for v in vec]
    return vec


def cosine(a: List[float], b: List[float]) -> float:
    if len(a) != len(b):
        return 0.0
    return sum(x * y for x, y in zip(a, b))


def connect(db_path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    return conn


def init_db(conn: sqlite3.Connection) -> None:
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS memories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            source TEXT NOT NULL DEFAULT 'manual',
            category TEXT NOT NULL DEFAULT 'general',
            importance INTEGER NOT NULL DEFAULT 3,
            text TEXT NOT NULL,
            embedding TEXT NOT NULL
        )
        """
    )
    conn.execute("CREATE INDEX IF NOT EXISTS idx_memories_created_at ON memories(created_at)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_memories_category ON memories(category)")
    conn.commit()


def add_memory(conn: sqlite3.Connection, text: str, source: str, category: str, importance: int) -> int:
    ts = now_iso()
    vec = embed(text)
    cur = conn.execute(
        """
        INSERT INTO memories (created_at, updated_at, source, category, importance, text, embedding)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (ts, ts, source, category, importance, text.strip(), json.dumps(vec, ensure_ascii=False)),
    )
    conn.commit()
    return cur.lastrowid


def search(conn: sqlite3.Connection, query: str, top_k: int, category: str = None) -> List[Tuple]:
    qv = embed(query)
    if category:
        rows = conn.execute(
            "SELECT id, created_at, source, category, importance, text, embedding FROM memories WHERE category = ?",
            (category,),
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT id, created_at, source, category, importance, text, embedding FROM memories"
        ).fetchall()

    scored = []
    for r in rows:
        ev = json.loads(r[6])
        score = cosine(qv, ev)
        # small boost for importance
        score += (int(r[4]) - 3) * 0.02
        scored.append((score, r))

    scored.sort(key=lambda x: x[0], reverse=True)
    return scored[:top_k]


def list_recent(conn: sqlite3.Connection, limit: int) -> List[Tuple]:
    return conn.execute(
        "SELECT id, created_at, source, category, importance, text FROM memories ORDER BY id DESC LIMIT ?",
        (limit,),
    ).fetchall()


def main():
    p = argparse.ArgumentParser(description="Local persistent memory store with vector retrieval")
    p.add_argument("--db", default=DB_PATH_DEFAULT, help="Path to sqlite db")

    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("init", help="Initialize database")

    addp = sub.add_parser("add", help="Add a memory")
    addp.add_argument("text", help="Memory text")
    addp.add_argument("--source", default="manual")
    addp.add_argument("--category", default="general")
    addp.add_argument("--importance", type=int, default=3, choices=[1, 2, 3, 4, 5])

    sp = sub.add_parser("search", help="Semantic search")
    sp.add_argument("query", help="Search query")
    sp.add_argument("--top-k", type=int, default=5)
    sp.add_argument("--category", default=None)

    lp = sub.add_parser("recent", help="Show recent memories")
    lp.add_argument("--limit", type=int, default=10)

    args = p.parse_args()

    os.makedirs(os.path.dirname(os.path.abspath(args.db)), exist_ok=True)
    conn = connect(args.db)

    if args.cmd == "init":
        init_db(conn)
        print(f"initialized: {args.db}")
        return

    init_db(conn)

    if args.cmd == "add":
        mid = add_memory(conn, args.text, args.source, args.category, args.importance)
        print(f"added memory id={mid}")

    elif args.cmd == "search":
        results = search(conn, args.query, args.top_k, args.category)
        for score, r in results:
            print(json.dumps({
                "id": r[0],
                "score": round(score, 4),
                "created_at": r[1],
                "source": r[2],
                "category": r[3],
                "importance": r[4],
                "text": r[5],
            }, ensure_ascii=False))

    elif args.cmd == "recent":
        rows = list_recent(conn, args.limit)
        for r in rows:
            print(json.dumps({
                "id": r[0],
                "created_at": r[1],
                "source": r[2],
                "category": r[3],
                "importance": r[4],
                "text": r[5],
            }, ensure_ascii=False))


if __name__ == "__main__":
    main()
