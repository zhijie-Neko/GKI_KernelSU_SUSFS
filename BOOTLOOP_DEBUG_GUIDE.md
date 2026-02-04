# 🔍 不开机问题诊断指南

## 如何抓取启动日志

### 方法 1：使用 ADB 抓取 Logcat（推荐）

#### 准备工作
1. 确保电脑已安装 ADB
2. 手机连接电脑
3. 在刷入内核前先测试 ADB 连接

#### 抓取步骤

```bash
# 1. 清除旧日志
adb logcat -c

# 2. 开始记录日志到文件
adb logcat > boot_log.txt

# 3. 刷入内核并重启
# 在另一个终端或 Recovery 中刷入内核

# 4. 等待设备尝试启动（即使卡住也要等）
# 日志会持续记录

# 5. 如果设备完全无响应，强制重启到 Recovery
# 按住电源键 + 音量键

# 6. 停止日志记录（Ctrl+C）

# 7. 查看日志文件
cat boot_log.txt | grep -i "kernel\|panic\|error\|crash"
```

### 方法 2：使用 dmesg 抓取内核日志

如果设备能进入 Recovery 或 Fastboot：

```bash
# 在 Recovery 中（如果有 ADB）
adb shell dmesg > kernel_log.txt

# 或者在设备上
su
dmesg > /sdcard/kernel_log.txt
```

### 方法 3：使用 Last Kmsg（最后的内核消息）

如果设备重启后能进入系统或 Recovery：

```bash
# 查看上次启动的内核日志
adb shell su -c "cat /proc/last_kmsg" > last_kmsg.txt

# 或者
adb shell su -c "cat /sys/fs/pstore/console-ramoops-0" > pstore_log.txt
```

### 方法 4：使用串口调试（高级）

如果你有串口调试线：

```bash
# 连接串口
screen /dev/ttyUSB0 115200

# 或使用 minicom
minicom -D /dev/ttyUSB0 -b 115200
```

## 常见的不开机原因

### 1. KMI 破坏（最常见）

**症状：**
- 卡在开机动画
- 设备反复重启
- 完全无响应

**日志特征：**
```
kernel: Unable to handle kernel paging request
kernel: Internal error: Oops
kernel: Call trace:
kernel: [<ffffffc0xxxxxxxx>] some_vendor_module+0x...
```

**原因：**
- 修改了冻结的结构体（如 task_struct）
- 厂商模块使用了错误的偏移量

**解决：**
- 禁用修改结构体的补丁
- 禁用相关的内核配置

### 2. 模块加载失败

**症状：**
- 卡在开机 Logo
- 部分功能不工作

**日志特征：**
```
kernel: module: disagrees about version of symbol
kernel: module: Unknown symbol
kernel: Failed to load module
```

**原因：**
- 内核符号不匹配
- 模块版本检查失败

**解决：**
- 使用 Bypass 版本（跳过模块检查）
- 检查 KMI 符号列表

### 3. SELinux 策略问题

**症状：**
- 能看到开机动画但卡住
- 系统服务无法启动

**日志特征：**
```
avc: denied { ... } for ...
init: Service '...' could not be started
```

**原因：**
- SELinux 策略不匹配
- 新的内核功能被 SELinux 阻止

**解决：**
- 临时设置 SELinux 为 Permissive
- 添加 `androidboot.selinux=permissive` 到内核命令行

### 4. 设备树不兼容

**症状：**
- 完全无响应
- 无法进入 Fastboot

**日志特征：**
```
kernel: Machine model: ...
kernel: Failed to find device tree
kernel: Unable to handle kernel NULL pointer dereference
```

**原因：**
- 内核版本与设备不匹配
- 设备树配置错误

**解决：**
- 确认使用正确的内核版本
- 检查设备是否支持 GKI

## 针对我们的 Docker/LXC 内核

### 可能的问题点

#### 1. task_struct 补丁（已禁用）

**如果之前启用了：**
```
CONFIG_SYSVIPC=y
CONFIG_DETECT_HUNG_TASK=y
CONFIG_IO_URING=y
```

**会导致：**
- task_struct 结构体被修改
- 厂商模块崩溃
- 系统无法启动

**日志会显示：**
```
kernel: Unable to handle kernel paging request at virtual address
kernel: pc : [<ffffffc0xxxxxxxx>] vendor_module+0x...
kernel: lr : [<ffffffc0xxxxxxxx>] vendor_module+0x...
```

#### 2. Cgroup 补丁

**如果补丁有问题：**
```
kernel: BUG: unable to handle kernel NULL pointer dereference
kernel: RIP: cgroup_add_file+0x...
```

**解决：**
- 检查 cgroup 补丁是否正确应用
- 确认补丁与内核版本匹配

#### 3. OverlayFS 补丁

**如果补丁有问题：**
```
kernel: overlayfs: failed to mount
kernel: VFS: Cannot open root device
```

**解决：**
- 检查 overlayfs 补丁
- 确认 DCACHE 修改正确

## 诊断步骤

### 第 1 步：确认设备状态

```bash
# 检查设备是否被识别
adb devices

# 如果显示 "unauthorized"，需要在设备上授权
# 如果显示 "offline"，设备可能卡在启动过程中
# 如果显示 "device"，设备正常连接
```

### 第 2 步：抓取完整日志

```bash
# 开始记录
adb logcat -v time > full_boot_log.txt

# 同时记录内核日志
adb shell dmesg -w > kernel_boot_log.txt

# 等待至少 5 分钟
# 即使设备看起来卡住了
```

### 第 3 步：分析日志

```bash
# 查找 panic
grep -i "panic" full_boot_log.txt

# 查找 oops
grep -i "oops" kernel_boot_log.txt

# 查找错误
grep -i "error\|fail\|crash" full_boot_log.txt | head -50

# 查找 KMI 相关
grep -i "disagrees about version\|unknown symbol" full_boot_log.txt

# 查找模块加载
grep -i "module" kernel_boot_log.txt | grep -i "load\|fail"
```

### 第 4 步：检查关键服务

```bash
# 查看 init 进程
grep "init:" full_boot_log.txt | tail -20

# 查看 zygote
grep "zygote" full_boot_log.txt | tail -20

# 查看 system_server
grep "system_server" full_boot_log.txt | tail -20
```

## 快速修复方案

### 方案 1：使用安全配置（当前配置）

已经禁用了可能导致问题的配置：
- ❌ CONFIG_SYSVIPC
- ❌ CONFIG_DETECT_HUNG_TASK
- ❌ CONFIG_IO_URING
- ❌ task_struct 补丁

只保留安全的补丁：
- ✅ cgroup 修复
- ✅ overlayfs 修复

### 方案 2：完全禁用 Docker/LXC 补丁

如果还是不开机，可以尝试完全禁用我们的补丁：

```yaml
# 在 build.yml 中注释掉
# - name: Apply Docker & LXC Support Patches
```

### 方案 3：使用原版内核测试

编译一个没有任何修改的原版 GKI 内核：
- 不应用 Docker/LXC 补丁
- 不启用额外的配置
- 只保留 KernelSU

如果原版能开机，说明是我们的修改导致的。

## 提供日志以获取帮助

如果需要帮助，请提供：

### 1. 设备信息
```
设备型号：
Android 版本：
原始内核版本：
```

### 2. 编译信息
```
使用的 KSU 变体：
是否启用 SUSFS：
是否启用 Docker/LXC 补丁：
```

### 3. 日志文件
```
boot_log.txt（前 500 行和最后 500 行）
kernel_boot_log.txt（完整）
last_kmsg.txt（如果有）
```

### 4. 关键错误信息
```bash
# 提取关键错误
grep -i "panic\|oops\|error.*kernel" *.txt > critical_errors.txt
```

## 测试新内核的安全方法

### 1. 备份当前内核

在 Recovery 中：
```bash
# 备份 boot 分区
adb shell dd if=/dev/block/by-name/boot of=/sdcard/boot_backup.img

# 下载到电脑
adb pull /sdcard/boot_backup.img
```

### 2. 刷入新内核

```bash
# 刷入 AnyKernel3 ZIP
adb sideload kernel.zip
```

### 3. 观察启动

```bash
# 同时运行这两个命令（两个终端）
adb logcat -v time > boot_test.txt
adb shell dmesg -w > kernel_test.txt
```

### 4. 如果不开机

```bash
# 重启到 Recovery
adb reboot recovery

# 或强制重启（按住电源键 + 音量键）

# 恢复备份
adb push boot_backup.img /sdcard/
adb shell dd if=/sdcard/boot_backup.img of=/dev/block/by-name/boot
adb reboot
```

## 当前配置的预期行为

使用最新的安全配置，内核应该：

✅ **能够启动**
- 没有 task_struct 修改
- 没有破坏 KMI 的配置

✅ **Docker 基本功能**
- 命名空间支持
- Cgroup 支持
- OverlayFS 支持
- 网络功能

❌ **LXC 可能受限**
- 缺少 SYSVIPC
- 某些 LXC 功能可能不工作

如果这个配置还是不开机，请提供日志，我们可以进一步诊断。

---

**重要提示：** 刷入自定义内核前，务必备份当前的 boot 分区！
