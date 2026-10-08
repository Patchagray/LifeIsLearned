# Narration QA tone

`narration-tone.mp3` is an original synthetic 440 Hz sine tone, 1.2 seconds, mono 44.1 kHz / 64 kbps MP3. It contains no speech, music, voice impersonation or ElevenLabs output. Tests use it for native decoding, complete-bundle routing, normalization and byte reclamation, not audible script fidelity.

Generated locally with FFmpeg's `sine=frequency=440:duration=1.2:sample_rate=44100` source, `-ac 1 -c:a libmp3lame -b:a 64k`. The checked-in bytes are the deterministic fixture. The DEBUG app fixture embeds the same bytes so simulator tests do not depend on host filesystem/network access. Production builds exclude the DEBUG fixture.
