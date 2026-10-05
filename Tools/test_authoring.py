"""Regression tests for import policy and authoring gates; measurement fixtures are synthetic."""
import base64
import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from convert_package import convert
from lesson_timing import apply_measurements, package_report, plan, planning_errors, word_count
from validate_package import content, read_package

ROOT = Path(__file__).resolve().parents[1]


class AuthoringTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.demo = json.loads((ROOT/'Example-Lesson-Package.json').read_text())

    def package(self, count=1):
        p = copy.deepcopy(self.demo)
        p['book']['lessons'] = [dict(copy.deepcopy(p['book']['lessons'][0]), id=f'idea-{i}') for i in range(count)]
        p['manifest'] = [dict(id=l['id'], revision=l['revision']) for l in p['book']['lessons']]
        return p

    def measured(self, report, total=300):
        # Synthetic data tests validation math only; never publish as measured audio.
        ideas = []
        for idea in report['ideas']:
            budget = total - idea['pauseSeconds'] - idea['answerAllowanceSeconds']
            records = [dict(s, seconds=1.0) for s in idea['segments']]
            records[-1]['seconds'] = budget - len(records) + 1
            ideas.append(dict(id=idea['id'], revision=idea['revision'], segments=records))
        voice = dict(identifier='synthetic-test-only', name='Synthetic test fixture', quality='premium')
        return dict(bookID=report['bookID'], collectionRevision=report['collectionRevision'],
                    method='speech-completion-callbacks', ideas=ideas,
                    reference=dict(guide=voice, storyteller=copy.deepcopy(voice), speed=1,
                                   pagePauseSeconds=2, deviceModel='Synthetic test fixture', os='Synthetic test fixture'))

    def test_new_collection_count_boundaries(self):
        for count in (1, 12):
            self.assertEqual(content(self.package(count)), count)
        for count in (0, 13, 100):
            with self.assertRaises(ValueError):
                content(self.package(count))

    def test_duplicate_ideas_and_mismatched_manifest(self):
        p = self.package(2)
        p['book']['lessons'][1]['id'] = p['book']['lessons'][0]['id']
        p['manifest'] = [dict(id=l['id'], revision=l['revision']) for l in p['book']['lessons']]
        with self.assertRaises(ValueError): content(p)
        p = self.package(2); p['manifest'].reverse()
        with self.assertRaises(ValueError): content(p)

    def test_forty_three_shared_images_with_cover_and_references(self):
        p = self.package(12)
        image = next(iter(p['assets'].values()))
        p['assets'] = {f'image-{i}': image for i in range(43)}
        p['book'].update(coverAssetID='image-42', coverDescription='Synthetic fixture cover')
        used = set()
        for i, page in enumerate(page for l in p['book']['lessons'] for page in l['pages']):
            key = f'image-{i % 43}'; used.add(key)
            page.update(imageID=key, imageDescription='Synthetic fixture illustration')
        self.assertEqual(set(p['assets']), used)
        self.assertEqual(content(p), 12)

    def test_image_byte_dimension_and_reference_limits_remain(self):
        p = self.package(); key = next(iter(p['assets']))
        p['assets'][key]['data'] = base64.b64encode(bytes(2*1024*1024+1)).decode()
        with self.assertRaisesRegex(ValueError, '2 MiB'): content(p)
        p = self.package(); image = next(iter(p['assets'].values()))
        size = len(base64.b64decode(image['data']))
        p['assets'] = {f'image-{i}': image for i in range(24*1024*1024//size+1)}
        with self.assertRaisesRegex(ValueError, '24 MiB'): content(p)
        p = self.package(); p['book']['coverAssetID'] = 'missing'; p['book']['coverDescription'] = 'Cover'
        with self.assertRaises(ValueError): content(p)
        p = self.package(); p['book']['lessons'][0]['pages'][0]['imageID'] = 'missing'
        with self.assertRaises(ValueError): content(p)
        p = self.package(); p['assets'][' '] = next(iter(p['assets'].values()))
        with self.assertRaises(ValueError): content(p)
        p = self.package(); p['assets'][key] = dict(mediaType='image/png', data=base64.b64encode(b'bad image').decode())
        with self.assertRaises(ValueError): content(p)
        # Portable header test; native decoding is separately covered by XCTest.
        p = self.package(); raw = b'\x89PNG\r\n\x1a\n' + bytes(8) + (2049).to_bytes(4, 'big') + (1).to_bytes(4, 'big')
        p['assets'][key] = dict(mediaType='image/png', data=base64.b64encode(raw).decode())
        with self.assertRaisesRegex(ValueError, '2048'): content(p)

    def test_duplicate_json_keys_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'duplicate.json'
            path.write_text('{"assets":{"same":1,"same":2}}')
            with self.assertRaisesRegex(ValueError, 'Duplicate JSON object key'): read_package(path)

    def test_complete_spoken_script_and_reference_settings(self):
        lesson = self.demo['book']['lessons'][0]
        result = plan(lesson)
        self.assertEqual(result['spokenWords'], 413)
        self.assertEqual(word_count("Don't rush—café 2’s choice."), 5)
        self.assertEqual(result['transitionCount'], 5)
        self.assertEqual(result['pauseSeconds'], 10)
        self.assertEqual(result['answerAllowanceSeconds'], 40)
        self.assertAlmostEqual(result['estimatedTotalSeconds'], 240.6153846153846)
        self.assertEqual(result['approximateMinutes'], lesson['estimatedMinutes'])
        self.assertIn('Option 3.', result['segments'][-3]['text'])
        feedback = [s for s in result['segments'] if s['kind'] == 'feedback']
        self.assertEqual(len(feedback), 2)
        self.assertTrue(all(s['text'].startswith(("That's right.", "Let's reconsider.")) for s in feedback))
        self.assertEqual(result['segments'][-1]['kind'], 'completion')
        self.assertGreater(result['wordsByKind']['question'], 0)
        self.assertGreater(result['wordsByKind']['feedback'], 0)

    def test_planning_boundary_and_cli_exit_codes(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'boundary.json'; report_path = Path(directory)/'report.json'
            for words, expected in ((541, 0), (542, 1)):
                p = copy.deepcopy(self.demo); lesson = p['book']['lessons'][0]
                lesson['pages'][0]['text'] += ' word' * (words - plan(lesson)['spokenWords'])
                lesson['estimatedMinutes'] = plan(lesson)['approximateMinutes']
                path.write_text(json.dumps(p))
                result = subprocess.run([sys.executable, str(ROOT/'Tools/validate_package.py'), str(path), '--authoring-gate', '--report', str(report_path)], capture_output=True, text=True)
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                report = json.loads(report_path.read_text())
                seconds = report['packages'][0]['timing']['ideas'][0]['estimatedTotalSeconds']
                self.assertEqual(seconds <= 300, expected == 0)
                print(f'AUTHORING_GATE words={words} plannedSeconds={seconds:.6f} exit={result.returncode}')

    def test_exactly_two_questions_and_consistent_estimate(self):
        p = self.package(); p['book']['lessons'][0]['questions'].pop()
        self.assertTrue(any('exactly two' in e for e in planning_errors(p, package_report(p))))
        p = self.package(); p['book']['lessons'][0]['estimatedMinutes'] = 1
        self.assertTrue(any('estimatedMinutes' in e for e in planning_errors(p, package_report(p))))

    def test_measured_300_passes_and_just_over_fails(self):
        for total, passes in ((300, True), (300.01, False)):
            report = package_report(self.demo)
            errors = apply_measurements(report, self.measured(report, total))
            self.assertEqual(not errors, passes)
            self.assertEqual(report['ideas'][0]['measuredTotalSeconds'], total)

    def test_measurements_require_premium_exact_script_and_settings(self):
        for change in ('voice', 'text', 'speed', 'pause', 'revision', 'missing'):
            report = package_report(self.demo); observed = self.measured(report)
            if change == 'voice': observed['reference']['guide']['quality'] = 'enhanced'
            elif change == 'text': observed['ideas'][0]['segments'][0]['text'] += ' Changed.'
            elif change == 'speed': observed['reference']['speed'] = 1.2
            elif change == 'pause': observed['reference']['pagePauseSeconds'] = 0
            elif change == 'revision': observed['ideas'][0]['revision'] = 1
            else: observed['ideas'][0]['segments'].pop()
            self.assertTrue(apply_measurements(report, observed), change)

    def test_release_approval_cannot_use_planning_alone(self):
        result = subprocess.run([sys.executable, str(ROOT/'Tools/validate_package.py'), str(ROOT/'Example-Lesson-Package.json'), '--approve-release'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('requires measured premium voices', result.stdout)

    def test_converter_rejects_over_cap_and_over_budget_before_export(self):
        with self.assertRaisesRegex(ValueError, '13 ideas'): convert(self.package(13))
        p = self.package(); p['formatVersion'] = 1
        for page in p['book']['lessons'][0]['pages']:
            page.pop('imageID', None)
        p['book']['lessons'][0]['pages'][0]['text'] += ' word' * 500
        with self.assertRaisesRegex(ValueError, '300-second'): convert(p)


if __name__ == '__main__':
    unittest.main(verbosity=2)
