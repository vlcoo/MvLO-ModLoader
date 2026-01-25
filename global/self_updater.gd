extends CanvasLayer

var vercode: int = 6
var verdate: String = "2026-01-25"
@onready var requester: HTTPRequest = $HTTPRequest
const UPDATE_URL = "https://mvloml.vlcoo.net/api/meta/update"


func _ready() -> void:
	ContentGetter.cache_updated.connect(_on_cache_updated)


func _on_cache_updated(_succeeded: bool) -> void:
	if not Configurator.cache_is_old: return
	requester.request(UPDATE_URL)


func _self_update(update_info: SelfUpdaterUpdate) -> void:
	$AcceptDialog.dialog_text = tr("Date:") + " " + update_info.date + "\n" + tr("Changelog:") + "\n" + update_info.changelog + \
		"\n\n" + tr("Please download the new release.")
	$AcceptDialog.popup_centered()


func _on_accept_dialog_confirmed() -> void:
	OS.shell_open("https://github.com/vlcoo/MvLO-ModLoader/releases/latest")


func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != 0 or response_code != 200:
		return
	
	var json = JSON.parse_string(body.get_string_from_utf8())
	var latest_version = json["vercode"]
	if int(latest_version) > vercode:
		_self_update(SelfUpdaterUpdate.new(json["date"], json["changelog"], json["vercode"]))
