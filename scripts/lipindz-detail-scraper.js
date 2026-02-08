#!/usr/bin/env node
/**
 * 产品详情页抓取脚本
 * 用法: node lipindz-detail-scraper.js [batchSize] [startIndex]
 * 
 * 功能：
 * - 读取产品 ID 列表
 * - 并发抓取详情页
 * - 支持断点续抓
 * - 完整字段：名称、品牌、分类、供应商、规格、图片、价格、描述
 */

const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

const DATA_DIR = path.join(__dirname, "..", "data");
const COOKIES_FILE = "/tmp/lipindz-cookies.json";
const PRODUCTS_FILE = path.join(DATA_DIR, "products-bulk-2026-02-08.json");
const OUTPUT_FILE = path.join(DATA_DIR, "products-detail-2026-02-08.json");
const PROGRESS_FILE = path.join(DATA_DIR, ".detail-progress.json");

const BATCH_SIZE = parseInt(process.argv[2]) || 5; // 并发数
const START_INDEX = parseInt(process.argv[3]) || 0;

async function scrapeDetail(page, productId) {
  const url = `https://lipindz.miniappss.com/goodsInfo/${productId}.html`;
  
  try {
    await page.goto(url, { waitUntil: "networkidle", timeout: 30000 });
    
    const detail = await page.evaluate(() => {
      const getText = (sel) => document.querySelector(sel)?.textContent?.trim() || "";
      const getAttr = (sel, attr) => document.querySelector(sel)?.getAttribute(attr) || "";
      
      // 产品名称
      const name = getText(".goods-name, .product-name, h1, .title");
      
      // 品牌
      const brand = getText(".brand-name, [class*=brand], .goods-brand") || 
                    getText("td:contains('品牌') + td, th:contains('品牌') + td");
      
      // 分类
      const category = Array.from(document.querySelectorAll(".breadcrumb a, .crumb a"))
                           .map(a => a.textContent.trim())
                           .filter(t => t && t !== "首页")
                           .join(" > ");
      
      // 价格 - 更精确的解析
      const priceText = getText(".show_price, .retail-price, .price, [class*=price]");
      const retailPrice = priceText.match(/[\d.]+/)?.[0] || "";
      
      const wholesaleText = getText(".wholesale-price, .batch-price, [class*=wholesale]");
      const wholesalePrice = wholesaleText.match(/[\d.]+/)?.[0] || "";
      
      // 供应商
      const supplier = getText(".supplier-name, .shop-name, [class*=supplier], [class*=shop]");
      
      // 规格参数
      const specs = {};
      document.querySelectorAll("table tr, .spec-item, .param-item").forEach(row => {
        const cells = row.querySelectorAll("td, th, .label, .value");
        if (cells.length >= 2) {
          const key = cells[0].textContent.trim().replace(/[：:]/g, "");
          const value = cells[1].textContent.trim();
          if (key && value && key.length < 20) {
            specs[key] = value;
          }
        }
      });
      
      // 图片
      const images = Array.from(document.querySelectorAll(".goods-img img, .product-img img, .gallery img, .swiper img"))
                         .map(img => img.src || img.dataset.src)
                         .filter(Boolean)
                         .slice(0, 10);
      
      // 描述
      const description = getText(".goods-desc, .product-desc, .description, [class*=detail]")
                         .substring(0, 500);
      
      return {
        name,
        brand,
        category,
        retailPrice,
        wholesalePrice,
        supplier,
        specs,
        images,
        description
      };
    });
    
    return { id: productId, url, ...detail, success: true };
    
  } catch (err) {
    return { id: productId, url, error: err.message, success: false };
  }
}

async function main() {
  console.log("🚀 启动详情页抓取...");
  
  // 读取产品列表
  if (!fs.existsSync(PRODUCTS_FILE)) {
    console.error("❌ 产品列表文件不存在:", PRODUCTS_FILE);
    process.exit(1);
  }
  
  const products = JSON.parse(fs.readFileSync(PRODUCTS_FILE, "utf-8"));
  console.log(`📦 共 ${products.length} 个产品`);
  
  // 读取已抓取的进度
  let completed = [];
  let completedIds = new Set();
  if (fs.existsSync(OUTPUT_FILE)) {
    completed = JSON.parse(fs.readFileSync(OUTPUT_FILE, "utf-8"));
    completedIds = new Set(completed.map(p => p.id));
    console.log(`✅ 已完成 ${completed.length} 个`);
  }
  
  // 过滤待抓取
  const pending = products.filter(p => !completedIds.has(p.id)).slice(START_INDEX);
  console.log(`⏳ 待抓取 ${pending.length} 个\n`);
  
  if (pending.length === 0) {
    console.log("🎉 全部完成！");
    return;
  }
  
  // 启动浏览器
  const browser = await chromium.launch({
    headless: true,
    args: ["--no-sandbox", "--disable-setuid-sandbox"]
  });
  
  const context = await browser.newContext();
  if (fs.existsSync(COOKIES_FILE)) {
    const cookies = JSON.parse(fs.readFileSync(COOKIES_FILE, "utf-8"));
    await context.addCookies(cookies);
  }
  
  // 创建多个页面并发抓取
  const pages = await Promise.all(
    Array(BATCH_SIZE).fill().map(() => context.newPage())
  );
  
  let processed = 0;
  const results = [...completed];
  
  // 批量处理
  for (let i = 0; i < pending.length; i += BATCH_SIZE) {
    const batch = pending.slice(i, i + BATCH_SIZE);
    
    const batchResults = await Promise.all(
      batch.map((p, idx) => scrapeDetail(pages[idx % pages.length], p.id))
    );
    
    results.push(...batchResults);
    processed += batch.length;
    
    // 每 10 个保存一次进度
    if (processed % 10 === 0 || i + BATCH_SIZE >= pending.length) {
      fs.writeFileSync(OUTPUT_FILE, JSON.stringify(results, null, 2));
      const successCount = results.filter(r => r.success).length;
      console.log(`📊 进度: ${processed}/${pending.length} (成功: ${successCount})`);
    }
    
    await new Promise(r => setTimeout(r, 200)); // 礼貌延迟
  }
  
  await browser.close();
  
  const successCount = results.filter(r => r.success).length;
  console.log(`\n🎉 完成！总计 ${results.length} 个，成功 ${successCount} 个`);
  console.log(`💾 保存到 ${OUTPUT_FILE}`);
}

main().catch(console.error);
