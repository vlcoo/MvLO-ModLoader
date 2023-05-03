extends Panel


func _on_mouse_entered() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_QUAD)


func _on_mouse_exited() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), 0.1).set_trans(Tween.TRANS_QUAD)


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game_viewer.tscn")
