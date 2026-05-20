extends Node

const SAMPLE_RATE := 22050
const MUSIC_VOLUME_DB := -19.0
const SFX_VOLUME_DB := -8.0
const FANFARE_VOLUME_DB := -7.0
const TWO_PI := TAU
const RECENT_EVENT_LIMIT := 12

var music_player: AudioStreamPlayer
var fanfare_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_index := 0
var stream_cache := {}
var current_music_key := ""
var event_counts := {}
var recent_events: Array[String] = []
var last_event_seconds := {}
var event_cooldowns := {
	"ui_accept": 0.08,
	"ui_back": 0.08,
	"locked": 0.20,
	"chapter_start": 0.25,
	"complete": 0.50,
	"clue_found": 0.18,
	"dialogue": 0.25,
	"reveal": 0.35,
	"lewm_shift": 0.55,
	"weapon_switch": 0.10,
	"dash": 0.12,
	"axe": 0.06,
	"bow": 0.06,
	"hit": 0.07,
	"damage": 0.20,
	"arena_start": 0.50,
	"boss_telegraph": 0.16,
	"hazard": 0.22,
	"charge_start": 0.20,
	"jump": 0.12,
	"land": 0.12,
	"fall": 0.35,
	"wind": 0.70,
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player = _create_player("MusicPlayer", MUSIC_VOLUME_DB)
	fanfare_player = _create_player("FanfarePlayer", FANFARE_VOLUME_DB)
	for i in range(10):
		sfx_players.append(_create_player("SfxPlayer%d" % i, SFX_VOLUME_DB))

func play_menu_music() -> void:
	_play_music("menu")

func play_chapter_music(chapter_id: String) -> void:
	_play_music(chapter_id)

func play_ui_accept() -> void:
	play_event("ui_accept")

func play_ui_back() -> void:
	play_event("ui_back")

func play_locked() -> void:
	play_event("locked")

func play_chapter_start() -> void:
	play_event("chapter_start")

func play_completion() -> void:
	if _event_is_throttled("complete"):
		return
	fanfare_player.stop()
	fanfare_player.stream = _event_stream("complete")
	fanfare_player.volume_db = FANFARE_VOLUME_DB
	fanfare_player.play()
	_track_event("complete")

func play_event(event_name: String) -> void:
	if sfx_players.is_empty():
		return
	var stream := _event_stream(event_name)
	if stream == null:
		return
	if _event_is_throttled(event_name):
		return
	var player := sfx_players[sfx_index]
	sfx_index = (sfx_index + 1) % sfx_players.size()
	player.stop()
	player.stream = stream
	player.volume_db = _event_volume_db(event_name)
	player.pitch_scale = 1.0
	player.play()
	_track_event(event_name)

func get_audio_debug_data() -> Dictionary:
	return {
		"music": current_music_key,
		"music_playing": music_player != null and music_player.playing,
		"active_sfx_players": _active_sfx_player_count(),
		"sfx_pool_size": sfx_players.size(),
		"event_counts": event_counts.duplicate(true),
		"recent_events": recent_events.duplicate(),
	}

func get_audio_summary() -> String:
	var recent := ",".join(PackedStringArray(recent_events.slice(maxi(recent_events.size() - 4, 0), recent_events.size())))
	if recent == "":
		recent = "-"
	return "audio:%s sfx:%d/%d recent:%s" % [
		current_music_key,
		_active_sfx_player_count(),
		sfx_players.size(),
		recent,
	]

func _create_player(player_name: String, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.volume_db = volume_db
	add_child(player)
	return player

func _play_music(music_key: String) -> void:
	if current_music_key == music_key and music_player.playing:
		return
	current_music_key = music_key
	music_player.stop()
	music_player.stream = _music_stream(music_key)
	music_player.volume_db = MUSIC_VOLUME_DB
	music_player.play()

func _event_is_throttled(event_name: String) -> bool:
	var cooldown := float(event_cooldowns.get(event_name, 0.0))
	if cooldown <= 0.0:
		return false
	var now := float(Time.get_ticks_msec()) / 1000.0
	var last := float(last_event_seconds.get(event_name, -9999.0))
	if now - last < cooldown:
		return true
	last_event_seconds[event_name] = now
	return false

func _track_event(event_name: String) -> void:
	event_counts[event_name] = int(event_counts.get(event_name, 0)) + 1
	recent_events.append(event_name)
	if recent_events.size() > RECENT_EVENT_LIMIT:
		recent_events.remove_at(0)

func _active_sfx_player_count() -> int:
	var count := 0
	for player in sfx_players:
		if player.playing:
			count += 1
	return count

func _music_stream(music_key: String) -> AudioStreamWAV:
	var cache_key := "music:%s" % music_key
	if stream_cache.has(cache_key):
		return stream_cache[cache_key]
	var stream := _build_wav_stream(cache_key, 6.0, true)
	stream_cache[cache_key] = stream
	return stream

func _event_stream(event_name: String) -> AudioStreamWAV:
	var cache_key := "event:%s" % event_name
	if stream_cache.has(cache_key):
		return stream_cache[cache_key]
	var duration := _event_duration(event_name)
	if duration <= 0.0:
		return null
	var stream := _build_wav_stream(cache_key, duration, false)
	stream_cache[cache_key] = stream
	return stream

func _build_wav_stream(cache_key: String, duration: float, loop: bool) -> AudioStreamWAV:
	var sample_count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(SAMPLE_RATE)
		var sample := 0.0
		if cache_key.begins_with("music:"):
			sample = _music_sample(cache_key.trim_prefix("music:"), t, duration)
		else:
			sample = _event_sample(cache_key.trim_prefix("event:"), t, duration)
		_write_i16(data, i * 2, sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream

func _write_i16(data: PackedByteArray, offset: int, sample: float) -> void:
	var value := int(round(clampf(sample, -1.0, 1.0) * 32767.0))
	if value < 0:
		value += 65536
	data[offset] = value & 0xff
	data[offset + 1] = (value >> 8) & 0xff

func _music_sample(music_key: String, t: float, duration: float) -> float:
	var edge := minf(clampf(t / 0.05, 0.0, 1.0), clampf((duration - t) / 0.05, 0.0, 1.0))
	match music_key:
		"chapter_1":
			var chord := [174.61, 220.00, 261.63, 329.63]
			var step := int(floor(t * 1.25)) % chord.size()
			var pad := _soft_sine(chord[step], t) * 0.20 + _soft_sine(chord[(step + 2) % chord.size()] * 0.5, t) * 0.15
			var pulse := sin(TWO_PI * 2.0 * t) * 0.04
			var shimmer := sin(TWO_PI * (880.0 + sin(t * 0.9) * 14.0) * t) * 0.025
			return (pad + pulse + shimmer) * edge
		"chapter_2":
			var beat := fmod(t * 2.0, 1.0)
			var drum := exp(-beat * 10.0) * sin(TWO_PI * 72.0 * t) * 0.34
			var bass_note := 98.0 if int(t * 2.0) % 4 < 2 else 116.54
			var bass := _soft_sine(bass_note, t) * 0.18
			var tension := sin(TWO_PI * 233.08 * t) * (0.055 if fmod(t * 4.0, 1.0) < 0.28 else 0.0)
			return (drum + bass + tension) * edge
		"chapter_3":
			var height_air := sin(TWO_PI * (329.63 + sin(t * 0.31) * 4.0) * t) * 0.07
			var low := _soft_sine(146.83, t) * 0.16
			var bell := sin(TWO_PI * 587.33 * t) * (0.05 if fmod(t * 0.75, 1.0) < 0.20 else 0.0)
			return (low + height_air + bell) * edge
		_:
			var menu_notes := [196.00, 246.94, 293.66, 329.63]
			var menu_step := int(floor(t * 0.9)) % menu_notes.size()
			var menu_pad := _soft_sine(menu_notes[menu_step], t) * 0.18
			var menu_bell := sin(TWO_PI * menu_notes[(menu_step + 2) % menu_notes.size()] * 2.0 * t) * 0.045
			return (menu_pad + menu_bell) * edge

func _event_sample(event_name: String, t: float, duration: float) -> float:
	var env := _envelope(t, duration, 0.006, 0.08)
	match event_name:
		"ui_accept":
			return (sin(TWO_PI * (520.0 + 260.0 * t / duration) * t) * 0.34) * env
		"ui_back":
			return (sin(TWO_PI * (360.0 - 120.0 * t / duration) * t) * 0.30) * env
		"locked":
			var buzz := sin(TWO_PI * 118.0 * t) + sin(TWO_PI * 124.0 * t)
			return buzz * 0.18 * _pulse_gate(t, 12.0) * env
		"chapter_start":
			return (sin(TWO_PI * 392.0 * t) * 0.24 + sin(TWO_PI * 587.33 * t) * 0.18) * env
		"complete":
			var note := _sequenced_note(t, [392.0, 493.88, 587.33, 783.99], 0.16)
			return (sin(TWO_PI * note * t) * 0.40 + sin(TWO_PI * note * 2.0 * t) * 0.11) * _envelope(t, duration, 0.01, 0.22)
		"clue_found":
			return _bell(t, duration, 659.25, 0.42)
		"dialogue":
			return _bell(t, duration, 440.0, 0.28)
		"reveal":
			return _bell(t, duration, 783.99, 0.32) + _bell(t, duration, 1174.66, 0.18)
		"lewm_shift":
			var bend := 180.0 + sin(t * 18.0) * 38.0
			return (sin(TWO_PI * bend * t) * 0.26 + sin(TWO_PI * 91.0 * t) * 0.12) * env
		"weapon_switch":
			return (sin(TWO_PI * 330.0 * t) * 0.22 + sin(TWO_PI * 660.0 * t) * 0.18) * _pulse_gate(t, 16.0) * env
		"dash":
			return (sin(TWO_PI * (240.0 + 900.0 * t / duration) * t) * 0.32 + _noise(t) * 0.16) * env
		"axe":
			return (sin(TWO_PI * 104.0 * t) * 0.42 + sin(TWO_PI * 168.0 * t) * 0.20) * env
		"bow":
			return (sin(TWO_PI * (760.0 - 420.0 * t / duration) * t) * 0.32) * env
		"hit":
			return _bell(t, duration, 932.33, 0.34)
		"damage":
			return (sin(TWO_PI * 88.0 * t) * 0.36 + _noise(t) * 0.20) * _pulse_gate(t, 18.0) * env
		"arena_start":
			return (sin(TWO_PI * 72.0 * t) * 0.42 + sin(TWO_PI * 144.0 * t) * 0.12) * _envelope(t, duration, 0.01, 0.18)
		"boss_telegraph":
			return (sin(TWO_PI * 360.0 * t) * 0.34) * _pulse_gate(t, 8.0) * env
		"hazard":
			return (sin(TWO_PI * 62.0 * t) * 0.46 + _noise(t) * 0.12) * env
		"charge_start":
			return (sin(TWO_PI * (220.0 + 260.0 * t / duration) * t) * 0.22) * env
		"jump":
			return (sin(TWO_PI * (300.0 + 260.0 * t / duration) * t) * 0.34) * env
		"land":
			return (sin(TWO_PI * 96.0 * t) * 0.38) * env
		"fall":
			return (sin(TWO_PI * (260.0 - 150.0 * t / duration) * t) * 0.32 + _noise(t) * 0.10) * env
		"wind":
			return (sin(TWO_PI * (420.0 + sin(t * 12.0) * 70.0) * t) * 0.16 + _noise(t) * 0.18) * env
		_:
			return 0.0

func _event_duration(event_name: String) -> float:
	match event_name:
		"complete":
			return 0.95
		"arena_start", "lewm_shift", "fall", "wind":
			return 0.55
		"reveal", "chapter_start":
			return 0.42
		"locked", "damage", "boss_telegraph", "hazard":
			return 0.28
		"clue_found", "dialogue", "weapon_switch", "dash", "axe", "bow", "hit", "charge_start", "jump", "land":
			return 0.22
		"ui_accept", "ui_back":
			return 0.16
		_:
			return 0.0

func _event_volume_db(event_name: String) -> float:
	match event_name:
		"damage", "arena_start", "fall":
			return -5.0
		"complete":
			return FANFARE_VOLUME_DB
		"wind", "lewm_shift":
			return -11.0
		_:
			return SFX_VOLUME_DB

func _soft_sine(frequency: float, t: float) -> float:
	return sin(TWO_PI * frequency * t) * 0.74 + sin(TWO_PI * frequency * 2.0 * t) * 0.18

func _bell(t: float, duration: float, frequency: float, gain: float) -> float:
	var decay := exp(-t * 6.0)
	return (sin(TWO_PI * frequency * t) + sin(TWO_PI * frequency * 2.01 * t) * 0.22) * gain * decay * _envelope(t, duration, 0.004, 0.12)

func _sequenced_note(t: float, notes: Array, step_length: float) -> float:
	var index := mini(int(floor(t / step_length)), notes.size() - 1)
	return float(notes[index])

func _envelope(t: float, duration: float, attack: float, release: float) -> float:
	var attack_gain := clampf(t / maxf(attack, 0.001), 0.0, 1.0)
	var release_gain := clampf((duration - t) / maxf(release, 0.001), 0.0, 1.0)
	return minf(attack_gain, release_gain)

func _pulse_gate(t: float, rate: float) -> float:
	return 1.0 if fmod(t * rate, 1.0) < 0.48 else 0.32

func _noise(t: float) -> float:
	return sin(t * 1234.567) * sin(t * 345.123)
