#!/usr/bin/env python3
"""
PrintShop 知识库向量嵌入生成器
生成 34 个知识库文档的向量嵌入，支持 JSON 输出和 PostgreSQL/pgvector 写入
"""

import os
import json
import hashlib
from pathlib import Path
from datetime import datetime

# 尝试导入依赖
try:
    from sentence_transformers import SentenceTransformer
except ImportError:
    print("错误: 需要安装 sentence-transformers")
    print("运行: pip install sentence-transformers")
    exit(1)

# 配置
KNOWLEDGE_DIR = Path(__file__).parent.parent / "knowledge"
OUTPUT_JSON = Path(__file__).parent.parent / "embeddings" / "knowledge-vectors.json"
MODEL_NAME = "paraphrase-multilingual-MiniLM-L12-v2"  # 支持中文的多语言模型

# PostgreSQL 配置（可选）
PG_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "database": "printshop",
    "user": "postgres",
    "password": ""  # 从环境变量读取
}


def load_markdown_files(knowledge_dir: Path) -> list[dict]:
    """加载所有 markdown 文件"""
    documents = []
    
    for md_file in knowledge_dir.rglob("*.md"):
        # 跳过 README 文件
        if md_file.name == "README.md":
            continue
            
        relative_path = md_file.relative_to(knowledge_dir)
        category = relative_path.parts[0] if len(relative_path.parts) > 1 else "root"
        
        with open(md_file, "r", encoding="utf-8") as f:
            content = f.read()
        
        # 提取标题（第一个 # 开头的行）
        title = md_file.stem
        for line in content.split("\n"):
            if line.startswith("# "):
                title = line[2:].strip()
                break
        
        # 生成文档 ID（基于路径的 hash）
        doc_id = hashlib.md5(str(relative_path).encode()).hexdigest()[:12]
        
        documents.append({
            "id": doc_id,
            "path": str(relative_path),
            "category": category,
            "title": title,
            "content": content,
            "char_count": len(content)
        })
    
    return documents


def chunk_document(doc: dict, max_chars: int = 1000, overlap: int = 200) -> list[dict]:
    """将长文档分块"""
    content = doc["content"]
    
    # 短文档不分块
    if len(content) <= max_chars:
        return [doc]
    
    chunks = []
    start = 0
    chunk_idx = 0
    
    while start < len(content):
        end = start + max_chars
        
        # 尝试在段落边界切分
        if end < len(content):
            # 找最近的换行符
            newline_pos = content.rfind("\n\n", start, end)
            if newline_pos > start + max_chars // 2:
                end = newline_pos
        
        chunk_content = content[start:end].strip()
        
        if chunk_content:
            chunks.append({
                "id": f"{doc['id']}_c{chunk_idx}",
                "path": doc["path"],
                "category": doc["category"],
                "title": f"{doc['title']} (Part {chunk_idx + 1})",
                "content": chunk_content,
                "char_count": len(chunk_content),
                "chunk_index": chunk_idx,
                "parent_id": doc["id"]
            })
            chunk_idx += 1
        
        start = end - overlap
    
    return chunks


def generate_embeddings(documents: list[dict], model: SentenceTransformer) -> list[dict]:
    """生成向量嵌入"""
    print(f"正在生成 {len(documents)} 个文档的向量嵌入...")
    
    # 提取文本（标题 + 内容）
    texts = [f"{doc['title']}\n\n{doc['content']}" for doc in documents]
    
    # 批量生成嵌入
    embeddings = model.encode(texts, show_progress_bar=True, convert_to_numpy=True)
    
    # 添加嵌入到文档
    for doc, embedding in zip(documents, embeddings):
        doc["embedding"] = embedding.tolist()
        doc["embedding_dim"] = len(embedding)
    
    return documents


def save_to_json(documents: list[dict], output_path: Path):
    """保存到 JSON 文件"""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    # 创建输出结构
    output = {
        "metadata": {
            "model": MODEL_NAME,
            "generated_at": datetime.now().isoformat(),
            "total_documents": len(documents),
            "embedding_dim": documents[0]["embedding_dim"] if documents else 0
        },
        "documents": documents
    }
    
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    
    print(f"✅ 已保存到 {output_path}")
    print(f"   文件大小: {output_path.stat().st_size / 1024 / 1024:.2f} MB")


def save_to_postgres(documents: list[dict]):
    """保存到 PostgreSQL（需要 pgvector 扩展）"""
    try:
        import psycopg2
        from psycopg2.extras import execute_values
    except ImportError:
        print("警告: 未安装 psycopg2，跳过 PostgreSQL 写入")
        return False
    
    password = os.environ.get("PGPASSWORD", PG_CONFIG["password"])
    if not password:
        print("警告: 未设置 PGPASSWORD，跳过 PostgreSQL 写入")
        return False
    
    try:
        conn = psycopg2.connect(
            host=PG_CONFIG["host"],
            port=PG_CONFIG["port"],
            database=PG_CONFIG["database"],
            user=PG_CONFIG["user"],
            password=password
        )
        cur = conn.cursor()
        
        # 确保 pgvector 扩展存在
        cur.execute("CREATE EXTENSION IF NOT EXISTS vector;")
        
        # 创建表（如果不存在）
        embedding_dim = documents[0]["embedding_dim"]
        cur.execute(f"""
            CREATE TABLE IF NOT EXISTS knowledge_embeddings (
                id VARCHAR(20) PRIMARY KEY,
                path VARCHAR(255),
                category VARCHAR(50),
                title VARCHAR(255),
                content TEXT,
                embedding vector({embedding_dim}),
                created_at TIMESTAMP DEFAULT NOW()
            );
        """)
        
        # 清空旧数据
        cur.execute("TRUNCATE knowledge_embeddings;")
        
        # 批量插入
        values = [
            (
                doc["id"],
                doc["path"],
                doc["category"],
                doc["title"],
                doc["content"],
                doc["embedding"]
            )
            for doc in documents
        ]
        
        execute_values(
            cur,
            """
            INSERT INTO knowledge_embeddings (id, path, category, title, content, embedding)
            VALUES %s
            """,
            values,
            template="(%s, %s, %s, %s, %s, %s::vector)"
        )
        
        conn.commit()
        cur.close()
        conn.close()
        
        print(f"✅ 已写入 PostgreSQL ({len(documents)} 条记录)")
        return True
        
    except Exception as e:
        print(f"❌ PostgreSQL 写入失败: {e}")
        return False


def main():
    print("=" * 50)
    print("PrintShop 知识库向量嵌入生成器")
    print("=" * 50)
    
    # 1. 加载文档
    print(f"\n📂 加载知识库: {KNOWLEDGE_DIR}")
    documents = load_markdown_files(KNOWLEDGE_DIR)
    print(f"   找到 {len(documents)} 个文档")
    
    # 2. 分块处理
    print("\n📄 文档分块处理...")
    chunked_docs = []
    for doc in documents:
        chunks = chunk_document(doc)
        chunked_docs.extend(chunks)
    print(f"   分块后共 {len(chunked_docs)} 个片段")
    
    # 3. 加载模型
    print(f"\n🤖 加载模型: {MODEL_NAME}")
    model = SentenceTransformer(MODEL_NAME)
    
    # 4. 生成嵌入
    print("\n⚡ 生成向量嵌入...")
    embedded_docs = generate_embeddings(chunked_docs, model)
    
    # 5. 保存结果
    print("\n💾 保存结果...")
    save_to_json(embedded_docs, OUTPUT_JSON)
    save_to_postgres(embedded_docs)
    
    # 6. 统计
    print("\n📊 统计信息:")
    print(f"   原始文档: {len(documents)}")
    print(f"   分块片段: {len(chunked_docs)}")
    print(f"   向量维度: {embedded_docs[0]['embedding_dim']}")
    
    categories = {}
    for doc in documents:
        cat = doc["category"]
        categories[cat] = categories.get(cat, 0) + 1
    
    print("   分类统计:")
    for cat, count in sorted(categories.items()):
        print(f"     - {cat}: {count}")
    
    print("\n✅ 完成!")


if __name__ == "__main__":
    main()
