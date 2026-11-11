# 实现细节

给想改代码或排查问题的人看。

## 凭证都存在哪

`wbs` 不写死路径，而是扫描：

```
~/Library/Application Support/*/Data/Public/auth/*.info
```

排序规则：优先挑文件名里带 `workbuddy` 或 `codebuddy` 的，其次挑最近被写过的。这样换产品目录名、换安装形态都不用改代码。

每个 `.info` 对应一个「产品通道」。一台机器上可能同时存在：

- `workbuddy-desktop.info` —— 桌面版主通道
- `workbuddy-desktop-ai.info` —— 另一个通道，通常是另一个账号

默认只操作**最近更新的那个**，其余通道互不干扰。要指定用 `WBS_CHANNEL`。

## 文件结构

```jsonc
{
  "auth": {
    "accessToken":  { "$wbEncrypted": 1, "envelope": "eyJzdWl0ZSI6MSw..." },
    "refreshToken": { "$wbEncrypted": 1, "envelope": "..." },
    "expiresAt": 1796981447468,
    "refreshExpiresAt": 1799573446468,
    "sessionState": "...",
    "domain": "www.workbuddy.cn"
  },
  "account": {
    "uid": "...",
    "type": "personal",        // 企业号这里可能是 ultimate
    "uin": "...",
    "isCurrentOneIdEnterprise": false,
    "isCurrentOneIdPersonal": true
  },
  "accounts":    [ /* 账号数组，实际只写 1 个 */ ],
  "allAccounts": [ /* 同上 */ ]
}
```

`accounts` / `allAccounts` 结构上支持多账号，但应用当前只写一个。所以不能指望应用自己切——它的 `switchAccount` 走的是 `login.enterprise.switch`，本质是重新走一遍 OAuth。

## 加密怎么解的

`$wbEncrypted` 信封里是：

```json
{
  "suite": 1,
  "keyId": "9127dea1b44020a7",
  "nonce": "...",
  "authTag": "...",
  "ciphertext": "..."
}
```

`keyId` 指向 `~/.workbuddy/keyblob` 里的主密钥槽位。keyblob 本身是被系统层（macOS Keychain / Windows DPAPI）保护的，格式是：

```json
{
  "version": 1,
  "keyId": "...",
  "slots": [{ "type": "static-v1", "protectorKeyId": "...", "wrapped": "..." }]
}
```

**`wbs` 完全不碰加密。** 它只复制整份 `.info`，让应用自己去解。所以：

- 不需要导出、解密、重新加密 token
- 不需要理解 `suite` 的具体算法
- 同机同用户下，主密钥永远对得上

这也是为什么换到另一台机器时，单纯拷快照有时能用、有时不能——取决于那把主密钥是否相同。

## 切换时序

顺序不能错：

```
1. 确认目标快照存在
2. 兜底备份当前号 → snapshots/_auto_<plan>-<uin4>/
3. 确认 WorkBuddy 在跑 → osascript quit → 轮询直到进程消失（最多 25s）
4. 备份现有 .info 为 .info.bak
5. 覆盖 .info
6. chmod 600
7. 同步 storage/skeleton/account-snapshot.json（首屏缓存）
8. open -a WorkBuddy
```

第 3 步是关键。WorkBuddy 运行时会周期性 refresh token 并写回文件，如果不等它退出，覆盖会被它盖掉。

第 7 步是为了首屏不显示错的账号名。`account-snapshot.json` 是明文缓存，结构：

```json
{ "primary": { "uid": "...", "nickname": "威", "type": "personal" } }
```

昵称从这里读——`account.nickname` 是加密的，解不开，但缓存里是明文。

## 账号识别

| 信息 | 来源 |
|---|---|
| uid / type / uin / 到期时间 | `.info` 的 `account`、`auth` 段，明文 |
| 昵称 | `storage/skeleton/account-snapshot.json` |
| 套餐名（personal / ultimate） | `local_storage/wb_entry_*.info` 里的账号历史，key 格式 `<uid>\|<plan>\|<corpId>\|<uin>` |

昵称拿不到就退化成 uid 前 8 位，不影响功能。

## 快照仓库

```
~/.workbuddy-accounts/          700
└── snapshots/
    ├── personal/
    │   ├── meta.json           uid / plan / uin / nickname / 到期时间 / 保存时间
    │   ├── account-snapshot.json
    │   └── auth/
    │       └── workbuddy-desktop.info   600
    └── _auto_personal-2942/    切换前自动备份，轮换时被过滤掉
```

`_auto_` 前缀是约定：`all_snapshots()` 默认不返回它们，避免兜底备份干扰两号判断。

同一账号重复 `wbs s` 会复用原名字，不会存出第二份。

## 两号轮换的判定

```python
当前 uid → 找出所有非 _auto_ 快照 → 过滤掉自己 → 剩下的就是「另一个号」
```

- 0 个：提示去登录另一个号
- 1 个：切过去
- 多个：要求 `wbs u <名字>` 指定，不猜

首次遇到没存过的号，会先静默存一份并**停止**，不继续切换——刚登录就被弹回旧号很别扭。

## 适配其他产品

改三个地方：

1. `find_auth_dir()` —— 候选目录的 glob 模式
2. `pick_channel()` —— 通道挑选规则
3. 如果目标产品的 `.info` 结构不同，`account_meta()` 的字段映射

Windows 需要另做，凭证大概率在 `%APPDATA%` 下，且 DPAPI 的行为与 macOS 不同，未经实测不做承诺。

## 已知坑

**`Path.mkdir(exist_ok=True)` 在某些沙箱环境会抛 `FileExistsError`。** 有些 Electron 应用会给 Python 注入 `sitecustomize.py` 做文件访问拦截，它的 `mkdir` 实现没正确处理 `exist_ok`。代码里统一走 `mkd()`，先 `is_dir()` 判断再建。

**非 TTY 环境不切换。** `wbs` 在管道/脚本里跑时，确认环节会拿不到输入。此时直接拒绝，要求显式 `-y`，防止顺手跑一下就把应用退了。

**`.info.bak` 会累积。** 每次切换留一份，用于极端情况下手工回滚。数量不多（同通道覆盖同名），介意可以手动清。
