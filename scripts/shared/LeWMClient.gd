extends RefCounted

const DEFAULT_HOST := "127.0.0.1"
const DEFAULT_PORT := 8765
const DEFAULT_TIMEOUT_MS := 120
const DEFAULT_CAPTURE_SIZE := 128
const RETRY_COOLDOWN_MS := 2000

var enabled := true
var force_ml := false
var host := DEFAULT_HOST
var port := DEFAULT_PORT
var timeout_ms := DEFAULT_TIMEOUT_MS
var capture_size := DEFAULT_CAPTURE_SIZE
var session_id := ""
var last_error := ""
var last_latency_ms := 0.0
var disabled_until_msec := 0

func configure(user_args: PackedStringArray) -> void:
	force_ml = user_args.has("--lewm-force-ml")
	enabled = not user_args.has("--lewm-no-ml")
	if enabled and not force_ml and DisplayServer.get_name() == "headless":
		enabled = false
	for arg in user_args:
		if arg.begins_with("--lewm-sidecar-host="):
			host = arg.get_slice("=", 1)
		elif arg.begins_with("--lewm-sidecar-port="):
			port = int(arg.get_slice("=", 1))
		elif arg.begins_with("--lewm-timeout-ms="):
			timeout_ms = maxi(20, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--lewm-capture-size="):
			capture_size = maxi(32, int(arg.get_slice("=", 1)))

func start_session(chapter_id: String) -> void:
	if not _can_request():
		return
	var response := _request_json(HTTPClient.METHOD_POST, "/v1/session/start", {
		"chapter_id": chapter_id,
	})
	if response.is_empty():
		return
	session_id = String(response.get("session_id", session_id))

func end_session() -> void:
	if session_id == "" or not _can_request():
		return
	_request_json(HTTPClient.METHOD_POST, "/v1/session/end", {
		"session_id": session_id,
	})
	session_id = ""

func predict_reaction(chapter_id: String, viewport: Viewport, action_vector: Array, scalar_context: Dictionary, candidate_reactions: Array) -> Dictionary:
	if not _can_request():
		return {}
	var frame_png_base64 := _capture_viewport_png_base64(viewport)
	if frame_png_base64 == "":
		last_error = "empty_frame"
		return {}

	var response := _request_json(HTTPClient.METHOD_POST, "/v1/predict_reaction", {
		"session_id": session_id,
		"chapter_id": chapter_id,
		"frame_png_base64": frame_png_base64,
		"action_vector": action_vector,
		"scalar_context": scalar_context,
		"candidate_reactions": candidate_reactions,
	})
	if response.is_empty():
		return {}
	if response.has("reaction") and response["reaction"] is Dictionary:
		return response["reaction"]
	if response.has("intent"):
		return response
	last_error = "missing_reaction"
	return {}

func health() -> Dictionary:
	if not _can_request():
		return {}
	return _request_json(HTTPClient.METHOD_GET, "/health", {})

func status_summary() -> String:
	if not enabled:
		return "ml:disabled"
	if last_error != "":
		return "ml:error:%s latency:%dms" % [last_error, int(last_latency_ms)]
	return "ml:ready latency:%dms" % int(last_latency_ms)

func _can_request() -> bool:
	if not enabled:
		return false
	return Time.get_ticks_msec() >= disabled_until_msec

func _capture_viewport_png_base64(viewport: Viewport) -> String:
	if viewport == null:
		return ""
	var texture := viewport.get_texture()
	if texture == null:
		return ""
	var image := texture.get_image()
	if image == null or image.is_empty():
		return ""
	image.resize(capture_size, capture_size, Image.INTERPOLATE_BILINEAR)
	var bytes := image.save_png_to_buffer()
	if bytes.is_empty():
		return ""
	return Marshalls.raw_to_base64(bytes)

func _request_json(method: int, path: String, payload: Dictionary) -> Dictionary:
	var started := Time.get_ticks_msec()
	var http := HTTPClient.new()
	var err := http.connect_to_host(host, port)
	if err != OK:
		_mark_unavailable("connect_%d" % err, started)
		return {}

	if not _wait_for_status(http, [HTTPClient.STATUS_CONNECTED], started):
		_mark_unavailable("connect_timeout", started)
		return {}

	var body := ""
	var headers := PackedStringArray(["Accept: application/json"])
	if method != HTTPClient.METHOD_GET:
		body = JSON.stringify(payload)
		headers.append("Content-Type: application/json")

	err = http.request(method, path, headers, body)
	if err != OK:
		_mark_unavailable("request_%d" % err, started)
		return {}

	if not _wait_for_response(http, started):
		_mark_unavailable("response_timeout", started)
		return {}

	var response_bytes := PackedByteArray()
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk := http.read_response_body_chunk()
		if not chunk.is_empty():
			response_bytes.append_array(chunk)
		if Time.get_ticks_msec() - started > timeout_ms:
			_mark_unavailable("body_timeout", started)
			return {}
		OS.delay_msec(1)

	last_latency_ms = float(Time.get_ticks_msec() - started)
	var parsed = JSON.parse_string(response_bytes.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error = "invalid_json"
		return {}
	last_error = ""
	return parsed

func _wait_for_status(http: HTTPClient, desired: Array, started: int) -> bool:
	while Time.get_ticks_msec() - started <= timeout_ms:
		http.poll()
		var status := http.get_status()
		if desired.has(status):
			return true
		if _is_terminal_error(status):
			return false
		OS.delay_msec(1)
	return false

func _wait_for_response(http: HTTPClient, started: int) -> bool:
	while Time.get_ticks_msec() - started <= timeout_ms:
		http.poll()
		var status := http.get_status()
		if status == HTTPClient.STATUS_BODY or status == HTTPClient.STATUS_CONNECTED:
			return true
		if _is_terminal_error(status):
			return false
		OS.delay_msec(1)
	return false

func _is_terminal_error(status: int) -> bool:
	return status == HTTPClient.STATUS_CANT_RESOLVE \
		or status == HTTPClient.STATUS_CANT_CONNECT \
		or status == HTTPClient.STATUS_CONNECTION_ERROR \
		or status == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR

func _mark_unavailable(error: String, started: int) -> void:
	last_error = error
	last_latency_ms = float(Time.get_ticks_msec() - started)
	disabled_until_msec = Time.get_ticks_msec() + RETRY_COOLDOWN_MS
