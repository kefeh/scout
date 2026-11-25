# Scout

**An AI QA agent for Android apps.** Tell it what to test ("check out with an empty cart, then go offline"), and it drives the app on a real phone, watches for crashes, ANRs and failed requests, and writes a report with the evidence: screenshots, screen recording, logcat and stack traces. Each bug it finds becomes a replayable test.

> **Status:** week 1 of 26, building in public. Nothing here works yet. Follow along on the [project board](https://github.com/users/kefeh/projects/2) and in the [devlog](docs/devlog/).

## How Scout differs
- **Open source**, and runs locally with small open models, so testing costs nothing per run.
- **Flutter-aware:** the optional `qa_probe` SDK lets Scout see inside a Flutter app (network calls, errors, the widget tree) instead of guessing from pixels.
- **Bugs it can prove:** every finding comes with a deterministic Maestro flow that reproduces it, and Scout's own accuracy is measured against `bugzoo`, an app with planted bugs.

## Layout
| Path | What | From |
|---|---|---|
| `runner/` | Python agent (adb + uiautomator2 + model) | week 1 |
| `apps/bugzoo/` | Flutter shop app with planted bugs | week 2 |
| `apps/control/` | Flutter macOS app to start and watch runs | week 3 |
| `packages/qa_probe/` | Flutter SDK for white-box mode | January |
| `crates/` | Rust: `logsift`, `qa-core` | February |
| `deploy/` | Docker, Terraform, Helm, Argo CD | January |
| `docs/devlog/` | Weekly build log | week 1 |

## Roadmap
| Release | Target | Milestone |
|---|---|---|
| v0.1 | Dec 20, 2026 | Agent finds planted bugs on a real phone; control app shipped by CI |
| v0.2 | Feb 7, 2027 | Backend, `qa_probe` SDK, Maestro reproductions, GitHub issues |
| v0.3 | Mar 28, 2027 | Runs on Kubernetes (Helm, RBAC, network policies) |
| v1.0 | Apr 25, 2027 | QA on every PR, fix loop opening draft PRs, GitOps + observability |

## Licence
MIT
