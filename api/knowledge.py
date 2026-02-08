"""
知识库 CRUD API
产品和供应商的增删改查
"""
from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
import os

# 数据库（生产环境用 SQLAlchemy + PostgreSQL）
from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, ForeignKey, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session, relationship

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://localhost/printshop")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# ============ 数据模型 ============

class Supplier(Base):
    __tablename__ = "suppliers"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    contact = Column(String(255))
    phone = Column(String(50))
    email = Column(String(255))
    created_at = Column(DateTime, default=datetime.utcnow)
    
    products = relationship("Product", back_populates="supplier")

class Product(Base):
    __tablename__ = "products"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False, index=True)
    supplier_id = Column(Integer, ForeignKey("suppliers.id"))
    supplier_price = Column(Float)
    retail_price = Column(Float)
    unit = Column(String(50))
    min_quantity = Column(Integer, default=1)
    description = Column(Text)
    image_url = Column(String(500))
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    supplier = relationship("Supplier", back_populates="products")

# ============ Pydantic 模型 ============

class SupplierCreate(BaseModel):
    name: str
    contact: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None

class SupplierResponse(BaseModel):
    id: int
    name: str
    contact: Optional[str]
    phone: Optional[str]
    email: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True

class ProductCreate(BaseModel):
    name: str
    supplier_id: Optional[int] = None
    supplier_price: Optional[float] = None
    retail_price: Optional[float] = None
    unit: Optional[str] = None
    min_quantity: Optional[int] = 1
    description: Optional[str] = None
    image_url: Optional[str] = None

class ProductResponse(BaseModel):
    id: int
    name: str
    supplier_id: Optional[int]
    supplier_price: Optional[float]
    retail_price: Optional[float]
    unit: Optional[str]
    min_quantity: Optional[int]
    description: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True

class ProductUpdate(BaseModel):
    name: Optional[str] = None
    supplier_price: Optional[float] = None
    retail_price: Optional[float] = None
    unit: Optional[str] = None
    description: Optional[str] = None

# ============ 依赖 ============

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ============ 路由 ============

router = APIRouter(prefix="/api/v1", tags=["knowledge"])

# --- 供应商 ---

@router.post("/suppliers", response_model=SupplierResponse)
def create_supplier(supplier: SupplierCreate, db: Session = Depends(get_db)):
    """创建供应商"""
    db_supplier = Supplier(**supplier.dict())
    db.add(db_supplier)
    db.commit()
    db.refresh(db_supplier)
    return db_supplier

@router.get("/suppliers", response_model=List[SupplierResponse])
def list_suppliers(
    skip: int = 0,
    limit: int = 20,
    q: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """获取供应商列表"""
    query = db.query(Supplier)
    if q:
        query = query.filter(Supplier.name.ilike(f"%{q}%"))
    return query.offset(skip).limit(limit).all()

@router.get("/suppliers/{supplier_id}", response_model=SupplierResponse)
def get_supplier(supplier_id: int, db: Session = Depends(get_db)):
    """获取单个供应商"""
    supplier = db.query(Supplier).filter(Supplier.id == supplier_id).first()
    if not supplier:
        raise HTTPException(404, "供应商不存在")
    return supplier

@router.delete("/suppliers/{supplier_id}")
def delete_supplier(supplier_id: int, db: Session = Depends(get_db)):
    """删除供应商"""
    supplier = db.query(Supplier).filter(Supplier.id == supplier_id).first()
    if not supplier:
        raise HTTPException(404, "供应商不存在")
    db.delete(supplier)
    db.commit()
    return {"status": "deleted"}

# --- 产品 ---

@router.post("/products", response_model=ProductResponse)
def create_product(product: ProductCreate, db: Session = Depends(get_db)):
    """创建产品"""
    db_product = Product(**product.dict())
    db.add(db_product)
    db.commit()
    db.refresh(db_product)
    return db_product

@router.get("/products", response_model=List[ProductResponse])
def list_products(
    skip: int = 0,
    limit: int = 20,
    q: Optional[str] = None,
    supplier_id: Optional[int] = None,
    db: Session = Depends(get_db)
):
    """获取产品列表（支持搜索）"""
    query = db.query(Product)
    if q:
        query = query.filter(Product.name.ilike(f"%{q}%"))
    if supplier_id:
        query = query.filter(Product.supplier_id == supplier_id)
    return query.offset(skip).limit(limit).all()

@router.get("/products/{product_id}", response_model=ProductResponse)
def get_product(product_id: int, db: Session = Depends(get_db)):
    """获取单个产品"""
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(404, "产品不存在")
    return product

@router.put("/products/{product_id}", response_model=ProductResponse)
def update_product(product_id: int, update: ProductUpdate, db: Session = Depends(get_db)):
    """更新产品"""
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(404, "产品不存在")
    
    for key, value in update.dict(exclude_unset=True).items():
        setattr(product, key, value)
    
    db.commit()
    db.refresh(product)
    return product

@router.delete("/products/{product_id}")
def delete_product(product_id: int, db: Session = Depends(get_db)):
    """删除产品"""
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(404, "产品不存在")
    db.delete(product)
    db.commit()
    return {"status": "deleted"}

# --- 批量导入 ---

@router.post("/products/batch")
def batch_import_products(products: List[ProductCreate], db: Session = Depends(get_db)):
    """批量导入产品"""
    created = []
    for p in products:
        db_product = Product(**p.dict())
        db.add(db_product)
        created.append(db_product)
    
    db.commit()
    return {"status": "imported", "count": len(created)}
