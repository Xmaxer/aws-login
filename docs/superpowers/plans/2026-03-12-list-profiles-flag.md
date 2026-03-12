# --list-profiles Flag Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `--list-profiles` flag to `aws-login` that prints all profiles from `~/.aws/config` grouped by SSO session, then exits.

**Architecture:** Early argument check at the top of `aws-login()`, before dependency checks. A new inner helper `aws-list-all-profiles` reads `~/.aws/config` with `awk` and prints sessions with their profiles indented beneath, using the existing color helpers. Returns immediately after printing.

**Tech Stack:** Bash/Zsh, awk, existing color helper functions in `aws-login.sh`

---

## Chunk 1: Implement --list-profiles

### Task 1: Add aws-list-all-profiles helper and --list-profiles argument check

**Files:**
- Modify: `aws-login.sh`

- [ ] **Step 1: Add the `aws-list-all-profiles` inner function**

  Insert this function alongside the other `aws-*` inner helpers (after line 51, after `aws-list-sessions`):

  ```bash
  aws-list-all-profiles() {
      [ -f ~/.aws/config ] || { print_warning "No ~/.aws/config found."; return 1; }

      # Collect all sessions
      local sessions
      sessions=$(grep -o '\[sso-session [^]]*\]' ~/.aws/config | sed 's/\[sso-session \(.*\)\]/\1/')

      if [ -z "$sessions" ]; then
          print_warning "No SSO sessions found in ~/.aws/config."
          return 0
      fi

      while IFS= read -r session; do
          echo -e "${PURPLE}$session${NC}"
          # Find all profiles whose sso_session matches this session
          awk -v session="$session" '
              /^\[profile / {
                  p=$0
                  gsub(/^\[profile |\]$/, "", p)
              }
              /^\[/ && !/^\[profile / { p="" }
              /^sso_session = / && $3==session && p!="" {
                  print "  " p
              }
          ' ~/.aws/config
          echo ""
      done <<< "$sessions"
  }
  ```

- [ ] **Step 2: Add the early argument check**

  Insert this block at the very start of `aws-login()`, before the color variable definitions (line 2), so it runs before any dependency checks:

  ```bash
  if [[ "$1" == "--list-profiles" ]]; then
      # Define colors inline since they haven't been set yet
      PURPLE='\033[0;35m'
      NC='\033[0m'
      aws-list-all-profiles
      return $?
  fi
  ```

  > Note: Because the color variables and inner functions are defined later in the function body, the `--list-profiles` branch must either define colors inline (as above) OR be placed after the color/helper definitions. Place it **after** all inner function definitions and color vars but **before** the dependency checks (`command -v fzf` etc.) to keep it clean. In that case, the inline color definitions are not needed.

  **Preferred placement:** After the last inner helper (`aws-config-add-to-section`, line ~179) and before the `fzf` dependency check (line ~181):

  ```bash
  if [[ "$1" == "--list-profiles" ]]; then
      aws-list-all-profiles
      return $?
  fi
  ```

- [ ] **Step 3: Manual smoke test**

  Source the updated script and run:
  ```bash
  source aws-login.sh
  aws-login --list-profiles
  ```

  Expected output (example):
  ```
  my-sso-session
    login-my-sso-session
    my-sso-session/MyAccount/AdministratorAccess/eu-west-1

  another-session
    login-another-session
  ```

  Verify:
  - Sessions are listed as purple headers
  - Profiles are indented under their session
  - Script exits after printing (does not proceed to fzf/dependency checks)
  - If `~/.aws/config` doesn't exist, a warning is shown and script exits cleanly

- [ ] **Step 4: Commit**

  ```bash
  git add aws-login.sh
  git commit -m "feat: add --list-profiles flag to list all profiles grouped by session"
  ```
