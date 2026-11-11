# 一键安装提示词

把下面整段内容发给能执行终端命令的 AI 助手（Claude Code / WorkBuddy / Cursor / Codex 等）。

> **重要前提**：这个工具要读写你**本机** WorkBuddy 的登录文件。如果 AI 跑在隔离沙箱（常见于云端 Agent、Linux 容器）里，它看不到你机器上的文件，装了也没用。下面第一版提示词会让 AI 自己判断这件事。

---

## 一句话版

```
帮我装 https://github.com/xianzhen2008-dotcom/wbs-auth 。先 uname -s 看你在哪：不是 Darwin 就说明在沙箱里、别装，把 README 里那条带完整性校验的安装命令给我，我自己跑；是 Darwin 就直接装，装完跑 wbs init 把结果告诉我。别替我切账号。
```

这句包含了三件事：装什么、先判断环境、不准越界切账号。

---

## 完整版

想控制得更细（要求逐步汇报、异常逐条解释）用这个：

``` 
帮我安装 wbs auth —— 一个 WorkBuddy 双账号轮换的本地工具。
仓库：https://github.com/xianzhen2008-dotcom/wbs-auth

第一步，先确认你运行在什么环境，别急着装：

1. 执行 uname -s
   - 结果不是 Darwin：你在我 AI 助手的沙箱里，不是我的电脑。
     直接告诉我"我在沙箱里装不了"，然后把下面这行命令原样给我，
     让我自己在终端里跑：
       curl -fL --retry 3 -o /tmp/wbs-install.sh https://raw.githubusercontent.com/xianzhen2008-dotcom/wbs-auth/main/install.sh && tail -3 /tmp/wbs-install.sh | grep -q WBS_AUTH_INSTALLER_END && bash /tmp/wbs-install.sh
     不要尝试绕过，不要试图映射路径，不要装到沙箱里。
   - 结果是 Darwin：继续下一步。

2. 再确认能不能看到我的真实用户目录：
   执行 ls -d "$HOME/Library/Application Support" "$HOME/.workbuddy"
   - 两个都不存在：说明还是受限环境，同样把命令给我，别装。
   - 至少一个存在：正常，可以装。

3. 安装（仅当上面两步都通过）
   执行：curl -fL --retry 3 -o /tmp/wbs-install.sh https://raw.githubusercontent.com/xianzhen2008-dotcom/wbs-auth/main/install.sh && tail -3 /tmp/wbs-install.sh | grep -q WBS_AUTH_INSTALLER_END && bash /tmp/wbs-install.sh

4. 体检
   执行：wbs init
   把完整输出贴给我，不要省略。

5. 如果 init 里有任何 ✗ 或 !
   - 逐条解释是什么意思
   - PATH 没生效就告诉我 source 哪个文件
   - 找不到凭证目录就告诉我先去 WorkBuddy 登录

6. 告诉我下一步

约束：
- 不要替我切换账号，也不要执行 wbs / wbs -y。切换会退出 WorkBuddy，时机我自己定。
- 不要修改 ~/.workbuddy 下的任何东西。
- 不要读取或打印 ~/.workbuddy-accounts 里 .info 的内容，里面有凭证。
- 不要在沙箱里"变通"安装——路径对不上，装了也是废的。
```

---

## 如果 AI 说"沙箱 Linux 环境无法安装"

这是正常现象，不是工具的问题。

多数 AI 助手的命令执行跑在隔离容器里（Linux），和你自己的 Mac 是两个世界：

- 容器里 `uname -s` 返回 `Linux`
- 容器里没有 `~/Library/Application Support/CodeBuddyExtension`
- 容器里装的东西，会话结束就没了

而 `wbs` 的全部价值就是操作**你本机**那个加密的登录文件。所以：

**打开你自己电脑的「终端 / Terminal」，粘这一行就行：**

```bash
curl -fL --retry 3 -o /tmp/wbs-install.sh https://raw.githubusercontent.com/xianzhen2008-dotcom/wbs-auth/main/install.sh && tail -3 /tmp/wbs-install.sh | grep -q WBS_AUTH_INSTALLER_END && bash /tmp/wbs-install.sh
```

不需要 AI 参与，装完直接能用。想让它帮你解读输出，把结果贴回去问它。

### 如果你的 AI 确实跑在本机

有些配置下（比如本地 CLI 版 Claude Code、关掉沙箱的 WorkBuddy），AI 就是在你的 Mac 上执行命令。判断方法：

```bash
uname -s                              # Darwin
ls -d ~/Library/Application\ Support   # 存在
```

两条都满足，让它装没问题。我这台就是这么装的。

---

## 装完预期看到什么

```
WorkBuddy 账号轮换 · 环境配置
──────────────────────────────────────────────────────────────
  ✓ 应用     WorkBuddy.app
  ✓ 凭证目录 ~/Library/Application Support/CodeBuddyExtension/Data/Public/auth
  ✓ 当前通道 workbuddy-desktop  11-11 18:00 更新
  ✓ 登录账号 你的名字 personal  uin 1234567890
  ✓ 续登凭证 2027-01-10 18:00  剩 59 天
  ✓ 快照仓库 ~/.workbuddy-accounts  已创建 1 份
  ✓ 命令路径 ~/.local/bin  已在 PATH
──────────────────────────────────────────────────────────────
✓ 已自动保存当前号：personal  (你的名字 personal)

下一步
  1. 在 WorkBuddy 里登出，登录另一个号
  2. 回来跑 wbs  它会自动记住，不会把你弹回去
  3. 之后再跑 wbs 就开始来回切了
```

看到这个就说明装好了，当前账号也已经自动采集完成。

---

## 给 AI 的补充上下文（可选，贴在上面提示词后面）

```
关于这个工具你可能想知道：

- 它不联网，运行时只在本地复制文件。
- 凭证在 ~/Library/Application Support/<产品目录>/Data/Public/auth/*.info，
  加密主密钥在 ~/.workbuddy/keyblob，同机所有账号共用一把，所以换文件等于换登录态。
- 切换必须等 WorkBuddy 完全退出，否则退出时内存会话会写回覆盖。
  工具内部已经处理了这个等待，所以不需要你额外做什么。
- 快照在 ~/.workbuddy-accounts/snapshots/<名字>/，权限 700。
- 命令：wbs（轮换）/ wbs st（状态）/ wbs s（存当前号）/ wbs init（体检）/ wbs h（详细说明）

环境上的注意事项：

- 只支持 macOS 原生环境，别在 Linux / Windows 上试，凭证路径和加密方式都不同。
- 不要在容器或沙箱里装，那些环境看不到宿主机文件，装了没有意义。
- 需要 python3 ≥ 3.8。安装脚本会自己找，包括 WorkBuddy 自带的
  ~/.workbuddy/binaries/python/versions/*/bin/python3。
- 如果 install.sh 报「没找到 python3」，不要自己乱装一堆东西，
  先确认 ~/.workbuddy/binaries/python 是否被清过；
  真要装就 xcode-select --install，别用 pip 装 python。
```

---

## 关于「任何环境」的说明

不绕弯子：**不是任何环境都能用**。

| 场景 | 能不能用 |
|---|---|
| macOS 本机终端 | 能，唯一验证过的组合 |
| macOS 本机 + AI 跑在本机 | 能，AI 可以直接装 |
| macOS + AI 跑在 Linux 沙箱 | 不能。让 AI 把命令给你，自己终端跑 |
| macOS + 没装 WorkBuddy | 用不上，本工具就是给它换号的 |
| macOS + 没有 python3 | 能。WorkBuddy 自带一个，安装脚本会自动找到并钉住 shebang |
| Linux | 不能，凭证路径和加密后端都不同，未适配 |
| Windows | 不能，同上 |

之所以"没 python3 也能用"基本成立，是因为**目标用户必然装了 WorkBuddy**，而 WorkBuddy 自己就带 python（跑 skills 用）。所以实际卡在这个点的概率很低。

之所以"AI 沙箱里不能装"是硬限制，是因为沙箱和你的 Mac 之间隔着文件系统边界——不是改个判断、加个路径映射能绕过去的。
