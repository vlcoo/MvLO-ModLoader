extends TabContainer

@onready var vanilla_game_viewer: Panel = $Vanilla/GameViewer
@onready var current_mod_game_viewer: Panel = $"Mod Gallery/GameViewer"
@onready var gallery: GridContainer = $"Mod Gallery/ContainerBig/VBoxContainer/ScrollContainer/MarginContainer/GridMods"
@onready var installs_tree: ItemList = $"Storage Usage/MarginContainer/VBoxContainer/Tree"
@onready var button_uninstall: Button = $"Storage Usage/MarginContainer/VBoxContainer/HBoxContainer2/ButtonUninstall"
@onready var button_launch: Button = $"Storage Usage/MarginContainer/VBoxContainer/HBoxContainer2/ButtonLaunch"
@onready var button_browse: Button = $"Storage Usage/MarginContainer/VBoxContainer/HBoxContainer2/ButtonBrowse"
@onready var input_search: LineEdit = $"Mod Gallery/ContainerBig/VBoxContainer/ContainerFilters/InputSearch"

var gallery_element_big = preload("res://scenes/game_gallery_element_big.tscn")
var gallery_element_list = preload("res://scenes/game_gallery_element_list.tscn")
var installed_texture: Texture2D = preload("res://audiovisual/installed.png")

var awaited_mod_view: String = ""
var requires_game_viewer_ui_reload = false
var selected_install: Dictionary = {}
var filter_search = ""
var filter_favourites = false
var filter_installed = false


func _ready() -> void:
	#current_mod_game_viewer.get_node("AnimationPlayer").play("out")
	ContentGetter.cache_updated.connect(_on_cache_updated)
	current_tab = Configurator.remembered_tab_idx
	Configurator.set_discord_status(Configurator.DiscordStatus.IN_MENU)
	set_tab_icon(0, load("res://audiovisual/nsmb.png"))
	set_tab_icon(1, load("res://audiovisual/puzzle.png"))
	set_tab_icon(2, load("res://audiovisual/drive.png"))
	set_tab_icon(3, load("res://audiovisual/settings.png"))


func _on_ready() -> void:
	set_physics_process(false)
	
	$Settings/ScrollContainer/VBoxContainer/Panel/LabelVersion.text = "v" + str(SelfUpdater.vercode)
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer/OptionButton.selected = Configurator.current_theme_id
	#$Settings/ScrollContainer/VBoxContainer/HBoxContainer7/OptionButton.selected = Configurator.get_config("discord", 0)
	$"Mod Gallery/ContainerBig/VBoxContainer/ContainerFilters/OptionSort".selected = Configurator.get_config("sort", -1) + 1
	theme = Configurator.current_theme
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer2/LineEdit.text = Configurator.get_config("args_windows", "")
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer3/LineEdit2.text = Configurator.get_config("args_linux", "")
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer4/LineEdit3.text = Configurator.get_config("args_macos", "")
	$Settings/ScrollContainer/VBoxContainer/CheckButton.button_pressed = Configurator.get_config("list_gallery", false)
	$Settings/ScrollContainer/VBoxContainer/CheckButton4.button_pressed = Configurator.get_config("discord-rpc", true)
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer5/LineEdit3.text= Configurator.get_config("install_location", "user://")
	$Settings/ScrollContainer/VBoxContainer/CheckButton3.button_pressed = Configurator.get_config("all_platforms")
	$Settings/ScrollContainer/VBoxContainer/CheckButton5.button_pressed = Configurator.get_config("minimize", false)

	if Configurator.get_config("remember_view", false):
		$Settings/ScrollContainer/VBoxContainer/CheckButton2.button_pressed = true
		current_tab = Configurator.get_config("remembered_tab", 0)
		if current_tab == 1: awaited_mod_view = Configurator.get_config("remembered_mod", "")


func _on_tree_exiting() -> void:
	if current_tab < 3: Configurator.remembered_tab_idx = current_tab


func _on_cache_updated(_succeeded: bool) -> void:
	vanilla_game_viewer.refresh_mod_data()
	_repopulate_gallery(gallery_element_list if Configurator.get_config("list_gallery", 0) else gallery_element_big, 1 if Configurator.get_config("list_gallery") else 5)
	if awaited_mod_view != "":
		current_mod_game_viewer.mod_data_id = Configurator.get_config("remembered_mod", "")
		current_mod_game_viewer.refresh_mod_data()


func _repopulate_gallery(element: PackedScene, cols: int) -> void:
	if gallery.get_child_count() > 0:
		for child in gallery.get_children():
			gallery.remove_child(child)

	gallery.columns = cols
	var mod_array = ContentGetter.moddatas.values()
	mod_array.sort_custom(_mod_comparator)
	for mod in mod_array:
		if mod.idx == "vanilla": continue
		var child: GalleryElement = element.instantiate()
		child.idx = mod.idx
		child.opened.connect(_on_mod_opened)
		child.init_ui(mod.cover_image, mod.name)
		gallery.add_child(child)
	
	gallery.modulate = Color.TRANSPARENT
	apply_gallery_filters()
	await create_tween().tween_property(gallery, "modulate", Color.WHITE, 0.1).finished
	input_search.grab_focus.call_deferred()


func apply_gallery_filters() -> void:
	var filters_enabled = true
	if filter_search == "" and not filter_favourites and not filter_installed:
		filters_enabled = false
	
	for child: GalleryElement in gallery.get_children():
		if not filters_enabled: 
			child.visible = true
			continue
		
		# match each mod to searched text, favourite and installed
		child.visible = (filter_search == "" or filter_search in child.title.to_lower()) and \
			(not filter_favourites or child.favourite) and \
			(not filter_installed or child.installed)


func _mod_comparator(a: ModData, b: ModData) -> bool:
	match Configurator.get_config("sort", -1):
		0:	# by name
			return a.name < b.name
		1:	# most played
			return Configurator.get_timer_mod(a.idx) > Configurator.get_timer_mod(b.idx)
		2:	# recently updated
			return int(a.timestamp) >= int(b.timestamp)
		3:	# by favourite
			return Configurator.get_is_mod_favourite(a.idx) > Configurator.get_is_mod_favourite(b.idx)
		4:	# by installed
			return InstallsIndex.mod_is_installed(a.idx) > InstallsIndex.mod_is_installed(b.idx)
		_:	# by id
			return a.idx < b.idx


func _repopulate_installs_tree() -> void:
	installs_tree.clear()
	var total_mb_str = str(snapped(InstallsIndex.get_total_installs_size(), 0.01))
	var header_index = installs_tree.add_item("All installed games (" + total_mb_str + " MB)", installed_texture, false)

	for install in InstallsIndex.index.installs:
		var mb_str = str(snapped(install.size/1024/1024, 0.01)) if install.has("size") else "?"
		installs_tree.add_item(install.mod_id + " - " + install.version + " - " + install.platform + " - " + mb_str + " MB")

	installs_tree.sort_items_by_text()
	installs_tree.move_item(header_index, 0)
	button_browse.disabled = true
	button_launch.disabled = true
	button_uninstall.disabled = true


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
	Configurator.set_config("args_linux", new_text)


func _on_line_edit_3_text_submitted(new_text: String) -> void:
	Configurator.set_config("args_macos", new_text)


func _on_button_pressed() -> void:
	# update db
	Configurator.update_timestamp(true)
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer6/Button.disabled = true
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer6/Button.text = "Scheduled (next restart)"


func _on_button_2_pressed() -> void:
	# delete db
	OS.move_to_trash(ProjectSettings.globalize_path("user://DB/"))
	OS.move_to_trash(ProjectSettings.globalize_path("user://DB.zip"))
	OS.move_to_trash(ProjectSettings.globalize_path("user://DB.tar"))
	OS.move_to_trash(ProjectSettings.globalize_path("user://DB.gamefiles.json"))


func _on_button_3_pressed() -> void:
	# uninstall mods
	OS.move_to_trash(ProjectSettings.globalize_path(Configurator.get_config("install_location", "user://Installs/")))


func _on_button_4_pressed() -> void:
	# reset settings
	Configurator.restore_config()
	_on_ready()


func _on_tab_changed(tab: int) -> void:
	Configurator.set_config("remembered_tab", tab)
	if tab == 1: input_search.grab_focus.call_deferred()
	if tab == 2: _repopulate_installs_tree()
	if requires_game_viewer_ui_reload:
		requires_game_viewer_ui_reload = false
		if tab == 0: vanilla_game_viewer.refresh_mod_data()
		if tab == 1: current_mod_game_viewer.refresh_mod_data()


func _on_option_button_item_selected(index: int) -> void:
	Configurator.set_config("theme", index)
	theme = Configurator.themes[index]


func _on_check_button_3_toggled(button_pressed: bool) -> void:
	Configurator.set_config("all_platforms", button_pressed)
	requires_game_viewer_ui_reload = true


func _on_tree_item_selected(index: int) -> void:
	var item_str: PackedStringArray = installs_tree.get_item_text(index).split(" - ")
	if item_str.size() < 4: return
	selected_install = InstallsIndex._find_install_in_array(item_str[0], item_str[1], item_str[2])
	if selected_install == {}: return

	selected_install["tree_item_id"] = index
	button_browse.disabled = false
	button_launch.disabled = false
	button_uninstall.disabled = false


func _on_button_uninstall_pressed() -> void:
	if selected_install == {}: return
	InstallsIndex.uninstall(selected_install.mod_id, selected_install.version, selected_install.platform)
	installs_tree.remove_item(selected_install["tree_item_id"])
	button_browse.disabled = true
	button_launch.disabled = true
	button_uninstall.disabled = true

	var total_mb_str = str(snapped(InstallsIndex.get_total_installs_size(), 0.01))
	installs_tree.set_item_text(0, "All installed games (" + total_mb_str + " MB)")


func _on_button_launch_pressed() -> void:
	if selected_install == {}: return
	InstallsIndex.launch(selected_install.mod_id, selected_install.version, selected_install.platform)
	button_launch.text = "Loading"
	button_launch.disabled = true
	$"Storage Usage"/MarginContainer/VBoxContainer/HBoxContainer2/TimerLoading.start()


func _on_button_browse_pressed() -> void:
	if selected_install == {}: return
	InstallsIndex.show_file_explorer(selected_install.mod_id, selected_install.version, selected_install.platform)


func _on_timer_loading_timeout() -> void:
	button_launch.text = "Launch"
	button_launch.disabled = false


func _on_option_button2_item_selected(index: int) -> void:
	Configurator.set_config("discord", index)


func _on_button_choose_folder_pressed() -> void:
	InstallsIndex.warn("This will set the following folder as the location for any future installs.\n\
	The previous install location and its contents will be *deleted*.")
	await InstallsIndex.dialog.confirmed or InstallsIndex.dialog.canceled
	$Settings/FileDialog.popup_centered()


func _on_button_clear_pressed() -> void:
	if Configurator.get_config("install_location", "user://Installs/") == "user://Installs/": return
	OS.move_to_trash(ProjectSettings.globalize_path(Configurator.get_config("install_location")))
	Configurator.set_config("install_location", "user://Installs/")
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer5/LineEdit3.text = "user://Installs/"


func _on_file_dialog_dir_selected(dir: String) -> void:
	var dir_access = DirAccess.open(dir)
	if dir_access.get_files().size() != 0:
		InstallsIndex.warn("Folder must be empty.")
		return
	
	dir = dir + "/"
	OS.move_to_trash(ProjectSettings.globalize_path(Configurator.get_config("install_location", "user://Installs/")))
	Configurator.set_config("install_location", dir)
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer5/LineEdit3.text = dir


func _on_option_button3_item_selected(index: int) -> void:
	Configurator.set_config("sort", index-1)
	_repopulate_gallery(gallery_element_list if $Settings/ScrollContainer/VBoxContainer/CheckButton.button_pressed \
	else gallery_element_big, 1 if $Settings/ScrollContainer/VBoxContainer/CheckButton.button_pressed else 5)


func _on_button_5_pressed() -> void:
	OS.shell_open(ProjectSettings.globalize_path("user://logs"))


func _on_check_button_4_toggled(toggled_on: bool) -> void:
	if not toggled_on: 
		Configurator.set_discord_status(Configurator.DiscordStatus.CLEARED)
	Configurator.set_config("discord-rpc", toggled_on)


func _on_game_viewer_viewer_closed() -> void:
	_repopulate_gallery(gallery_element_list if Configurator.get_config("list_gallery") else gallery_element_big, 1 if Configurator.get_config("list_gallery") else 5)
	input_search.grab_focus.call_deferred()
	Configurator.set_config("remembered_mod", "")


func _on_input_search_text_changed(new_text: String) -> void:
	filter_search = new_text.to_lower()
	apply_gallery_filters()


func _on_check_only_favourites_toggled(toggled_on: bool) -> void:
	filter_favourites = toggled_on
	apply_gallery_filters()


func _on_check_only_installed_toggled(toggled_on: bool) -> void:
	filter_installed = toggled_on
	apply_gallery_filters()


func _on_check_button_5_toggled(toggled_on: bool) -> void:
	Configurator.set_config("minimize", toggled_on)
