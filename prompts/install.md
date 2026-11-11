# 一键安装提示词

把下面整段内容发给能执行终端命令的 AI 助手（Claude Code / WorkBuddy / Cursor / Codex 等）。

---

## 一句话版

最省事的用法，直接复制这一句：

```
帮我装这个 WorkBuddy 双账号切换工具 https://github.com/xianzhen2008-dotcom/wbs-auth ，装完跑 wbs init 把结果告诉我，别替我切账号。
```

这句话里已经包含了最关键的三件事：装哪个、装完要验证什么、以及不要越界替你切账号。

---

## 完整版

想控制得更细（要求逐步汇报、异常逐条解释）就用这个：

```
帮我安装 wbs auth —— 一个 WorkBuddy 双账号轮换的本地小工具。

仓库：https://github.com/xianzhen2008-dotcom/wbs-auth

请按顺序做，每步把结果告诉我：

1. 确认环境
   - 确认是 macOS（uname -s 输出 Darwin）
   - 确认有 python3，且版本 ≥ 3.8
   - 不满足就告诉我缺什么，先别继续

2. 安装
   执行：curl -fsSL https://raw.githubusercontent.com/xianzhen2008-dotcom/wbs-auth/main/install.sh | bash

3. 体检
   执行：wbs init
   把完整输出贴给我，不要省略。

4. 如果 init 里出现任何 ✗ 或 ! 项
   - 逐条解释是什么意思
   - PATH 没生效就告诉我该 source 哪个文件
   - 找不到凭证目录就告诉我先去 WorkBuddy 登录

5. 告诉我下一步

约束：
- 不要替我切换账号，也不要执行 wbs / wbs -y。切换会退出 WorkBuddy，我得自己决定时机。
- 不要修改 ~/.workbuddy 下的任何东西。
- 不要读取或打印 ~/.workbuddy-accounts 里 .info 文件的内容，里面有凭证。
- 装完只要告诉我：装在哪、当前认到几个号、下一步该做什么。
```

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

## 如果你不想让 AI 装

两条命令等价：

```bash
curl -fsSL https://raw.githubusercontent.com/xianzhen2008-dotcom/wbs-auth/main/install.sh | bash
wbs init
```

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

- 只支持 macOS，别在 Linux / Windows 上试，凭证路径不一样。
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
| macOS + 装了 WorkBuddy | 能，这也是唯一验证过的组合 |
| macOS + 没装 WorkBuddy | 用不上，本工具就是给它换号的 |
| macOS + 没有 python3 | 能。WorkBuddy 自带一个，安装脚本会自动找到并钉住 shebang |
| Linux | 不能，凭证路径和加密后端都不同，未适配 |
| Windows | 不能，同上 |

之所以"没 python3 也能用"基本成立，是因为**目标用户必然装了 WorkBuddy**，而 WorkBuddy 自己就带 python（跑 skills 用）。所以实际卡在这个点的概率很低。
