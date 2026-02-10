import Link from "next/link";

export default function Home() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center">
      <div className="text-center">
        <h1 className="text-5xl font-bold text-gray-800 mb-4">PrintShop</h1>
        <p className="text-xl text-gray-600 mb-8">智能印刷报价系统</p>
        <div className="space-x-4">
          <Link
            href="/knowledge"
            className="inline-block bg-blue-600 text-white px-8 py-3 rounded-lg text-lg font-medium hover:bg-blue-700 transition"
          >
            知识库浏览
          </Link>
          <Link
            href="/upload"
            className="inline-block bg-white text-blue-600 border-2 border-blue-600 px-8 py-3 rounded-lg text-lg font-medium hover:bg-blue-50 transition"
          >
            上传设计稿
          </Link>
        </div>
        <div className="mt-12 text-gray-500 text-sm">
          <p>71个产品 · 11个分类 · 盛大印刷供应商</p>
        </div>
      </div>
    </div>
  );
}
