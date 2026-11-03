import pypdfium2 as pdfium
from PIL import Image,ImageDraw
from pathlib import Path
p=Path('Documentation/FactoryArena/render_redesign');pdf=pdfium.PdfDocument(p/'report.pdf');print('Pages',len(pdf))
thumbs=[]
for i,page in enumerate(pdf):
 im=page.render(scale=1.6).to_pil();im.save(p/f'page-{i+1}.png')
 text=page.get_textpage().get_text_range();print(i+1,len(text),text[:65].replace('\r',' ').replace('\n',' '))
 im.thumbnail((340,440));thumbs.append(im)
for start in range(0,len(thumbs),6):
 sheet=Image.new('RGB',(1020,920),'#ccd2d8');draw=ImageDraw.Draw(sheet)
 for j,im in enumerate(thumbs[start:start+6]):
  x=(j%3)*340;y=(j//3)*460;sheet.paste(im,(x,y));draw.text((x+8,y+440),str(start+j+1),fill='black')
 sheet.save(p/f'sheet-{start//6}.png')
