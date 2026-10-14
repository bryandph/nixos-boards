import copy
import unittest

from release_gate import REQUIRED_JOBS, admit


class ReleaseGateTests(unittest.TestCase):
    def setUp(self):
        self.sha = "a" * 40
        self.env = {
            "RELEASE_SHA": self.sha,
            "APPROVED_RELEASE_SHA": self.sha,
            "GITHUB_REF": "refs/heads/main",
            "GITHUB_EVENT_NAME": "workflow_run",
            "GITHUB_REPOSITORY": "example/boards",
        }
        self.branch = {"commit": {"sha": self.sha}}
        self.run = {
            "id": 123, "run_number": 9, "run_attempt": 2,
            "head_sha": self.sha, "head_branch": "main", "event": "push",
            "path": ".github/workflows/check.yml", "repository": {"full_name": "example/boards"},
            "status": "completed", "conclusion": "success",
        }
        self.runs = [self.run]
        self.jobs = {"total_count": 2, "jobs": [
            {"name": name, "head_sha": self.sha, "status": "completed", "conclusion": "success"}
            for name in sorted(REQUIRED_JOBS)
        ]}

    def get(self, path):
        if path == "/repos/example/boards/branches/main":
            return self.branch
        if path == (
            "/repos/example/boards/actions/workflows/check.yml/runs?head_sha="
            + self.sha + "&event=push&branch=main&per_page=100"
        ):
            return {"workflow_runs": self.runs}
        if path == "/repos/example/boards/actions/runs/123/attempts/2/jobs?per_page=100":
            return self.jobs
        raise AssertionError(f"unexpected API request: {path}")

    def test_success_for_main_workflow_and_manual_retry(self):
        for event in ("workflow_run", "workflow_dispatch"):
            self.env["GITHUB_EVENT_NAME"] = event
            self.assertEqual(admit(self.env, self.get), self.sha)

    def test_environment_denials(self):
        for field, values in {
            "APPROVED_RELEASE_SHA": ["", "b" * 40, "true", self.sha + "\n"],
            "RELEASE_SHA": ["", "main", "A" * 40, "a" * 39],
            "GITHUB_REF": ["refs/heads/topic", "refs/tags/main", ""],
            "GITHUB_EVENT_NAME": ["pull_request", "push", ""],
        }.items():
            for value in values:
                with self.subTest(field=field, value=value):
                    env = dict(self.env, **{field: value})
                    with self.assertRaises(ValueError):
                        admit(env, self.get)

    def test_main_advanced(self):
        self.branch["commit"]["sha"] = "b" * 40
        with self.assertRaises(ValueError):
            admit(self.env, self.get)

    def test_absent_run(self):
        self.runs = []
        with self.assertRaises(ValueError):
            admit(self.env, self.get)

    def test_run_identity_and_result_denials(self):
        for field, values in {
            "head_sha": ["b" * 40], "head_branch": ["topic"], "event": ["pull_request"],
            "path": [".github/workflows/other.yml"], "repository": [{"full_name": "fork/boards"}],
            "status": ["in_progress", "queued"], "conclusion": ["failure", "skipped", None],
        }.items():
            for value in values:
                with self.subTest(field=field, value=value):
                    self.runs = [dict(self.run, **{field: value})]
                    with self.assertRaises(ValueError):
                        admit(self.env, self.get)

    def test_no_fallback_to_older_success(self):
        for field in ("run_number", "run_attempt"):
            latest = dict(self.run, conclusion="failure")
            latest[field] += 1
            self.runs = [self.run, latest]
            with self.assertRaises(ValueError):
                admit(self.env, self.get)

    def test_required_jobs(self):
        original = copy.deepcopy(self.jobs)
        for field, values in {
            "head_sha": ["b" * 40], "name": ["other"], "status": ["in_progress"],
            "conclusion": ["failure", "skipped", "cancelled", None],
        }.items():
            for value in values:
                with self.subTest(field=field, value=value):
                    self.jobs = copy.deepcopy(original)
                    self.jobs["jobs"][0][field] = value
                    with self.assertRaises(ValueError):
                        admit(self.env, self.get)
        for jobs in ([], [original["jobs"][0]], [original["jobs"][0]] * 2):
            self.jobs = {"total_count": len(jobs), "jobs": jobs}
            with self.assertRaises(ValueError):
                admit(self.env, self.get)

    def test_incomplete_evidence_and_api_failure_deny(self):
        self.jobs["total_count"] = 101
        with self.assertRaises(ValueError):
            admit(self.env, self.get)

        def unavailable(_):
            raise OSError("API unavailable")

        with self.assertRaises(OSError):
            admit(self.env, unavailable)


if __name__ == "__main__":
    unittest.main()
