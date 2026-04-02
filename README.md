<div align="center">

<div style="width: 160px;">
  <!-- Light mode -->
  <img src="Screenshot/Icon-Light.png#gh-light-mode-only" width="160">
  <!-- Dark mode -->
  <img src="Screenshot/Icon-Dark.png#gh-dark-mode-only" width="160">
</div>

# Mousecape-swiftUI

<p>
  <!-- GitHub Downloads -->
  <a href="https://github.com/kianwoon/Mousecape-swiftUI/releases">
    <img src="https://img.shields.io/github/downloads/kianwoon/Mousecape-swiftUI/total" alt="GitHub all releases">
  </a>
  <!-- GitHub Release Version -->
  <a href="https://github.com/kianwoon/Mousecape-swiftUI/releases">
    <img src="https://img.shields.io/github/v/release/kianwoon/Mousecape-swiftUI" alt="GitHub release (with filter)">
  </a>
  <!-- GitHub Issues -->
  <a href="https://github.com/kianwoon/Mousecape-swiftUI/issues">
    <img src="https://img.shields.io/github/issues/kianwoon/Mousecape-swiftUI" alt="GitHub issues">
  </a>
  <!-- GitHub Stars -->
  <a href="https://github.com/kianwoon/Mousecape-swiftUI/stargazers">
    <img src="https://img.shields.io/github/stars/kianwoon/Mousecape-swiftUI" alt="GitHub Repo stars">
  </a>
</p>

A free macOS cursor manager that allows you to easily replace Mac system pointers.
<br/>
<br/>
**Compatible with macOS 26, featuring a fully liquid glass design. Supports one-click conversion to Windows cursor.**
<br/>
</div>

## Interface Display

![light](Screenshot/Light_en.gif#gh-light-mode-only)
![dark](Screenshot/Dark_en.gif#gh-dark-mode-only)

> The cursor theme "Kiriko" shown in the screenshots is created by [ArakiCC](https://space.bilibili.com/14913641), available in the example files.

## Features

- Customize Mac system cursors, supporting both static and animated cursors
- One-click import of Windows cursor formats (.cur / .ani), mapping 85% of macOS cursor types
- Left-hand mode: mirror all cursors horizontally for left-handed users
- **Cursor Scale System**: Choose between Global scale (one size for all cursors) or Custom mode (set a different scale per cursor type, up to 16x)
- **Visual Effects**: Add inner shadow and outer glow effects to cursor edges for better visibility
- **High Resolution Support**: Supports cursors up to 16x scale with 2048px source images
- Uses private, non-intrusive CoreGraphics API, safe and reliable

## Download & Installation

Download the latest version from the [Releases](https://github.com/kianwoon/Mousecape-swiftUI/releases) section of this GitHub page.

If you encounter any problems, we recommend that you first check the [Troubleshooting](#troubleshooting) section.

### System Requirements

- macOS Sequoia (15) or later
- Support Architectures: runs on both Intel and Apple Silicon Macs

## Example Cursors

This repository includes an example Kiriko.cape file, available for [download here](Example/Kiriko.cape).

**License:** CC BY-NC-ND 4.0 (Attribution-NonCommercial-NoDerivs 4.0)

This cursor set was created by [ArakiCC](https://space.bilibili.com/14913641).

## Getting Started

<details>
<summary>Set Up Launch at Login</summary>

1. Download and open the Mousecape app
2. Go to **Settings > General** and enable **Launch at Login**

When enabled, Mousecape starts in the background at login and provides a menu bar icon that you can use to:
- Open the Mousecape app
- Reset cursor themes
- Quit the helper

</details>
<br>
<details>
<summary>Import Windows Format Cursors</summary>

Mousecape supports batch importing Windows cursor themes:

1. Extract the downloaded Windows cursor package
2. Click the "+" button and select "Import Windows Cursors"
3. Select the folder containing the cursor files to import

If the folder contains an `*.inf` file, Mousecape will automatically parse it to map cursor files to the correct cursor types. Otherwise, it will use filename-based matching.

</details>
<br>
<details>
<summary>Create Custom Cursor Sets</summary>

1. Click the "+" button to add a new cursor set
2. Click the "+" button to add pointers to customize
3. Drag and drop image or cursor files into the edit window
4. Adjust hotspot position and other parameters for each cursor
5. Save and apply your theme

**Simple / Advanced Mode**

Mousecape offers two editing modes, switchable via the toolbar:

- **Simple Mode**: Displays cursors in 15 Windows cursor groups. Editing one cursor automatically applies changes to all related macOS cursor types in the same group.
- **Advanced Mode**: Edit each of the 52 macOS cursor types individually for full control.

The home screen preview also supports Simple/Advanced display modes, configurable in **Settings > Appearance > Preview Panel**.

</details>
<br>
<details>
<summary>Customize Cursor Scale</summary>

Mousecape gives you two ways to control cursor size:

- **Global Scale**: Set one size for all cursors at once (0.5x to 16x)
- **Custom Scale**: Set a different size for each cursor type individually (up to 16x per cursor)

Go to **Settings > General > Cursor Scale** to choose your mode and adjust sizes. Custom mode is useful if you want the text cursor (IBeam) smaller than the arrow cursor, for example.

</details>
<br>
<details>
<summary>Visual Effects</summary>

Mousecape supports two visual effects for improved cursor visibility:

- **Inner Shadow**: Adds an inset shadow around cursor edges
- **Outer Glow**: Adds a soft glow around the cursor

Both effects can be toggled in **Settings > Appearance > Effects**. They apply to all registered cursors system-wide.

</details>
<br>
<details>
<summary>Import/Export .cape Format Cursors</summary>

- Click the "Import" button, then select the **.cape** format cursor file in the Finder window
- Or drag and drop **.cape** files directly onto the app window to import
- Or double-click a **.cape** file in Finder to open it directly in Mousecape
- Click the "Export" button, then choose where to save the **.cape** cursor file

> **.cape** is Mousecape's proprietary cursor format, containing a complete set of cursors in one file
>
> **Note:** Cape files saved with v1.1.0+ use HEIF image format and may not be compatible with older versions of Mousecape. Existing cape files will be automatically upgraded to the new format when saved.

</details>
<br>
<details>
<summary>Reset System Cursor</summary>

If you want to revert to the default macOS cursor, you can:

- Click **Settings > Reset System Cursor**
- Or use the keyboard shortcut **Cmd+R**

</details>
<br>
<details>
<summary>Export System Cursors</summary>

You can back up your original Mac cursors:

- Go to **Settings > Advanced > Reset** and click "Dump System Cursors"
- Or use the **File > Export System Cursors** menu item

This saves the current system cursors as a .cape file that can be re-imported later.

</details>
<br>
<details>
<summary>Supported Image Formats</summary>

- **Standard image formats**: PNG, JPEG, TIFF, GIF
- **Windows cursor formats**: .cur (static), .ani (animated)

</details>

## Troubleshooting

If you encounter issues, please check the common solutions below first. For more help, please [submit an Issue](https://github.com/kianwoon/Mousecape-swiftUI/issues).

### Cursor Limitations

Due to macOS system limitations, Mousecape has the following restrictions:

**Image Size Limit**

- Maximum import size: **512x512 pixels** (larger images will be rejected)
- All cursor images are automatically scaled to **64x64 pixels** at 1x resolution
- If the imported image is larger than 64x64 (up to 512x512), it will be automatically scaled down
- If the imported image is smaller than 64x64, it will be scaled up (may result in lower quality)

**Animation Frame Limit**

- Maximum **24 frames** per animated cursor
- Animated cursors with more than 24 frames will be automatically downsampled
- The downsampling preserves animation timing by adjusting frame duration

**Example:** A 32-frame GIF animation will be downsampled to 24 frames, and the frame duration will be increased to maintain the original animation speed.

### Cursor Animation Only Works in Dock Area

**Symptoms:** Custom cursor animations only appear when hovering over the Dock, but revert to the default system cursor elsewhere.

**Cause:** macOS system settings for custom pointer colors can prevent Mousecape from successfully applying cursors globally.

**Solution:** Reset the system pointer color to the default setting:

1. Open **System Settings > Accessibility > Display**
2. Find the **Pointer** section
3. Click the **Reset Color** button
4. Re-apply your cursor theme in Mousecape

The pointer must use the default color scheme (white outline, black fill) for Mousecape to work properly.

</details>
<br>
<details>
<summary>Animated Cursor Import Failed</summary>

**Symptoms:** Animated cursor files (.ani or .gif) fail to import or are rejected.

**Cause:** Animated cursors with more than 24 frames exceed macOS system limits and require automatic downsampling.

**Solution:**
- Mousecape automatically downsamples animations with more than 24 frames
- The animation speed is preserved by adjusting frame duration
- If import still fails, ensure the file is not corrupted and try re-downloading

</details>
<br>
<details>
<summary>Cursor Theme Display Issues (Non-English)</summary>

**Symptoms:** Non-English cursor themes show garbled filenames or incorrect names.

**Cause:** INF file encoding not detected correctly.

**Solution:**
- Mousecape supports multiple encodings: UTF-8, UTF-16 LE/BE, GBK, GB18030, Big5, Shift_JIS, EUC-KR, ISO-8859-1
- Ensure the INF file is saved in a supported encoding
- If issues persist, try resaving the INF file as UTF-8

</details>
<br>
<details>
<summary>Cursor Image Too Large</summary>

**Symptoms:** Large cursor images are rejected during import.

**Cause:** Image exceeds the maximum supported size of 512x512 pixels.

**Solution:**
- Resize images to 512x512 pixels or smaller before importing
- All imported images are automatically scaled to 64x64 pixels
- Images larger than 512x512 will be rejected with an error message

</details>

## Acknowledgments

- Original project created by [Alex Zielenski](https://github.com/alexzielenski)
- Demo and example cursor "Kiriko" created by [ArakiCC](https://space.bilibili.com/14913641)
- UI guidance by [Winter喵](https://space.bilibili.com/15016945)
- SwiftUI interface redesign and Liquid Glass adaptation by [sdmj76](https://space.bilibili.com/224661756)
- SwiftUI code programming and localization assisted by [Claude Code](https://claude.ai/code)

## Feedback & Issues

If you have questions or suggestions, please submit them on [GitHub Issues](https://github.com/kianwoon/Mousecape-swiftUI/issues).
