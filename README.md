# Minecraft Timer for macOS

A parental control system for Minecraft Java Edition on macOS that limits daily play time with remote approval via Telegram.

## Features

- ⏱️ **Daily Time Limits** - Set different limits for weekdays and weekends
- 📱 **Telegram Authentication** - Parents approve time extensions remotely via Telegram bot
- 🔐 **Fallback Password** - Admin password option when Telegram is unavailable
- ⏰ **Smart Warnings** - 5-minute and 1-minute warnings before time expires
- 🎮 **Kid-Friendly UI** - Clean GUI dialogs with clear messages
- 🔄 **Daily Reset** - Time counters reset automatically at midnight
- 💻 **Multi-Extension Support** - Grant multiple extensions throughout the day

## How It Works

1. **Time Limit Reached**: When daily play time expires, a popup appears
2. **Request More Time**: Child clicks "Ask for More Time"
3. **Telegram Notification**: Parents receive a message with a 4-digit code
4. **Code Entry**: Child enters the code (3 attempts)
5. **Time Granted**: If correct, child gets 30 more minutes
6. **Fallback Option**: If code fails, admin password can be used

### Example Telegram Message

```
🎮 MINECRAFT TIME REQUEST

💻 Computer: iMac-Kids
⏰ Time: 15:30
⏱️  Played today: 30 minutes
➕ Extension: 30 minutes

🔐 Approval Code: 7382
```

## Installation

### 1. Download or Clone

```bash
git clone https://github.com/yourusername/minecraft-timer.git
cd minecraft-timer
```

### 2. Configure Settings

```bash
# Copy the example config
cp minertimer.config.example minertimer.config

# Edit the config file
nano minertimer.config
```

**Required settings:**
- `TIME_LIMIT` - Weekday limit in seconds (default: 1800 = 30 min)
- `WEEKEND_TIME_LIMIT` - Weekend limit in seconds (default: 3600 = 60 min)
- `EXTENSION_TIME` - Extension time per request (default: 1800 = 30 min)
- `TELEGRAM_BOT_TOKEN` - Your Telegram bot token (see setup below)
- `TELEGRAM_CHAT_ID` - Your Telegram chat/group ID

### 3. Set Up Telegram Bot (Optional but Recommended)

See [TELEGRAM_SETUP.md](TELEGRAM_SETUP.md) for detailed instructions.

**Quick steps:**
1. Message [@BotFather](https://t.me/botfather) on Telegram
2. Create a new bot with `/newbot`
3. Copy the bot token
4. Message your bot or add it to a family group
5. Get your chat ID from: `https://api.telegram.org/bot<TOKEN>/getUpdates`
6. Add both to `minertimer.config`

### 4. Install

```bash
# Make sure you're in the project directory
cd /path/to/minecraft-timer

# Run the installer with sudo
sudo ./install_minertimer.sh
```

### 5. Verify Installation

```bash
sudo launchctl list | grep com.soferio.minertimer_daily_timer
```

You should see a line with a process ID.

## Configuration

All settings are in `minertimer.config`:

| Setting | Default | Description |
|---------|---------|-------------|
| `TIME_LIMIT` | 1800 | Weekday time limit (seconds) |
| `WEEKEND_TIME_LIMIT` | 3600 | Weekend time limit (seconds) |
| `EXTENSION_TIME` | 1800 | Extension time per approval (seconds) |
| `DISPLAY_5_MIN_WARNING` | true | Show 5-minute warning |
| `DISPLAY_1_MIN_WARNING` | true | Show 1-minute warning |
| `REQUIRE_ADMIN_PASSWORD` | true | Enable password fallback |
| `ENABLE_TELEGRAM_AUTH` | true | Enable Telegram authentication |
| `TELEGRAM_BOT_TOKEN` | "" | Your Telegram bot token |
| `TELEGRAM_CHAT_ID` | "" | Your Telegram chat ID |

## Testing

Test the authentication flow without waiting for the timer:

```bash
./test_telegram.sh
```

This will:
- Send a real Telegram message with a code
- Show all GUI dialogs
- Let you test correct/incorrect codes
- Test the fallback password option

## Usage

### For Parents

**Approve Time Extension:**
1. Receive Telegram message with 4-digit code
2. Decide if you want to approve
3. Tell child the code (or don't!)

**Remotely Monitor:**
- All requests show computer name, time, and current play time
- Works from anywhere you have Telegram access
- Full audit trail in Telegram chat

### For Kids

**When Time Expires:**
1. Popup appears: "Time Limit Reached"
2. Click "Ask for More Time"
3. Message is sent to parents
4. Enter the 4-digit code parents give you
5. Get 30 more minutes!

**Tips:**
- You have 3 attempts to enter the code
- If code doesn't work, ask a parent for the admin password
- Check warnings - you get alerts at 5 min and 1 min remaining

## Uninstallation

```bash
sudo ./uninstall_minertimer.sh
```

Or manually:

```bash
# Stop the service
sudo launchctl unload /Library/LaunchDaemons/com.soferio.minertimer_daily_timer.plist

# Remove files
sudo rm /Library/LaunchDaemons/com.soferio.minertimer_daily_timer.plist
sudo rm -rf /Users/Shared/minertimer
sudo rm -rf /var/lib/minertimer
```

## Troubleshooting

### Telegram messages not received?

1. Check bot token and chat ID are correct
2. Make sure you've sent at least one message to your bot
3. For groups, check the chat ID has a minus sign (e.g., `-123456789`)
4. Test with: `./test_telegram.sh`

### Timer not running?

```bash
# Check if daemon is running
sudo launchctl list | grep com.soferio.minertimer_daily_timer

# Check logs
tail -f /var/log/system.log | grep minertimer
```

### Minecraft not closing?

- Make sure Minecraft Java Edition is running (not Bedrock)
- Check the process name matches "Minecraft" in Activity Monitor

### Need to stop timer temporarily?

```bash
# Unload (stop)
sudo launchctl unload /Library/LaunchDaemons/com.soferio.minertimer_daily_timer.plist

# Load (start)
sudo launchctl load -w /Library/LaunchDaemons/com.soferio.minertimer_daily_timer.plist
```

## Files

- `minertimer.sh` - Main timer script
- `minertimer.config.example` - Example configuration file
- `minertimer.config` - Your actual config (not in git, copy from .example)
- `install_minertimer.sh` - Installation script
- `uninstall_minertimer.sh` - Uninstallation script
- `test_telegram.sh` - Test script for authentication flow
- `com.soferio.minertimer_daily_timer.plist` - LaunchDaemon configuration
- `TELEGRAM_SETUP.md` - Detailed Telegram setup guide

## Security Notes

- Config file (`minertimer.config`) is in `.gitignore` - never commit it
- Config file permissions are set to `600` (owner read/write only)
- Telegram bot token should be kept secret
- Admin password uses macOS's native authentication

## Requirements

- macOS (tested on macOS 10.15+)
- Minecraft Java Edition
- Administrator account for installation
- Telegram account (optional, for remote approval)

## License

MIT License - see [LICENSE](LICENSE) file for details

Copyright (c) 2025 Linas Purinis

## Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## Credits

- Original concept and foundation by Soferio Pty Limited
- Telegram authentication and remote approval system by Linas Purinis
- Enhanced parental controls and modern UI improvements
