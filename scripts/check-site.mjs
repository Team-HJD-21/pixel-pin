import assert from 'node:assert/strict';
import {readFile,stat} from 'node:fs/promises';
import path from 'node:path';
const root=path.resolve(process.argv[2]||'.pages');
const pages=['index.html','changelog/index.html','en/index.html','en/changelog/index.html','zh-CN/index.html','zh-CN/changelog/index.html','404.html'];
for(const name of pages){
  const html=await readFile(path.join(root,name),'utf8');
  assert(!/\{\{\w+\}\}/.test(html),'Unresolved template token');
  assert(/<html lang="(ko|en|zh-CN)"/.test(html),'Missing document language');
  const ids=[...html.matchAll(/\bid="([^"]+)"/g)].map(m=>m[1]);assert.equal(new Set(ids).size,ids.length,'Duplicate IDs');
  for(const match of html.matchAll(/(?:href|src)="([^"]+)"/g)){
    const value=match[1];if(/^https:|^mailto:/.test(value))continue;
    assert(!value.startsWith('javascript:'),'Unsafe URL');
    const [location,fragment]=value.split('#');
    let relative=location.replace(/^\//,'');
    const base=(process.env.BASE_PATH||'').replace(/^\/|\/$/g,'');if(base&&(relative===base||relative.startsWith(base+'/')))relative=relative.slice(base.length).replace(/^\//,'');
    let target=location?path.resolve(root,relative||'.'):path.join(root,name);if(!location.startsWith('/')&&location)target=path.resolve(path.dirname(path.join(root,name)),location);
    const info=await stat(target);if(info.isDirectory())target=path.join(target,'index.html');
    if(fragment){const body=await readFile(target,'utf8');assert(body.includes(`id="${fragment}"`),`Missing anchor ${value}`);}
  }
}
for(const code of ['ko','en','zh-CN']){
 const prefix=code==='ko'?'':code+'/';
 const html=await readFile(path.join(root,prefix,'index.html'),'utf8');
 assert(html.includes('id="site-language"'),'Missing language picker');
 assert(html.includes(`data-code="${code}" selected`),'Wrong selected language');
 assert(html.includes(`/assets/preview-${code}-light.png`),'Wrong preview language');
 assert(!html.includes('다크 · 简体中文'),'Theme and language must be independent');
 const notes=await readFile(path.join(root,prefix,'changelog/index.html'),'utf8');
 assert(notes.includes(`data-code="${code}" selected`),'Wrong release-notes language');
 assert(notes.includes(`${process.env.BASE_PATH||''}/zh-CN/changelog/`),'Language switch should keep the release-notes page');
 if(code!=='ko'){
  const visible=html.replace(/<option[^>]*>[\s\S]*?<\/option>/g,'').replaceAll('한국어 · English · 简体中文','');
  const korean=visible.match(/[가-힣][가-힣\s·,/.?]+/g);assert(!korean,`Untranslated copy in ${code}: ${korean?.join(' | ')}`);
  assert(!/[가-힣]/.test(notes.replace(/<option[^>]*>[\s\S]*?<\/option>/g,'')),`Untranslated release notes in ${code}`);
 }
 for(const mode of ['light','dark'])for(const kind of ['preview','settings'])await stat(path.join(root,'assets',`${kind}-${code}-${mode}.png`));
}
const release=JSON.parse(await readFile(path.join(root,'release-data.json'),'utf8'));assert(release.releases.length>0);assert.match(release.download,/^https:\/\/github\.com\/Team-HJD-21\/pixel-pin\/releases\/download\//i);
const css=await readFile(path.join(root,'assets/site.css'),'utf8');assert(css.includes('@media(max-width:760px)'));assert(css.includes('prefers-reduced-motion'));
const home=await readFile(path.join(root,'index.html'),'utf8');assert(home.includes('clipboard')===false);assert(home.includes('aria-live="polite"'));
console.log('PASS: 3 language homepages and release notes, localized previews, routes, assets, anchors, release links, responsive/reduced-motion rules.');
