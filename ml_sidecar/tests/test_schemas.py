from __future__ import annotations

import unittest

from lewm_sidecar.schemas import PredictReactionRequest, ReactionContract


class SchemaTests(unittest.TestCase):
    def test_reaction_contract_accepts_extra_fields(self) -> None:
        reaction = ReactionContract(
            intent="AreaDeny",
            severity=80.0,
            effects=["arena_hazard"],
            ui={"whisper": "x", "meter_label": "AreaDeny", "warning": "y"},
            tactic="AreaDeny",
            arena_pressure=15.0,
        )
        self.assertEqual(reaction.intent, "AreaDeny")
        self.assertEqual(reaction.source, "ml")

    def test_predict_payload_shape(self) -> None:
        payload = PredictReactionRequest(
            chapter_id="chapter_2",
            frame_png_base64="abcd",
            action_vector=[0, 0, 1, 0, 0, 0],
            scalar_context={"attack_frequency": 5},
            candidate_reactions=[{"intent": "PunishSpam", "severity": 84, "effects": [], "ui": {}}],
        )
        self.assertEqual(payload.chapter_id, "chapter_2")
        self.assertEqual(len(payload.candidate_reactions), 1)


if __name__ == "__main__":
    unittest.main()
