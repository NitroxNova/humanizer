import bpy
from random import random

mesh = bpy.context.active_object.data
uvlayer = mesh.uv_layers.new() # default name and do_init

mesh.uv_layers.active = uvlayer

max_index = len(mesh.vertices) - 1

for face in mesh.polygons:
    for vert_idx, loop_idx in zip(face.vertices, face.loop_indices):
        print(1/max_index)
        uvlayer.data[loop_idx].uv = ((vert_idx/max_index),1-(1/max_index))
