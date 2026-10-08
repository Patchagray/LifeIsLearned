"""Export every exact interactive narration branch. Does not generate speech or edit prose."""
import argparse
import json
from pathlib import Path
from narration_audio import manifest
from validate_package import read_package, content

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('package', type=Path); parser.add_argument('output', type=Path)
    args = parser.parse_args()
    package, _ = read_package(args.package); content(package)
    args.output.write_text(json.dumps(manifest(package), ensure_ascii=False, indent=2) + '\n')
if __name__ == '__main__': main()
