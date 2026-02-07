#!/usr/bin/env python3
"""
PrintShop 知识库查询测试
用于联调测试向量嵌入和语义搜索
"""

import json
import numpy as np
from pathlib import Path

EMBEDDINGS_FILE = Path(__file__).parent.parent / "embeddings" / "knowledge-vectors.json"


def cosine_similarity(a, b):
    """计算余弦相似度"""
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))


def search(query_embedding, documents, top_k=5):
    """搜索最相似的文档"""
    results = []
    for doc in documents:
        similarity = cosine_similarity(query_embedding, doc["embedding"])
        results.append({
            "title": doc["title"],
            "category": doc["category"],
            "path": doc["path"],
            "similarity": float(similarity)
        })
    
    results.sort(key=lambda x: x["similarity"], reverse=True)
    return results[:top_k]


def main():
    # 检查向量文件是否存在
    if not EMBEDDINGS_FILE.exists():
        print(f"❌ 向量文件不存在: {EMBEDDINGS_FILE}")
        print("请先运行 generate-embeddings.py 生成向量")
        return
    
    # 加载向量
    print(f"📂 加载向量文件: {EMBEDDINGS_FILE}")
    with open(EMBEDDINGS_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    documents = data["documents"]
    print(f"✅ 加载 {len(documents)} 个文档向量")
    print(f"   模型: {data.get('model', 'unknown')}")
    print(f"   生成时间: {data.get('generated_at', 'unknown')}")
    
    # 测试查询（需要模型来生成查询向量）
    print("\n" + "=" * 50)
    print("测试用例（需要 sentence-transformers 生成查询向量）")
    print("=" * 50)
    
    test_queries = [
        "名片报价多少钱",
        "喷绘用什么材料",
        "画册装订工艺",
        "企业活动物料",
        "VI设计服务"
    ]
    
    try:
        from sentence_transformers import SentenceTransformer
        model = SentenceTransformer(data.get("model", "paraphrase-multilingual-MiniLM-L12-v2"))
        
        for query in test_queries:
            print(f"\n🔍 查询: {query}")
            query_embedding = model.encode(query)
            results = search(query_embedding, documents, top_k=3)
            
            for i, r in enumerate(results, 1):
                print(f"   {i}. [{r['category']}] {r['title']} (相似度: {r['similarity']:.3f})")
    
    except ImportError:
        print("\n⚠️ 未安装 sentence-transformers，无法生成查询向量")
        print("仅显示已加载的文档列表：")
        for doc in documents[:10]:
            print(f"   - [{doc['category']}] {doc['title']}")
        if len(documents) > 10:
            print(f"   ... 还有 {len(documents) - 10} 个文档")


if __name__ == "__main__":
    main()
