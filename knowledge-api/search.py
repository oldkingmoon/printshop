"""
PrintShop 知识库向量搜索模块
"""

import json
import numpy as np
from pathlib import Path
from typing import List, Dict, Optional
from dataclasses import dataclass


@dataclass
class SearchResult:
    """搜索结果"""
    id: str
    title: str
    content: str
    category: str
    path: str
    similarity: float


class KnowledgeSearch:
    """知识库向量搜索引擎"""
    
    def __init__(self, embeddings_path: str):
        self.embeddings_path = Path(embeddings_path)
        self.documents: List[Dict] = []
        self.embeddings: np.ndarray = None
        self.model = None
        self.model_name: str = ""
        self._loaded = False
    
    def load(self) -> bool:
        """加载向量文件到内存"""
        if self._loaded:
            return True
            
        if not self.embeddings_path.exists():
            raise FileNotFoundError(f"向量文件不存在: {self.embeddings_path}")
        
        print(f"📂 加载向量文件: {self.embeddings_path}")
        with open(self.embeddings_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        
        self.model_name = data["metadata"]["model"]
        self.documents = data["documents"]
        
        # 提取嵌入向量为 numpy 数组（加速计算）
        self.embeddings = np.array([doc["embedding"] for doc in self.documents])
        
        print(f"✅ 加载完成: {len(self.documents)} 个文档, 维度 {self.embeddings.shape[1]}")
        self._loaded = True
        return True
    
    def load_model(self):
        """加载 sentence-transformers 模型"""
        if self.model is not None:
            return
            
        try:
            from sentence_transformers import SentenceTransformer
            print(f"🤖 加载模型: {self.model_name}")
            self.model = SentenceTransformer(self.model_name)
            print("✅ 模型加载完成")
        except ImportError:
            raise ImportError("需要安装 sentence-transformers: pip install sentence-transformers")
    
    def encode_query(self, query: str) -> np.ndarray:
        """将查询文本编码为向量"""
        self.load_model()
        return self.model.encode(query)
    
    def search(self, query: str, top_k: int = 5) -> List[SearchResult]:
        """
        搜索最相似的文档
        
        Args:
            query: 查询文本
            top_k: 返回结果数量
            
        Returns:
            搜索结果列表
        """
        if not self._loaded:
            self.load()
        
        # 编码查询
        query_embedding = self.encode_query(query)
        
        # 计算余弦相似度
        similarities = self._cosine_similarity(query_embedding, self.embeddings)
        
        # 获取 top_k 索引
        top_indices = np.argsort(similarities)[::-1][:top_k]
        
        # 构建结果
        results = []
        for idx in top_indices:
            doc = self.documents[idx]
            results.append(SearchResult(
                id=doc["id"],
                title=doc["title"],
                content=doc["content"][:500],  # 截断内容
                category=doc["category"],
                path=doc["path"],
                similarity=float(similarities[idx])
            ))
        
        return results
    
    def search_with_embedding(self, query_embedding: np.ndarray, top_k: int = 5) -> List[SearchResult]:
        """
        使用预计算的向量搜索（用于外部编码）
        
        Args:
            query_embedding: 查询向量
            top_k: 返回结果数量
            
        Returns:
            搜索结果列表
        """
        if not self._loaded:
            self.load()
        
        # 计算余弦相似度
        similarities = self._cosine_similarity(query_embedding, self.embeddings)
        
        # 获取 top_k 索引
        top_indices = np.argsort(similarities)[::-1][:top_k]
        
        # 构建结果
        results = []
        for idx in top_indices:
            doc = self.documents[idx]
            results.append(SearchResult(
                id=doc["id"],
                title=doc["title"],
                content=doc["content"][:500],
                category=doc["category"],
                path=doc["path"],
                similarity=float(similarities[idx])
            ))
        
        return results
    
    @staticmethod
    def _cosine_similarity(a: np.ndarray, b: np.ndarray) -> np.ndarray:
        """计算余弦相似度（向量 a 与矩阵 b 的每一行）"""
        # 归一化
        a_norm = a / np.linalg.norm(a)
        b_norm = b / np.linalg.norm(b, axis=1, keepdims=True)
        # 点积
        return np.dot(b_norm, a_norm)
    
    @property
    def stats(self) -> Dict:
        """返回统计信息"""
        if not self._loaded:
            return {"loaded": False}
        
        categories = {}
        for doc in self.documents:
            cat = doc["category"]
            categories[cat] = categories.get(cat, 0) + 1
        
        return {
            "loaded": True,
            "model": self.model_name,
            "total_documents": len(self.documents),
            "embedding_dim": self.embeddings.shape[1] if self.embeddings is not None else 0,
            "categories": categories
        }
