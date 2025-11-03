# Media CCC Library for Jellyfin

## Overview

This PowerShell script generates a Jellyfin-compatible video library from [media.ccc.de](https://media.ccc.de) content. It creates `.strm` files (containing direct streaming URLs) and `.nfo` files (containing metadata) that Jellyfin can scan and organize.

**Videos are streamed directly from cdn.media.ccc.de without downloading.**

## ⚠️ Important Limitations

This is a **workaround solution** because Jellyfin does not support content provider plugins like Plex does. The `.strm` + `.nfo` approach works but has limitations:

- **Not a native plugin** - External script required to generate library
- **Manual updates** - Re-run script to add new conferences/videos
- **No dynamic content** - Library is static until regenerated
- **Metadata refresh** - Jellyfin must be configured to read NFO files

## Features

✅ **Hierarchical folder structure** based on conference organization (e.g., `congress/2024/`, `events/camp/`)  
✅ **Highest quality MP4** selection automatically  
✅ **Rich metadata** in NFO files:
   - Title, subtitle, description
   - Speakers (as actors)
   - Tags and genres
   - Release dates and runtime
   - Poster and thumbnail URLs
   - Video resolution (width/height)
   - Conference information

✅ **Progress tracking** with detailed logging  
✅ **Error handling** with automatic retries  
✅ **Dry-run mode** for testing  
✅ **Conference filtering** to process specific events  

## Requirements

- **PowerShell 5.1 or higher** (Windows, Linux, macOS)
  - Linux/macOS: Install PowerShell 7+ from [Microsoft's repo](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)
- **Internet connection** to access media.ccc.de API
- **Jellyfin 10.8+** with NFO metadata support enabled

## Quick Start

### 1. Generate the Library

```powershell
# Generate all conferences (WARNING: 441+ conferences = thousands of files)
.\Generate-MediaCCCLibrary.ps1 -OutputPath "D:\Jellyfin\MediaCCC"

# Generate specific conferences only (RECOMMENDED)
.\Generate-MediaCCCLibrary.ps1 -OutputPath "D:\Jellyfin\MediaCCC" -ConferenceFilter "38c3,37c3,36c3"

# Dry run to preview what will be created
.\Generate-MediaCCCLibrary.ps1 -ConferenceFilter "38c3" -DryRun
```

### 2. Add to Jellyfin

1. Open Jellyfin web interface
2. Go to **Dashboard** → **Libraries**
3. Click **Add Media Library**
4. Settings:
   - **Content type**: Movies (or "Other Videos")
   - **Display name**: Media CCC
   - **Folders**: Add the path you used in `-OutputPath`
   - **Prefer embedded titles over filenames**: ✅ Enabled
   - **Metadata savers**: ✅ Enable "Nfo"
   - **Metadata readers**: ✅ Enable "Nfo"
5. Click **OK**
6. Jellyfin will scan and import the library

### 3. Configure NFO Support

Ensure Jellyfin is configured to read NFO files:

1. **Dashboard** → **Libraries** → Select "Media CCC" library
2. **Manage Library** → **NFO Settings**
3. Enable:
   - ✅ **Enable NFO-based metadata**
   - ✅ **Replace existing metadata**

## Script Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-OutputPath` | String | `./jellyfin-mediaccc` | Root directory for library |
| `-ConferenceFilter` | String | (none) | Comma-separated conference acronyms (e.g., "38c3,37c3") |
| `-MaxConcurrent` | Int | `5` | Max concurrent API requests |
| `-DryRun` | Switch | `false` | Preview without creating files |
| `-Force` | Switch | `false` | Overwrite existing files |
| `-LogFile` | String | `./mediaccc-generator.log` | Path to log file |

## Examples

### Generate Recent Congresses Only

```powershell
.\Generate-MediaCCCLibrary.ps1 `
    -OutputPath "D:\Jellyfin\MediaCCC" `
    -ConferenceFilter "38c3,37c3,36c3,35c3,34c3,camp2023"
```

### Update Library with New Content

```powershell
# Re-run with -Force to overwrite existing files
.\Generate-MediaCCCLibrary.ps1 `
    -OutputPath "D:\Jellyfin\MediaCCC" `
    -ConferenceFilter "38c3" `
    -Force
```

After running, trigger a library scan in Jellyfin:
- **Dashboard** → **Libraries** → **Scan Library**

### Test Before Full Generation

```powershell
# Dry run to see what will be created
.\Generate-MediaCCCLibrary.ps1 `
    -OutputPath "D:\Jellyfin\MediaCCC" `
    -ConferenceFilter "38c3" `
    -DryRun `
    -Verbose
```

## Folder Structure

The script creates a hierarchical structure based on `webgen_location`:

```
jellyfin-mediaccc/
├── congress/
│   ├── 2024/
│   │   ├── Wir wissen wo dein Auto steht.strm
│   │   ├── Wir wissen wo dein Auto steht.nfo
│   │   ├── Security Nightmares.strm
│   │   └── Security Nightmares.nfo
│   └── 2023/
│       └── ...
├── events/
│   └── camp/
│       └── ...
└── andere-konferenzen/
    └── ...
```

## File Formats

### .strm Files

Plain text file containing a single URL to the MP4:

```
https://cdn.media.ccc.de/congress/2024/h264-hd/38c3-598-deu-eng-fra-Wir_wissen_wo_dein_Auto_steht_-_Volksdaten_von_Volkswagen_hd.mp4
```

### .nfo Files

Kodi/Jellyfin compatible XML:

```xml
<?xml version="1.0" encoding="utf-8"?>
<movie>
  <title>Wir wissen wo dein Auto steht</title>
  <tagline>Volksdaten von Volkswagen</tagline>
  <plot>Bewegungsdaten von 800.000 E-Autos...</plot>
  <runtime>39</runtime>
  <premiered>2024-12-30</premiered>
  <year>2024</year>
  <tag>38c3</tag>
  <tag>Security</tag>
  <actor>
    <name>Michael Kreil</name>
    <role>Speaker</role>
  </actor>
  <thumb aspect="poster">https://static.media.ccc.de/...</thumb>
  <studio>38C3: Illegal Instructions</studio>
</movie>
```

## Updating the Library

The script does not run continuously. To add new conferences or videos:

1. Run the script again with the same `-OutputPath`
2. Use `-Force` to overwrite existing files (or skip them by omitting `-Force`)
3. Trigger a library scan in Jellyfin

**Recommendation**: Set up a scheduled task (Windows) or cron job (Linux/macOS) to run weekly:

### Windows Task Scheduler

```powershell
# Create a scheduled task
$action = New-ScheduledTaskAction -Execute 'pwsh.exe' `
    -Argument '-File "C:\Scripts\Generate-MediaCCCLibrary.ps1" -OutputPath "D:\Jellyfin\MediaCCC" -ConferenceFilter "38c3,37c3" -Force'

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am

Register-ScheduledTask -TaskName "MediaCCC-Update" -Action $action -Trigger $trigger
```

### Linux Cron

```bash
# Add to crontab (crontab -e)
0 3 * * 0 /usr/bin/pwsh /path/to/Generate-MediaCCCLibrary.ps1 -OutputPath /media/jellyfin/mediaccc -ConferenceFilter "38c3,37c3" -Force
```

### macOS LaunchAgent

Create a Launch Agent to run the script weekly:

```bash
# Create the plist file
cat > ~/Library/LaunchAgents/com.mediaccc.update.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.mediaccc.update</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/pwsh</string>
        <string>/path/to/Generate-MediaCCCLibrary.ps1</string>
        <string>-OutputPath</string>
        <string>/Users/YourUsername/Jellyfin/MediaCCC</string>
        <string>-ConferenceFilter</string>
        <string>38c3,37c3,36c3</string>
        <string>-Force</string>
    </array>
    
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>0</integer>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    
    <key>StandardOutPath</key>
    <string>/tmp/mediaccc-update.log</string>
    
    <key>StandardErrorPath</key>
    <string>/tmp/mediaccc-update-error.log</string>
</dict>
</plist>
EOF

# Load the launch agent
launchctl load ~/Library/LaunchAgents/com.mediaccc.update.plist

# Verify it's loaded
launchctl list | grep mediaccc
```

To test the LaunchAgent immediately:
```bash
launchctl start com.mediaccc.update
```

To stop/unload:
```bash
launchctl unload ~/Library/LaunchAgents/com.mediaccc.update.plist
```

## Troubleshooting

### Videos Won't Play in Jellyfin

**Possible causes:**

1. **Network access**: Jellyfin server needs internet access to cdn.media.ccc.de
2. **Codec support**: Ensure H.264 codec is supported by your client
3. **Transcoding**: May require transcoding depending on client capabilities

**Solution**: Check Jellyfin's playback logs and ensure direct streaming is enabled.

### Metadata Not Showing

**Possible causes:**

1. NFO support not enabled in library settings
2. Jellyfin cached old metadata

**Solution:**
1. Enable NFO metadata in library settings
2. **Metadata Manager** → Select videos → **Refresh Metadata** → ✅ Replace all metadata

### Some Videos Missing

**Possible causes:**

1. No MP4 recording available (only WebM or audio)
2. API timeout or network error during generation

**Solution:**
- Check the log file: `mediaccc-generator.log`
- Re-run with `-Verbose` to see detailed output
- Check the "Errors" count in the summary

### Special Characters in Filenames

Windows has restrictions on certain characters. The script automatically sanitizes:
- `:` → ` -`
- `/`, `\`, `|` → `-`
- `"` → `'`
- Invalid characters → `_`

Files longer than 200 characters are truncated.

## API Information

The script uses the public media.ccc.de API:

- **Base URL**: `https://api.media.ccc.de/public/`
- **Endpoints**:
  - `/conferences` - List all conferences
  - `/conferences/{id}` - Conference details + events
  - `/events/{id}` - Event details + recordings
- **No authentication required**
- **Rate limiting**: Script uses 5 concurrent requests by default (adjustable with `-MaxConcurrent`)

## Performance

**Generation time** depends on conference count:

- 1 conference (38c3): ~15 seconds, ~220 videos
- 5 conferences: ~1-2 minutes, ~1000 videos
- All 441 conferences: ~30-60 minutes, ~30,000+ videos (NOT RECOMMENDED)

**Disk space**: Minimal (only .strm and .nfo files)
- .strm files: ~130 bytes each
- .nfo files: ~1-5 KB each
- Total: ~200 MB for all conferences

## Contributing

To improve the script or report issues with media.ccc.de integration:

- **API documentation**: https://github.com/voc/media-ccc-de
- **media.ccc.de**: https://media.ccc.de

## License

This script is provided as-is for personal use. Media CCC content is licensed individually (typically CC BY-SA).

---

**Media CCC Library Generator for Jellyfin**  
**Last updated**: 2025-11-03  
**Compatible with**: Jellyfin 10.8+, PowerShell 5.1+
