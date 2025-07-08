extends Control

enum ServerStatus {UP, DOWN}

@onready var panel: Panel = $Panel
@onready var texture: TextureRect = $Panel/TextureRect
@onready var requester: HTTPRequest = $HTTPRequestGameServer
@onready var timer_reping: Timer = $TimerReping

const URL := "https://mariovsluigi.azurewebsites.net/ping"
const URL_NEWS := "https://mariovsluigi.azurewebsites.net/news/all"

var getting_posts_instead_of_status: bool = false

signal posts_gotten(posts: Array[NewsPost])

var status: ServerStatus = ServerStatus.UP:
	set(v):
		status = v
		if status == ServerStatus.DOWN: flash_down_hint()
		elif status == ServerStatus.UP: visible = false


func _ready() -> void:
	if Configurator.get_config("ping-servers", true):
		check_server_status()
	else:
		get_news_posts()


func get_news_posts() -> void:
	getting_posts_instead_of_status = true
	requester.request(URL_NEWS)


func check_server_status() -> void:
	getting_posts_instead_of_status = false
	requester.request(URL)


func flash_down_hint() -> void:
	visible = true
	var tween = create_tween()
	tween.set_loops(12)
	var og_color = texture.modulate
	tween.tween_property(texture, ^"modulate", Color.TRANSPARENT, 1).from_current().set_trans(Tween.TRANS_EXPO)
	tween.finished.connect(func(): texture.modulate = og_color)


func _on_http_request_game_server_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if getting_posts_instead_of_status:
		if result != 0 or response_code != 200:
			return
		
		var json = JSON.parse_string(body.get_string_from_utf8())
		var posts: Array[NewsPost] = []
		for raw_post in json:
			var post = NewsPost.new_from_json(raw_post)
			posts.append(post)
		posts_gotten.emit(posts)
	
	else:
		if result != 0 or response_code != 200:
			status = ServerStatus.DOWN
			timer_reping.start()
		else:
			status = ServerStatus.UP
			get_news_posts()


func _on_timer_reping_timeout() -> void:
	check_server_status()
