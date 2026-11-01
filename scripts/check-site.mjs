import assert from 'node:assert/strict';
import {readFile,stat} from 'node:fs/promises';
import path from 'node:path';
const root=path.resolve(process.argv[2]||'.pages');
const pages=['index.html','changelog/index.html','404.html'];
for(const name of pages){
  const html=await readFile(path.join(root,name),'utf8');
  assert(!/\{\{\w+\}\}/.test(html),'Unresolved template token');
  assert(/<html lang="ko"/.test(html),'Missing document language');
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
const release=JSON.parse(await readFile(path.join(root,'release-data.json'),'utf8'));assert(release.releases.length>0);assert.match(release.download,/^https:\/\/github\.com\/Team-HJD-21\/pixel-pin\/releases\/download\//i);
const css=await readFile(path.join(root,'assets/site.css'),'utf8');assert(css.includes('@media(max-width:760px)'));assert(css.includes('prefers-reduced-motion'));
const home=await readFile(path.join(root,'index.html'),'utf8');assert(home.includes('clipboard')===false);assert(home.includes('aria-live="polite"'));
console.log('PASS: built routes, assets, anchors, release download, responsive/reduced-motion rules, template completion.');
