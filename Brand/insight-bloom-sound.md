# Insight Bloom UI sound

An original synthesized two-note accent, not a downloaded recording. The app resource is `LifeIsLearned/Resources/insight-bloom.wav`: 0.72 seconds, 22,050 Hz, mono, signed 16-bit little-endian PCM.

For sample time `t`, sum two sine tones `(onset, frequency) = (0, 523.25 Hz), (0.12, 783.99 Hz)`. Each contributes zero before its onset; afterwards with `u = t - onset`, its amplitude is `0.12 * min(1, u / 0.012) * exp(-7 * u) * sin(2 * pi * frequency * u)`. Round the sum times 32767 to an Int16 sample. No normalization, loop, recording, voice or third-party asset.

Playback uses the system's UI-sound path; haptics are independently controlled. Silent-switch behavior, perceived loudness and tactile quality require physical-device review. The sound must never alter the guide/storyteller selection or lesson progression.
