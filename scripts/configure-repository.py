#!/usr/bin/env python3
"""Verify/apply required CI checks and restricted release deployment refs."""
import argparse
import json
from pathlib import Path
import subprocess


def api(path, method="GET", payload=None):
    command = ["gh", "api", path, "--method", method]
    if payload is not None:
        command += ["--input", "-"]
    result = subprocess.run(command, input=json.dumps(payload) if payload is not None else None,
                            capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return json.loads(result.stdout) if result.stdout.strip() else None


def actors(value):
    if value is None:
        return None
    return {key: [item["slug" if key in ("teams", "apps") else "login"] for item in value.get(key, [])]
            for key in ("users", "teams", "apps")}


def initial_protection(protection, status):
    # GitHub's status-only PATCH returns 404 until the feature is enabled.
    # The initial PUT must retain every existing review/admin/restriction flag.
    reviews = protection.get("required_pull_request_reviews")
    if reviews is not None:
        reviews = {key: value for key, value in reviews.items() if key != "url"}
        for key in ("dismissal_restrictions", "bypass_pull_request_allowances"):
            if key in reviews:
                reviews[key] = actors(reviews[key])
    result = dict(required_status_checks=status, required_pull_request_reviews=reviews,
                  enforce_admins=protection.get("enforce_admins", {}).get("enabled", False),
                  restrictions=actors(protection.get("restrictions")))
    for key in ("required_linear_history", "allow_force_pushes", "allow_deletions", "block_creations",
                "required_conversation_resolution", "lock_branch", "allow_fork_syncing"):
        if key in protection:
            result[key] = protection[key]["enabled"]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", default="joaopinto14/Production")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    root = f"repos/{args.repository}"
    protection_path = root + "/branches/main/protection"
    protection = api(protection_path)
    status = protection.get("required_status_checks") or {}
    required = {"Runtime tests", "Multi-architecture build"}
    current_checks = {item["context"]: item.get("app_id", -1) for item in status.get("checks", [])}
    checks = dict(current_checks)
    for context in status.get("contexts", []):
        checks.setdefault(context, -1)
    checks.update({name: 15368 for name in required})  # Verified GitHub Actions App.
    configured = status.get("strict") is True and all(current_checks.get(name) == 15368 for name in required)
    if not configured:
        if not args.apply:
            raise ValueError("main must require Runtime tests and Multi-architecture build from GitHub Actions, strict=true")
        payload = dict(strict=True, checks=[dict(context=name, app_id=app) for name, app in sorted(checks.items())])
        if status:
            api(protection_path + "/required_status_checks", "PATCH", payload)
        else:
            api(protection_path, "PUT", initial_protection(protection, payload))
    environments = api(root + "/environments")["environments"]
    environment = next((item for item in environments if item["name"] == "release"), None)
    environment_path = root + "/environments/release"
    if environment is None:
        if not args.apply:
            raise ValueError("Missing restricted release environment")
        api(environment_path, "PUT", dict(deployment_branch_policy=dict(protected_branches=False, custom_branch_policies=True)))
    else:
        policy = api(environment_path)["deployment_branch_policy"]
        if not policy or not policy.get("custom_branch_policies"):
            raise ValueError("Existing release environment needs custom deployment policies; refusing to replace its protections")
    policies = api(environment_path + "/deployment-branch-policies")["branch_policies"]
    allowed = {("main", "branch"), ("v*", "tag")}
    found = {(item["name"], item["type"]) for item in policies}
    if found - allowed:
        raise ValueError(f"Unexpected release deployment refs: {found - allowed}")
    for name, kind in sorted(allowed - found):
        if not args.apply:
            raise ValueError(f"Missing release deployment ref: {kind} {name}")
        api(environment_path + "/deployment-branch-policies", "POST", dict(name=name, type=kind))
    evidence = dict(branch=api(protection_path), environment=api(environment_path),
                    deployment_refs=api(environment_path + "/deployment-branch-policies"))
    final = evidence["branch"]["required_status_checks"]
    assert final["strict"] and required <= {item["context"] for item in final["checks"]}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(evidence, indent=2) + "\n")
    print("Repository protections verified: required GitHub Actions checks, strict status policy, release refs main/v*.")


if __name__ == "__main__":
    main()
