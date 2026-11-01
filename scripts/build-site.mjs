import { readFile, writeFile, mkdir, cp } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const out=path.join(root,'.pages');
const base=(process.env.BASE_PATH||'').replace(/\/$/,'');
if(base && !/^\/[\w/-]+$/.test(base))throw new Error('Invalid base path');
const siteUrl=(process.env.SITE_URL||'https://pixelpin.teamhjd.com').replace(/^http:/,'https:').replace(/\/$/,'');
const escape=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function safeUrl(value){const url=new URL(value);if(url.protocol!=='https:')throw new Error('Only HTTPS release links are supported');return escape(url.href);}
function inline(value){return escape(value).replace(/`([^`]+)`/g,'<code>$1</code>').replace(/\*\*([^*]+)\*\*/g,'<strong>$1</strong>').replace(/\[([^\]]+)\]\((https:\/\/[^\s)]+)\)/g,(_,label,url)=>`<a href="${url}">${label}</a>`);}
function markdown(body){
  const lines=String(body).replace(/\r/g,'').split('\n');const result=[];let list=false,paragraph=[];
  const flush=()=>{if(paragraph.length){result.push(`<p>${inline(paragraph.join(' '))}</p>`);paragraph=[];}if(list){result.push('</ul>');list=false;}};
  for(let i=0;i<lines.length;i++){
    const line=lines[i].trim();
    if(!line){flush();continue;}
    if(line.startsWith('```')){flush();let code=[];while(++i<lines.length&&!lines[i].trim().startsWith('```'))code.push(lines[i]);result.push(`<pre><code>${escape(code.join('\n'))}</code></pre>`);continue;}
    const heading=/^(#{1,6})\s+(.+)$/.exec(line);if(heading){flush();const level=Math.min(4,heading[1].length+1);result.push(`<h${level}>${inline(heading[2])}</h${level}>`);continue;}
    if(line.startsWith('|')&&lines[i+1]&&/^\|[\s:|-]+\|$/.test(lines[i+1].trim())){
      flush();const cells=text=>text.trim().replace(/^\||\|$/g,'').split('|').map(c=>c.trim());
      result.push('<div class="table-scroll"><table><thead><tr>'+cells(line).map(c=>`<th>${inline(c)}</th>`).join('')+'</tr></thead><tbody>');i++;
      while(i+1<lines.length&&lines[i+1].trim().startsWith('|')){i++;result.push('<tr>'+cells(lines[i]).map(c=>`<td>${inline(c)}</td>`).join('')+'</tr>');}
      result.push('</tbody></table></div>');continue;
    }
    const bullet=/^[-*]\s+(.+)$/.exec(line);if(bullet){if(paragraph.length){result.push(`<p>${inline(paragraph.join(' '))}</p>`);paragraph=[];}if(!list){result.push('<ul>');list=true;}result.push(`<li>${inline(bullet[1])}</li>`);continue;}
    if(list){result.push('</ul>');list=false;}paragraph.push(line);
  }
  flush();return result.join('\n');
}
let all=[];const fixture=process.argv.indexOf('--releases-file');
if(fixture>=0)all=JSON.parse(await readFile(path.resolve(process.argv[fixture+1]),'utf8'));
else{
  for(let page=1;page<=20;page++){
    const response=await fetch(`https://api.github.com/repos/Team-HJD-21/pixel-pin/releases?per_page=100&page=${page}`,{headers:{Accept:'application/vnd.github+json',...(process.env.GITHUB_TOKEN?{Authorization:`Bearer ${process.env.GITHUB_TOKEN}`}:{})}});
    if(!response.ok)throw new Error(`Release fetch failed: ${response.status}`);
    const releases=await response.json();all.push(...releases);if(releases.length<100)break;
  }
}
const releases=all.filter(r=>!r.draft&&!r.prerelease&&r.published_at).sort((a,b)=>Date.parse(b.published_at)-Date.parse(a.published_at));
if(!releases.length)throw new Error('A published stable release is required');
const latest=releases[0];const zip=latest.assets.find(a=>/win-x64\.zip$/i.test(a.name));if(!zip)throw new Error('Missing Windows x64 release asset');
const anchor=release=>'release-'+String(release.tag_name).replace(/[^a-zA-Z0-9_-]/g,'-');
const date=value=>new Intl.DateTimeFormat('ko-KR',{year:'numeric',month:'2-digit',day:'2-digit',timeZone:'Asia/Seoul'}).format(new Date(value));
const versionLinks=releases.map(r=>`<a href="#${anchor(r)}">${escape(r.tag_name)}</a>`).join('\n');
const releaseCards=releases.map((r,i)=>`<article class="release-article" id="${anchor(r)}"><div class="release-meta"><span class="version-tag">${escape(r.tag_name)}</span><time datetime="${escape(r.published_at)}">${date(r.published_at)}</time>${i===0?'<span class="latest-badge">LATEST</span>':''}</div><h2>${escape(r.name||r.tag_name)}</h2><div class="release-body">${markdown(r.body||'새 버전이 출시되었습니다.')}</div><div class="release-links"><a href="${safeUrl(r.html_url)}">GitHub에서 보기 ↗</a>${r.assets.find(a=>/win-x64\.zip$/i.test(a.name))?`<a href="${safeUrl(r.assets.find(a=>/win-x64\.zip$/i.test(a.name)).browser_download_url)}">이 버전 다운로드 ↓</a>`:''}</div></article>`).join('\n');
const data={base,siteUrl:escape(siteUrl),home:base+'/',changelog:base+'/changelog/',download:safeUrl(zip.browser_download_url),version:escape(latest.tag_name),releaseName:escape(latest.name||latest.tag_name),size:(zip.size/1048576).toFixed(1),publishedIso:escape(latest.published_at),date:date(latest.published_at),releaseAnchor:anchor(latest),versionLinks,releaseCards,year:'2026'};
function render(template){return template.replace(/\{\{(\w+)\}\}/g,(_,key)=>{if(!(key in data))throw new Error('Unknown template key '+key);return data[key];});}
await mkdir(path.join(out,'assets'),{recursive:true});await mkdir(path.join(out,'changelog'),{recursive:true});
await writeFile(path.join(out,'index.html'),render(await readFile(path.join(root,'site/index.html'),'utf8')));
await writeFile(path.join(out,'changelog/index.html'),render(await readFile(path.join(root,'site/changelog.html'),'utf8')));
for(const name of ['site.css','site.js'])await cp(path.join(root,'site',name),path.join(out,'assets',name));
for(const name of ['app-icon.png','app.ico','preview.png','preview-dark-zh.png','settings.png'])await cp(path.join(root,'assets',name),path.join(out,'assets',name));
await writeFile(path.join(out,'.nojekyll'),'');
await writeFile(path.join(out,'robots.txt'),`User-agent: *\nAllow: /\nSitemap: ${siteUrl}/sitemap.xml\n`);
await writeFile(path.join(out,'sitemap.xml'),`<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc>${escape(siteUrl)}/</loc></url><url><loc>${escape(siteUrl)}/changelog/</loc></url></urlset>`);
await writeFile(path.join(out,'404.html'),`<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>페이지를 찾을 수 없습니다 — Pixel Pin</title><link rel="stylesheet" href="${base}/assets/site.css"><main class="shell section-space"><p class="eyebrow">404</p><h1>픽셀 하나,<br>길을 잃었네요.</h1><p class="section-description">요청한 페이지를 찾을 수 없습니다.</p><a class="button primary" style="margin-top:24px" href="${base}/">Pixel Pin 홈으로</a></main></html>`);
await writeFile(path.join(out,'release-data.json'),JSON.stringify({version:latest.tag_name,publishedAt:latest.published_at,download:zip.browser_download_url,size:zip.size,releases:releases.map(r=>({version:r.tag_name,date:r.published_at,url:r.html_url}))},null,2));
console.log(`Built ${releases.length} release(s), latest ${latest.tag_name}, ${out}`);
