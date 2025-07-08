class_name GameViewer
extends Panel

const TEMPLATE_SUBTITLE := "[img]res://audiovisual/person.png[/img]  %s\n[img]res://audiovisual/calendar.png[/img]  %s"

@onready var texture_cover: TextureRect = $PanelOverview/CenterContainer/VBoxContainer/TextureCover
@onready var label_title: Label = $PanelOverview/CenterContainer/VBoxContainer/LabelTitle
@onready var label_subtitle: RichTextLabel = $PanelOverview/CenterContainer/VBoxContainer/HBoxContainer/LabelSubtitle
@onready var item_list: ItemList = $PanelDetail/CenterContainer/VBoxContainer/Panel/MarginContainer/VBoxContainer/ItemList
@onready var label_timer: Label = $PanelDetail/CenterContainer/VBoxContainer/ContainerTimer/Label
@onready var options_version: OptionButton = $PanelDetail/CenterContainer/VBoxContainer/ContainerVersions/OptionsVersion
@onready var options_platform: OptionButton = $PanelDetail/CenterContainer/VBoxContainer/ContainerVersions/OptionsPlatform
@onready var button_install: Button = $PanelDetail/CenterContainer/VBoxContainer/ContainerButtons/ButtonInstall
@onready var button_launch: Button = $PanelDetail/CenterContainer/VBoxContainer/ContainerButtons/ButtonLaunch
@onready var button_uninstall: Button = $PanelDetail/CenterContainer/VBoxContainer/ContainerButtons/ButtonUninstall
@onready var button_browse: Button = $PanelDetail/CenterContainer/VBoxContainer/ContainerButtons/ButtonBrowse
@onready var button_files: MenuButton = $PanelDetail/CenterContainer/VBoxContainer/ContainerButtons/ButtonFileMgmt
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var text_description: TextEdit = $PanelDetail/CenterContainer/VBoxContainer/Panel/MarginContainer/VBoxContainer/TextDescription
@onready var texture_icon: TextureRect = $PanelOverview/CenterContainer/VBoxContainer/HBoxContainer/TextureIcon

var nodata_texture: Texture2D = preload("res://audiovisual/nodata.png")
var discord_texture: Texture2D = preload("res://audiovisual/discord.png")
var code_texture: Texture2D = preload("res://audiovisual/code.png")
var version_texture: Texture2D = preload("res://audiovisual/version.png")
var website_texture: Texture2D = preload("res://audiovisual/website.png")
var platform_apple_texture: Texture2D = preload("res://audiovisual/apple.png")
var platform_linux_texture: Texture2D = preload("res://audiovisual/linux.png")
var platform_windows_texture: Texture2D = preload("res://audiovisual/windows.png")
var platform_redirect_texture: Texture2D = preload("res://audiovisual/redirect.png")
var fire_texture: Texture2D = preload("res://audiovisual/fire.png")
var uninstall_texture: Texture2D = preload("res://audiovisual/uninstall.png")

@export var mod_data_id: String
@export var auto_refresh: bool = true
@export var is_vanilla_tab: bool = false
var mod_data: ModData
var is_mod_running: bool = false
var done_critical_operation: bool = false

signal viewer_closed(critical_operation_done: bool)


func _ready() -> void:
	if is_vanilla_tab:
		mod_data_id = Configurator.vanilla_id
		label_title.visible = mod_data_id != "vanilla"
	
	if auto_refresh && mod_data_id != "":
		mod_data_id = Configurator.remembered_mod_idx
		refresh_mod_data()

	Configurator.process_ended.connect(_on_mod_closed)
	button_files.get_popup().id_pressed.connect(_on_button_files_id_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if InstallsIndex.background.mouse_filter != MOUSE_FILTER_IGNORE: return
	
	if event.is_action_pressed("ui_cancel"):
		_on_button_back_pressed()


func _on_button_back_pressed() -> void:
	if not visible or not $PanelOverview/ButtonBack.visible: return
	animation_player.play("out")
	#await animation_player.animation_finished
	viewer_closed.emit(done_critical_operation)


func refresh_mod_data() -> bool:
	if mod_data_id != "": mod_data = ContentGetter.get_local_moddata(mod_data_id)
	if mod_data_id == "" or mod_data == null: return false
	clear_all()
	done_critical_operation = false

	label_title.text = mod_data.name
	var last_updated = tr("Never Updated") if mod_data.timestamp == "0" else Time.get_date_string_from_unix_time(int(mod_data.timestamp))
	var subtitle: String = TEMPLATE_SUBTITLE % [mod_data.author, last_updated]
	#if mod_data.abbreviation != "": subtitle = "aka %s\n%s" % [mod_data.abbreviation, subtitle]
	label_subtitle.text = subtitle
	text_description.text = mod_data.description
	if mod_data.icon == null: 
		texture_icon.visible = false
		label_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else: 
		texture_icon.texture = mod_data.icon
		texture_icon.visible = true
		label_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	#item_list.add_item(mod_data.description, mod_data.icon, false)
	#else: item_list.add_item("Description unavailable.", null, false)
	if mod_data_id != "vanilla" and mod_data.base_version != "": item_list.add_item(tr("Based on version {version}.").format({version = mod_data.base_version}), version_texture, false)
	if mod_data.link_main_website != "": item_list.add_item(mod_data.link_main_website, website_texture, false)
	if mod_data.link_source_code != "": item_list.add_item(mod_data.link_source_code, code_texture, false)
	for server in mod_data.link_discord:
		if server != "": item_list.add_item(server, discord_texture, false)

	_refresh_time_played()
	$PanelOverview/CheckFavourite.button_pressed = Configurator.get_is_mod_favourite(mod_data_id)

	$PanelDetail/CenterContainer/VBoxContainer/CheckSubscribe.button_pressed = Configurator.get_ts_mod(mod_data_id) != ""
	texture_cover.texture = mod_data.cover_image if mod_data.cover_image != null else nodata_texture
	for version in mod_data.get_gamefiles_versions():
		options_version.add_item(version)
	options_version.visible = options_version.item_count > 1
	_on_options_version_item_selected(options_version.selected)
	
	animation_player.play("in")
	if get_parent().visible:
		$PanelDetail/CenterContainer/VBoxContainer/ContainerButtons.grab_focus.call_deferred()
	return true


@warning_ignore("integer_division")
func _refresh_time_played():
	var time_played_seconds = Configurator.get_timer_mod(mod_data_id)
	if time_played_seconds <= 0:
		label_timer.text = tr("Never played.")
	elif time_played_seconds > 0 and time_played_seconds < 60:
		label_timer.text = tr("Played for a few seconds.")
	#elif time_played_seconds >= 60 and time_played_seconds < 3600:
		#label_timer.text = "Played for " + str(time_played_seconds / 60) + " minute" + ("" if time_played_seconds < 120 else "s") + "."
	#elif time_played_seconds >= 3600:
		#label_timer.text = "Played for " + str(time_played_seconds / 3600) + " hour" + ("" if time_played_seconds < 7200 else "s") + "."
	elif time_played_seconds >= 60 and time_played_seconds < 3600:
		var time = str(time_played_seconds / 60)
		var unit = tr_n("minute", "minutes", time_played_seconds / 120)
		label_timer.text = tr("Played for {time} {unit}.").format({time = time, unit = unit})
	elif time_played_seconds >= 3600:
		var time = str(time_played_seconds / 3600)
		var unit = tr_n("hour", "hours", time_played_seconds / 7200)
		label_timer.text = tr("Played for {time} {unit}.").format({time = time, unit = unit})


func clear_all():
	item_list.clear()
	options_version.clear()
	options_platform.clear()


func _on_options_version_item_selected(index: int) -> void:
	var show_all = Configurator.get_config("all_platforms")
	if show_all is String: show_all = show_all != ""
	
	# double check for no versions found. first, if no links were given by the server...
	if mod_data.gamefile_urls.is_empty():
		_on_no_downloads_found(show_all)
		return

	options_platform.clear()
	options_platform.disabled = false
	var version = options_version.get_item_text(index)
	#var platforms_dict = mod_data.gamefile_urls[options_version.get_item_text(index)]
	var sorted_platform_assets = []
	for gamefiles in mod_data.get_gamefiles_version(version):
		sorted_platform_assets.append(gamefiles["platform"])
	sorted_platform_assets.sort_custom(func(a, b):
		var integrity_result_a = InstallsIndex.is_installed(mod_data_id, options_version.get_item_text(options_version.selected), a)
		var integrity_result_b = InstallsIndex.is_installed(mod_data_id, options_version.get_item_text(options_version.selected), b)
		# points based sorting of platforms dropdown
		var pts_a = 0
		var pts_b = 0
		# give one point if item is compatible with device os
		pts_a += int(_platform_asset_coincides_with_os(a))
		pts_b += int(_platform_asset_coincides_with_os(b))
		# give two (more important) points if item is installed
		pts_a += int(integrity_result_a == 0) * 2
		pts_b += int(integrity_result_b == 0) * 2
		# give three (even more important) points if item is a newer release (only applicable to itch.io distribs)
		if options_version.item_count <= 1 and options_version.get_item_text(0).contains("itch"):
			pts_a += int(mod_data.get_gamefiles_url(version, a)["timestamp"] > mod_data.get_gamefiles_url(version, b)["timestamp"]) * 3
			pts_b += int(mod_data.get_gamefiles_url(version, b)["timestamp"] > mod_data.get_gamefiles_url(version, a)["timestamp"]) * 3
		# more points = more at the beginning of array
		return pts_a > pts_b
	)
	for asset: String in sorted_platform_assets:
		var platform_icon: Texture2D = get_platform_icon(asset)
		if not show_all and (asset.to_lower().contains("web") or not _platform_asset_coincides_with_os(asset)):
			continue
		if platform_icon == null:
			options_platform.add_item(asset)
		else:
			options_platform.add_icon_item(platform_icon, asset)
	
	# ...secondly, if none of the links made it to the dropdown.
	if options_platform.item_count <= 0:
		_on_no_downloads_found(show_all)
		return
	
	_on_options_platform_item_selected(options_platform.selected)


func _platform_asset_coincides_with_os(a: String) -> bool:
	a = a.to_lower()
	if a.contains("web"): return false
	return (a.contains("win") and Configurator.os_name == "Windows") or \
	((a.contains("linux") or a.contains("unix")) and Configurator.os_name == "Linux") or \
	((a.contains("apple") or a.contains("mac")) and Configurator.os_name == "macOS") or not \
	(a.contains("win") or a.contains("linux") or a.contains("unix") or a.contains("apple") or a.contains("mac"))


func _on_no_downloads_found(show_all: bool) -> void:
	options_platform.disabled = true
	options_platform.add_item("???")
	var msg = tr("No downloads found.") if show_all else tr("No downloads found for your OS.")
	msg += "\n"
	msg += tr("Try enabling \"Show all platforms\" in Settings!")
	InstallsIndex.warn(msg)
	set_buttons_state(false, false, false, false)


func _on_options_platform_item_selected(index: int) -> void:
	var IntegrityResult = InstallsIndex.is_installed(mod_data_id, options_version.get_item_text(options_version.selected), options_platform.get_item_text(index))
	var already_installed = IntegrityResult & (InstallsIndex.IntegrityResult.FAIL_NOT_IN_FILESYSTEM | InstallsIndex.IntegrityResult.FAIL_NOT_IN_INDEX) == 0
	var executable_found = IntegrityResult & InstallsIndex.IntegrityResult.FAIL_NO_EXE == 0
	set_buttons_state(already_installed, Configurator.get_mod_pid(mod_data_id, options_version.get_item_text(options_version.selected), options_platform.get_item_text(options_platform.selected)) != -1, executable_found)


func get_platform_icon(filename: String) -> Texture2D:
	filename = filename.to_lower()

	if filename.contains("win") or filename.contains(".exe"):
		return platform_windows_texture
	if filename.contains("linux") or filename.contains("unix"):
		return platform_linux_texture
	if filename.contains("apple") or filename.contains("mac"):
		return platform_apple_texture
	if filename.contains("redirect ("):
		return platform_redirect_texture

	return null


func set_buttons_state(installed: bool, running: bool = false, launchable: bool = true, installable: bool = true) -> void:
	button_install.disabled = installed or not installable
	button_install.visible = not installed
	button_uninstall.visible = installed
	button_uninstall.disabled = false
	button_launch.visible = installed
	button_launch.text = tr("Launch")
	#button_browse.visible = installed
	button_files.visible = installed
	button_launch.disabled = not launchable

	button_uninstall.text = tr("Kill process") if running else tr("Uninstall")
	button_uninstall.icon = fire_texture if running else uninstall_texture
	
	if not running and installed: _refresh_time_played()


func _on_button_install_pressed() -> void:
	if options_platform.get_item_text(options_platform.selected).contains("Redirect ("):
		InstallsIndex.redirect(mod_data_id, options_version.get_item_text(options_version.selected), options_platform.get_item_text(options_platform.selected))
		return
	
	button_install.disabled = true
	InstallsIndex.operation_done.connect(_on_installs_index_done, CONNECT_ONE_SHOT)
	InstallsIndex.install(mod_data_id, options_version.get_item_text(options_version.selected), options_platform.get_item_text(options_platform.selected))
	
	done_critical_operation = true


func _on_button_launch_pressed() -> void:
	if not InstallsIndex.launch(mod_data_id, options_version.get_item_text(options_version.selected), options_platform.get_item_text(options_platform.selected), true):
		return
	
	button_launch.text = tr("Loading...")
	button_launch.disabled = true
	$TimerLoading.start()
	button_uninstall.text = tr("Kill process")
	button_uninstall.icon = fire_texture
	button_uninstall.disabled = true
	
	done_critical_operation = true


func _on_button_uninstall_pressed() -> void:
	var pid = Configurator.get_mod_pid(mod_data_id, options_version.get_item_text(options_version.selected), options_platform.get_item_text(options_platform.selected))

	if pid == -1:
		InstallsIndex.operation_done.connect(_on_installs_index_done, CONNECT_ONE_SHOT)
		InstallsIndex.uninstall(
			mod_data_id,
			options_version.get_item_text(options_version.selected),
			options_platform.get_item_text(options_platform.selected)
		)
		_on_options_platform_item_selected(options_platform.selected)
	else:
		OS.kill(pid)
		button_uninstall.disabled = true
		button_uninstall.text = tr("Closing game...")
		$TimerKilling.start()
	
	done_critical_operation = true


func _on_button_browse_pressed() -> void:
	InstallsIndex.show_file_explorer(mod_data_id, options_version.get_item_text(options_version.selected), options_platform.get_item_text(options_platform.selected))


func _on_installs_index_done(succeeded: bool, type: String) -> void:
	if not succeeded: return

	match type:
		"install":
			_on_options_platform_item_selected(options_platform.selected)
			if Configurator.get_config("auto_subscribe", false):
				$PanelDetail/CenterContainer/VBoxContainer/CheckSubscribe.button_pressed = true
		"cancel":
			set_buttons_state(false)
	
	$PanelDetail/CenterContainer/VBoxContainer/ContainerButtons.grab_focus.call_deferred()


func _on_item_list_item_activated(index: int) -> void:
	var url = item_list.get_item_text(index)
	if url.begins_with("https://"):
		OS.shell_open(url)


func _on_timer_loading_timeout() -> void:
	if button_launch.disabled and button_launch.visible and button_launch.text == tr("Loading..."):
		button_launch.disabled = false
		button_launch.text = tr("Launch")
		button_uninstall.disabled = false


func _on_check_button_toggled(button_pressed: bool) -> void:
	Configurator.set_ts_mod(mod_data_id, mod_data.timestamp if button_pressed else "")


func _on_timer_killing_timeout() -> void:
	if button_uninstall.disabled and button_uninstall.visible and button_uninstall.text == tr("Closing game..."):
		button_uninstall.disabled = false
		button_uninstall.text = tr("Uninstall")
		button_uninstall.icon = uninstall_texture


func _on_mod_closed(process: ModProcess) -> void:
	if process.mod_id != mod_data_id: return
	var is_current_running = Configurator.get_mod_pid(mod_data_id, options_version.get_item_text(options_version.selected), options_platform.get_item_text(options_platform.selected)) != -1

	if not is_current_running and button_uninstall.text != tr("Uninstall"):
		set_buttons_state(true, false)


func _on_button_favourite_toggled(toggled_on: bool) -> void:
	Configurator.set_is_mod_favourite(mod_data_id, toggled_on)
	done_critical_operation = true


func _on_button_files_id_pressed(id: int) -> void:
	var error: Error
	#var ml_path = OS.get_executable_path()
	var ml_path = "C:/Users/Victor/Projects/Godot/builds/mvloml win portable/MvLOMLWindows-Portable.exe"
	var mod_version = options_version.get_item_text(options_version.selected)
	var mod_platform = options_platform.get_item_text(options_platform.selected)
	var shortcut_description = mod_data.name + " (" + (mod_platform if "Latest" in mod_version else mod_version) + ")"
	
	match id:
		1:
			# shortcut to version directly
			error = OsTools.CreateFileShortcut(shortcut_description, InstallsIndex.get_exe_path(mod_data_id, mod_version, mod_platform), "")
		2:
			# shortcut to version through ml
			error = OsTools.CreateFileShortcut(shortcut_description, ml_path, "--mode=\"\"launch\"\" --id=\"\"" + mod_data_id + "\"\" --version=\"\"" + mod_version + "\"\" --platform=\"\"" + mod_platform + "\"\"")
		3:
			# shortcut to viewer
			error = OsTools.CreateFileShortcut(shortcut_description, ml_path, "--mode=\"\"show\"\" --id=\"\"" + mod_data_id + "\"\"")
		4:
			# browse files
			error = ERR_SKIP
			InstallsIndex.show_file_explorer(mod_data_id, options_version.get_item_text(options_version.selected), options_platform.get_item_text(options_platform.selected))
	
	if error == OK:
		InstallsIndex.toast_success()


func _on_button_file_mgmt_about_to_popup() -> void:
	if not Configurator.get_toured_status("shortcuts"):
		InstallsIndex.show_help("shortcuts")
		Configurator.set_toured_status("shortcuts")
		await InstallsIndex.dialog_help.confirmed or InstallsIndex.dialog_help.canceled
