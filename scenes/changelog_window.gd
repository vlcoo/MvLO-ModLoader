extends AcceptDialog

const CHANGELOG_ELEMENT = preload("uid://dmhttr0wrgjwd")

@onready var posts_container: VBoxContainer = $PanelContainer/ScrollContainer/VBoxContainer
@onready var loading_texture: TextureRect = $PanelContainer/TextureLoading
@onready var requester_changelog: HTTPRequest = $HTTPRequest
@onready var container_button_website: HBoxContainer = $PanelContainer/ScrollContainer/VBoxContainer/HBoxContainer
@onready var container_no_results: VBoxContainer = $PanelContainer/ContainerNoResults

var current_mod: ModData


func _ready() -> void:
	pass


func _on_visibility_changed() -> void:
	if not visible: return
	fetch_changelog()


func fetch_changelog() -> void:
	loading_texture.visible = true
	container_no_results.visible = false
	container_button_website.visible = false
	for post in posts_container.get_children():
		if post is NewsElement:
			post.queue_free()
	
	var feed_link = current_mod.link_main_website
	if feed_link.is_empty(): feed_link = current_mod.link_source_code
	if feed_link.contains("github"):
		if not feed_link.ends_with("/"): feed_link += "/"
		feed_link += "releases.atom"
	elif feed_link.contains("itch"):
		if not feed_link.ends_with("/"): feed_link += "/"
		feed_link += "devlog.rss"
	else:
		populate_posts([])
		return
	
	requester_changelog.request(feed_link)


func _on_button_pressed() -> void:
	OS.shell_open(current_mod.link_main_website)


func populate_posts(posts: Array[NewsPost]) -> void:
	loading_texture.visible = false
	if posts.is_empty():
		container_no_results.visible = true
	else:
		container_button_website.visible = true
		for post in posts:
			var element = CHANGELOG_ELEMENT.instantiate()
			posts_container.add_child(element)
			element.init_ui(post)


func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 404: 
		populate_posts([])
		return
	populate_posts([NewsPost.new_from_feed(body.get_string_from_utf8())])
