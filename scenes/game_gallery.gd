extends TabContainer

@onready var vanilla_game_viewer: Panel = $Vanilla/GameViewer
@onready var current_mod_game_viewer: Panel = $Mods/GameViewer
@onready var gallery: GridContainer = $Mods/ContainerBig/GridContainer

var gallery_element_big = preload("res://scenes/game_gallery_element_big.tscn")
var gallery_element_list = preload("res://scenes/game_gallery_element_list.tscn")


var awaited_mod_view: String = ""


func _ready() -> void:
	current_mod_game_viewer.get_node("AnimationPlayer").play("out")
	ContentGetter.cache_updated.connect(_on_cache_updated)
	current_tab = Configurator.remembered_tab_idx


func _on_ready() -> void:
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer/OptionButton.selected = Configurator.current_theme_id
	theme = Configurator.current_theme

	$Settings/ScrollContainer/VBoxContainer/HBoxContainer2/LineEdit.text = Configurator.get_config("args_windows")
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer3/LineEdit2.text = Configurator.get_config("args_linux")
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer4/LineEdit3.text = Configurator.get_config("args_macos")
	$Settings/ScrollContainer/VBoxContainer/CheckButton.button_pressed = Configurator.get_config("list_gallery")

	if Configurator.get_config("remember_view"):
		$Settings/ScrollContainer/VBoxContainer/CheckButton2.button_pressed = true
		if Configurator.get_config("remembered_tab") == 1:
			current_tab = Configurator.get_config("remembered_tab")
			awaited_mod_view = Configurator.get_config("remembered_mod")


func _on_tree_exiting() -> void:
	Configurator.remembered_tab_idx = current_tab


func _on_cache_updated(succeeded: bool) -> void:
	vanilla_game_viewer.refresh_mod_data()
	_repopulate_gallery(gallery_element_list if Configurator.get_config("list_gallery") else gallery_element_big, 1 if Configurator.get_config("list_gallery") else 5)
	if awaited_mod_view != "":
		current_mod_game_viewer.mod_data_id = Configurator.get_config("remembered_mod")
		current_mod_game_viewer.refresh_mod_data()


func _repopulate_gallery(element: Resource, cols: int) -> void:
	if gallery.get_child_count() > 0:
		for child in gallery.get_children():
			gallery.remove_child(child)

	gallery.columns = cols
	for mod in ContentGetter.moddatas.keys():
		if mod == "vanilla": continue
		var child = element.instantiate()
		var moddata: ModData = ContentGetter.moddatas[mod]
		child.idx = mod
		child.opened.connect(_on_mod_opened)
		child.init_ui(moddata.cover_image, moddata.name)
		gallery.add_child(child)


func _on_mod_opened(idx: String):
	current_mod_game_viewer.mod_data_id = idx
	current_mod_game_viewer.refresh_mod_data()
	Configurator.set_config("remembered_mod", idx)


func _on_check_button_toggled(button_pressed: bool) -> void:
	Configurator.set_config("list_gallery", button_pressed)
	_repopulate_gallery(gallery_element_list if button_pressed else gallery_element_big, 1 if button_pressed else 5)


func _on_check_button_2_toggled(button_pressed: bool) -> void:
	Configurator.set_config("remember_view", button_pressed)


func _on_line_edit_text_submitted(new_text: String) -> void:
	Configurator.set_config("args_windows", new_text)


func _on_line_edit_2_text_submitted(new_text: String) -> void:
	Configurator.set_config("args_windows", new_text)


func _on_line_edit_3_text_submitted(new_text: String) -> void:
	Configurator.set_config("args_windows", new_text)


func _on_button_pressed() -> void:
	Configurator.update_timestamp(true)
	$Settings/ScrollContainer/VBoxContainer/Button.disabled = true
	$Settings/ScrollContainer/VBoxContainer/Button.text = "Scheduled for next restart"


func _on_tab_changed(tab: int) -> void:
	Configurator.set_config("remembered_tab", tab)


func _on_option_button_item_selected(index: int) -> void:
	Configurator.set_config("theme", index)
	theme = Configurator.themes[index]
