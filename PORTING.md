# Seeed reComputer RK3588 DevKit BalenaOS 移植

本阶段的详细修改记录见：[阶段一移植工作记录](docs/阶段一移植工作记录.md)。

## 当前状态

第一阶段已经建立在 `balena-os/balena-radxa` 的 Yocto Scarthgap 骨架上，目标设备为：

- slug：`recomputer-rk3588-devkit`
- SoC：Rockchip RK3588
- 架构：AArch64
- Linux DTB：`rockchip/rk3588-recomputer-rk3588-devkit.dtb`
- U-Boot defconfig：`recomputer-rk3588-devkit_defconfig`
- 启动链：`idbloader.img` + `u-boot.itb`

当前仓库已经把 kernel/U-Boot 源码提交固定到 Yocto 配方，并把板级 U-Boot 文件作为 layer 输入；还不能宣称已经完成首次启动，必须先通过实际 BitBake 构建和串口验证。

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
- Rockchip BSP layer：`radxa/meta-rockchip`，`scarthgap`
- Seeed Armbian 参考：`/home/seeed/workspace/rk3588`
- Seeed vendor kernel：Armbian 使用 `armbian/linux-rockchip` 的 `rk-6.1-rkr5.1`
- Seeed U-Boot：Radxa `next-dev-v2024.10` 加板级补丁

## 下一步

1. 在容器化 Yocto 环境执行 `balena-image-flasher` dry build，检查依赖、`wic` 分区号、extlinux、`config.json` 和 bootloader 偏移。
2. 确认 `u-boot.itb` 的 FIT 中包含非空 DTB，且 `idbloader.img` 能由 RK3588 loader 工具链生成。
3. 用 RK3588 DevKit 的串口（1500000 8N1）进行 SD/eMMC 首启，再验证 hostapp 更新能正确重写 bootloader。
4. 首次启动稳定后，再接入 Panthor/Mesa、AIC8800 Wi-Fi/BT、摄像头和 Balena 云端硬件测试。

## 暂不纳入第一阶段

Panthor/Mesa、AIC8800 Wi-Fi/BT、摄像头和 Armbian 专属 OTA 扩展不直接移植到 BalenaOS 第一版。它们会在最小系统能稳定启动后按设备功能逐项接入。
