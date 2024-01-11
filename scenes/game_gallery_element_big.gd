class_name GalleryElement
extends Panel

var idx: String
var title: String
var installed = false
var favourite = false

signal opened


func init_ui(cover: Texture2D, display_name: String) -> void:
	if cover != null: %TextureCover.texture = cover
	%LabelTitle.text = display_name
	title = display_name
	installed = InstallsIndex.mod_is_installed(idx)
	%TextureInstalled.visible = installed
	favourite = Configurator.get_is_mod_favourite(idx)
	%TextureFavourite.visible = favourite
	
	if has_node("ContainerIcons") and not installed and not favourite:
		$ContainerIcons.visible = false


func _on_mouse_entered() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_QUAD)
	ContentGetter.sfx.pitch_scale = randf_range(0.8, 1.2)
	ContentGetter.sfx.play()


func _on_mouse_exited() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), 0.1).set_trans(Tween.TRANS_QUAD)


func _on_button_pressed() -> void:
	Configurator.remembered_mod_idx = idx
	emit_signal("opened", idx)
