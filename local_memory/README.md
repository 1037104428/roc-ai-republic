# Local Memory Stack

This folder stores a persistent local memory database for 阿爪.

## What it is
- `memory.db`: SQLite database on local disk
- `memdb.py`: add/search/recent CLI
- Embedding: deterministic local hashing vectors (no cloud dependency)

## Quick usage
```bash
python3 local_memory/memdb.py init
python3 local_memory/memdb.py add "用户偏好：低打扰自治" --category preference --importance 5 --source chat
python3 local_memory/memdb.py search "用户喜欢什么沟通方式" --top-k 5
python3 local_memory/memdb.py recent --limit 10
```

## Notes
- This is persistent across restarts.
- Designed to be robust/offline-first.
- Can be upgraded later to model-based embeddings (e.g. sentence-transformers + faiss).
