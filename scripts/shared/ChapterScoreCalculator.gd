extends RefCounted

func calculate(chapter_id: String, payload: Dictionary) -> Dictionary:
	match chapter_id:
		"chapter_1":
			return _calculate_chapter_1(payload)
		"chapter_2":
			return _calculate_chapter_2(payload)
		"chapter_3":
			return _calculate_chapter_3(payload)
		_:
			return {
				"stars": 1,
				"criteria": ["Hoan thanh man"],
			}

func preview(chapter_id: String, payload: Dictionary) -> int:
	return int(calculate(chapter_id, payload).get("stars", 1))

func _calculate_chapter_1(payload: Dictionary) -> Dictionary:
	var clues := int(payload.get("clues_found", 0))
	var time_seconds := float(payload.get("time_seconds", 9999.0))
	var dream_stability := float(payload.get("dream_stability", 0.0))

	var criteria := ["Hoan thanh man"]
	var stars := 1
	if clues >= 2:
		stars = 2
		criteria.append("Tim it nhat 2/3 manh moi")
	else:
		criteria.append("Can tim 2/3 manh moi de dat 2 sao")

	if clues >= 2 and time_seconds <= 90.0 and dream_stability >= 55.0:
		stars = 3
		criteria.append("Hoan thanh <= 90s va dream stability >= 55")
	else:
		criteria.append("3 sao can <= 90s va dream stability >= 55")

	return {"stars": stars, "criteria": criteria}

func _calculate_chapter_2(payload: Dictionary) -> Dictionary:
	var hp_remaining := float(payload.get("hp_remaining", 0.0))
	var time_seconds := float(payload.get("time_seconds", 9999.0))
	var danger_spikes := int(payload.get("danger_spikes", 999))

	var criteria := ["Danh bai boss"]
	var stars := 1
	if hp_remaining >= 35.0:
		stars = 2
		criteria.append("Con it nhat 35 HP")
	else:
		criteria.append("Can con it nhat 35 HP de dat 2 sao")

	if hp_remaining >= 35.0 and time_seconds <= 150.0 and danger_spikes <= 2:
		stars = 3
		criteria.append("Thang <= 150s va danger high-pressure <= 2 lan")
	else:
		criteria.append("3 sao can <= 150s va danger high-pressure <= 2 lan")

	return {"stars": stars, "criteria": criteria}

func _calculate_chapter_3(payload: Dictionary) -> Dictionary:
	var fall_count := int(payload.get("fall_count", 999))
	var time_seconds := float(payload.get("time_seconds", 9999.0))

	var criteria := ["Len toi dinh"]
	var stars := 1
	if fall_count < 8:
		stars = 2
		criteria.append("Duoi 8 lan roi")
	else:
		criteria.append("Can duoi 8 lan roi de dat 2 sao")

	if fall_count < 4 and time_seconds <= 300.0:
		stars = 3
		criteria.append("Duoi 5 phut va duoi 4 lan roi")
	else:
		criteria.append("3 sao can duoi 5 phut va duoi 4 lan roi")

	return {"stars": stars, "criteria": criteria}
