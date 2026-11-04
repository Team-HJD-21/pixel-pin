import unittest
from unittest.mock import patch
import os
from pathlib import Path
import tempfile
from compiled_inputs import trusted_runs, validate_manifest, find_build, restore


class ReuseSafetyTests(unittest.TestCase):
    def setUp(self):
        self.current = dict(id=20, run_number=20, head_sha="a" * 40, workflow_id=5)
        self.run = dict(id=10, run_number=10, head_sha="a" * 40, workflow_id=5,
                        event="push", head_repository=dict(full_name="owner/repo"))

    def test_only_earlier_same_repository_push_builds_are_trusted(self):
        self.assertEqual(trusted_runs([self.run], self.current, "owner/repo"), [self.run])
        for override in (dict(id=20), dict(run_number=21), dict(head_sha="b" * 40),
                         dict(workflow_id=6), dict(event="pull_request"),
                         dict(head_repository=dict(full_name="fork/repo"))):
            with self.subTest(override=override):
                self.assertEqual(trusted_runs([self.run | override], self.current, "owner/repo"), [])

    def test_source_and_toolchain_must_match_before_restoring(self):
        manifest = dict(schema=1, sha="a" * 40, toolchain="compiler")
        validate_manifest(manifest, "a" * 40, "compiler")
        for override in (dict(schema=2), dict(sha="b" * 40), dict(toolchain="other")):
            with self.subTest(override=override), self.assertRaises(ValueError):
                validate_manifest(manifest | override, "a" * 40, "compiler")

    def test_only_unexpired_artifact_from_successful_run_can_be_selected(self):
        for expired in (True, False):
            with self.subTest(expired=expired), tempfile.TemporaryDirectory() as temporary:
                output = Path(temporary) / "output"
                run = self.run | dict(status="completed", conclusion="success")
                replies = [self.current, dict(workflow_runs=[run]), dict(artifacts=[dict(
                    name="macos-compiled-v1-" + "a" * 40, expired=expired)])]
                with patch("compiled_inputs.gh", side_effect=replies), patch.dict(os.environ, {
                    "GITHUB_REPOSITORY": "owner/repo", "GITHUB_RUN_ID": "20", "GITHUB_OUTPUT": str(output)
                }):
                    find_build(0)
                self.assertEqual(output.exists(), not expired)
                if not expired:
                    self.assertIn("run_id=10", output.read_text())

    def test_failed_run_is_not_reused_even_if_it_uploaded_an_artifact(self):
        replies = [self.current, dict(workflow_runs=[self.run | dict(status="completed", conclusion="failure")])]
        with patch("compiled_inputs.gh", side_effect=replies) as api, patch.dict(os.environ, {
            "GITHUB_REPOSITORY": "owner/repo", "GITHUB_RUN_ID": "20"
        }):
            find_build(0)
        self.assertEqual(api.call_count, 2)

    def test_damaged_archive_is_rejected_before_extraction(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "inputs.tar.gz"
            archive.write_bytes(b"damaged archive")
            Path(str(archive) + ".sha256").write_text("0" * 64)
            with self.assertRaisesRegex(ValueError, "checksum"):
                restore(archive)


if __name__ == "__main__":
    unittest.main()
