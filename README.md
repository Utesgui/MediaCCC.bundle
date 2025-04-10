# media.ccc.de for Jellyfin

This is the un-official Jellyfin plugin to browse content on media.ccc.de.

## Features

- Stream videos from [media.ccc.de](https://media.ccc.de), the media platform of the Chaos Computer Club
- Browse conferences and events
- Search for specific talks
- View metadata including descriptions, speakers, and tags
- Configure caching and content limitations

## Installation

### Prerequisites

- Jellyfin server 10.8.0 or later
- .NET 6.0 or later

### Method 1: Installing from Plugin Catalog

1. Open your Jellyfin web interface
2. Navigate to Dashboard → Plugins
3. Select the "Catalog" tab
4. Find "MediaCCC" and click on it
5. Click "Install"
6. Restart Jellyfin when prompted

### Method 2: Manual Installation

1. Download the latest release from the [releases page](https://github.com/yourusername/jellyfin-plugin-mediaccc/releases)
2. Extract the ZIP file
3. Copy the extracted folder to your Jellyfin plugin directory:
   - Linux: `/var/lib/jellyfin/plugins` or `~/.local/share/jellyfin/plugins`
   - Windows: `C:\ProgramData\Jellyfin\Server\plugins` or `%LOCALAPPDATA%\jellyfin\plugins`
   - Docker: `/config/plugins`
4. Restart Jellyfin

### Method 3: Building from Source

1. Clone this repository
2. Build the solution with `dotnet build`
3. Copy the generated `Jellyfin.Plugin.MediaCCC.dll` from the `bin` directory to your Jellyfin plugin directory
4. Restart Jellyfin

## Configuration

After installation, you can configure the plugin through the Jellyfin web interface:

1. Navigate to Dashboard → Plugins
2. Find the MediaCCC plugin and click the "Settings" button
3. Configure the following options:
   - Maximum Items: The maximum number of items to load from the MediaCCC repository
   - Enable for Movies: Whether to enable the plugin for the Movies library type
   - Cache Time: How long to cache data (in minutes)
4. Click "Save"

## Usage

1. Add a new library in Jellyfin
2. Select "Movies" as the content type
3. Enable the MediaCCC metadata provider
4. Add a "virtual folder" with any name
5. Save the library
6. The content from media.ccc.de will be accessible through this library

## Development

This plugin is built on the Jellyfin plugin architecture and interacts with the media.ccc.de API. Contributions are welcome!

### Project Structure

- `Plugin.cs`: Main plugin class
- `Configuration/`: Plugin configuration classes
- `Api/`: API client for media.ccc.de
- `Providers/`: Content and image providers for Jellyfin

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- The Jellyfin team for creating a great open-source media server
- The Chaos Computer Club for providing an extensive library of educational content
