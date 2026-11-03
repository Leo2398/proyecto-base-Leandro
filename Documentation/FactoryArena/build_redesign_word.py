from pathlib import Path
import re
from docx import Document
from docx.shared import Inches,Pt,RGBColor
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
base=Path('C:/ProyectoFinalRV/Documentation/FactoryArena')
lines=(base/'Informe_Rediseno_Fabrica_Mortal.md').read_text(encoding='utf-8').splitlines()
end=lines.index('## 11. Estado de entrega')
state=lines[end:];lines=lines[:end]
extra=next(x for x in lines if x.startswith('También se guardaron'))
lines.remove(extra)
gallery=lines.index('## 10. Evidencias visuales')
state[0]='## 10. Estado de entrega'
lines[gallery]='## 11. Evidencias visuales'
lines=lines[:gallery]+state+['']+lines[gallery:]
first_image=next(i for i,x in enumerate(lines) if x.startswith('!['))
lines[first_image:first_image]=[extra,'']
d=Document();s=d.sections[0];s.page_width=Inches(8.5);s.page_height=Inches(11)
s.top_margin=s.bottom_margin=Inches(.65);s.left_margin=s.right_margin=Inches(.8)
s.header_distance=s.footer_distance=Inches(.3)
for name in ['Normal','Title','Subtitle','Heading 1','Heading 2','Heading 3']:
 st=d.styles[name];st.font.name='Calibri';st.font.color.rgb=RGBColor(0,0,0)
d.styles['Normal'].font.size=Pt(11)
d.styles['Normal'].paragraph_format.space_after=Pt(7)
d.styles['Normal'].paragraph_format.line_spacing=1.05
d.styles['Title'].font.size=Pt(27)
d.styles['Heading 1'].font.size=Pt(17)
d.styles['Heading 2'].font.size=Pt(13)
for name in ['Heading 1','Heading 2']:
 d.styles[name].paragraph_format.space_before=Pt(13);d.styles[name].paragraph_format.space_after=Pt(7)
foot=s.footer.paragraphs[0];foot.alignment=WD_ALIGN_PARAGRAPH.RIGHT
foot.add_run('Fábrica Mortal  |  Rediseño visual  |  ').font.size=Pt(9)
f=OxmlElement('w:fldSimple');f.set(qn('w:instr'),'PAGE');foot._p.append(f)
header=s.header.paragraphs[0];header.add_run('ProyectoFinalRV     •     2 de noviembre de 2026').font.size=Pt(9)
count=0;i=0
while i<len(lines):
 line=lines[i]
 if not line.strip():i+=1;continue
 if line.startswith('# '):
  d.add_paragraph('Informe del rediseño visual de Fábrica Mortal',style='Title');i+=1;continue
 if line.startswith('## '):
  title=re.sub(r'^(\d+)\.',r'\1',line[3:]);d.add_heading(title,1);i+=1;continue
 if line.startswith('### '):d.add_heading(line[4:],2);i+=1;continue
 if line.startswith('| '):
  rows=[]
  while i<len(lines) and lines[i].startswith('| '):
   cells=[x.strip() for x in lines[i].strip('|').split('|')]
   if not all(re.fullmatch(r'[-: ]+',x) for x in cells):rows.append(cells)
   i+=1
  table=d.add_table(rows=1, cols=len(rows[0]));table.autofit=False
  widths=[1.6,5.3] if len(rows[0])==2 else [4.7,1.1,1.1]
  for c,w in zip(table.columns,widths):c.width=Inches(w)
  for n,row in enumerate(rows):
   cells=table.rows[0].cells if n==0 else table.add_row().cells
   for cell,text,w in zip(cells,row,widths):
    cell.width=Inches(w);cell.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER
    cell.text=text
    for p in cell.paragraphs:
     p.paragraph_format.space_before=Pt(4);p.paragraph_format.space_after=Pt(4)
     for run in p.runs:run.font.size=Pt(10);run.bold=n==0;run.font.color.rgb=RGBColor(255,255,255) if n==0 else RGBColor(0,0,0)
    pr=cell._tc.get_or_add_tcPr();shade=OxmlElement('w:shd');shade.set(qn('w:fill'),'283F52' if n==0 else ('F0F4F7' if n%2==0 else 'FFFFFF'));pr.append(shade)
    borders=OxmlElement('w:tcBorders')
    for edge in ['top','left','bottom','right']:
     el=OxmlElement('w:'+edge);el.set(qn('w:val'),'single');el.set(qn('w:sz'),'4');el.set(qn('w:color'),'D9D9D9');borders.append(el)
    pr.append(borders)
   trpr=table.rows[n]._tr.get_or_add_trPr();trpr.append(OxmlElement('w:cantSplit'))
   if n==0:trpr.append(OxmlElement('w:tblHeader'))
  d.add_paragraph();continue
 if line.startswith('!['):
  match=re.match(r'!\[(.*?)\]\((.*)\)',line)
  if count%2==0:d.add_page_break()
  pic=d.add_paragraph();pic.alignment=WD_ALIGN_PARAGRAPH.CENTER;pic.paragraph_format.keep_with_next=True;pic.paragraph_format.space_after=Pt(3)
  pic.add_run().add_picture(match.group(2),width=Inches(6.2))
  cap=d.add_paragraph(f'Figura {count+1}. '+match.group(1),style='Caption');cap.paragraph_format.space_after=Pt(12)
  count+=1;i+=1;continue
 if line.startswith('['):
  match=re.match(r'\[(.*?)\]\((.*)\)',line)
  p=d.add_paragraph();p.add_run(match.group(1)).bold=True
  p.paragraph_format.keep_with_next=True
  p=d.add_paragraph(match.group(2));p.paragraph_format.space_after=Pt(5)
  for run in p.runs:run.font.size=Pt(9)
  i+=1;continue
 if line.startswith('- '):d.add_paragraph(line[2:],style='List Bullet')
 else:d.add_paragraph(line)
 i+=1
d.core_properties.title='Informe del rediseño visual de Fábrica Mortal'
d.core_properties.subject='Mejoras del mapa FactoryArena pruebas y capturas de Unity'
d.core_properties.author='ProyectoFinalRV'
for el in list(d.styles.element.iter(qn('w:pBdr'))) + list(d.element.iter(qn('w:pBdr'))):
 el.getparent().remove(el)
path=base/'Informe_Rediseno_Fabrica_Mortal.docx';d.save(path);print(path)

