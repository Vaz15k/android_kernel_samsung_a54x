#!/bin/bash
DIR=$(readlink -f .)
PARENT_DIR=$(readlink -f ${DIR}/..)

ARGS="$*"

AK3_DIR="$HOME/AnyKernel3"
OUT_DIR="$DIR/out"

MKBOOTIMG="$DIR/build/mkbootimg/mkbootimg.py"
MKDTBOIMG="$DIR/build/dtb/mkdtboimg.py"

TMPDIR="$DIR/build/tmp"
DLKM_DIR="$TMPDIR/ramdisk_dlkm"
PLATFORM_DIR="$TMPDIR/ramdisk_platform"

PRE_PLATFORM="$DIR/build/vboot_platform"
PRE_DLKM="$DIR/build/vboot_dlkm"
MODULES_DIR="$DLKM_DIR/lib/modules"

DTB="$OUT_DIR/arch/arm64/boot/dts/exynos/s5e8835.dtb"
MOD_OUTDIR="$OUT_DIR/modules_out"
OUT_KERNEL="$OUT_DIR/arch/arm64/boot/Image"
OUT_DTBIMAGE="$TMPDIR/dtb.img"
OUT_VENDORBOOTIMG="$TMPDIR/vendor_boot.img"


toolchain() {
    if [ "$GITHUB_ACTIONS" = "true" ]; then
        TC_DIR="$HOME/Prebuilts"
    else
        TC_DIR="$HOME/Projetos/Prebuilts"
    fi
	BT_DIR="$TC_DIR/build-tools"
	CL_DIR="$TC_DIR/gl-clang/clang-r522817"
	GAS_DIR="$TC_DIR/gas"

	export PATH=$CL_DIR/bin:$PATH
	export PATH=$BT_DIR/path/linux-x86:$PATH
	export PATH=$GAS_DIR/linux-x86:$PATH
}

zip_name() {
    if [[ "$ARGS" == *"--permissive"* ]]; then
        ZIP_NAME="Squeak_PERMISSIVE_$(date +'%Y-%m-%d')"

    elif [[ "$ARGS" == *"--ksu"* ]]; then
        ZIP_NAME="Squeak_KSU_$(date +'%Y-%m-%d')"

    elif [[ "$ARGS" == *"--next"* ]]; then
        ZIP_NAME="Squeak_KSU_NEXT_$(date +'%Y-%m-%d')"

    else
        ZIP_NAME="Squeak_$(date +'%Y-%m-%d')"
    fi
}

permissive() {
    if [[ "$ARGS" == *"--permissive"* ]]; then
        scripts/config --file $DIR/arch/arm64/configs/a54x_defconfig \
            -e CONFIG_PERMISSIVE_SELINUX \
            -e CONFIG_MODULE_FORCE_UNLOAD \
            -e CONFIG_MODULE_LOAD \
            -e CONFIG_MODULE_FORCE_LOAD \
            -d CONFIG_INTEGRITY \
            -d CONFIG_INTEGRITY_SIGNATURE \
            -d CONFIG_INTEGRITY_ASYMMETRIC_KEYS \
            -d CONFIG_INTEGRITY_TRUSTED_KEYRING \
            -d CONFIG_INTEGRITY_AUDIT \
            --set-str CONFIG_LOCALVERSION "-squeak_permissive"
        
        echo "Building permissive kernel"
    fi
}

ksu() {
    if [[ "$ARGS" == *"--ksu"* ]]; then
        if [ -d "build/tmp" ]; then
            rm -fr build/tmp $OUT_DIR
        fi

        if [ ! -d "KernelSU" ]; then
            echo "KernelSU not found !"
            echo "Fetching ...."
            curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -
        fi

        scripts/config --file $DIR/arch/arm64/configs/a54x_defconfig \
            -e CONFIG_KSU \
            --set-str CONFIG_LOCALVERSION "-squeak_ksu"

        echo "Building Kernel with KernelSU"

    elif [[ "$ARGS" == *"--next"* ]]; then
        if [ -d "build/tmp" ]; then
            rm -fr build/temp $OUT_DIR
        fi

        if [ ! -d "KernelSU" ]; then
            echo "KernelSU-Next not found !"
            echo "Fetching ...."
            curl -LSs "https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next/kernel/setup.sh" | bash -
        fi

        scripts/config --file $DIR/arch/arm64/configs/a54x_defconfig \
            -e CONFIG_KSU \
            --set-str CONFIG_LOCALVERSION "-squeak_next"

        echo "Building Kernel with KernelSU-Next"

    else
        echo "KSU disabled"
        if [ -d "KernelSU" ]; then
            rm -rf drivers/kernelsu KernelSU build/tmp
            git reset HEAD --hard
        fi
    fi
}

anykernel3() {
	if [ -d $AK3_DIR ]; then
		cd $AK3_DIR
		git reset HEAD --hard
		git clean -xdf
		cd $DIR
	else
        git clone --branch a54x https://github.com/Vaz15k/AnyKernel3.git $AK3_DIR
        cd $DIR
	fi
}

makezipfile() {
    cp $OUT_KERNEL $AK3_DIR
    cp $OUT_VENDORBOOTIMG $AK3_DIR
    cd $AK3_DIR
    zip -r9 $ZIP_NAME . -x '*.git*' '*patch*' '*ramdisk*' 'README.md' '*modules*'
}

copy_modules() {
    echo "INFO: Copiando módulos..."
    rm -rf "$TMPDIR"
    mkdir -p "$TMPDIR" "$MODULES_DIR/0.0" "$DLKM_DIR" "$PLATFORM_DIR"
    
    if ! find "$MOD_OUTDIR/lib/modules" -mindepth 1 -type d | read; then
        echo -e "\nERROR: Nenhum módulo encontrado!\n"
        exit 1
    fi

    cp "$OUT_DIR/modules.order" "$MODULES_DIR/0.0/"
    cp "$OUT_DIR/modules.builtin" "$MODULES_DIR/0.0/"
    cp "$OUT_DIR/modules.builtin.modinfo" "$MODULES_DIR/0.0/"

    missing_modules=""

    for module in $(cat "$PRE_DLKM/modules.load"); do
        module_path=$(find "$MOD_OUTDIR/lib/modules" -name $module)
        if [ -f "$module_path" ]; then
            cp -f "$module_path" "$MODULES_DIR/0.0/$module"
        else
            missing_modules="$missing_modules $module"
        fi
    done

    if [ "$missing_modules" != "" ]; then
        echo "ERROR: Os seguintes módulos não foram encontrados: $missing_modules"
    fi

    depmod 0.0 -b "$DLKM_DIR"
    
    sed -i 's/\([^ ]\+\)/\/lib\/modules\/\1/g' "$MODULES_DIR/0.0/modules.dep"
    
    cd "$MODULES_DIR/0.0"
    for i in $(find . -name "modules.*" -type f); do
        if [ $(basename "$i") != "modules.dep" ] && \
            [ $(basename "$i") != "modules.softdep" ] && \
            [ $(basename "$i") != "modules.alias" ]; then
            rm -f "$i"
        fi
    done
    cd "$DIR"

    cp -f "$PRE_DLKM/modules.load" "$MODULES_DIR/0.0/modules.load"
    
    mv "$MODULES_DIR/0.0"/* "$MODULES_DIR/"
    rm -rf "$MODULES_DIR/0.0"

    echo "INFO: Módulos copiados com sucesso!"
}

build_boot_images() {
    # Prepara ramdisk platform
    cp -rf "$PRE_PLATFORM"/* "$PLATFORM_DIR/"

    # Build DTB
    echo "INFO: Gerando DTB image..."
    python "$MKDTBOIMG" create "$OUT_DTBIMAGE" --custom0=0x00000000 --custom1=0x000000ff  --version=0 --page_size=2048 "$DTB"

    # Prepara ramdisks para vendor_boot
    cd "$DLKM_DIR"
    find . | cpio --quiet -o -H newc -R root:root | lz4 -9cl > ../ramdisk_dlkm.lz4
    cd ../ramdisk_platform
    find . | cpio --quiet -o -H newc -R root:root | lz4 -9cl > ../ramdisk_platform.lz4
    cd ..
    echo "buildtime_bootconfig=enable" > bootconfig

    # Build vendor_boot.img
    echo "INFO: Gerando vendor_boot.img..."
    $MKBOOTIMG --header_version 4 \
        --vendor_boot "$OUT_VENDORBOOTIMG" \
        --vendor_bootconfig "$TMPDIR/bootconfig" \
        --dtb "$OUT_DTBIMAGE" \
        --board SRPVI13A011 \
        --cmdline "bootconfig loop.max_part=7" \
        --vendor_ramdisk "$TMPDIR/ramdisk_platform.lz4" \
        --ramdisk_type dlkm \
        --ramdisk_name dlkm \
        --vendor_ramdisk_fragment "$TMPDIR/ramdisk_dlkm.lz4" \
        --os_version 13.0.0 \
        --os_patch_level 2024-12 || exit 1

    cd "$DIR"
    echo "INFO: Build das imagens concluído!"
}

DEFCONFIG=a54x_defconfig
JOBS=$(nproc --all)
MAKE_PARAMS="-j$JOBS -C $DIR CC=clang LLVM=1 LLVM_IAS=1 CLANG_TRIPLE=llvm- CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi-"

export DEPMOD=depmod

export KBUILD_BUILD_USER="Vaz15K"
export KBUILD_BUILD_HOST="GithubActions"

echo "Starting Building ..."

toolchain
zip_name
permissive
ksu

make $MAKE_PARAMS $DEFCONFIG
make $MAKE_PARAMS

if [[ ! -f "$OUT_KERNEL" ]]; then
    echo "Build failed"
else
    make $MAKE_PARAMS INSTALL_MOD_STRIP="--strip-debug --keep-section=.ARM.attributes" INSTALL_MOD_PATH="$MOD_OUTDIR" modules_install
    copy_modules
    build_boot_images
    anykernel3
    makezipfile
fi
