extends CanvasLayer

const URL_DB = "https://github.com/vlcoo/MvLO-ModLoader/raw/main/DB.zip"
const PATH_DB = "user://DB.zip"
const ERROR_MSG = "Database could not be downloaded! Info might be out of date.\n"

@onready var requester: HTTPRequest = $HTTPRequestDB
var reader: ZIPReader = ZIPReader.new()
var mod_filenames: Array
var moddatas: Dictionary
var n_moddatas_versions_downloaded: int = 0

signal cache_updated
signal version_list_populated


func update_cache() -> void:
	$Panel/Label.text = "[center][wave]Updating cache, please wait!"
	$AnimationPlayer.play("in")
	requester.download_file = PATH_DB

	var error: Error = requester.request(URL_DB)
	if error != OK:
		err(str(error))
		$AnimationPlayer.play("out")
		emit_signal("cache_updated")


func get_local_moddata(idx: String) -> ModData:
	return _load_local_moddata(idx) if not moddatas.has(idx) else moddatas[idx]


func _load_local_moddata(idx: String) -> ModData:
	var data: ModData = load("user://DB/mod_datas/" + idx + ".tres")
	data.cover_image = load("user://DB/" + idx + "C.png")
	data.icon = load("user://DB/" + idx + "I.png")

	match data.download_method:
		ModData.DownloadMethods.ITCH:
			data.gamefile_urls = get_url_dict_itch(data.download_url)
		ModData.DownloadMethods.GITHUB:
			data.gamefile_urls = get_url_dict_github(data.download_url)
		ModData.DownloadMethods.CUSTOM_DIRECT:
			data.gamefile_urls = {
				"Unique version": {
					"Custom file (direct download)": data.download_url
				}
			}
		ModData.DownloadMethods.CUSTOM_REDIRECT:
			data.gamefile_urls = {
				"Unique version": {
					"Redirect (opens in browser)": data.download_url
				}
			}

	return data


func get_url_dict_itch(home_url: String) -> Dictionary:
	return {}


func get_url_dict_github(home_url: String) -> Dictionary:
	var gamefiles_requester: HTTPRequest = HTTPRequest.new()
	add_child(gamefiles_requester)
	gamefiles_requester.request_completed.connect(_on_github_request_completed.bind(gamefiles_requester), CONNECT_ONE_SHOT)
	gamefiles_requester.request(home_url)
	return {}

func _on_github_request_completed(result, response_code, headers, body, requester_node):
	var json = JSON.parse_string(body.get_string_from_utf8())
	for r in json:
		print(r["name"])
		for a in r["assets"]:
			print(a["name"] + " " + a["browser_download_url"])

	remove_child(requester_node)
	n_moddatas_versions_downloaded += 1
	if n_moddatas_versions_downloaded == moddatas.keys().size() + 1:
		emit_signal("version_list_populated")
		$AnimationPlayer.play("out")


func get_all_local_mods() -> void:
	$Panel/Label.text = "[center][wave]Populating version lists,\nplease wait!"
	for mod_filename in mod_filenames:
		moddatas[mod_filename] = _load_local_moddata(mod_filename)


func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		err(str(response_code))

	_unpack_db()


func _unpack_db() -> void:
	var error: Error = reader.open(PATH_DB)
	if error != OK:
		err("Unpacking failed. " + str(error))
		return

	for filename in reader.get_files():
		if filename.ends_with("/"):
			DirAccess.make_dir_absolute("user://" + filename)
		else:
			var file = FileAccess.open("user://" + filename, FileAccess.READ_WRITE if FileAccess.file_exists("user://" + filename) else FileAccess.WRITE)
			file.store_buffer(reader.read_file(filename))
			if filename.contains("mod_datas/") and not filename.contains("vanilla"):
				mod_filenames.append(filename.replace(".tres", "").replace("DB/mod_datas/", ""))

	reader.close()
	emit_signal("cache_updated")


func err(text: String):
	$AcceptDialog.dialog_text = ERROR_MSG + text
	$AcceptDialog.popup_centered()


func _on_tree_exiting() -> void:
	pass
