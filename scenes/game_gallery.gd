extends TabContainer

@onready var vanilla_game_viewer: Panel = $Vanilla/GameViewer
@onready var current_mod_game_viewer: Panel = $Mods/GameViewer
var mod_game_entry_panel = preload("res://scenes/game_gallery_element_big.tscn")


func _ready() -> void:
	current_mod_game_viewer.get_node("AnimationPlayer").play("out")
#	ContentGetter.cache_updated.connect(_on_cache_updated)
	current_tab = Configurator.remembered_tab_idx


func _on_tree_exiting() -> void:
	Configurator.remembered_tab_idx = current_tab


func _on_cache_updated() -> void:
	vanilla_game_viewer.refresh_mod_data()
#	if not Configurator.remembered_cache_already_updated:
#		await ContentGetter.get_all_local_mods()
	Configurator.remembered_cache_already_updated = true

#	for mod in ContentGetter.moddatas.keys():
#		var child = mod_game_entry_panel.instantiate()
#		var moddata: ModData = ContentGetter.moddatas[mod]
#		child.idx = mod
#		child.opened.connect(_on_mod_opened)
#		child.init_ui(moddata.cover_image, moddata.name)
#		$Mods/ContainerBig/GridContainer.add_child(child)


func _on_ready() -> void:
	pass
#	if not Configurator.remembered_cache_already_updated:
#		ContentGetter.update_cache()
#	else:
#		_on_cache_updated()


func _on_mod_opened(idx: String):
	current_mod_game_viewer.mod_data_id = idx
	current_mod_game_viewer.refresh_mod_data()
