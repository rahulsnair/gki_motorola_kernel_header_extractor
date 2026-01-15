# GKI Kernel Header Extractor (ARM64)

This repository documents the minimal and correct steps to prepare an Android **GKI (Generic Kernel Image)** kernel tree for ARM64, using the GNU AArch64 cross-compiler. The result is a clean kernel source ready for external module builds and userspace header extraction.

---

## Install Toolchain

Install the ARM64 GNU cross-compiler:

```bash
sudo apt update
sudo apt install gcc-aarch64-linux-gnu
```

This provides the `aarch64-linux-gnu-` toolchain required for kernel builds.

---

## Navigate to Kernel Source

```bash
cd /home/rahulsnair/android/lineage/device/motorola/kernel-mtk
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

## Extract Headers

Navigate to the directory containing `extract-header.sh`, then execute it:

```bash
cd <path-to-extract-header.sh>
./extract-header.sh
```

This script is typically used to collect and package the generated headers for downstream Android builds. Make sure you change paths inside extract-header.sh.

---

## Result

After completing these steps, the kernel source tree will:

* Be configured for **ARM64 GKI**
* Contain generated internal kernel headers
* Provide exported userspace (UAPI) headers
* Be ready for external module and Android HAL builds

---

## Notes

* Re-run `modules_prepare` after any change to `.config`
* Always use the same toolchain for kernel and module builds
* Do not manually modify generated headers

---

## License

This project follows the licensing terms defined by the Android Open Source Project (AOSP).
