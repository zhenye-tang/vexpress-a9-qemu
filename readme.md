# QEMU & Linux

## 1. 简介

​	这是一个基于 qemu 中 vexpress-a9 开发板如何运行 linux 的说明文档。该文档介绍了 qemu 如何通过 u-boot 引导起 linux kernel，复现了真实开发板 linux kernel 移植的全流程。通过 qemu，能够更方便的学习与调试代码！！

## 2. 依赖准备

### 2.1 编译 u-boot

​	最终得到 arm 平台的 u-boot 可执行文件，该文件用于初始化一些基本的外设，然后将 linux 内核拷贝到内存中，最终启动 linux 内核，其实就是一个大的 bootloader。

​	编译流程：

* make vexpress_ca9x4_defconfig
* make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- -j12

### 2.2 编译 busybox

​	最终得到一堆的文件夹以及文件，这些东西组成了 linux 中文件系统下的最基本的文件，也就是一个最基本的文件系统镜像。这些文件有些是 linux 运行所必须的，如常用的软件和命令、设备文件、配置文件、库等等。该文件系统镜像（根文件系统）是 linux 内核启动以后挂载的第一个文件系统，然后 linux 会从中读取初始化脚本，如 rcS，inittab 等。

​	编译流程：

* make defconfig
* make menuconfg ---> Settings ---->  Build static binary (no shared libs) 
* make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi-
* make install

最终检查一下生成的 busybox 文件架构，必须与交叉编译器平台一致，如不一致，可修改顶层 Makefile 来指定交叉编译器路径。

### 2.3 编译 Linux

​	最终得到 linux 镜像，这里需要的是 zImage 与 dtb 文件，zImage 是经过压缩的可执行文件，dtb 是设备树文件。

​	编译流程：

* make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- distclean
* make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- vexpress_defconfig
* make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- -j16

zImage 文件在 linux 源码根目录下的 /arch/arm/boot，dtb 文件在 /arch/arm/boot/dts/arm/vexpress-v2p-ca9.dtb



## 3. 制作 sd 镜像

​	我们将根文件系统、zImage、dtb 文件放入 sd 卡镜像中，然后让 qemu 启动 u-boot，最终 u-boot 从 sd 卡中将 linux 启动所需要的依赖项拿出来，进而启动 linux。

### 3.1 制作过程

创建 sd_card.img 文件 :

* dd if=/dev/zero of=sd_card.img bs=1M count=1024 （内容为零的尺寸为 1GB 的 sd 卡镜像文件 sd_card.img ）

sd_card.img 进行分区：

* parted sd_card.img mklabel msdos
* parted sd_card.img mkpart primary fat32 1MiB 128MiB
* parted sd_card.img mkpart primary ext4 128MiB 100%

格式化各分区：

* sudo losetup -Pf --show sd_card.img
* sudo mkfs.vfat /dev/loop0p1
* sudo mkfs.ext4 /dev/loop0p2

挂载分区：

* mkdir -p mnt/boot mnt/rootfs
* sudo mount /dev/loop0p1 mnt/boot
* sudo mount /dev/loop0p2 mnt/rootfs

将文件复制到分区：

* sudo cp ./linux/arch/arm/boot/zImage mnt/boot/
* sudo cp ./linux/arch/arm/boot/dts/arm/vexpress-v2p-ca9.dtb mnt/boot/
* sudo cp -r rootfs/* mnt/rootfs/

卸载分区：

* sudo umount mnt/boot mnt/rootfs
* sudo umount mnt/boot mnt/boot
* sudo losetup -d /dev/loop0

## 4. qemu 启动 u-boot

​	sd 卡镜像准备好之后，就能够启动 u-boot了，启动命令：`qemu-system-arm -M vexpress-a9 -m 512M -kernel u-boot -sd sdcard.img -nographic -serial mon:stdio`

u-boot 启动 linux 内核：

* fatload mmc 0:1 0x60008000 zImage
* fatload mmc 0:1 0x61000000 vexpress-v2p-ca9.dtb
* setenv bootargs "root=/dev/mmcblk0p2 rw console=ttyAMA0"
* bootz 0x60008000 - 0x61000000