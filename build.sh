#!/bin/bash

# Build script for ChargeLimit App

echo "Building ChargeLimit.app..."

# Ensure the App bundle structure exists
mkdir -p ChargeLimit.app/Contents/MacOS
mkdir -p ChargeLimit.app/Contents/Resources

# Create Info.plist
cat <<EOF > ChargeLimit.app/Contents/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>ChargeLimit</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.example.ChargeLimit</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>ChargeLimit</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
</dict>
</plist>
EOF

# Compile the Swift code
swiftc -parse-as-library ChargeLimit.swift -o ChargeLimit.app/Contents/MacOS/ChargeLimit

# Copy the app icon
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns ChargeLimit.app/Contents/Resources/AppIcon.icns
fi

# Bundle bclm binary for self-contained distribution
BCLM_PATH=$(which bclm)
if [ -f "$BCLM_PATH" ]; then
    echo "Bundling bclm from $BCLM_PATH..."
    rm -f ChargeLimit.app/Contents/Resources/bclm
    cp "$BCLM_PATH" ChargeLimit.app/Contents/Resources/bclm
    chmod +x ChargeLimit.app/Contents/Resources/bclm
else
    echo "Warning: bclm not found in PATH. App will require manual bclm installation."
fi

echo "Build complete! You can run the app with: open ChargeLimit.app"

echo "Building DMG..."
rm -f ChargeLimit.dmg
mkdir -p dmg_staging
cp -r ChargeLimit.app dmg_staging/
ln -s /Applications dmg_staging/Applications

# Set DMG volume icon
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns dmg_staging/.VolumeIcon.icns
    SetFile -c icnC dmg_staging/.VolumeIcon.icns
    SetFile -a C dmg_staging
fi

hdiutil create -volname ChargeLimit -srcfolder dmg_staging -ov -format UDZO ChargeLimit.dmg
rm -rf dmg_staging
echo "DMG created successfully."
