#!/usr/bin/env node

/**
 * 自动生成sitemap.xml文件
 * 
 * 此脚本用于构建时自动生成网站的sitemap.xml文件
 * 将静态路由和动态资源路由添加到站点地图中
 */

import fs from 'fs';
import path from 'path';
import axios from 'axios';
import { fileURLToPath } from 'url';
import { config as dotenvConfig } from 'dotenv'; // 使用别名避免冲突

// 加载 .env.production
dotenvConfig({ path: path.resolve('.env.production') });

// 调试：检查 BASE_URL 是否正确加载
console.log('BASE_URL:', process.env.BASE_URL);

// 获取当前文件的目录路径
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// 命令行参数
const args = process.argv.slice(2);
const TEST_MODE = args.includes('--test') || args.includes('-t');

// 配置项
const config = {
  // 网站基础URL
  baseUrl: process.env.BASE_URL,
  // 输出目录
  outputDir: path.resolve(__dirname, '../public'),
  // API基础URL - 注意这里使用了环境变量或开发环境的默认值
  apiBaseUrl: `${process.env.BASE_URL}/app/` || 'http://localhost:8000/app/api',
  // 是否为测试模式
  testMode: TEST_MODE,
  // 每次API请求的资源数量限制
  batchSize: 100,
  // 并发请求数量
  concurrentRequests: 10,
  // 并发请求间隔时间(毫秒)
  requestDelay: 100,
  // 每个sitemap文件中的最大URL数量（超过此数量会分割sitemap）
  maxUrlsPerSitemap: 50000,
  // 是否创建sitemap索引（当有多个sitemap文件时）
  createSitemapIndex: true,
  // 静态路由
  staticRoutes: [
    {
      path: '/',
      changefreq: 'daily',
      priority: 1.0
    },
    {
      path: '/submit',
      changefreq: 'weekly',
      priority: 0.8
    },
    {
      path: '/about',
      changefreq: 'monthly',
      priority: 0.7
    }
  ],
  // 测试模式下使用的资源数据
  testResources: [
    { id: '1', title: '测试资源1', updated_at: new Date().toISOString() },
    { id: '2', title: '测试资源2', updated_at: new Date().toISOString() },
    { id: '3', title: '测试资源3', updated_at: new Date().toISOString() },
    { id: '4', title: '测试资源4', updated_at: new Date().toISOString() },
    { id: '5', title: '测试资源5', updated_at: new Date().toISOString() }
  ]
};

console.log('站点地图生成器启动');
console.log('使用API基础URL:', config.apiBaseUrl);
console.log('输出目录:', config.outputDir);
console.log('测试模式:', config.testMode ? '开启' : '关闭');

// 确保输出目录存在
if (!fs.existsSync(config.outputDir)) {
  fs.mkdirSync(config.outputDir, { recursive: true });
}

// 生成XML头部
const generateSitemapHeader = () => {
  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">`;
};

// 生成XML尾部
const generateSitemapFooter = () => {
  return `</urlset>`;
};

// 生成静态路由的URL条目
const generateStaticUrls = () => {
  return config.staticRoutes.map(route => {
    const today = new Date().toISOString().split('T')[0];
    return `  <url>
    <loc>${config.baseUrl}${route.path}</loc>
    <lastmod>${today}</lastmod>
    <changefreq>${route.changefreq}</changefreq>
    <priority>${route.priority}</priority>
  </url>`;
  }).join('\n');
};

// 发起单个批次请求
const fetchResourceBatch = async (skip, limit, sort_by = 'likes_count', sort_order = 'desc') => {
  const apiUrl = `${config.apiBaseUrl}/api/resources/public?skip=${skip}&limit=${limit}&sort_by=${sort_by}&sort_order=${sort_order}`;
  console.log(`请求资源数据: skip=${skip}, limit=${limit}`);
  
  try {
    const response = await axios.get(apiUrl);
    if (response.status !== 200) {
      console.error(`API请求失败(skip=${skip}):`, response.status);
      return [];
    }
    
    // 根据实际响应结构调整，并添加null检查
    const responseData = response.data;
    let resources = [];
    
    if (responseData) {
      resources = responseData.resources || responseData.data || responseData || [];
      console.log(`获取到资源(skip=${skip}): ${resources.length}条`);
      
      // 如果响应中包含总数信息，添加到返回的数组中
      if (responseData.total !== undefined) {
        resources.total = responseData.total;
        console.log(`API返回总数信息: total=${resources.total}`);
      }
    } else {
      console.log(`获取到空响应(skip=${skip})`);
    }
    
    return resources;
  } catch (error) {
    console.error(`获取资源失败(skip=${skip}):`, error.message);
    return [];
  }
};

// 生成动态资源的URL条目
const generateDynamicUrls = async () => {
  // 如果是测试模式，使用测试数据
  if (config.testMode) {
    console.log('使用测试模式，生成测试资源URL');
    
    return config.testResources.map(resource => {
      const formattedLastmod = resource.updated_at.split('T')[0];
      
      return `  <url>
    <loc>${config.baseUrl}/resource/${resource.id}</loc>
    <lastmod>${formattedLastmod}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.9</priority>
  </url>`;
    }).join('\n');
  }
  
  try {
    // 分批次并发获取所有资源
    console.log('开始并发获取所有资源数据...');
    
    // 首先发送一个请求获取第一批数据
    console.log('发送首次请求获取数据...');
    const firstBatchSize = config.batchSize;
    const firstBatch = await fetchResourceBatch(0, firstBatchSize, 'likes_count', 'desc');
    
    // 如果第一批数据已经不足批次大小，则表明数据已全部获取
    if (firstBatch.length < firstBatchSize) {
      console.log(`首次请求获取 ${firstBatch.length} 条数据，少于批次大小 ${firstBatchSize}，表明已获取全部数据`);
      
      // 为每个资源生成URL条目
      return firstBatch.map(resource => {
        // 处理ID可能存在的格式差异
        const resourceId = resource.id || resource._id || resource.resourceId;
        
        // 处理日期格式差异
        const lastmod = resource.updatedAt || resource.updated_at || resource.createTime || resource.created_at || new Date().toISOString();
        const formattedLastmod = typeof lastmod === 'string' ? 
          lastmod.split('T')[0] : new Date(lastmod).toISOString().split('T')[0];
        
        return `  <url>
    <loc>${config.baseUrl}/resource/${resourceId}</loc>
    <lastmod>${formattedLastmod}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.9</priority>
  </url>`;
      }).join('\n');
    }
    
    // 如果还需要更多数据，继续并发请求
    console.log(`首次请求获取 ${firstBatch.length} 条数据，达到批次大小，需要继续获取更多数据`);
    let allResources = [...firstBatch]; // 已经包含第一批数据
    
    // 估计总数量
    let totalCount = 0;
    // 如果API返回总数信息
    if (firstBatch.total) {
      totalCount = firstBatch.total;
    } else {
      // 否则根据第一批数据推测，至少是当前获取的数量
      totalCount = Math.max(1000, firstBatch.length * 2);
    }
    console.log(`估计总资源数量: ${totalCount}`);
    
    // 计算需要的批次数
    const batchSize = config.batchSize;
    const estimatedBatches = Math.ceil((totalCount - firstBatch.length) / batchSize);
    console.log(`已获取第一批 ${firstBatch.length} 条，预计还需要 ${estimatedBatches} 个批次请求`);
    
    // 准备剩余的请求
    const remainingRequests = [];
    for (let skip = firstBatchSize; skip < totalCount; skip += batchSize) {
      remainingRequests.push({ skip, limit: batchSize });
    }
    
    // 如果没有剩余请求，直接返回第一批数据
    if (remainingRequests.length === 0) {
      console.log('无需进一步请求，已获取所有数据');
      
      // 为资源生成URL条目
      // ... existing code for generating URLs from resources
      
      return allResources.map(resource => {
        // 处理ID可能存在的格式差异
        const resourceId = resource.id || resource._id || resource.resourceId;
        
        // 处理日期格式差异
        const lastmod = resource.updatedAt || resource.updated_at || resource.createTime || resource.created_at || new Date().toISOString();
        const formattedLastmod = typeof lastmod === 'string' ? 
          lastmod.split('T')[0] : new Date(lastmod).toISOString().split('T')[0];
        
        return `  <url>
    <loc>${config.baseUrl}/resource/${resourceId}</loc>
    <lastmod>${formattedLastmod}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.9</priority>
  </url>`;
      }).join('\n');
    }
    
    // 分组进行并发请求
    const concurrentBatchSize = config.concurrentRequests;
    let dataCompletelyFetched = false; // 标记是否已获取全部数据
    
    // 按并发数量分组处理请求
    for (let batchIndex = 0; batchIndex < remainingRequests.length && !dataCompletelyFetched; batchIndex += concurrentBatchSize) {
      // 如果已经获取到所有数据，跳过后续批次
      if (dataCompletelyFetched) {
        console.log('已获取所有资源数据，跳过剩余请求');
        break;
      }
      
      const currentBatchRequests = remainingRequests.slice(batchIndex, batchIndex + concurrentBatchSize);
      console.log(`处理并发批次 ${Math.floor(batchIndex / concurrentBatchSize) + 1}/${Math.ceil(remainingRequests.length / concurrentBatchSize)}, 包含${currentBatchRequests.length}个请求`);
      
      // 准备当前批次的所有请求
      const currentBatchPromises = currentBatchRequests.map(req => 
        fetchResourceBatch(req.skip, req.limit)
      );
      
      // 并发执行当前批次的所有请求
      const results = await Promise.all(currentBatchPromises);
      
      // 检查结果，合并资源
      let resourcesInBatch = 0;
      let anyBatchIncomplete = false;
      
      results.forEach((resources, idx) => {
        if (resources && resources.length) {
          allResources = [...allResources, ...resources];
          resourcesInBatch += resources.length;
          
          // 检查该批次是否获取了完整数据（小于限制数量表示已到末尾）
          if (resources.length < batchSize) {
            console.log(`请求 ${currentBatchRequests[idx].skip}/${currentBatchRequests[idx].limit} 返回数据不足 ${batchSize} 条，表明已到达数据末尾`);
            
            // 判断此批次的请求是否包含最后的数据
            const isLastBatchForThisSkip = (resources.length > 0 && resources.length < currentBatchRequests[idx].limit);
            
            if (isLastBatchForThisSkip) {
              // 标记为已获取全部数据，后续批次无需请求
              dataCompletelyFetched = true;
            }
          }
        }
      });
      
      console.log(`当前批次获取到${resourcesInBatch}条资源，累计${allResources.length}条`);
      
      // 如果当前批次获取的资源数量小于预期，很可能已经获取了所有数据
      const expectedResourcesInBatch = Math.min(
        currentBatchRequests.length * batchSize, 
        totalCount - batchIndex * batchSize
      );
      
      if (resourcesInBatch < expectedResourcesInBatch) {
        console.log(`资源数量小于预期(${resourcesInBatch} < ${expectedResourcesInBatch})，标记为已获取全部数据`);
        dataCompletelyFetched = true;
      }
      
      // 添加延迟，避免请求过于频繁
      if (!dataCompletelyFetched && batchIndex + concurrentBatchSize < remainingRequests.length) {
        console.log(`等待${config.requestDelay}毫秒后继续下一批请求...`);
        await new Promise(resolve => setTimeout(resolve, config.requestDelay));
      }
    }
    
    console.log(`成功获取所有资源，共${allResources.length}条`);
    
    // 如果未获取到任何资源，使用测试数据
    if (allResources.length === 0) {
      console.warn('未获取到任何资源数据，将使用测试数据');
      return config.testResources.map(resource => {
        const formattedLastmod = resource.updated_at.split('T')[0];
        
        return `  <url>
    <loc>${config.baseUrl}/resource/${resource.id}</loc>
    <lastmod>${formattedLastmod}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.9</priority>
  </url>`;
      }).join('\n');
    }
    
    // 对资源进行去重（可能有重复）
    const uniqueResources = [];
    const resourceIds = new Set();
    
    allResources.forEach(resource => {
      const resourceId = resource.id || resource._id || resource.resourceId;
      if (resourceId && !resourceIds.has(resourceId)) {
        resourceIds.add(resourceId);
        uniqueResources.push(resource);
      }
    });
    
    console.log(`去重后资源数量: ${uniqueResources.length}`);
    
    // 为每个资源生成URL条目
    return uniqueResources.map(resource => {
      // 处理ID可能存在的格式差异
      const resourceId = resource.id || resource._id || resource.resourceId;
      
      // 处理日期格式差异
      const lastmod = resource.updatedAt || resource.updated_at || resource.createTime || resource.created_at || new Date().toISOString();
      const formattedLastmod = typeof lastmod === 'string' ? 
        lastmod.split('T')[0] : new Date(lastmod).toISOString().split('T')[0];
      
      return `  <url>
    <loc>${config.baseUrl}/resource/${resourceId}</loc>
    <lastmod>${formattedLastmod}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.9</priority>
  </url>`;
    }).join('\n');
  } catch (error) {
    console.error('获取动态资源失败:', error.message);
    // 打印更详细的错误信息
    if (error.response) {
      console.error('响应状态:', error.response.status);
      console.error('响应数据:', error.response.data);
    } else if (error.request) {
      console.error('请求未收到响应:', error.request);
    }
    
    console.log('由于API请求失败，使用测试数据生成资源URL');
    return config.testResources.map(resource => {
      const formattedLastmod = resource.updated_at.split('T')[0];
      
      return `  <url>
    <loc>${config.baseUrl}/resource/${resource.id}</loc>
    <lastmod>${formattedLastmod}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.9</priority>
  </url>`;
    }).join('\n');
  }
};

// 主函数
const generateSitemap = async () => {
  try {
    console.log('开始生成站点地图...');
    
    // 生成静态URL
    const staticUrls = generateStaticUrls();
    
    // 尝试生成动态URL
    let dynamicUrls = '';
    try {
      dynamicUrls = await generateDynamicUrls();
    } catch (err) {
      console.warn('无法获取动态URL，只生成静态站点地图:', err.message);
    }
    
    // 计算总URL数量
    const staticUrlsCount = config.staticRoutes.length;
    const dynamicUrlsLines = dynamicUrls ? dynamicUrls.split('\n').filter(line => line.trim().startsWith('<url>')).length : 0;
    const totalUrls = staticUrlsCount + dynamicUrlsLines;
    
    console.log(`站点地图包含: ${staticUrlsCount} 个静态URL + ${dynamicUrlsLines} 个动态URL = 共 ${totalUrls} 个URL`);
    
    // 如果URL数量较少，直接生成单个sitemap文件
    if (totalUrls <= config.maxUrlsPerSitemap) {
      const sitemap = `${generateSitemapHeader()}
${staticUrls}
${dynamicUrls}
${generateSitemapFooter()}`;
      
      // 写入文件
      const outputPath = path.join(config.outputDir, 'sitemap.xml');
      fs.writeFileSync(outputPath, sitemap);
      
      console.log(`站点地图已生成: ${outputPath}`);
    } 
    // 如果URL数量较多，需要分割sitemap
    else {
      console.log(`URL数量(${totalUrls})超过每个sitemap的最大限制(${config.maxUrlsPerSitemap})，将分割生成多个sitemap文件`);
      
      const sitemapFiles = [];
      // 将所有URL合并，然后按maxUrlsPerSitemap分割
      const allUrls = [];
      
      // 添加静态URL
      config.staticRoutes.forEach(route => {
        const today = new Date().toISOString().split('T')[0];
        allUrls.push({
          loc: `${config.baseUrl}${route.path}`,
          lastmod: today,
          changefreq: route.changefreq,
          priority: route.priority
        });
      });
      
      // 添加动态URL（需要解析字符串）
      const dynamicUrlsArray = dynamicUrls.split('<url>').filter(Boolean);
      dynamicUrlsArray.forEach(urlXml => {
        const locMatch = urlXml.match(/<loc>(.*?)<\/loc>/);
        const lastmodMatch = urlXml.match(/<lastmod>(.*?)<\/lastmod>/);
        const changefreqMatch = urlXml.match(/<changefreq>(.*?)<\/changefreq>/);
        const priorityMatch = urlXml.match(/<priority>(.*?)<\/priority>/);
        
        if (locMatch) {
          allUrls.push({
            loc: locMatch[1],
            lastmod: lastmodMatch ? lastmodMatch[1] : new Date().toISOString().split('T')[0],
            changefreq: changefreqMatch ? changefreqMatch[1] : 'weekly',
            priority: priorityMatch ? priorityMatch[1] : '0.7'
          });
        }
      });
      
      // 分批生成sitemap文件
      const batchCount = Math.ceil(allUrls.length / config.maxUrlsPerSitemap);
      console.log(`需要生成 ${batchCount} 个sitemap文件`);
      
      for (let i = 0; i < batchCount; i++) {
        const startIndex = i * config.maxUrlsPerSitemap;
        const endIndex = Math.min((i + 1) * config.maxUrlsPerSitemap, allUrls.length);
        const batchUrls = allUrls.slice(startIndex, endIndex);
        
        // 生成当前批次的sitemap内容
        const batchUrlsXml = batchUrls.map(url => `  <url>
    <loc>${url.loc}</loc>
    <lastmod>${url.lastmod}</lastmod>
    <changefreq>${url.changefreq}</changefreq>
    <priority>${url.priority}</priority>
  </url>`).join('\n');
        
        const sitemap = `${generateSitemapHeader()}
${batchUrlsXml}
${generateSitemapFooter()}`;
        
        // 文件名格式: sitemap-1.xml, sitemap-2.xml, ...
        const sitemapFileName = `sitemap-${i + 1}.xml`;
        const outputPath = path.join(config.outputDir, sitemapFileName);
        fs.writeFileSync(outputPath, sitemap);
        
        sitemapFiles.push({
          fileName: sitemapFileName,
          count: batchUrls.length
        });
        
        console.log(`生成sitemap文件 ${i + 1}/${batchCount}: ${outputPath} (包含 ${batchUrls.length} 个URL)`);
      }
      
      // 如果需要创建sitemap索引文件
      if (config.createSitemapIndex) {
        const today = new Date().toISOString().split('T')[0];
        const sitemapIndex = `<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${sitemapFiles.map(file => `  <sitemap>
    <loc>${config.baseUrl}/${file.fileName}</loc>
    <lastmod>${today}</lastmod>
  </sitemap>`).join('\n')}
</sitemapindex>`;
        
        const indexPath = path.join(config.outputDir, 'sitemap.xml');
        fs.writeFileSync(indexPath, sitemapIndex);
        
        console.log(`生成sitemap索引文件: ${indexPath} (引用 ${sitemapFiles.length} 个sitemap文件)`);
      }
    }
    
    console.log('站点地图生成完成！');
  } catch (error) {
    console.error('生成站点地图失败:', error);
    process.exit(1);
  }
};

// 执行主函数
generateSitemap();