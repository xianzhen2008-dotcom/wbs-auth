# 一键安装提示词

把下面整段内容发给能执行终端命令的 AI 助手（Claude Code / WorkBuddy / Cursor / Codex 等）。

> **重要前提**：这个工具要读写你**本机** WorkBuddy 的登录文件。如果 AI 跑在隔离沙箱（常见于云端 Agent、Linux 容器）里，它看不到你机器上的文件，装了也没用。下面第一版提示词会让 AI 自己判断这件事。

---

## 一句话版

```
装一下 https://github.com/xianzhen2008-dotcom/wbs-auth ，照 README 来，装完把 wbs init 的结果给我，别替我切账号。
```

就这一句。怎么装、什么环境能装、坏了怎么修，README 里都写了，AI 读一遍就知道。

判断能不能装只有一条：`ls -d ~/Library/"Application Support"`。有输出就能装，报错就是隔离容器。

> **用过旧提示词、被劝退过的**：如果之前得到的结论是「沙箱环境装不了」，那多半是判断错了。README 的「让 AI 帮你装」里有纠偏说明，让它重读一遍再判断。

---

## 完整版

想控制得更细（要求逐步汇报、异常逐条解释）用这个：

``` 
帮我安装 wbs auth —— 一个 WorkBuddy 双账号轮换的本地工具。
仓库：https://github.com/xianzhen2008-dotcom/wbs-auth

第一步，先判断你能不能碰到我的真实文件。这比看系统名可靠：

1. 执行：ls -d "$HOME/Library/Application Support" "$HOME/.workbuddy"
   - 两个都不存在 → 你被隔离在另一套文件系统里（Linux 容器、远程执行环境之类），
     看不到我机器上的 WorkBuddy 登录文件，装了也用不了。
     告诉我"我在隔离环境里"，把下面这条命令原样给我，我自己跑：
       curl -fL --retry 3 -o /tmp/wbs-install.sh https://raw.githubusercontent.com/xianzhen2008-dotcom/wbs-auth/main/install.sh && tail -3 /tmp/wbs-install.sh | grep -q WBS_AUTH_INSTALLER_END && bash /tmp/wbs-install.sh
     不要试图映射路径，不要装到那个环境里。
   - 至少一个存在 → 你就在我机器上，继续。

   顺带看一眼 uname -s。它不是 Darwin 就同样按「被隔离」处理。

   注意：如果 uname 是 Darwin、上面两个目录也都存在，哪怕你有文件写入白名单、
   禁了 ps 之类的限制，也说明是同一套文件系统，可以正常装。

2. 安装（仅当第 1 步通过）
   用上面那条已经带完整性校验的命令，别自己拼 curl | bash——
   网络断掉时管道会把半截脚本喂给 bash，装出个残缺文件还看不出原因。

3. 体检
   执行：wbs init
   把完整输出贴给我，不要省略。

4. 如果 init 里有任何 ✗ 或 !
   - 逐条解释是什么意思
   - PATH 没生效就告诉我 source 哪个文件
   - 找不到凭证目录就告诉我先去 WorkBuddy 登录

5. 告诉我下一步

约束：
- 不要替我切换账号，也不要执行 wbs / wbs -y。切换会退出 WorkBuddy，时机我自己定。
- 不要修改 ~/.workbuddy 下的任何东西。
- 不要读取或打印 ~/.workbuddy-accounts 里 .info 的内容，里面有凭证。
- 不要在隔离环境里"变通"安装——文件不在那儿，装了也是废的。
```

---

## 如果 AI 说「装不了」「我在沙箱里」

这是正常现象，不是工具的问题。但要分清它说的是哪种「隔离」：

### 两种「沙箱」，只有一种装不了

| | macOS 进程沙箱 | Linux 容器 / 远程执行 |
|---|---|---|
| 例子 | WorkBuddy 桌面版里跑命令、本地 CLI 代理 | 云端 Agent、Codex 云环境、CI |
| `uname -s` | Darwin | Linux |
| `~` 指向 | 你的真实用户目录 | 容器里的 `/root`、`/home/user` |
| 你的 `.info` 文件 | **看得见** | 看不见 |
| 能不能装 | **能** | 不能 |

macOS 上的沙箱是**进程级**的：禁 `ps`、限某些命令、限制部分写入路径——但文件系统是同一套。写个文件、装个命令都没问题。

Linux 容器是**文件系统隔离**：`/Users/你的名字` 根本不存在，`~` 是另一个人的 home，装进去的东西会话结束就没了。

判断只需要一条：

```bash
ls -d ~/Library/Application\ Support
```

- **有输出** → 同一个文件系统，能装。哪怕 `ps` 用不了、有些路径写不进去，都不影响。
- **报错没有这个目录** → 你在另一套文件系统里，别装了。

`wbs` 的全部价值就是操作**你本机**那个加密的登录文件，文件不在这儿就无从谈起。

### 确认装不了的话

**打开你自己电脑的「终端 / Terminal」，粘这一行：**

```bash
curl -fL --retry 3 -o /tmp/wbs-install.sh https://raw.githubusercontent.com/xianzhen2008-dotcom/wbs-auth/main/install.sh && tail -3 /tmp/wbs-install.sh | grep -q WBS_AUTH_INSTALLER_END && bash /tmp/wbs-install.sh
```

不需要 AI 参与，装完直接能用。想让它帮你解读输出，把结果贴回去问它。

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
- 命令：wbs（轮换）/ wbs st（状态）/ wbs s（存当前号）/ wbs init（体检）/ wbs up（升级）/ wbs h（详细说明）

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
| macOS 终端里手动跑 | 能，唯一完整验证过的组合 |
| macOS + AI 在同一套文件系统里（含进程级沙箱） | 能。AI 能访问你的文件就行，禁 `ps`、限部分路径都不妨碍 |
| macOS + AI 跑在 Linux 容器 / 远程环境 | 不能。让 AI 把命令给你，自己终端跑 |
| macOS + 没装 WorkBuddy | 用不上，本工具就是给它换号的 |
| macOS + 没有 python3 | 能。WorkBuddy 自带一个，安装脚本会自动找到并钉住 shebang |
| Linux | 不能，凭证路径和加密后端都不同，未适配 |
| Windows | 不能，同上 |

之所以"没 python3 也能用"基本成立，是因为**目标用户必然装了 WorkBuddy**，而 WorkBuddy 自己就带 python（跑 skills 用）。所以实际卡在这个点的概率很低。

之所以"AI 沙箱里不能装"是硬限制，是因为沙箱和你的 Mac 之间隔着文件系统边界——不是改个判断、加个路径映射能绕过去的。
