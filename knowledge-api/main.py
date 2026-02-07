"""
PrintShop 知识库查询 API
FastAPI 服务，提供语义搜索接口
"""

import os
from pathlib import Path
from typing import List, Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from search import KnowledgeSearch, SearchResult


# 配置
EMBEDDINGS_PATH = os.environ.get(
    "EMBEDDINGS_PATH",
    str(Path(__file__).parent.parent / "embeddings" / "knowledge-vectors.json")
)

# 全局搜索引擎实例
search_engine: Optional[KnowledgeSearch] = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    global search_engine
    
    # 启动时加载向量
    print("🚀 启动 PrintShop 知识库 API...")
    search_engine = KnowledgeSearch(EMBEDDINGS_PATH)
    search_engine.load()
    
    # 预加载模型（可选，首次查询时也会加载）
    try:
        search_engine.load_model()
    except ImportError as e:
        print(f"⚠️ 模型未加载: {e}")
        print("   首次查询时将尝试加载")
    
    yield
    
    # 关闭时清理
    print("👋 关闭 PrintShop 知识库 API")


# 创建 FastAPI 应用
app = FastAPI(
    title="PrintShop 知识库 API",
    description="图文快印行业知识库语义搜索服务",
    version="1.0.0",
    lifespan=lifespan
)

# CORS 配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============ 请求/响应模型 ============

class QueryRequest(BaseModel):
    """查询请求"""
    question: str = Field(..., description="查询问题", min_length=1, max_length=500)
    top_k: int = Field(default=3, description="返回结果数量", ge=1, le=10)


class ResultItem(BaseModel):
    """单个搜索结果"""
    id: str
    title: str
    content: str
    category: str
    path: str
    similarity: float


class QueryResponse(BaseModel):
    """查询响应"""
    question: str
    results: List[ResultItem]
    total: int


class StatsResponse(BaseModel):
    """统计信息响应"""
    loaded: bool
    model: Optional[str] = None
    total_documents: Optional[int] = None
    embedding_dim: Optional[int] = None
    categories: Optional[dict] = None


# ============ API 路由 ============

@app.get("/", tags=["健康检查"])
async def root():
    """根路径 - 健康检查"""
    return {
        "service": "PrintShop 知识库 API",
        "status": "running",
        "version": "1.0.0"
    }


@app.get("/health", tags=["健康检查"])
async def health():
    """健康检查"""
    return {"status": "healthy"}


@app.get("/stats", response_model=StatsResponse, tags=["统计"])
async def stats():
    """获取知识库统计信息"""
    if search_engine is None:
        raise HTTPException(status_code=503, detail="搜索引擎未初始化")
    return search_engine.stats


@app.post("/query", response_model=QueryResponse, tags=["搜索"])
async def query(request: QueryRequest):
    """
    知识库语义搜索
    
    根据问题查询最相关的知识库内容
    """
    if search_engine is None:
        raise HTTPException(status_code=503, detail="搜索引擎未初始化")
    
    try:
        results = search_engine.search(request.question, request.top_k)
        
        return QueryResponse(
            question=request.question,
            results=[
                ResultItem(
                    id=r.id,
                    title=r.title,
                    content=r.content,
                    category=r.category,
                    path=r.path,
                    similarity=round(r.similarity, 4)
                )
                for r in results
            ],
            total=len(results)
        )
    except ImportError as e:
        raise HTTPException(
            status_code=503,
            detail=f"模型未安装: {str(e)}. 请安装 sentence-transformers"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"搜索失败: {str(e)}")


@app.get("/categories", tags=["统计"])
async def categories():
    """获取知识库分类列表"""
    if search_engine is None:
        raise HTTPException(status_code=503, detail="搜索引擎未初始化")
    
    stats = search_engine.stats
    return {
        "categories": stats.get("categories", {}),
        "total": stats.get("total_documents", 0)
    }


# ============ 启动入口 ============

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8001,
        reload=True
    )
