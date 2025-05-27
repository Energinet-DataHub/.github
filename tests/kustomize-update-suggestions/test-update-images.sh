#!/bin/bash

set +e

BASE=$(dirname "$0")
SCRIPT="$BASE/../../.github/actions/kustomize-update-suggestions/update-images.sh"
FIXTURES="$BASE/fixtures"
RESOURCES="/tmp/fixtures"
TMP=/tmp/logs
TAGGING="/tmp/tagging"
export PATH="$BASE/mocks:$PATH"

echo "alpine:3" > "$TAGGING"

reset_resources() {
    find "$TMP" -type f -not -name .gitignore -delete
    rm -rf "$RESOURCES" 2>/dev/null
    mkdir -p "$RESOURCES"
    cp -r "$FIXTURES" "$RESOURCES"
}

reset_resources
echo "Test that only the configured alpine is set to a hash"
cat << EOF >"$TMP/expected"
::notice::no tag configuration for: nginxinc/nginx-unprivileged
+ sed -i '14s|^.*$|          image: alpine@sha256:hash # 3|' /tmp/fixtures/fixtures/deployment.yaml
+ sed -i '22s|^.*$|          image: alpine@sha256:hash # 3|' /tmp/fixtures/fixtures/deployment.yaml
EOF
bash "$SCRIPT" "$RESOURCES" /dev/null "$TAGGING" >"$TMP/out" 2>&1
diff "$TMP/expected" "$TMP/out" || exit 1

reset_resources
echo "Test that excludes prevents updates"
echo "$RESOURCES" >"$TMP/excludes"
bash "$SCRIPT" "$RESOURCES" "$TMP/excludes" "$TAGGING" >"$TMP/out" 2>&1
diff /dev/null "$TMP/out" || exit 1

reset_resources
echo "Test that no configurations results in no updates"
cat << EOF >"$TMP/expected"
::notice::no tag configuration for: nginxinc/nginx-unprivileged
::notice::no tag configuration for: alpine
::notice::no tag configuration for: alpine
EOF
bash "$SCRIPT" "$RESOURCES" /dev/null /dev/null >"$TMP/out" 2>&1
diff "$TMP/expected" "$TMP/out" || exit 1

reset_resources
echo "Test that only the configured alpine is set to a hash when other things are excluded"
cat << EOF >"$TMP/expected"
::notice::no tag configuration for: nginxinc/nginx-unprivileged
+ sed -i '14s|^.*$|          image: alpine@sha256:hash # 3|' /tmp/fixtures/fixtures/deployment.yaml
+ sed -i '22s|^.*$|          image: alpine@sha256:hash # 3|' /tmp/fixtures/fixtures/deployment.yaml
EOF
printf "doesnotmatter\nalsoirrelevant\n" >"$TMP/excludes"
bash "$SCRIPT" "$RESOURCES" "$TMP/excludes" "$TAGGING" >"$TMP/out" 2>&1
diff "$TMP/expected" "$TMP/out" || exit 1

reset_resources
echo "Test that non-matching configurations results in no updates"
cat << EOF >"$TMP/expected"
::notice::no tag configuration for: nginxinc/nginx-unprivileged
::notice::no tag configuration for: alpine
::notice::no tag configuration for: alpine
EOF
printf "nginx:latest\nubuntu:latest\n" >"$TMP/tags"
bash "$SCRIPT" "$RESOURCES" /dev/null "$TMP/tags" >"$TMP/out" 2>&1
diff "$TMP/expected" "$TMP/out" || exit 1

echo "Success!"
