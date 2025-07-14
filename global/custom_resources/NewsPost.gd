class_name NewsPost
extends Resource

@export var title: String
@export var timestamp: int
@export var author: String
@export var message: String


static func new_from_json(json: Dictionary) -> NewsPost:
	var post := NewsPost.new()
	
	post.title = json.get("title", "")
	post.author = json.get("author", "Anonymous")
	post.timestamp = json.get("created", 0)
	post.message = json.get("text", "Message unavailable.")
	
	post.message = cleanup_richtext_tags(post.message)
	
	return post


static func cleanup_richtext_tags(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("<.+?>")
	for result in regex.search_all(text):
		text = text.replace(result.get_string(), "")
	text = text.replace("\r", "")
	text = text.replace("\n\n", "\n")
	return text
