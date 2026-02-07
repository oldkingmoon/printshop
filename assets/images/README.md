# 图片素材采集指南

> 更新: 2026-02-06

## 一、素材来源

### 1.1 免费图库（推荐）

| 网站 | 说明 | 授权 |
|------|------|------|
| [Pexels](https://www.pexels.com) | 高质量免费图片 | 免费商用 |
| [Unsplash](https://unsplash.com) | 高质量免费图片 | 免费商用 |
| [Pixabay](https://pixabay.com) | 免费图片素材 | 免费商用 |
| [Freepik](https://www.freepik.com) | 设计素材 | 需注明来源 |

### 1.2 行业参考网站

| 网站 | 说明 |
|------|------|
| [VistaPrint](https://www.vistaprint.com) | 美国印刷电商 |
| [HelloPrint](https://www.helloprint.co.uk) | 欧洲印刷电商 |
| [盛大图文](https://www.sd888.com) | 国内印刷平台 |
| [印刷家](https://www.yinshuajia.com) | 国内印刷平台 |

### 1.3 自拍素材（最佳）

**建议**：拍摄自己店铺的实际产品，最真实！

## 二、目录结构

```
projects/printshop/assets/images/
├── cards/              # 名片
├── banners/            # 易拉宝、展架
├── certificates/       # 证书
├── trophies/           # 奖杯奖牌
├── printing/           # 喷绘、写真
├── packaging/          # 包装盒
├── signage/            # 标识标牌
├── materials/          # 材料样本
├── crafts/             # 工艺效果
└── brochures/          # 画册
```

## 三、命名规范

```
{产品类型}-{具体名称}-{序号}.{格式}

示例：
card-standard-01.jpg        # 标准名片
card-rounded-01.jpg         # 圆角名片
card-foil-gold-01.jpg       # 烫金名片
banner-rollup-80x200-01.jpg # 易拉宝
```

## 四、图片要求

| 属性 | 要求 |
|------|------|
| 格式 | JPG/PNG |
| 尺寸 | 800×600 以上 |
| 大小 | < 500KB |
| 背景 | 干净、白色/浅色 |
| 角度 | 正面、45度、细节 |

## 五、采集脚本

### 5.1 使用 Pexels API

```bash
# 需要先注册获取 API Key: https://www.pexels.com/api/
PEXELS_API_KEY="your_api_key"

# 搜索名片图片
curl -s "https://api.pexels.com/v1/search?query=business+card&per_page=10" \
  -H "Authorization: $PEXELS_API_KEY" | jq '.photos[].src.medium'
```

### 5.2 使用 wget 下载

```bash
# 下载单张图片
wget -O cards/card-standard-01.jpg "图片URL"

# 批量下载
cat urls.txt | xargs -I {} wget -P cards/ {}
```

## 六、待采集清单

### 名片 (cards/)
- [ ] 标准名片（正面、背面）
- [ ] 圆角名片
- [ ] 烫金名片
- [ ] 特种纸名片
- [ ] 透明PVC名片
- [ ] 异形名片

### 易拉宝 (banners/)
- [ ] 易拉宝整体
- [ ] X展架
- [ ] 门型展架
- [ ] 底座特写

### 证书 (certificates/)
- [ ] 红色绒面证书
- [ ] 蓝色皮纹证书
- [ ] 证书内芯
- [ ] 烫金效果

### 奖杯 (trophies/)
- [ ] 水晶奖杯
- [ ] 金属奖杯
- [ ] 奖牌
- [ ] 锦旗

### 喷绘 (printing/)
- [ ] 室内写真
- [ ] 户外喷绘
- [ ] 灯箱
- [ ] 车贴

### 包装 (packaging/)
- [ ] 折叠纸盒
- [ ] 天地盖礼盒
- [ ] 书型盒
- [ ] 手提袋

### 标牌 (signage/)
- [ ] 亚克力门牌
- [ ] 金属标牌
- [ ] 发光字
- [ ] 导视系统

### 材料 (materials/)
- [ ] 纸张对比
- [ ] 喷绘材料
- [ ] 板材对比

### 工艺 (crafts/)
- [ ] 覆膜效果
- [ ] 烫金效果
- [ ] UV效果
- [ ] 装订方式

## 七、临时方案

在正式图片采集完成前，可以使用以下占位图服务：

```markdown
![名片示例](https://via.placeholder.com/800x500/f5f5f5/333?text=Business+Card)
```

或使用 Lorem Picsum：
```markdown
![随机图片](https://picsum.photos/800/500)
```
