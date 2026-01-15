#!/bin/bash

# ================= CONFIGURATION =================
# Path to your GKI Core (Repo 1) - pure Google code
KERNEL_CORE="/home/rahulsnair/android/lineage/kernel/motorola/cybert"

# Path to your Modules/Drivers (Repo 2) - Motorola/MTK code
KERNEL_MODULES="/home/rahulsnair/android/lineage/kernel/motorola/cybert-modules"

# Destination: Your LineageOS device tree headers
OUTPUT_DIR="/home/rahulsnair/android/lineage/device/motorola/cybert-kernel/headers"
# =================================================

echo "Starting Kernel 6.1 Split-Source Header Merge (V3)..."

mkdir -p "$OUTPUT_DIR"

# ---------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------
sync_headers() {
    local src=$1
    local dest=$2
    if [ -d "$src" ]; then
        echo ">> Merging $src..."
        mkdir -p "$dest"
        # Strict cleanup: Only .h files, no junk.
        rsync -avm \
            --include='*/' --include='*.h' \
            --exclude='*.c' --exclude='*.o' --exclude='*.S' --exclude='*.ko' \
            --exclude='*.cmd' --exclude='*.a' --exclude='*.mod*' \
            --exclude='Makefile' --exclude='Kconfig*' --exclude='Kbuild*' \
            --exclude='*.txt' --exclude='*.md' --exclude='*.sh' \
            --exclude='.*' --exclude='*' \
            "$src/" "$dest/"
    else
        echo "-- Skipping $src (Not found)"
    fi
}

# ---------------------------------------------------------
# Phases 1 & 2: Copying Headers
# ---------------------------------------------------------
echo ">> Phase 1: Core Kernel Headers (GKI)"
sync_headers "$KERNEL_CORE/usr/include"      "$OUTPUT_DIR/usr/include"
sync_headers "$KERNEL_CORE/include"          "$OUTPUT_DIR/include"
sync_headers "$KERNEL_CORE/arch"             "$OUTPUT_DIR/arch"
sync_headers "$KERNEL_CORE/drivers"          "$OUTPUT_DIR/drivers"
sync_headers "$KERNEL_CORE/sound"            "$OUTPUT_DIR/sound"
sync_headers "$KERNEL_CORE/fs"               "$OUTPUT_DIR/fs"
sync_headers "$KERNEL_CORE/net"              "$OUTPUT_DIR/net"

# ---------------------------------------------------------
# Phase 2: Vendor Module Headers (Motorola/MTK)
# ---------------------------------------------------------
echo ">> Phase 2: Vendor Module Headers (Motorola/MTK)"
sync_headers "$KERNEL_MODULES/include"       "$OUTPUT_DIR/include"
sync_headers "$KERNEL_MODULES/arch"          "$OUTPUT_DIR/arch"
sync_headers "$KERNEL_MODULES/drivers"       "$OUTPUT_DIR/drivers"
sync_headers "$KERNEL_MODULES/sound"         "$OUTPUT_DIR/sound"
sync_headers "$KERNEL_MODULES/fs"            "$OUTPUT_DIR/fs"
sync_headers "$KERNEL_MODULES/kernel"        "$OUTPUT_DIR/kernel"

# ---------------------------------------------------------
# Phase 3: Generate the Makefile (The New Part)
# ---------------------------------------------------------
echo ">> Phase 3: Generating Makefile..."

# 1. Extract Version from the actual Kernel Source
# We read the first few lines of the kernel-mtk/Makefile
K_VERSION=$(grep "^VERSION =" $KERNEL_CORE/Makefile | awk '{print $3}' | head -n 1)
K_PATCHLEVEL=$(grep "^PATCHLEVEL =" $KERNEL_CORE/Makefile | awk '{print $3}' | head -n 1)
K_SUBLEVEL=$(grep "^SUBLEVEL =" $KERNEL_CORE/Makefile | awk '{print $3}' | head -n 1)

if [ -z "$K_VERSION" ]; then
    # Fallback if extraction fails
    echo "Warning: Could not extract version. Defaulting to 6.1.0"
    K_VERSION=6
    K_PATCHLEVEL=1
    K_SUBLEVEL=0
else
    echo "Detected Kernel Version: $K_VERSION.$K_PATCHLEVEL.$K_SUBLEVEL"
fi

# 2. Write the Makefile to the output directory
cat > "$OUTPUT_DIR/Makefile" <<EOF
VERSION = $K_VERSION
PATCHLEVEL = $K_PATCHLEVEL
SUBLEVEL = $K_SUBLEVEL

# Standard clean/install targets for Android Build System
headers_install:
	@echo "  INSTALL headers to \$(O)/usr"
	@mkdir -p \$(O)/usr
	@rsync -mrq --exclude=Makefile \$(shell pwd)/ \$(O)/

modules_install:
	@true

all:
	@true
EOF

# ---------------------------------------------------------
# Phase 4: Final Cleanup
# ---------------------------------------------------------
echo ">> Phase 4: Final Polish"
find "$OUTPUT_DIR" -type d -empty -delete
find "$OUTPUT_DIR" -type d -exec chmod 755 {} +
find "$OUTPUT_DIR" -type f -name "*.h" -exec chmod 644 {} +
chmod 644 "$OUTPUT_DIR/Makefile"

echo "------------------------------------------------"
echo "Success! Headers and Makefile ready at: $OUTPUT_DIR"
