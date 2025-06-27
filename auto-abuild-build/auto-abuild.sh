#!/bin/bash

# Base Build Directory
BUILD_DIR=$1
BUILD_DIR=${BUILD_DIR:-"*/"}

git pull

if command -v sudo >/dev/null 2>&1; then
    PRIVILAGE_CMD=$(command -v sudo)
elif command -v doas >/dev/null 2>&1; then
    PRIVILAGE_CMD=$(command -v doas)
else
    echo "sudo/doas do not existed! exiting..."
    exit 1
fi

dirs=$(ls -d */ | sed 's:/$::')

packages_ok=()
packages_failed=()

for dir in $dirs; do
    if [ -f "$dir/APKBUILD" ]; then
        echo "✅ $dir: APKBUILD found, running..."
        cd "$dir" || exit 1

        if ! $PRIVILAGE_CMD -u builder abuild -r; then
            packages_failed+=("$dir")
            echo "❌ Build for $dir failed!....collecting"
        else
            packages_ok+=("$dir")
            echo "✅ Build for $dir succeeded."
        fi

        cd ..
    else
        echo "⛔ $dir: No APKBUILD found, skipping."
    fi
done

# Summary
echo
echo "✅ Successful packages:"
for pkg in "${packages_ok[@]}"; do
    echo "  - $pkg"
done

echo
echo "❌ Failed packages:"
for pkg in "${packages_failed[@]}"; do
    echo "  - $pkg"
done