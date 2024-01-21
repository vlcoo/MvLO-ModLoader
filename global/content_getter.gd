extends Node

const URL_DB: String = "https://github.com/vlcoo/MvLO-ModLoader/raw/v3-c%23/DB.tar"
const URL_GAMEFILES: String = "http://mvloml.vlcoo.net/DB.gamefiles.json"

var style_focus: StyleBoxTexture = preload("res://ui_resources/style_focus.tres")

@onready var requester_db: HTTPRequest = $HTTPRequestDB
@onready var requester_gamefiles: HTTPRequest = $HTTPRequestGamefiles
@onready var sfx: AudioStreamPlayer = $AudioStreamPlayer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var dialog: AcceptDialog = $AcceptDialog
@onready var background: ColorRect = $RectBackground

var db_request_complete = false
var gamefiles_request_complete = false
var regex_acronym = RegEx.new()
var controller_hint_shown = false

var moddatas: Dictionary = {}

signal cache_updated(succeeded: bool)


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_input_joy_connection_changed)
	ArchiveHandler.ExtractionComplete.connect(_on_archive_extraction_complete)
	regex_acronym.compile("\\b[\\w\\']+?\\b")


func _input(event: InputEvent) -> void:
	if background.mouse_filter == Control.MOUSE_FILTER_IGNORE or animation_player.is_playing(): return
	
	if event.is_action_pressed("ui_cancel"):
		animation_player.play("refuse")


func _on_input_joy_connection_changed(_device: int, connected: bool) -> void:
	style_focus.modulate_color = Color.WHITE if connected else Color.WHITE * 0.4
	
	if connected:
		$TimerControllerHint.start(2 if controller_hint_shown else 6)
		$ContainerControllerHints.modulate = Color.WHITE
		controller_hint_shown = true


func _on_ready() -> void:
	$Panel.theme = Configurator.current_theme

	if Configurator.cache_is_old or not _check_dbs_integrity():
		animation_player.play("in")
		var error = requester_db.request(URL_DB) + requester_gamefiles.request(URL_GAMEFILES)
		if error != OK: err(str(error))
	else:
		await $Timer.timeout # dummy
		_populate_moddata_array(false)


func _on_requester_db_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != 0 or response_code != 200:
		err("DB server unavailable. Try again later!")
		db_request_complete = true
		if gamefiles_request_complete: _populate_moddata_array()
		return
	
	ArchiveHandler.ExtractArchive(ProjectSettings.globalize_path(requester_db.download_file), OS.get_user_data_dir(), true)


func _on_archive_extraction_complete(message: String, _path: String, archive_was_db: bool, _archive_size: int) -> void:
	if not archive_was_db: return
	
	if message == "":
		db_request_complete = true
		if gamefiles_request_complete: _populate_moddata_array()
	else:
		err(message)


func _on_requester_gamefiles_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != 0 or response_code != 200:
		err("Gamefile server unavailable. Try again later!")
	else:
		Configurator.update_timestamp(false)
	gamefiles_request_complete = true
	if db_request_complete: _populate_moddata_array()


func _populate_moddata_array(hide_animation: bool = true) -> void:
	if not _check_dbs_integrity():
		err("Important files have gone missing. Please restart the program!")
		return

	var json = JSON.parse_string(FileAccess.get_file_as_string("user://DB.gamefiles.json"))
	var dir = DirAccess.open("user://DB/mod_datas")
	var new_updates_list: String = ""
	if dir == null:
		Configurator.update_timestamp(true)
		err("DB hasn't been downloaded properly. Please restart the program!")
		return
	if json == null:
		Configurator.update_timestamp(true)
		err("Gamefiles haven't been downloaded properly. Please restart the program or try again later!")

	for filename in dir.get_files():	# for each mod in the database...
		var mod_id: String = filename.replace(".tres", "")
		var data := load(dir.get_current_dir() + "/" + filename) as ModData
		var tmp_image: Image = Image.new()
		if FileAccess.file_exists("user://DB/" + mod_id + "C.png"):
			tmp_image.load("user://DB/" + mod_id + "C.png")
			data.cover_image = ImageTexture.create_from_image(tmp_image)
		if FileAccess.file_exists("user://DB/" + mod_id + "I.png"):
			tmp_image.load("user://DB/" + mod_id + "I.png")
			data.icon = ImageTexture.create_from_image(tmp_image)
		if json != null:
			if not json.has(mod_id): continue
			var max_ts: int = 0
			data.gamefile_urls = json[mod_id]
			for version in data.gamefile_urls:
				for asset in data.gamefile_urls[version]:
					if int(data.gamefile_urls[version][asset]["timestamp"]) > max_ts: max_ts = int(data.gamefile_urls[version][asset]["timestamp"])
			data.timestamp = str(max_ts)
			if Configurator.get_ts_mod(mod_id) != "" and int(data.timestamp) > int(Configurator.get_ts_mod(mod_id)):
				Configurator.set_ts_mod(mod_id, data.timestamp)
				new_updates_list += "- " + data.name.substr(0, min(data.name.length(), 30)) + "\n"
		data.idx = mod_id
		moddatas[mod_id] = data

	emit_signal("cache_updated", true)
	if hide_animation: animation_player.play("out")
	if new_updates_list != "": 
		warn("New updates for mods you're subscribed to!\n" + new_updates_list)
	
	var mod_count_before = Configurator.get_config("mod_count", 0)
	var mod_count_after = moddatas.size()
	if mod_count_after > mod_count_before and mod_count_before > 0: 
		warn(str(mod_count_after - mod_count_before) + " new mods have been added since the last time you checked!")
	Configurator.set_config("mod_count", mod_count_after)


func _check_dbs_integrity() -> bool:
	return FileAccess.file_exists("user://DB.gamefiles.json") and DirAccess.dir_exists_absolute("user://DB")


func get_local_moddata(idx: String) -> ModData:
	return moddatas[idx] if moddatas.has(idx) else null


func string_coincides_with_mod_name(string: String, mod_name: String) -> bool:
	mod_name = mod_name.to_lower().replace("-", " ")
	for c in ["'", "."]:
		mod_name = mod_name.replace(c, "")
	
	var acronym = ""
	var matches = regex_acronym.search_all(mod_name)
	for m in matches:
		acronym += m.get_string()[0]
	
	return string == "" or string in mod_name or string in acronym


func err(text: String):
	if dialog.visible: await dialog.confirmed or dialog.canceled
	
	dialog.title = "Something went wrong"
	dialog.dialog_text = "Some info might be out of date.\n" + text
	dialog.popup_centered()
	emit_signal("cache_updated", false)
	animation_player.play("out")


func warn(text: String):
	if dialog.visible: await dialog.confirmed or dialog.canceled
	
	dialog.title = "Warning"
	dialog.dialog_text = text
	dialog.popup_centered()


func _on_timer_controller_hint_timeout() -> void:
	create_tween().tween_property($ContainerControllerHints, "modulate", Color.TRANSPARENT, 1)
