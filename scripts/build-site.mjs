import { readFile, writeFile, mkdir, cp, readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {languages,tr,translateMarkup} from '../site/translations.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const out=path.join(root,'.pages');
const cssSource=await readFile(path.join(root,'site/site.css'));
const jsSource=await readFile(path.join(root,'site/site.js'));
const cssName=`site.${createHash('sha256').update(cssSource).digest('hex').slice(0,12)}.css`;
const jsName=`site.${createHash('sha256').update(jsSource).digest('hex').slice(0,12)}.js`;
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
const prefix=language=>language==='ko'?'':`/${language}`;
const localizedName=(release,language)=>language==='zh-CN'&&release.tag_name==='v1.1.0'?'Pixel Pin v1.1.0 — 按你的习惯来':release.name||release.tag_name;
function render(template,data){return template.replace(/\{\{(\w+)\}\}/g,(_,key)=>{if(!(key in data))throw new Error('Unknown template key '+key);return data[key];});}
await mkdir(path.join(out,'assets'),{recursive:true});
const homeTemplate=await readFile(path.join(root,'site/index.html'),'utf8');
const notesTemplate=await readFile(path.join(root,'site/changelog.html'),'utf8');
const sitemap=[];
for(const language of languages){
 const code=language.code;
 const date=value=>new Intl.DateTimeFormat(language.locale,{year:'numeric',month:code==='ko'?'2-digit':'short',day:'numeric',timeZone:'Asia/Seoul'}).format(new Date(value));
 const versionLinks=releases.map(r=>`<a href="#${anchor(r)}">${escape(r.tag_name)}</a>`).join('\n');
 const releaseCards=(await Promise.all(releases.map(async(r,i)=>{
  let body=r.body||tr('새 버전이 출시되었습니다.',code),fallback=false;
  if(code!=='ko'){
   try{body=await readFile(path.join(root,'site/releases',`${String(r.tag_name).replace(/[^a-zA-Z0-9_.-]/g,'_')}.${code}.md`),'utf8');}
   catch(error){if(error.code!=='ENOENT')throw error;fallback=true;}
  }
  const asset=r.assets.find(a=>/win-x64\.zip$/i.test(a.name));
  return `<article class="release-article" id="${anchor(r)}"><div class="release-meta"><span class="version-tag">${escape(r.tag_name)}</span><time datetime="${escape(r.published_at)}">${date(r.published_at)}</time>${i===0?'<span class="latest-badge">'+(code==='zh-CN'?'最新版本':'LATEST')+'</span>':''}</div><h2>${escape(localizedName(r,code))}</h2>${fallback?'<p class="fine-print">'+tr('원문 패치노트',code)+'</p>':''}<div class="release-body">${markdown(body)}</div><div class="release-links"><a href="${safeUrl(r.html_url)}">${tr('GitHub에서 보기',code)}</a>${asset?`<a href="${safeUrl(asset.browser_download_url)}">${tr('이 버전 다운로드',code)}</a>`:''}</div></article>`;
 }))).join('\n');
 for(const page of ['home','changelog']){
  const suffix=page==='home'?'/':'/changelog/';
  const canonical=siteUrl+prefix(code)+suffix;
  const data={base,language:code,siteUrl:escape(siteUrl),canonical:escape(canonical),home:base+prefix(code)+'/',changelog:base+prefix(code)+'/changelog/',download:safeUrl(zip.browser_download_url),version:escape(latest.tag_name),releaseName:escape(localizedName(latest,code)),size:(zip.size/1048576).toFixed(1),publishedIso:escape(latest.published_at),date:date(latest.published_at),releaseAnchor:anchor(latest),versionLinks,releaseCards,year:'2026',styleUrl:base+'/assets/'+cssName,scriptUrl:base+'/assets/'+jsName,previewImage:base+`/assets/preview-${code}-light.png`,settingsImage:base+`/assets/settings-${code}-light.png`};
  data.languageName=language.name;data.languageControlLabel=tr('언어 선택',code)+' · '+language.name;
  data.languageOptions=languages.map(item=>`<a class="language-option" href="${base+prefix(item.code)+suffix}" lang="${item.code}" hreflang="${item.code}" data-language="${item.code}"${item.code===code?' aria-current="page"':''}>${item.name}</a>`).join('');
  data.alternateLinks=languages.map(item=>`<link rel="alternate" hreflang="${item.code}" href="${siteUrl+prefix(item.code)+suffix}">`).join('')+`<link rel="alternate" hreflang="x-default" href="${siteUrl+suffix}">`;
  const directory=path.join(out,prefix(code),page==='home'?'':'changelog');await mkdir(directory,{recursive:true});
  await writeFile(path.join(directory,'index.html'),render(translateMarkup(page==='home'?homeTemplate:notesTemplate,code),data));
  sitemap.push(canonical);
 }
}
for(const name of ['site.css','site.js'])await cp(path.join(root,'site',name),path.join(out,'assets',name));
await writeFile(path.join(out,'assets',cssName),cssSource);await writeFile(path.join(out,'assets',jsName),jsSource);
for(const name of await readdir(path.join(root,'assets')))if(name.endsWith('.png')||name==='app.ico')await cp(path.join(root,'assets',name),path.join(out,'assets',name));
await writeFile(path.join(out,'.nojekyll'),'');
await writeFile(path.join(out,'robots.txt'),`User-agent: *\nAllow: /\nSitemap: ${siteUrl}/sitemap.xml\n`);
await writeFile(path.join(out,'sitemap.xml'),`<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${sitemap.map(url=>`<url><loc>${escape(url)}</loc></url>`).join('')}</urlset>`);
await writeFile(path.join(out,'404.html'),`<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>페이지를 찾을 수 없습니다 — Pixel Pin</title><link rel="stylesheet" href="${base}/assets/${cssName}"><main class="shell section-space"><p class="eyebrow">404</p><h1>픽셀 하나,<br>길을 잃었네요.</h1><p class="section-description">요청한 페이지를 찾을 수 없습니다.</p><a class="button primary" style="margin-top:24px" href="${base}/">Pixel Pin 홈으로</a></main></html>`);
await writeFile(path.join(out,'release-data.json'),JSON.stringify({version:latest.tag_name,publishedAt:latest.published_at,download:zip.browser_download_url,size:zip.size,releases:releases.map(r=>({version:r.tag_name,date:r.published_at,url:r.html_url}))},null,2));
console.log(`Built 3 languages × 2 pages, ${releases.length} release(s), latest ${latest.tag_name}, ${out}`);
