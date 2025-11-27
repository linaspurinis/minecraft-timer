# Button-Based Approval System

## Overview
The Minecraft Timer now uses **one-tap Telegram button approval** instead of code entry. Parents can approve or deny time extension requests with a single button tap.

## What Changed

### Before
- Parent received 4-digit code via Telegram
- Child had to enter code manually (3 attempts)
- More steps, more friction

### After
- Parent receives message with **[✅ Approve]** and **[❌ Deny]** buttons
- One tap = instant approval or denial
- Child just waits (no code entry needed)
- Message updates to show "APPROVED" or "DENIED" status

## Technical Implementation

### Key Components
1. **Inline Keyboard Buttons**: Telegram inline_keyboard with callback_data
2. **Long Polling**: Script polls Telegram API every 5 seconds for button clicks
3. **Python JSON Parsing**: Robust parsing of callback data (handles Unicode/emojis)
4. **Webhook Clearing**: Ensures polling mode is active (not webhook mode)
5. **Unique Request IDs**: Each request has unique ID to prevent conflicts

### Flow
1. Child clicks "Ask for More Time"
2. Script sends Telegram message with inline keyboard buttons
3. Script disables webhooks and starts polling for updates
4. Parent clicks button in Telegram
5. Script receives callback_query, validates REQUEST_ID
6. Script acknowledges callback and updates message
7. Time granted or denied accordingly

### Error Handling
- Timeout after 5 minutes (60 polls × 5 seconds)
- Fallback to admin password if denied/timeout
- Skips old/unrelated callbacks
- Error detection for webhook conflicts

## Files Modified
- `minertimer.sh` - Main script with button approval logic
- `test_telegram.sh` - Test script updated for buttons
- `README.md` - Documentation updated

## Production Ready
✅ Debug output removed
✅ Error handling in place
✅ Webhook conflicts handled
✅ Unicode/emoji parsing fixed
✅ Proper offset management
✅ Callback acknowledgment
✅ Message status updates

## Testing
Run: `./test_telegram.sh`

This will:
- Send real Telegram message with buttons
- Wait for parent to tap button
- Show approval/denial flow
- Test fallback password if needed

## Requirements
- Python 3 (for JSON parsing)
- curl (for Telegram API)
- Telegram bot in polling mode (not webhook)
