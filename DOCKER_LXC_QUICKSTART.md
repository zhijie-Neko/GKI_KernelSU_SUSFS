# Docker & LXC 快速入门指南

## 🚀 快速开始

### 1. 编译内核

#### 使用 GitHub Actions（推荐）
```bash
1. Fork 本仓库
2. 进入 Actions → Build Single Kernel (6.1.118)
3. 点击 Run workflow
4. 等待编译完成（约 30-60 分钟）
5. 下载 Artifacts 中的 AnyKernel3 ZIP
```

### 2. 刷入内核

```bash
1. 重启到 Recovery（TWRP）
2. 刷入下载的 AnyKernel3 ZIP
3. 清除 Dalvik/ART Cache（可选）
4. 重启系统
```

### 3. 验证安装

在 Termux 或 ADB Shell 中运行：

```bash
# 检查内核版本
uname -r
# 应该显示类似: 6.1.118-android14-...-Wild

# 检查配置（需要 root）
su
zcat /proc/config.gz | grep -E "CONFIG_(NAMESPACES|CGROUPS|OVERLAY_FS)" | head -10

# 或使用检查脚本
sh /sdcard/check_docker_lxc_support.sh
```

## 🐳 安装 Docker

### 方法一：使用 Termux

```bash
# 安装 Termux
# 从 F-Droid 或 GitHub 下载

# 更新包
pkg update && pkg upgrade

# 安装依赖
pkg install root-repo
pkg install docker

# 启动 Docker 守护进程（需要 root）
su
dockerd &

# 测试 Docker
docker run hello-world
```

### 方法二：使用预编译二进制

```bash
# 下载 Docker 静态二进制
wget https://download.docker.com/linux/static/stable/aarch64/docker-24.0.7.tgz
tar xzvf docker-24.0.7.tgz
sudo cp docker/* /usr/local/bin/

# 启动 Docker
sudo dockerd &
```

## 📦 安装 LXC

### 使用 Termux

```bash
# 安装 LXC
pkg install lxc

# 检查配置
lxc-checkconfig

# 创建容器
lxc-create -n mycontainer -t download

# 启动容器
lxc-start -n mycontainer

# 进入容器
lxc-attach -n mycontainer
```

## 🔍 故障排查

### Docker 无法启动

```bash
# 检查内核配置
zcat /proc/config.gz | grep CONFIG_OVERLAY_FS
# 应该显示: CONFIG_OVERLAY_FS=y

# 检查 cgroup 挂载
mount | grep cgroup

# 手动挂载 cgroup（如果需要）
su
mount -t tmpfs -o mode=755 tmpfs /sys/fs/cgroup
mkdir -p /sys/fs/cgroup/cpu
mount -t cgroup -o cpu cgroup /sys/fs/cgroup/cpu
```

### LXC 容器无法创建

```bash
# 检查必需的配置
lxc-checkconfig

# 检查 SYSVIPC
zcat /proc/config.gz | grep CONFIG_SYSVIPC
# 应该显示: CONFIG_SYSVIPC=y

# 检查命名空间
ls -la /proc/self/ns/
```

### 权限问题

```bash
# 确保以 root 运行
su

# 检查 SELinux 状态
getenforce
# 如果是 Enforcing，可能需要临时设置为 Permissive
setenforce 0

# 或添加 SELinux 规则（推荐）
```

## 📊 性能优化

### Docker 存储驱动

```bash
# 使用 overlay2（推荐，已启用）
dockerd --storage-driver=overlay2

# 或在配置文件中设置
cat > /etc/docker/daemon.json <<EOF
{
  "storage-driver": "overlay2"
}
EOF
```

### 限制容器资源

```bash
# 限制 CPU
docker run --cpus=".5" ubuntu

# 限制内存
docker run --memory="512m" ubuntu

# 限制 CPU 和内存
docker run --cpus=".5" --memory="512m" ubuntu
```

## 🎯 常用命令

### Docker

```bash
# 拉取镜像
docker pull alpine

# 运行容器
docker run -it alpine sh

# 列出容器
docker ps -a

# 停止容器
docker stop <container_id>

# 删除容器
docker rm <container_id>

# 查看日志
docker logs <container_id>
```

### LXC

```bash
# 列出容器
lxc-ls -f

# 启动容器
lxc-start -n mycontainer

# 停止容器
lxc-stop -n mycontainer

# 删除容器
lxc-destroy -n mycontainer

# 查看容器信息
lxc-info -n mycontainer
```

## 🔧 高级配置

### Docker Compose

```bash
# 安装 Docker Compose
pkg install docker-compose

# 或下载二进制
wget https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-linux-aarch64
chmod +x docker-compose-linux-aarch64
mv docker-compose-linux-aarch64 /usr/local/bin/docker-compose
```

### 网络配置

```bash
# 创建自定义网络
docker network create mynetwork

# 使用自定义网络运行容器
docker run --network=mynetwork alpine

# 查看网络
docker network ls
```

## 📚 示例项目

### 运行 Web 服务器

```bash
# Nginx
docker run -d -p 8080:80 nginx

# 访问 http://localhost:8080
```

### 运行数据库

```bash
# PostgreSQL
docker run -d \
  -e POSTGRES_PASSWORD=mysecret \
  -p 5432:5432 \
  postgres

# MySQL
docker run -d \
  -e MYSQL_ROOT_PASSWORD=mysecret \
  -p 3306:3306 \
  mysql
```

### 开发环境

```bash
# Node.js
docker run -it -v $(pwd):/app node:18 bash

# Python
docker run -it -v $(pwd):/app python:3.11 bash

# Go
docker run -it -v $(pwd):/app golang:1.21 bash
```

## ⚠️ 注意事项

1. **电池消耗**：运行容器会增加电池消耗
2. **存储空间**：Docker 镜像会占用大量存储空间
3. **性能**：移动设备性能有限，大型容器可能运行缓慢
4. **网络**：某些网络功能可能受限于 Android 系统
5. **SELinux**：可能需要调整 SELinux 策略

## 🆘 获取帮助

- 📖 [完整技术文档](./GKI_LXC_DOCKER_GUIDE.md)
- 🐛 [提交 Issue](https://github.com/WildKernels/GKI_KernelSU_SUSFS/issues)
- 💬 [Telegram 群组](https://t.me/WildKernels)

## 📝 更新日志

### v1.0.0 (2025-01)
- ✅ 初始版本
- ✅ 完整的 Docker 支持
- ✅ 完整的 LXC 支持
- ✅ KMI 安全补丁
- ✅ 自动化编译流程

---

**提示：** 如果遇到问题，请先运行 `check_docker_lxc_support.sh` 脚本检查内核配置。
