# GKI Kernel Header Extractor (ARM64)

This repository documents the minimal and correct steps to prepare an Android **GKI (Generic Kernel Image)** kernel tree for ARM64, using the GNU AArch64 cross-compiler. The result is a clean kernel source ready for external module builds and userspace header extraction.

## Clone the Core Kernel (GKI)
git clone https://github.com/MotorolaMobilityLLC/kernel-mtk.git -b MMI-W1VV36H.7-21-5 /home/rahulsnair/android/lineage/kernel/motorola/cybert

## Clone the Device Modules (Drivers)
git clone https://github.com/MotorolaMobilityLLC/kernel-kernel_device_modules-6.1.git -b MMI-W1VV36H.7-21-5 /home/rahulsnair/android/lineage/kernel/motorola/cybert-modules

---

## Install Toolchain

Install the ARM64 GNU cross-compiler:

```bash
sudo apt update
sudo apt install gcc-aarch64-linux-gnu rsync
```

This provides the `aarch64-linux-gnu-` toolchain (for kernel builds) and `rsync` (for header extraction).

---

## Navigate to Kernel Source

```bash
cd /home/rahulsnair/android/lineage/kernel/motorola/cybert
```

Adjust the path according to your local setup.

---

## Clean the Kernel Tree

Remove any artifacts from previous build attempts:

```bash
make clean && make mrproper
```

---

## Load GKI Configuration

Generate the default GKI kernel configuration:

```bash
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- gki_defconfig
```

This creates a `.config` aligned with Android GKI requirements.

---

## Prepare Kernel Headers (Required)

Generate internal kernel headers such as `autoconf.h` and `version.h`:

```bash
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- modules_prepare
```

This step is mandatory for external kernel module builds.

---

## Install Userspace (UAPI) Headers

Export kernel headers used by Android HALs and userspace components:

```bash
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- headers_install INSTALL_HDR_PATH=usr
```

Headers will be installed under the `usr/` directory inside the kernel tree.

---

## Extract UAPI Headers

The `extractor/extract_headers.sh` script is the core tool of this repository. It automates the collection, merging, and sanitization of **UAPI (Userspace API)** kernel headers.

### Features & Phases

1.  **Phase 1: Base Headers**
    *   Copies standard Linux headers from the GKI Core (`usr/include`).
    *   Falls back to running `make headers_install` if pre-generated headers are missing.

2.  **Phase 2: Vendor Overlays**
    *   Merges vendor-specific headers from `include/` (e.g., `linux`, `soc`, `dt-bindings`).
    *   Correctly maps `include/uapi` to the root `usr/include`.
    *   **Special Handling**: Automatically detects and includes Mali GPU UAPI headers (`drivers/.../midgard/include/uapi`).

3.  **Phase 3: Recursive Dependency Resolver**
    *   This is the critical step. The script recursively scans all extracted headers for `#include <...>` directives.
    *   If a referenced header is missing (e.g., `asm/types.h`), it locates the file in the GKI Source (`arch/arm64/include/asm` or `include/`) and copies it.
    *   This ensures the final tarball is *self-contained* without needing the full kernel source tree.

4.  **Phase 4: Packaging**
    *   Sets correct file permissions.
    *   Generates a `kernel-uapi-headers.tar.gz` ready for the Android build system.

### Usage

1.  **Verify Configuration**:
    Open `extractor/extract_headers.sh` and ensure the following variables match your directory structure:
    *   `KERNEL_CORE`: Path to the GKI source.
    *   `KERNEL_MODULES`: Path to the vendor modules source.
    *   `DEST_DIR`: Where the resulting tarball should be saved.

2.  **Run the Script**:

```bash
cd extractor
chmod +x extract_headers.sh
./extract_headers.sh
```

---

## Result

After completing these steps, the kernel source tree will:

* Be configured for **ARM64 GKI**
* Contain generated internal kernel headers
* Provide exported userspace (UAPI) headers
* Have a generated `kernel-uapi-headers.tar.gz` package (if script was run)
* Be ready for external module and Android HAL builds

---

## Notes

* Re-run `modules_prepare` after any change to `.config`
* Always use the same toolchain for kernel and module builds
* Do not manually modify generated headers

---

## License

This project follows the licensing terms defined by the Android Open Source Project (AOSP).
