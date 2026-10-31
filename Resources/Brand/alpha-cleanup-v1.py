from PIL import Image, ImageFilter, ImageDraw
import numpy as np
from pathlib import Path
root=Path(__file__).resolve().parents[2]
src=Image.open(root/'Resources/Brand/agenticnights-moon-dark-v1.png').convert('RGB')
rgb=np.asarray(src).astype(np.float32)
peak=rgb.max(axis=2)
# The moon has a bright rim; flood-fill the dark exterior, retaining all
# interior texture even where that texture is dark.
solid=Image.fromarray(np.uint8(peak>80)*255, 'L')
exterior=solid.copy()
ImageDraw.floodfill(exterior,(0,0),128,thresh=0)
inside=np.asarray(exterior)!=128
# Restrict antialiasing to the immediate outside edge, removing the source glow.
dilated=np.asarray(Image.fromarray(np.uint8(inside)*255).filter(ImageFilter.MaxFilter(3)))>0
eroded=np.asarray(Image.fromarray(np.uint8(inside)*255).filter(ImageFilter.MinFilter(3)))>0
edge=dilated & ~eroded
alpha=inside.astype(np.float32)
alpha[edge]=np.clip((peak[edge]-22)/185,0,1)
# Keep only the component connected to the crescent body.
components=Image.fromarray(np.uint8(alpha>0)*255).copy()
ImageDraw.floodfill(components,(300,600),128,thresh=0)
alpha[np.asarray(components)!=128]=0
# Dematte partial pixels against the source's nearly black background.
# Edge colors are recovered from their premultiplied source values.
a=np.maximum(alpha,1e-6)
out=np.clip((rgb-(1-alpha[:,:,None])*np.array([5,8,14]))/a[:,:,None],0,255)
out[alpha==0]=0
rgba=np.dstack((out,alpha*255)).astype(np.uint8)
result=Image.fromarray(rgba,'RGBA')
result.save(root/'Resources/Brand/agenticnights-moon-transparent-v1.png')
review=root/'.build/moon-alpha-review'
review.mkdir(parents=True,exist_ok=True)
for name,color in [('black',(0,0,0)),('white',(255,255,255)),('gray',(128,128,128))]:
 bg=Image.new('RGB',result.size,color); bg.paste(result,mask=result.getchannel('A')); bg.save(review/f'{name}.png')
small=result.resize((64,64),Image.Resampling.LANCZOS)
canvas=Image.new('RGB',(192,64))
for i,c in enumerate([(0,0,0),(255,255,255),(128,128,128)]):
 bg=Image.new('RGB',(64,64),c); bg.paste(small,mask=small.getchannel('A')); canvas.paste(bg,(i*64,0))
canvas.resize((768,256),Image.Resampling.NEAREST).save(review/'64px.png')
print('size',result.size,'alpha range',int(rgba[:,:,3].min()),int(rgba[:,:,3].max()),'transparent',int((rgba[:,:,3]==0).sum()),'partial',int(((rgba[:,:,3]>0)&(rgba[:,:,3]<255)).sum()))
