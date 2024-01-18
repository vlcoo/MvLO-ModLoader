extends CanvasLayer

var vercode: int = 4
var verdate: String = "2024-01-18"

signal updated

func _ready() -> void:
	ContentGetter.cache_updated.connect(_on_cache_updated)


func _on_cache_updated(_succeeded: bool) -> void:
	if not Configurator.cache_is_old: return
	var update_info = load("user://DB/mlupdate.tres")
	if update_info == null: return
	if update_info.vercode > vercode: _self_update(update_info)


func _self_update(update_info: SelfUpdaterUpdate) -> void:
	$AcceptDialog.dialog_text = "Date: " + update_info.date + "\nChangelog:\n" + update_info.changelog + \
		"\n\nPlease download the new release."
	$AcceptDialog.popup_centered()


func _on_accept_dialog_confirmed() -> void:
	OS.shell_open("https://github.com/vlcoo/MvLO-ModLoader/releases/latest")
