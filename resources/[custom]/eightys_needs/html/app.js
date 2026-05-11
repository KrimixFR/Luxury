'use strict';

const barHunger = document.getElementById('bar-hunger');
const barThirst  = document.getElementById('bar-thirst');
const rowHunger = document.getElementById('row-hunger');
const rowThirst  = document.getElementById('row-thirst');
const CRIT = 20;

window.addEventListener('message', e => {
    const d = e.data;
    if (!d || !d.type) return;

    if (d.type === 'SHOW') {
        document.getElementById('needs').classList.remove('hidden');
    }

    if (d.type === 'UPDATE') {
        const h = Math.max(0, Math.min(100, d.hunger));
        const t  = Math.max(0, Math.min(100, d.thirst));

        barHunger.style.width = h + '%';
        barThirst.style.width  = t + '%';

        barHunger.classList.toggle('low', h <= CRIT);
        barThirst.classList.toggle('low',  t <= CRIT);
        rowHunger.classList.toggle('critical', h <= CRIT);
        rowThirst.classList.toggle('critical',  t <= CRIT);
    }
});
