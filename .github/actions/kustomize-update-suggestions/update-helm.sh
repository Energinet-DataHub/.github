#!/bin/bash

TARGET="$1"
EXCLUDES="$2"

LIST=$(find "$TARGET" -iname kustomization.yaml | sort)
tmp=$(mktemp -d)
#shellcheck disable=SC2064
trap "rm -rf $tmp" EXIT

for ITEM in $LIST; do
    yq '[.helmCharts[] | del(.valuesInline, .releaseName, .namespace, .includeCRDs)] | .[]' -o json < "$ITEM" | jq -rc | while IFS= read -r item; do
        if [ "$item" = "" ]; then
            continue
        fi

        while read -r exclude; do
            if [ "$exclude" = "" ]; then
                break
            fi
            echo "$ITEM" | grep "^$exclude" >/dev/null
            if [ "$?" -eq 0 ]; then
                break 2
            fi
        done < "$EXCLUDES"

        name=$(echo "$item" | jq -r '.name' -)
        repo=$(echo "$item" | jq -r '.repo' -)
        version=$(echo "$item" | jq -r '.version' -)

        if [[ "$repo" = oci://* ]]; then
            updatedVersion=$(helm show chart "$repo/$name" 2>/dev/null | yq .version)
        else
            updatedVersion=$(helm show chart "$name" --repo "$repo" | yq .version)
        fi

        if [ "$updatedVersion" = "" ] || [ "$updatedVersion" = "null" ]; then
            echo "::error::failed to lookup '$name' in '$repo'" 1>&2
            continue
        fi

        if [ "$updatedVersion" = "$version" ]; then
            continue
        fi

        echo "yq -ie \"(.helmCharts[] | select(.name == \\\"$name\\\") | .version) = \\\"$updatedVersion\\\"\" $ITEM"
    done | sh -x
done
