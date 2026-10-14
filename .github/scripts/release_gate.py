"""Default-deny release admission; no publication credentials are needed here."""

import json
import os
import re
import urllib.parse
import urllib.request


REQUIRED_JOBS = {
    "flake-check (ubuntu-26.04)",
    "flake-check (ubuntu-26.04-arm)",
}


def admit(env, get):
    sha = env.get("RELEASE_SHA", "")
    approved = env.get("APPROVED_RELEASE_SHA", "")
    if not re.fullmatch(r"[0-9a-f]{40}", sha) or approved != sha:
        raise ValueError("release SHA is absent, malformed, or not explicitly approved")
    if env.get("GITHUB_REF") != "refs/heads/main":
        raise ValueError("only main may release")
    if env.get("GITHUB_EVENT_NAME") not in {"workflow_run", "workflow_dispatch"}:
        raise ValueError("unsupported release event")
    repo = env["GITHUB_REPOSITORY"]
    prefix = f"/repos/{repo}"
    if get(f"{prefix}/branches/main")["commit"]["sha"] != sha:
        raise ValueError("approved SHA is not the current main head")
    # Only the repository's check workflow, on a main push, can admit a release.
    # PR checks (including successful checks of the same SHA) are insufficient.
    runs = get(
        f"{prefix}/actions/workflows/check.yml/runs?"
        + urllib.parse.urlencode({"head_sha": sha, "event": "push", "branch": "main", "per_page": 100})
    )["workflow_runs"]
    runs = [r for r in runs if r["head_sha"] == sha and r["head_branch"] == "main"
            and r["event"] == "push" and r["path"] == ".github/workflows/check.yml"
            and r["repository"]["full_name"] == repo]
    if not runs:
        raise ValueError("no same-SHA main-push check run")
    # A newer failed/in-progress retry must not fall back to an older green run.
    run = max(runs, key=lambda r: (r["run_number"], r["run_attempt"]))
    if run["status"] != "completed" or run["conclusion"] != "success":
        raise ValueError("latest same-SHA check run did not succeed")
    jobs = get(
        f"{prefix}/actions/runs/{run['id']}/attempts/{run['run_attempt']}/jobs?per_page=100"
    )
    if jobs["total_count"] != len(jobs["jobs"]):
        raise ValueError("incomplete job evidence")
    for name in REQUIRED_JOBS:
        matches = [j for j in jobs["jobs"] if j["name"] == name]
        if len(matches) != 1 or any(
            j["head_sha"] != sha or j["status"] != "completed" or j["conclusion"] != "success"
            for j in matches
        ):
            raise ValueError(f"missing or unsuccessful same-SHA required job: {name}")
    return sha


def main():
    env = os.environ
    api = env["GITHUB_API_URL"].rstrip("/")

    def get(path):
        request = urllib.request.Request(api + path, headers={
            "Authorization": f"Bearer {env['GH_TOKEN']}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        })
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)

    sha = admit(env, get)
    print(f"Admitted approved main SHA {sha} with both native check jobs successful")
    if env.get("GITHUB_OUTPUT"):
        with open(env["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
            output.write(f"sha={sha}\n")


if __name__ == "__main__":
    main()
