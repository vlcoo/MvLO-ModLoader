extends Node

enum INTEGRITY_RESULT {
	PASS = 0,					# installed
	FAIL_NOT_IN_INDEX = 1,		# files may be there but they're not referenced in the index
	FAIL_NOT_IN_FILESYSTEM = 2			# the index references to files that don't exist
}

const INDEX_PATH: String = "user://Installs/index.tres"

@onready var progress_bar: ProgressBar = $Panel/VBoxContainer/ProgressBar
@onready var requester: HTTPRequest = $HTTPRequestGame
@onready var itch_requester: HTTPRequest = $HTTPRequestItchURL
@onready var timer: Timer = $TimerUpdateProgressbar
@onready var l_progress: Label = $Panel/VBoxContainer/Label2


var index: InstallsIndexRes
var install_in_progress: Dictionary = {}
var install_needs_wizard: bool = true

signal operation_done(succeeded: bool, type: String)


func _ready() -> void:
	# read or create installsindex resource
	index = load(INDEX_PATH) if ResourceLoader.exists(INDEX_PATH) else InstallsIndexRes.new()


func install(mod_id: String, version: String, platform: String) -> void:
	if mod_id == "" or not ContentGetter.moddatas.has(mod_id) or ContentGetter.moddatas[mod_id].gamefile_urls in [null, {}]: return

	$AnimationPlayer.play("in")
	install_in_progress = InstallsIndexRes.Install.duplicate()
	install_in_progress.mod_id = mod_id
	install_in_progress.version = version
	install_in_progress.platform = platform
	install_in_progress.timestamp = ContentGetter.moddatas[mod_id].gamefile_urls[version][platform]["timestamp"]

	var home_url: String = ContentGetter.moddatas[mod_id].gamefile_urls[version][platform]["url"]
	var dir_path: String = "user://Installs/" + mod_id + "/" + version + "/" + platform + "/"
	if not DirAccess.dir_exists_absolute(dir_path): DirAccess.make_dir_recursive_absolute(dir_path)
	requester.download_file = dir_path + "game"
	install_in_progress.dltmp_path = dir_path

	var error = 0
	if home_url.contains("itch.io/api"):
		error += itch_requester.request(home_url)
	else:
		error += requester.request(home_url)
	timer.start()
	if error != OK: err(str(error))


func _on_http_request_game_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	# unpack and add to array...
	# if it's not zip then check what kind of executable it is!!!
	l_progress.text = "Unpacking"
	timer.stop()

	var reader: ZIPReader = ZIPReader.new()
	var error: Error = reader.open(install_in_progress.dltmp_path + "game")
	if error != OK:
		err("Unpacking failed or service unavailable. " + str(error) + " " + str(response_code))
		return

	for filename in reader.get_files():
		if filename.contains("/") and not DirAccess.dir_exists_absolute(install_in_progress.dltmp_path + filename.get_base_dir()):
			DirAccess.make_dir_recursive_absolute(install_in_progress.dltmp_path + filename.get_base_dir())
		if not filename.ends_with("/"):
			var file = FileAccess.open(install_in_progress.dltmp_path + filename, FileAccess.WRITE)
			file.store_buffer(reader.read_file(filename))

			if filename.ends_with(".x86_64"):	# do it OS dependant!!!!!!
				install_in_progress.executable_path = install_in_progress.dltmp_path + filename
				if Configurator.os_name == "Linux":
					OS.execute("chmod", ["+x", ProjectSettings.globalize_path(install_in_progress.executable_path)])
				install_needs_wizard = false
			elif filename.ends_with(".exe") and not filename.to_lower().contains("crashhandler"):
				install_in_progress.executable_path = install_in_progress.dltmp_path + filename
				install_needs_wizard = false
			elif filename.ends_with(".app"):
				install_in_progress.executable_path = install_in_progress.dltmp_path + filename
				install_needs_wizard = false

	reader.close()
	index.installs.append(install_in_progress)
	install_in_progress = {}
	emit_signal("operation_done", true, "install")
	_save_index_to_file()
	$AnimationPlayer.play("out")


func launch(mod_id: String, version: String, platform: String) -> void:
	# verify integrity and execute...
	var inst: Dictionary = _find_install_in_array(mod_id, version, platform)
	if inst == null: return
	var command: String = ""
	var os_mismatch = false

	if inst.executable_path.ends_with(".x86_64"):
		command = Configurator.get_config("args_linux")
		if Configurator.os_name != "Linux": os_mismatch = true
	elif inst.executable_path.ends_with(".exe"):
		command = Configurator.get_config("args_windows")
		if Configurator.os_name != "Windows": os_mismatch = true
	elif inst.executable_path.ends_with(".app"):
		command = Configurator.get_config("args_macos")
		if Configurator.os_name != "macOS": os_mismatch = true

	if os_mismatch:
		warn("You tried launching a version of a mod not built for your OS. This might not work.")

	if command in ["", null]:
		command = ProjectSettings.globalize_path(inst.executable_path)
	else:
		command += " " + ProjectSettings.globalize_path(inst.executable_path)
	print(command)
	OS.create_process(command, [])


func uninstall(mod_id: String, version: String, platform: String) -> void:
	# delete files and remove from array...
	var install: Dictionary = _find_install_in_array(mod_id, version, platform)
	if install == {}: return
	index.installs.erase(install)
	_save_index_to_file()
	OS.move_to_trash(ProjectSettings.globalize_path(install.dltmp_path))


func show_file_explorer(mod_id: String, version: String, platform: String) -> void:
	# verify integrity and open file explorer...
	var install: Dictionary = _find_install_in_array(mod_id, version, platform)
	if install == {}: return
	OS.shell_open(ProjectSettings.globalize_path(install.dltmp_path))


func is_installed(mod_id: String, version: String, platform: String) -> INTEGRITY_RESULT:
	# check if files exist
	var in_filesystem = DirAccess.dir_exists_absolute("user://Installs/" + mod_id + "/" + version + "/" + platform)

	var result = INTEGRITY_RESULT.PASS
	if not _find_install_in_array(mod_id, version, platform) != {}:
		result |= INTEGRITY_RESULT.FAIL_NOT_IN_INDEX
	if not in_filesystem:
		result |= INTEGRITY_RESULT.FAIL_NOT_IN_FILESYSTEM
	return result


func _find_install_in_array(mod_id: String, version: String, platform: String) -> Dictionary:
	for inst in index.installs:
		if inst.mod_id == mod_id and inst.version == version and inst.platform == platform:
			return inst

	return {}


func _save_index_to_file() -> void:
	# do that lol
	ResourceSaver.save(index, INDEX_PATH)


func err(text: String):
	$AcceptDialog.dialog_text = "Can't download or install game!\n" + "Cause: " + text
	$AcceptDialog.popup_centered()
	timer.stop()
	install_in_progress = {}
	emit_signal("operation_done", false, "")
	$AnimationPlayer.play("out")


func warn(text: String):
	$AcceptDialog.dialog_text = text
	$AcceptDialog.popup_centered()


func _on_timer_update_progressbar_timeout() -> void:
	l_progress.text = str(requester.get_downloaded_bytes()/1024/1024) + " MB"
	if requester.get_body_size() == -1: return
	progress_bar.value = requester.get_downloaded_bytes() / requester.get_body_size()


func _on_http_request_itch_url_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var json = JSON.parse_string(body.get_string_from_utf8())
	requester.request(json["url"])


func _on_ready() -> void:
	$Panel.theme = Configurator.current_theme
