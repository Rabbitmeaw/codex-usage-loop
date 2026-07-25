# CI 触发次数评估

日期：2026-07-25

## 结论

当前 CI 不是每次 push 固定执行两次。普通 `main` push 只执行一次；同一提交先
推送到 `main`、随后再推送版本 tag 时，会分别触发一次完全相同的 CI。对于当前
没有 tag 专用发布逻辑的工作流，这种重复验证收益很低，不建议长期保留。

## 证据

`.github/workflows/ci.yml` 当前同时监听未限定 ref 的 `push` 和
`pull_request`。未限定的 `push` 会匹配分支与 tag。

| 提交 | ref | run | 结果 |
| --- | --- | --- | --- |
| `bd2d532` | `main` | `30147272838` | 成功 |
| `bd2d532` | `v0.1.2` | `30147346010` | 成功 |
| `2b5c3c8` | `main` | `30147400783` | 成功 |
| `2b5c3c8` | `v0.1.2` | `30147423662` | 成功 |

同仓库功能分支存在打开的 PR 时，一次分支 push 还可能同时触发 `push` 与
`pull_request`；fork PR 通常只在目标仓库看到 `pull_request` run。

## 成本与收益

- `main` 与 tag 指向同一提交，当前两次 run 执行相同的 macOS 测试／编译和
  Windows 构建／集成／打包，没有增加不同平台或发布门槛。
- Windows job 还会重复生成并上传同名 Release 工件，增加 runner 时间和工件
  存储，但不提高 tag 与提交的一致性；一致性已由 tag 指向和 Release 元数据
  校验承担。
- PR 合并后再验证 `main` 的合并提交仍然合理，不应与 tag 重复混为一类。

## 已实施配置

B41 已将普通 CI 限定为 PR 和 `main`：

```yaml
on:
  push:
    branches:
      - main
  pull_request:
```

这样 PR 更新验证候选修改，合并后的 `main` 再验证最终提交；普通 CI 不再因
tag push 重复运行，也不再为每个 `main` push 保存 Windows Release 工件。

新增的 `.github/workflows/release.yml` 只监听 `v*` tag。它确认 tag 提交属于
`origin/main`、版本与说明文件一致，重新执行发布所需的双平台测试、构建、
集成、签名与校验和检查，再以最小写权限创建 GitHub Release。发布重跑测试是
独立发布门禁，不会与普通 CI 在同一次 tag push 上形成两个 workflow run。

## 本批次决定

B40 只记录评估；B41 已实施触发策略拆分。`main` push 仍应只有一个日常 CI
run，`vX.Y.Z` tag 只触发一个 Release workflow。PR 与合并后的 `main` 各验证
一次属于不同提交阶段，保留。
