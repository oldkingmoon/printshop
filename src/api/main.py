"""PrintShop Knowledge API - FastAPI Backend"""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import asyncpg
from typing import Optional, List
from pydantic import BaseModel

app = FastAPI(title="PrintShop Knowledge API", version="1.0.0")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database connection
DATABASE_URL = "postgresql://printshop:printshop123@localhost:5432/printshop"
pool = None

@app.on_event("startup")
async def startup():
    global pool
    pool = await asyncpg.create_pool(DATABASE_URL)

@app.on_event("shutdown")
async def shutdown():
    await pool.close()

# Models
class Product(BaseModel):
    id: int
    name: str
    description: Optional[str]
    category_id: Optional[int]
    category_name: Optional[str]
    image_url: Optional[str] = None

class Category(BaseModel):
    id: int
    name: str
    product_count: Optional[int]

# Routes
@app.get("/")
async def root():
    return {"service": "PrintShop Knowledge API", "status": "running"}

@app.get("/health")
async def health():
    async with pool.acquire() as conn:
        result = await conn.fetchval("SELECT COUNT(*) FROM products")
    return {"status": "healthy", "products": result}

@app.get("/categories", response_model=List[Category])
async def list_categories():
    async with pool.acquire() as conn:
        rows = await conn.fetch("""
            SELECT c.id, c.name, COUNT(p.id) as product_count
            FROM categories c
            LEFT JOIN products p ON p.category_id = c.id
            GROUP BY c.id, c.name
            ORDER BY c.id
        """)
    return [dict(r) for r in rows]

@app.get("/products", response_model=List[Product])
async def list_products(category_id: Optional[int] = None, search: Optional[str] = None, limit: int = 50):
    async with pool.acquire() as conn:
        if category_id:
            rows = await conn.fetch("""
                SELECT p.id, p.name, p.description, p.category_id, c.name as category_name, p.image_url
                FROM products p
                LEFT JOIN categories c ON p.category_id = c.id
                WHERE p.category_id = $1
                ORDER BY p.id LIMIT $2
            """, category_id, limit)
        elif search:
            rows = await conn.fetch("""
                SELECT p.id, p.name, p.description, p.category_id, c.name as category_name, p.image_url
                FROM products p
                LEFT JOIN categories c ON p.category_id = c.id
                WHERE p.name ILIKE $1 OR p.description ILIKE $1
                ORDER BY p.id LIMIT $2
            """, f"%{search}%", limit)
        else:
            rows = await conn.fetch("""
                SELECT p.id, p.name, p.description, p.category_id, c.name as category_name, p.image_url
                FROM products p
                LEFT JOIN categories c ON p.category_id = c.id
                ORDER BY p.id LIMIT $1
            """, limit)
    return [dict(r) for r in rows]

@app.get("/products/{product_id}", response_model=Product)
async def get_product(product_id: int):
    async with pool.acquire() as conn:
        row = await conn.fetchrow("""
            SELECT p.id, p.name, p.description, p.category_id, c.name as category_name, p.image_url
            FROM products p
            LEFT JOIN categories c ON p.category_id = c.id
            WHERE p.id = $1
        """, product_id)
    if not row:
        raise HTTPException(status_code=404, detail="Product not found")
    return dict(row)

@app.get("/stats")
async def get_stats():
    async with pool.acquire() as conn:
        products = await conn.fetchval("SELECT COUNT(*) FROM products")
        categories = await conn.fetchval("SELECT COUNT(*) FROM categories")
        suppliers = await conn.fetchval("SELECT COUNT(*) FROM suppliers")
    return {
        "products": products,
        "categories": categories,
        "suppliers": suppliers
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
