class_name VybeApi
extends RefCounted

# Adresse de l'API sur o2switch (HTTPS obligatoire). À modifier avant publication.
const BASE_URL := "https://CHANGE-ME.example.com/api/index.php"

static var token: String = ""

# Appelle une action de l'API. Renvoie { "code": int, "data": Dictionary }.
static func call_api(parent: Node, action: String, method: int = HTTPClient.METHOD_GET, payload: Dictionary = {}, query: String = "") -> Dictionary:
	var http := HTTPRequest.new()
	parent.add_child(http)
	var headers := ["Content-Type: application/json"]
	if token != "":
		headers.append("Authorization: Bearer " + token)
	var url := BASE_URL + "?action=" + action + query
	var body := "" if payload.is_empty() else JSON.stringify(payload)
	http.request(url, headers, method, body)
	var result: Array = await http.request_completed
	http.queue_free()
	var parsed: Variant = JSON.parse_string(result[3].get_string_from_utf8())
	return {"code": result[1], "data": parsed if parsed is Dictionary else {}}
