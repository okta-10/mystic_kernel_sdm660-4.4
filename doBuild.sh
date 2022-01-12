#!/usr/bin/env bash
# Copyright (C) 2021-2022 Oktapra Amtono <oktapra.amtono@gmail.com>
# Kernel Build Script

# Kernel Directory
KERNEL_DIR=$PWD

RELEASE_VERSION="_x8.9"

# Device Name
if [[ "$*" =~ "whyred" ]]; then
  DEVICE="whyred"
  export LOCALVERSION="$RELEASE_VERSION"
elif [[ "$*" =~ "tulip" ]]; then
  DEVICE="tulip"
  export LOCALVERSION="$RELEASE_VERSION"
elif [[ "$*" =~ "lavender" ]]; then
  DEVICE="lavender"
  export LOCALVERSION="$RELEASE_VERSION"
elif [[ "$*" =~ "a26x" ]]; then
  DEVICE="a26x"
  export LOCALVERSION="$RELEASE_VERSION"
fi

# Cam Version
if [[ "$*" =~ "oldcam" ]]; then
  CONFIGVERSION="oldcam"
elif [[ "$*" =~ "newcam" ]]; then
  CONFIGVERSION="newcam"
elif [[ "$*" =~ "tencam" ]]; then
  CONFIGVERSION="tencam"
elif [[ "$*" =~ "qtihaptics" ]]; then
  CONFIGVERSION="qtihaptics"
fi

if [[ "$*" =~ "oc" ]]; then
  export LOCALVERSION="$RELEASE_VERSION-OC"
  wget https://raw.githubusercontent.com/okta-10/my-script/main/patch/dtbs/qpnp/sdm636-mtp_e7s_oc.dtb -O ak3-whyred/dtbs/qpnp/sdm636-mtp_e7s.dtb
  wget https://raw.githubusercontent.com/okta-10/my-script/main/patch/dtbs/qti/sdm636-mtp_e7s_oc.dtb -O ak3-whyred/dtbs/qti/sdm636-mtp_e7s.dtb
  wget https://raw.githubusercontent.com/okta-10/my-script/main/patch/dtbs/qpnp/sdm636-mtp_e7t_oc.dtb -O ak3-tulip/dtbs/qpnp/sdm636-mtp_e7t.dtb
  wget https://raw.githubusercontent.com/okta-10/my-script/main/patch/dtbs/qti/sdm636-mtp_e7t_oc.dtb -O ak3-tulip/dtbs/qti/sdm636-mtp_e7t.dtb
else
  wget https://raw.githubusercontent.com/okta-10/my-script/main/patch/dtbs/qpnp/sdm636-mtp_e7s.dtb -O ak3-whyred/dtbs/qpnp/sdm636-mtp_e7s.dtb
  wget https://raw.githubusercontent.com/okta-10/my-script/main/patch/dtbs/qti/sdm636-mtp_e7s.dtb -O ak3-whyred/dtbs/qti/sdm636-mtp_e7s.dtb
  wget https://raw.githubusercontent.com/okta-10/my-script/main/patch/dtbs/qpnp/sdm636-mtp_e7t.dtb -O ak3-tulip/dtbs/qpnp/sdm636-mtp_e7t.dtb
  wget https://raw.githubusercontent.com/okta-10/my-script/main/patch/dtbs/qti/sdm636-mtp_e7t.dtb -O ak3-tulip/dtbs/qti/sdm636-mtp_e7t.dtb
  wget https://raw.githubusercontent.com/okta-10/my-script/main/patch/dtbs/qpnp/sdm660-mtp_f7a.dtb -O ak3-lavender/dtbs/qpnp/sdm660-mtp_f7a.dtb
  wget https://raw.githubusercontent.com/okta-10/my-script/main/patch/dtbs/qti/sdm660-mtp_f7a.dtb -O ak3-lavender/dtbs/qti/sdm660-mtp_f7a.dtb
fi

# Setup Environtment
AK3_DIR=$KERNEL_DIR/ak3-$DEVICE
SOURCE="$(git rev-parse --abbrev-ref HEAD)"

if [[ "$*" =~ "clang" ]]; then
  # Clang Setup
  CLANG_DIR="$KERNEL_DIR/clang"
  export PATH="$KERNEL_DIR/clang/bin:$PATH"
  CCV="$("$CLANG_DIR"/bin/clang --version | head -n 1)"
  LDV="$("$CLANG_DIR"/bin/ld.lld --version | head -n 1)"
  export KBUILD_COMPILER_STRING="$CCV + $LDV"
fi

export SOURCE
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER="okta_10"
export KBUILD_BUILD_HOST="dockerci"

# Telegram Directory
TELEGRAM=Telegram/telegram

# Push Info Kernel to Telegram
sendInfo() {
  "${TELEGRAM}" -c "${CHANNEL_ID}" -H \
      "$(
          for POST in "${@}"; do
              echo "${POST}"
          done
      )"
}

# Push Zip Kernel to Telegram
sendKernel() {
  "${TELEGRAM}" -f "$(echo "$AK3_DIR"/*.zip)" \
  -c "${CHANNEL_ID}" -H \
      "# <code>$DEVICE-$CONFIGVERSION</code> # <code>md5: $(md5sum "$AK3_DIR"/*.zip | cut -d' ' -f1)</code> # <code>Build Took : $(("$DIFF" / 60)) Minute, $(("$DIFF" % 60)) Second</code>"
}

# Start Count
BUILD_START=$(date +"%s")

# Export Defconfig
make O=out mystic-"$DEVICE"-"$CONFIGVERSION"_defconfig

# QTI Haptics
if [[ "$*" =~ "a26x" ]]; then
  KERNEL_IMG=$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb
  # Disable QTI Haptics for A26X
  scripts/config --file out/.config -d CONFIG_INPUT_QTI_HAPTICS
else
  KERNEL_IMG=$KERNEL_DIR/out/arch/arm64/boot/Image.gz
  # Enable QTI Haptics for all build except A26X
  scripts/config --file out/.config -e CONFIG_INPUT_QTI_HAPTICS
fi

# Start Compile
if [[ "$*" =~ "clang" ]]; then
  make -j"$(nproc --all)" O=out \
          CC=clang \
          AR=llvm-ar \
          NM=llvm-nm \
          OBJCOPY=llvm-objcopy \
          OBJDUMP=llvm-objdump \
          STRIP=llvm-strip \
          CROSS_COMPILE=aarch64-linux-gnu- \
          CROSS_COMPILE_ARM32=arm-linux-gnueabi-
elif [[ "$*" =~ "gcc" ]]; then
  export CROSS_COMPILE="$KERNEL_DIR/arm64/bin/aarch64-elf-"
  export CROSS_COMPILE_ARM32="$KERNEL_DIR/arm32/bin/arm-eabi-"
  make -j"$(nproc --all)" O=out ARCH=arm64
fi

# If build error
if ! [ -a "$KERNEL_IMG" ]; then
  sendInfo "<b>Failed building kernel for <code>$DEVICE-$CONFIGVERSION</code> Please fix it...!</b>"
  exit 1
fi

# End Count and Calculate Total Build Time
BUILD_END=$(date +"%s")
DIFF=$(( BUILD_END - BUILD_START ))

# Make zip
if [[ "$*" =~ "a26x" ]]; then
  cp -r "$KERNEL_IMG" "$AK3_DIR"/
else
  cp -r "$KERNEL_IMG" "$AK3_DIR"/kernel/
fi

cd "$AK3_DIR" || exit
zip -r9 Mystic-EAS_"$DEVICE""$LOCALVERSION"_"$CONFIGVERSION".zip ./*
cd "$KERNEL_DIR" || exit

sendKernel

rm -rf out/arch/arm64/boot/
rm -rf out/.version
rm -rf "$AK3_DIR"/*.zip
