#!/usr/bin/env bash
# One-time GitHub setup for Scout: milestones, labels, P0 issues and the project board.
# Run AFTER the repo exists on GitHub and you have pushed:
#   gh auth login --web -s project      (once)
#   ./scripts/setup-github.sh
# Safe to re-run for labels; milestones/issues/board would be created twice, so run it once.
set -euo pipefail

REPO="${REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
OWNER="${REPO%%/*}"
echo "Setting up $REPO"

# ---- milestones (due at the end of each phase) --------------------------------------
milestone() { gh api "repos/$REPO/milestones" -f title="$1" -f due_on="$2T23:59:59Z" -f description="$3" --silent; echo "  milestone: $1"; }
milestone "P0 · v0.1 agent + bugzoo"       2026-12-20 "Agent finds planted bugs on a real phone; control app shipped by CI"
milestone "P1 · v0.2 backend + qa_probe"   2027-02-07 "Backend, qa_probe SDK, Maestro reproductions, GitHub issues; logsift"
milestone "P2 · v0.3 Kubernetes"           2027-03-28 "Helm, RBAC, network policies, kubeadm lab; qa-core"
milestone "P3 · v1.0 production"           2027-04-25 "QA on every PR, fix loop, GitOps, observability, supply chain"
milestone "P4 · showcase + CKA"            2027-05-23 "Real targets, demo video, CKA"

# ---- labels ----------------------------------------------------------------------------
label() { gh label create "$1" --repo "$REPO" --color "$2" --description "$3" --force >/dev/null; echo "  label: $1"; }
label runner        1f6feb "Python agent"
label bugzoo        d73a4a "Planted-bug Flutter app"
label control-app   8250df "Flutter macOS control app"
label infra         0e8a16 "CI, Docker, Terraform, Kubernetes"
label rust          dea584 "logsift / qa-core"
label spike         fbca04 "Time-boxed experiment; result goes in the devlog"
label docs          0075ca "Devlog, README, articles"
label planted-bug   b60205 "A bug hidden in bugzoo on purpose"
label this-week     5319e7 "Planned for the current week"

# ---- P0 issues -------------------------------------------------------------------------
M0="P0 · v0.1 agent + bugzoo"
URLS=()
issue() { # title, labels, body
  local url; url=$(gh issue create --repo "$REPO" --title "$1" --label "$2" --milestone "$M0" --body "$3")
  URLS+=("$url"); echo "  issue: $1"
}

issue "Spike A: Pixel over wireless adb + uiautomator2 + logcat" "spike,runner,this-week" \
"**Week 1.** Connect the Pixel with \`adb pair\` / \`adb connect\`, drive one screen with uiautomator2 (dump the hierarchy, tap one element), and pull logcat for the app's PID.

**Done when:** a short Python script taps a named button in any app and saves the hierarchy + logcat to \`runs/\` (gitignored). Result written in \`docs/devlog/2026-W48.md\`."

issue "Spike B: Ollama 3–4B vs 8B on one screen tree" "spike,runner,this-week" \
"**Week 1.** Take one recorded screen hierarchy and ask each model to \"find and tap Checkout\". Measure input tokens, seconds per step, and whether it picked the right element (10 tries each).

**Done when:** the comparison table is filled in the W48 devlog and one model is chosen as the default."

issue "Devlog 2026-W48 + first #ScoutBuild post" "docs,this-week" \
"**Week 1.** Fill \`docs/devlog/2026-W48.md\` from the template and post one visual on LinkedIn with #ScoutBuild."

issue "bugzoo: shop app skeleton (catalogue → cart → checkout)" "bugzoo" \
"**Week 2.** Minimal Flutter Android app with three screens and a fake API (local JSON or a tiny mock server).

**Done when:** \`flutter run\` on the Pixel goes from catalogue to a checkout confirmation."

issue "bugzoo: plant the first 5 bugs" "bugzoo,planted-bug" \
"**Week 2.** One of each: a crash (unhandled exception), an ANR (main-thread block), a failed request (500 on checkout), a dead button (no handler), a wrong total (rounding).

Record each in \`apps/bugzoo/BUGS.md\` (id, trigger, expected evidence) — this is the answer key Scout is scored against."

issue "Runner: explore a use case, save screenshot + hierarchy + logcat per step" "runner" \
"**Week 2.** Loop: dump hierarchy → compress → ask the model for the next action → act → record. Stop on goal, max steps, or crash.

**Done when:** \`scout run --app <pkg> --goal \"...\"\` produces \`runs/<id>/step-NN/{screen.png,tree.json}\` and \`logcat.txt\`."

issue "Runner: crash and ANR detection from logcat" "runner" \
"**Week 2.** Detect \`FATAL EXCEPTION\`, Flutter error output and ANRs for the target PID; stop the run and mark the step.

**Done when:** the planted crash and ANR in bugzoo are flagged with their stack traces."

issue "Control app (macOS) skeleton: start a run, watch steps live" "control-app" \
"**Week 3.** Flutter macOS app: pick device + app + goal, start a run, stream steps (screenshot + action) as they happen."

issue "CI: analyze, test, format for both Flutter apps" "infra" \
"**Week 3.** GitHub Actions on every push/PR: \`flutter analyze\`, \`dart format --set-exit-if-changed\`, \`flutter test\` for bugzoo and control. Add the badge to the README."

issue "Runner as a multi-stage Docker image" "infra,runner" \
"**Week 3.** Small final image (python-slim + adb), non-root user, built in CI. Connects to the Pixel over the network."

issue "Report: Markdown/HTML with screen recording" "runner" \
"**Week 4.** Per run: goal, steps with screenshots, findings with logcat excerpt and stack trace, and an \`adb screenrecord\` video."

issue "Release workflow: macOS app → Releases, APK → Firebase App Distribution, image → GHCR" "infra" \
"**Week 4.** Triggered by a \`v*\` tag. No manual steps."

issue "Tag v0.1.0" "docs" \
"**Week 4 (by Dec 20).** Scout finds at least 3 of the 5 planted bugs on the Pixel; tagging publishes all three artifacts. Release notes + phase devlog."

# ---- project board ------------------------------------------------------------------------
NUM=$(gh project create --owner "$OWNER" --title "Scout" --format json --jq .number)
gh project link "$NUM" --owner "$OWNER" --repo "$REPO" >/dev/null
gh project edit "$NUM" --owner "$OWNER" --visibility PUBLIC >/dev/null
for u in "${URLS[@]}"; do gh project item-add "$NUM" --owner "$OWNER" --url "$u" >/dev/null; done
echo "  board: https://github.com/users/$OWNER/projects/$NUM (${#URLS[@]} issues added)"

echo
echo "Done. Two things to do in the browser (2 min):"
echo "  1. Board → View → Layout: Board. In the Status field, rename Todo → Backlog and add 'This week' before 'In progress'."
echo "  2. Drag the 3 issues labelled 'this-week' into 'This week'. Then put the board link in README.md."
