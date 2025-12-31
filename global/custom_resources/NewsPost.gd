class_name NewsPost
extends Resource

@export var title: String
@export var timestamp: int
@export var author: String
@export var message: String


func _init(post_title: String, post_timestamp: int, post_author: String, post_message: String) -> void:
	title = post_title
	timestamp = post_timestamp
	author = post_author
	message = cleanup_richtext_tags(post_message).strip_edges()


static func new_from_json(json: Dictionary) -> NewsPost:
	return NewsPost.new(
		json.get("title", ""),
		json.get("created", 0),
		json.get("author", "Anonymous"),
		json.get("text", "Message unavailable.")
	)


static func cleanup_richtext_tags(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("<.+?>")
	for result in regex.search_all(text):
		var s = result.get_string()
		if s == "<li>": text = text.replace(s, "• ")
		else: text = text.replace(s, "")
	text = text.replace("\r", "")
	text = text.replace("\n\n", "\n")
	text = text.replace("&#039;", "'")
	return text
