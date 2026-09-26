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

import base64
import importlib.util
import json
import tempfile
import unittest
import zipfile
from pathlib import Path

SCRIPT_PATH = Path(__file__).with_name("create_offline_wheelhouse.py")
SPEC = importlib.util.spec_from_file_location("create_offline_wheelhouse", SCRIPT_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(MODULE)


class CreateOfflineWheelhouseTests(unittest.TestCase):
    def test_parse_runtime_packages_normalizes_names(self):
        actual = MODULE.parse_runtime_packages("PySpark, delta_spark\nRequests")

        self.assertEqual(actual, {"pyspark", "delta-spark", "requests"})

    def test_parse_requirement_blocks_preserves_hashes(self):
        content = """\
requests==2.32.5 \\
    --hash=sha256:abc \\
    --hash=sha256:def
private-package @ git+https://github.com/example/private-package@0123456789abcdef0123456789abcdef01234567
"""

        requirements = MODULE.parse_requirement_blocks(content)

        self.assertEqual(requirements[0][0:2], ("requests", "=="))
        self.assertIn("--hash=sha256:def", requirements[0][2])
        self.assertEqual(requirements[1][0:2], ("private-package", "@"))

    def test_git_requirement_must_be_commit_pinned_and_credential_free(self):
        MODULE.validate_git_requirement(
            "package @ git+https://github.com/example/package@"
            "0123456789abcdef0123456789abcdef01234567"
        )
        with self.assertRaisesRegex(ValueError, "full commit"):
            MODULE.validate_git_requirement(
                "package @ git+https://github.com/example/package@main"
            )
        with self.assertRaisesRegex(ValueError, "credentials"):
            MODULE.validate_git_requirement(
                "package @ git+https://token@github.com/example/package@"
                "0123456789abcdef0123456789abcdef01234567"
            )

    def test_git_requirement_accepts_commit_with_subdirectory(self):
        MODULE.validate_git_requirement(
            "package @ git+https://github.com/example/package@"
            "0123456789abcdef0123456789abcdef01234567"
            "?download=1#subdirectory=src/package"
        )

    def test_git_requirement_rejects_branch_with_commit_in_fragment(self):
        with self.assertRaisesRegex(ValueError, "full commit"):
            MODULE.validate_git_requirement(
                "package @ git+https://github.com/example/package@main"
                "#subdirectory=src@0123456789abcdef0123456789abcdef01234567"
            )

    def test_git_requirement_rejects_branch_with_commit_in_query(self):
        with self.assertRaisesRegex(ValueError, "full commit"):
            MODULE.validate_git_requirement(
                "package @ git+https://github.com/example/package@main"
                "?ref=0123456789abcdef0123456789abcdef01234567"
            )

    def test_git_requirement_rejects_branch_with_commit_in_userinfo(self):
        with self.assertRaisesRegex(ValueError, "full commit"):
            MODULE.validate_git_requirement(
                "package @ git+https://"
                "0123456789abcdef0123456789abcdef01234567@github.com/"
                "example/package@main"
            )

    def test_git_requirement_rejects_tag_with_commit_in_repository_path(self):
        with self.assertRaisesRegex(ValueError, "full commit"):
            MODULE.validate_git_requirement(
                "package @ git+https://github.com/example/"
                "0123456789abcdef0123456789abcdef01234567/package@v1.0.0"
            )

    def test_manifest_uses_metadata_and_sha256_deterministically(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            wheelhouse = Path(temp_dir)
            wheel = wheelhouse / "Example_Package-1.2.3-py3-none-any.whl"
            with zipfile.ZipFile(wheel, "w") as archive:
                archive.writestr(
                    "example_package-1.2.3.dist-info/METADATA",
                    "Metadata-Version: 2.1\nName: Example_Package\nVersion: 1.2.3\n",
                )

            manifest = MODULE.create_manifest(
                wheelhouse, {("example-package", "1.2.3"): {"registry"}}
            )

            self.assertEqual(
                manifest,
                [
                    {
                        "name": "example-package",
                        "version": "1.2.3",
                        "source": "registry",
                        "filename": wheel.name,
                        "sha256": MODULE.hashlib.sha256(wheel.read_bytes()).hexdigest(),
                    }
                ],
            )

    def test_manifest_json_is_serializable(self):
        document = {
            "schema_version": 1,
            "runtime_packages": [],
            "packages": [],
        }

        self.assertEqual(json.loads(json.dumps(document)), document)

    def test_find_lock_supports_uv_workspace_members(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            workspace = Path(temp_dir)
            member = workspace / "packages" / "example"
            member.mkdir(parents=True)
            lock = workspace / "uv.lock"
            lock.touch()

            self.assertEqual(MODULE.find_lock(member), lock)

    def test_index_arguments_reject_credentials(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            project = Path(temp_dir) / "pyproject.toml"
            project.write_text(
                '[[tool.uv.index]]\nurl = "https://token@example.com/simple"\n',
                encoding="utf-8",
            )

            with self.assertRaisesRegex(ValueError, "credentials"):
                MODULE.load_index_arguments([project])

    def test_git_token_is_passed_as_an_ephemeral_authorization_header(self):
        environment = MODULE.create_git_build_environment("secret-token")

        self.assertEqual(environment["GIT_CONFIG_COUNT"], "2")
        self.assertEqual(environment["GIT_CONFIG_VALUE_0"], "")
        self.assertEqual(
            environment["GIT_CONFIG_VALUE_1"],
            "AUTHORIZATION: basic "
            + base64.b64encode(b"x-access-token:secret-token").decode(),
        )
        self.assertNotIn("secret-token", environment["GIT_CONFIG_KEY_1"])


if __name__ == "__main__":
    unittest.main()
