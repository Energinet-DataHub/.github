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
import json
import logging
import os
import subprocess
import tomllib
from dataclasses import dataclass, asdict
from pathlib import Path

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
log = logging.getLogger("python-discover-pyproject")


@dataclass
class ResultType:
    package_name: str
    package_version: str
    package_path: str
    release_name: str | None


def parse_args():
    """Parse arguments.

    Returns:
        argparse.Namespace: The parsed arguments
    """
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--packages-dir",
        required=True,
        help="Directory containing the packages",
    )
    parser.add_argument(
        "--issue-number",
        required=False,
        default="",
        help="Fetch releases from a specific issue number",
    )
    parser.add_argument(
        "--versioned-release",
        required=False,
        default=False,
        action="store_true",
        help="Whether to use versioned releases",
    )
    parser.add_argument(
        "--gh-output-key",
        required=False,
        default="matrix",
        help="The key to save the matrix to in GitHub output",
    )
    parser.add_argument(
        "--dry-run",
        required=False,
        action="store_true",
        default=False,
        help="Print the matrix without saving it to GitHub output",
    )
    return parser.parse_args()


def create_matrix(packages_dir: str, issue_number: str | int, versioned_release=False):
    """Create a matrix of packages.

    Args:
        packages_dir (str): The directory containing the packages
        releases (dict): A dictionary of releases

    Returns:
        list: A list of dictionaries with the following keys:
            - package_name: The name of the package
            - package_version: The version of the package
            - package_path: The path to the package
            - release_name: The name of the release (if any)
    """
    packages = Path(packages_dir).rglob("pyproject.toml")
    matrix = []
    for toml in packages:
        with open(toml, "rb") as fh:
            data = tomllib.load(fh)
        name = data.get("project", {}).get("name")
        version = data.get("project", {}).get("version")
        release_name = create_release_name(
            package_name=name,
            package_version=version,
            issue_number=issue_number,
            versioned_release=versioned_release,
        )
        if _check_release_exists(release_name):
            log.info("Release %s already exists", release_name)
        matrix.append(
            asdict(
                ResultType(
                    package_name=name,
                    package_version=version,
                    package_path=str(toml.parent),
                    release_name=release_name,
                )
            )
        )
    return matrix


def create_release_name(package_name, package_version, issue_number, versioned_release):
    """Create a release name.

    Args:
        package_name (str): The name of the package
        package_version (str): The version of the package
        issue_number (str): The issue number
        versioned_release (bool): Whether to use versioned releases

    Returns:
        str: The release name
    """
    if versioned_release:
        return f"{package_name}_{package_version}_{issue_number}"
    return f"{package_name}_{issue_number}"


def _check_release_exists(release_name):
    """Check if a release exists.

    Args:
        release_name (str): The name of the release

    Returns:
        bool: Whether the release exists
    """
    try:
        subprocess.run(
            ["gh", "release", "view", release_name],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        return True
    except subprocess.CalledProcessError:
        return False


def save_to_github_output(key, value):
    """Save the value to GitHub output.

    Args:
        key (str): The key (name) of the value in GITHUB_OUTPUT
        value (any): The value to save to GITHUB_OUTPUT (must be JSON serializable)
    """
    with open(os.environ["GITHUB_OUTPUT"], "a") as fh:
        print(f"{key}={json.dumps(value)}", file=fh)  # noqa: T001


def main():
    args = parse_args()
    matrix = create_matrix(
        packages_dir=args.packages_dir,
        issue_number=args.issue_number,
        versioned_release=args.versioned_release,
    )
    log.info("Found %d packages\n%s", len(matrix), json.dumps(matrix, indent=2))
    if args.dry_run:
        log.info("Dry run, not saving to GitHub output")
        return
    save_to_github_output(args.gh_output_key, matrix)


if __name__ == "__main__":
    main()
