# wbs auth

> WorkBuddy 双账号一键轮换。个人号和企业号来回切，不用重新扫码登录。

```bash
wbs          # 切到另一个号
```

同一个 WorkBuddy 只能保持一个账号登录。有两个号的人（个人 + 企业）每天要在两者之间倒，每次都得登出、扫码、等加载。这个工具把每个号的登录态各存一份，用一条命令换过来，token 还继续有效。

---

## 它做什么

- **一条命令轮换**：`wbs` 就在两个号之间来回切，不用记账号名
- **不用重新登录**：换回旧号是秒切，不是重新走 OAuth
- **零配置**：首次运行自动找到凭证、认出当前账号、建好仓库
- **只碰本地文件**：不联网、不上传、不碰服务器

支持 macOS 上的 WorkBuddy 桌面版（腾讯版与 CodeBuddy 系产品都可能适用，见[限制](#限制)）。

---

## 原理

WorkBuddy 把当前登录会话加密存在一个文件里：

```
~/Library/Application Support/<产品目录>/Data/Public/auth/<通道>.info
```

文件里是 `accessToken` / `refreshToken` / `account`，token 字段用 `$wbEncrypted` 信封加密。

关键点在于：**加密主密钥在 `~/.workbuddy/keyblob`，同一台机器上所有账号共用同一把**，它由系统层保护，不跟着账号变。

所以：

```
备份 .info 文件  =  备份登录状态
还原 .info 文件  =  还原登录状态
```

换回去的 token 服务端仍然认，因为本来就是同一个客户端、同一把锁、没过期。

这不是破解，也没有绕过任何授权——只是把自己已经登录过的会话文件搬来搬去。

`wbs` 做的额外事情是：切换前确保 WorkBuddy **完全退出**。它运行时会把内存里的会话定期写回该文件，如果直接覆盖会被它盖掉，白切一次。

---

## 安装

### 方式一：一行命令

```bash
curl -fL --retry 3 --connect-timeout 15 -o /tmp/wbs-install.sh \
  https://raw.githubusercontent.com/xianzhen2008-dotcom/wbs-auth/main/install.sh \
  && bash /tmp/wbs-install.sh
```

> **别用 `curl ... | bash`。** 网络抖一下，管道会把半截脚本喂给 bash，结果是几行 `syntax error` 加一个装了一半的残缺文件，还特别难看出发生了什么。先落盘、再执行，就没有这个问题。

国内访问 raw 常超时，换这个源：

```bash
curl -fL --retry 3 -o /tmp/wbs-install.sh \
  https://cdn.jsdelivr.net/gh/xianzhen2008-dotcom/wbs-auth@main/install.sh \
  && bash /tmp/wbs-install.sh
```

装到 `~/.local/bin/wbs`，顺带建 `wbs-auth` 别名，并自动跑一次环境检查。脚本内部下载主程序时也会在 raw 不通时自动切备用源。

### 方式二：让 AI 帮你装

一句话，丢给 Claude Code / WorkBuddy / Cursor 就行：

```
帮我装 https://github.com/xianzhen2008-dotcom/wbs-auth 。先跑 uname -s 看你在哪：不是 Darwin 就说明你在沙箱里、别装，把该在我终端跑的命令给我；是 Darwin 就直接装，装完跑 wbs init 把结果告诉我。别替我切账号。
```

> **如果 AI 说「沙箱 Linux 环境无法安装」**，那是正常现象，不是工具坏了。
> 多数 AI 的命令执行跑在隔离容器里，容器看不到你 Mac 上的 WorkBuddy 登录文件。
> 这时让它把命令给你，**自己在终端里粘一下**就行：
>
> ```bash
> curl -fL --retry 3 -o /tmp/wbs-install.sh https://raw.githubusercontent.com/xianzhen2008-dotcom/wbs-auth/main/install.sh && bash /tmp/wbs-install.sh
> ```
>
> 详细说明见 [`prompts/install.md`](prompts/install.md)，里面有沙箱环境的排查步骤。

### 方式三：手动

```bash
git clone https://github.com/xianzhen2008-dotcom/wbs-auth.git
cd wbs-auth
./install.sh
```

或者直接把 `wbs` 拷到任意 PATH 目录：

```bash
install -m 755 wbs ~/.local/bin/wbs
chmod +x ~/.local/bin/wbs
```

### 环境要求

- **macOS**（Windows / Linux 未适配，见[限制](#限制)）
- **原生终端**，不要在 Docker、容器或 AI 沙箱里装——那些环境看不到你机器上的凭证
- **python3 ≥ 3.8**

安装脚本会依次尝试：PATH 里的 `python3` → `/usr/bin/python3` → Homebrew → **WorkBuddy 自带的那个**（`~/.workbuddy/binaries/python/versions/*/bin/python3`）。装了 WorkBuddy 的机器基本都有，不用额外装。

如果都没有，脚本会提示 `xcode-select --install` 或 `brew install python`。PATH 里没有 `python3` 时会自动把 shebang 钉到找到的绝对路径，装完照样能跑。

无第三方包，不需要 pip。

---

## 用法

```bash
wbs              切到另一个号，切完自动打开 WorkBuddy
wbs -y           同上，不问直接切
wbs -n           只演练，看清会切成什么，不动手
wbs -s           切完不自动打开
wbs st           现在哪个号、续登还剩几天
wbs ls           已保存的号
wbs s [名字]     把当前号存下来（不给名字就按套餐自动起名）
wbs u <名字>     切到指定号（三个号以上时用）
wbs rm <名字>    删掉某个号
wbs init         环境体检 + 自动配置
wbs h            详细说明
```

`wbs auth <子命令>` 与 `wbs <子命令>` 完全等价，两种写法随便用。

名字支持前缀匹配，`wbs u per` 就够了。

### 第一次配置

```bash
# 1. 登录个人号，存下来
wbs s
#   ✓ 已存为 personal

# 2. 在 WorkBuddy 里登出，登录企业号

# 3. 跑一次，让它记住——注意它不会把你弹回去
wbs
#   当前  ● 你的名字 ultimate ...
#     新号，已记作 ultimate
#     两个号都记好了，再跑 wbs 就切到 personal

# 4. 之后就是来回切
wbs
```

第 3 步之所以不切换，是因为你刚登进来，直接弹回旧号很别扭。再跑一次才轮到轮换。

如果懒得手动存，直接跑 `wbs` 也行——发现是没见过的号会自动先记下来。

### 每天怎么用

```bash
wbs        # 换个号
wbs -y     # 连确认都不要
```

### 换新电脑

**快照不能跨机器直接用。** 它是用本机主密钥加密的，换台机器主密钥不同，拷过去大概率解不开——这是加密设计决定的，不是工具的缺陷。

所以换电脑就重来一次，两个号各登一次：

```bash
# 登录第一个号
wbs s

# 登出，登录第二个号
wbs
```

快照目录本身只值一份元信息（套餐名、到期时间），token 那部分搬不动。

> 如果你确实想连密钥一起搬，需要整个 `~/.workbuddy` 目录（含 `keyblob`）一起迁移，而不是只搬 `~/.workbuddy-accounts`。

---

## 安全

需要说清楚几件事：

- **快照里有可直接使用的凭证。** 虽然是加密的，但同一台机器上能被还原成能用的 token。所以仓库 `~/.workbuddy-accounts` 权限设成 `700`，别丢公共目录、别提交到 git、别发给别人。
- **工具不联网。** 除了安装时下载脚本，运行时完全本地，不请求任何服务器。
- **不改 token、不伪造登录。** 只做文件复制。
- **`wbs` 不是官方工具。** 它靠观察文件结构实现，WorkBuddy 更新可能改变存储方式导致失效。失效时不会破坏你的登录态（切换失败只是没切成），最坏情况是重新登录一次。
- **只用于你自己的账号。** 拿它去换别人的账号属于另外一回事，与本工具无关。

---

## 限制

- **只支持 macOS**。Windows 的凭证路径在 `%APPDATA%` 下，尚未验证；Linux 同理。
- **同一时刻只能一个号在线**。WorkBuddy 本身没有多账号并行能力，这个工具做的是快速换，不是同时登。
- **切换会退出 WorkBuddy**，正在跑的对话会中断。这是必须的，见[原理](#原理)。
- **续登凭证约 60 天过期**。`wbs st` 会显示剩余天数，过期了要重新登录一次刷新。
- **一个产品通道一份凭证**。如果你的 WorkBuddy 有多个通道（比如桌面版和 AI 版），它们各自独立，默认只轮换最近在用的那个。可以用 `WBS_CHANNEL` 指定。

---

## 常见问题

**切过去还是要求登录？**

快照的 refreshToken 过期了（一般 60 天）。重新登录一次，然后 `wbs s` 刷新快照。

**`wbs` 说「只认得这一个号」**

另一个号还没存过。切过去登录一次，再跑 `wbs`。

**提示「找不到凭证目录」**

WorkBuddy 没登录，或者装在了非标准位置。先在 WorkBuddy 里登录，再跑 `wbs init`。路径特殊时用 `WBS_AUTH_DIR` 指定。

**切完打开还是旧账号？**

大概率是 WorkBuddy 没退干净就被覆盖了。确认退出后再跑一次，`wbs` 会等进程真正结束。

**运行 `wbs` 弹出一堆 `xcode-select: note: No developer tools were found`？**

安装时装到了系统那个「假」python3（`/usr/bin/python3` 只是个壳，没装 Xcode 命令行工具时跑起来就弹这个）。**不用联网也不用重装**，把第一行的解释器改掉就行：

```bash
sed -i.bak "1s|.*|#!$(ls -d ~/.workbuddy/binaries/python/versions/*/bin/python3 | tail -1)|" ~/.local/bin/wbs
wbs --version
```

或者重跑一次安装，会自动修好。

**`curl: (56) Recv failure` 或者 `bash: syntax error: unexpected end of file`？**

网络把下载掐断了。`curl | bash` 这种写法会把半截脚本直接喂给 bash——前半段已经执行了（所以你能看到「✓ python3」），后半段没了就报 `unexpected end of file`。

改用先落盘再执行，并且重跑一次把残缺文件覆盖掉：

```bash
curl -fL --retry 3 --connect-timeout 15 -o /tmp/wbs-install.sh \
  https://raw.githubusercontent.com/xianzhen2008-dotcom/wbs-auth/main/install.sh \
  && bash /tmp/wbs-install.sh
```

如果 `wbs` 命令已经坏了，上面那条 `sed` 也能先救回来。

**会不会影响公司电脑的合规监控？**

不知道，请自行判断。这工具只操作本地登录文件，不改变 WorkBuddy 本身的任何行为。

---

## 环境变量

| 变量 | 作用 |
|---|---|
| `WBS_HOME` | 快照仓库位置，默认 `~/.workbuddy-accounts` |
| `WBS_AUTH_DIR` | 手动指定凭证目录 |
| `WBS_CHANNEL` | 手动指定产品通道 |
| `WBS_AUTH_RAW` | 安装时的下载源（镜像或内网） |

---

## 卸载

```bash
rm -f ~/.local/bin/wbs ~/.local/bin/wbs-auth
rm -rf ~/.workbuddy-accounts
```

删掉快照不会影响当前登录。想彻底恢复干净，删完后在 WorkBuddy 里重新登录一次。

---

## 目录结构

```
wbs-auth/
├── wbs                 主程序（单文件 Python，无依赖）
├── install.sh          一键安装
├── prompts/install.md  AI 安装提示词
├── docs/how-it-works.md 实现细节
├── README.md
└── LICENSE
```

运行后产生的文件：

```
~/.workbuddy-accounts/          仓库，权限 700
└── snapshots/
    ├── personal/               每个号一个目录
    │   ├── meta.json           账号元信息（uid / 套餐 / 到期时间）
    │   ├── account-snapshot.json
    │   └── auth/
    │       └── workbuddy-desktop.info   加密后的登录态
    └── _auto_xxx/              切换前自动兜底备份，轮换时不计入
```

---

## License

[MIT](LICENSE)

与腾讯 / WorkBuddy 官方无关，非官方工具。
