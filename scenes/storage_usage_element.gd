extends Button
class_name StorageUsageElement

var mod_id: String = ""
var n_id: int = -1


func set_info(mod_name: String, description: String, mod_size: String, mod_icon: Texture2D = null):
	$HBoxContainer/LabelName.text = mod_name
	$HBoxContainer/LabelVersionPlatform.text = description
	$HBoxContainer/LabelSize.text = mod_size
	$HBoxContainer/TextureIcon.texture = mod_icon
	tooltip_text = mod_name + "\n" + description + "\n" + mod_size
