
'use strict';
const DATA=JSON.parse(document.getElementById('dataset').textContent);
const $=id=>document.getElementById(id);
const LANG=new Map(DATA.languages.map(l=>[l.id,l]));
const FN={commercial:['商业','#b38a29'],infrastructure:['基础设施','#387f88'],regulatory:['规约／行为提醒','#b84f38'],interpersonal:['交际','#796aa0'],mixed:['复合用途','#bb718b'],other:['其他／待判定','#92968b']};
const COUNT={1:['1 种','#779486'],2:['2 种','#3e7e86'],3:['3 种','#b58a35'],4:['4 种及以上','#b84f38'],unknown:['未确定','#aaa99c']};
const state={scope:'reviewed',roles:'all',day:'all',fn:'all',query:'',mode:'language',language:'ja',point:null,page:0,selected:null};
const localImages=new Map();
const H=Object.fromEntries(DATA.headers.map((h,i)=>[h,i]));
const raw=(r,h)=>r.raw[H[h]]||'';
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const fmt=n=>n.toLocaleString('zh-CN');
const pct=(n,d)=>d?(n/d*100).toFixed(1)+'%':'—';
const getRoles=()=>state.roles==='main'?['main']:state.roles==='info'?['main','aux']:['main','aux','decor'];
const parseUnknown=s=>String(s).replace(/[（(][^）)]*[）)]/g,'').split(/[/／,，、;；|]/).map(t=>t.trim()).filter(t=>t&&!['—','-','–','无','無'].includes(t)&&!DATA.languages.some(l=>l.source===t)&&t!=='中国語簡体字');
for(const r of DATA.records){r.search=r.raw.join(' ').toLocaleLowerCase();r.unknownRoles={main:parseUnknown(raw(r,'主要言語')),aux:parseUnknown(raw(r,'補助言語')),decor:parseUnknown(raw(r,'装飾の言語'))};}
const coordinates=DATA.records.filter(r=>Number.isFinite(r.lat)&&Number.isFinite(r.lon));
const minLon=Math.min(...coordinates.map(r=>r.lon)),maxLon=Math.max(...coordinates.map(r=>r.lon));
const minLat=Math.min(...coordinates.map(r=>r.lat)),maxLat=Math.max(...coordinates.map(r=>r.lat));
const latMid=(minLat+maxLat)/2,lonMid=(minLon+maxLon)/2;
const mx=111320*Math.cos(latMid*Math.PI/180),my=111320;
const spanX=(maxLon-minLon)*mx,spanY=(maxLat-minLat)*my;
for(const r of DATA.records){if(Number.isFinite(r.lat)&&Number.isFinite(r.lon)){r.x=(r.lon-minLon)*mx;r.y=(r.lat-minLat)*my;r.bin=Math.floor(r.x/5)+','+Math.floor(r.y/5);}else r.bin=null;}
const group=rows=>{const m=new Map();for(const r of rows){if(!r.bin)continue;if(!m.has(r.bin)){const [gx,gy]=r.bin.split(',').map(Number);m.set(r.bin,{key:r.bin,x:gx*5+2.5,y:gy*5+2.5,rows:[]});}m.get(r.bin).rows.push(r);}return [...m.values()];};
const allBins=group(DATA.records),maxBin=Math.max(...allBins.map(b=>b.rows.length));
let context={rows:[],bins:[],listed:[],active:[],counts:new Map()};
function prepare(r){const roles=getRoles();r.currentLangs=[...new Set(roles.flatMap(k=>r.roles[k]))].sort((a,b)=>DATA.languages.findIndex(l=>l.id===a)-DATA.languages.findIndex(l=>l.id===b));r.exact=r.currentLangs.length>0&&!roles.some(k=>r.unknownRoles[k].length);return r;}
function languageMatch(r,key){if(key==='all')return true;if(key==='jaOnly')return r.exact&&r.currentLangs.length===1&&r.currentLangs[0]==='ja';if(key==='nonJa')return r.currentLangs.some(l=>l!=='ja');return r.currentLangs.includes(key);}
function languageName(key){return key==='all'?'所有语言':key==='jaOnly'?'仅日语':key==='nonJa'?'含日语以外语言':LANG.get(key)?.name||key;}
function languageColor(key){return LANG.get(key)?.color||'#3f7864';}
function countKey(r){return r.exact?String(Math.min(4,r.currentLangs.length)):'unknown';}
function filterRows(){return DATA.records.filter(r=>(state.scope==='all'||r.text)&&(state.scope!=='reviewed'||['human-reviewed','final'].includes(r.status))&&(state.day==='all'||r.date===state.day)&&(state.fn==='all'||r.fn===state.fn)&&(!state.query||r.search.includes(state.query))).map(prepare);}
function update(){
 const rows=filterRows(),exact=rows.filter(r=>r.exact),counts=new Map(DATA.languages.map(l=>[l.id,rows.filter(r=>r.currentLangs.includes(l.id)).length]));
 const active=state.mode==='language'?rows.filter(r=>languageMatch(r,state.language)):rows;
 const bins=group(rows);if(state.point&&!bins.some(b=>b.key===state.point))state.point=null;
 const listed=state.point?active.filter(r=>r.bin===state.point):active;
 context={rows,bins,listed,active,counts};
 state.page=Math.max(0,Math.min(state.page,Math.ceil(listed.length/12)-1));
 if(!listed.some(r=>r.i===state.selected))state.selected=(listed.find(r=>imageFor(r))||listed[0])?.i??null;
 $('statRecords').textContent=fmt(rows.length);$('statLanguages').textContent=[...counts.values()].filter(v=>v>0).length;
 $('statMulti').textContent=pct(exact.filter(r=>r.currentLangs.length>1).length,exact.length);
 $('statMulti').title=exact.filter(r=>r.currentLangs.length>1).length+' / '+exact.length;
 const invalid=rows.filter(r=>!r.bin).length;
 $('scopeSummary').textContent=`数据共 ${fmt(DATA.records.length)} 条 · 当前 ${fmt(rows.length)} 条 · 语言数量可确定 ${fmt(exact.length)} 条 · 未确定 ${fmt(rows.length-exact.length)} 条${invalid?' · 无有效坐标 '+invalid+' 条':''}`;
 $('mapTitle').textContent={language:'01 / 语言在哪里',count:'02 / 每条标识有几种语言',function:'03 / 文字在做什么'}[state.mode];
 $('languageControl').hidden=state.mode!=='language';
 $('mapContext').textContent=state.mode==='language'?`${languageName(state.language)} ${fmt(active.length)} 条 / 当前 ${fmt(rows.length)} 条`:`当前 ${fmt(rows.length)} 条记录`;
 document.querySelectorAll('[data-mode]').forEach(b=>{b.classList.toggle('active',b.dataset.mode===state.mode);b.setAttribute('aria-selected',String(b.dataset.mode===state.mode));});
 renderMap();renderMini();renderCharts();renderRecords();renderDetail();
}
function geometry(w=1100,h=350,pad=55){const s=Math.min((w-2*pad)/(spanX+10),(h-(h<150?18:95))/(spanY+10));return {s,px:x=>w/2+(x-spanX/2)*s,py:y=>h/2+3-(y-spanY/2)*s};}
function circleRadius(n){return Math.sqrt(n)*1.95;}
function pie(x,y,r,parts){const total=parts.reduce((s,p)=>s+p.n,0);let angle=-Math.PI/2;return parts.filter(p=>p.n).map(p=>{const next=angle+p.n/total*2*Math.PI;let result;if(p.n===total)result=`<circle cx="${x}" cy="${y}" r="${r}" fill="${p.color}"/>`;else result=`<path d="M ${x} ${y} L ${x+r*Math.cos(angle)} ${y+r*Math.sin(angle)} A ${r} ${r} 0 ${next-angle>Math.PI?1:0} 1 ${x+r*Math.cos(next)} ${y+r*Math.sin(next)} Z" fill="${p.color}"/>`;angle=next;return result;}).join('');}
function renderMap(){
 const {px,py,s}=geometry();const bins=context.bins;let svg='';
 for(let x=0;x<=spanX+5;x+=25)svg+=`<line x1="${px(x)}" x2="${px(x)}" y1="43" y2="303" stroke="#dfe4d8" stroke-width=".8"/>`;
 for(let y=0;y<=spanY+5;y+=25)svg+=`<line x1="40" x2="1060" y1="${py(y)}" y2="${py(y)}" stroke="#dfe4d8" stroke-width=".8"/>`;
 svg+=`<text x="35" y="26" font-size="11" fill="#687269">${minLon.toFixed(4)}° E</text><text x="1065" y="26" text-anchor="end" font-size="11" fill="#687269">${maxLon.toFixed(4)}° E</text><text x="35" y="327" font-size="11" fill="#687269">西</text><text x="1065" y="327" text-anchor="end" font-size="11" fill="#687269">东</text><path d="M1036 77 L1036 46 M1032 54 L1036 46 L1040 54" stroke="#4b6555" fill="none"/><text x="1036" y="39" text-anchor="middle" font-size="11" fill="#4b6555">N</text>`;
 svg+=`<path d="M ${px(0)} 316 v -5 M ${px(0)} 313 h ${s*50} M ${px(50)} 316 v -5" fill="none" stroke="#67796a"/><text x="${px(25)}" y="334" text-anchor="middle" font-size="10" fill="#687269">50 m</text>`;
 for(const b of bins){const x=px(b.x),y=py(b.y),rad=circleRadius(b.rows.length),selected=state.point===b.key;
 let marks='';if(state.mode==='language'){const n=b.rows.filter(r=>languageMatch(r,state.language)).length;marks=`<circle cx="${x}" cy="${y}" r="${rad}" fill="#cdd5c7" opacity=".8"/>`+(n?`<circle cx="${x}" cy="${y}" r="${circleRadius(n)}" fill="${languageColor(state.language)}" opacity=".88"/>`:'');}
 else{const keys=state.mode==='count'?COUNT:FN;marks=pie(x,y,rad,Object.entries(keys).map(([k,v])=>({n:b.rows.filter(r=>(state.mode==='count'?countKey(r):r.fn)===k).length,color:v[1]})));}
 const inLayer=state.mode==='language'?b.rows.filter(r=>languageMatch(r,state.language)).length:b.rows.length;
 svg+=`<g class="bin" data-bin="${b.key}" tabindex="0" role="button" aria-label="5米网格，${b.rows.length}条记录，当前图层${inLayer}条"><circle class="hit" cx="${x}" cy="${y}" r="${Math.max(7,rad+3)}" fill="transparent"/>${marks}${selected?`<circle cx="${x}" cy="${y}" r="${rad+4}" fill="none" stroke="#263b32" stroke-width="1.8"/>`:''}</g>`;
 }
 $('map').innerHTML=svg;$('mapEmpty').textContent=context.active.length?'':'当前图层没有记录';$('mapEmpty').hidden=!!context.active.length;
 const legends=state.mode==='language'?[[languageName(state.language),languageColor(state.language)],['当前全部记录','#cdd5c7']]:Object.values(state.mode==='count'?COUNT:FN);
 $('legend').innerHTML=legends.map(([name,color])=>`<span class="legend-item"><i class="swatch" style="background:${color}"></i>${esc(name)}</span>`).join('');
}
function renderMini(){
 const keys=['ja','en','zh','ko','vi','ne'];const {px,py}=geometry(280,85,10);
 $('miniMaps').innerHTML=keys.map(k=>{const l=LANG.get(k),n=context.counts.get(k),dots=context.bins.map(b=>{const hit=b.rows.filter(r=>r.currentLangs.includes(k)).length;const x=px(b.x),y=py(b.y);return `<circle cx="${x}" cy="${y}" r="${Math.sqrt(b.rows.length)*.55}" fill="#d7dcd1"/>`+(hit?`<circle cx="${x}" cy="${y}" r="${Math.sqrt(hit)*.55}" fill="${l.color}"/>`:'');}).join('');return `<button class="mini-panel ${state.mode==='language'&&state.language===k?'selected':''}" data-language="${k}" aria-label="查看${l.name}，${n}条记录"><div class="mini-heading"><span><i class="swatch" style="background:${l.color}"></i> ${l.name}</span><strong>${fmt(n)}</strong></div><svg class="mini-map" viewBox="0 0 280 85" aria-hidden="true">${dots}</svg><div class="mini-caption"><span>${esc(l.source)}</span><span>占当前记录 ${pct(n,context.rows.length)}</span></div></button>`;}).join('');
}
function bars(items,max){return items.map(({label,n,color})=>`<div class="bar-row"><span class="bar-label" title="${esc(label)}">${esc(label)}</span><div class="bar-track"><div class="bar-fill" style="width:${max?n/max*100:0}%;background:${color}"></div></div><span class="bar-number">${fmt(n)}</span></div>`).join('');}
function renderCharts(){const exact=context.rows.filter(r=>r.exact),combos=new Map();for(const r of exact){const key=r.currentLangs.join('|');combos.set(key,(combos.get(key)||0)+1);}const top=[...combos].sort((a,b)=>b[1]-a[1]).slice(0,6);$('comboNote').textContent=`按所选语言范围去重 · 数量可确定 ${fmt(exact.length)} 条 · 前 6 种组合`;$('comboChart').innerHTML=top.length?bars(top.map(([key,n])=>({label:key.split('|').map(k=>LANG.get(k).name).join('＋'),n,color:'#748d7a'})),Math.max(...top.map(x=>x[1]))):'<p class="tiny">没有可确定的语言组合。</p>';const cs=Object.entries(COUNT).map(([k,v])=>({label:v[0],n:context.rows.filter(r=>countKey(r)===k).length,color:v[1]}));$('countNote').textContent=`共 ${fmt(context.rows.length)} 条 · “未确定”单独显示`;$('countChart').innerHTML=bars(cs,Math.max(1,...cs.map(x=>x.n)));}
function imageFor(r){if(!r)return '';return localImages.get(raw(r,'写真ファイル名'))||DATA.images[r.image]||'';}
function renderRecords(){const rows=context.listed,start=state.page*12;const slice=rows.slice(start,start+12);$('recordsTitle').textContent=state.point?'这个位置附近的标识':'回到具体标识';$('recordsContext').textContent=`${state.mode==='language'?languageName(state.language)+' · ':''}${state.point?'所选 5 m 网格 · ':''}${fmt(rows.length)} 条记录`;$('clearPoint').hidden=!state.point;
 $('recordGrid').innerHTML=slice.length?slice.map(r=>{const src=imageFor(r);return `<button class="record-card ${state.selected===r.i?'selected':''}" data-record="${r.i}" aria-label="查看${esc(r.label)}"><div class="record-thumb">${src?`<img loading="lazy" src="${src}" alt="${esc(r.label)} 标识缩略图">`:`<span class="text-specimen">${r.currentLangs.length?r.currentLangs.map(k=>LANG.get(k).source).join(' / '):'语言未确定'}</span>`}</div><div class="record-card-text"><b>${esc(r.label)}</b><span>${esc(FN[r.fn][0])} · ${src?'照片已匹配':'暂无匹配照片'}</span></div></button>`;}).join(''):'<div class="empty-list">这里没有符合当前图层的记录。可取消点位选择或调整筛选。</div>';
 $('pageInfo').textContent=rows.length?`${start+1}–${Math.min(start+12,rows.length)} / ${fmt(rows.length)} 条`:'0 条记录';$('prev').disabled=state.page===0;$('next').disabled=start+12>=rows.length;$('exportRows').disabled=!rows.length;
}
function renderDetail(){const r=DATA.records.find(r=>r.i===state.selected);$('photoAvailability').textContent=`已内嵌 ${DATA.meta.photos} 条匹配照片；其余可从本地文件夹补充。${localImages.size?' 本次已关联 '+localImages.size+' 个文件。':''}`;
 if(!r){$('detail').innerHTML='<div class="photo-empty">选择图上的位置或下方记录，查看原始标注。</div>';$('inspectIndex').textContent='';return;}
 $('inspectIndex').textContent=`记录 ${r.i+1} / ${DATA.records.length}`;
 const src=imageFor(r);const fields=[['采集日期',raw(r,'採集日時')],['主要语言',raw(r,'主要言語')],['辅助语言',raw(r,'補助言語')],['装饰语言',raw(r,'装飾の言語')],['语言关系',raw(r,'多言語関係')],['标识用途',raw(r,'ディスコース類型')],['载体',raw(r,'担体類型')],['放置位置',raw(r,'放置位置')],['制作方式',raw(r,'製作品質')],['审核状态',({'human-reviewed':'已人工审核',final:'定稿',ai:'AI 起草待审核',pending:'待处理'})[r.status]||r.status]];
 $('detail').innerHTML=`<div class="photo-stage">${src?`<img class="photo-open" tabindex="0" role="button" src="${src}" alt="${esc(r.label)}，点击放大照片">`:`<div class="photo-empty"><b>${esc(r.currentLangs.map(k=>LANG.get(k).source).join(' / ')||'文字记录')}</b>CSV 有这条记录，当前未匹配到照片。<br>可在下方选择本地照片文件夹。</div>`}</div><div class="detail-body"><h3 class="detail-title">${esc(r.label)}</h3><div class="chips">${r.currentLangs.map(k=>`<span class="chip" style="border-left:3px solid ${LANG.get(k).color}">${LANG.get(k).name}</span>`).join('')}${!r.exact?'<span class="chip">语言数量未确定</span>':''}</div><dl class="detail-fields">${fields.map(([k,v])=>`<dt>${k}</dt><dd>${esc(v||'未标注')}</dd>`).join('')}</dl><p class="detail-note"><strong>原始备注 · 沿用 CSV 标注</strong>${esc(raw(r,'備考')||'无备注')}</p><details class="raw"><summary>查看全部原始字段</summary><table>${DATA.headers.map((h,i)=>`<tr><td>${esc(h)}</td><td>${esc(r.raw[i]||'—')}</td></tr>`).join('')}</table></details></div>`;
 const img=$('detail').querySelector('.photo-open');if(img){const open=()=>{$('dialogImage').src=src;$('dialogCaption').textContent=r.label+' · 阅读用缩略图';$('photoDialog').showModal();};img.onclick=open;img.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();open();}};}
}
function selectPoint(key){state.point=state.point===key?null:key;state.page=0;state.selected=null;update();}
$('map').addEventListener('click',e=>{const g=e.target.closest('[data-bin]');if(g)selectPoint(g.dataset.bin);});
$('map').addEventListener('keydown',e=>{const g=e.target.closest('[data-bin]');if(g&&(e.key==='Enter'||e.key===' ')){e.preventDefault();selectPoint(g.dataset.bin);}});
$('map').addEventListener('pointermove',e=>{const g=e.target.closest('[data-bin]');if(!g){$('tooltip').style.display='none';return;}const b=context.bins.find(b=>b.key===g.dataset.bin);if(!b)return;const languageCounts=DATA.languages.map(l=>({name:l.name,n:b.rows.filter(r=>r.currentLangs.includes(l.id)).length})).filter(l=>l.n).sort((a,b)=>b.n-a.n);$('tooltip').innerHTML=`5 m 网格 · ${b.rows.length} 条记录<br>${languageCounts.slice(0,5).map(l=>`${l.name} ${l.n}`).join(' / ')}<br>语言可重复计入，点击查看标识`;$('tooltip').style.display='block';$('tooltip').style.left=Math.min(e.clientX+15,window.innerWidth-260)+'px';$('tooltip').style.top=Math.min(e.clientY+15,window.innerHeight-120)+'px';});
$('map').addEventListener('pointerleave',()=>{$('tooltip').style.display='none';});
document.querySelectorAll('[data-mode]').forEach(b=>b.addEventListener('click',()=>{state.mode=b.dataset.mode;state.page=0;state.point=null;update();}));
$('miniMaps').onclick=e=>{const b=e.target.closest('[data-language]');if(b){state.language=b.dataset.language;state.mode='language';state.point=null;state.page=0;$('language').value=state.language;update();}};
$('recordGrid').onclick=e=>{const b=e.target.closest('[data-record]');if(b){state.selected=Number(b.dataset.record);renderRecords();renderDetail();if(window.innerWidth<721)document.querySelector('.inspector').scrollIntoView({behavior:'smooth',block:'start'});}};
for(const [id,key] of [['scope','scope'],['roles','roles'],['day','day'],['function','fn'],['language','language']])$(id).onchange=()=>{state[key]=$(id).value;state.page=0;state.point=null;update();};
let searchTimer;$('search').oninput=()=>{clearTimeout(searchTimer);searchTimer=setTimeout(()=>{state.query=$('search').value.trim().toLocaleLowerCase();state.page=0;state.point=null;update();},160);};
$('reset').onclick=()=>{clearTimeout(searchTimer);Object.assign(state,{scope:'reviewed',roles:'all',day:'all',fn:'all',query:'',mode:'language',language:'ja',point:null,page:0,selected:null});$('scope').value='reviewed';$('roles').value='all';$('day').value='all';$('function').value='all';$('search').value='';$('language').value='ja';update();};
$('prev').onclick=()=>{state.page--;renderRecords();};$('next').onclick=()=>{state.page++;renderRecords();};$('clearPoint').onclick=()=>{state.point=null;state.page=0;update();};
$('methodJump').onclick=()=>{$('method').open=true;$('method').scrollIntoView({behavior:'smooth'});};
$('connectPhotos').onclick=()=>$('photoFolder').click();$('photoFolder').onchange=()=>{const needed=new Set(DATA.records.map(r=>raw(r,'写真ファイル名')));for(const file of $('photoFolder').files){if(needed.has(file.name)&&file.type.startsWith('image/')){if(localImages.has(file.name))URL.revokeObjectURL(localImages.get(file.name));localImages.set(file.name,URL.createObjectURL(file));}}renderRecords();renderDetail();};
$('closePhoto').onclick=()=>$('photoDialog').close();$('photoDialog').onclick=e=>{if(e.target===$('photoDialog'))$('photoDialog').close();};
$('exportRows').onclick=()=>{const q=v=>'"'+String(v??'').replace(/"/g,'""')+'"';const csv='\ufeff'+[DATA.headers,...context.listed.map(r=>r.raw)].map(row=>row.map(q).join(',')).join('\r\n');const blob=new Blob([csv],{type:'text/csv;charset=utf-8'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='llmap-filtered-records.csv';a.click();setTimeout(()=>URL.revokeObjectURL(url),2000);};
for(const date of [...new Set(DATA.records.map(r=>r.date))].sort())$('day').insertAdjacentHTML('beforeend',`<option value="${esc(date)}">${esc(date)}</option>`);
for(const [key,[name]] of Object.entries(FN))$('function').insertAdjacentHTML('beforeend',`<option value="${key}">${name}</option>`);
$('language').innerHTML='<option value="all">所有语言</option><option value="jaOnly">仅日语（精确）</option><option value="nonJa">含日语以外语言</option>'+DATA.languages.map(l=>`<option value="${l.id}">${l.name}</option>`).join('');$('language').value='ja';
update();
