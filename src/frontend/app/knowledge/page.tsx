"use client";
import { useState, useEffect } from "react";

interface Category {
  id: number;
  name: string;
  product_count: number;
}

interface Product {
  id: number;
  name: string;
  description: string;
  category_id: number;
  category_name: string;
  image_url?: string;
}

const API_BASE = "http://192.168.1.8:8000";

export default function KnowledgePage() {
  const [categories, setCategories] = useState<Category[]>([]);
  const [products, setProducts] = useState<Product[]>([]);
  const [selectedCategory, setSelectedCategory] = useState<number | null>(null);
  const [searchQuery, setSearchQuery] = useState("");
  const [stats, setStats] = useState<{products: number; categories: number; suppliers: number} | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    fetch(`${API_BASE}/categories`).then(r => r.json()).then(setCategories);
    fetch(`${API_BASE}/stats`).then(r => r.json()).then(setStats);
    fetch(`${API_BASE}/products?limit=20`).then(r => r.json()).then(setProducts);
  }, []);

  const handleCategoryClick = async (categoryId: number) => {
    setLoading(true);
    setSelectedCategory(categoryId);
    const res = await fetch(`${API_BASE}/products?category_id=${categoryId}`);
    setProducts(await res.json());
    setLoading(false);
  };

  const handleSearch = async () => {
    if (!searchQuery.trim()) return;
    setLoading(true);
    setSelectedCategory(null);
    const res = await fetch(`${API_BASE}/products?search=${encodeURIComponent(searchQuery)}`);
    setProducts(await res.json());
    setLoading(false);
  };

  const handleShowAll = async () => {
    setLoading(true);
    setSelectedCategory(null);
    setSearchQuery("");
    const res = await fetch(`${API_BASE}/products?limit=71`);
    setProducts(await res.json());
    setLoading(false);
  };

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <div className="bg-white rounded-lg shadow p-6 mb-6">
          <h1 className="text-2xl font-bold text-gray-800">PrintShop 知识库</h1>
          <p className="text-gray-600 mt-1">印刷产品智能匹配系统</p>
          {stats && (
            <div className="flex gap-6 mt-4">
              <div className="bg-blue-50 px-4 py-2 rounded">
                <span className="text-2xl font-bold text-blue-600">{stats.products}</span>
                <span className="text-gray-600 ml-2">产品</span>
              </div>
              <div className="bg-green-50 px-4 py-2 rounded">
                <span className="text-2xl font-bold text-green-600">{stats.categories}</span>
                <span className="text-gray-600 ml-2">分类</span>
              </div>
              <div className="bg-purple-50 px-4 py-2 rounded">
                <span className="text-2xl font-bold text-purple-600">{stats.suppliers}</span>
                <span className="text-gray-600 ml-2">供应商</span>
              </div>
            </div>
          )}
        </div>

        {/* Search */}
        <div className="bg-white rounded-lg shadow p-4 mb-6">
          <div className="flex gap-2">
            <input
              type="text"
              placeholder="搜索产品..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyPress={(e) => e.key === "Enter" && handleSearch()}
              className="flex-1 border rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <button
              onClick={handleSearch}
              className="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700"
            >
              搜索
            </button>
            <button
              onClick={handleShowAll}
              className="bg-gray-200 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-300"
            >
              全部
            </button>
          </div>
        </div>

        <div className="flex gap-6">
          {/* Categories Sidebar */}
          <div className="w-64 bg-white rounded-lg shadow p-4">
            <h2 className="font-bold text-gray-700 mb-3">产品分类</h2>
            <div className="space-y-1">
              {categories.map((cat) => (
                <button
                  key={cat.id}
                  onClick={() => handleCategoryClick(cat.id)}
                  className={`w-full text-left px-3 py-2 rounded-lg transition ${
                    selectedCategory === cat.id
                      ? "bg-blue-100 text-blue-700"
                      : "hover:bg-gray-100"
                  }`}
                >
                  <span>{cat.name}</span>
                  <span className="float-right text-gray-400 text-sm">{cat.product_count}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Products Grid */}
          <div className="flex-1">
            <div className="bg-white rounded-lg shadow p-4">
              <div className="flex justify-between items-center mb-4">
                <h2 className="font-bold text-gray-700">
                  {selectedCategory
                    ? categories.find((c) => c.id === selectedCategory)?.name
                    : "全部产品"}
                </h2>
                <span className="text-gray-500 text-sm">{products.length} 个产品</span>
              </div>
              {loading ? (
                <div className="text-center py-8 text-gray-500">加载中...</div>
              ) : (
                <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                  {products.map((product) => (
                    <div
                      key={product.id}
                      className="border rounded-lg p-4 hover:shadow-md transition cursor-pointer"
                    >
                      {product.image_url && (
                        <img
                          src={product.image_url}
                          alt={product.name}
                          className="w-full h-32 object-cover rounded-lg mb-3"
                        />
                      )}
                      <h3 className="font-medium text-gray-800">{product.name}</h3>
                      <p className="text-gray-500 text-sm mt-1 line-clamp-2">
                        {product.description || "暂无描述"}
                      </p>
                      <span className="inline-block mt-2 text-xs bg-gray-100 text-gray-600 px-2 py-1 rounded">
                        {product.category_name}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
