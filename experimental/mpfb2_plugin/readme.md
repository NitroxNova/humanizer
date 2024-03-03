in-game character menu will work out of the box, but if you want to re-generate the shapekeys or menu tabs:  
first download the latest nightly 'belnder-4' zip from http://files.makehumancommunity.org/plugins/  
extract into this folder, and move the mpfb folder up a level  
the path should be project_folder/mpfb2_plugin/mpfb/  
then go to the data/targets folder in the terminal and run: gunzip -r *  
or extract the targets manually by selecting all and right clicking  
  
then download the system assets or other 'assets' zip from http://static.makehumancommunity.org/assets/assetpacks.html  
extract folders and copy to 'mpfb2_plugin/assets' in the project  
filepath should be Godot_Project/mpfb2_plugin/assets/clothes/femalecasualsuit01  
now you can run the clothes_gen 'move_texture_files','make_material_resources', 'obj_to_mesh' and finally 'generate_clothes_mesh'  