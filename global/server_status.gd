extends Control

enum ServerStatus {UP, DOWN}

@onready var panel: Panel = $Panel
@onready var texture: TextureRect = $Panel/TextureRect
@onready var requester: HTTPRequest = $HTTPRequestGameServer

const URL := "https://mariovsluigi.azurewebsites.net/ping"

var status: ServerStatus = ServerStatus.UP:
	set(v):
		status = v
		if status == ServerStatus.DOWN: flash_down_hint()
		elif status == ServerStatus.UP: visible = false


func _ready() -> void:
	if not OS.is_debug_build(): check_server_status()


func check_server_status() -> void:
	requester.request(URL)


func flash_down_hint() -> void:
	visible = true
	var tween = create_tween()
	tween.set_loops(12)
	var og_color = texture.modulate
	tween.tween_property(texture, ^"modulate", Color.TRANSPARENT, 1).from_current().set_trans(Tween.TRANS_EXPO)
	tween.finished.connect(func(): texture.modulate = og_color)


func _on_http_request_game_server_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != 0 or response_code != 200:
		status = ServerStatus.DOWN
	else:
		status = ServerStatus.UP
