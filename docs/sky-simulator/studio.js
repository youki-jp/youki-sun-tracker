(function () {
  'use strict';
  const $ = id => document.getElementById(id);
  const { generateScene, makeRenderer, elevationAt, smooth, clamp } = globalThis.YoukiAtmosphere;
  const presets = [
    { id:'golden', name:'Golden hour', swatch:'linear-gradient(#9b8297,#efbd85)', caption:'Warm light, scattered cloud.', time:1060, total:42, low:12, mid:25, high:48, sunlight:650, diffuse:30, visibility:24, aerosol:.18 },
    { id:'clear', name:'Clear sky', swatch:'linear-gradient(#5580ab,#c9dfe4)', caption:'Open sky. A clear source of light.', time:780, total:3, low:0, mid:0, high:3, sunlight:760, diffuse:15, visibility:30, aerosol:.08 },
    { id:'wisps', name:'High wisps', swatch:'linear-gradient(#a2bccb,#e4ddd4)', caption:'Thin cloud catches and softens the light.', time:950, total:60, low:0, mid:10, high:72, sunlight:420, diffuse:50, visibility:24, aerosol:.1 },
    { id:'broken', name:'Broken cloud', swatch:'linear-gradient(#90a3b1,#c8cdd0)', caption:'Clouds with depth, and room for light.', time:880, total:58, low:48, mid:42, high:18, sunlight:370, diffuse:45, visibility:22, aerosol:.12 },
    { id:'overcast', name:'Overcast', swatch:'linear-gradient(#92999e,#c8c9c5)', caption:'A low cloud deck. Soft, diffuse daylight.', time:760, total:100, low:100, mid:78, high:30, sunlight:0, diffuse:100, visibility:12, aerosol:.12 },
    { id:'dawn', name:'Before sunrise', swatch:'linear-gradient(#68617f,#e8b69b)', caption:'The sky warms before the sun appears.', time:349, total:22, low:5, mid:8, high:35, sunlight:650, diffuse:30, visibility:24, aerosol:.2 },
    { id:'fog', name:'Mist', swatch:'linear-gradient(#acb4b8,#d3d5d0)', caption:'Low visibility softens every edge.', time:440, total:76, low:82, mid:25, high:10, sunlight:100, diffuse:90, visibility:.2, aerosol:.18 },
    { id:'night', name:'Night', swatch:'linear-gradient(#252f46,#626d85)', caption:'The original night palette, without solar light.', time:1320, total:25, low:12, mid:15, high:24, sunlight:650, diffuse:50, visibility:24, aerosol:.08 }
  ];
  let state, selected = presets[0], frame = 0, timer = null, scene, input;
  const options = { sun:true, clouds:true, haze:true };
  const renderer = makeRenderer((w,h) => { const c = document.createElement('canvas'); c.width=w; c.height=h; return c; });
  const definitions = [
    ['total','Total cover',0,100,1,'%', 'cloud-controls'], ['high','High wisps',0,100,1,'%', 'cloud-controls'],
    ['mid','Middle clouds',0,100,1,'%', 'cloud-controls'], ['low','Low cloud deck',0,100,1,'%', 'cloud-controls'],
    ['sunlight','Sunlight potential',0,1000,10,' W/m2','light-controls'], ['diffuse','Diffuse share',0,100,1,'%','light-controls'],
    ['visibility','Visibility',.1,40,.1,' km','light-controls'], ['aerosol','Aerosol / warmth',0,.6,.01,'','light-controls']
  ];
  for (const [key,label,min,max,step,unit,parent] of definitions) {
    const row = document.createElement('div'); row.className='slider-row';
    row.innerHTML=`<div class="slider-heading"><label for="${key}">${label}</label><output id="${key}-value" for="${key}"></output></div><input type="range" id="${key}" min="${min}" max="${max}" step="${step}">`;
    $(parent).append(row);
    $(key).addEventListener('input', event => { state[key]=Number(event.target.value); markCustom(); updateControls(); schedule(); });
  }
  for (const preset of presets) {
    const button = document.createElement('button'); button.dataset.preset=preset.id; button.setAttribute('aria-pressed','false');
    const dot=document.createElement('span'); dot.className='preset-dot'; dot.style.setProperty('--swatch',preset.swatch); dot.setAttribute('aria-hidden','true');
    button.append(dot,document.createTextNode(preset.name)); button.addEventListener('click',()=>applyPreset(preset)); $('presets').append(button);
  }
  function timeLabel(minutes) { return `${String(Math.floor(minutes/60)).padStart(2,'0')}:${String(minutes%60).padStart(2,'0')}`; }
  function stop() { clearInterval(timer); timer=null; $('play').innerHTML='Play day <span aria-hidden="true">&#9654;</span>'; $('play').setAttribute('aria-pressed','false'); }
  function applyPreset(preset) {
    stop(); selected=preset; state={...preset,mode:'radiation'}; $('data-mode').value=state.mode;
    for (const key of ['sun','clouds','haze']) { options[key]=true; $('show-'+key).checked=true; }
    document.querySelectorAll('[data-preset]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.preset===preset.id)));
    $('scenario-caption').textContent=preset.caption; updateControls(); schedule();
  }
  function markCustom() {
    document.querySelectorAll('[data-preset]').forEach(b=>b.setAttribute('aria-pressed','false'));
    $('scenario-caption').textContent='Your atmosphere study';
  }
  function updateControls() {
    $('time').value=state.time;
    for (const [key,, , ,step,unit] of definitions) {
      $(key).value=state[key]; const precision=step===.01?2:step===.1?1:0;
      $(key+'-value').textContent=state[key].toFixed(precision)+unit;
      const weatherMissing=state.mode==='missing';
      $(key).disabled = weatherMissing || (state.mode==='clouds' && ['sunlight','diffuse'].includes(key));
    }
  }
  function observation() {
    const elevation=elevationAt(state.time), daylight=smooth(-.267,12,elevation);
    const direct=state.sunlight*daylight;
    const horizontal=direct*Math.max(0,Math.sin(elevation*Math.PI/180));
    // The diffuse slider is a synthetic horizontal fraction. At 100%, the
    // diffuse ambient field stays lit while direct irradiance goes to zero.
    const fraction=state.diffuse/100;
    const dhi=(80+horizontal*.8)*fraction*daylight;
    const ghi=horizontal*(1-fraction)+dhi;
    const missing=state.mode==='missing', radiation=state.mode==='radiation';
    return { elevationDegrees:elevation, azimuthDegrees:180, seed:42,
      cloudTotalPct:missing?null:state.total, cloudLowPct:missing?null:state.low,
      cloudMidPct:missing?null:state.mid, cloudHighPct:missing?null:state.high,
      visibilityMeters:missing?null:state.visibility*1000, relativeHumidityPct:missing?null:65,
      precipitationMillimeters:missing?null:0, aerosolOpticalDepth:missing?null:state.aerosol, dustUgM3:0, pm25UgM3:0,
      directNormalWm2:radiation?direct*(1-fraction):null,
      globalHorizontalWm2:radiation?ghi:null, diffuseHorizontalWm2:radiation?dhi:null };
  }
  function schedule() { if (!frame) frame=requestAnimationFrame(()=>{frame=0;render();}); }
  function sizeCanvas(canvas) {
    const rect=canvas.parentElement.getBoundingClientRect();
    if (rect.width===0 || rect.height===0) return;
    const scale=Math.min(window.devicePixelRatio||1,2);
    const w=Math.round(rect.width*scale), h=Math.round(rect.height*scale);
    if (canvas.width!==w || canvas.height!==h) {canvas.width=w;canvas.height=h;}
  }
  function render() {
    input=observation(); scene=generateScene(input);
    for (const id of ['baseline','enhanced']) sizeCanvas($(id));
    renderer.draw($('baseline'),scene,{baseline:true}); renderer.draw($('enhanced'),scene,options);
    const clock=timeLabel(state.time), e=scene.elevation;
    const phase=e<=-6?'Night':e<-.267?'Twilight':e<8?'Golden hour':'Daylight';
    $('clock').textContent=clock; $('phase').textContent=phase;
    $('time').setAttribute('aria-valuetext',`${clock}, ${phase}`);
    document.querySelectorAll('.mock-time').forEach(el=>el.textContent=clock);
    $('palette').replaceChildren(...scene.base.ramp.map(hex=>{const sw=document.createElement('div');sw.innerHTML=`<div class="swatch" style="background:${hex}"></div><code>${hex.toUpperCase()}</code>`;return sw;}));
    $('elevation-stat').textContent=e.toFixed(1)+'\u00b0';
    $('direct-stat').textContent=input.directNormalWm2===null?'Estimated':Math.round(input.directNormalWm2)+' W/m2';
    const notes={ 'radiation-supported':'Synthetic radiation sets the light; clouds can obscure the sun.', 'cloud-estimated':'Radiation unavailable. Cloud cover provides a conservative light estimate.', unavailable:'Weather unavailable. Only the fallback gradient and geometric twilight glow remain; no confident sun or clouds.' };
    $('quality-note').textContent=notes[scene.quality];
    let title,body;
    if(scene.quality==='unavailable'){title='A palette without a weather claim';body='No cloud or radiation data is available. The colorful base is a rendering fallback, not evidence of a clear sky.';}
    else if(e<=-6){title='No sunlight after dark';body='The sun and twilight glow are switched off by solar geometry. Clouds remain subtle silhouettes over the original night colors.';}
    else if(e<-.267){title='The glow before the sun';body='Twilight light can reach the sky while the solar disc is still below the horizon. High clouds pick up a restrained warm tint.';}
    else if(state.visibility<1){title='Light dissolves into the haze';body='Low visibility suppresses the sharp sun and washes the scene with a soft atmospheric veil.';}
    else if(state.low>85){title='A softer kind of daylight';body='A dense low deck obscures the sun. The gradient keeps its palette while cloud cover gives the light a diffuse, quieter character.';}
    else if(e<8){title='Golden light, softened by clouds';body='A low sun warms the horizon. Wisps and cloud masses catch its color, with the sun drawn behind them.';}
    else {title=state.total<10?'An open sky, a distinct sun':'Layers between you and the sun';body=state.total<10?'The original palette carries the atmosphere. A small solar disc and broad, restrained halo give the daylight a source.':'High wisps stay translucent. Middle and low clouds add shape and obscure the light without replacing the gradient.';}
    $('insight-title').textContent=title; $('insight-body').textContent=body;
    $('enhanced').setAttribute('aria-label',`${clock}. ${title}. ${body} ${notes[scene.quality]}`);
    $('scene-json').textContent=JSON.stringify({source:'synthetic-local-study',time:clock,input,scene,visibleLayers:options},null,2);
  }
  $('time').addEventListener('input',event=>{state.time=Number(event.target.value);markCustom();schedule();});
  document.querySelectorAll('[data-time]').forEach(b=>b.addEventListener('click',()=>{state.time=Number(b.dataset.time);markCustom();updateControls();schedule();}));
  $('play').addEventListener('click',()=>{
    if(timer){stop();return;}
    $('play').textContent='Pause day';$('play').setAttribute('aria-pressed','true');markCustom();
    timer=setInterval(()=>{state.time=(state.time+6)%1440;updateControls();schedule();},120);
  });
  document.addEventListener('visibilitychange',()=>{if(document.hidden)stop();});
  for(const key of ['sun','clouds','haze']) $('show-'+key).addEventListener('change',event=>{options[key]=event.target.checked;schedule();});
  $('show-overlay').addEventListener('change',event=>document.querySelectorAll('.mock-overlay').forEach(el=>el.hidden=!event.target.checked));
  $('data-mode').addEventListener('change',event=>{state.mode=event.target.value;markCustom();updateControls();schedule();});
  $('reset').addEventListener('click',()=>applyPreset(selected));
  $('focus').addEventListener('click',()=>{const focused=$('previews').classList.toggle('focused');$('focus').setAttribute('aria-pressed',String(focused));$('focus').textContent=focused?'Compare views':'Focus view';schedule();});
  function download(url,name) { const a=document.createElement('a');a.href=url;a.download=name;document.body.append(a);a.click();a.remove();$('notification').textContent=`Downloaded ${name}`; }
  $('save-image').addEventListener('click',()=>{render();download($('enhanced').toDataURL('image/png'),`youki-sky-${timeLabel(state.time).replace(':','')}.png`);});
  $('save-json').addEventListener('click',()=>{render();const url=URL.createObjectURL(new Blob([$('scene-json').textContent],{type:'application/json'}));download(url,'youki-sky-scene.json');setTimeout(()=>URL.revokeObjectURL(url),1000);});
  new ResizeObserver(schedule).observe($('previews'));
  applyPreset(presets[0]);
})();
