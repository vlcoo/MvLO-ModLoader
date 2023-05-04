extends CanvasLayer

const URL_DB = "https://github.com/vlcoo/MvLO-ModLoader/raw/main/DB.zip"
const PATH_DB = "user://DB.zip"
const ERROR_MSG = "Database could not be downloaded! Info might be out of date.\n"

@onready var requester: HTTPRequest = $HTTPRequest
var reader: ZIPReader = ZIPReader.new()
var mod_filenames: Array

signal cache_updated


func _ready() -> void:
	pass


func update_cache() -> void:
	$AnimationPlayer.play("in")
	requester.download_file = PATH_DB
	var error: Error = requester.request(URL_DB)
	if error != OK:
		err(str(error))
		$AnimationPlayer.play("out")
		emit_signal("cache_updated")


func get_local_moddata(idx: String) -> ModData:
	var data: ModData = load("user://DB/mod_datas/" + idx + ".tres")
	data.cover_image = load("user://DB/" + idx + "C.png")
	data.icon = load("user://DB/" + idx + "I.png")
	return data


func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		err(str(response_code))

	await _unpack_db()
	$AnimationPlayer.play("out")
	emit_signal("cache_updated")


func _unpack_db() -> void:
	var error: Error = reader.open(PATH_DB)
	if error != OK:
		err("Unpacking failed. " + str(error))
		return

	for filename in reader.get_files():
		if filename.ends_with("/"):
			DirAccess.make_dir_absolute("user://" + filename)
		else:
			var file = FileAccess.open("user://" + filename, FileAccess.WRITE)
			file.store_buffer(reader.read_file(filename))
			if filename.contains("mod_datas/") and not filename.contains("vanilla"):
				mod_filenames.append(filename.replace(".tres", "").replace("DB/mod_datas/", ""))

	reader.close()


func err(text: String):
	$AcceptDialog.dialog_text = ERROR_MSG + text
	$AcceptDialog.popup_centered()


func _on_tree_exiting() -> void:
	pass
