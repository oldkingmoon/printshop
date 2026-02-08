'use client';

import { useState, useCallback } from 'react';
import { useDropzone } from 'react-dropzone';

interface Task {
  task_id: string;
  filename: string;
  status: 'queued' | 'processing' | 'completed' | 'failed';
  progress: number;
  created_at: string;
}

export default function UploadPage() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [uploading, setUploading] = useState(false);

  const onDrop = useCallback(async (acceptedFiles: File[]) => {
    setUploading(true);
    
    for (const file of acceptedFiles) {
      const formData = new FormData();
      formData.append('file', file);
      
      try {
        const res = await fetch('/api/v1/upload', {
          method: 'POST',
          body: formData,
        });
        
        if (res.ok) {
          const task = await res.json();
          setTasks(prev => [task, ...prev]);
          // 开始轮询状态
          pollTaskStatus(task.task_id);
        }
      } catch (error) {
        console.error('上传失败:', error);
      }
    }
    
    setUploading(false);
  }, []);

  const pollTaskStatus = async (taskId: string) => {
    const interval = setInterval(async () => {
      try {
        const res = await fetch(`/api/v1/tasks/${taskId}`);
        if (res.ok) {
          const status = await res.json();
          setTasks(prev => 
            prev.map(t => t.task_id === taskId ? { ...t, ...status } : t)
          );
          
          if (status.status === 'completed' || status.status === 'failed') {
            clearInterval(interval);
          }
        }
      } catch (error) {
        clearInterval(interval);
      }
    }, 1000);
  };

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'application/pdf': ['.pdf'],
      'application/vnd.ms-powerpoint': ['.ppt'],
      'application/vnd.openxmlformats-officedocument.presentationml.presentation': ['.pptx'],
    },
    maxSize: 50 * 1024 * 1024, // 50MB
  });

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'queued': return '⏳';
      case 'processing': return '🔄';
      case 'completed': return '✅';
      case 'failed': return '❌';
      default: return '❓';
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-3xl font-bold text-gray-900 mb-8">
          供应商资料上传中心
        </h1>

        {/* 上传区域 */}
        <div
          {...getRootProps()}
          className={`
            border-2 border-dashed rounded-xl p-12 text-center cursor-pointer
            transition-colors duration-200
            ${isDragActive 
              ? 'border-blue-500 bg-blue-50' 
              : 'border-gray-300 hover:border-gray-400 bg-white'
            }
          `}
        >
          <input {...getInputProps()} />
          <div className="text-6xl mb-4">📁</div>
          {isDragActive ? (
            <p className="text-xl text-blue-600">放开以上传文件...</p>
          ) : (
            <>
              <p className="text-xl text-gray-600 mb-2">
                拖拽文件到这里，或点击选择文件
              </p>
              <p className="text-sm text-gray-400">
                支持格式：PDF、PPT、PPTX | 单文件最大 50MB
              </p>
            </>
          )}
          {uploading && (
            <p className="mt-4 text-blue-600">上传中...</p>
          )}
        </div>

        {/* 任务列表 */}
        {tasks.length > 0 && (
          <div className="mt-8 bg-white rounded-xl shadow-sm overflow-hidden">
            <div className="px-6 py-4 border-b border-gray-100">
              <h2 className="text-lg font-semibold text-gray-900">
                上传队列
              </h2>
            </div>
            <ul className="divide-y divide-gray-100">
              {tasks.map((task) => (
                <li key={task.task_id} className="px-6 py-4 flex items-center justify-between">
                  <div className="flex items-center gap-4">
                    <span className="text-2xl">{getStatusIcon(task.status)}</span>
                    <div>
                      <p className="font-medium text-gray-900">{task.filename}</p>
                      <p className="text-sm text-gray-500">
                        {task.status === 'processing' 
                          ? `解析中... ${task.progress}%` 
                          : task.status === 'completed'
                          ? '解析完成'
                          : task.status === 'failed'
                          ? '解析失败'
                          : '等待中'
                        }
                      </p>
                    </div>
                  </div>
                  {task.status === 'processing' && (
                    <div className="w-32 bg-gray-200 rounded-full h-2">
                      <div 
                        className="bg-blue-600 h-2 rounded-full transition-all duration-300"
                        style={{ width: `${task.progress}%` }}
                      />
                    </div>
                  )}
                  {task.status === 'completed' && (
                    <button className="px-4 py-2 bg-green-600 text-white rounded-lg text-sm hover:bg-green-700">
                      查看结果
                    </button>
                  )}
                </li>
              ))}
            </ul>
          </div>
        )}

        {/* 操作按钮 */}
        {tasks.some(t => t.status === 'completed') && (
          <div className="mt-6 flex gap-4">
            <button className="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
              添加到知识库
            </button>
            <button className="px-6 py-3 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300">
              导出客户版
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
