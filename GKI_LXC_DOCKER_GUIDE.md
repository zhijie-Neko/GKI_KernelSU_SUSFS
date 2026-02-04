# GKI 内核 LXC-Docker 编译指南

## 概述

在 GKI 时代，编译一个能用的 LXC-Docker 内核变得困难，主要原因是：
- 开启某些内核配置会破坏 KMI (Kernel Module Interface)
- 使用某些工具链也可能破坏 KMI

## 工具链选择

### 推荐工具链
- **最佳选择**：使用谷歌魔改的 clang 工具链，并根据内核清单选择对应工具链版本
- **避免使用**：官方 clang、Proton clang、Electron-clang 等工具链（可能破坏 KMI）

### ARM64 平台编译
如需在 ARM64 平台上编译内核：
1. 可以使用确定能编译开机的官方 clang 版本
2. AOSP 仓库只提供了 x86_64 的 prebuilt 工具链
3. 可以克隆谷歌 LLVM 源码自行编译：
   ```bash
   git clone https://android.googlesource.com/toolchain/llvm-project/
   # 切换到对应分支后编译 clang/llvm
   ```

## KMI 破坏问题

### 什么是 KMI 破坏？
破坏 KMI 会导致不开机。厂商预编译的模块已经确定了结构体的偏移量和成员顺序等，在破坏 KMI 的内核开机加载这些模块会出现各种错误导致 bootloop。

### KMI 破坏的常见原因

#### 1. 修改已冻结的结构体
- 检查文件：`android/abi_gki_aarch64.xml`
- 如果结构体在此文件中被列出（如 `task_struct`），则该结构体已被冻结
- 禁止操作：
  - 添加成员
  - 删除成员
  - 修改成员
  - 交换成员顺序

#### 2. 内核配置导致的结构体修改
以 `CONFIG_SYSVIPC` 为例：

**原始代码：**
```c
#ifdef CONFIG_SYSVIPC
struct sysv_sem sysvsem;
struct sysv_shm sysvshm;
#endif
```

开启 `CONFIG_SYSVIPC` 后会向 `task_struct` 中间插入 `sysvsem` 和 `sysvshm`，破坏 KMI。

## 正确修改内核源码的方法

### 使用 ANDROID_KABI 保留字段

内核提供了保留字段机制来避免破坏 KMI：

#### 1. ANDROID_KABI_USE
用于替换单个保留字段：
```c
ANDROID_KABI_USE(1, struct sysv_sem sysvsem);
```

#### 2. _ANDROID_KABI_REPLACE
用于替换多个保留字段（适用于较大的结构体）：
```c
_ANDROID_KABI_REPLACE(2, 3, struct sysv_shm sysvshm);
```

### 修改示例（基于提供的截图）

**修改前：**
```c
#ifdef CONFIG_SYSVIPC
struct sysv_sem sysvsem;
struct sysv_shm sysvshm;
#endif
```

**修改后：**
```c
#ifdef CONFIG_SYSVIPC
// struct sysv_sem sysvsem;
// struct sysv_shm sysvshm;
ANDROID_KABI_USE(2, struct sysv_sem sysvsem);
_ANDROID_KABI_REPLACE(2, 3, struct sysv_shm sysvshm);
#endif
```

### 注意事项
- 前提：结构体必须有保留字段（`ANDROID_KABI_RESERVE`）
- 如果没有保留字段：
  - 在末尾添加成员可能可行
  - 但如果该结构体被其他冻结结构体嵌套使用，且在中间位置，则末尾添加的成员会插入到冻结结构体中间，破坏原有成员顺序

## LXC-Docker 内核配置排查

### 排查步骤
1. 在内核源码目录执行：
   ```bash
   grep -r CONFIG_NAME
   ```
   
2. 查找出现 `#ifdef CONFIG_NAME` 的地方

3. 检查是否有修改结构体的行为

4. 对比 `android/abi_gki_aarch64.xml` 确认是否为冻结的结构体

5. 如果是冻结结构体，使用 `ANDROID_KABI_USE` 或 `_ANDROID_KABI_REPLACE` 修改

### 需要排查的配置（示例）
- `CONFIG_SYSVIPC`
- `CONFIG_KEYS`
- `CONFIG_DETECT_HUNG_TASK`
- `CONFIG_IO_URING`
- 其他 LXC-Docker 所需配置

## 必要的补丁

### 1. Cgroup 补丁
按照"秋秋的补丁"修补 cgroup（参考截图1）：

```c
// 补丁内容示例（基于截图）
if (cft->ss && (cgrp->root->flags & CGRP_ROOT_NOPREFIX) && !(cft->flags & CFTYPE_NO_PREFIX)) {
    snprintf(name, CGROUP_FILE_NAME_MAX, "%s.%s", 
             cft->ss->name, cft->name);
    kernfs_create_link(cgrp->kn, name, kn);
}
```

### 2. OverlayFS 补丁
如果需要使用 Docker 的 overlay2 驱动（参考截图4）：

```c
// 移除 DCACHE_OP_HASH 和 DCACHE_OP_COMPARE 检查
bool ovl_dentry_weird(struct dentry *dentry)
{
    return dentry->d_flags & (DCACHE_NEED_AUTOMOUNT |
                              DCACHE_MANAGE_TRANSIT);
    // 移除: DCACHE_OP_HASH | DCACHE_OP_COMPARE
}
```

**补丁说明：**
- Android 使用 sdcardfs 的 native fs casefold 功能
- 这会破坏 overlayfs 在 userdata 分区上的使用
- 该补丁移除了相关检查，确保 overlayfs 的 case sensitivity 转移给用户

## 编译流程

### 方式一：使用 GitHub Actions 自动编译（推荐）

本仓库已集成 Docker 和 LXC 支持到 GitHub Actions 工作流中。

#### 触发编译

1. 进入仓库的 **Actions** 标签页
2. 选择 **Build Single Kernel (6.1.118)** 工作流
3. 点击 **Run workflow**
4. 配置编译选项：
   - **Release Type**: 选择 Actions/Pre-Release/Release
   - **KernelSU Variant**: 选择 KSU 变体（WKSU/KSU/Next/RKSU）
   - **KSU Commit**: 可选，指定特定的 KSU 提交
   - **Build Bypass**: 是否同时编译 Normal 和 Bypass 版本

5. 点击 **Run workflow** 开始编译

#### 自动应用的配置

工作流会自动：
- 应用 cgroup 修复补丁
- 应用 overlayfs 修复补丁（支持 Docker overlay2 驱动）
- 应用 task_struct KMI 安全修改
- 启用所有必需的 Docker 和 LXC 内核配置
- 编译并打包 AnyKernel3 刷机包

#### 下载编译产物

编译完成后：
- 在 Actions 运行页面的 **Artifacts** 部分下载 AnyKernel3 刷机包
- 如果选择了 Release，会自动创建 GitHub Release

### 方式二：手动编译

如果需要手动编译，按照以下步骤：

```bash
# 1. 应用补丁
cd kernel_root/common
patch -p1 < /path/to/kernel_patches/docker_lxc/cgroup_fix.patch
patch -p1 < /path/to/kernel_patches/docker_lxc/overlayfs_fix.patch
patch -p1 < /path/to/kernel_patches/docker_lxc/task_struct_kmi_fix.patch

# 2. 配置内核
# 将以下配置添加到 arch/arm64/configs/gki_defconfig

# Docker & LXC 基础支持
CONFIG_NAMESPACES=y
CONFIG_NET_NS=y
CONFIG_PID_NS=y
CONFIG_IPC_NS=y
CONFIG_UTS_NS=y
CONFIG_CGROUPS=y
CONFIG_CGROUP_CPUACCT=y
CONFIG_CGROUP_DEVICE=y
CONFIG_CGROUP_FREEZER=y
CONFIG_CGROUP_SCHED=y
CONFIG_CPUSETS=y
CONFIG_MEMCG=y
CONFIG_KEYS=y
CONFIG_VETH=y
CONFIG_BRIDGE=y
CONFIG_BRIDGE_NETFILTER=y

# 网络过滤
CONFIG_IP_NF_FILTER=y
CONFIG_IP_NF_TARGET_MASQUERADE=y
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y
CONFIG_NETFILTER_XT_MATCH_CONNTRACK=y
CONFIG_NETFILTER_XT_MATCH_IPVS=y
CONFIG_NETFILTER_XT_MARK=y
CONFIG_IP_NF_NAT=y
CONFIG_NF_NAT=y

# LXC 特定配置
CONFIG_SYSVIPC=y
CONFIG_DETECT_HUNG_TASK=y
CONFIG_IO_URING=y
CONFIG_POSIX_MQUEUE=y

# OverlayFS（Docker overlay2 驱动）
CONFIG_OVERLAY_FS=y

# 文件系统支持
CONFIG_EXT4_FS=y
CONFIG_EXT4_FS_POSIX_ACL=y
CONFIG_EXT4_FS_SECURITY=y

# 3. 编译内核
LTO=thin BUILD_CONFIG=common/build.config.gki.aarch64 build/build.sh

# 或使用 Bazel（Android 14+）
tools/bazel build --config=fast --lto=thin //common:kernel_aarch64_dist

# 4. 打包并刷入设备
# 使用 AnyKernel3 打包刷机包
```

## 参考资料

- Android KMI 文档：检查 `android/abi_gki_aarch64.xml`
- Google LLVM 工具链：https://android.googlesource.com/toolchain/llvm-project/
- Cgroup 补丁来源：秋秋的补丁
- OverlayFS 补丁参考：Android sdcardfs 相关讨论

## 常见问题

### Q: 为什么破坏 KMI 会导致不开机？
A: 厂商预编译的模块依赖特定的结构体布局。修改结构体后，模块访问成员时会使用错误的偏移量，导致系统崩溃。

### Q: 如何确定使用哪个工具链版本？
A: 查看内核源码中的清单文件（manifest），通常会指定推荐的工具链版本。

### Q: 所有内核配置都会破坏 KMI 吗？
A: 不是。只有那些会修改已冻结结构体的配置才会破坏 KMI。需要逐个排查。

### Q: 编译后如何验证 Docker 和 LXC 支持？
A: 刷入内核后，可以使用以下命令验证：
```bash
# 检查内核配置
zcat /proc/config.gz | grep -E "CONFIG_(NAMESPACES|CGROUPS|OVERLAY_FS|SYSVIPC)"

# 测试 Docker
docker run hello-world

# 测试 LXC
lxc-checkconfig
```

## 附录：完整的 Docker & LXC 内核配置清单

以下是工作流自动启用的所有配置项：

```bash
# ===== 命名空间支持 =====
CONFIG_NAMESPACES=y
CONFIG_NET_NS=y          # 网络命名空间
CONFIG_PID_NS=y          # 进程 ID 命名空间
CONFIG_IPC_NS=y          # IPC 命名空间
CONFIG_UTS_NS=y          # UTS 命名空间

# ===== Cgroup 支持 =====
CONFIG_CGROUPS=y
CONFIG_CGROUP_CPUACCT=y  # CPU 计费
CONFIG_CGROUP_DEVICE=y   # 设备访问控制
CONFIG_CGROUP_FREEZER=y  # 冻结/解冻进程组
CONFIG_CGROUP_SCHED=y    # 调度器支持
CONFIG_CPUSETS=y         # CPU 集合
CONFIG_MEMCG=y           # 内存控制组

# ===== 网络支持 =====
CONFIG_VETH=y            # 虚拟以太网对
CONFIG_BRIDGE=y          # 网桥支持
CONFIG_BRIDGE_NETFILTER=y

# ===== 网络过滤 =====
CONFIG_IP_NF_FILTER=y
CONFIG_IP_NF_TARGET_MASQUERADE=y
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y
CONFIG_NETFILTER_XT_MATCH_CONNTRACK=y
CONFIG_NETFILTER_XT_MATCH_IPVS=y
CONFIG_NETFILTER_XT_MARK=y
CONFIG_IP_NF_NAT=y
CONFIG_NF_NAT=y
CONFIG_NF_NAT_IPV4=y
CONFIG_NF_NAT_NEEDED=y

# ===== LXC 特定配置 =====
CONFIG_SYSVIPC=y         # System V IPC（需要 KMI 修复）
CONFIG_DETECT_HUNG_TASK=y # 检测挂起任务（需要 KMI 修复）
CONFIG_IO_URING=y        # 异步 I/O（需要 KMI 修复）
CONFIG_POSIX_MQUEUE=y    # POSIX 消息队列
CONFIG_KEYS=y            # 密钥管理

# ===== 文件系统支持 =====
CONFIG_OVERLAY_FS=y      # OverlayFS（需要补丁）
CONFIG_EXT4_FS=y
CONFIG_EXT4_FS_POSIX_ACL=y
CONFIG_EXT4_FS_SECURITY=y
CONFIG_BTRFS_FS=y
CONFIG_BTRFS_FS_POSIX_ACL=y

# ===== 其他必需配置 =====
CONFIG_DEVPTS_MULTIPLE_INSTANCES=y
```

## 补丁文件说明

### 1. cgroup_fix.patch
修复 cgroup 文件命名问题，确保 Docker 和 LXC 能正确访问 cgroup 接口。

### 2. overlayfs_fix.patch
移除 overlayfs 中的 `DCACHE_OP_HASH` 和 `DCACHE_OP_COMPARE` 检查，解决 Android sdcardfs 与 Docker overlay2 驱动的兼容性问题。

### 3. task_struct_kmi_fix.patch
使用 `ANDROID_KABI_USE` 和 `_ANDROID_KABI_REPLACE` 宏安全地添加以下结构体成员：
- `sysvsem` (CONFIG_SYSVIPC)
- `sysvshm` (CONFIG_SYSVIPC)
- `last_switch_count` (CONFIG_DETECT_HUNG_TASK)
- `last_switch_time` (CONFIG_DETECT_HUNG_TASK)
- `io_uring` (CONFIG_IO_URING)

这些修改不会破坏 KMI，因为使用了预留的 `ANDROID_KABI_RESERVE` 字段。

---

**注意：** 本指南基于实际经验总结，不同设备和内核版本可能需要额外的调整。建议在修改前备份原始内核和数据。
A: 查看内核源码中的清单文件（manifest），通常会指定推荐的工具链版本。

### Q: 所有内核配置都会破坏 KMI 吗？
A: 不是。只有那些会修改已冻结结构体的配置才会破坏 KMI。需要逐个排查。

---

**注意：** 本指南基于实际经验总结，不同设备和内核版本可能需要额外的调整。建议在修改前备份原始内核和数据。
