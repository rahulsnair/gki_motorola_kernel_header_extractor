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

# Helper function
sync_headers() {
    local src=$1
    local dest=$2
    if [ -d "$src" ]; then
        echo ">> Merging $src..."
        mkdir -p "$dest"
        # STRICT CLEANUP:
        # 1. Include ONLY .h (headers) and .dtsi (sometimes needed for dtc, but mostly safe to skip if building only HALs. Keeping .h only for safety).
        # 2. Exclude everything else.
        rsync -avm \
            --include='*/' \
            --include='*.h' \
            --exclude='*.c' --exclude='*.o' --exclude='*.S' --exclude='*.ko' \
            --exclude='*.cmd' --exclude='*.a' --exclude='*.mod*' \
            --exclude='Makefile' --exclude='Kconfig*' --exclude='Kbuild*' --exclude='*.bp' \
            --exclude='*.txt' --exclude='*.md' --exclude='*.rst' --exclude='*.json' \
            --exclude='*.sh' --exclude='*.pl' --exclude='*.py' \
            --exclude='.*' \
            --exclude='*' \
            "$src/" "$dest/"
    else
        echo "-- Skipping $src (Not found)"
    fi
}

# ---------------------------------------------------------
# STEP 1: Copy Core GKI Headers
# ---------------------------------------------------------
echo ">> Phase 1: Core Kernel Headers (GKI)"
sync_headers "$KERNEL_CORE/usr/include"          "$OUTPUT_DIR/usr/include"
sync_headers "$KERNEL_CORE/include"              "$OUTPUT_DIR/include"
sync_headers "$KERNEL_CORE/arch/arm64/include"   "$OUTPUT_DIR/arch/arm64/include"
sync_headers "$KERNEL_CORE/arch/arm/include"     "$OUTPUT_DIR/arch/arm/include"

# Core Subsystems
sync_headers "$KERNEL_CORE/drivers"              "$OUTPUT_DIR/drivers"
sync_headers "$KERNEL_CORE/sound"                "$OUTPUT_DIR/sound"
sync_headers "$KERNEL_CORE/fs"                   "$OUTPUT_DIR/fs"
sync_headers "$KERNEL_CORE/net"                  "$OUTPUT_DIR/net"

# ---------------------------------------------------------
# STEP 2: Copy Module Headers
# ---------------------------------------------------------
echo ">> Phase 2: Vendor Module Headers (Motorola/MTK)"

# 1. Main Include Overlay
sync_headers "$KERNEL_MODULES/include"           "$OUTPUT_DIR/include"

# 2. Architecture Specific
sync_headers "$KERNEL_MODULES/arch/arm64/include" "$OUTPUT_DIR/arch/arm64/include"
sync_headers "$KERNEL_MODULES/arch/arm/include"   "$OUTPUT_DIR/arch/arm/include"

# 3. Drivers & Subsystems
sync_headers "$KERNEL_MODULES/drivers"           "$OUTPUT_DIR/drivers"
sync_headers "$KERNEL_MODULES/sound"             "$OUTPUT_DIR/sound"
sync_headers "$KERNEL_MODULES/fs"                "$OUTPUT_DIR/fs"
sync_headers "$KERNEL_MODULES/kernel"            "$OUTPUT_DIR/kernel"

# ---------------------------------------------------------
# STEP 3: Final Cleanup
# ---------------------------------------------------------
echo ">> Phase 3: Final Polish"
# Remove empty folders
find "$OUTPUT_DIR" -type d -empty -delete
# Fix permissions
find "$OUTPUT_DIR" -type d -exec chmod 755 {} +
find "$OUTPUT_DIR" -type f -name "*.h" -exec chmod 644 {} +

echo "------------------------------------------------"
echo "Success! Clean headers ready at: $OUTPUT_DIR"
