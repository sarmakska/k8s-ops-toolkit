"""Shared fixtures for the chart end-to-end tests.

The tests drive the real Helm binary against charts/nextjs-app and parse the
rendered Kubernetes objects. Helm is discovered on PATH or, failing that, in
the vendored .venv/helmbin directory the test harness downloads. When no Helm
binary can be found the whole module is skipped rather than failing, so a
machine without Helm reports the chart suite as skipped rather than broken.
"""
from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import pytest
import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
CHART_DIR = REPO_ROOT / "charts" / "nextjs-app"
FIXTURES = Path(__file__).resolve().parent / "fixtures"


def _find_helm() -> str | None:
    found = shutil.which("helm")
    if found:
        return found
    vendored = REPO_ROOT / ".venv" / "helmbin" / "helm"
    if vendored.exists() and os.access(vendored, os.X_OK):
        return str(vendored)
    return None


HELM = _find_helm()

requires_helm = pytest.mark.skipif(
    HELM is None, reason="helm binary not available; chart render tests skipped"
)


def helm_template(release: str = "release-test", values_file: Path | None = None,
                  sets: dict[str, str] | None = None) -> list[dict]:
    """Render the chart and return the parsed Kubernetes objects."""
    assert HELM is not None
    cmd = [HELM, "template", release, str(CHART_DIR)]
    if values_file is not None:
        cmd += ["-f", str(values_file)]
    for key, value in (sets or {}).items():
        cmd += ["--set", f"{key}={value}"]
    out = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    return [doc for doc in yaml.safe_load_all(out) if doc]


def by_kind(objs: list[dict], kind: str) -> list[dict]:
    return [o for o in objs if o.get("kind") == kind]


def one(objs: list[dict], kind: str) -> dict:
    matches = by_kind(objs, kind)
    assert len(matches) == 1, f"expected exactly one {kind}, found {len(matches)}"
    return matches[0]


@pytest.fixture
def render():
    return helm_template
