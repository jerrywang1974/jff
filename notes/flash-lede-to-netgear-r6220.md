# Flash LEDE to Netgear R6220

# References

* https://www.zybuluo.com/zwh8800/note/856488
* https://lede-project.org/toh/hwdata/netgear/netgear_r6220
* https://git.lede-project.org/?p=source.git;a=commit;h=38bee61dab029a7608088f64da71c19cfc8cf267

# Steps

0. 使用网线连接路由器和电脑，插好 FAT32 格式的 U 盘(卷标为 U);
1. 访问 http://192.168.1.1/setup.cgi?todo=debug，应该看到 "Debug Enabled!" 字样，如果报告访问被控制，则换成无线，关掉路由器的访问控制功能;
2. telnet 192.168.1.1，登录名是 root，没有密码;
3. 备份
```
cd /mnt/shares/U
cat /proc/partitions > proc_partitions.txt
cat /proc/mtd > proc_mtd.txt
for i in `seq 0 21`; do dd if=/dev/mtd$i of=mtd$i.bin; done  # 最后两个会报错，reserved block 没有挂载
umount /mnt/shares/U
```
4. 下载官方固件放到 U 盘里
```
curl -o download.sh 'https://lede-project.org/_export/code/docs/user-guide/release_signatures?codeblock=1'
sha256sum download.sh
# 应该输出 e94df2d7991bb2b7e6ac38bb349cc0349a103687ea7b910f0073189475961518  Download.sh
chmod a+rx download.sh
./download.sh https://downloads.lede-project.org/snapshots/targets/ramips/mt7621/lede-ramips-mt7621-r6220-squashfs-kernel.bin
./download.sh https://downloads.lede-project.org/snapshots/targets/ramips/mt7621/lede-ramips-mt7621-r6220-squashfs-rootfs.bin
```
5. 重复 0/1/2 三步，进入路由器烧写
```
mtd_write write lede-ramips-mt7621-r6220-squashfs-rootfs.bin Rootfs
mtd_write write lede-ramips-mt7621-r6220-squashfs-kernel.bin Kernel
reboot
```

# More packages

```
opkg update
opkg install luci
opkg install luci-i18n-base-zh-cn
opkg install luci-theme-material
opkg install luci-app-upnp
opkg install luci-app-sqm
```

# Rescue

1. 下载 https://github.com/jclehner/nmrpflash
2. 下载 https://www.netgear.com/support/product/R6220.aspx
3. 关掉路由器电源, 执行 sudo ./nmrpflash 后立刻开机
```
./nmrpflash -L  # 设置电脑侧静态 IP 后，立刻执行以确定是哪个网卡
sudo ./nmrpflash -i en5 -f R6220_V1.1.0.50_1.0.1.img
```
在恢复过程中 nmrpflash 会不断打印 "Received keep-alive request."，此时表
示没有完成，一直到显示如下文字才表示完成，然后重启路由器。
```
Remote finished. Closing connection.
Reboot your device now.
10.164.183.252 (10.164.183.252) deleted
```

