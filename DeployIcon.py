
import os
from PIL import Image

icon = Image.open('icon.png')

for parent, dirnames, filenames in os.walk(".",  followlinks=True):
    for filename in filenames:
        file_path = os.path.join(parent, filename)
        if file_path.endswith(".png"):
            target = Image.open(file_path)
            converted = icon.resize((target.width, target.height),Image.ANTIALIAS)
            converted.save(file_path, "png")

