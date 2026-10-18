from pathlib import Path
import math,wave,struct,random
root=Path(__file__).resolve().parents[1]
shapes={
'gold':'<ellipse cx="16" cy="20" rx="11" ry="5" fill="#c18b38"/><path d="M5 15v5c0 6 22 6 22 0v-5" fill="#c18b38"/><ellipse cx="16" cy="15" rx="11" ry="6" fill="#efca72"/><path d="M16 11v8m-3-6h5m-5 4h5"/>',
'food':'<path d="M16 29V7m0 9c-8 0-9-5-9-7 6 0 9 3 9 7zm0 8c-8 0-9-5-9-7 6 0 9 3 9 7zm0-12c8 0 9-5 9-7-6 0-9 3-9 7zm0 8c8 0 9-5 9-7-6 0-9 3-9 7z" fill="#ddbd6c"/>',
'wood':'<path d="M5 17L20 5l9 9-15 13z" fill="#ad7950"/><ellipse cx="9" cy="22" rx="6" ry="7" transform="rotate(-40 9 22)" fill="#d8b57e"/><path d="M6 23l6-4m4-6 6-5m-2 10 5-4"/>',
'stone':'<path d="M3 24l3-12 10-8 11 9 3 11-10 4z" fill="#a2b7bd"/><path d="m6 12 10 6 11-5m-11 5 4 10M16 4v14" fill="none"/>',
'population':'<circle cx="16" cy="10" r="6" fill="#a8cab2"/><path d="M5 28v-6c0-11 22-11 22 0v6z" fill="#7fae99"/>',
'turn':'<path d="M7 10a11 11 0 1 1-2 9M7 3v8H0" fill="none" stroke="#e6c582"/><path d="M16 8v9l6 3" fill="none" stroke="#e6c582"/>',
'house':'<path d="M2 27 16 5l14 22z" fill="#dfb888"/><path d="m16 5 1 22h13" fill="#b97958"/><path d="m12 27 4-9 4 9" fill="#283f43"/>',
'farm':'<path d="M3 25 16 31l14-8-14-6z" fill="#788b52"/><path d="m7 24 16-4m-10 8 16-5M9 23V9m0 7L5 12m4 0 4-4m8 13V6m0 6-4-4m4 8 5-5" stroke="#e7c36d" fill="none"/>',
'sawmill':'<path d="M4 27V12h24v15z" fill="#ad7950"/><path d="m1 12 15-9 15 9z" fill="#6d9d90"/><circle cx="16" cy="22" r="7" fill="#c6d3cf"/><path d="m16 15 2 7-2 7m-7-7h14"/>',
'quarry':'<path d="m2 28 4-11 7 2 5-13 10 17 2 5z" fill="#a9b5bc"/><path d="M9 19V4h17v14m-8-14L9 13" fill="none" stroke="#d1ab71"/>',
'market':'<path d="M5 27V12h22v15" fill="#b58a60"/><path d="m3 12 4-9h18l4 9z" fill="#d8a265"/><path d="m10 4-1 8m9-8v8m6-8 2 8" stroke="#efe0b4"/><path d="M3 21h26v7H3z" fill="#dfc797"/>',
'workshop':'<path d="M4 28V13l10-6 10 6v15z" fill="#b5c3bb"/><path d="M22 28V4h6v24" fill="#ad7950"/><circle cx="14" cy="21" r="6" fill="#d4ae65"/><circle cx="14" cy="21" r="2" fill="#293e43"/>',
'town':'<path d="M6 28V14h20v14z" fill="#e4d1a4"/><path d="M2 14 16 4l14 10z" fill="#b76957"/><path d="M13 28V18h6v10" fill="#314a50"/><path d="M16 4V0h11l-3 4z" fill="#e6bf70"/>',
'undo':'<path d="M11 7 3 14l8 7m-8-7h16c13 0 13 14 0 14" fill="none" stroke="#d2c3a1"/>',
'rotate':'<path d="M7 10a11 11 0 1 1-2 9M7 3v8H0" fill="none" stroke="#d2c3a1"/>',
'save':'<path d="M4 3h21l4 5v21H4z" fill="#809b96"/><path d="M9 3v9h13V3M9 29V18h15v11" fill="#d8caa9"/>',
'home':'<path d="m2 14 14-12 14 12M6 12v17h20V12" fill="#77988b"/><path d="M12 29V18h8v11" fill="#d6c3a2"/>',
'sound':'<path d="M3 12h6l8-7v22l-8-7H3z" fill="#d6c3a2"/><path d="M21 10c5 3 5 9 0 12m4-17c8 6 8 17 0 23" fill="none" stroke="#9fc3b3"/>'}
for name,shape in shapes.items():
 (root/'assets/icons'/f'{name}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="-2 -2 36 36"><g stroke="#394c4c" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round">{shape}</g></svg>')
random.seed(2026)
rate=22050
for name,dur,freqs in [('click',.09,[660,990]),('error',.24,[160,130]),('land',.18,[100,62]),('build',.65,[392,494,587,784]),('turn',1.0,[262,330,392,523]),('save',.4,[523,659,784]),('undo',.24,[440,330])]:
 samples=[]
 for i in range(int(rate*dur)):
  t=i/rate; env=min(1,t/.008)*max(0,1-t/dur)**2
  if name=='land':
   v=(math.sin(2*math.pi*(100*t-100*t*t))*.55+random.uniform(-1,1)*math.exp(-t*35)*.45)*env
  else:
   step=min(len(freqs)-1,int(t/dur*len(freqs)))
   f=freqs[step];v=(math.sin(2*math.pi*f*t)*.6+math.sin(2*math.pi*f*2*t)*.12)*env
  samples.append(struct.pack('<h',int(v*.26*32767)))
 with wave.open(str(root/'assets/audio'/f'{name}.wav'),'wb') as w:
  w.setparams((1,2,rate,0,'NONE','not compressed'));w.writeframes(b''.join(samples))
