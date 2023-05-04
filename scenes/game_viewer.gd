extends Panel

@onready var texture_cover: TextureRect = $PanelOverview/CenterContainer/VBoxContainer/TextureCover
@onready var label_title: Label = $PanelOverview/CenterContainer/VBoxContainer/LabelTitle
@onready var label_subtitle: Label = $PanelOverview/CenterContainer/VBoxContainer/LabelSubtitle
@onready var item_list: ItemList = $PanelDetail/CenterContainer/VBoxContainer/ItemList
@onready var options_version: OptionButton = $PanelDetail/CenterContainer/VBoxContainer/HBoxContainer/OptionsVersion
@onready var options_platform: OptionButton = $PanelDetail/CenterContainer/VBoxContainer/HBoxContainer/OptionsPlatform

@export var mod_data_id: String
@export var auto_refresh: bool = true
var mod_data: ModData


func _ready() -> void:
	if auto_refresh:
		mod_data_id = Configurator.remembered_mod_idx
		refresh_mod_data()


func _on_button_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game_gallery.tscn")


func refresh_mod_data() -> void:
	mod_data = ContentGetter.get_local_moddata(mod_data_id)
	if mod_data == null: return

	label_title.text = mod_data.name
	label_subtitle.text = "aka %s\nAuthor: %s\nLast updated: %s" % [mod_data.abbreviation, mod_data.author, "Never"]
	item_list.remove_item(0)
	item_list.add_item(mod_data.description, mod_data.icon)
	item_list.add_item(mod_data.link_main_website, preload("res://graphics/website.png"))
	item_list.add_item(mod_data.link_source_code, preload("res://graphics/code.png"))
	var icon_discord: Texture2D = preload("res://graphics/discord.png")
	for server in mod_data.link_discord:
		item_list.add_item(server, icon_discord)

	if mod_data.cover_image != null:
		texture_cover.texture = mod_data.cover_image
