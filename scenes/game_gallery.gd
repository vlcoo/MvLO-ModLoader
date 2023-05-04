extends TabContainer

@onready var vanilla_game_viewer: Panel = $Vanilla/GameViewer


func _ready() -> void:
	ContentGetter.cache_updated.connect(_on_cache_updated)
	current_tab = Configurator.remembered_tab_idx


func _on_tree_exiting() -> void:
	Configurator.remembered_tab_idx = current_tab


func _on_cache_updated() -> void:
	vanilla_game_viewer.refresh_mod_data()


func _on_ready() -> void:
	ContentGetter.update_cache()
