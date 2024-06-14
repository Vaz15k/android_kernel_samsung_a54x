# SPDX-License-Identifier: GPL-2.0

# s5e8835
dtb-$(CONFIG_SOC_S5E8835) += s5e8835.dtb
dtbo-$(CONFIG_SOC_S5E8835) += board/erd/s5e8535-erd8535_r1f.dtbo
dtbo-$(CONFIG_SOC_S5E8835) += board/erd/s5e8835-erd8835.dtbo

# s5e9925
dtb-$(CONFIG_SOC_S5E9925) += s5e9925.dtb
dtbo-$(CONFIG_SOC_S5E9925) += board/univ/s5e9925-universal9925_rev1b.dtbo
dtbo-$(CONFIG_SOC_S5E9925) += board/univ/s5e9925-universal9925_rev17.dtbo
dtbo-$(CONFIG_SOC_S5E9925) += board/univ/s5e9925-universal9925_rev00.dtbo
dtbo-$(CONFIG_SOC_S5E9925) += board/erd/s5e9925-erd9925_r13.dtbo
dtbo-$(CONFIG_SOC_S5E9925) += board/erd/s5e9925-erd9925.dtbo

# s5e8535
dtb-$(CONFIG_SOC_S5E8535) += s5e8535.dtb
dtbo-$(CONFIG_SOC_S5E8535) += board/erd/s5e8535-erd8535.dtbo

# s5e9935
dtb-$(CONFIG_SOC_S5E9935) += s5e9935.dtb
dtbo-$(CONFIG_SOC_S5E9935) += board/erd/s5e9935-erd9935_r01.dtbo
dtbo-$(CONFIG_SOC_S5E9935) += board/erd/s5e9935-erd9935.dtbo

# exynos
dtb-$(CONFIG_ARCH_EXYNOS) += exynos5433-tm2e.dtb
dtb-$(CONFIG_ARCH_EXYNOS) += exynos5433-tm2.dtb
dtb-$(CONFIG_ARCH_EXYNOS) += exynos7-espresso.dtb

always		:= $(dtb-y) $(dtbo-y)
subdir-y	:= $(dts-dirs)
clean-files	:= *.dtb *.dtbo *.reverse.dts
