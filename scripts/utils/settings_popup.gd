@tool
extends Window

@onready var slot_categories : Dictionary = ProjectSettings.get_setting("addons/humanizer/slots")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	fill_slot_category_options()
	select_and_emit_option(0,%Slot_Category_Options)
	%Save_Slot_Category_Name_Button.hide()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_close_requested() -> void:
	get_parent().remove_child(self)
	queue_free()

func select_and_emit_option(index:int,options:OptionButton):
	options.select(index)
	options.item_selected.emit(index)

func is_slot_id_unique(new_name:String):
	for category_name in slot_categories:
		for slot_name in slot_categories[category_name]:
			if slot_name == new_name:
				return false
	return true

func find_item_in_options(search_text:String,options:OptionButton)->int:
	for item_id in options.item_count:
		var item_text = options.get_item_text(item_id)
		if item_text == search_text:
			return item_id
	return -1
	
func fill_slot_category_options()-> void:
	%Slot_Category_Options.clear()
	%Slot_Category_Options.add_item(" -- New Category -- ")
	for category_name in slot_categories:
		%Slot_Category_Options.add_item(category_name)

func fill_slot_options()->void:
	%Slot_Options.clear()
	%Slot_Options.add_item(" -- New Slot -- ")
	var selected_category = %Slot_Category_Options.get_item_text(%Slot_Category_Options.selected)
	for slot_name in slot_categories[selected_category]:
		%Slot_Options.add_item(slot_name)
	%Slot_Edit_Container.show()
	
func _on_slot_category_options_item_selected(index: int) -> void:
	var select_text = %Slot_Category_Options.get_item_text(index)
	if select_text == " -- New Category -- ":
		%Slot_Category_Name_Edit.text = ""
		%Slot_Category_Name_Edit.show()
		%Slot_Edit_Container.hide()
		%Delete_Slot_Category_Button.hide()
		return
	%Slot_Category_Name_Edit.text = select_text
	%Slot_Category_Name_Edit.show()
	%Save_Slot_Category_Name_Button.hide()
	fill_slot_options()
	select_and_emit_option(0,%Slot_Options)
	if slot_categories[select_text].size() == 0:
		%Delete_Slot_Category_Button.show()
	else:
		%Delete_Slot_Category_Button.hide()
	
func _on_slot_category_name_edit_text_changed(new_text: String) -> void:
	%Save_Slot_Category_Name_Button.show()

func _on_save_slot_category_name_button_pressed() -> void:
	var new_category_name = %Slot_Category_Name_Edit.text
	if new_category_name == "":
		printerr("Category Name cannot be Blank")
		return
	if new_category_name in slot_categories:
		printerr("Category Name must be Unique")
		return
	var selected_category = %Slot_Category_Options.get_item_text(%Slot_Category_Options.selected)
	if selected_category == " -- New Category -- ":
		slot_categories[new_category_name] = {}
	else:
		slot_categories[new_category_name] = slot_categories[selected_category]
		slot_categories.erase(selected_category)
	ProjectSettings.save()
	fill_slot_category_options()
	var menu_id = find_item_in_options(new_category_name,%Slot_Category_Options)
	select_and_emit_option(menu_id,%Slot_Category_Options)		
	%Save_Slot_Category_Name_Button.hide()

func _on_delete_slot_category_button_pressed() -> void:
	var selected_category = %Slot_Category_Options.get_item_text(%Slot_Category_Options.selected)
	if selected_category == " -- New Category -- ":
		return
	slot_categories.erase(selected_category)
	ProjectSettings.save()
	fill_slot_category_options()
	select_and_emit_option(0,%Slot_Category_Options)
	
func _on_slot_options_item_selected(index: int) -> void:
	var selected_slot = %Slot_Options.get_item_text(%Slot_Options.selected)
	var selected_category = %Slot_Category_Options.get_item_text(%Slot_Category_Options.selected)
	%Save_Slot_Name_Button.hide()
	%Delete_Slot_Button.text = "Delete Slot"
	if selected_slot == " -- New Slot -- ":
		%Slot_ID_Line_Edit.text = ""
		%Slot_Display_Line_Edit.text = ""
		%Delete_Slot_Button.hide()
		%Save_Slot_Name_Button.text = "Add"
		return
	%Slot_ID_Line_Edit.text = selected_slot
	%Slot_Display_Line_Edit.text = slot_categories[selected_category][selected_slot]
	%Delete_Slot_Button.show()
	%Save_Slot_Name_Button.text = "Save"

func _on_delete_slot_button_pressed() -> void:
	var selected_slot = %Slot_Options.get_item_text(%Slot_Options.selected)
	var selected_category = %Slot_Category_Options.get_item_text(%Slot_Category_Options.selected)
	if %Delete_Slot_Button.text == "Delete Slot":
		%Delete_Slot_Button.text = "Confirm Delete?"	
		return
	if %Delete_Slot_Button.text == "Confirm Delete?":
		slot_categories[selected_category].erase(selected_slot)
		ProjectSettings.save()
		fill_slot_options()
		select_and_emit_option(find_item_in_options(selected_category,%Slot_Category_Options),%Slot_Category_Options)
		select_and_emit_option(0,%Slot_Options)
		
func _on_save_slot_name_button_pressed() -> void:
	var selected_slot = %Slot_Options.get_item_text(%Slot_Options.selected)
	var selected_category = %Slot_Category_Options.get_item_text(%Slot_Category_Options.selected)
	var new_id = %Slot_ID_Line_Edit.text
	var new_display = %Slot_Display_Line_Edit.text
	if new_id == "":
		printerr("Slot ID cannot be Blank")
		return
	if selected_slot == " -- New Slot -- ":
		if not is_slot_id_unique(new_id):
			printerr("Slot ID must be Unique")
			return
		slot_categories[selected_category][new_id] = new_display
		ProjectSettings.save()
		fill_slot_options()
		select_and_emit_option(find_item_in_options(selected_category,%Slot_Category_Options),%Slot_Category_Options)
		select_and_emit_option(0,%Slot_Options)
		return
	if not new_id == selected_slot: 
		if not is_slot_id_unique(new_id):
			printerr("Slot ID must be Unique")
			return
		slot_categories[selected_category].erase(selected_slot)
	slot_categories[selected_category][new_id] = new_display
	ProjectSettings.save()
	fill_slot_options()
	select_and_emit_option( find_item_in_options(new_id,%Slot_Options) ,%Slot_Options)
	
func _on_slot_id_line_edit_text_changed(new_text: String) -> void:
	%Save_Slot_Name_Button.show()

func _on_slot_display_line_edit_text_changed(new_text: String) -> void:
	%Save_Slot_Name_Button.show()
