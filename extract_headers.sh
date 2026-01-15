#!/bin/bash
# Optimized Kernel Header Extractor for LineageOS (GKI + Modules)
#
# Goals:
# 1. Functional: Include all headers required by vendor modules (recursive resolution).
# 2. Structure: Maintain correct kernel header directory structure.
# 3. Base: Use pre-generated UAPI from GKI Core as the base.

set -e

# ================= CONFIGURATION =================
# Path to GKI Core (Repo 1)
KERNEL_CORE="/home/rahulsnair/android/lineage/kernel/motorola/cybert"

# Path to Modules/Drivers (Repo 2)
KERNEL_MODULES="/home/rahulsnair/android/lineage/kernel/motorola/cybert-modules"

# Destination: LineageOS device tree directory
DEST_DIR="/home/rahulsnair/android/lineage/device/motorola/cybert-kernel"
TARBALL_NAME="kernel-uapi-headers.tar.gz"

# Staging Directory for extraction
OUTPUT_DIR=$(mktemp -d)
trap 'rm -rf "$OUTPUT_DIR"' EXIT
# =================================================

echo ">> Starting Header Extraction for GKI..."
echo "   Core:    $KERNEL_CORE"
echo "   Modules: $KERNEL_MODULES"
echo "   Staging: $OUTPUT_DIR"
echo "   Target:  $DEST_DIR/$TARBALL_NAME"

# ---------------------------------------------------------
# Phase 1: Base Headers (Pre-generated GKI UAPI)
# ---------------------------------------------------------
echo ">> Phase 1: Copying Base Headers from $KERNEL_CORE/usr/include..."

if [ -d "$KERNEL_CORE/usr/include" ]; then
    mkdir -p "$OUTPUT_DIR/usr/include"
    rsync -avm \
        --include='*/' --include='*.h' \
        --exclude='*' \
        "$KERNEL_CORE/usr/include/" "$OUTPUT_DIR/usr/include/" > /dev/null
else
    echo "   [!] $KERNEL_CORE/usr/include not found. Falling back to make headers_install..."
    make -C "$KERNEL_CORE" O="$OUTPUT_DIR" ARCH=arm64 headers_install > /dev/null
fi

# ---------------------------------------------------------
# Phase 2: Vendor Module Headers (Overlay)
# ---------------------------------------------------------
echo ">> Phase 2: Overlaying Vendor Module Headers..."

merge_headers() {
    local src=$1
    local dest=$2
    if [ -d "$src" ]; then
        echo "   Merging $src -> $dest"
        rsync -avm \
            --include='*/' --include='*.h' \
            --exclude='*' \
            "$src/" "$dest/" > /dev/null
    else
        echo "   [!] Directory not found: $src"
    fi
}

# 1. Merge ALL directories from Modules Include (uapi, linux, soc, dt-bindings, performance, trace, etc.)
echo "   Merging all vendor includes..."
for DIR in "$KERNEL_MODULES/include/"*; do
    if [ -d "$DIR" ]; then
        BASENAME=$(basename "$DIR")
        
        # 'uapi' contents go to the root of usr/include.
        # All other directories (linux, soc, etc.) are merged as subdirectories.
        if [ "$BASENAME" == "uapi" ]; then
             echo "     + Merging uapi root..."
             merge_headers "$DIR" "$OUTPUT_DIR/usr/include"
        else
             echo "     + Merging $BASENAME..."
             merge_headers "$DIR" "$OUTPUT_DIR/usr/include/$BASENAME"
        fi
    fi
done

# 2. Mali GPU UAPI (Special Case from Drivers)
MALI_UAPI_PATH=$(find "$KERNEL_MODULES/drivers" -type d -path "*/midgard/include/uapi" | head -n 1)
if [ -n "$MALI_UAPI_PATH" ]; then
    echo "   Found Mali GPU UAPI: $MALI_UAPI_PATH"
    merge_headers "$MALI_UAPI_PATH" "$OUTPUT_DIR/usr/include"
fi

# ---------------------------------------------------------
# Phase 3: Resolver (Recursive Import Backfill)
# ---------------------------------------------------------
echo ">> Phase 3: Resolving Recursive Dependencies..."
# Logic: Grep for all '#include <...>' usage in the output headers.
# If a referenced file is missing, copy it from the Kernel Core source.
# This ensures a self-contained header set without including the entire kernel source.

MAX_LOOPS=30
LOOP_COUNT=0

while [ $LOOP_COUNT -lt $MAX_LOOPS ]; do
    LOOP_COUNT=$((LOOP_COUNT+1))
    echo "   [Loop $LOOP_COUNT] Scanning for missing includes..."
    
    # regex matches: #include <path/to/file.h>
    INCLUDES=$(grep -r -h "^#include <.*>" "$OUTPUT_DIR/usr/include" | \
               sed 's/#include <//; s/>.*//' | \
               sort -u)
    
    MOVED_COUNT=0
    
    for INC in $INCLUDES; do
        target_path="$OUTPUT_DIR/usr/include/$INC"
        
        # If the header reference is missing in our output...
        if [ ! -f "$target_path" ]; then
             
             # Case A: Architecture-specific headers (asm/...), typically located in arch/arm64/include/asm
             if [[ "$INC" == "asm/"* ]]; then
                 REAL_NAME="${INC#asm/}"
                 # Assume arm64 for this device
                 ARCH_SRC="$KERNEL_CORE/arch/arm64/include/asm/$REAL_NAME"
                 if [ -f "$ARCH_SRC" ]; then
                      mkdir -p "$(dirname "$target_path")"
                      cp "$ARCH_SRC" "$target_path"
                      MOVED_COUNT=$((MOVED_COUNT+1))
                 fi
                 
             # Case B: Standard headers (linux/..., asm-generic/...), located in include/
             elif [ -f "$KERNEL_CORE/include/$INC" ]; then
                 mkdir -p "$(dirname "$target_path")"
                 cp "$KERNEL_CORE/include/$INC" "$target_path"
                 MOVED_COUNT=$((MOVED_COUNT+1))
             fi
        fi
    done
    
    if [ "$MOVED_COUNT" -eq 0 ]; then
        echo "   Dependency tree stabilized."
        break
    else
        echo "   -> Added $MOVED_COUNT new headers."
    fi
done

# Ensure kconfig.h exists (often generated or minimal in userspace)
if [ ! -f "$OUTPUT_DIR/usr/include/linux/kconfig.h" ]; then
   touch "$OUTPUT_DIR/usr/include/linux/kconfig.h"
fi

# ---------------------------------------------------------
# Phase 4: Final Cleanup & Compression
# ---------------------------------------------------------
echo ">> Phase 4: Setting Permissions..."
find "$OUTPUT_DIR" -type d -exec chmod 755 {} +
find "$OUTPUT_DIR" -type f -name "*.h" -exec chmod 644 {} +

echo ">> Phase 5: Creating Tarball..."
mkdir -p "$DEST_DIR"
cd "$OUTPUT_DIR"
# Archive the 'usr' directory structure
tar -czf "$DEST_DIR/$TARBALL_NAME" usr/

echo "------------------------------------------------"
echo "Success! Package created at: $DEST_DIR/$TARBALL_NAME"

