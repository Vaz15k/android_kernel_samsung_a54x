#!/bin/bash
BUILD_DIR=$(dirname "$(readlink -f "$0")")
KERNEL_DIR=$(dirname "$BUILD_DIR")

ARGS="$*"
DATE=$(date +'%Y-%m-%d')

if [ "$GITHUB_ACTIONS" = "true" ]; then
    export KBUILD_BUILD_HOST="GithubActions"
    TC_DIR="$HOME/Prebuilts"
    AK_DIR="$HOME/AnyKernel"
else
    TC_DIR="$HOME/Projetos/Prebuilts"
    AK_DIR="$HOME/Projetos/AnyKernel"
fi

toolchain() {
    CLANG_DIR="$TC_DIR/clang-r450784c"    
    export PATH="$CLANG_DIR/bin:$PATH"
}

ksu() {
    if [[ "$ARGS" == *"--ksu"* ]]; then
        if [ ! -d "$KERNEL_DIR/KernelSU" ]; then
            echo "INFO: Cloning KernelSU"
            if [[ "$ARGS" == *"--sus"* ]]; then
                curl -LSs "https://raw.githubusercontent.com/rsuntk/KernelSU/main/kernel/setup.sh" | bash -s susfs-main
            else
                curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -
            fi
        fi
        
        ZIP_NAME="Squeak_KSU_${DATE}"
        
        scripts/config --file $KERNEL_DIR/arch/arm64/configs/a54x_defconfig \
            -e CONFIG_KSU \
            --set-str CONFIG_LOCALVERSION "-squeak-ksu-${DATE}"
        
        if [[ "$ARGS" == *"--sus"* ]]; then
            ZIP_NAME="Squeak_KSU_SUS_$(date +'%Y-%m-%d')"
            scripts/config --file $KERNEL_DIR/arch/arm64/configs/a54x_defconfig \
                -e CONFIG_KSU_SUSFS \
                --set-str CONFIG_LOCALVERSION "-squeak-ksu-sus-${DATE}"
        fi
        
        echo "INFO: Building KSU kernel"
    
    elif [[ "$ARGS" == *"--next"* ]]; then
        if [ ! -d "$KERNEL_DIR/KernelSU-Next" ]; then
            echo "INFO: Cloning KernelSU Next"
            curl -LSs "https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next-susfs/kernel/setup.sh" | bash -s next
        fi
        
        ZIP_NAME="Squeak_KSU_NEXT_${DATE}"
        
        scripts/config --file $KERNEL_DIR/arch/arm64/configs/a54x_defconfig \
            -e CONFIG_KSU \
            -e CONFIG_KSU_SUSFS \
            --set-str CONFIG_LOCALVERSION "-squeak-ksun-${DATE}"
        
        echo "INFO: Building KSU Next"
    
    elif [[ "$ARGS" == *"--sukisu"* ]]; then
        if [ ! -d "$KERNEL_DIR/KernelSU" ]; then
                echo "INFO: Cloning KernelSU Next"
                curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s susfs-main
        fi
        ZIP_NAME="Squeak_SukiSU_${DATE}"
        
        scripts/config --file $KERNEL_DIR/arch/arm64/configs/a54x_defconfig \
            -e CONFIG_KSU \
            -e CONFIG_KSU_SUSFS \
            -e CONFIG_KPM \
            --set-str CONFIG_LOCALVERSION "-squeak-sukisu-${DATE}"
        
        echo "INFO: Building SukiSU kernel"
    
    else
        if [ -d "$KERNEL_DIR/KernelSU" ] || [ -d "$KERNEL_DIR/KernelSU-Next" ]; then
            rm -rf "$KERNEL_DIR/KernelSU" "$KERNEL_DIR/KernelSU-Next" "$KERNEL_DIR/drivers/kernelsu"
            git reset HEAD --hard
        fi
        ZIP_NAME="Squeak_${DATE}"
        scripts/config --file $KERNEL_DIR/arch/arm64/configs/a54x_defconfig \
            --set-str CONFIG_LOCALVERSION "-squeak-${DATE}"
        
        permissive
    fi
}

permissive() {
    if [[ "$ARGS" == *"--permissive"* ]]; then
        ZIP_NAME="Squeak_PERMISSIVE_${DATE}"
        
        scripts/config --file $KERNEL_DIR/arch/arm64/configs/a54x_defconfig \
            -e CONFIG_PERMISSIVE_SELINUX \
            -e CONFIG_MODULE_FORCE_UNLOAD \
            -e CONFIG_MODULE_LOAD \
            -e CONFIG_MODULE_FORCE_LOAD \
            -d CONFIG_INTEGRITY \
            -d CONFIG_INTEGRITY_SIGNATURE \
            -d CONFIG_INTEGRITY_ASYMMETRIC_KEYS \
            -d CONFIG_INTEGRITY_TRUSTED_KEYRING \
            -d CONFIG_INTEGRITY_AUDIT \
            --set-str CONFIG_LOCALVERSION "-squeak_permissive-${DATE}"
        
        echo "Building permissive kernel"
    fi
}

anykernel() {
	if [ -d $AK_DIR ]; then
		cd $AK_DIR
		git reset HEAD --hard
		git clean -xdf
		cd $KERNEL_DIR
	else
        git clone --branch a54x https://github.com/Vaz15k/AnyKernel3.git $AK_DIR
        cd $KERNEL_DIR
	fi
}

makezipfile() {
    anykernel
    cp $KERNEL_DIR/out/arch/arm64/boot/Image $AK_DIR
    cd $AK_DIR
    zip -r9 $ZIP_NAME . -x '*.git*' '*patch*' '*ramdisk*' 'README.md' '*modules*'
}

DEFCONFIG="a54x_defconfig"

export PLATFORM_VERSION=14
export TARGET_SOC=s5e8835
export DEPMOD=depmod

export KBUILD_BUILD_USER="Vaz15K"

# JOBS=2
JOBS=$(nproc --all)
MAKE_PARAMS="-j$JOBS ARCH=arm64 KBUILD_OUTPUT=$KERNEL_DIR/out CC=clang LLVM=1 LLVM_IAS=1 CLANG_TRIPLE=llvm- CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi-"

toolchain
ksu

make $MAKE_PARAMS $DEFCONFIG
make $MAKE_PARAMS

if [ -f "$KERNEL_DIR/out/arch/arm64/boot/Image" ]; then
    echo "INFO: Kernel build completed successfully"
    makezipfile
fi
