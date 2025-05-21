extends Node

const URL_DB: String = "https://mvloml.vlcoo.net/api/mods"

var style_focus: StyleBoxTexture = preload("res://ui_resources/style_focus.tres")

@onready var requester_db: HTTPRequest = $HTTPRequestDB
@onready var sfx: AudioStreamPlayer = $AudioStreamPlayer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var dialog: AcceptDialog = $AcceptDialog
@onready var background: ColorRect = $RectBackground

var db_request_complete = false
var regex_acronym = RegEx.new()
var controller_hint_shown = false

var mods: Array[ModData] = []
var raw_moddatas: Array = []

signal cache_updated(succeeded: bool)


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_input_joy_connection_changed)
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
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://DB/")):
		print("migrating from old ver.!! previous DB folder will be deleted.")
		Configurator.remove_recursive(ProjectSettings.globalize_path("user://DB/"))
	if FileAccess.file_exists(ProjectSettings.globalize_path("user://DB.gamefiles.json")):
		print("migrating from old ver.!! previous DB gamefiles json will be deleted.")
		print(DirAccess.remove_absolute(ProjectSettings.globalize_path("user://DB.gamefiles.json")))

	if Configurator.cache_is_old or not _check_dbs_integrity():
		print(Configurator.cache_is_old)
		print(_check_dbs_integrity())
		sync()
	else:
		await $Timer.timeout # dummy
		_populate_moddata_array(false)


func sync() -> void:
	animation_player.play("in")
	var error = requester_db.request(URL_DB)
	if error != OK: err(str(error))


func _on_requester_db_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != 0 or response_code != 200:
		err(tr("DB server unreachable.") + " " + tr("Please try again later!"))
		db_request_complete = true
		_populate_moddata_array()
		return
	
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null or not json.has("mods"):
		err(tr("DB server unreachable.") + " " + tr("Please try again later!"))
		return
	raw_moddatas = json["mods"]
	
	Configurator.update_timestamp(false)
	db_request_complete = true
	_populate_moddata_array()


func _populate_moddata_array(hide_animation: bool = true) -> void:
	var dir = DirAccess.open("user://DB-cache")
	var new_updates_list: String = ""
	if dir == null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://DB-cache"))
		dir = DirAccess.open("user://DB-cache")
	
	if raw_moddatas.is_empty():
		# no data was downloaded from the server. use cache
		for filename in dir.get_files():
			var data := ResourceLoader.load(dir.get_current_dir() + "/" + filename) as ModData
			mods.append(data)
	else:
		# cache is old. use server's data
		Configurator.remove_recursive("user://DB-cache", false)
		for mod in raw_moddatas:
			var data := ModData.new_from_json(mod)
			mods.append(data)
			ResourceSaver.save(data, "user://DB-cache/" + data.id + ".res")
	
	# new updates check
	for data in mods:
		if Configurator.get_ts_mod(data.id) != "" and int(data.timestamp) > int(Configurator.get_ts_mod(data.id)):
			Configurator.set_ts_mod(data.id, data.timestamp)
			new_updates_list += "- " + data.name.substr(0, min(data.name.length(), 30)) + "\n"

	cache_updated.emit(true)
	if hide_animation: animation_player.play("out")
	if new_updates_list != "": 
		warn(tr("New updates for mods you're subscribed to!\n{mods}").format({mods = new_updates_list}))
	
	var mod_count_before = Configurator.get_config("mod_count", 0)
	var mod_count_after = mods.size()
	if mod_count_after > mod_count_before and mod_count_before > 0: 
		warn(tr("{count} new mods have been added since the last time you checked!").format({count = str(mod_count_after - mod_count_before)}))
	Configurator.set_config("mod_count", mod_count_after)


func _check_dbs_integrity() -> bool:
	return DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://DB-cache/")) and not DirAccess.get_files_at(ProjectSettings.globalize_path("user://DB-cache/")).size() <= 0


func get_local_moddata(idx: String) -> ModData:
	var i = mods.find_custom(func(m): return m.id == idx)
	return mods[i] if i > -1 else null


func string_coincides_with_mod_names(string: String, mod_names: Array[String]) -> bool:
	var success = false
	for mod_name in mod_names:
		if _string_coincides_with_mod_name(string, mod_name):
			success = true
	return success


func _string_coincides_with_mod_name(string: String, mod_name: String) -> bool:
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
	
	dialog.title = tr("Something went wrong")
	dialog.dialog_text = tr("Some info might be out of date.") + "\n" + tr(text)
	dialog.popup_centered()
	cache_updated.emit(false)
	animation_player.play("out")


func warn(text: String):
	if dialog.visible: await dialog.confirmed or dialog.canceled
	
	dialog.title = tr("Warning")
	dialog.dialog_text = text
	dialog.popup_centered()


func _on_timer_controller_hint_timeout() -> void:
	create_tween().tween_property($ContainerControllerHints, "modulate", Color.TRANSPARENT, 1)
