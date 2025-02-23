#!/bin/bash
DIR=$(readlink -f .)
PARENT_DIR=$(readlink -f ${DIR}/..)

AK3_DIR="$HOME/AnyKernel3"
OUT_DIR="$DIR/out"

if [ "$GITHUB_ACTIONS" = "true" ]; then
    TC_DIR="$HOME/Prebuilts"
else
    TC_DIR="$HOME/Projetos/Prebuilts"
fi

ARGS="$*"

MKBOOTIMG="$DIR/build/mkbootimg/mkbootimg.py"
MKDTBOIMG="$DIR/build/dtb/mkdtboimg.py"

MOD_OUTDIR="$OUT_DIR/modules_out"

TMPDIR="$DIR/build/tmp"

PRE_PLATFORM="$DIR/build/vboot_platform"
PRE_DLKM="$DIR/build/vboot_dlkm"
PLATFORM_DIR="$TMPDIR/ramdisk_platform"
DLKM_DIR="$TMPDIR/ramdisk_dlkm"
STOCK_MODULES="$DIR/build/modules_stock"

MODULES_DIR="$DLKM_DIR/lib/modules"
DTB="$OUT_DIR/arch/arm64/boot/dts/exynos/s5e8835.dtb"

OUT_KERNEL="$OUT_DIR/arch/arm64/boot/Image"
OUT_DTBIMAGE="$TMPDIR/dtb.img"
OUT_VENDORBOOTIMG="$TMPDIR/vendor_boot.img"

DEFCONFIG=a54x_defconfig
JOBS=$(nproc --all)
MAKE_PARAMS="-j$JOBS -C $DIR CC=clang LLVM=1 LLVM_IAS=1 CLANG_TRIPLE=llvm- CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi-"

toolchain() {
	BT_DIR="$TC_DIR/build-tools"
	CL_DIR="$TC_DIR/gl-clang/clang-r522817"
	GAS_DIR="$TC_DIR/gas"

	export PATH=$CL_DIR/bin:$PATH
	export PATH=$BT_DIR/path/linux-x86:$PATH
	export PATH=$GAS_DIR/linux-x86:$PATH
}

ksu() {
    if [[ "$ARGS" == *"--ksu"* ]]; then
        KSU="true"
        CONFIG_KSU=y
        ZIP_NAME="Squeak_KSU_"$(date +'%Y-%m-%d')""
    elif [[ "$ARGS" == *"--next"* ]]; then
        KSU_NEXT="true"
        CONFIG_KSU=y
        ZIP_NAME="Squeak_KSU_NEXT_"$(date +'%Y-%m-%d')""
    else
        KSU="false"
        ZIP_NAME="Squeak_"$(date +'%Y-%m-%d')""
    fi

    if [ "$KSU" == "true" ]; then
		rm -fr build/temp $OUT_DIR
        if [ -d "KernelSU" ]; then
            echo "KernelSU exists"
        else
            echo "KernelSU not found !"
            echo "Fetching ...."
            curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -
        fi
    elif [ "$KSU_NEXT" == "true" ]; then
		rm -fr build/temp $OUT_DIR
        if [ -d "KernelSU" ]; then
            echo "KernelSU Next exists"
        else
            echo "KernelSU-Next not found !"
            echo "Fetching ...."
            curl -LSs "https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next/kernel/setup.sh" | bash -
        fi
    else
        echo "KSU disabled"
        if [ -d "KernelSU" ]; then
            rm -rf drivers/kernelsu
            rm -rf KernelSU
            git reset HEAD --hard
        fi
    fi
}

anykernel3() {
	if [ -d $AK3_DIR ]; then
		cd $AK3_DIR
		git reset HEAD --hard
		rm -fr Squeak* Image vendor_boot.img
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

export DEPMOD=depmod

echo "Starting Building ..."
ksu
toolchain
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
