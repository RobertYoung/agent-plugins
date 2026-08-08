#!/bin/bash

# Parse requirements.yml and check for latest tags
yq eval '.roles[] | select(.src | test("git|github|gitlab")) | [.name, .src, .version] | @tsv' requirements.yml | \
while IFS=$'\t' read -r name src version; do
    echo "=== $name ==="
    echo "Current: $version"
    
    # Get latest tag from remote
    latest=$(git ls-remote --tags --sort=-v:refname "$src" 2>/dev/null | \
             grep -v '{}' | head -1 | sed 's/.*refs\/tags\///')
    
    echo "Latest:  $latest"
    
    if [[ "$version" != "$latest" ]]; then
        echo "⚠️  UPDATE AVAILABLE"
    else
        echo "✅ Up to date"
    fi
    echo ""
done