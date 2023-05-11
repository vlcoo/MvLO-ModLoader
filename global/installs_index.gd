extends Node

@onready var progress_bar: ProgressBar = $Panel/VBoxContainer/ProgressBar
@onready var requester: HTTPRequest = $HTTPRequestGame
@onready var timer: Timer = $TimerUpdateProgressbar
@onready var l_progress: Label = $Panel/VBoxContainer/Label2


var index: InstallsIndexRes
var install_in_progress: InstallsIndexRes.Install

signal operation_done(succeeded: bool, type: String)


func _ready() -> void:
	# read or create installsindex resource
	pass


func install(mod_id: String, version: String, platform: String) -> void:
	if mod_id == "" or not ContentGetter.moddatas.has(mod_id) or ContentGetter.moddatas[mod_id].gamefile_urls in [null, {}]: return

	$AnimationPlayer.play("in")
	install_in_progress = InstallsIndexRes.Install.new()
	install_in_progress.mod_id = mod_id
	install_in_progress.version = version
	install_in_progress.platform = platform
	install_in_progress.timestamp = ContentGetter.moddatas[mod_id].gamefile_urls[version][platform]["timestamp"]

	var home_url: String = ContentGetter.moddatas[mod_id].gamefile_urls[version][platform]["url"]
	var dir_path: String = "user://Installs/" + mod_id + "/" + version + "/" + platform + "/"
	if not DirAccess.dir_exists_absolute(dir_path): DirAccess.make_dir_recursive_absolute(dir_path)
	requester.download_file = dir_path + "game"
	install_in_progress.dltmp_path = dir_path
	var error = requester.request(home_url)
	timer.start()
	if error != OK: err(str(error))


func _on_http_request_game_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	# unpack and add to array...
	# if it's not zip then check what kind of executable it is!!!
	timer.stop()
	l_progress.text = "Unpacking"

	var reader: ZIPReader = ZIPReader.new()
	var error: Error = reader.open(install_in_progress.dltmp_path + "game")
	if error != OK:
		err("Unpacking failed. " + str(error))
		return

	for filename in reader.get_files():
		if filename.contains("/") and not DirAccess.dir_exists_absolute(install_in_progress.dltmp_path + filename.get_base_dir()):
			DirAccess.make_dir_absolute(install_in_progress.dltmp_path + filename.get_base_dir())
		if not filename.ends_with("/"):
			var file = FileAccess.open(install_in_progress.dltmp_path + filename, FileAccess.WRITE)
			file.store_buffer(reader.read_file(filename))
			if filename.ends_with(".x86_64"):	# do it OS dependant!!!!!!
				install_in_progress.executable_path = install_in_progress.dltmp_path + filename
				var out = []
				OS.execute("chmod", ["+x", OS.get_user_data_dir() + install_in_progress.executable_path.replace("user:/", "")], out)
				print(out)

	reader.close()
	index.installs.append(install_in_progress)
	install_in_progress = null
	emit_signal("operation_done", true, "install")
	$AnimationPlayer.play("out")


func launch(mod_id: String, version: String, platform: String) -> void:
	# verify integrity and execute...
	var inst: InstallsIndexRes.Install = _find_install_in_array(mod_id, version, platform)
	if inst == null: return
	OS.create_process(OS.get_user_data_dir() + inst.executable_path.replace("user:/", ""), [], true)


func uninstall(mod_id: String, version: String, platform: String) -> void:
	# delete files and remove from array...
	pass


func show_file_explorer(mod_id: String, version: String, platform: String) -> void:
	# verify integrity and open file explorer...
	pass


func is_installed(mod_id: String, version: String, platform: String) -> bool:
	# check if files exist
	return false


func _find_install_in_array(mod_id: String, version: String, platform: String) -> InstallsIndexRes.Install:
	for inst in index.installs:
		if inst.mod_id == mod_id and inst.version == version and inst.platform == platform:
			return inst

	return null


func _save_index_to_file() -> void:
	# do that lol
	pass


func err(text: String):
	$AcceptDialog.dialog_text = "Can't download or install game!\n" + "Cause: " + text
	$AcceptDialog.popup_centered()
	timer.stop()
	install_in_progress = null
	emit_signal("operation_done", false, "")
	$AnimationPlayer.play("out")


func _on_timer_update_progressbar_timeout() -> void:
	l_progress.text = str(requester.get_downloaded_bytes()/1024/1024) + " MB"
	if requester.get_body_size() == -1: return
	progress_bar.value = requester.get_downloaded_bytes() / requester.get_body_size()
