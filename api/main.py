"""
PrintShop API - 供应商资料管理系统
"""
from fastapi import FastAPI, UploadFile, File, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import uuid
from datetime import datetime

app = FastAPI(
    title="PrintShop API",
    description="供应商资料上传与解析系统",
    version="1.0.0"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 模拟任务存储 (生产环境用 Redis/PostgreSQL)
tasks_db = {}

# ============ 数据模型 ============

class TaskResponse(BaseModel):
    task_id: str
    filename: str
    status: str
    created_at: datetime

class TaskStatus(BaseModel):
    task_id: str
    status: str  # queued, processing, completed, failed
    progress: int
    result: Optional[dict] = None

class ProductImport(BaseModel):
    task_id: str
    confirmed: bool = True

class Product(BaseModel):
    id: int
    name: str
    supplier_name: Optional[str]
    supplier_price: Optional[float]
    retail_price: Optional[float]
    category: Optional[str]

# ============ API 路由 ============

@app.post("/api/v1/upload", response_model=TaskResponse)
async def upload_file(
    file: UploadFile = File(...),
    supplier_name: Optional[str] = None,
    background_tasks: BackgroundTasks = None
):
    """上传供应商 PDF/PPT 文件"""
    
    # 验证文件类型
    allowed_types = [".pdf", ".ppt", ".pptx"]
    filename = file.filename.lower()
    if not any(filename.endswith(t) for t in allowed_types):
        raise HTTPException(400, "只支持 PDF、PPT、PPTX 文件")
    
    # 创建任务
    task_id = str(uuid.uuid4())
    task = {
        "task_id": task_id,
        "filename": file.filename,
        "supplier_name": supplier_name,
        "status": "queued",
        "progress": 0,
        "result": None,
        "created_at": datetime.now()
    }
    tasks_db[task_id] = task
    
    # 后台处理解析
    if background_tasks:
        background_tasks.add_task(process_file, task_id, file)
    
    return TaskResponse(
        task_id=task_id,
        filename=file.filename,
        status="queued",
        created_at=task["created_at"]
    )

@app.get("/api/v1/tasks/{task_id}", response_model=TaskStatus)
async def get_task_status(task_id: str):
    """查询解析任务状态"""
    if task_id not in tasks_db:
        raise HTTPException(404, "任务不存在")
    
    task = tasks_db[task_id]
    return TaskStatus(
        task_id=task_id,
        status=task["status"],
        progress=task["progress"],
        result=task.get("result")
    )

@app.get("/api/v1/tasks")
async def list_tasks(limit: int = 20, offset: int = 0):
    """获取任务列表"""
    tasks = list(tasks_db.values())
    tasks.sort(key=lambda x: x["created_at"], reverse=True)
    return {
        "tasks": tasks[offset:offset+limit],
        "total": len(tasks)
    }

@app.post("/api/v1/products/import")
async def import_products(data: ProductImport):
    """将解析结果导入知识库"""
    if data.task_id not in tasks_db:
        raise HTTPException(404, "任务不存在")
    
    task = tasks_db[data.task_id]
    if task["status"] != "completed":
        raise HTTPException(400, "任务尚未完成")
    
    # TODO: 实际导入到 PostgreSQL
    return {"status": "imported", "products_count": len(task.get("result", {}).get("products", []))}

@app.get("/api/v1/products")
async def search_products(q: Optional[str] = None, category: Optional[str] = None, limit: int = 20):
    """搜索产品"""
    # TODO: 实际从 PostgreSQL + 向量搜索
    return {
        "products": [],
        "total": 0,
        "query": q,
        "category": category
    }

# ============ 后台任务 ============

async def process_file(task_id: str, file: UploadFile):
    """后台处理文件解析"""
    import asyncio
    
    task = tasks_db[task_id]
    task["status"] = "processing"
    
    try:
        # 模拟解析过程
        for i in range(1, 11):
            await asyncio.sleep(0.5)
            task["progress"] = i * 10
        
        # 模拟解析结果
        task["result"] = {
            "supplier": task.get("supplier_name", "未知供应商"),
            "products": [
                {"name": "A4 打印", "supplier_price": 0.1, "retail_price": 0.15},
                {"name": "名片印刷", "supplier_price": 50, "retail_price": 80},
            ]
        }
        task["status"] = "completed"
        task["progress"] = 100
        
    except Exception as e:
        task["status"] = "failed"
        task["error"] = str(e)

# ============ 健康检查 ============

@app.get("/health")
async def health():
    return {"status": "ok", "time": datetime.now().isoformat()}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
