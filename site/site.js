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
    feedback.textContent=format==='CMYK'?'CMYK는 인쇄 프로파일을 적용하지 않은 참고값입니다.':format==='HSV'?'HSV는 색상 수치이며 CSS 문법은 아닙니다.':'표시된 색상 코드를 복사해 보세요.';
  }
  document.querySelectorAll('[data-color]').forEach(button=>button.addEventListener('click',()=>{
    color=button.dataset.color;document.querySelectorAll('[data-color]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)));render();
  }));
  document.querySelectorAll('[data-format]').forEach(button=>button.addEventListener('click',()=>{
    format=button.dataset.format;document.querySelectorAll('[data-format]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)));render();
  }));
  document.querySelector('#copy-demo').addEventListener('click',async()=>{
    try {await navigator.clipboard.writeText(demoValue.textContent);feedback.textContent='복사했습니다. 원하는 곳에 붙여넣어 보세요.';}
    catch {const selection=window.getSelection(),range=document.createRange();range.selectNodeContents(demoValue);selection.removeAllRanges();selection.addRange(range);feedback.textContent='코드를 선택했습니다. Ctrl + C 또는 길게 눌러 복사해 주세요.';}
    clearTimeout(reset);reset=setTimeout(render,3500);
  });
  const image=document.querySelector('#app-preview');
  document.querySelectorAll('[data-preview]').forEach(button=>button.addEventListener('click',()=>{
    image.src=new URL(button.dataset.preview,image.src).href;
    image.alt=button.dataset.preview==='preview.png'?'Pixel Pin 라이트 모드 화면 예시':'Pixel Pin 다크 모드·简体中文 화면 예시';
    document.querySelectorAll('[data-preview]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)));
  }));
  render();
}
