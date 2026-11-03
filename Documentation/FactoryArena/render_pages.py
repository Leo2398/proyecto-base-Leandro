import pypdfium2 as pdfium
from PIL import Image, ImageOps, ImageDraw
from pathlib import Path
p=Path('Documentation/FactoryArena/render');pdf=pdfium.PdfDocument(p/'report.pdf');print('Pages',len(pdf))
thumbs=[]
for i,page in enumerate(pdf):
 pix=page.render(scale=1.3).to_pil();pix.save(p/f'page-{i+1}.png');im=Image.open(p/f'page-{i+1}.png');im.thumbnail((306,420));thumbs.append(im)
for start in range(0,len(thumbs),6):
 sheet=Image.new('RGB',(918,880),'#cccccc')
 for j,im in enumerate(thumbs[start:start+6]):sheet.paste(im,((j%3)*306,(j//3)*440))
 sheet.save(p/f'sheet-{start//6}.png')

