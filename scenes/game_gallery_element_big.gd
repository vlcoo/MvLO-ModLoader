class_name GalleryElement
extends Panel

var idx: String
var container_index: int = 0
var title: String
var installed = false
var favourite = false

signal opened


func init_ui(cover: Texture2D, display_name: String) -> void:
	if cover != null: %TextureCover.texture = cover
	%LabelTitle.text = display_name
	title = display_name
	accessibility_name = display_name
	installed = InstallsIndex.mod_is_installed(idx)
	%TextureInstalled.visible = installed
	favourite = Configurator.get_is_mod_favourite(idx)
	%TextureFavourite.visible = favourite
	
	if has_node("ContainerIcons") and not installed and not favourite:
		$ContainerIcons.visible = false


func _on_mouse_entered() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property($Container, "scale", Vector2(0.95, 0.95), 0.1).set_trans(Tween.TRANS_QUAD)
	#ContentGetter.sfx.pitch_scale = randf_range(0.8, 1.2)
	ContentGetter.sfx.pitch_scale = [0.94387, 1.05946, 1.18921, 1.25992, 1.41421, 1.5874, 1.7818, 1.88775][container_index % 8] * 0.6
	#ContentGetter.sfx.pitch_scale = [0.94387, 1.05946, 1.12246, 1.25992, 1.41421, 1.49831, 1.68179, 1.88775][container_index % 8] * 0.8
	ContentGetter.sfx.play()


func _on_mouse_exited() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property($Container, "scale", Vector2(1, 1), 0.1).set_trans(Tween.TRANS_QUAD)


func _on_button_pressed() -> void:
	Configurator.remembered_mod_idx = idx
	opened.emit(idx)
