# Seeed reComputer RK3588 DevKit BalenaOS 移植

本阶段的详细修改记录见：[阶段一移植工作记录](docs/阶段一移植工作记录.md)。

## 当前状态

第一阶段已经建立在 `balena-os/balena-radxa` 的 Yocto 骨架上，并已迁移到 Wrynose，目标设备为：

- slug：`recomputer-rk3588-devkit`
- SoC：Rockchip RK3588
- 架构：AArch64
- Linux DTB：`rockchip/rk3588-recomputer-rk3588-devkit.dtb`
- U-Boot defconfig：`recomputer-rk3588-devkit_defconfig`
- 启动链：`idbloader.img` + `u-boot.itb`

当前仓库将 Rockchip 官方 SDK 固定快照保存在 `bsp/rockchip-sdk/`，由 kernel、U-Boot 和 rkbin 配方使用 `externalsrc` 接入；该目录是可复现构建所需的版本化输入。Seeed Armbian 的板级 DTS、camera dtsi 和 U-Boot 适配作为 layer 文件叠加。

## 已确定的硬件启动布局

RK3588 的现有 Seeed U-Boot 在裸盘中的写入位置为：

| 内容              | 起始扇区  | 说明                     |
| --------------- | -----:| ---------------------- |
| `idbloader.img` | 64    | Rockchip SPL/DDR 初始化镜像 |
| `u-boot.itb`    | 16384 | U-Boot proper/FIT      |

Balena 镜像会在这两个裸盘偏移之外创建标准 GPT 分区。当前目标布局是：

1. `loader1`
2. `loader2`
3. Balena boot
4. Balena root A
5. Balena root B/state 等标准分区

因此板级 U-Boot 配方使用 `BALENA_BOOT_PART = "3"` 和 `BALENA_DEFAULT_ROOT_PART = "4"`。最终分区号必须在第一次实际 Yocto 构建后从 `wic` 日志和镜像中复核。

## 参考基线

- Balena：`balena-os/balena-radxa`，master，导入时提交 `3f8d1c4cecd3a01177e8345f851a5f182e8e1149`
- Rockchip BSP layer：来自 `.78` 官方 SDK 的 `yocto/meta-rockchip`，本地路径为 `bsp/rockchip-sdk/yocto/meta-rockchip`；不再使用 Radxa `meta-rockchip` 链接
- Seeed Armbian 参考：外部 Seeed 板级仓库（仅用于移植参考，不是构建依赖）
- Rockchip 官方 SDK：仓库内 `bsp/rockchip-sdk/` 固定快照（版本 `RK3588_LINUX6.1_SDK_RELEASE_V1.4.0_20251220`）
- 版本化 SDK 快照：`bsp/rockchip-sdk/source/kernel-6.1`、`source/u-boot`、`rkbin`、`device`
- Seeed Armbian：仅作为板级 DTS、camera dtsi 和 U-Boot 适配参考/叠加来源，不作为 kernel/U-Boot 的长期 recipe 源

## Wrynose 迁移状态

- OE-Core、BitBake、meta-yocto、meta-arm、meta-openembedded 已切换到 Wrynose。
- meta-balena 使用 v8.0.0 的 `meta-balena-wrynose` 兼容层。
- 构建脚本会检查并初始化所有 pinned submodule，使用 `bsp/rockchip-sdk/yocto/meta-rockchip`，不会依赖 Radxa `meta-rockchip`。
- SDK layer 中的 Wrynose 解析兼容修正（`${WORKDIR}`→`${UNPACKDIR}`、Mesa append 文件名）已随版本库提交。
- 已将官方 SDK 的 `rockchip-mpp`、`gstreamer1.0-rockchip`、`rockchip-rkaiq` IQ/server、`rockchip-rkisp` IQ/server 纳入 RK3588 image install；尚未宣称这些组件已在硬件上验收。

## 下一步

1. 在设备上验证 hostapp 更新能正确重写 `idbloader.img@64` 和 `u-boot.itb@16384`。
2. 验收 RKAIQ/RKISP 服务、GStreamer/Mpp 和摄像头 pipeline。
3. 再移植 Panthor/Mesa、AIC8800 Wi-Fi/BT、USB gadget、Morse 和 PCIe/显示等 Seeed Armbian 用户态/板级配置。

## 暂不纳入第一阶段

Panthor/Mesa、AIC8800 Wi-Fi/BT、摄像头和 Armbian 专属 OTA 扩展不直接移植到 BalenaOS 第一版。它们会在最小系统能稳定启动后按设备功能逐项接入。
