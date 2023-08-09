extends Panel

var texture_installed: TextureRect
var idx: String

signal opened


func init_ui(cover: Texture2D, display_name: String) -> void:
	texture_installed = %TextureInstalled
	if cover != null: $VBoxContainer/TextureRect.texture = cover
	$VBoxContainer/Label.text = display_name
	texture_installed.visible = InstallsIndex.mod_is_installed(idx)


func _on_mouse_entered() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_QUAD)
	InstallsIndex.mod_is_installed(idx)


func _on_mouse_exited() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), 0.1).set_trans(Tween.TRANS_QUAD)


func _on_button_pressed() -> void:
	Configurator.remembered_mod_idx = idx
	emit_signal("opened", idx)
	texture_installed.visible = InstallsIndex.mod_is_installed(idx)
