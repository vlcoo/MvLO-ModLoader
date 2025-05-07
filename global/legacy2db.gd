extends Control

@onready var label: Label = $VBoxContainer/Label
@onready var progress: ProgressBar = $VBoxContainer/ProgressBar
@onready var request: HTTPRequest = $HTTPRequest

const BASE_URL = "http://127.0.0.1:5000/"
const DEFAULT_GAMEFILES = {
	"method": "ignore",
	"home_url": "",
}


func _on_ready() -> void:
	do()


func do() -> void:
	var dir = DirAccess.open("res://DB/mod_datas")
	var files = dir.get_files()
	progress.max_value = files.size()
	var gamefiles: Dictionary = JSON.parse_string(FileAccess.open("res://DB.min.json", FileAccess.READ).get_as_text())
	
	for path in files:
		var mod_path = "res://DB/mod_datas/" + path
		var mod: ModData = ResourceLoader.load(mod_path) as ModData
		var mod_id = path.replace(".tres", "")
		var img_cover_file = FileAccess.get_file_as_bytes("res://DB/" + mod_id + "C.png")
		var img_icon_file = FileAccess.get_file_as_bytes("res://DB/" + mod_id + "I.png")
		label.text = mod.name
		
		var json := {
			"modId": mod_id,
			"modName": mod.name,
			"modAuthor": mod.author,
			"modImageCover": "" if img_cover_file.is_empty() else Marshalls.raw_to_base64(img_cover_file),
			"modImageIcon": "" if img_icon_file.is_empty() else Marshalls.raw_to_base64(img_icon_file),
			"modDescription": mod.description,
			"modBaseVersion": mod.base_version,
			"modNeedsDiscordRPC": mod.needs_discord_activity,
			"modLinkMainWebsite": mod.link_main_website,
			"modLinkSourceCode": mod.link_source_code,
			"modLinkDiscordServer": mod.link_discord[1] if mod.link_discord.size() > 1 else "",
			"modLinkDiscordThread": mod.link_discord[0] if not mod.link_discord.is_empty() else "",
			"modDownloadUrl": gamefiles.get(mod_id, DEFAULT_GAMEFILES)["home_url"],
			"modDownloadMethod": gamefiles.get(mod_id, DEFAULT_GAMEFILES)["method"],
		}
		
		request.request(BASE_URL + "api/mods", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(json))
		await request.request_completed
		progress.value += 1
	
	label.text = "success!"


func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print(body.get_string_from_utf8() + ", " + str(response_code))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		label.text = "restarting."
		progress.value = 0
		do()
