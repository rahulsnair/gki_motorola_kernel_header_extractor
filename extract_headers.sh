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
        # Flags: -u (update), -r (recursive), -m (prune empty)
        # Strictly copy only headers (.h, .dtsi) to keep size down
        rsync -avm \
            --include='*/' --include='*.h' --include='*.dtsi' \
            --exclude='*.c' --exclude='*.o' --exclude='*.S' --exclude='*.cmd' --exclude='Makefile' --exclude='*.bp' --exclude='*' \
            "$src/" "$dest/"
    else
        echo "-- Skipping $src (Not found)"
    fi
}

# ---------------------------------------------------------
# STEP 1: Copy Core GKI Headers (The Base)
# ---------------------------------------------------------
echo ">> Phase 1: Core Kernel Headers (GKI)"
# Standard Includes
sync_headers "$KERNEL_CORE/usr/include"          "$OUTPUT_DIR/usr/include"
sync_headers "$KERNEL_CORE/include"              "$OUTPUT_DIR/include"
sync_headers "$KERNEL_CORE/arch/arm64/include"   "$OUTPUT_DIR/arch/arm64/include"
sync_headers "$KERNEL_CORE/arch/arm/include"     "$OUTPUT_DIR/arch/arm/include"

# Standard Subsystems (Added based on your ls -F)
sync_headers "$KERNEL_CORE/drivers"              "$OUTPUT_DIR/drivers"
sync_headers "$KERNEL_CORE/sound"                "$OUTPUT_DIR/sound"
sync_headers "$KERNEL_CORE/fs"                   "$OUTPUT_DIR/fs"
sync_headers "$KERNEL_CORE/net"                  "$OUTPUT_DIR/net"

# ---------------------------------------------------------
# STEP 2: Copy Module Headers (The Overlay)
# ---------------------------------------------------------
echo ">> Phase 2: Vendor Module Headers (Motorola/MTK)"
# This will OVERWRITE or ADD to the folders created in Phase 1

# 1. Main Include Overlay (Critical)
sync_headers "$KERNEL_MODULES/include"           "$OUTPUT_DIR/include"

# 2. Architecture Specific Module Headers
sync_headers "$KERNEL_MODULES/arch/arm64/include" "$OUTPUT_DIR/arch/arm64/include"
sync_headers "$KERNEL_MODULES/arch/arm/include"   "$OUTPUT_DIR/arch/arm/include"

# 3. Drivers & Subsystems (Vendor Specifics)
sync_headers "$KERNEL_MODULES/drivers"           "$OUTPUT_DIR/drivers"
sync_headers "$KERNEL_MODULES/sound"             "$OUTPUT_DIR/sound"
sync_headers "$KERNEL_MODULES/fs"                "$OUTPUT_DIR/fs"
sync_headers "$KERNEL_MODULES/kernel"            "$OUTPUT_DIR/kernel"

# ---------------------------------------------------------
# STEP 3: Cleanup & Fix Permissions
# ---------------------------------------------------------
echo ">> Phase 3: Finalizing"
find "$OUTPUT_DIR" -type d -empty -delete
find "$OUTPUT_DIR" -type d -exec chmod 755 {} +
find "$OUTPUT_DIR" -type f -name "*.h" -exec chmod 644 {} +

echo "------------------------------------------------"
echo "Success! Headers merged at: $OUTPUT_DIR"
