"""Normalize a downloaded master to mono 64 kbps MP3, using two-pass -16 LUFS / -1.5 dBTP."""
import argparse
import json
import math
from pathlib import Path
import subprocess
from narration_audio import ffmpeg, inspect_mp3


def normalize(source, output):
    if source.resolve() == output.resolve(): raise ValueError('Keep the downloaded master; choose a separate output file.')
    common = [ffmpeg(), '-nostdin', '-hide_banner', '-i', str(source), '-map', '0:a:0', '-vn', '-ac', '1']
    first = subprocess.run(common + ['-af', 'loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json', '-f', 'null', '-'], capture_output=True, timeout=180, check=True)
    text = first.stderr.decode(errors='replace'); values = json.loads(text[text.rfind('{'):text.rfind('}')+1])
    fields = ['input_i','input_tp','input_lra','input_thresh','target_offset']
    if not all(math.isfinite(float(values[k])) for k in fields): raise ValueError('Master has no measurable speech/loudness; inspect it before packaging.')
    filters = (f"loudnorm=I=-16:TP=-1.5:LRA=11:measured_I={values['input_i']}:measured_TP={values['input_tp']}:"
               f"measured_LRA={values['input_lra']}:measured_thresh={values['input_thresh']}:offset={values['target_offset']}:linear=true:print_format=json")
    temporary = output.with_name(output.name + '.tmp.mp3')
    try:
        second = subprocess.run(common + ['-af', filters, '-ar', '44100', '-c:a', 'libmp3lame', '-b:a', '64k',
                                '-map_metadata', '-1', '-y', str(temporary)], capture_output=True, timeout=180, check=True)
        duration = inspect_mp3(temporary)
        text = second.stderr.decode(errors='replace'); measured = json.loads(text[text.rfind('{'):text.rfind('}')+1])
        # Encoder true-peak/loudness should still be auditioned and measured for a release.
        temporary.replace(output)
        return dict(durationMilliseconds=duration, normalization=measured, targetLUFS=-16, targetTruePeakDB=-1.5, channels=1, bitrate=64000)
    finally:
        temporary.unlink(missing_ok=True)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('master',type=Path);p.add_argument('output',type=Path);p.add_argument('--report',type=Path,required=True)
    a=p.parse_args();a.report.write_text(json.dumps(normalize(a.master,a.output),indent=2)+'\n')
if __name__=='__main__':main()
