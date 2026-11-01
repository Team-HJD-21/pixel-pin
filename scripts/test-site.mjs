import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';import vm from 'node:vm';
class Element{constructor(dataset={}){this.dataset=dataset;this.style={};this.attrs={};this.textContent='';this.handlers={};}addEventListener(type,fn){this.handlers[type]=fn;}setAttribute(key,value){this.attrs[key]=value;}async click(){await this.handlers.click?.();}}
const source=await readFile(new URL('../site/site.js',import.meta.url),'utf8');
for(const language of ['ko','en','zh-CN']){
 const nodes=Object.fromEntries(['demo-value','demo-swatch','demo-feedback','demo-hex','copy-demo','app-preview','site-language','settings-preview'].map(id=>[id,new Element()]));
 const surfaces=[nodes['app-preview'],new Element(),new Element()];
 nodes['app-preview'].src=`https://pixelpin.teamhjd.com/assets/preview-${language}-light.png`;nodes['settings-preview'].src=`https://pixelpin.teamhjd.com/assets/settings-${language}-light.png`;
 nodes['site-language'].options=['ko','en','zh-CN'].map(code=>({dataset:{code},value:code==='ko'?'/':`/${code}/`}));nodes['site-language'].selectedIndex=['ko','en','zh-CN'].indexOf(language);
 const colors=['#547CF0','#202B40','#6DD4B0','#FFBE8B','#BCA4F5'].map(color=>new Element({color}));const formats=['HEX','RGB','HSL','HSV','CMYK'].map(format=>new Element({format}));const previews=['light','dark'].map(preview=>new Element({preview}));let copied,deny=false,selected=false,navigation;
 const stored=new Map([['pixelpin.theme','legacy-site-preference']]);
 const documentRoot={lang:language,dataset:new Proxy({base:''},{set(){throw new Error('Sample controls must not change the website root');}})};
 const context={document:{documentElement:documentRoot,querySelector:s=>s==='.settings-image img'?nodes['settings-preview']:nodes[s.slice(1)],querySelectorAll:s=>s==='[data-color]'?colors:s==='[data-format]'?formats:s==='[data-preview-surface]'?surfaces:previews,createRange:()=>({selectNodeContents:()=>{selected=true;}})},navigator:{clipboard:{writeText:async value=>{if(deny)throw new Error('denied');copied=value;}}},window:{localStorage:{getItem:key=>stored.get(key),setItem:(key,value)=>stored.set(key,value)},location:{pathname:language==='ko'?'/':`/${language}/`,assign:value=>{navigation=value;},replace:value=>{navigation=value;}},getSelection:()=>({removeAllRanges(){},addRange(){}})},URL,setTimeout:()=>0,clearTimeout:()=>{}};
 vm.runInNewContext(source,context);
 assert.equal(nodes['demo-value'].textContent,'#547CF0');await formats[1].click();assert.equal(nodes['demo-value'].textContent,'rgb(84, 124, 240)');
 colors[0].dataset.color='#FF0000';await colors[0].click();await formats[2].click();assert.equal(nodes['demo-value'].textContent,'hsl(0, 100%, 50%)');await formats[3].click();assert.equal(nodes['demo-value'].textContent,'hsv(0, 100%, 100%)');await formats[4].click();assert.equal(nodes['demo-value'].textContent,'cmyk(0%, 100%, 100%, 0%)');
 colors[0].dataset.color='#000000';await colors[0].click();assert.equal(nodes['demo-value'].textContent,'cmyk(0%, 0%, 0%, 100%)');assert.equal(nodes['demo-swatch'].style.color,'#fff');
 colors[0].dataset.color='#FFFFFF';await colors[0].click();assert.equal(nodes['demo-value'].textContent,'cmyk(0%, 0%, 0%, 0%)');assert.equal(nodes['demo-swatch'].style.color,'#000');await nodes['copy-demo'].click();assert.equal(copied,nodes['demo-value'].textContent);
 assert(nodes['demo-feedback'].textContent.startsWith(language==='en'?'Copied.':language==='zh-CN'?'已复制':'복사했습니다'));
 deny=true;await nodes['copy-demo'].click();assert(selected);assert(nodes['demo-feedback'].textContent.startsWith(language==='en'?'The code is selected.':language==='zh-CN'?'已选中':'코드를 선택했습니다'));
 const colorBefore=nodes['demo-value'].textContent;
 await previews[1].click();assert.equal(nodes['app-preview'].src,`https://pixelpin.teamhjd.com/assets/preview-${language}-dark.png`);assert.equal(nodes['settings-preview'].src,`https://pixelpin.teamhjd.com/assets/settings-${language}-dark.png`);assert.equal(documentRoot.lang,language);assert.equal(documentRoot.dataset.theme,undefined);assert(surfaces.every(surface=>surface.dataset.previewTheme==='dark'));assert.equal(stored.get('pixelpin.previewTheme'),'dark');assert.equal(stored.get('pixelpin.theme'),'legacy-site-preference');assert.equal(nodes['demo-value'].textContent,colorBefore);
 await previews[0].click();assert(surfaces.every(surface=>surface.dataset.previewTheme==='light'));assert.equal(nodes['app-preview'].src,`https://pixelpin.teamhjd.com/assets/preview-${language}-light.png`);assert.equal(documentRoot.dataset.theme,undefined);
 nodes['site-language'].selectedIndex=2;await nodes['site-language'].handlers.change();assert.equal(navigation,'/zh-CN/');assert.equal(stored.get('pixelpin.language'),'zh-CN');
}
console.log('PASS: all 3 languages, theme changes limited to 3 samples, website root unchanged, color values preserved, language navigation, clipboard success/failure.');
