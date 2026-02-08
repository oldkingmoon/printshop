"""
PDF/PPT 智能解析模块
使用多模态 LLM（GPT-4V/Claude）解析供应商价格表
"""
import os
import json
import base64
from typing import List, Dict, Optional
from pathlib import Path
import tempfile

# PDF 处理
from pdf2image import convert_from_path
# PPT 处理
from pptx import Presentation
from PIL import Image
import io

# LLM
from openai import OpenAI

class DocumentParser:
    """文档解析器"""
    
    def __init__(self, api_key: Optional[str] = None):
        self.client = OpenAI(api_key=api_key or os.getenv("OPENAI_API_KEY"))
        
    def parse_file(self, file_path: str, supplier_name: Optional[str] = None) -> Dict:
        """解析 PDF/PPT 文件"""
        path = Path(file_path)
        
        if path.suffix.lower() == '.pdf':
            images = self._pdf_to_images(file_path)
        elif path.suffix.lower() in ['.ppt', '.pptx']:
            images = self._ppt_to_images(file_path)
        else:
            raise ValueError(f"不支持的文件格式: {path.suffix}")
        
        # 解析每一页
        all_products = []
        for i, img in enumerate(images):
            print(f"正在解析第 {i+1}/{len(images)} 页...")
            products = self._parse_image(img, supplier_name)
            all_products.extend(products)
        
        return {
            "supplier": supplier_name or "未知供应商",
            "source_file": path.name,
            "total_pages": len(images),
            "products": all_products
        }
    
    def _pdf_to_images(self, pdf_path: str) -> List[Image.Image]:
        """将 PDF 转换为图片列表"""
        images = convert_from_path(pdf_path, dpi=150)
        return images
    
    def _ppt_to_images(self, ppt_path: str) -> List[Image.Image]:
        """将 PPT 转换为图片列表"""
        prs = Presentation(ppt_path)
        images = []
        
        # 使用临时目录
        with tempfile.TemporaryDirectory() as tmpdir:
            for i, slide in enumerate(prs.slides):
                # 导出幻灯片为图片（需要 LibreOffice 或其他工具）
                # 这里使用简化方案：提取文本
                pass
        
        # 如果无法导出图片，返回空列表，改用文本解析
        return images
    
    def _parse_image(self, image: Image.Image, supplier_name: Optional[str] = None) -> List[Dict]:
        """使用 GPT-4V 解析图片中的产品信息"""
        
        # 将图片转为 base64
        buffered = io.BytesIO()
        image.save(buffered, format="PNG")
        img_base64 = base64.b64encode(buffered.getvalue()).decode()
        
        prompt = f"""请分析这张供应商价格表图片，提取所有产品信息。

供应商名称：{supplier_name or '请识别'}

请提取以下信息并以 JSON 格式返回：
{{
  "products": [
    {{
      "name": "产品名称",
      "category": "产品分类（如：打印、喷绘、印刷等）",
      "supplier_price": 供应商价格（数字，如果有的话）,
      "retail_price": 零售价格（数字），
      "unit": "单位（如：张、份、个）",
      "min_quantity": 起订量（数字，默认1）,
      "description": "产品描述或规格"
    }}
  ]
}}

注意：
1. 如果价格表中同时有供应商价和零售价，请都提取
2. 如果只有一个价格，默认为零售价
3. 单位和起订量如果不明确，可以省略
4. 只返回 JSON，不要其他内容"""

        try:
            response = self.client.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/png;base64,{img_base64}"
                                }
                            }
                        ]
                    }
                ],
                max_tokens=4096
            )
            
            content = response.choices[0].message.content
            
            # 提取 JSON
            if "```json" in content:
                content = content.split("```json")[1].split("```")[0]
            elif "```" in content:
                content = content.split("```")[1].split("```")[0]
            
            result = json.loads(content.strip())
            return result.get("products", [])
            
        except Exception as e:
            print(f"解析失败: {e}")
            return []
    
    def generate_customer_pricelist(self, products: List[Dict]) -> List[Dict]:
        """生成客户版价格表（去除供应商价）"""
        customer_products = []
        for p in products:
            customer_p = {k: v for k, v in p.items() if k != 'supplier_price'}
            customer_products.append(customer_p)
        return customer_products


# 使用示例
if __name__ == "__main__":
    parser = DocumentParser()
    
    # 解析文件
    result = parser.parse_file("supplier_catalog.pdf", "测试供应商")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    
    # 生成客户版
    customer_list = parser.generate_customer_pricelist(result["products"])
    print("\n客户版价格表:")
    print(json.dumps(customer_list, ensure_ascii=False, indent=2))
