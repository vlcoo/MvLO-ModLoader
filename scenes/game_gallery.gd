extends TabContainer

@onready var vanilla_game_viewer: GameViewer = $Vanilla/GameViewer
@onready var current_mod_game_viewer: GameViewer = $"Mod Gallery/GameViewer"
@onready var gallery: GridContainer = $"Mod Gallery/ContainerBig/VBoxContainer/ContainerMods/MarginContainer/GridContainer"
@onready var installs_tree_list: VBoxContainer = $"Storage/MarginContainer/VBoxContainer/Panel/ScrollContainer/VBoxContainer"
@onready var label_usage_disk: RichTextLabel = $"Storage/MarginContainer/VBoxContainer/HBoxContainer/RichTextLabel"
@onready var label_usage_installs: Label = $"Storage/MarginContainer/VBoxContainer/HBoxContainer/Label"
@onready var button_uninstall: Button = $"Storage/MarginContainer/VBoxContainer/ContainerButtons/ButtonUninstall"
@onready var button_launch: Button = $"Storage/MarginContainer/VBoxContainer/ContainerButtons/ButtonLaunch"
@onready var button_browse: Button = $"Storage/MarginContainer/VBoxContainer/ContainerButtons/ButtonBrowse"
@onready var button_find: Button = $"Storage/MarginContainer/VBoxContainer/ContainerButtons/ButtonFind"
@onready var input_search: LineEdit = $"Mod Gallery/ContainerBig/VBoxContainer/ContainerFilters/InputSearch"
@onready var container_no_results: VBoxContainer = $"Mod Gallery/ContainerBig/VBoxContainer/ContainerMods/MarginContainer/ContainerNoResults"
@onready var check_list: CheckButton = $Settings/ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer/CheckList
@onready var label_vanilla_id: LineEdit = $Settings/ScrollContainer/VBoxContainer/ContainerAdvanced/VBoxContainer/ContainerVanillaReplacement/LineEdit


var gallery_element_big = preload("res://scenes/game_gallery_element_big.tscn")
var gallery_element_list = preload("res://scenes/game_gallery_element_list.tscn")
var installed_texture: Texture2D = preload("res://audiovisual/installed.png")
var storage_element = preload("res://scenes/storage_usage_element.tscn")

var awaited_mod_view: String = ""
var requires_game_viewer_ui_reload = false
var gallery_game_viewer_opened = false
var selected_install: Dictionary = {}
var filter_search = ""
var filter_favourites = false
var filter_installed = false
var filter_result_count = 0
var gallery_chooser_mode = false
var focused_storage_usage_item: StorageUsageElement
var installs_tree_item_count: int = 0


func _ready() -> void:
	InstallsIndex.operation_done.connect(_on_installs_index_operation_done)
	Configurator.mod_requested.connect(_on_mod_opened)
	
	#current_mod_game_viewer.get_node("AnimationPlayer").play("out")
	ContentGetter.cache_updated.connect(_on_cache_updated)
	Configurator.set_discord_status(Configurator.DiscordStatus.IN_MENU)
	set_tab_icon(0, load("res://audiovisual/nsmb-drop.png"))
	set_tab_icon(1, load("res://audiovisual/puzzle-drop.png"))
	set_tab_icon(2, load("res://audiovisual/drive-drop.png"))
	set_tab_icon(3, load("res://audiovisual/settings-drop.png"))
	set_tab_icon(4, load("res://audiovisual/news-drop.png"))
	if Configurator.vanilla_id != "vanilla": set_tab_title(0, "\"Vanilla\"")


func _on_ready() -> void:
	set_physics_process(false)
	
	$Settings/ScrollContainer/VBoxContainer/PanelAbout/LabelVersion.text = "v" + str(SelfUpdater.vercode)
	$Settings/ScrollContainer/VBoxContainer/PanelAbout/LabelVersion.tooltip_text = tr("Built on the {date}".format({date = SelfUpdater.verdate}))
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer/ContainerTheme/HBoxContainer/OptionButton.selected = Configurator.current_theme_id
	theme = Configurator.current_theme
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer/ContainerTheme/HBoxContainer/HSlider.value = Configurator.get_config("theme-colour", 360)
	$"Mod Gallery/ContainerBig/VBoxContainer/ContainerFilters/OptionSort".selected = Configurator.get_config("sort", 2)
	$"Mod Gallery/ContainerBig/VBoxContainer/ContainerFilters/VBoxContainer/CheckOnlyInstalled".button_pressed = Configurator.get_config("filter-installed", false)
	$"Mod Gallery/ContainerBig/VBoxContainer/ContainerFilters/VBoxContainer/CheckOnlyFavourites".button_pressed = Configurator.get_config("filter-favourite", false)
	$Settings/ScrollContainer/VBoxContainer/ContainerAdvanced/VBoxContainer/ContainerArgsWin/LineEdit.text = Configurator.get_config("args_windows", "")
	$Settings/ScrollContainer/VBoxContainer/ContainerAdvanced/VBoxContainer/ContainerArgsLinux/LineEdit.text = Configurator.get_config("args_linux", "")
	$Settings/ScrollContainer/VBoxContainer/ContainerAdvanced/VBoxContainer/ContainerArgsMac/LineEdit.text = Configurator.get_config("args_macos", "")
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer/CheckList.button_pressed = Configurator.get_config("list_gallery", false)
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer/CheckPlatforms.button_pressed = Configurator.get_config("all_platforms", Configurator.os_name != "Windows")
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer2/CheckDiscord.button_pressed = Configurator.get_config("discord-rpc", true)
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer/CheckAutoSubscribe.button_pressed = Configurator.get_config("auto_subscribe", false)
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer2/CheckMinimize.button_pressed = Configurator.get_config("minimize", false)
	$Settings/ScrollContainer/VBoxContainer/ContainerAdvanced/VBoxContainer/ContainerLocation/LineEdit.text= Configurator.get_config("install_location", "user://")
	$Settings/ScrollContainer/VBoxContainer/ContainerTroubleshooting/HBoxContainer/ButtonFixChar.visible = Configurator.os_name == "Windows"
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer2/ContainerLanguage/HBoxContainer/OptionLanguage.selected = 1 if Configurator.get_config("translate", false) else 0
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer2/ContainerMinimize/HBoxContainer/OptionMinimize.selected = Configurator.get_config("after_launch", 1 if Configurator.get_config("minimize", false) else 0)
	$Settings/ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer/CheckFools.visible = Time.get_datetime_dict_from_system()["month"] == Time.MONTH_APRIL and Time.get_datetime_dict_from_system()["day"] == 1

	if Configurator.get_config("remember_view", false):
		$Settings/ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer2/CheckRemember.button_pressed = true
		current_tab = Configurator.get_config("remembered_tab")
		if current_tab == 1: awaited_mod_view = Configurator.get_config("remembered_mod", "")


func _on_tree_exiting() -> void:
	if current_tab in [0, 1, 2, 4]: Configurator.set_config("remembered_tab", current_tab)


func _input(_event: InputEvent) -> void:
	if InstallsIndex.background.mouse_filter != MOUSE_FILTER_IGNORE or not Configurator.is_window_focused:
		return
	
	var delta = Input.get_axis("ui_home", "ui_end")
	current_tab = clamp(current_tab + delta, 0, get_tab_count() - 1)


func _on_cache_updated(_succeeded: bool) -> void:
	vanilla_game_viewer.refresh_mod_data()
	_repopulate_gallery(gallery_element_list if Configurator.get_config("list_gallery", 0) else gallery_element_big, 1 if Configurator.get_config("list_gallery") else 5)
	if awaited_mod_view != "":
		_on_mod_opened(Configurator.get_config("remembered_mod", ""))


func _repopulate_gallery(element: PackedScene, cols: int, _skip_animations := false) -> void:
	if gallery.get_child_count() > 0:
		for child in gallery.get_children():
			gallery.remove_child(child)

	gallery.columns = cols
	var mod_array = ContentGetter.mods
	mod_array.sort_custom(_mod_comparator)
	var i = 0
	for mod in mod_array:
		if mod.idx == Configurator.vanilla_id: continue
		var child: GalleryElement = element.instantiate()
		child.idx = mod.idx
		child.container_index = i
		child.opened.connect(_on_mod_opened)
		child.init_ui(mod.cover_image, mod.name)
		gallery.add_child(child)
		i += 1
	
	apply_gallery_filters()
	#if not skip_animations:
		#gallery.modulate = Color.TRANSPARENT
		#await create_tween().tween_property(gallery, "modulate", Color.WHITE, 0.1).finished
	#input_search.grab_focus.call_deferred()


func apply_gallery_filters() -> void:
	var filters_enabled = true
	if filter_search == "" and not filter_favourites and not filter_installed:
		filters_enabled = false
	filter_result_count = 0
	
	for child: GalleryElement in gallery.get_children():
		if not filters_enabled: 
			child.visible = true
			filter_result_count += 1
			continue
		
		# match each mod to searched text, favourite and installed
		child.visible = (ContentGetter.string_coincides_with_mod_names(filter_search, [child.title, child.idx])) and \
			(not filter_favourites or child.favourite) and \
			(not filter_installed or child.installed)
		if child.visible: filter_result_count += 1
	
	container_no_results.visible = filter_result_count <= 0


static func _mod_comparator(a: ModData, b: ModData) -> bool:
	match Configurator.get_config("sort", 2):
		0:	# by name
			return a.name.to_lower() < b.name.to_lower()
		1:	# most played
			return Configurator.get_timer_mod(a.idx) > Configurator.get_timer_mod(b.idx)
		2:	# recently updated
			return int(a.timestamp) > int(b.timestamp)
		3:	# by favourite
			return Configurator.get_is_mod_favourite(a.idx) > Configurator.get_is_mod_favourite(b.idx)
		4:	# by installed
			return InstallsIndex.mod_is_installed(a.idx) > InstallsIndex.mod_is_installed(b.idx)
		_:	# by id
			return a.idx < b.idx


func _recalculate_installs_title() -> void:
	#var total_mb_str = str(snapped(InstallsIndex.get_total_installs_size(), 0.01))
	var total_size_str = InstallsIndex.mb_to_string(InstallsIndex.get_total_installs_size())
	label_usage_disk.text = total_size_str
	label_usage_installs.text = tr_n("{count} install", "{count} installs", installs_tree_item_count).format({count = installs_tree_item_count})


func _repopulate_installs_tree() -> void:
	for child in installs_tree_list.get_children():
		child.queue_free()
	_recalculate_installs_title()
	var group = ButtonGroup.new()
	var i = 0
	
	for install in InstallsIndex.index.installs:
		var element: StorageUsageElement = storage_element.instantiate()
		var mb_str = "?"
		if install.has("size") and install.size > 0:
			mb_str = ("> " + str(install.size/1024/1024)) if install.size > 1000000 else str(install.size)
		var mod_data: ModData = ContentGetter.get_local_moddata(install.mod_id)
		if mod_data == null:
			element.set_info(install.mod_id, install.version + " (" + install.platform + ")", mb_str + " MB")
		else:
			element.set_info(mod_data.name, install.version + " (" + install.platform + ")", mb_str + " MB", mod_data.cover_image if mod_data.icon == null else mod_data.icon)
		element.button_group = group
		element.n_id = i
		installs_tree_list.add_child(element)
		element.pressed.connect(_on_tree_item_selected.bind(element))
		element.focus_next = NodePath("../../../../ContainerButtons/ButtonLaunch")
		i += 1
	
	installs_tree_item_count = i
	#installs_tree.move_item(header_index, 0)
	button_browse.disabled = true
	button_launch.disabled = true
	button_uninstall.disabled = true
	button_find.disabled = true
	label_usage_installs.text = tr_n("{count} install", "{count} installs", installs_tree_item_count).format({count = installs_tree_item_count})


func _on_mod_opened(idx: String) -> bool:
	if idx == "": return false
	var mod: ModData = ContentGetter.get_local_moddata(idx)
	
	if gallery_chooser_mode:
		if not mod.vanilla_compatible:
			InstallsIndex.warn(tr("This mod is not vanilla compatible (it doesn't share the same servers and playerbase) - proceed at your own discretion.\nYou can revert this change by re-choosing 'New Super Mario Bros. Versus' for this setting."))
			await InstallsIndex.dialog.confirmed or InstallsIndex.dialog.canceled
		Configurator.vanilla_id = idx
		label_vanilla_id.text = tr("[No change]") if idx == "vanilla" else mod.name
		current_tab = 3
		gallery_chooser_mode = false
		InstallsIndex.warn(tr("App will reboot now to apply changes."))
		await InstallsIndex.dialog.confirmed or InstallsIndex.dialog.canceled
		OS.set_restart_on_exit(true)
		get_tree().quit()
		return false
	
	current_mod_game_viewer.mod_data_id = idx
	var success = current_mod_game_viewer.refresh_mod_data()
	if success:
		Configurator.set_config("remembered_mod", idx)
		gallery.modulate = Color.WHITE * 0.3
		if Configurator.vanilla_id != idx and current_tab != 1:
			current_tab = 1
	#recalculate_focused_node()
	return success


func _on_check_button_toggled(button_pressed: bool) -> void:
	Configurator.set_config("list_gallery", button_pressed)
	_repopulate_gallery(gallery_element_list if button_pressed else gallery_element_big, 1 if button_pressed else 5, true)


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
	$Settings/ScrollContainer/VBoxContainer/ContainerTroubleshooting/HBoxContainer/ButtonRedownloadDB.disabled = true
	$Settings/ScrollContainer/VBoxContainer/ContainerTroubleshooting/HBoxContainer/ButtonRedownloadDB.text = tr("Restarting...")
	OS.set_restart_on_exit(true)
	get_tree().quit()


func _on_button_2_pressed() -> void:
	# delete db
	OS.move_to_trash(ProjectSettings.globalize_path("user://DB/"))
	OS.move_to_trash(ProjectSettings.globalize_path("user://DB.zip"))
	OS.move_to_trash(ProjectSettings.globalize_path("user://DB.tar"))
	OS.move_to_trash(ProjectSettings.globalize_path("user://DB.gamefiles.json"))


func _on_button_3_pressed() -> void:
	# uninstall mods
	OS.move_to_trash(ProjectSettings.globalize_path(Configurator.get_config("install_location", "user://Installs/")))
	InstallsIndex.index.installs.clear()
	requires_game_viewer_ui_reload = true
	InstallsIndex.toast_success()


func _on_button_4_pressed() -> void:
	# reset settings
	Configurator.restore_config()
	_on_ready()


func _on_tab_changed(tab: int) -> void:
	if not is_node_ready(): return
	
	if gallery_chooser_mode:
		gallery_chooser_mode = false
	
	if tab == 2: _repopulate_installs_tree()
	if tab == 3:
		label_vanilla_id.text = tr("[No change]") if Configurator.vanilla_id == "vanilla" else ContentGetter.get_local_moddata(Configurator.vanilla_id).name
	
	if requires_game_viewer_ui_reload:
		requires_game_viewer_ui_reload = false
		vanilla_game_viewer.refresh_mod_data()
		if current_mod_game_viewer.visible:
			current_mod_game_viewer.refresh_mod_data()
	
	recalculate_focused_node()


func recalculate_focused_node() -> void: 
	match current_tab:
		0:
			$Vanilla/GameViewer/PanelDetail/CenterContainer/VBoxContainer/ContainerButtons.grab_focus.call_deferred()
		1:
			if current_mod_game_viewer.visible:
				$"Mod Gallery/GameViewer/PanelDetail/CenterContainer/VBoxContainer/ContainerButtons".grab_focus.call_deferred()
			else:
				input_search.grab_focus.call_deferred()
		2:
			if installs_tree_list.get_child_count() > 0:
				installs_tree_list.get_child(0).grab_focus.call_deferred()
		3:
			$Settings/ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer/CheckList.grab_focus.call_deferred()


func _on_option_button_item_selected(index: int) -> void:
	Configurator.set_config("theme-scheme", index)
	theme = Configurator.themes[index]


func _on_check_button_3_toggled(button_pressed: bool) -> void:
	Configurator.set_config("all_platforms", button_pressed)
	requires_game_viewer_ui_reload = true


func _on_tree_item_selected(button: StorageUsageElement) -> void:
	var index = button.n_id
	selected_install = InstallsIndex.index.installs[index]
	if selected_install == {}: return
	
	focused_storage_usage_item = button
	selected_install["tree_item_id"] = index
	button_browse.disabled = false
	button_launch.disabled = false
	button_uninstall.disabled = false
	button_find.disabled = false


func _on_item_list_item_activated(index: int) -> void:
	if selected_install == {} or button_launch.disabled: return
	InstallsIndex.launch(selected_install.mod_id, selected_install.version, selected_install.platform)
	button_launch.text = tr("Loading")
	button_launch.disabled = true
	$"Storage/MarginContainer/VBoxContainer/ContainerButtons/TimerLoading".start()


func _on_button_uninstall_pressed() -> void:
	if selected_install == {}: return
	InstallsIndex.uninstall(selected_install.mod_id, selected_install.version, selected_install.platform)
	focused_storage_usage_item.queue_free()
	button_browse.disabled = true
	button_launch.disabled = true
	button_uninstall.disabled = true
	button_find.disabled = true

	installs_tree_item_count -= 1
	_recalculate_installs_title()
	requires_game_viewer_ui_reload = true


func _on_button_launch_pressed() -> void:
	if selected_install == {}: return
	InstallsIndex.launch(selected_install.mod_id, selected_install.version, selected_install.platform)
	button_launch.text = tr("Loading")
	button_launch.disabled = true
	$"Storage/MarginContainer/VBoxContainer/ContainerButtons/TimerLoading".start()


func _on_button_browse_pressed() -> void:
	if selected_install == {}: return
	InstallsIndex.show_file_explorer(selected_install.mod_id, selected_install.version, selected_install.platform)


func _on_button_find_pressed() -> void:
	if selected_install == {}: return
	if selected_install.mod_id == Configurator.vanilla_id:
		current_tab = 0
	else:
		current_tab = 1
		await get_tree().process_frame
		await get_tree().process_frame
		if not await _on_mod_opened(selected_install.mod_id):
			InstallsIndex.warn(tr("Mod not found in the gallery!\nIt might've become unavailable since you've installed it."))


func _on_timer_loading_timeout() -> void:
	button_launch.text = tr("Launch")
	button_launch.disabled = false


func _on_option_button2_item_selected(index: int) -> void:
	Configurator.set_config("discord", index)


func _on_button_choose_folder_pressed() -> void:
	InstallsIndex.warn(tr("Please select a folder as the location for any future installs.\nWatch out, the previous install location and its contents will be deleted!"))
	await InstallsIndex.dialog.confirmed or InstallsIndex.dialog.canceled
	$Settings/FileDialog.popup_centered()


func _on_button_clear_pressed() -> void:
	if Configurator.get_config("install_location", "user://Installs/") == "user://Installs/": return
	OS.move_to_trash(ProjectSettings.globalize_path(Configurator.get_config("install_location")))
	Configurator.set_config("install_location", "user://Installs/")
	$Settings/ScrollContainer/VBoxContainer/ContainerLocation/ButtonClear.text = "user://Installs/"


func _on_file_dialog_dir_selected(dir: String) -> void:
	var dir_access = DirAccess.open(dir)
	if dir_access.get_files().size() != 0:
		InstallsIndex.warn(tr("Please select an empty folder."))
		return
	
	dir = dir + "/"
	OS.move_to_trash(ProjectSettings.globalize_path(Configurator.get_config("install_location", "user://Installs/")))
	Configurator.set_config("install_location", dir)
	$Settings/ScrollContainer/VBoxContainer/ContainerLocation/LineEdit.text = dir


func _on_option_button3_item_selected(index: int) -> void:
	Configurator.set_config("sort", index)
	_repopulate_gallery(gallery_element_list if check_list.button_pressed \
	else gallery_element_big, 1 if check_list.button_pressed else 5, true)


func _on_button_5_pressed() -> void:
	OS.shell_open(ProjectSettings.globalize_path("user://logs"))


func _on_check_button_4_toggled(toggled_on: bool) -> void:
	if not toggled_on: 
		Configurator.set_discord_status(Configurator.DiscordStatus.CLEARED)
	Configurator.set_config("discord-rpc", toggled_on)


func _on_game_viewer_viewer_closed(gallery_needs_refresh: bool) -> void:
	if gallery_needs_refresh:
		_repopulate_gallery(gallery_element_list if Configurator.get_config("list_gallery") else gallery_element_big, 1 if Configurator.get_config("list_gallery") else 5)
	create_tween().tween_property(gallery, "modulate", Color.WHITE, 0.05)
	Configurator.set_config("remembered_mod", "")
	await current_mod_game_viewer.animation_player.animation_finished
	recalculate_focused_node()


func _on_input_search_text_changed(new_text: String) -> void:
	filter_search = new_text.to_lower()
	apply_gallery_filters()


func _on_check_only_favourites_toggled(toggled_on: bool) -> void:
	Configurator.set_config("filter-favourite", toggled_on)
	filter_favourites = toggled_on
	apply_gallery_filters()


func _on_check_only_installed_toggled(toggled_on: bool) -> void:
	Configurator.set_config("filter-installed", toggled_on)
	filter_installed = toggled_on
	apply_gallery_filters()


func _on_check_button_5_toggled(toggled_on: bool) -> void:
	Configurator.set_config("minimize", toggled_on)


func _on_check_button_6_toggled(toggled_on: bool) -> void:
	Configurator.set_config("auto_subscribe", toggled_on)


func _on_input_search_text_submitted(_new_text: String) -> void:
	if filter_result_count != 1: return
	
	for child: GalleryElement in gallery.get_children():
		if child.visible: _on_mod_opened(child.idx)


func _on_h_slider_value_changed(value: float) -> void:
	Configurator.set_clear_colour_from_hue(int(value))


func _on_h_slider_drag_ended(_value_changed: bool) -> void:
	Configurator.set_config("theme-colour", $Settings/ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer/ContainerTheme/HBoxContainer/HSlider.value)


func _on_button_website_pressed() -> void:
	OS.shell_open("https://github.com/vlcoo/mvlo-modloader")


func _on_button_fix_char_pressed():
	if Configurator.os_name != "Windows": return
	InstallsIndex.warn(tr("This will reset your character to Mario in vanilla MvLO to attempt fixing this problem.\nPlease only do this once and if you're actually having issues.
	"))
	await InstallsIndex.dialog.confirmed or InstallsIndex.dialog.canceled
	var error = OS.execute("reg", ["add", "HKEY_CURRENT_USER\\Software\\ipodtouch0218\\NSMB-MarioVsLuigi", "/v", "Character_h1854990716", "/t", "REG_DWORD", "/d", "00000000", "/f"])
	if error == OK:
		InstallsIndex.toast_success()


func _on_button_choose_mod_pressed() -> void:
	InstallsIndex.warn(tr("Please choose the mod you want to see in the 'Vanilla' tab.\nCome back to Settings to cancel the operation."))
	await InstallsIndex.dialog.confirmed or InstallsIndex.dialog.canceled
	current_tab = 1
	gallery_chooser_mode = true


func _on_installs_index_operation_done(succeeded: bool, type: String) -> void:
	if succeeded and type in ["uninstall"]:
		InstallsIndex.toast_success()


func _on_option_language_item_selected(index: int) -> void:
	Configurator.set_config("translate", index > 0)
	TranslationServer.set_locale(OS.get_locale() if Configurator.get_config("translate", false) else "en")


func _on_button_reset_tours_pressed() -> void:
	Configurator.reset_tours()
	InstallsIndex.toast_success()


func _on_option_minimize_item_selected(index: int) -> void:
	Configurator.set_config("after_launch", index)
