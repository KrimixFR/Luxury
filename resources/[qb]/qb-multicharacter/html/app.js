'use strict';
function res(){return typeof GetParentResourceName==='function'?GetParentResourceName():'qb-multicharacter';}
function nui(cb,data){fetch(`https://${res()}/${cb}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data||{})}).catch(()=>{});}

let chars=[];
function showScreen(id){['screen-select','screen-create'].forEach(s=>document.getElementById(s).classList.add('hidden'));document.getElementById(id).classList.remove('hidden');}
function showCreate(){showScreen('screen-create');}
function backToSelect(){showScreen('screen-select');}

function renderChars(){
    const list=document.getElementById('char-list');
    list.innerHTML='';
    if(!chars||chars.length===0){
        list.innerHTML='<p style="color:rgba(255,255,255,0.4);font-size:16px;margin-bottom:16px;">Aucun personnage. Créez-en un.</p>';
        return;
    }
    chars.forEach((c,i)=>{
        const d=document.createElement('div');
        d.className='char-card';
        const ci=c.charinfo||{};
        d.innerHTML=`<div class="char-name">${esc(ci.firstname||'?')} ${esc(ci.lastname||'?')}</div>
            <div class="char-info">Né(e) le ${esc(ci.birthdate||'?')} · ${c.job&&c.job.label||'Chômeur'} · $${(c.money&&c.money.cash)||0}</div>`;
        d.onclick=()=>nui('selectChar',{index:i});
        list.appendChild(d);
    });
}

function confirmCreate(){
    const fn=document.getElementById('inp-firstname').value.trim();
    const ln=document.getElementById('inp-lastname').value.trim();
    const bd=document.getElementById('inp-birthdate').value.trim();
    const gd=parseInt(document.getElementById('inp-gender').value)||0;
    if(!fn||!ln){alert('Prénom et nom requis.');return;}
    nui('createChar',{firstname:fn,lastname:ln,birthdate:bd,gender:gd});
}

window.addEventListener('message',e=>{
    const d=e.data;
    if(!d||!d.type)return;
    if(d.type==='OPEN'){document.getElementById('overlay').classList.remove('hidden');showScreen('screen-select');renderChars();}
    if(d.type==='SHOW_CHARS'){chars=d.chars||[];renderChars();}
});

function esc(s){return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');}
