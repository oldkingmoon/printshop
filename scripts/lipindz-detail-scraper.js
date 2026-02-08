#!/usr/bin/env node
/**
 * 产品详情页抓取脚本 v2
 * 修复选择器，使用正确的页面结构
 */

const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

const DATA_DIR = path.join(__dirname, "..", "data");
const COOKIES_FILE = "/tmp/lipindz-cookies.json";
const PRODUCTS_FILE = path.join(DATA_DIR, "products-bulk-2026-02-08.json");
const OUTPUT_FILE = path.join(DATA_DIR, "products-detail-2026-02-08.json");

const BATCH_SIZE = parseInt(process.argv[2]) || 5;
const MAX_PRODUCTS = parseInt(process.argv[3]) || 0; // 0 = 全部

async function scrapeDetail(page, productId) {
  const url = `https://lipindz.miniappss.com/goodsInfo/${productId}.html`;
  
  try {
    await page.goto(url, { waitUntil: "networkidle", timeout: 30000 });
    
    // 使用正确的选择器
    const name = await page.$eval(".title", el => el.textContent.trim()).catch(() => "");
    const priceText = await page.$eval(".price_range", el => el.textContent.trim()).catch(() => "");
    const mainImage = await page.$eval(".big-img img", el => el.src).catch(() => "");
    const thumbnails = await page.$$eval(".small-img img", els => els.map(el => el.src)).catch(() => []);
    const specs = await page.$eval(".spec", el => el.textContent.trim()).catch(() => "");
    const description = await page.$eval(".descript", el => el.textContent.trim().substring(0, 500)).catch(() => "");
    const brand = await page.$eval("#parameter-brand span", el => el.textContent.trim()).catch(() => "");
    const supplier = await page.$eval(".supplier_info_auth", el => el.textContent.trim()).catch(() => "");
    
    // 解析价格范围
    const priceMatch = priceText.match(/[\d.]+/g) || [];
    const minPrice = priceMatch[0] || "";
    const maxPrice = priceMatch[1] || priceMatch[0] || "";
    
    // 解析参数表格
    const params = await page.evaluate(() => {
      const result = {};
      document.querySelectorAll("table tr").forEach(tr => {
        const cells = tr.querySelectorAll("td");
        if (cells.length >= 2) {
          const key = cells[0].textContent.trim().replace(/[：:]/g, "");
          const value = cells[1].textContent.trim();
          if (key && value && key.length < 30) {
            result[key] = value;
          }
        }
      });
      return result;
    }).catch(() => ({}));
    
    // 从参数中提取更多信息
    const brand2 = params["品牌"] || params["商品品牌"] || "";
    const supplier2 = params["供应商"] || params["商家"] || "";
    
    return {
      id: productId,
      url,
      name,
      brand: brand || brand2,
      supplier: supplier || supplier2,
      minPrice,
      maxPrice,
      priceText,
      mainImage,
      thumbnails,
      specs,
      params,
      description,
      success: true
    };
    
  } catch (err) {
    return { id: productId, url, error: err.message, success: false };
  }
}

async function main() {
  console.log("🚀 启动详情页抓取 v2...");
  
  const products = JSON.parse(fs.readFileSync(PRODUCTS_FILE, "utf-8"));
  const limit = MAX_PRODUCTS > 0 ? MAX_PRODUCTS : products.length;
  console.log(`📦 共 ${products.length} 个产品，本次抓取 ${limit} 个`);
  
  // 读取已完成的
  let completed = [];
  let completedIds = new Set();
  if (fs.existsSync(OUTPUT_FILE)) {
    completed = JSON.parse(fs.readFileSync(OUTPUT_FILE, "utf-8"));
    completedIds = new Set(completed.map(p => p.id));
    console.log(`✅ 已完成 ${completed.length} 个`);
  }
  
  const pending = products.filter(p => !completedIds.has(p.id)).slice(0, limit);
  console.log(`⏳ 待抓取 ${pending.length} 个\n`);
  
  if (pending.length === 0) {
    console.log("🎉 全部完成！");
    return;
  }
  
  const browser = await chromium.launch({
    headless: true,
    args: ["--no-sandbox", "--disable-setuid-sandbox"]
  });
  
  const context = await browser.newContext();
  if (fs.existsSync(COOKIES_FILE)) {
    const cookies = JSON.parse(fs.readFileSync(COOKIES_FILE, "utf-8"));
    await context.addCookies(cookies);
  }
  
  const pages = await Promise.all(
    Array(BATCH_SIZE).fill().map(() => context.newPage())
  );
  
  let processed = 0;
  const results = [...completed];
  
  for (let i = 0; i < pending.length; i += BATCH_SIZE) {
    const batch = pending.slice(i, i + BATCH_SIZE);
    
    const batchResults = await Promise.all(
      batch.map((p, idx) => scrapeDetail(pages[idx % pages.length], p.id))
    );
    
    results.push(...batchResults);
    processed += batch.length;
    
    if (processed % 100 === 0 || i + BATCH_SIZE >= pending.length) {
      fs.writeFileSync(OUTPUT_FILE, JSON.stringify(results, null, 2));
      const successCount = results.filter(r => r.success).length;
      const withBrand = results.filter(r => r.brand).length;
      const withImage = results.filter(r => r.mainImage).length;
      console.log(`📊 进度: ${processed}/${pending.length} | 成功: ${successCount} | 有品牌: ${withBrand} | 有图片: ${withImage}`);
    }
    
    await new Promise(r => setTimeout(r, 200));
  }
  
  await browser.close();
  
  const successCount = results.filter(r => r.success).length;
  console.log(`\n🎉 完成！总计 ${results.length} 个，成功 ${successCount} 个`);
  console.log(`💾 保存到 ${OUTPUT_FILE}`);
}

main().catch(console.error);
