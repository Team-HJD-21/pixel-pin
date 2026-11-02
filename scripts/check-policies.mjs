import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {policies,policyUi} from '../site/policies.mjs';
const root=new URL('../',import.meta.url);
for(const code of ['ko','en','zh-CN']){
 for(const page of ['terms','privacy','support']){
  const html=await readFile(new URL(`.pages/${code==='ko'?'':code+'/'}${page}/index.html`,root),'utf8');
  assert(html.includes(`<h1>${policyUi[code][page].replaceAll('&','&amp;')}</h1>`));
  assert.equal((html.match(/<section id="section-/g)||[]).length,policies[code][page].sections.length);
  for(const other of ['ko','en','zh-CN'])assert(html.includes(`href="${process.env.BASE_PATH||''}${other==='ko'?'':'/'+other}/${page}/"`),'Language switch loses policy route');
  assert(!/lemonsqueezy\.com\/checkout|lemon\.js|data-lemonsqueezy/.test(html),'Unconfigured checkout must remain absent');
 }
 const privacy=policies[code].privacy.sections.map(section=>section.join(' ')).join(' ');
 for(const value of ['pixelpin.language','pixelpin.previewTheme','GitHub','Lemon Squeezy','history.json','settings.json'])assert(privacy.includes(value));
}
const css=await readFile(new URL('site/site.css',root),'utf8');
function luminance(hex){const c=hex.replace('#','');const rgb=(c.length===3?[...c].map(x=>x+x):c.match(/../g)).map(x=>parseInt(x,16)/255).map(x=>x<=.04045?x/12.92:((x+.055)/1.055)**2.4);return .2126*rgb[0]+.7152*rgb[1]+.0722*rgb[2];}
function check(a,b,label){let x=luminance(a),y=luminance(b),ratio=(Math.max(x,y)+.05)/(Math.min(x,y)+.05);assert(ratio>=4.5,`${label}: ${a} on ${b} is ${ratio}`);}
for(const block of css.matchAll(/(?:^|[{}])(?:\s*:root|\s*\[data-preview-surface\]\[data-preview-theme=(?:light|dark)\])\{([^}]+)/g)){
 const vars=Object.fromEntries([...block[1].matchAll(/--(\w+):(#[a-f0-9]+)/gi)].map(m=>[m[1],m[2]]));
 for(const text of ['ink','muted','blue'])for(const bg of ['canvas','surface','soft','tint'])check(vars[text],vars[bg],`site ${text}/${bg}`);
}
check('#fff','#4269ed','download button');
const theme=await readFile(new URL('ThemeManager.cs',root),'utf8');
const palette=Object.fromEntries([...theme.matchAll(/\["(\w+)", "(#[A-F0-9]+)", "(#[A-F0-9]+)"\]/g)].map(m=>[m[1],[m[2],m[3]]]));
for(let i=0;i<2;i++)for(const text of ['Ink','Muted','Footer','Accent'])for(const bg of ['Canvas','Surface','Inset','Selected'])check(palette[text][i],palette[bg][i],`app ${i} ${text}/${bg}`);
console.log('PASS: all 9 policy pages, same-page language routes, payment disabled, and normal-text palette contrast >=4.5:1.');
