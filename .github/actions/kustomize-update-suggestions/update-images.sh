#!/bin/bash

TARGET="$1"
EXCLUDES="$2"
TAGGING="$3"

LIST=$(find "$TARGET" -name "*.yaml" | sort)
tmp=$(mktemp -d)
#shellcheck disable=SC2064
trap "rm -rf $tmp" EXIT

for ITEM in $LIST; do
    while read -r exclude; do
        if [ "$exclude" = "" ]; then
            break
        fi
        echo "$ITEM" | grep "^$exclude" >/dev/null
        if [ $? -eq 0 ]; then
            continue 2
        fi
    done < "$EXCLUDES"

    grep -q 'image: ' "$ITEM" || continue
    yq -e '.kind == "Deployment" or .kind == "StatefulSet"' "$ITEM" 2>/dev/null >/dev/null || continue

    grep -in 'image: ' "$ITEM" | while read -r line; do
        image=$(echo "$line" | cut -d':' -f3 | cut -d\  -f2 | cut -d@ -f1)
        tag=$(grep "^${image}:" "$TAGGING" | cut -d: -f2)
        if [ -z "$tag" ]; then
            echo "::notice::no tag configuration for: $image" 1>&2
            continue
        fi

        target="docker://$image:$tag"
        skopeo inspect --no-creds --format "{{.Digest}}" "$target" > "$tmp/hash"
        if [ $? -ne 0 ]; then
            echo "::error::❌ skopeo failed to lookup: $target" 1>&2
            continue
        fi
        hash=$(cat "$tmp/hash")

        number=$(echo "$line" | cut -d':' -f1)
        replacement=$(echo "$line" | cut -d':' -f2-3 | cut -d@ -f1)

        echo "sed -i '${number}s|^.*$|${replacement}@${hash} # ${tag}|' $ITEM"
    done | sh -x
done
