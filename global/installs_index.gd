extends Node

enum IntegrityResult {
	PASS = 0,					# installed
	FAIL_NOT_IN_INDEX = 1,		# files may be there but they're not referenced in the index
	FAIL_NOT_IN_FILESYSTEM = 2,	# the index references to files that don't exist
	FAIL_NO_EXE = 4				# the version downloaded doesn't have an executable for the current OS
}

enum Operation {
	IDLE, DOWNLOADING, EXTRACTING
}

const PROGRESS_TEXT_TEMPLATE = "[center][img width=16 color=#ffffff8b]res://audiovisual/%.png[/img]   "

var index_path:
	get:
		return Configurator.get_config("install_location", "user://Installs/") + "index.tres"

@onready var progress_bar: ProgressBar = $Panel/VBoxContainer/ProgressBar
@onready var requester: HTTPRequest = $HTTPRequestGame
@onready var itch_requester: HTTPRequest = $HTTPRequestItchURL
@onready var timer: Timer = $TimerUpdateProgressbar
@onready var l_progress: RichTextLabel = $Panel/VBoxContainer/ProgressBar/LabelSubtitle
@onready var dialog: AcceptDialog = $AcceptDialog
@onready var dialog_ask: ConfirmationDialog = $ConfirmationDialogRedirect
@onready var dialog_sure: ConfirmationDialog = $ConfirmationDangerous
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var background: ColorRect = $RectBackground


var index: InstallsIndexRes
var install_in_progress: Dictionary = {}
var redirect_in_progress: String = ""
var state: Operation = Operation.IDLE

signal operation_done(succeeded: bool, type: String)


func _ready() -> void:
	# read or create installsindex resource
	index = load(index_path) if ResourceLoader.exists(index_path) else InstallsIndexRes.new()
	ArchiveHandler.ExtractionComplete.connect(_on_archive_extraction_complete)
	l_progress.text = ""


func _input(event: InputEvent) -> void:
	if background.mouse_filter == Control.MOUSE_FILTER_IGNORE or animation_player.is_playing(): return
	
	if event.is_action_pressed("ui_cancel"):
		animation_player.play("refuse")


func get_total_installs_size() -> float:
	# unit is megabytes
	var mb: float = 0
	for inst in index.installs:
		# adjust for installs from v3 where size was in bytes
		if inst.has("size"): mb += inst.size/1024/1024 if inst.size > 1000000 else inst.size
	return mb


func redirect(mod_id: String, version: String, platform: String) -> void:
	var redirect_url = ContentGetter.moddatas[mod_id].gamefile_urls[version][platform]["url"]
	dialog_ask.dialog_text = "This operation will open the following website using your default browser:\n" + redirect_url + "\nContinue?"
	dialog_ask.popup_centered()
	redirect_in_progress = redirect_url


func install(mod_id: String, version: String, platform: String) -> void:
	if mod_id == "" or not ContentGetter.moddatas.has(mod_id) or ContentGetter.moddatas[mod_id].gamefile_urls in [null, {}]: return

	install_in_progress = InstallsIndexRes.Install.duplicate()
	install_in_progress.mod_id = mod_id
	install_in_progress.version = version
	install_in_progress.platform = platform
	install_in_progress.timestamp = ContentGetter.moddatas[mod_id].gamefile_urls[version][platform]["timestamp"]

	var home_url: String = ContentGetter.moddatas[mod_id].gamefile_urls[version][platform]["url"]
	var dir_path: String = Configurator.get_config("install_location", "user://Installs/") + mod_id + "/" + version + "/" + platform + "/"
	if not DirAccess.dir_exists_absolute(dir_path): DirAccess.make_dir_recursive_absolute(dir_path)
	requester.download_file = dir_path + "game"
	install_in_progress.dltmp_path = dir_path

	var error = 0
	if home_url.contains("itch.io/api"):
		error += itch_requester.request(home_url)
	else:
		error += requester.request(home_url)
		
	timer.start()
	state = Operation.DOWNLOADING
	animation_player.play("in")
	if error != OK: err(str(error))


func _on_http_request_game_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	# unpack and add to array...
	# if it's not zip then check what kind of executable it is!!!
	if result != 0 or response_code != 200:
		err("Game currently not available.\nPlease try again later! " + str(result) + " " + str(response_code))
		return
	
	state = Operation.EXTRACTING
	
	var globalized_dltmp_path: String = ProjectSettings.globalize_path(install_in_progress.dltmp_path)
	if ArchiveHandler.IsArchive(globalized_dltmp_path + "game"):
		ArchiveHandler.ExtractArchive(globalized_dltmp_path + "game", globalized_dltmp_path, false)
	else:
		err("Sorry, this mod is not compatible.\nPlease visit its website and try installing it manually.")


func _on_archive_extraction_complete(message: String, path: String, archive_was_db: bool, archive_size: int) -> void:
	if archive_was_db: return
	if message != "":
		err(message)
		return
	var extracted_files: PackedStringArray = ArchiveHandler.GetAllFilesInDirectory(path)
	if extracted_files.size() == 0:
		err("Empty archive.")
		return
	
	var install_needs_wizard = true
	for filename in extracted_files:
		if filename.ends_with(".x86_64"):	# do it OS dependant!!!!!!
			install_in_progress.executable_path = filename
			if Configurator.os_name == "Linux":
				OS.execute("chmod", ["+x", ProjectSettings.globalize_path(install_in_progress.executable_path)])
			install_needs_wizard = false
			continue
		elif filename.ends_with(".exe") and not filename.to_lower().contains("crashhandler"):
			install_in_progress.executable_path = filename
			install_needs_wizard = false
			continue
		elif filename.ends_with(".app"):
			install_in_progress.executable_path = filename
			if Configurator.os_name == "macOS":
				var potential_executables := DirAccess.get_files_at(install_in_progress.executable_path + "/Contents/MacOS")
				if potential_executables.size() == 1:
					OS.execute("chmod", ["+x", ProjectSettings.globalize_path(potential_executables[0])])
			install_needs_wizard = false
			continue

	install_in_progress.size = archive_size

	index.installs.push_front(install_in_progress)
	install_in_progress = {}
	_save_index_to_file()
	animation_player.play("out")
	state = Operation.IDLE
	timer.stop()
	operation_done.emit(true, "install")
	Configurator.set_window_state(Configurator.WindowState.ATTENTION)

	if install_needs_wizard: warn("Couldn't find an executable in the downloaded files. 'Launch' will not work.")


func launch(mod_id: String, version: String, platform: String, register_process: bool = false) -> bool:
	# verify integrity and execute...
	var inst: Dictionary = _find_install_in_array(mod_id, version, platform)
	if inst == {}:
		warn("Couldn't launch! Maybe it's corrupted?\nPlease try reinstalling this mod.")
		return false
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
	else: return false

	#if os_mismatch:
		#warn("You tried launching a version of a mod not built for your OS. This might not work.")
		#if Configurator.get_config("minimize", false):
			## make sure the user can read the warning before minimizing...
			#await dialog.confirmed or dialog.canceled

	var globalized_path: String = ProjectSettings.globalize_path(inst.executable_path)
	if Configurator.os_name == "macOS": globalized_path = "file:/" + globalized_path
	var pid: int = -1

	if command in ["", null]:
		pid = OS.create_process(globalized_path, [])
	else:
		pid = OS.create_process(command, [globalized_path])
	
	if pid == -1:
		warn("Couldn't launch game! " + \
			"Maybe it's not built for your type of device? Please choose another version."
			if os_mismatch else
			"Maybe it's corrupted or incompatible? Please visit this mod's website and try installing it manually.")
		return false
	
	if not register_process: return true
	Configurator.add_process(mod_id, version, platform, pid)
	return true


func uninstall(mod_id: String, version: String, platform: String) -> void:
	# delete files and remove from array...
	var inst: Dictionary = _find_install_in_array(mod_id, version, platform)
	if inst == {}: return
	var result = OS.move_to_trash(ProjectSettings.globalize_path(inst.dltmp_path))
	if result != OK:
		warn("A problem happened and some files might've not been deleted successfully.\n\
			Maybe the game is still running, or your device's Recycle Bin is full?
		")
	else:
		index.installs.erase(inst)
		_save_index_to_file()
	operation_done.emit(result == OK, "uninstall")


func show_file_explorer(mod_id: String, version: String, platform: String) -> void:
	# verify integrity and open file explorer...
	var inst: Dictionary = _find_install_in_array(mod_id, version, platform)
	if inst == {}: return
	if Configurator.os_name == "macOS":
		OS.create_process("open", [ProjectSettings.globalize_path(inst.dltmp_path)])
	else:
		OS.shell_open(ProjectSettings.globalize_path(inst.dltmp_path))


func is_installed(mod_id: String, version: String, platform: String) -> int:
	# check if files exist
	var in_filesystem = DirAccess.dir_exists_absolute(Configurator.get_config("install_location", "user://Installs/") + mod_id + "/" + version + "/" + platform)
	var found_install = _find_install_in_array(mod_id, version, platform)

	var result: int = IntegrityResult.PASS
	if not found_install != {}:
		result |= IntegrityResult.FAIL_NOT_IN_INDEX
	elif found_install.executable_path == "":
		result |= IntegrityResult.FAIL_NO_EXE
	if not in_filesystem:
		result |= IntegrityResult.FAIL_NOT_IN_FILESYSTEM
	return result


func _find_install_in_array(mod_id: String, version: String, platform: String) -> Dictionary:
	var found_installs: Array[Dictionary] = index.installs.filter(func(inst): return inst.mod_id == mod_id && inst.version == version && inst.platform == platform)
	return {} if found_installs.is_empty() else found_installs[0]


func mod_is_installed(mod_id: String) -> bool:
	return str(index.installs).contains("\"" + mod_id + "\"")


func _save_index_to_file() -> void:
	# do that lol
	ResourceSaver.save(index, index_path)


func err(text: String):
	if dialog.visible: await dialog.canceled or dialog.confirmed
	
	dialog.title = "Can't install game!"
	dialog.dialog_text = text
	dialog.popup_centered()
	timer.stop()
	install_in_progress = {}
	emit_signal("operation_done", false, "")
	animation_player.play("out")
	state = Operation.IDLE


func warn(text: String):
	if dialog.visible: await dialog.canceled or dialog.confirmed
	
	dialog.title = "Warning"
	dialog.dialog_text = text
	dialog.popup_centered()


func confirm(function: Callable, args: Array):
	#for c in dialog_sure.confirmed.get_connections():
		#dialog_sure.confirmed.disconnect(c.callable)
	dialog_sure.confirmed.connect(function.bindv(args), CONNECT_ONE_SHOT)
	dialog_sure.popup_centered()


@warning_ignore("integer_division")
func _on_timer_update_progressbar_timeout() -> void:
	match state:
		Operation.IDLE:
			timer.stop()
			l_progress.text = ""
			progress_bar.self_modulate = Color.TRANSPARENT
		Operation.DOWNLOADING:
			var mb_downloaded = requester.get_downloaded_bytes()/1024/1024
			var mb_total = requester.get_body_size()/1024/1024
			if mb_downloaded == mb_total:
				l_progress.text = PROGRESS_TEXT_TEMPLATE.replace("%", "loading") + "Please hold"
				progress_bar.self_modulate = Color.TRANSPARENT
			else:
				l_progress.text = PROGRESS_TEXT_TEMPLATE.replace("%", "downloading") + str(mb_downloaded) + ("" if mb_total == 0 else (" out of " + str(mb_total))) + " MB downloaded"
				progress_bar.self_modulate = Color.WHITE
				progress_bar.value = float(mb_downloaded) / maxf(mb_total, 1.0)
		Operation.EXTRACTING:
			#l_progress.text = str(ArchiveHandler.ExtractionProgressText) + "% extracted"
			l_progress.text = PROGRESS_TEXT_TEMPLATE.replace("%", "zip") + "Extracting files"
			progress_bar.self_modulate = Color.TRANSPARENT


func _on_http_request_itch_url_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != 0 or response_code != 200:
		err("Game currently not available.\nPlease try again later! " + str(result) + " " + str(response_code))
		return
	
	var json = JSON.parse_string(body.get_string_from_utf8())
	requester.request(json["url"])


func _on_ready() -> void:
	$Panel.theme = Configurator.current_theme


func _on_confirmation_dialog_redirect_confirmed() -> void:
	if redirect_in_progress == "": return
	OS.shell_open(redirect_in_progress)
	redirect_in_progress = ""
