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


var nodata_texture: Texture2D = preload("res://graphics/nodata.png")
var platform_apple_texture: Texture2D = preload("res://graphics/apple.png")
var platform_linux_texture: Texture2D = preload("res://graphics/linux.png")
var platform_windows_texture: Texture2D = preload("res://graphics/windows.png")

@export var mod_data_id: String
@export var auto_refresh: bool = true
var mod_data: ModData


func _ready() -> void:
	if auto_refresh && mod_data_id != "":
		mod_data_id = Configurator.remembered_mod_idx
		await refresh_mod_data()


func _on_button_back_pressed() -> void:
	$AnimationPlayer.play("out")


func refresh_mod_data() -> void:
	mod_data = await ContentGetter.get_local_moddata(mod_data_id)
	if mod_data == null: return
	clear_all()
	$AnimationPlayer.play("in")

	label_title.text = mod_data.name
	label_subtitle.text = "aka %s\nAuthor: %s\nLast updated: %s" % [mod_data.abbreviation, mod_data.author, "Never"]
	item_list.add_item(mod_data.description, mod_data.icon)
	item_list.add_item(mod_data.link_main_website, preload("res://graphics/website.png"))
	item_list.add_item(mod_data.link_source_code, preload("res://graphics/code.png"))
	var icon_discord: Texture2D = preload("res://graphics/discord.png")
	for server in mod_data.link_discord:
		item_list.add_item(server, icon_discord)

	texture_cover.texture = mod_data.cover_image if mod_data.cover_image != null else nodata_texture
	for release in mod_data.gamefile_urls.keys():
		options_version.add_item(release)
	_on_options_version_item_selected(options_version.selected)


func clear_all():
	item_list.clear()
	options_version.clear()
	options_platform.clear()


func _on_options_version_item_selected(index: int) -> void:
	options_platform.clear()
	for asset in mod_data.gamefile_urls[options_version.get_item_text(index)].keys():
		var platform_icon: Texture2D = get_platform_icon(asset)
		if platform_icon == null:
			options_platform.add_item(asset)
		else:
			options_platform.add_icon_item(platform_icon, asset)
	_on_options_platform_item_selected(options_platform.selected)


func _on_options_platform_item_selected(index: int) -> void:
	var already_installed = ContentGetter.check_for_local_gamefiles(mod_data_id, options_version.get_item_text(options_version.selected), options_platform.get_item_text(index))

	button_install.disabled = already_installed
	button_launch.disabled = not already_installed
	button_uninstall.disabled = not already_installed


func get_platform_icon(filename: String) -> Texture2D:
	filename = filename.to_lower()

	if filename.contains("win") or filename.contains(".exe"):
		return platform_windows_texture
	if filename.contains("linux") or filename.contains("unix"):
		return platform_linux_texture
	if filename.contains("apple") or filename.contains("mac"):
		return platform_apple_texture

	return null


func _on_button_install_pressed() -> void:
	button_install.disabled = true
	ContentGetter.download_gamefile(mod_data.gamefile_urls[options_version.get_item_text(options_version.selected)][options_platform.get_item_text(options_platform.selected)])


func _on_button_launch_pressed() -> void:
	pass # Replace with function body.


func _on_button_uninstall_pressed() -> void:
	pass # Replace with function body.
