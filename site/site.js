const pageRoot = document.documentElement;
const pageLanguage = pageRoot?.lang || 'ko';
const copyText = ({
  ko:{ready:'표시된 색상 코드를 복사해 보세요.',cmyk:'CMYK는 인쇄 프로파일을 적용하지 않은 참고값입니다.',hsv:'HSV는 색상 수치이며 CSS 문법은 아닙니다.',copied:'복사했습니다. 원하는 곳에 붙여넣어 보세요.',failed:'코드를 선택했습니다. Ctrl + C 또는 길게 눌러 복사해 주세요.'},
  en:{ready:'Try copying the color code.',cmyk:'Reference CMYK only. No print profile is applied.',hsv:'HSV values are not standard CSS syntax.',copied:'Copied. Paste it wherever you need it.',failed:'The code is selected. Press Ctrl + C, or touch and hold to copy.'},
  'zh-CN':{ready:'试着复制这段颜色代码。',cmyk:'CMYK 仅供参考，未应用印刷配置文件。',hsv:'HSV 数值并非标准 CSS 语法。',copied:'已复制，可以粘贴到需要的地方了。',failed:'已选中代码，请按 Ctrl + C，或长按复制。'}
})[pageLanguage] || null;
const demoValue = document.querySelector('#demo-value');
if (demoValue) {
  let color = '#547CF0'; let format = 'HEX'; let reset;
  const swatch = document.querySelector('#demo-swatch');
  const feedback = document.querySelector('#demo-feedback');
  function values(hex, type) {
    const rgb = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16));
    if (type === 'HEX') return hex;
    if (type === 'RGB') return `rgb(${rgb.join(', ')})`;
    const [r, g, b] = rgb.map(c => c / 255), max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
    const n = value => String(Math.round(value * 10) / 10);
    if (type === 'CMYK') return `cmyk(${[max ? (max-r)/max : 0, max ? (max-g)/max : 0, max ? (max-b)/max : 0, 1-max].map(v => `${n(v*100)}%`).join(', ')})`;
    let h = !d ? 0 : max === r ? 60 * (((g-b)/d)%6) : max === g ? 60*((b-r)/d+2) : 60*((r-g)/d+4);
    h = (h+360)%360; const l=(max+min)/2;
    const s=type==='HSV' ? (max ? d/max : 0) : (d ? d/(1-Math.abs(2*l-1)) : 0);
    return `${type.toLowerCase()}(${n(h)}, ${n(s*100)}%, ${n((type==='HSV'?max:l)*100)}%)`;
  }
  function render() {
    demoValue.textContent=values(color,format); document.querySelector('#demo-hex').textContent=color;
    swatch.style.backgroundColor=color;
    const linear=[1,3,5].map(i=>parseInt(color.slice(i,i+2),16)/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4);
    swatch.style.color=linear[0]*.2126+linear[1]*.7152+linear[2]*.0722>.179?'#000':'#fff';
    feedback.textContent=format==='CMYK'?copyText.cmyk:format==='HSV'?copyText.hsv:copyText.ready;
  }
  document.querySelectorAll('[data-color]').forEach(button=>button.addEventListener('click',()=>{
    color=button.dataset.color;document.querySelectorAll('[data-color]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)));render();
  }));
  document.querySelectorAll('[data-format]').forEach(button=>button.addEventListener('click',()=>{
    format=button.dataset.format;document.querySelectorAll('[data-format]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)));render();
  }));
  document.querySelector('#copy-demo').addEventListener('click',async()=>{
    try {await navigator.clipboard.writeText(demoValue.textContent);feedback.textContent=copyText.copied;}
    catch {const selection=window.getSelection(),range=document.createRange();range.selectNodeContents(demoValue);selection.removeAllRanges();selection.addRange(range);feedback.textContent=copyText.failed;}
    clearTimeout(reset);reset=setTimeout(render,3500);
  });
  render();
}

function preference(key,value){try{if(value===undefined)return window.localStorage.getItem(key);window.localStorage.setItem(key,value);}catch{}return null;}
const languagePicker=document.querySelector('#site-language');
if(languagePicker){
  languagePicker.addEventListener('change',()=>{const option=languagePicker.options[languagePicker.selectedIndex];preference('pixelpin.language',option.dataset.code);window.location.assign(option.value);});
  const remembered=preference('pixelpin.language');
  if(pageLanguage==='ko'&&window.location.pathname===(pageRoot.dataset.base||'')+'/'&&remembered&&remembered!=='ko'){
    const option=[...languagePicker.options].find(item=>item.dataset.code===remembered);if(option)window.location.replace(option.value);
  }
}
const appearanceButtons=document.querySelectorAll('[data-preview]');
const previewImage=document.querySelector('#app-preview');
const settingsImage=document.querySelector('.settings-image img');
function applyAppearance(mode,save=false){
  if(pageRoot)pageRoot.dataset.theme=mode;
  if(save)preference('pixelpin.theme',mode);
  if(previewImage){
    previewImage.src=new URL(`preview-${pageLanguage}-${mode}.png`,previewImage.src).href;
    previewImage.alt=pageLanguage==='en'?`Pixel Pin ${mode} appearance example`:pageLanguage==='zh-CN'?`Pixel Pin ${mode==='dark'?'深色':'浅色'}模式示例`:`Pixel Pin ${mode==='dark'?'다크':'라이트'} 모드 화면 예시`;
  }
  if(settingsImage)settingsImage.src=new URL(`settings-${pageLanguage}-${mode}.png`,settingsImage.src).href;
  appearanceButtons.forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.preview===mode)));
}
const systemAppearance=window.matchMedia?.('(prefers-color-scheme: dark)');
const savedAppearance=preference('pixelpin.theme');
applyAppearance(savedAppearance==='light'||savedAppearance==='dark'?savedAppearance:systemAppearance?.matches?'dark':'light');
appearanceButtons.forEach(button=>button.addEventListener('click',()=>applyAppearance(button.dataset.preview,true)));
systemAppearance?.addEventListener('change',event=>{if(!preference('pixelpin.theme'))applyAppearance(event.matches?'dark':'light');});
