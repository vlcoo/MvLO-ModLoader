extends CanvasLayer

const URL_DB = "https://github.com/vlcoo/MvLO-ModLoader/raw/main/DB.zip"
const PATH_DB = "user://DB.zip"
const ERROR_MSG = "Database could not be downloaded! Some info might be out of date.\n"
const KEY_GITHUB = ""
const KEY_ITCH = ""

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
	return await _load_local_moddata(idx) if not moddatas.has(idx) else moddatas[idx]


func _load_local_moddata(idx: String) -> ModData:
	var data: ModData = load("user://DB/mod_datas/" + idx + ".tres")
	data.cover_image = load("user://DB/" + idx + "C.png")
	data.icon = load("user://DB/" + idx + "I.png")

	match data.download_method:
		ModData.DownloadMethods.ITCH:
			data.gamefile_urls = await get_url_dict_itch(data.download_url)
		ModData.DownloadMethods.GITHUB:
			data.gamefile_urls = await get_url_dict_github(data.download_url)
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
	var dict: Dictionary = {"Latest version on itch.io": {}}
	var gamefiles_requester: HTTPRequest = HTTPRequest.new()
	add_child(gamefiles_requester)

	var error = gamefiles_requester.request(home_url)
	var response = await gamefiles_requester.request_completed
	var json = JSON.parse_string(response[3].get_string_from_utf8())

	var current_id = json["id"]
	error = gamefiles_requester.request("https://itch.io/api/1/" + KEY_ITCH + "/game/" + str(current_id) + "/uploads")
	response = await gamefiles_requester.request_completed
	json = JSON.parse_string(response[3].get_string_from_utf8())

	for upload in json["uploads"]:
		current_id = upload["id"]
		var filename = upload["filename"]
		error = gamefiles_requester.request("https://itch.io/api/1/" + KEY_ITCH + "/upload/" + str(current_id) + "/download")
		response = await gamefiles_requester.request_completed
		json = JSON.parse_string(response[3].get_string_from_utf8())
		dict["Latest version on itch.io"][filename] = json["url"]

	remove_child(gamefiles_requester)
	n_moddatas_versions_downloaded += 1
	if n_moddatas_versions_downloaded == moddatas.keys().size() + 1:
		emit_signal("version_list_populated")
		$AnimationPlayer.play("out")

	return dict


func get_url_dict_github(home_url: String) -> Dictionary:
	var dict: Dictionary
	var gamefiles_requester: HTTPRequest = HTTPRequest.new()
	add_child(gamefiles_requester)

	var error = gamefiles_requester.request(home_url)
	var response = await gamefiles_requester.request_completed

	if error != OK:
#		err(str(error))
#		emit_signal("version_list_populated")
#		$AnimationPlayer.play("out")
		return {"": {"": ""}}

	var json = JSON.parse_string(response[3].get_string_from_utf8())
	if not json is Dictionary:
		err("No connection." if json == null else "Response body is invalid.")
#		emit_signal("version_list_populated")
#		$AnimationPlayer.play("out")
		return {"": {"": ""}}

	if json.has("message") and json["message"].contains("limit exceeded"):
		err("You are being rate limited by GitHub.")
#		emit_signal("version_list_populated")
#		$AnimationPlayer.play("out")
		return {"": {"": ""}}

	for release in json:
		dict[release["name"]] = {}
		for asset in release["assets"]:
			dict[release["name"]][asset["name"]] = asset["browser_download_url"]

	remove_child(gamefiles_requester)
	n_moddatas_versions_downloaded += 1
	if n_moddatas_versions_downloaded == moddatas.keys().size() + 1:
		emit_signal("version_list_populated")
		$AnimationPlayer.play("out")
	return dict


func get_all_local_mods() -> void:
	$Panel/Label.text = "[center][wave]Populating version lists,\nplease wait!"
	for mod_filename in mod_filenames:
		moddatas[mod_filename] = await _load_local_moddata(mod_filename)


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
	$AcceptDialog.dialog_text = ERROR_MSG + "Cause: " + text
	$AcceptDialog.popup_centered()


func _on_tree_exiting() -> void:
	pass
