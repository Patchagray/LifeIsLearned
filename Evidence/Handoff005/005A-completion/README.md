# 005A — Insight Bloom evidence

The two captures are simulator renders of the completion view with the normal one-shot Bloom and its Reduce Motion alternative. The existing completion controls remain in place. They demonstrate visual states, not physical haptic or silent-switch behavior.

Deterministic `Handoff005ATests` cover incomplete-to-complete delivery, consumed visual events, revisits, new revisions, disabled sound/haptics, Reduce Motion policy and independent feedback-service failures. The full regression also exercises actual practice completion and collected-card navigation. See [commands](../005A-commands.md) and [final results](../test-results.json).

Physical sound volume, silent switch, haptic feel and timing alongside installed premium narration remain pending device checks. The original chime source is bundled `insight-bloom.wav`; playback does not reconfigure the narration audio session.

Final card regression captures: [iPhone accessibility XXXL](iphone-card-large-final.jpg) and [iPad accessibility XXXL](ipad-card-large-final.jpg). These scroll-position captures show the retained card and selected counter, not a whole-page fit at accessibility size. The suite also verifies the chosen identity, manual swiping, full detail navigation and completion-to-card alignment.
