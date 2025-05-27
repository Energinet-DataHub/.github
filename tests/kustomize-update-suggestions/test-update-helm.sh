#!/bin/bash

set +e

BASE=$(dirname "$0")
SCRIPT="$BASE/../../.github/actions/kustomize-update-suggestions/update-helm.sh"
FIXTURES="$BASE/fixtures"
RESOURCES="/tmp/fixtures"
TMP=/tmp/logs
export PATH="$BASE/mocks:$PATH"

reset_resources() {
    find "$TMP" -type f -not -name .keep -delete
    rm -rf "$RESOURCES" 2>/dev/null
    mkdir -p "$RESOURCES"
    cp -r "$FIXTURES" "$RESOURCES"
}

reset_resources
echo "Test cert-manager is marked as updatable"
cat << EOF >"$TMP/expected"
+ yq -ie '(.helmCharts[] | select(.name == "cert-manager") | .version) = "3.0.0"' /tmp/fixtures/fixtures/kustomization.yaml
+ yq -ie '(.helmCharts[] | select(.name == "thanos") | .version) = "2.0.0"' /tmp/fixtures/fixtures/kustomization.yaml
EOF
bash "$SCRIPT" "$RESOURCES" /dev/null >"$TMP/out" 2>&1
diff "$TMP/expected" "$TMP/out" || exit 1

reset_resources
echo "Test excludes correctly prevents cert-manager from being marked"
echo "$RESOURCES" >"$TMP/excludes"
bash "$SCRIPT" "$RESOURCES" "$TMP/excludes" >"$TMP/out" 2>&1
diff /dev/null "$TMP/out" || exit 1

reset_resources
echo "Test cert-manager is marked as updatable when other things are excluded"
cat << EOF >"$TMP/expected"
+ yq -ie '(.helmCharts[] | select(.name == "cert-manager") | .version) = "3.0.0"' /tmp/fixtures/fixtures/kustomization.yaml
+ yq -ie '(.helmCharts[] | select(.name == "thanos") | .version) = "2.0.0"' /tmp/fixtures/fixtures/kustomization.yaml
EOF
printf "doesnotmatter\nalsoirrelevant\n" >"$TMP/excludes"
bash "$SCRIPT" "$RESOURCES" "$TMP/excludes" /dev/null >"$TMP/out" 2>&1
diff "$TMP/expected" "$TMP/out" || exit 1

echo "Success!"
