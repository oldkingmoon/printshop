-- PrintShop 知识库数据模型
-- 生成时间: 2026-02-08

-- 启用向量扩展
CREATE EXTENSION IF NOT EXISTS vector;

-- 供应商表
CREATE TABLE suppliers (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  contact VARCHAR(255),
  phone VARCHAR(50),
  email VARCHAR(255),
  address TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 分类表 (支持多级分类)
CREATE TABLE categories (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  parent_id INT REFERENCES categories(id),
  type VARCHAR(50), -- industry/product/tag
  created_at TIMESTAMP DEFAULT NOW()
);

-- 产品表
CREATE TABLE products (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  supplier_id INT REFERENCES suppliers(id),
  supplier_price DECIMAL(10,2),
  retail_price DECIMAL(10,2),
  unit VARCHAR(50),
  min_quantity INT DEFAULT 1,
  description TEXT,
  image_url VARCHAR(500),
  embedding VECTOR(1536), -- OpenAI embedding
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 产品分类关联 (多对多)
CREATE TABLE product_categories (
  product_id INT REFERENCES products(id) ON DELETE CASCADE,
  category_id INT REFERENCES categories(id) ON DELETE CASCADE,
  PRIMARY KEY (product_id, category_id)
);

-- 价格历史 (版本控制)
CREATE TABLE price_history (
  id SERIAL PRIMARY KEY,
  product_id INT REFERENCES products(id) ON DELETE CASCADE,
  supplier_price DECIMAL(10,2),
  retail_price DECIMAL(10,2),
  changed_at TIMESTAMP DEFAULT NOW(),
  changed_by VARCHAR(100)
);

-- 解析任务表
CREATE TABLE parse_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  filename VARCHAR(255) NOT NULL,
  file_path VARCHAR(500),
  supplier_name VARCHAR(255),
  status VARCHAR(50) DEFAULT 'queued', -- queued/processing/completed/failed
  progress INT DEFAULT 0,
  result JSONB,
  error_message TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  created_by VARCHAR(100)
);

-- 索引
CREATE INDEX idx_products_supplier ON products(supplier_id);
CREATE INDEX idx_products_name ON products USING gin(to_tsvector('simple', name));
CREATE INDEX idx_parse_tasks_status ON parse_tasks(status);
CREATE INDEX idx_price_history_product ON price_history(product_id);

-- 向量相似度搜索索引
CREATE INDEX idx_products_embedding ON products USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
