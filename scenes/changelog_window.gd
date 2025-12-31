extends AcceptDialog

const CHANGELOG_ELEMENT = preload("uid://dmhttr0wrgjwd")

@onready var posts_container: VBoxContainer = $PanelContainer/ScrollContainer/VBoxContainer
@onready var loading_texture: TextureRect = $PanelContainer/TextureLoading
@onready var requester_changelog: HTTPRequest = $HTTPRequest
@onready var container_button_website: HBoxContainer = $PanelContainer/ScrollContainer/VBoxContainer/HBoxContainer
@onready var container_no_results: VBoxContainer = $PanelContainer/ContainerNoResults

var current_mod: ModData
var button_link: String = ""


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
	
	var feed_link = current_mod.link_source_code
	if feed_link.is_empty(): feed_link = current_mod.link_main_website
	if feed_link.contains("github"):
		if not feed_link.ends_with("/"): feed_link += "/"
		feed_link += "releases.atom"
	elif feed_link.contains("itch"):
		if not feed_link.ends_with("/"): feed_link += "/"
		feed_link += "devlog.rss"
	else:
		populate_posts([])
		return
	
	button_link = feed_link.replace(".rss", "").replace(".atom", "")
	requester_changelog.request(feed_link)


func _on_button_pressed() -> void:
	OS.shell_open(button_link)


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
	
	$PanelContainer/ScrollContainer.pos.y = 0


func _on_http_request_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != 0 or response_code != 200:
		populate_posts([])
		return
	
	var news_posts: Array[NewsPost] = []
	var doc = XML.parse_str(body.get_string_from_utf8())
	
	if button_link.contains("github"):
		var entries: Array[XMLNode] = doc.root.children.filter(func(n: XMLNode): return n.name == "entry")
		for entry in entries:
			var content_i = entry.children.find_custom(func(n: XMLNode): return n.name == "content")
			var header_i = entry.children.find_custom(func(n: XMLNode): return n.name == "title")
			var author_i = entry.children.find_custom(func(n: XMLNode): return n.name == "author")
			var timestamp_i = entry.children.find_custom(func(n: XMLNode): return n.name == "updated")
			if content_i < 0 or header_i < 0 or author_i < 0 or timestamp_i < 0: continue
			var content = entry.children[content_i].content
			var header = entry.children[header_i].content
			var author = entry.children[author_i].children[0].content
			var timestamp = Time.get_unix_time_from_datetime_string(entry.children[timestamp_i].content)
			news_posts.append(NewsPost.new(header, timestamp, author, content))
	
	elif button_link.contains("itch"):
		var entries: Array[XMLNode] = doc.root.children[0].children.filter(func(n: XMLNode): return n.name == "item")
		for entry in entries:
			var content_i = entry.children.find_custom(func(n: XMLNode): return n.name == "description")
			var header_i = entry.children.find_custom(func(n: XMLNode): return n.name == "title")
			var date_i = entry.children.find_custom(func(n: XMLNode): return n.name == "pubDate")
			if content_i < 0 or header_i < 0 or date_i < 0: continue
			var content = entry.children[content_i].cdata[0]
			var header = entry.children[header_i].content
			var author = current_mod.author
			var timestamp = itch_date_to_timestamp(entry.children[date_i].content)
			news_posts.append(NewsPost.new(header, timestamp, author, content))
	
	populate_posts(news_posts)


# itch.io just has to always make things more difficult huh
const month_names = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
func itch_date_to_timestamp(d: String) -> int:
	var parts = d.split(" ")
	if (parts.size() != 6): return 0
	return Time.get_unix_time_from_datetime_dict({
		"year": parts[3],
		"month": month_names.find(parts[2].to_lower()) + 1,
		"day": parts[1]
	})
