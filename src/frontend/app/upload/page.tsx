"use client";
import { useState, useCallback } from "react";
import Link from "next/link";

interface MatchResult {
  product_name: string;
  category: string;
  confidence: number;
  price_range?: string;
}

export default function UploadPage() {
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [analyzing, setAnalyzing] = useState(false);
  const [results, setResults] = useState<MatchResult[]>([]);
  const [error, setError] = useState<string | null>(null);

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    const droppedFile = e.dataTransfer.files[0];
    if (droppedFile && droppedFile.type.startsWith("image/")) {
      setFile(droppedFile);
      setPreview(URL.createObjectURL(droppedFile));
      setResults([]);
      setError(null);
    }
  }, []);

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFile = e.target.files?.[0];
    if (selectedFile) {
      setFile(selectedFile);
      setPreview(URL.createObjectURL(selectedFile));
      setResults([]);
      setError(null);
    }
  };

  const handleAnalyze = async () => {
    if (!file) return;
    
    setAnalyzing(true);
    setError(null);
    
    // 模拟AI分析（后续接入GPT-4V）
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // 基于文件名/类型的简单匹配演示
    const mockResults: MatchResult[] = [];
    const fileName = file.name.toLowerCase();
    
    if (fileName.includes("名片") || fileName.includes("card")) {
      mockResults.push({ product_name: "名片", category: "名片/卡片", confidence: 0.95, price_range: "15-80元/盒" });
    } else if (fileName.includes("海报") || fileName.includes("poster")) {
      mockResults.push({ product_name: "海报", category: "单张", confidence: 0.92, price_range: "1-10元/张" });
    } else if (fileName.includes("画册") || fileName.includes("册")) {
      mockResults.push({ product_name: "画册", category: "书籍画册", confidence: 0.88, price_range: "5-50元/本" });
    } else if (fileName.includes("标签") || fileName.includes("不干胶")) {
      mockResults.push({ product_name: "铜版不干胶", category: "标签/不干胶", confidence: 0.90, price_range: "0.4-2元/张" });
    } else {
      // 默认推荐
      mockResults.push(
        { product_name: "名片", category: "名片/卡片", confidence: 0.65, price_range: "15-80元/盒" },
        { product_name: "宣传单", category: "单张", confidence: 0.55, price_range: "0.05-0.3元/张" },
        { product_name: "画册", category: "书籍画册", confidence: 0.45, price_range: "5-50元/本" }
      );
    }
    
    setResults(mockResults);
    setAnalyzing(false);
  };

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="flex justify-between items-center mb-6">
          <div>
            <h1 className="text-2xl font-bold text-gray-800">上传设计稿</h1>
            <p className="text-gray-600">AI 自动识别并匹配印刷产品</p>
          </div>
          <Link href="/" className="text-blue-600 hover:underline">
            返回首页
          </Link>
        </div>

        <div className="grid grid-cols-2 gap-6">
          {/* Upload Area */}
          <div className="bg-white rounded-lg shadow p-6">
            <div
              onDrop={handleDrop}
              onDragOver={(e) => e.preventDefault()}
              className={`border-2 border-dashed rounded-lg p-8 text-center transition ${
                preview ? "border-green-400 bg-green-50" : "border-gray-300 hover:border-blue-400"
              }`}
            >
              {preview ? (
                <div>
                  <img src={preview} alt="预览" className="max-h-48 mx-auto mb-4 rounded" />
                  <p className="text-gray-600">{file?.name}</p>
                </div>
              ) : (
                <div>
                  <div className="text-4xl mb-4">📤</div>
                  <p className="text-gray-600 mb-2">拖拽设计稿到这里</p>
                  <p className="text-gray-400 text-sm">或点击下方按钮选择文件</p>
                </div>
              )}
            </div>
            
            <div className="mt-4 space-y-3">
              <input
                type="file"
                accept="image/*,.pdf"
                onChange={handleFileSelect}
                className="hidden"
                id="file-input"
              />
              <label
                htmlFor="file-input"
                className="block w-full text-center bg-gray-100 text-gray-700 py-2 rounded-lg cursor-pointer hover:bg-gray-200"
              >
                选择文件
              </label>
              
              <button
                onClick={handleAnalyze}
                disabled={!file || analyzing}
                className={`w-full py-3 rounded-lg font-medium ${
                  file && !analyzing
                    ? "bg-blue-600 text-white hover:bg-blue-700"
                    : "bg-gray-200 text-gray-400 cursor-not-allowed"
                }`}
              >
                {analyzing ? "分析中..." : "开始智能匹配"}
              </button>
            </div>
          </div>

          {/* Results */}
          <div className="bg-white rounded-lg shadow p-6">
            <h2 className="font-bold text-gray-700 mb-4">匹配结果</h2>
            
            {error && (
              <div className="bg-red-50 text-red-600 p-4 rounded-lg mb-4">{error}</div>
            )}
            
            {analyzing && (
              <div className="text-center py-8">
                <div className="animate-spin w-8 h-8 border-4 border-blue-600 border-t-transparent rounded-full mx-auto mb-4"></div>
                <p className="text-gray-600">AI 正在分析您的设计稿...</p>
              </div>
            )}
            
            {!analyzing && results.length === 0 && (
              <div className="text-center py-8 text-gray-400">
                <p>上传设计稿后，AI 将自动匹配合适的印刷产品</p>
              </div>
            )}
            
            {results.length > 0 && (
              <div className="space-y-3">
                {results.map((result, index) => (
                  <div
                    key={index}
                    className={`p-4 rounded-lg border ${
                      index === 0 ? "border-green-400 bg-green-50" : "border-gray-200"
                    }`}
                  >
                    <div className="flex justify-between items-start">
                      <div>
                        <h3 className="font-medium text-gray-800">{result.product_name}</h3>
                        <p className="text-gray-500 text-sm">{result.category}</p>
                        {result.price_range && (
                          <p className="text-blue-600 text-sm mt-1">参考价: {result.price_range}</p>
                        )}
                      </div>
                      <div className="text-right">
                        <span className={`text-sm font-medium ${
                          result.confidence > 0.8 ? "text-green-600" : 
                          result.confidence > 0.6 ? "text-yellow-600" : "text-gray-500"
                        }`}>
                          {Math.round(result.confidence * 100)}% 匹配
                        </span>
                        {index === 0 && (
                          <span className="block text-xs text-green-600 mt-1">推荐</span>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
