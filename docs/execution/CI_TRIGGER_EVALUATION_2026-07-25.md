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

## 建议配置

当前为手动创建 Release，推荐普通 CI 只覆盖 PR 和 `main`：

```yaml
on:
  push:
    branches:
      - main
  pull_request:
```

这样 PR 更新验证候选修改，合并后的 `main` 再验证最终提交，tag push 不重复
运行。Windows Release 工件继续由 `main` run 生成，维护者在打 tag 前下载并
校验。

如果未来需要 tag 自动发布，应新建 tag 专用 Release workflow，只执行打包、
签名校验和发布步骤，并复用已经通过的提交级测试结论；不要让普通 CI 与发布
workflow 对同一 tag 重复执行完整测试矩阵。

## 本批次决定

B40 只记录评估，不修改 CI。触发策略调整应作为独立、可回滚的后续批次执行，
并在修改后分别验证 PR push、`main` push 与 tag push 的 run 数量。
