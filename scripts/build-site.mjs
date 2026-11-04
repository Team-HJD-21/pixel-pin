import { readFile, writeFile, mkdir, cp, readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {languages,tr,translateMarkup} from '../site/translations.mjs';
import {policies,policyUi,policyDate} from '../site/policies.mjs';
import {selectPublicReleases} from './release-selection.mjs';

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
const {stable:releases,windows:windowsRelease,windowsAsset:zip,mac:macRelease,macAsset}=selectPublicReleases(all);
const latest=releases[0];
const anchor=release=>'release-'+String(release.tag_name).replace(/[^a-zA-Z0-9_-]/g,'-');
const prefix=language=>language==='ko'?'':`/${language}`;
const localizedName=(release,language)=>release.tag_name==='v1.2.1'?tr('Pixel Pin v1.2.1 — macOS 정식 출시',language):language==='zh-CN'&&release.tag_name==='v1.1.0'?'Pixel Pin v1.1.0 — 按你的习惯来':release.name||release.tag_name;
function render(template,data){return template.replace(/\{\{(\w+)\}\}/g,(_,key)=>{if(!(key in data))throw new Error('Unknown template key '+key);return data[key];});}
await mkdir(path.join(out,'assets'),{recursive:true});
const homeTemplate=await readFile(path.join(root,'site/index.html'),'utf8');
const notesTemplate=await readFile(path.join(root,'site/changelog.html'),'utf8');
const legalTemplate=homeTemplate.replace(/<title>[\s\S]*?<\/title>/,'<title>{{policyTitle}} — Pixel Pin</title>').replace(/<meta name="description" content="[^"]*">/,'<meta name="description" content="{{policyDescription}}">').replace(/<main\b[\s\S]*?<\/main>/,'<main id="main" class="shell legal-main"><header class="legal-heading"><p class="eyebrow">PIXEL PIN / {{policyEyebrow}}</p><h1>{{policyTitle}}</h1><p>{{policySummary}}</p><p class="policy-date">{{policyUpdated}} <time datetime="'+policyDate+'">'+policyDate+'</time></p></header><div class="legal-layout"><nav class="legal-nav" aria-label="{{policyTitle}}">{{policyNavigation}}</nav><article class="legal-copy">{{policyBody}}<a class="text-link" href="{{home}}">{{policyBack}}</a></article></div></main>');
const sitemap=[];
let defaultFooter='';
for(const language of languages){
 const code=language.code;
 const date=value=>new Intl.DateTimeFormat(language.locale,{year:'numeric',month:code==='ko'?'2-digit':'short',day:'numeric',timeZone:'Asia/Seoul'}).format(new Date(value));
 const versionLinks=releases.map(r=>`<a href="#${anchor(r)}">${escape(r.tag_name)}</a>`).join('\n');
 const releaseCards=(await Promise.all(releases.map(async(r,i)=>{
  let body=r.body||tr('새 버전이 출시되었습니다.',code),fallback=false;
  {
   try{body=await readFile(path.join(root,'site/releases',`${String(r.tag_name).replace(/[^a-zA-Z0-9_.-]/g,'_')}.${code}.md`),'utf8');}
   catch(error){if(error.code!=='ENOENT')throw error;fallback=code!=='ko';}
  }
  const asset=r.assets.find(a=>/win-x64\.zip$/i.test(a.name))||r.assets.find(a=>/macos-universal\.dmg$/i.test(a.name))||r.assets.find(a=>/macos-universal\.zip$/i.test(a.name));
  return `<article class="release-article" id="${anchor(r)}"><div class="release-meta"><span class="version-tag">${escape(r.tag_name)}</span><time datetime="${escape(r.published_at)}">${date(r.published_at)}</time>${i===0?'<span class="latest-badge">'+(code==='zh-CN'?'最新版本':'LATEST')+'</span>':''}</div><h2>${escape(localizedName(r,code))}</h2>${fallback?'<p class="fine-print">'+tr('원문 패치노트',code)+'</p>':''}<div class="release-body">${markdown(body)}</div><div class="release-links"><a href="${safeUrl(r.html_url)}">${tr('GitHub에서 보기',code)}</a>${asset?`<a href="${safeUrl(asset.browser_download_url)}">${tr('이 버전 다운로드',code)}</a>`:''}</div></article>`;
 }))).join('\n');
 for(const page of ['home','changelog','terms','privacy','support']){
  const suffix=page==='home'?'/':`/${page}/`;
  const canonical=siteUrl+prefix(code)+suffix;
  const data={base,language:code,siteUrl:escape(siteUrl),canonical:escape(canonical),home:base+prefix(code)+'/',changelog:base+prefix(code)+'/changelog/',download:safeUrl(zip.browser_download_url),macDownload:safeUrl(macAsset?.browser_download_url||'https://github.com/Team-HJD-21/pixel-pin/releases'),macVersion:escape(macRelease?.tag_name||tr('준비 중',code)),windowsVersion:escape(windowsRelease.tag_name),version:escape(latest.tag_name),releaseName:escape(localizedName(latest,code)),size:(zip.size/1048576).toFixed(1),publishedIso:escape(latest.published_at),date:date(latest.published_at),releaseAnchor:anchor(latest),versionLinks,releaseCards,year:'2026',styleUrl:base+'/assets/'+cssName,scriptUrl:base+'/assets/'+jsName,previewImage:base+`/assets/preview-${code}-light.png`,settingsImage:base+`/assets/settings-${code}-light.png`};
  data.languageName=language.name;data.languageControlLabel=tr('언어 선택',code)+' · '+language.name;
  data.languageOptions=languages.map(item=>`<a class="language-option" href="${base+prefix(item.code)+suffix}" lang="${item.code}" hreflang="${item.code}" data-language="${item.code}"${item.code===code?' aria-current="page"':''}>${item.name}</a>`).join('');
  data.alternateLinks=languages.map(item=>`<link rel="alternate" hreflang="${item.code}" href="${siteUrl+prefix(item.code)+suffix}">`).join('')+`<link rel="alternate" hreflang="x-default" href="${siteUrl+suffix}">`;
  const ui=policyUi[code], policy=policies[code][page];
  const relatedLabel={ko:'관련 사이트',en:'Related sites','zh-CN':'相关网站'}[code];
  const newTabLabel={ko:'새 탭에서 열림',en:'opens in a new tab','zh-CN':'在新标签页中打开'}[code];
  const relatedSites=[['TeamHJD','teamhjd.com'],['Threadle','threadle.teamhjd.com'],['TeamHJD Docs','docs.teamhjd.com'],['Test Launcher','testlauncher.teamhjd.com']];
  const relatedMenu=`<details class="related-sites" id="related-sites"><summary>${relatedLabel}</summary><nav class="related-sites-panel" aria-label="${relatedLabel}">${relatedSites.map(([name,domain])=>`<a href="https://${domain}/" target="_blank" rel="noopener noreferrer" aria-label="${name} · ${newTabLabel}"><span>${name}</span><span class="related-site-domain">${domain}</span></a>`).join('')}</nav></details>`;
  if(policy){
   data.policyTitle=escape(ui[page]);data.policyDescription=escape(policy.description);data.policySummary=escape(policy.summary);data.policyUpdated=escape(ui.updated);data.policyBack=escape(ui.back);data.policyEyebrow=escape(ui.intro);
   data.policyNavigation=policy.sections.map(([title],i)=>`<a href="#section-${i+1}">${escape(title)}</a>`).join('');
   data.policyBody=policy.sections.map(([title,body,links],i)=>`<section id="section-${i+1}"><h2>${escape(title)}</h2><p>${escape(body)}</p>${links?`<p class="policy-sources">${links}</p>`:''}</section>`).join('');
  }
  const companyLabels={ko:['상호','대표자','사업자등록번호','통신판매업 신고번호','사업장 주소','문의'],en:['Registered business','Representative','Business registration','Online sales registration','Business address','Contact'],'zh-CN':['经营主体','代表人','营业登记编号','网络销售登记编号','营业地址','联系']}[code];
  const companyValues=['팀 에이치제이디(TeamHJD)','황재동','622-10-17519','2026-수원영통-1221호','경기도 수원시 영통구 태장로 71번길 19'];
  const companyBlock=`<section class="footer-company" aria-label="TeamHJD"><a class="company-logo" href="https://teamhjd.com/"><img src="${base}/assets/teamhjd-logo.png" alt="TeamHJD" width="220" height="88"></a><dl>${companyValues.map((value,i)=>`<div><dt>${companyLabels[i]}</dt><dd>${value}</dd></div>`).join('')}<div><dt>${companyLabels[5]}</dt><dd><a href="https://teamhjd.com/privacy/index.html#email">support@teamhjd.com</a></dd></div></dl></section>`;
  const footer=`<footer class="site-footer shell"><a class="brand" href="${data.home}"><img src="${base}/assets/app-icon.png" width="25" height="25" alt=""><span>Pixel Pin</span></a><div class="footer-links"><a href="${base+prefix(code)}/terms/">${ui.terms}</a><a href="${base+prefix(code)}/privacy/">${ui.privacy}</a><a href="${base+prefix(code)}/support/">${ui.support}</a><a href="https://github.com/Team-HJD-21/pixel-pin/issues">${ui.contact}</a></div>${companyBlock}<div class="footer-preferences"><button id="reset-site-preferences" type="button">${ui.reset}</button>${relatedMenu}<span id="preferences-feedback" role="status" aria-live="polite"></span></div><p class="footer-copyright">© 2026 TeamHJD. All rights reserved.</p></footer>`;
  if(code==='ko'&&page==='home')defaultFooter=footer;
  const template=page==='home'?homeTemplate:page==='changelog'?notesTemplate:legalTemplate.replace(/<meta property="og:title" content="[^"]*">/,'<meta property="og:title" content="{{policyTitle}} — Pixel Pin">').replace(/<meta property="og:description" content="[^"]*">/,'<meta property="og:description" content="{{policyDescription}}">');
  const directory=path.join(out,prefix(code),page==='home'?'':page);await mkdir(directory,{recursive:true});
  await writeFile(path.join(directory,'index.html'),render(translateMarkup(template,code),data).replace(/<footer\b[\s\S]*?<\/footer>/,footer));
  sitemap.push(canonical);
 }
}
for(const name of ['site.css','site.js'])await cp(path.join(root,'site',name),path.join(out,'assets',name));
await writeFile(path.join(out,'assets',cssName),cssSource);await writeFile(path.join(out,'assets',jsName),jsSource);
for(const name of await readdir(path.join(root,'assets')))if(name.endsWith('.png')||name==='app.ico')await cp(path.join(root,'assets',name),path.join(out,'assets',name));
await writeFile(path.join(out,'.nojekyll'),'');
await writeFile(path.join(out,'robots.txt'),`User-agent: *\nAllow: /\nSitemap: ${siteUrl}/sitemap.xml\n`);
await writeFile(path.join(out,'sitemap.xml'),`<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${sitemap.map(url=>`<url><loc>${escape(url)}</loc></url>`).join('')}</urlset>`);
await writeFile(path.join(out,'404.html'),`<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>페이지를 찾을 수 없습니다 — Pixel Pin</title><link rel="stylesheet" href="${base}/assets/${cssName}"><main class="shell section-space"><p class="eyebrow">404</p><h1>픽셀 하나,<br>길을 잃었네요.</h1><p class="section-description">요청한 페이지를 찾을 수 없습니다.</p><a class="button primary" style="margin-top:24px" href="${base}/">Pixel Pin 홈으로</a></main>${defaultFooter}<script src="${base}/assets/${jsName}" defer></script></html>`);
await writeFile(path.join(out,'release-data.json'),JSON.stringify({version:windowsRelease.tag_name,publishedAt:windowsRelease.published_at,download:zip.browser_download_url,size:zip.size,mac:macRelease?{version:macRelease.tag_name,download:macAsset.browser_download_url,size:macAsset.size}:null,featuredVersion:latest.tag_name,releases:releases.map(r=>({version:r.tag_name,date:r.published_at,url:r.html_url}))},null,2));
console.log(`Built 3 languages × 5 pages, ${releases.length} release(s), latest ${latest.tag_name}, ${out}`);
