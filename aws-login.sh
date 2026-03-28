aws-login() {
  # Colors for output
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  PURPLE='\033[0;35m'
  NC='\033[0m' # No Color

  # Function to print colored output
  print_status() {
      echo -e "${BLUE}[INFO]${NC} $1"
  }

  print_success() {
      echo -e "${GREEN}[SUCCESS]${NC} $1"
  }

  print_warning() {
      echo -e "${YELLOW}[WARNING]${NC} $1"
  }

  print_error() {
      echo -e "${RED}[ERROR]${NC} $1"
  }

  print_debug() {
      echo -e "${CYAN}[DEBUG]${NC} $1"
  }

  print_highlight() {
      echo -e "${PURPLE}[HIGHLIGHT]${NC} $1"
  }

  aws-access-token() {
      # Get the most recently modified cache file (excluding botocore files)
      local latest_cache=$(ls -1t ~/.aws/sso/cache/* 2>/dev/null | grep -v botocore | head -n 1)
      if [ -z "$latest_cache" ]; then
          return 1
      fi
      cat "$latest_cache" | jq -r "{accessToken} | to_entries | select(.[].value != null)[0].value"
  }
  aws-list-accounts() {
      aws sso list-accounts --access-token "$(aws-access-token)" --output json
  }
  aws-list-account-roles() {
      aws sso list-account-roles --access-token "$(aws-access-token)" --account-id "$1" --output json
  }
  aws-list-sessions() {
      [ -f ~/.aws/config ] && grep -o '\[sso-session [^]]*\]' ~/.aws/config | sed 's/\[sso-session \(.*\)\]/\1/'
      echo "Create new session"
  }
  aws-list-all-profiles() {
      [ -f ~/.aws/config ] || { print_warning "No ~/.aws/config found."; return 1; }

      local sessions
      sessions=$(grep -o '\[sso-session [^]]*\]' ~/.aws/config | sed 's/\[sso-session \(.*\)\]/\1/')

      if [ -z "$sessions" ]; then
          print_warning "No SSO sessions found in ~/.aws/config."
          return 0
      fi

      while IFS= read -r session; do
          echo -e "${PURPLE}$session${NC}"
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
  aws-delete-profile() {
      [ -f ~/.aws/config ] || return 0
      awk -v profile="$1" '$0 ~ "^\\[profile " {s=($0=="[profile " profile "]")} $0 ~ "^\\[" && $0 !~ "^\\[profile " {s=0} !s' ~/.aws/config >~/.aws/config.tmp && mv ~/.aws/config.tmp ~/.aws/config
  }
  aws-save-profile() {
      print_highlight "Saving profile: $1"
      export AWS_PROFILE="$1"
      awk -v profile="$AWS_PROFILE" '{gsub(/export AWS_PROFILE=.*/, "export AWS_PROFILE=" profile)} 1' ~/.zsh_env >~/.zsh_env.tmp && mv ~/.zsh_env.tmp ~/.zsh_env
      print_success "Profile saved and exported: $1"
  }
  aws-login-profile() {
      if aws sso login --profile "$1"; then
          aws-save-profile "$1"
          return 0
      else
          print_error "SSO login failed"
          return 1
      fi
  }
  aws-list-regions() {
      print_debug "Attempting to fetch regions dynamically from AWS..." >&2
      if dynamic_regions=$(aws account list-regions --output json --region-opt-status-contains ENABLED --region-opt-status-contains ENABLED_BY_DEFAULT 2>/dev/null | jq -r ".Regions[].RegionName" 2>/dev/null) && [ -n "$dynamic_regions" ]; then
          print_success "Successfully retrieved $(echo "$dynamic_regions" | wc -l) regions dynamically from AWS" >&2
          echo "$dynamic_regions"
      else
          print_warning "Dynamic region retrieval failed, falling back to hardcoded region list" >&2
          print_debug "This could be due to insufficient permissions or network issues" >&2
          AWS_REGIONS=(
              "us-east-1"
              "us-east-2"
              "us-west-1"
              "us-west-2"
              "af-south-1"
              "ap-east-1"
              "ap-south-1"
              "ap-south-2"
              "ap-southeast-1"
              "ap-southeast-2"
              "ap-southeast-3"
              "ap-southeast-4"
              "ap-northeast-1"
              "ap-northeast-2"
              "ap-northeast-3"
              "ca-central-1"
              "ca-west-1"
              "eu-central-1"
              "eu-central-2"
              "eu-west-1"
              "eu-west-2"
              "eu-west-3"
              "eu-south-1"
              "eu-south-2"
              "eu-north-1"
              "il-central-1"
              "me-south-1"
              "me-central-1"
              "sa-east-1"
          )
          print_status "Using ${#AWS_REGIONS[@]} hardcoded regions" >&2
          for region in "${AWS_REGIONS[@]}"; do
              echo "$region"
          done
      fi
  }
  aws-list-profiles-for-session() {
      [ -f ~/.aws/config ] && awk -v session="$1" '$0 ~ "^\\[profile " {p=$0; gsub("^\\[profile |\\]$","",p)} $0 ~ "^sso_session = " && $3==session && p !~ "^login" {print p}' ~/.aws/config
      echo "Create new profile"
  }
  aws-get-session-region() {
      [ -f ~/.aws/config ] || return 0
      awk -v session="$1" '
          $0 ~ "^\\[sso-session " {
              s=$0
              gsub("^\\[sso-session |\\]$","",s)
          }
          $0 ~ "^\\[" && $0 !~ "^\\[sso-session " {
              s=""
          }
          s==session && $0 ~ "^sso_region = " {
              print $3
              exit
          }
      ' ~/.aws/config
  }

  aws-config-add-to-section() {
      AWS_PROFILE="$1"
      PROPERTY_NAME="$2"
      PROPERTY_VALUE="$3"
      CONFIG_FILE="${4:-$HOME/.aws/config}"

      property_exists=$(awk -v profile="$AWS_PROFILE" -v prop="$PROPERTY_NAME" '
  BEGIN { in_target_section = 0; found_property = 0 }
  $0 ~ "^\\[profile " {
      if ($0=="[profile " profile "]") {
          in_target_section = 1
      } else {
          in_target_section = 0
      }
  }
  $0 ~ "^\\[" && $0 !~ "^\\[profile " {
      in_target_section = 0
  }
  in_target_section && $0 ~ "^" prop " =" {
      found_property = 1
      exit
  }
  END { print found_property }
  ' "$CONFIG_FILE")

      if [ "$property_exists" = "0" ]; then
          awk -v profile="$AWS_PROFILE" -v prop="$PROPERTY_NAME" -v value="$PROPERTY_VALUE" '
      $0 ~ "^\\[profile " {
          if ($0=="[profile " profile "]") {
              print
              print prop " = " value
              next
          }
      }
      { print }
      ' "$CONFIG_FILE" >"$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
          print_success "Added $PROPERTY_NAME to profile '$AWS_PROFILE'"
      else
          print_warning "$PROPERTY_NAME already exists in profile '$AWS_PROFILE', skipping"
      fi
  }

  aws-manage-profiles() {
      [ -f ~/.aws/config ] || { print_warning "No ~/.aws/config found."; return 0; }

      local last_status=""
      while true; do
          local profiles
          profiles=$(awk '/^\[profile / {
              p=$0
              gsub(/^\[profile |\]$/, "", p)
              if (p !~ /^login-/) print p
          }' ~/.aws/config 2>/dev/null)

          if [ -z "$profiles" ]; then
              print_warning "No profiles to manage."
              return 0
          fi

          local header="[Enter] delete  [Esc] quit"
          [ -n "$last_status" ] && header="${last_status} | ${header}"

          local selected
          selected=$(echo "$profiles" | fzf \
              --border=top \
              --border-label="Manage AWS Profiles" \
              --header="$header" \
              --prompt="Select profile to delete > " \
              -0)

          [ -z "$selected" ] && break

          read "confirm?Are you sure you want to delete profile '$selected'? [y/N]: "
          if [[ "$confirm" =~ ^[Yy]$ ]]; then
              aws-delete-profile "$selected"
              last_status="Deleted: $selected"
              print_success "Profile '$selected' deleted."
          else
              last_status="Cancelled: $selected"
          fi
      done
  }

    if [[ "$1" == "--list-profiles" ]]; then
        aws-list-all-profiles
        return $?
    fi

    if [[ "$1" == "--manage-profiles" ]]; then
        if ! command -v fzf &>/dev/null; then
            print_error "fzf is required for --manage-profiles"
            return 1
        fi
        aws-manage-profiles
        return $?
    fi

    if ! command -v fzf &>/dev/null; then
        print_warning "fzf is required to run this script. Do you want to install it now? [y/n]"
        read -r choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            print_status "Installing fzf..."
            brew install fzf
            print_success "fzf installed successfully"
        else
            print_error "fzf is required. Exiting."
            return 1
        fi
    fi

    if ! command -v jq &>/dev/null; then
        print_warning "jq is required to run this script. Do you want to install it now? [y/n]"
        read -r choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            print_status "Installing jq..."
            brew install jq
            print_success "jq installed successfully"
        else
            print_error "jq is required. Exiting."
            return 1
        fi
    fi

    if ! command -v aws &>/dev/null; then
        print_error "aws-cli is required to run this script."
        print_status "Go here to install it: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        return 1
    fi

    [ -f ~/.zsh_env ] || touch ~/.zsh_env
    grep -q "export AWS_PROFILE=" ~/.zsh_env || echo "export AWS_PROFILE=" >>~/.zsh_env

    profileName="login-$sessionName"
    authRegion="eu-west-1"

    # Check if authenticated by verifying both STS access and valid SSO token
    isAuthenticated=1
    if aws sts get-caller-identity >/dev/null 2>&1; then
        # Also verify we have a valid SSO token if using SSO
        if [ -n "$AWS_PROFILE" ] && [ -f ~/.aws/config ]; then
            # Check if current profile uses SSO
            uses_sso=$(awk -v profile="$AWS_PROFILE" '$0 ~ "^\\[profile " {s=($0=="[profile " profile "]")} $0 ~ "^\\[" && $0 !~ "^\\[profile " {s=0} s && $0 ~ "^sso_session = " {print "yes"; exit}' ~/.aws/config)
            if [ "$uses_sso" = "yes" ]; then
                # Verify SSO token exists and is valid
                if aws-access-token >/dev/null 2>&1; then
                    isAuthenticated=0
                fi
            else
                # Non-SSO profile, STS check is sufficient
                isAuthenticated=0
            fi
        else
            isAuthenticated=0
        fi
    fi

    SELECTED_SESSION=""

    beginSessionCreation() {
        print_status "Creating new SSO session..."
        print_status "This will configure only the SSO session (no account/role selection yet)."

        # Ensure .aws directory exists
        mkdir -p ~/.aws

        # Run the interactive SSO session configuration (no account/role selection)
        aws configure sso-session

        # Check if configuration was successful
        if [ $? -ne 0 ]; then
            print_error "SSO session configuration failed."
            return 1
        fi

        print_success "SSO session created successfully"
        return 0
    }

    beginSessionSelection() {
        print_status "Logging out and clearing SSO cache..."
        aws sso logout && rm -rf ~/.aws/sso/cache

        while true; do
            print_status "Fetching available SSO sessions..."
            sessions=$(aws-list-sessions)

            session=$(echo "$sessions" | fzf -0 --border=top --border-label="Pick a session to use, or create a new one")

            if [ -z "${session}" ]; then
                print_error "No session selected"
                return 1
            fi

            if [[ "$session" == "Create new session" ]]; then
                if ! beginSessionCreation; then
                    print_warning "Returning to session selection..."
                    continue
                fi
                # Loop back to session selection to pick the newly created session
                continue
            fi

            # Valid session selected, break out of loop
            break
        done

        print_success "Selected session: $session"
        profileName="login-$session"
        sessionRegion=$(aws-get-session-region "$session")

        print_debug "Session region retrieved: '$sessionRegion'"
        print_debug "Session region line count: $(echo "$sessionRegion" | wc -l)"

        print_status "Creating temporary login profile..."
        aws-delete-profile "$profileName" && {
            cat >> ~/.aws/config <<EOF
[profile $profileName]
sso_session = $session
region = $sessionRegion
EOF
        }

        print_status "Initiating SSO login..."
        if ! aws-login-profile "$profileName"; then
            print_error "Failed to authenticate with session: $session"
            return 1
        fi

        SELECTED_SESSION="$session"
        return 0
    }

    beginProfileCreation() {
        print_status "Creating new AWS profile..."

        # Prefer session passed as argument; fall back to deriving from $AWS_PROFILE
        if [ -n "$1" ]; then
            selectedSession="$1"
        elif [ -f ~/.aws/config ]; then
            selectedSession=$(awk -v profile="$AWS_PROFILE" '$0 ~ "^\\[profile " {s=($0=="[profile " profile "]")} $0 ~ "^\\[" && $0 !~ "^\\[profile " {s=0} s && $0 ~ "^sso_session = " {print $3; exit}' ~/.aws/config)
        fi
        if [ -z "${selectedSession}" ]; then
            print_error "No session associated to profile was found"
            return 1
        fi

        print_status "Fetching available AWS accounts..."
        accounts_json=$(aws-list-accounts 2>/dev/null)

        if [ -z "$accounts_json" ] || ! echo "$accounts_json" | jq -e '.accountList' >/dev/null 2>&1; then
            print_warning "SSO access token is invalid or expired. Re-authenticating with session: $selectedSession..."
            if ! aws sso login --sso-session "$selectedSession"; then
                print_error "Re-authentication failed"
                return 1
            fi
            accounts_json=$(aws-list-accounts)
        fi

        accountName=$(echo "$accounts_json" | jq -r ".accountList[].accountName" | fzf -0 --border=top --border-label="Choose the AWS account to use")

        if [ -z "${accountName}" ]; then
            print_error "No account selected, quitting"
            return 1
        fi

        accountId=$(echo "$accounts_json" | jq -r --arg accountName "$accountName" '.accountList[] | select(.accountName==$accountName).accountId')

        print_success "Selected account: $accountName ($accountId)"

        aws-config-add-to-section $AWS_PROFILE sso_account_id "$accountId"
        aws-config-add-to-section $AWS_PROFILE sso_role_name AdministratorAccess

        print_status "Fetching available roles for account: $accountName"
        role=$(aws-list-account-roles $accountId | jq -r ".roleList[].roleName" | fzf -0 --border=top --border-label="Choose the role to use within $accountName")

        if [ -z "${role}" ]; then
            print_error "No role selected, quitting"
            return 1
        fi

        print_success "Selected role: $role"

        region=$(aws-list-regions | fzf -0 --border=top --border-label="Choose a region for the profile")

        if [ -z "${region}" ]; then
            print_error "No region selected, quitting"
            return 1
        fi

        print_success "Selected region: $region"

        profileName="$selectedSession/$accountName/$role/$region"
        profileName="${profileName//[^a-zA-Z0-9\/]/-}"

        print_status "Creating profile: $profileName"
        aws-delete-profile "$profileName" && cat >> ~/.aws/config <<EOF
[profile $profileName]
sso_session = $selectedSession
sso_account_id = $accountId
sso_role_name = $role
region = $region
output = json
EOF

        aws-save-profile "$profileName"
    }

    beginProfileSelection() {
        print_status "Loading profiles for session: $1"
        selectedProfile=$(aws-list-profiles-for-session "$1" | fzf -0 --border=top --border-label="(Session: $1) Choose an existing profile, or create a new one")
        if [[ "$selectedProfile" == "Create new profile" ]]; then
            beginProfileCreation "$1"
        else
            print_success "Selected existing profile: $selectedProfile"
            aws-save-profile "$selectedProfile"
        fi
    }

    if [[ "$isAuthenticated" == 0 ]]; then
        print_success "Already authenticated with AWS"
        if [ -f ~/.aws/config ]; then
            selectedSession=$(awk -v profile="$AWS_PROFILE" '$0 ~ "^\\[profile " {s=($0=="[profile " profile "]")} $0 ~ "^\\[" && $0 !~ "^\\[profile " {s=0} s && $0 ~ "^sso_session = " {print $3; exit}' ~/.aws/config)
        fi

        if [ -z "${selectedSession}" ]; then
            print_error "$selectedSession is not a valid session"
            return 1
        fi

        print_status "Currently authenticated with session: $selectedSession"
        read "switchAccounts?Would you like to switch AWS sessions? [y/N]: "
        if [[ "$switchAccounts" =~ ^[Yy]$ ]]; then
            if ! beginSessionSelection; then
                print_error "Session selection failed"
                return 1
            fi
            selectedSession="$SELECTED_SESSION"
        fi

        beginProfileSelection "$selectedSession"
    else
        print_warning "Not currently authenticated with AWS"
        if ! beginSessionSelection; then
            print_error "Session selection and authentication failed"
            return 1
        fi
        selectedSession="$SELECTED_SESSION"
        beginProfileSelection "$selectedSession"
    fi

    print_success "AWS login process completed successfully!"
    print_status "Current AWS profile: $AWS_PROFILE"
    source ~/.zsh_env
}

[ ! -f ~/.zsh_env ] || source ~/.zsh_env
