# Telegram Bot Setup for Minecraft Timer

This guide will help you set up Telegram authentication for the Minecraft timer.

## Step 1: Create a Telegram Bot

1. Open Telegram and search for **@BotFather**
2. Start a chat and send: `/newbot`
3. Follow the instructions:
   - Choose a name for your bot (e.g., "Minecraft Timer")
   - Choose a username (e.g., "YourFamilyMinecraftBot")
4. BotFather will give you a **Bot Token** like: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`
5. **Save this token** - you'll need it for the configuration

## Step 2: Get Your Chat ID

### Option A: Using Your Bot (Recommended)

1. Search for your bot in Telegram by the username you created
2. Start a chat with your bot
3. Send any message to it (e.g., "hello")
4. Open this URL in your browser (replace `YOUR_BOT_TOKEN` with your actual token):
   ```
   https://api.telegram.org/botYOUR_BOT_TOKEN/getUpdates
   ```
5. Look for `"chat":{"id":` in the response
6. The number after `"id":` is your **Chat ID** (e.g., `123456789`)

### Option B: Using a Group Chat (For Family)

If you want both parents to receive notifications:

1. Create a Telegram group
2. Add your bot to the group (search by bot username)
3. Send a message in the group
4. Open the same URL as above in your browser
5. Look for the group's chat ID (it will be a **negative number** like `-987654321`)

## Step 3: Configure the Script

Edit the `minertimer.sh` file and add your credentials at the top:

```bash
# TELEGRAM CONFIGURATION
TELEGRAM_BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
TELEGRAM_CHAT_ID="123456789"  # or "-987654321" for group
ENABLE_TELEGRAM_AUTH=true
```

## Step 4: Test It

You can test the Telegram message without waiting for the timer:

```bash
# Test sending a message
curl -X POST "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/sendMessage" \
  -d "chat_id=<YOUR_CHAT_ID>" \
  -d "text=Test message from Minecraft Timer!"
```

If you receive the message in Telegram, it's working!

## How It Works

1. When Minecraft time limit is reached, the script:
   - Generates a random 4-digit code
   - Sends a message to your Telegram with:
     - Computer name
     - Current time
     - Minutes played
     - The 4-digit approval code

2. Your child sees a popup asking for the code
3. They call/text you to request more time
4. You check Telegram, see the request, and decide
5. If approved, you tell them the 4-digit code
6. They enter the code and get 30 more minutes
7. If they fail 3 times, they can use admin password as fallback

## Example Telegram Message

```
🎮 MINECRAFT TIME REQUEST

💻 Computer: iMac-Kids
⏰ Time: 15:30
⏱️  Played today: 30 minutes
➕ Extension: 30 minutes

🔐 Approval Code: 7382
```

## Troubleshooting

**No message received?**
- Check bot token is correct
- Check chat ID is correct (remember the minus sign for groups)
- Make sure you've sent at least one message to the bot first

**Want to disable Telegram?**
- Set `ENABLE_TELEGRAM_AUTH=false` in the script
- It will fall back to admin password only

**Want to use only Telegram (no password fallback)?**
- Set `REQUIRE_ADMIN_PASSWORD=false` in the script
- Only the code will work (more strict)

## Security Notes

- Keep your bot token secret (don't share publicly)
- The code is only valid for 5 minutes (3 attempts)
- Each request generates a new random code
- Codes cannot be reused
