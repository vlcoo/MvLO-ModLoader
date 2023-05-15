extends Panel

@onready var texture_cover: TextureRect = $PanelOverview/CenterContainer/VBoxContainer/TextureCover
@onready var label_title: Label = $PanelOverview/CenterContainer/VBoxContainer/LabelTitle
@onready var label_subtitle: Label = $PanelOverview/CenterContainer/VBoxContainer/LabelSubtitle
@onready var item_list: ItemList = $PanelDetail/CenterContainer/VBoxContainer/ItemList
@onready var options_version: OptionButton = $PanelDetail/CenterContainer/VBoxContainer/HBoxContainer/OptionsVersion
@onready var options_platform: OptionButton = $PanelDetail/CenterContainer/VBoxContainer/HBoxContainer/OptionsPlatform
@onready var button_install: Button = $PanelDetail/CenterContainer/VBoxContainer/HBoxContainer2/ButtonInstall
@onready var button_launch: Button = $PanelDetail/CenterContainer/VBoxContainer/HBoxContainer2/ButtonLaunch
@onready var button_uninstall: Button = $PanelDetail/CenterContainer/VBoxContainer/HBoxContainer2/ButtonUninstall
@onready var button_browse: Button = $PanelDetail/CenterContainer/VBoxContainer/HBoxContainer2/ButtonBrowse


var nodata_texture: Texture2D = preload("res://graphics/nodata.png")
var platform_apple_texture: Texture2D = preload("res://graphics/apple.png")
var platform_linux_texture: Texture2D = preload("res://graphics/linux.png")
var platform_windows_texture: Texture2D = preload("res://graphics/windows.png")

@export var mod_data_id: String
@export var auto_refresh: bool = true
var mod_data: ModData
var texture_installed: Texture2D


func _ready() -> void:
	if auto_refresh && mod_data_id != "":
		mod_data_id = Configurator.remembered_mod_idx
		await refresh_mod_data()


func _on_button_back_pressed() -> void:
	$AnimationPlayer.play("out")


func refresh_mod_data() -> void:
	mod_data = ContentGetter.get_local_moddata(mod_data_id)
	if mod_data == null: return
	clear_all()
	$AnimationPlayer.play("in")

	label_title.text = mod_data.name
	var subtitle: String = "Author: %s\nLast updated: %s" % [mod_data.author, Time.get_date_string_from_unix_time(int(mod_data.timestamp))]
	if mod_data.abbreviation != "": subtitle = "aka %s\n%s" % [mod_data.abbreviation, subtitle]
	label_subtitle.text = subtitle
	item_list.add_item(mod_data.description, mod_data.icon)
	item_list.add_item(mod_data.link_main_website, preload("res://graphics/website.png"))
	item_list.add_item(mod_data.link_source_code, preload("res://graphics/code.png"))
	var icon_discord: Texture2D = preload("res://graphics/discord.png")
	for server in mod_data.link_discord:
		item_list.add_item(server, icon_discord)

	$PanelDetail/CenterContainer/VBoxContainer/CheckButton.button_pressed = Configurator.get_ts_mod(mod_data_id) != ""
	texture_cover.texture = mod_data.cover_image if mod_data.cover_image != null else nodata_texture
	for release in mod_data.gamefile_urls.keys():
		options_version.add_item(release)
	_on_options_version_item_selected(options_version.selected)


func clear_all():
	item_list.clear()
	options_version.clear()
	options_platform.clear()


func _on_options_version_item_selected(index: int) -> void:
	if mod_data.gamefile_urls == {}: return
	var show_all = Configurator.get_config("all_platforms")
	if show_all is String: show_all = show_all != ""

	options_platform.clear()
	for asset in mod_data.gamefile_urls[options_version.get_item_text(index)].keys():
		var platform_icon: Texture2D = get_platform_icon(asset)
		var filename: String = asset.to_lower()
		if (not show_all) and (\
			(filename.contains("win") and Configurator.os_name != "Windows") or \
			(filename.contains("linux") and Configurator.os_name != "Linux") or \
			((filename.contains("apple") or filename.contains("mac")) and Configurator.os_name != "macOS") or \
			(filename.contains("web")) \
		): continue
		if platform_icon == null:
			options_platform.add_item(asset)
		else:
			options_platform.add_icon_item(platform_icon, asset)
	_on_options_platform_item_selected(options_platform.selected)


func _on_options_platform_item_selected(index: int) -> void:
	var already_installed = (InstallsIndex.is_installed(mod_data_id, options_version.get_item_text(options_version.selected), options_platform.get_item_text(index)) & (InstallsIndex.INTEGRITY_RESULT.FAIL_NOT_IN_FILESYSTEM | InstallsIndex.INTEGRITY_RESULT.FAIL_NOT_IN_INDEX)) == 0
	set_buttons_state(already_installed)


func get_platform_icon(filename: String) -> Texture2D:
	filename = filename.to_lower()

	if filename.contains("win") or filename.contains(".exe"):
		return platform_windows_texture
	if filename.contains("linux") or filename.contains("unix"):
		return platform_linux_texture
	if filename.contains("apple") or filename.contains("mac"):
		return platform_apple_texture

	return null


func set_buttons_state(installed: bool) -> void:
	button_install.disabled = installed
	button_install.visible = not installed
	button_uninstall.visible = installed
	button_launch.visible = installed
	button_browse.visible = installed


func _on_button_install_pressed() -> void:
	button_install.disabled = true
	InstallsIndex.operation_done.connect(_on_installs_index_done, CONNECT_ONE_SHOT)
	InstallsIndex.install(mod_data_id, options_version.get_item_text(options_version.selected), options_platform.get_item_text(options_platform.selected))


func _on_button_launch_pressed() -> void:
	InstallsIndex.launch(mod_data_id, options_version.get_item_text(options_version.selected), options_platform.get_item_text(options_platform.selected))
	button_launch.text = "Loading"
	button_launch.disabled = true
	$TimerLoading.start()


func _on_button_uninstall_pressed() -> void:
	InstallsIndex.uninstall(mod_data_id, options_version.get_item_text(options_version.selected), options_platform.get_item_text(options_platform.selected))
	_on_options_platform_item_selected(options_platform.selected)


func _on_button_browse_pressed() -> void:
	InstallsIndex.show_file_explorer(mod_data_id, options_version.get_item_text(options_version.selected), options_platform.get_item_text(options_platform.selected))


func _on_installs_index_done(succeeded: bool, type: String) -> void:
	if not succeeded: return

	match type:
		"install":
			set_buttons_state(true)


func _on_item_list_item_activated(index: int) -> void:
	if $PanelDetail/CenterContainer/VBoxContainer/ItemList.get_item_text(index).begins_with("https://"):
		OS.shell_open($PanelDetail/CenterContainer/VBoxContainer/ItemList.get_item_text(index))


func _on_timer_loading_timeout() -> void:
	if button_launch.disabled and button_launch.visible and button_launch.text == "Loading":
		button_launch.disabled = false
		button_launch.text = "Launch"


func _on_check_button_toggled(button_pressed: bool) -> void:
	Configurator.set_ts_mod(mod_data_id, mod_data.timestamp if button_pressed else "")
