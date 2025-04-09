# Linux系统Clash一键部署教程

此项目是通过使用开源项目 [clash](https://github.com/Dreamacro/clash) 作为核心程序（默认使用 [Kuingsmile/clash-core](https://github.com/Kuingsmile/clash-core) fork 版本进行自动下载）,以及前人[clashforlinux](https://github.com/AFanSKyQs/ClashForLinux.git)框架，再结合脚本实现简单的代理功能。

主要是为了解决我们在服务器上下载GitHub等一些国外资源速度慢的问题。

<br>

# 使用教程

## 前置步骤 (适用于所有方法)

### 1. 下载项目

```bash
# 建议克隆到 /usr/local/ 或 /opt/ 目录下
git clone https://github.com/CelestialIce/ClashForLinux.git
```

### 2. 进入目录

```bash
cd ClashForLinux
```

---

## 方法一：自动下载Clash核心 (推荐)

**此方法会自动检测系统架构，下载对应的 Clash 核心文件，并使用您提供的 `config.yaml` 启动服务。**

**优点：** 无需手动下载和放置 Clash 二进制文件。
**要求：** 您必须**手动准备一个完整且有效的 `config.yaml`** 文件，包含所有必要配置（端口、模式、DNS、`allow-lan: true`, `bind-address: '*'` 等）以及您的**代理节点信息**。

### 步骤：

#### 1. 准备 `config.yaml`

*   获取或创建您的 Clash 配置文件 (`config.yaml`)。 **确保它包含完整的代理节点/策略组信息。** 此脚本**不会**从订阅链接下载节点。
*   **将您准备好的 `config.yaml` 文件放入项目目录下的 `conf/` 文件夹中。**
    *   例如: `cp /path/to/your/config.yaml ./conf/`
    *   如果 `conf/` 目录不存在，请创建它: `mkdir conf`

#### 2. 运行自动设置脚本

*   (重要) 确保您已经将 `config.yaml` 放入 `./conf/` 目录！
*   执行脚本 (可能需要 `sudo` 权限来安装 `proxy_on`/`proxy_off` 环境变量助手):

```bash
sudo bash start-auto.sh
# 请将 start-auto.sh 替换为您实际的脚本名称 (例如 start2.sh 或 start3.sh)
```

*   脚本将执行以下操作：
    *   创建必要的目录 (`logs`, `bin`)。
    *   检查 `conf/config.yaml` 是否存在。
    *   检测 CPU 架构 (amd64, arm64, armv7)。
    *   从 GitHub (Kuingsmile/clash-core) 下载对应架构的 Clash v1.18.0 二进制文件到 `bin/` 目录。
    *   解压、重命名并设置执行权限。
    *   使用 `conf/config.yaml` 启动 Clash 服务。
    *   设置 `/etc/profile.d/clash.sh` 以提供 `proxy_on` / `proxy_off` 命令。

#### 3. 查看输出并启用代理

*   脚本成功执行后会显示类似以下信息：

```
Starting Clash Setup...
Created necessary directories                              [  OK   ]
Checking for configuration file...
Found configuration file: ./conf/config.yaml              [  OK   ]
# ... (Optional Dashboard config) ...
Reading API Secret...
Retrieved API Secret                                       [  OK   ]
Detecting CPU Architecture...
Detected CPU Architecture: x86_64                          [  OK   ]
Preparing Clash Core Binary (v1.18.0)...
# ... (Download/Extract/Rename/Permissions steps) ...     [  OK  ]
Clash binary is ready at ./bin/clash-linux-amd64
Starting Clash service...
Clash service started successfully!                        [  OK  ]

Clash Dashboard Access: http://<Your-Server-IP>:9090/ui
API Secret            : <Your-Secret-If-Set>
Mixed Proxy Port      : 7890 (HTTP/SOCKS)
Log File              : ./logs/clash.log

Setting up proxy environment helper functions...
Proxy helper functions installed to /etc/profile.d/clash.sh[  OK  ]

Proxy Helper Commands (run in a new shell or after sourcing):
  \033[32msource /etc/profile.d/clash.sh\033[0m (Load functions in current shell)
  \033[32mproxy_on\033[0m                    (Set proxy environment variables)
  \033[31mproxy_off\033[0m                   (Unset proxy environment variables)
```

*   加载环境变量并开启代理：

```bash
source /etc/profile.d/clash.sh
proxy_on
```

---

## 方法二：使用订阅链接 (原始方法)

**此方法会尝试从您提供的订阅链接下载节点信息，并与模板配置合并。**

**要求：** 您需要**手动**将正确的 Clash 核心二进制文件放在 `bin/` 目录下 (例如 `bin/clash-linux-amd64`)。
**注意：** 许多机场订阅链接是加密的或需要特定 User-Agent，直接下载可能失败或无法获取节点信息。

### 步骤：

#### 1. (手动) 准备 Clash 核心

*   从 [Clash Releases](https://github.com/Dreamacro/clash/releases) 或其他来源下载适合您服务器架构的 Clash 二进制文件。
*   创建 `bin` 目录: `mkdir bin`
*   将下载的二进制文件放入 `bin/` 目录，并确保其名称与 `start.sh` (或 `StartRun.sh` 调用的 `start.sh`) 脚本内预期的名称一致（通常是 `clash-linux-amd64`, `clash-linux-arm64`, 或 `clash-linux-armv7`）。
*   确保文件有执行权限: `chmod +x bin/clash-linux-*`

#### 2. 运行启动脚本

```bash
bash StartRun.sh
```

#### 3. 粘贴你的订阅地址、回车

> 可以使用 Shift+Insert 粘贴，或者鼠标右键粘贴 (取决于您的终端)。

#### 4. !!! 重点检查 !!!

*   脚本运行后，**强烈建议** 结合 `ftp` 软件或者直接使用 `vim` 查看 `ClashForLinux/conf/config.yaml` 配置文件内**是否有订阅节点信息** (`proxies:` 列表下应该有很多节点)。
*   现在大部分机场的订阅链接返回的内容可能无法被此脚本直接解析，导致 `config.yaml` 中**没有实际的代理节点**。

#### 5. 如果没有节点信息该怎么办？(订阅链接转换)

*   如果 `conf/config.yaml` 没有节点，说明直接下载失败。您需要使用订阅转换服务：
    1.  前往一个订阅转换网站，例如：`https://suburl.v1.mk/` (或您信任的其他转换器，`clash.back2me.cn` 可能已失效)
    2.  填入你的原始订阅链接 (`确保你链接原本就可用`)。
    3.  选择生成 Clash 配置。通常有选项指定输出格式为 `Clash`。
    4.  生成新的订阅链接 (这个链接指向的是转换后的 **完整配置文件内容**)。
    5.  复制这个**新生成的链接**。
    6.  **重新运行步骤 2 的脚本 (`bash StartRun.sh`)**，当提示输入订阅地址时，粘贴**这个新链接**，然后回车。

#### 6. 查看输出并启用代理

*   如果一切顺利，脚本会自动下载配置、合并、启动服务，并显示类似 `start.sh` 的输出信息。
*   加载环境变量并开启代理：

```bash
source /etc/profile.d/clash.sh
proxy_on
```

---

## 通用操作

### 远程设置节点 (Clash Dashboard)

*   **访问 Clash Dashboard**
    通过浏览器访问脚本执行成功后输出的地址 (`Clash Dashboard Access`)，例如：`http://<Your-Server-IP>:9090/ui` (请将 `<Your-Server-IP>` 替换为您服务器的实际 IP 地址)。
*   **登录管理界面**
    *   在 `Host` 或 `API Base URL` 一栏中输入：`http://<Your-Server-IP>:9090`
    *   在 `Secret(optional)` 一栏中输入启动成功后输出的 `Secret` (如果您的 `config.yaml` 中设置了 secret)。
    *   点击 `Add` 或 `Login` 并选择/连接到您刚刚输入的服务器地址。
    *   之后便可在浏览器上进行策略选择、查看连接等配置。
*   **更多教程**
    此项目默认配置的 Clash Dashboard 使用的是 [yacd](https://github.com/haishanh/yacd) 或类似面板，详细使用方法请移步到对应面板的项目主页查询。

### 检查服务状态

*   **检查服务端口**

```bash
# netstat 可能需要安装 (yum install net-tools / apt install net-tools)
# 或者使用 ss 命令: ss -tlpn | grep -E '9090|789.'
netstat -tlnp | grep -E '9090|789.'
```
> 你应该能看到 Clash 监听的端口 (例如 9090 控制端口, 7890 混合代理端口)。

*   **检查环境变量**

```bash
env | grep -E 'http_proxy|https_proxy|no_proxy'
```
> 如果执行了 `proxy_on`，这里应该显示设置的代理变量。

以上步骤如果正常，说明 Clash 服务启动成功，现在就可以体验高速下载 GitHub 资源或访问其他网站了。

<br>

### 重启程序 (`restart.sh`)

*   如果需要对 Clash 配置进行修改 (例如调整规则、DNS 等)，请**直接修改 `conf/config.yaml` 文件**。
*   然后运行 `restart.sh` 脚本进行重启以应用更改。

```bash
# 确保在 ClashForLinux 目录下
bash restart.sh
```

> **注意：**
> 重启脚本 `restart.sh` **不会**重新下载 Clash 核心，也**不会**更新订阅信息（它只是使用当前的 `conf/config.yaml` 重启 Clash 进程）。

<br>

### 停止程序 (`shutdown.sh`)

*   进入项目目录

```bash
cd ClashForLinux
```

*   关闭服务

```bash
bash shutdown.sh
```

*   脚本会提示关闭成功，并提醒您关闭系统代理：

```bash
proxy_off
```

*   然后可以再次检查程序端口、进程以及环境变量 `http_proxy|https_proxy`，若都没有则说明服务正常关闭。

<br>

# 常见问题

1.  **Shell 兼容性:** 部分 Ubuntu/Debian 系统默认的 `/bin/sh` 链接到 `dash`，而不是 `bash`。如果直接运行 `./*.sh` 出现语法报错，请明确使用 `bash` 来执行脚本，例如 `bash start-auto.sh`。
2.  **下载失败:** 如果使用 `start-auto.sh` 时下载 Clash 核心失败，请检查服务器网络连接是否正常，能否访问 GitHub。您也可以尝试手动下载对应的二进制文件放入 `bin/` 目录，然后再次运行脚本（脚本设计为如果发现已存在可执行文件则跳过下载）。
3.  **订阅无效 (方法二):** 如上文所述，`StartRun.sh` 直接使用订阅链接的功能可能因链接加密或需特定 User-Agent 而失败。强烈建议使用**方法一**并手动准备好 `config.yaml`，或在**方法二**中使用订阅转换服务获取完整的配置链接。
4.  **端口冲突:** 如果服务器上的 9090 或 7890 等端口已被其他程序占用，Clash 将启动失败。请检查端口占用 (`netstat -tlnp | grep <port>` 或 `ss -tlpn | grep <port>`)，并在 `conf/config.yaml` 中修改 Clash 使用的端口 (`port`, `mixed-port`, `external-controller`)，然后重启。
5.  **权限问题:** 运行 `start-auto.sh` 时建议使用 `sudo bash start-auto.sh`，因为它需要权限将 `clash.sh` 写入 `/etc/profile.d/`。如果服务无法启动，请检查 `logs/clash.log` 文件获取详细错误信息。

---