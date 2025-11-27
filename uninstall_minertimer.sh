#!/bin/zsh

###
# Minecraft Timer Uninstallation Script
# Copyright (c) 2025 Linas Purinis
# Requires administrator privileges
###

echo ""
echo "Uninstalling Minecraft Timer..."
echo ""

# Step 1: Unregister the minertimer as a background task
echo "Stopping background service..."
launchctl bootout system/com.purinis.minecrafttimer 2>/dev/null || true

# Step 2: Remove PLIST file
echo "Removing LaunchDaemon..."
rm -f /Library/LaunchDaemons/com.purinis.minecrafttimer.plist

# Step 3: Remove Minertimer script and config
echo "Removing application files..."
rm -f /Users/Shared/minertimer/minertimer.sh
rm -f /Users/Shared/minertimer/minertimer.config
rmdir /Users/Shared/minertimer 2>/dev/null || true

# Step 4: Remove log files
echo "Removing log files..."
rm -rf /var/lib/minertimer

# Step 5: Report
echo ""
echo "=========================================="
echo "✅ UNINSTALLATION COMPLETE!"
echo "=========================================="
echo ""
echo "To verify the timer is removed:"
echo "  sudo launchctl list | grep com.purinis.minecrafttimer"
echo ""
echo "You should get no results."
echo ""
