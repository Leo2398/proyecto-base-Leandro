from pathlib import Path
import zipfile,re,hashlib,json
root=Path('C:/ProyectoFinalRV')
z=zipfile.ZipFile(root/'Documentation/FactoryArena/Backups/BeforeVisualRedesign.zip')
selected=[]; changed=[]; missing=[]
for name in z.namelist():
 p=name.replace('\\','/')
 if p.startswith(('FactoryArena/MODELS/','MultiplayerTest/','Packages/','ProjectSettings/','FactoryArena/Scripts/Runtime/')) and not p.endswith('/'):
  dest=root/('Assets/'+p if p.startswith(('FactoryArena/','MultiplayerTest/')) else p)
  selected.append(p)
  if not dest.is_file(): missing.append(p)
  elif hashlib.sha256(z.read(name)).digest()!=hashlib.sha256(dest.read_bytes()).digest(): changed.append(p)
scene_name=next(n for n in z.namelist() if n.replace('\\','/').endswith('FactoryArena/Scenes/FactoryArena.unity'))
a=z.read(scene_name).decode('utf-8-sig');b=(root/'Assets/FactoryArena/Scenes/FactoryArena.unity').read_text(encoding='utf-8-sig')
def physics(text):
 return {ident:body for kind,ident,body in re.findall(r'^--- !u!(\d+) &(-?\d+)[^\n]*\n(.*?)(?=^--- !u!|\Z)',text,re.M|re.S) if kind in ('54','64','65','135','136')}
x=physics(a);y=physics(b)
physics_changed=[k for k,v in x.items() if y.get(k)!=v]
report={'checked_files':len(selected),'changed':changed,'missing':missing,'baseline_physics_components':len(x),'changed_or_missing_physics_components':physics_changed,'added_physics_components':len(set(y)-set(x))}
(root/'Assets/FactoryArena/Generated/Redesign/PreservationAudit.txt').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
