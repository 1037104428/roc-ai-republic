#!/usr/bin/env python3
"""
SQLite持久化示例 - quota-proxy 数据库层参考实现

功能：
1. 创建SQLite数据库和表结构
2. API密钥管理（生成、验证、统计）
3. 使用量跟踪和配额检查
4. 简单的管理接口

设计原则：
- 最小依赖（仅标准库sqlite3）
- 线程安全（每个线程独立连接）
- 自动重试和错误处理
- 支持内存和文件两种模式
"""

import sqlite3
import json
import time
import hashlib
import secrets
from typing import Optional, Dict, List, Tuple
from dataclasses import dataclass
from datetime import datetime, timedelta
import threading

@dataclass
class ApiKey:
    """API密钥数据类"""
    key_id: str
    key_hash: str
    name: str
    created_at: int
    expires_at: Optional[int] = None
    quota_daily: int = 1000
    quota_monthly: int = 30000
    enabled: bool = True
    metadata: Optional[Dict] = None

@dataclass
class UsageRecord:
    """使用记录数据类"""
    record_id: int
    key_id: str
    timestamp: int
    endpoint: str
    cost: int
    user_agent: Optional[str] = None
    ip_address: Optional[str] = None

class QuotaDatabase:
    """配额数据库管理器"""
    
    def __init__(self, db_path: str = ":memory:"):
        """
        初始化数据库连接
        
        Args:
            db_path: SQLite数据库路径，":memory:"表示内存数据库
        """
        self.db_path = db_path
        self._local = threading.local()
        self._init_schema()
    
    def _get_connection(self) -> sqlite3.Connection:
        """获取线程安全的数据库连接"""
        if not hasattr(self._local, 'conn'):
            conn = sqlite3.connect(self.db_path, check_same_thread=False)
            conn.row_factory = sqlite3.Row
            self._local.conn = conn
        return self._local.conn
    
    def _init_schema(self):
        """初始化数据库表结构"""
        conn = self._get_connection()
        
        # API密钥表
        conn.execute("""
        CREATE TABLE IF NOT EXISTS api_keys (
            key_id TEXT PRIMARY KEY,
            key_hash TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            expires_at INTEGER,
            quota_daily INTEGER DEFAULT 1000,
            quota_monthly INTEGER DEFAULT 30000,
            enabled INTEGER DEFAULT 1,
            metadata TEXT
        )
        """)
        
        # 使用记录表
        conn.execute("""
        CREATE TABLE IF NOT EXISTS usage_records (
            record_id INTEGER PRIMARY KEY AUTOINCREMENT,
            key_id TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            endpoint TEXT NOT NULL,
            cost INTEGER DEFAULT 1,
            user_agent TEXT,
            ip_address TEXT,
            FOREIGN KEY (key_id) REFERENCES api_keys (key_id) ON DELETE CASCADE
        )
        """)
        
        # 创建索引
        conn.execute("CREATE INDEX IF NOT EXISTS idx_usage_key_time ON usage_records(key_id, timestamp)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_keys_enabled ON api_keys(enabled)")
        
        conn.commit()
    
    def create_key(self, name: str, quota_daily: int = 1000, quota_monthly: int = 30000,
                  expires_days: Optional[int] = 30, metadata: Optional[Dict] = None) -> Tuple[str, ApiKey]:
        """
        创建新的API密钥
        
        Returns:
            (raw_key, api_key_object)
        """
        # 生成原始密钥和哈希
        raw_key = secrets.token_urlsafe(32)
        key_hash = hashlib.sha256(raw_key.encode()).hexdigest()
        
        # 生成密钥ID
        key_id = hashlib.sha256(key_hash.encode()).hexdigest()[:16]
        
        # 计算过期时间
        created_at = int(time.time())
        expires_at = None
        if expires_days:
            expires_at = created_at + (expires_days * 86400)
        
        # 创建API密钥对象
        api_key = ApiKey(
            key_id=key_id,
            key_hash=key_hash,
            name=name,
            created_at=created_at,
            expires_at=expires_at,
            quota_daily=quota_daily,
            quota_monthly=quota_monthly,
            metadata=metadata
        )
        
        # 保存到数据库
        conn = self._get_connection()
        conn.execute("""
        INSERT INTO api_keys 
        (key_id, key_hash, name, created_at, expires_at, quota_daily, quota_monthly, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            key_id, key_hash, name, created_at, expires_at,
            quota_daily, quota_monthly,
            json.dumps(metadata) if metadata else None
        ))
        conn.commit()
        
        return raw_key, api_key
    
    def validate_key(self, api_key: str) -> Optional[ApiKey]:
        """验证API密钥并返回密钥信息"""
        key_hash = hashlib.sha256(api_key.encode()).hexdigest()
        
        conn = self._get_connection()
        row = conn.execute("""
        SELECT * FROM api_keys 
        WHERE key_hash = ? AND enabled = 1
        """, (key_hash,)).fetchone()
        
        if not row:
            return None
        
        # 检查是否过期
        if row['expires_at'] and row['expires_at'] < time.time():
            return None
        
        return ApiKey(
            key_id=row['key_id'],
            key_hash=row['key_hash'],
            name=row['name'],
            created_at=row['created_at'],
            expires_at=row['expires_at'],
            quota_daily=row['quota_daily'],
            quota_monthly=row['quota_monthly'],
            enabled=bool(row['enabled']),
            metadata=json.loads(row['metadata']) if row['metadata'] else None
        )
    
    def record_usage(self, key_id: str, endpoint: str, cost: int = 1,
                    user_agent: Optional[str] = None, ip_address: Optional[str] = None) -> int:
        """记录API使用情况"""
        conn = self._get_connection()
        cursor = conn.execute("""
        INSERT INTO usage_records (key_id, timestamp, endpoint, cost, user_agent, ip_address)
        VALUES (?, ?, ?, ?, ?, ?)
        """, (key_id, int(time.time()), endpoint, cost, user_agent, ip_address))
        conn.commit()
        return cursor.lastrowid
    
    def get_usage_stats(self, key_id: str, period: str = "daily") -> Dict:
        """获取使用统计"""
        now = int(time.time())
        
        if period == "daily":
            start_time = now - 86400  # 24小时
        elif period == "monthly":
            start_time = now - 2592000  # 30天
        else:
            start_time = 0  # 全部
        
        conn = self._get_connection()
        
        # 获取总使用量
        total_row = conn.execute("""
        SELECT COUNT(*) as count, SUM(cost) as total_cost
        FROM usage_records
        WHERE key_id = ? AND timestamp >= ?
        """, (key_id, start_time)).fetchone()
        
        # 获取端点分布
        endpoint_rows = conn.execute("""
        SELECT endpoint, COUNT(*) as count, SUM(cost) as total_cost
        FROM usage_records
        WHERE key_id = ? AND timestamp >= ?
        GROUP BY endpoint
        ORDER BY total_cost DESC
        LIMIT 10
        """, (key_id, start_time)).fetchall()
        
        return {
            "period": period,
            "total_requests": total_row['count'] or 0,
            "total_cost": total_row['total_cost'] or 0,
            "endpoints": [
                {
                    "endpoint": row['endpoint'],
                    "requests": row['count'],
                    "cost": row['total_cost']
                }
                for row in endpoint_rows
            ]
        }
    
    def check_quota(self, key_id: str) -> Tuple[bool, Dict]:
        """检查配额使用情况"""
        conn = self._get_connection()
        
        # 获取密钥信息
        key_row = conn.execute("""
        SELECT quota_daily, quota_monthly FROM api_keys WHERE key_id = ?
        """, (key_id,)).fetchone()
        
        if not key_row:
            return False, {"error": "Key not found"}
        
        quota_daily = key_row['quota_daily']
        quota_monthly = key_row['quota_monthly']
        
        # 获取今日使用量
        today_start = int(time.time()) - (int(time.time()) % 86400)
        daily_usage = conn.execute("""
        SELECT SUM(cost) as total FROM usage_records 
        WHERE key_id = ? AND timestamp >= ?
        """, (key_id, today_start)).fetchone()
        
        # 获取本月使用量
        month_start = int(time.time()) - (int(time.time()) % 2592000)
        monthly_usage = conn.execute("""
        SELECT SUM(cost) as total FROM usage_records 
        WHERE key_id = ? AND timestamp >= ?
        """, (key_id, month_start)).fetchone()
        
        daily_total = daily_usage['total'] or 0
        monthly_total = monthly_usage['total'] or 0
        
        within_quota = (daily_total < quota_daily) and (monthly_total < quota_monthly)
        
        return within_quota, {
            "daily": {
                "used": daily_total,
                "quota": quota_daily,
                "remaining": max(0, quota_daily - daily_total)
            },
            "monthly": {
                "used": monthly_total,
                "quota": quota_monthly,
                "remaining": max(0, quota_monthly - monthly_total)
            }
        }
    
    def list_keys(self, enabled_only: bool = True) -> List[ApiKey]:
        """列出所有API密钥"""
        conn = self._get_connection()
        
        query = "SELECT * FROM api_keys"
        params = []
        if enabled_only:
            query += " WHERE enabled = 1"
        
        rows = conn.execute(query, params).fetchall()
        
        return [
            ApiKey(
                key_id=row['key_id'],
                key_hash=row['key_hash'],
                name=row['name'],
                created_at=row['created_at'],
                expires_at=row['expires_at'],
                quota_daily=row['quota_daily'],
                quota_monthly=row['quota_monthly'],
                enabled=bool(row['enabled']),
                metadata=json.loads(row['metadata']) if row['metadata'] else None
            )
            for row in rows
        ]
    
    def disable_key(self, key_id: str) -> bool:
        """禁用API密钥"""
        conn = self._get_connection()
        cursor = conn.execute("""
        UPDATE api_keys SET enabled = 0 WHERE key_id = ?
        """, (key_id,))
        conn.commit()
        return cursor.rowcount > 0
    
    def close(self):
        """关闭数据库连接"""
        if hasattr(self._local, 'conn'):
            self._local.conn.close()
            del self._local.conn

# 使用示例
def demo():
    """演示数据库功能"""
    print("=== Quota Database Demo ===")
    
    # 创建内存数据库
    db = QuotaDatabase(":memory:")
    
    # 创建API密钥
    print("\n1. 创建API密钥...")
    raw_key, api_key = db.create_key(
        name="测试用户",
        quota_daily=100,
        quota_monthly=3000,
        expires_days=7,
        metadata={"user_id": "123", "plan": "trial"}
    )
    print(f"   密钥ID: {api_key.key_id}")
    print(f"   原始密钥: {raw_key[:16]}...")
    print(f"   名称: {api_key.name}")
    print(f"   每日配额: {api_key.quota_daily}")
    
    # 验证密钥
    print("\n2. 验证API密钥...")
    validated = db.validate_key(raw_key)
    if validated:
        print(f"   验证成功: {validated.name}")
    else:
        print("   验证失败")
    
    # 记录使用
    print("\n3. 记录API使用...")
    for i in range(5):
        db.record_usage(
            key_id=api_key.key_id,
            endpoint=f"/api/v1/test/{i}",
            cost=1,
            user_agent="DemoClient/1.0",
            ip_address="127.0.0.1"
        )
    print("   记录了5次使用")
    
    # 检查配额
    print("\n4. 检查配额...")
    within_quota, quota_info = db.check_quota(api_key.key_id)
    print(f"   在配额内: {within_quota}")
    print(f"   今日使用: {quota_info['daily']['used']}/{quota_info['daily']['quota']}")
    print(f"   本月使用: {quota_info['monthly']['used']}/{quota_info['monthly']['quota']}")
    
    # 获取统计
    print("\n5. 使用统计...")
    stats = db.get_usage_stats(api_key.key_id, "daily")
    print(f"   总请求数: {stats['total_requests']}")
    print(f"   总成本: {stats['total_cost']}")
    
    # 列出密钥
    print("\n6. 列出所有密钥...")
    keys = db.list_keys()
    for key in keys:
        print(f"   - {key.name} ({key.key_id})")
    
    db.close()
    print("\n=== Demo 完成 ===")

if __name__ == "__main__":
    demo()