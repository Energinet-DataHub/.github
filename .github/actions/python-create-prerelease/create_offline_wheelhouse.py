# Copyright 2020 Energinet DataHub A/S
#
# Licensed under the Apache License, Version 2.0 (the "License2");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import base64
import hashlib
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import zipfile
from pathlib import Path

import tomllib

NAME_PATTERN = re.compile(r"^([A-Za-z0-9][A-Za-z0-9._-]*)\s*(==|@)\s*(.+)$")
FULL_COMMIT_PATTERN = re.compile(r"[0-9a-fA-F]{40}")


def canonicalize_name(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def parse_runtime_packages(value: str) -> set[str]:
    return {
        canonicalize_name(name)
        for name in re.split(r"[\s,]+", value)
        if name.strip()
    }


def parse_requirement_blocks(content: str) -> list[tuple[str, str, str]]:
    blocks: list[str] = []
    current: list[str] = []
    for line in content.splitlines():
        if not line.strip():
            continue
        if line[0].isspace():
            if not current:
                raise ValueError(f"Unexpected requirement continuation: {line}")
            current.append(line)
            continue
        if current:
            blocks.append("\n".join(current))
        current = [line]
    if current:
        blocks.append("\n".join(current))

    requirements = []
    for block in blocks:
        logical = re.sub(r"\\\s*\n\s*", " ", block).strip()
        match = NAME_PATTERN.match(logical)
        if not match:
            raise ValueError(f"Unsupported exported requirement: {logical}")
        requirements.append((canonicalize_name(match.group(1)), match.group(2), block))
    return requirements


def validate_git_requirement(block: str) -> None:
    logical = re.sub(r"\\\s*\n\s*", " ", block).strip()
    match = NAME_PATTERN.match(logical)
    if not match or match.group(2) != "@":
        raise ValueError(f"Only Git and registry dependencies are supported: {logical}")

    direct_url = match.group(3).split(" ;", maxsplit=1)[0].strip()
    if not direct_url.startswith("git+"):
        raise ValueError(f"Only Git and registry dependencies are supported: {logical}")

    parsed = urllib.parse.urlsplit(direct_url.removeprefix("git+"))
    _, revision_separator, revision = parsed.path.rpartition("@")
    if not revision_separator or not FULL_COMMIT_PATTERN.fullmatch(revision):
        raise ValueError(f"Git dependency is not pinned to a full commit: {logical}")

    if parsed.password or (parsed.scheme in {"http", "https"} and parsed.username):
        raise ValueError("Git dependency URL contains credentials")


def write_requirements(path: Path, blocks: list[str]) -> None:
    content = "\n".join(blocks)
    path.write_text(f"{content}\n" if content else "", encoding="utf-8")


def run(
    command: list[str],
    *,
    cwd: Path,
    hide_stdout: bool = False,
    environment: dict[str, str] | None = None,
) -> None:
    subprocess.run(
        command,
        cwd=cwd,
        check=True,
        stdout=subprocess.DEVNULL if hide_stdout else None,
        env=environment,
    )


def create_git_build_environment(token: str) -> dict[str, str]:
    environment = {
        **os.environ,
        "PYTHONHASHSEED": "0",
        "SOURCE_DATE_EPOCH": "315532800",
    }
    if not token:
        return environment

    credentials = base64.b64encode(f"x-access-token:{token}".encode()).decode()
    header_key = "http.https://github.com/.extraheader"
    environment.update(
        {
            "GIT_CONFIG_COUNT": "2",
            "GIT_CONFIG_KEY_0": header_key,
            "GIT_CONFIG_VALUE_0": "",
            "GIT_CONFIG_KEY_1": header_key,
            "GIT_CONFIG_VALUE_1": f"AUTHORIZATION: basic {credentials}",
        }
    )
    return environment


def find_lock(package_path: Path) -> Path:
    for directory in (package_path, *package_path.parents):
        lock_path = directory / "uv.lock"
        if lock_path.is_file():
            return lock_path
        if (directory / ".git").exists():
            break
    raise FileNotFoundError(f"Frozen uv.lock not found for: {package_path}")


def load_index_arguments(project_paths: list[Path]) -> list[str]:
    indexes: list[dict] = []
    for project_path in dict.fromkeys(project_paths):
        if not project_path.is_file():
            continue
        project = tomllib.loads(project_path.read_text(encoding="utf-8-sig"))
        indexes.extend(project.get("tool", {}).get("uv", {}).get("index", []))

    arguments = []
    for index in indexes:
        url = index.get("url")
        if not url:
            continue
        parsed = urllib.parse.urlsplit(url)
        if parsed.password or parsed.username:
            raise ValueError("Package index URL contains credentials")
        arguments.extend(
            ["--index-url" if index.get("default") else "--extra-index-url", url]
        )
    return arguments


def load_locked_packages(lock_path: Path) -> dict[tuple[str, str], set[str]]:
    with lock_path.open("rb") as lock_file:
        lock = tomllib.load(lock_file)

    packages: dict[tuple[str, str], set[str]] = {}
    for package in lock.get("package", []):
        source = package.get("source", {})
        source_types = set(source)
        supported = source_types.intersection({"git", "registry"})
        if not supported:
            continue
        key = (canonicalize_name(package["name"]), str(package["version"]))
        packages.setdefault(key, set()).update(supported)
    return packages


def read_wheel_metadata(wheel: Path) -> tuple[str, str]:
    with zipfile.ZipFile(wheel) as archive:
        metadata_paths = [
            name for name in archive.namelist() if name.endswith(".dist-info/METADATA")
        ]
        if len(metadata_paths) != 1:
            raise ValueError(f"Expected one METADATA file in {wheel.name}")
        metadata = archive.read(metadata_paths[0]).decode("utf-8")

    name = next(
        (line.removeprefix("Name: ").strip() for line in metadata.splitlines() if line.startswith("Name: ")),
        None,
    )
    version = next(
        (
            line.removeprefix("Version: ").strip()
            for line in metadata.splitlines()
            if line.startswith("Version: ")
        ),
        None,
    )
    if not name or not version:
        raise ValueError(f"Missing package name or version in {wheel.name}")
    return canonicalize_name(name), version


def create_manifest(
    wheelhouse: Path, locked_packages: dict[tuple[str, str], set[str]]
) -> list[dict[str, str]]:
    packages = []
    for wheel in sorted(wheelhouse.glob("*.whl"), key=lambda path: path.name.lower()):
        name, version = read_wheel_metadata(wheel)
        source_types = locked_packages.get((name, version))
        if not source_types:
            raise ValueError(
                f"{wheel.name} does not match a Git or registry package in uv.lock"
            )
        digest = hashlib.sha256(wheel.read_bytes()).hexdigest()
        packages.append(
            {
                "name": name,
                "version": version,
                "source": min(source_types),
                "filename": wheel.name,
                "sha256": digest,
            }
        )
    return sorted(
        packages,
        key=lambda package: (
            package["name"],
            package["version"],
            package["filename"],
        ),
    )


def verify_offline_install(dist: Path, requirements: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="offline-wheelhouse-verify-") as temp_dir:
        venv = Path(temp_dir) / "venv"
        run([sys.executable, "-m", "venv", str(venv)], cwd=dist)
        python = venv / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
        run(
            [
                str(python),
                "-m",
                "pip",
                "install",
                "--no-index",
                "--no-deps",
                "--require-hashes",
                "-r",
                requirements.name,
            ],
            cwd=dist,
        )


def build_wheelhouse(package_path: Path, runtime_packages: set[str]) -> None:
    package_path = package_path.resolve()
    lock_path = find_lock(package_path)
    if sys.platform != "linux" or platform.machine().lower() not in {"x86_64", "amd64"}:
        raise RuntimeError("Offline wheelhouses must be built on Linux x86-64")

    dist = package_path / "dist"
    wheelhouse = dist / "wheelhouse"
    requirements = dist / "offline-requirements.txt"
    manifest = dist / "offline-wheelhouse-manifest.json"
    shutil.rmtree(wheelhouse, ignore_errors=True)
    requirements.unlink(missing_ok=True)
    manifest.unlink(missing_ok=True)
    wheelhouse.mkdir(parents=True)

    with tempfile.TemporaryDirectory(prefix="offline-wheelhouse-build-") as temp_dir:
        temp = Path(temp_dir)
        exported = temp / "exported-requirements.txt"
        run(
            [
                "uv",
                "export",
                "--frozen",
                "--no-dev",
                "--no-default-groups",
                "--no-emit-project",
                "--no-editable",
                "--no-header",
                "--no-annotate",
                "--output-file",
                str(exported),
            ],
            cwd=package_path,
            hide_stdout=True,
        )

        registry_blocks = []
        git_blocks = []
        exported_requirements = parse_requirement_blocks(
            exported.read_text(encoding="utf-8")
        )
        exported_names = {name for name, _, _ in exported_requirements}
        unknown_runtime_packages = runtime_packages.difference(exported_names)
        if unknown_runtime_packages:
            raise ValueError(
                "Runtime package names are not present in the exported frozen lock: "
                + ", ".join(sorted(unknown_runtime_packages))
            )

        for name, operator, block in exported_requirements:
            if name in runtime_packages:
                continue
            if operator == "==":
                registry_blocks.append(block)
            else:
                validate_git_requirement(block)
                git_blocks.append(block)

        if registry_blocks:
            registry_requirements = temp / "registry-requirements.txt"
            write_requirements(registry_requirements, registry_blocks)
            index_arguments = load_index_arguments(
                [lock_path.parent / "pyproject.toml", package_path / "pyproject.toml"]
            )
            run(
                [
                    sys.executable,
                    "-m",
                    "pip",
                    "download",
                    "--only-binary=:all:",
                    "--no-deps",
                    "--require-hashes",
                    *index_arguments,
                    "--dest",
                    str(wheelhouse),
                    "--requirement",
                    str(registry_requirements),
                ],
                cwd=package_path,
            )
        if git_blocks:
            git_requirements = temp / "git-requirements.txt"
            write_requirements(git_requirements, git_blocks)
            run(
                [
                    sys.executable,
                    "-m",
                    "pip",
                    "wheel",
                    "--no-deps",
                    "--wheel-dir",
                    str(wheelhouse),
                    "--requirement",
                    str(git_requirements),
                ],
                cwd=package_path,
                environment=create_git_build_environment(
                    os.environ.get("OFFLINE_WHEELHOUSE_GIT_TOKEN", "")
                ),
            )

    packages = create_manifest(wheelhouse, load_locked_packages(lock_path))
    requirement_lines = [
        f"wheelhouse/{package['filename']} --hash=sha256:{package['sha256']}"
        for package in packages
    ]
    write_requirements(requirements, requirement_lines)
    manifest.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "target": {
                    "operating_system": "linux",
                    "architecture": "x86_64",
                    "python": f"{sys.version_info.major}.{sys.version_info.minor}",
                },
                "runtime_packages": sorted(runtime_packages),
                "packages": packages,
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    verify_offline_install(dist, requirements)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--package-path", type=Path, required=True)
    parser.add_argument("--runtime-packages", default="")
    args = parser.parse_args()
    build_wheelhouse(
        args.package_path,
        parse_runtime_packages(args.runtime_packages),
    )


if __name__ == "__main__":
    main()
