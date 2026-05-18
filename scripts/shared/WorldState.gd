extends RefCounted

const DEFAULT_RUNTIME_VALUES := {
	"trust_ly_thong": 0.0,
	"suspicion": 0.0,
	"courage": 0.0,
	"knowledge": 0.0,
	"danger": 0.0,
	"dream_stability": 70.0,
	"combat_style_spam": 0.0,
	"combat_style_kite": 0.0,
	"climb_confidence": 50.0,
}

const DEFAULT_GLOBAL_MEMORY := {
	"trust_ly_thong": 0.0,
	"suspicion": 0.0,
	"danger_bias": 0.0,
	"combat_spam_bias": 0.0,
	"combat_kite_bias": 0.0,
	"climb_anxiety": 0.0,
	"dream_instability": 0.0,
}

var runtime_state := DEFAULT_RUNTIME_VALUES.duplicate(true)
var global_memory := DEFAULT_GLOBAL_MEMORY.duplicate(true)

func reset() -> void:
	runtime_state = DEFAULT_RUNTIME_VALUES.duplicate(true)

func reset_all() -> void:
	reset()
	global_memory = DEFAULT_GLOBAL_MEMORY.duplicate(true)

func apply_global_memory(memory: Dictionary) -> void:
	global_memory = DEFAULT_GLOBAL_MEMORY.duplicate(true)
	for key in DEFAULT_GLOBAL_MEMORY.keys():
		if memory.has(key):
			global_memory[key] = clampf(float(memory[key]), 0.0, 100.0)

	runtime_state["trust_ly_thong"] = get_value("trust_ly_thong") + get_global_value("trust_ly_thong") * 0.20
	runtime_state["suspicion"] = get_value("suspicion") + get_global_value("suspicion") * 0.20
	runtime_state["danger"] = get_value("danger") + get_global_value("danger_bias") * 0.15
	runtime_state["combat_style_spam"] = get_value("combat_style_spam") + get_global_value("combat_spam_bias") * 0.25
	runtime_state["combat_style_kite"] = get_value("combat_style_kite") + get_global_value("combat_kite_bias") * 0.25
	runtime_state["climb_confidence"] = get_value("climb_confidence") - get_global_value("climb_anxiety") * 0.20
	runtime_state["dream_stability"] = get_value("dream_stability") - get_global_value("dream_instability") * 0.20

	for key in runtime_state.keys():
		runtime_state[key] = clampf(float(runtime_state[key]), -100.0, 100.0)

func get_value(key: String, fallback := 0.0) -> float:
	return float(runtime_state.get(key, fallback))

func set_value(key: String, value: float) -> void:
	runtime_state[key] = clampf(value, -100.0, 100.0)

func add_value(key: String, delta: float) -> void:
	set_value(key, get_value(key) + delta)

func get_global_value(key: String, fallback := 0.0) -> float:
	return float(global_memory.get(key, fallback))

func global_snapshot() -> Dictionary:
	return global_memory.duplicate(true)

func snapshot() -> Dictionary:
	return runtime_state.duplicate(true)

func debug_summary() -> String:
	return "trust:%d suspicion:%d knowledge:%d danger:%d dream:%d mem(danger:%d anxiety:%d)" % [
		int(get_value("trust_ly_thong")),
		int(get_value("suspicion")),
		int(get_value("knowledge")),
		int(get_value("danger")),
		int(get_value("dream_stability")),
		int(get_global_value("danger_bias")),
		int(get_global_value("climb_anxiety")),
	]
