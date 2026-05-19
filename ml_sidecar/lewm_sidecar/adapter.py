from __future__ import annotations

from typing import Any


ALLOWED_INTENTS: dict[str, set[str]] = {
    "chapter_1": {"ForestCalm", "ObjectMemory", "TemporalFog", "PathShift", "TrustGuide"},
    "chapter_2": {"BalancedPressure", "PunishSpam", "CloseGap", "AntiAim", "WeaponRead", "AreaDeny"},
    "chapter_3": {"MountainStillness", "WindMemory", "HighAltitudeWind", "MountainBreath", "LandingEcho"},
}


def safe_candidates(chapter_id: str, candidates: list[dict[str, Any]]) -> list[dict[str, Any]]:
    allowed = ALLOWED_INTENTS.get(chapter_id, set())
    return [candidate for candidate in candidates if str(candidate.get("intent", "")) in allowed]


def context_prior(chapter_id: str, intent: str, context: dict[str, Any]) -> float:
    """Small domain prior. The latent score remains the main selector."""
    if chapter_id == "chapter_1":
        if intent == "ObjectMemory":
            return min(float(context.get("explored_objects", 0.0)) / 3.0, 1.0)
        if intent == "TemporalFog":
            return min(float(context.get("time_in_forest", 0.0)) / 75.0, 1.0)
        if intent == "PathShift":
            return 1.0 if bool(context.get("wandering", False)) else 0.0
        if intent == "TrustGuide":
            return 1.0 if bool(context.get("direct_exit_route", False)) else 0.0
    elif chapter_id == "chapter_2":
        if intent == "PunishSpam":
            return min(float(context.get("attack_frequency", 0.0)) / 6.0, 1.0)
        if intent == "CloseGap":
            return min(float(context.get("bow_ratio", 0.0)), 1.0)
        if intent == "AntiAim":
            return min(float(context.get("aim_accuracy", 0.0)), 1.0)
        if intent == "WeaponRead":
            return min(float(context.get("weapon_switch_frequency", 0.0)) / 6.0, 1.0)
        if intent == "AreaDeny":
            return min(float(context.get("corner_time", 0.0)) / 3.0, 1.0)
    elif chapter_id == "chapter_3":
        if intent == "WindMemory":
            return min(float(context.get("fall_count", 0.0)) / 5.0, 1.0)
        if intent == "HighAltitudeWind":
            return min(float(context.get("height_ratio", 0.0)), 1.0)
        if intent == "MountainBreath":
            return min(float(context.get("idle_time", 0.0)) / 10.0, 1.0)
        if intent == "LandingEcho":
            return min(float(context.get("repeated_miss_count", 0.0)) / 3.0, 1.0)
    return 0.15


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def build_reaction(
    chapter_id: str,
    candidate: dict[str, Any],
    confidence: float,
    model_version: str,
    latency_ms: float,
) -> dict[str, Any]:
    intent = str(candidate.get("intent", ""))
    severity = clamp(float(candidate.get("severity", 0.0)) * (0.85 + confidence * 0.25), 0.0, 100.0)
    reaction = dict(candidate)
    reaction["intent"] = intent
    reaction["severity"] = severity
    reaction["effects"] = list(candidate.get("effects", []))
    reaction["ui"] = dict(candidate.get("ui", {}))
    reaction["confidence"] = clamp(confidence, 0.0, 1.0)
    reaction["model_version"] = model_version
    reaction["latency_ms"] = latency_ms
    reaction["source"] = "ml"

    if chapter_id == "chapter_1":
        _guard_forest(reaction)
    elif chapter_id == "chapter_2":
        _guard_boss(reaction)
    elif chapter_id == "chapter_3":
        _guard_climb(reaction)
    return reaction


def _guard_forest(reaction: dict[str, Any]) -> None:
    intent = str(reaction.get("intent", "ForestCalm"))
    reaction["fog"] = 0.0
    reaction["path_shift"] = False
    reaction["reverse_leaves"] = 0.0
    reaction["exit_guidance"] = 0.0
    if intent == "TemporalFog":
        reaction["fog"] = clamp(float(reaction["severity"]) / 160.0, 0.08, 0.62)
    elif intent == "PathShift":
        reaction["path_shift"] = True
        reaction["reverse_leaves"] = 1.0
    elif intent == "TrustGuide":
        reaction["exit_guidance"] = 1.0


def _guard_boss(reaction: dict[str, Any]) -> None:
    tactic = str(reaction.get("intent", "BalancedPressure"))
    reaction["tactic"] = tactic
    reaction["arena_pressure"] = clamp(float(reaction.get("arena_pressure", 3.0)), 2.0, 18.0)
    reaction["behavior_read"] = str(reaction.get("behavior_read", "balanced"))


def _guard_climb(reaction: dict[str, Any]) -> None:
    intent = str(reaction.get("intent", "MountainStillness"))
    reaction["wind"] = 0.0
    reaction["ghost_platform"] = False
    reaction["trajectory_echo"] = False
    if intent == "WindMemory":
        reaction["wind"] = -32.0
    elif intent == "HighAltitudeWind":
        reaction["wind"] = 26.0
    elif intent == "MountainBreath":
        reaction["ghost_platform"] = True
    elif intent == "LandingEcho":
        reaction["trajectory_echo"] = True
