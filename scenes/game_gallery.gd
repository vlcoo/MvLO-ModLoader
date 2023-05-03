extends TabContainer


func _ready() -> void:
	current_tab = Configurator.remembered_tab_idx


func _on_tree_exiting() -> void:
	Configurator.remembered_tab_idx = current_tab
