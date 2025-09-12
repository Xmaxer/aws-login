# AWS Login Script

A convenient shell script for managing AWS SSO logins with interactive account and role selection using `fzf`.

## Features

- Interactive AWS SSO session selection
- Account and role selection with fuzzy finding
- Profile creation and management
- Region selection

## Prerequisites

- Zsh shell

## Quick Installation

Install the script with a single command:

```bash
curl -sSL https://raw.githubusercontent.com/Xmaxer/aws-login/main/install.sh | bash
```

This will:
1. Download the `aws-login.sh` script
2. Install it to `~/.aws-login/`
3. Add it to your `.zshrc` file
4. Source it in your current session
5. Create a backup of your existing `.zshrc`

## Manual Installation

1. Download the script:
   ```bash
   curl -sSL https://raw.githubusercontent.com/Xmaxer/aws-login/main/aws-login.sh -o ~/.aws-login/aws-login.sh
   chmod +x ~/.aws-login/aws-login.sh
   ```

2. Add to your `.zshrc`:
   ```bash
   echo 'source ~/.aws-login/aws-login.sh' >> ~/.zshrc
   ```

3. Reload your shell:
   ```bash
   source ~/.zshrc
   ```

## Usage

### Main Command

```bash
aws-login
```

This interactive command will guide you through:
1. Selecting an AWS SSO session (if multiple are configured)
2. Choosing an AWS account
3. Selecting a role within that account
4. Picking a region for the profile

### Available Functions

- `aws-login` - Begins the interactive login process

## First Time Setup

Before using the script, you need to configure AWS SSO:

```bash
aws sso configure
```

Follow the prompts to set up your SSO session with:
- SSO start URL
- SSO region
- Default client region
- Default output format

## How It Works

1. **Session Selection**: Choose from configured SSO sessions
2. **Authentication**: Automatically handles SSO login
3. **Account Selection**: Browse available accounts with fuzzy search
4. **Role Selection**: Choose from available roles in the selected account
5. **Region Selection**: Pick your preferred AWS region
6. **Profile Creation**: Automatically creates and activates the profile

## Profile Management

The script creates profiles with the naming convention:
```
<session>/<account-name>/<role>/<region>
```

Special characters are replaced with hyphens for compatibility.

## Environment Variables

The script manages the `AWS_PROFILE` environment variable and saves it to `~/.zsh_env` for persistence across sessions.

## Dependencies

The script will automatically prompt to install missing dependencies:
- `fzf` - For interactive selection menus
- `jq` - For JSON processing
- `aws` - AWS CLI v2

On macOS with Homebrew, missing dependencies will be installed automatically with user confirmation.

## Troubleshooting

### Script not found after installation
Restart your terminal or run:
```bash
source ~/.zshrc
```

### Permission denied
Make sure the script is executable:
```bash
chmod +x ~/.aws-login/aws-login.sh
```

### AWS CLI not configured
Run the initial SSO configuration:
```bash
aws sso configure
```

### Missing dependencies
Install manually:
```bash
# macOS with Homebrew
brew install fzf jq awscli

# Ubuntu/Debian
sudo apt-get install jq
# For fzf and AWS CLI, follow their respective installation guides
```

## Uninstallation

To remove the script:

1. Remove the source line from `.zshrc`:
   ```bash
   sed -i '/source.*aws-login\.sh/d' ~/.zshrc
   ```

2. Remove the installation directory:
   ```bash
   rm -rf ~/.aws-login
   ```

3. Remove environment file (optional):
   ```bash
   rm -f ~/.zsh_env
   ```

## Contributing

Feel free to submit issues and pull requests to improve the script.

## License

This project is open source and available under the MIT License.
