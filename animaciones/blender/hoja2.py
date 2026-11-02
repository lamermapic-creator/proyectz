import sys, os
from PIL import Image, ImageDraw
pref, n, nv, etiquetas = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4].split(";")
W, H = 520, 480
o = Image.new('RGB', (W * nv, H * n), (255, 255, 255))
for i in range(n):
	for k in range(nv):
		o.paste(Image.open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'renders', '%s_%02d_%d.png' % (pref, i, k))), (k * W, i * H))
	ImageDraw.Draw(o).text((6, i * H + 6), etiquetas[i], fill=(0, 0, 0))
o.save(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'renders', '%s_hoja.png' % pref))
