<#
.SYNOPSIS
    Generates a Jellyfin-compatible library from media.ccc.de content using .strm files.

.DESCRIPTION
    This script parses the media.ccc.de public API to create a hierarchical folder structure
    with .strm files (containing direct MP4 URLs) and .nfo files (with metadata) that Jellyfin
    can scan and play. Videos are streamed directly from cdn.media.ccc.de without downloading.

.PARAMETER OutputPath
    The root directory where the library will be created. Default: ./jellyfin-mediaccc

.PARAMETER ConferenceFilter
    Optional filter to process only specific conferences (comma-separated acronyms).
    Example: "38c3,37c3,camp2023"

.PARAMETER MaxConcurrent
    Maximum number of concurrent API requests. Default: 5

.PARAMETER DryRun
    If specified, shows what would be created without actually creating files.

.PARAMETER Force
    If specified, overwrites existing files without prompting.

.PARAMETER LogFile
    Path to log file. Default: ./mediaccc-generator.log

.EXAMPLE
    .\Generate-MediaCCCLibrary.ps1 -OutputPath "D:\Jellyfin\MediaCCC"

.EXAMPLE
    .\Generate-MediaCCCLibrary.ps1 -ConferenceFilter "38c3,37c3" -DryRun

.NOTES
    Author: Generated for Jellyfin Media CCC Library
    Requires: PowerShell 5.1 or higher
    API: https://api.media.ccc.de/public/
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "./jellyfin-mediaccc",

    [Parameter(Mandatory=$false)]
    [string]$ConferenceFilter = "",

    [Parameter(Mandatory=$false)]
    [int]$MaxConcurrent = 5,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false,

    [Parameter(Mandatory=$false)]
    [switch]$Force = $false,

    [Parameter(Mandatory=$false)]
    [string]$LogFile = "./mediaccc-generator.log"
)

#Requires -Version 5.1

# Configuration
$API_BASE_URL = "https://api.media.ccc.de/public"
$script:Stats = @{
    ConferencesProcessed = 0
    EventsProcessed = 0
    StrmFilesCreated = 0
    NfoFilesCreated = 0
    Errors = 0
    Skipped = 0
}

#region Helper Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    $color = switch ($Level) {
        'INFO'    { 'Cyan' }
        'WARN'    { 'Yellow' }
        'ERROR'   { 'Red' }
        'SUCCESS' { 'Green' }
    }
    
    Write-Host $logMessage -ForegroundColor $color
    Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
}

function Invoke-APIRequest {
    param(
        [string]$Endpoint,
        [int]$RetryCount = 3
    )
    
    $url = "$API_BASE_URL/$Endpoint"
    $attempt = 0
    
    while ($attempt -lt $RetryCount) {
        try {
            Write-Verbose "Fetching: $url"
            $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 30
            return $response
        }
        catch {
            $attempt++
            if ($attempt -ge $RetryCount) {
                Write-Log "Failed to fetch $url after $RetryCount attempts: $_" -Level ERROR
                $script:Stats.Errors++
                return $null
            }
            Write-Log "Retry $attempt/$RetryCount for $url" -Level WARN
            Start-Sleep -Seconds (2 * $attempt)
        }
    }
}

function Get-SanitizedFilename {
    param([string]$Filename)
    
    # Replace invalid Windows filename characters
    $invalid = [System.IO.Path]::GetInvalidFileNameChars()
    $sanitized = $Filename
    
    foreach ($char in $invalid) {
        $sanitized = $sanitized.Replace($char, '_')
    }
    
    # Additional replacements for readability
    $sanitized = $sanitized.Replace(':', ' -')
    $sanitized = $sanitized.Replace('/', '-')
    $sanitized = $sanitized.Replace('\', '-')
    $sanitized = $sanitized.Replace('|', '-')
    $sanitized = $sanitized.Replace('"', "'")
    
    # Trim and remove multiple spaces/underscores
    $sanitized = $sanitized.Trim()
    $sanitized = $sanitized -replace '\s+', ' '
    $sanitized = $sanitized -replace '_+', '_'
    
    # Limit length (Windows path limit consideration)
    if ($sanitized.Length -gt 200) {
        $sanitized = $sanitized.Substring(0, 200).Trim()
    }
    
    return $sanitized
}

function Get-BestVideoRecording {
    param([array]$Recordings)
    
    # Filter to video recordings only (MP4 or WebM)
    $videoRecordings = $Recordings | Where-Object { 
        $_.mime_type -in @('video/mp4', 'video/webm')
    }
    
    if ($videoRecordings.Count -eq 0) {
        return $null
    }
    
    # Prefer MP4 over WebM (better compatibility)
    $mp4Videos = $videoRecordings | Where-Object { $_.mime_type -eq 'video/mp4' }
    $webmVideos = $videoRecordings | Where-Object { $_.mime_type -eq 'video/webm' }
    
    # Try MP4 first
    if ($mp4Videos.Count -gt 0) {
        $best = $mp4Videos | Sort-Object -Property @{Expression={$_.height}; Descending=$true}, @{Expression={$_.width}; Descending=$true} | Select-Object -First 1
        return $best
    }
    
    # Fallback to WebM if no MP4
    if ($webmVideos.Count -gt 0) {
        $best = $webmVideos | Sort-Object -Property @{Expression={$_.height}; Descending=$true}, @{Expression={$_.width}; Descending=$true} | Select-Object -First 1
        Write-Verbose "Using WebM fallback for recording (no MP4 available)"
        return $best
    }
    
    return $null
}

function New-NFOFile {
    param(
        [string]$Path,
        [hashtable]$Metadata
    )
    
    if ((Test-Path -LiteralPath $Path) -and -not $Force) {
        Write-Verbose "NFO exists: $Path"
        $script:Stats.Skipped++
        return
    }
    
    $xml = New-Object System.Xml.XmlDocument
    $declaration = $xml.CreateXmlDeclaration("1.0", "UTF-8", $null)
    [void]$xml.AppendChild($declaration)
    
    # Create root element based on type
    $movie = $xml.CreateElement("movie")
    [void]$xml.AppendChild($movie)
    
    # Title
    if ($Metadata.Title) {
        $titleNode = $xml.CreateElement("title")
        $titleNode.InnerText = $Metadata.Title
        [void]$movie.AppendChild($titleNode)
    }
    
    # Original Title
    if ($Metadata.Title) {
        $origTitleNode = $xml.CreateElement("originaltitle")
        $origTitleNode.InnerText = $Metadata.Title
        [void]$movie.AppendChild($origTitleNode)
    }
    
    # Subtitle (if available)
    if ($Metadata.Subtitle) {
        $subtitleNode = $xml.CreateElement("tagline")
        $subtitleNode.InnerText = $Metadata.Subtitle
        [void]$movie.AppendChild($subtitleNode)
    }
    
    # Plot/Description
    if ($Metadata.Description) {
        $plotNode = $xml.CreateElement("plot")
        $plotNode.InnerText = $Metadata.Description
        [void]$movie.AppendChild($plotNode)
        
        $outlineNode = $xml.CreateElement("outline")
        $outlineNode.InnerText = $Metadata.Description.Substring(0, [Math]::Min(200, $Metadata.Description.Length))
        [void]$movie.AppendChild($outlineNode)
    }
    
    # Runtime (in minutes)
    if ($Metadata.Length) {
        $runtimeNode = $xml.CreateElement("runtime")
        $runtimeNode.InnerText = [math]::Round($Metadata.Length / 60)
        [void]$movie.AppendChild($runtimeNode)
    }
    
    # Release Date
    if ($Metadata.ReleaseDate) {
        # Convert to string if it's a date object
        $releaseDateStr = if ($Metadata.ReleaseDate -is [DateTime]) {
            $Metadata.ReleaseDate.ToString("yyyy-MM-dd")
        } elseif ($Metadata.ReleaseDate -is [string]) {
            $Metadata.ReleaseDate
        } else {
            $Metadata.ReleaseDate.ToString()
        }
        
        $releasedNode = $xml.CreateElement("premiered")
        $releasedNode.InnerText = $releaseDateStr
        [void]$movie.AppendChild($releasedNode)
        
        $airedNode = $xml.CreateElement("aired")
        $airedNode.InnerText = $releaseDateStr
        [void]$movie.AppendChild($airedNode)
        
        $yearNode = $xml.CreateElement("year")
        $yearNode.InnerText = $releaseDateStr.Substring(0, 4)
        [void]$movie.AppendChild($yearNode)
    }
    
    # Tags
    if ($Metadata.Tags) {
        foreach ($tag in $Metadata.Tags) {
            $tagNode = $xml.CreateElement("tag")
            $tagNode.InnerText = $tag
            [void]$movie.AppendChild($tagNode)
            
            $genreNode = $xml.CreateElement("genre")
            $genreNode.InnerText = $tag
            [void]$movie.AppendChild($genreNode)
        }
    }
    
    # Persons (speakers/presenters)
    if ($Metadata.Persons) {
        foreach ($person in $Metadata.Persons) {
            $actorNode = $xml.CreateElement("actor")
            
            $nameNode = $xml.CreateElement("name")
            $nameNode.InnerText = $person
            [void]$actorNode.AppendChild($nameNode)
            
            $roleNode = $xml.CreateElement("role")
            $roleNode.InnerText = "Speaker"
            [void]$actorNode.AppendChild($roleNode)
            
            [void]$movie.AppendChild($actorNode)
        }
    }
    
    # Poster URL
    if ($Metadata.PosterUrl) {
        $posterNode = $xml.CreateElement("thumb")
        $posterNode.SetAttribute("aspect", "poster")
        $posterNode.InnerText = $Metadata.PosterUrl
        [void]$movie.AppendChild($posterNode)
    }
    
    # Thumb URL
    if ($Metadata.ThumbUrl) {
        $thumbNode = $xml.CreateElement("thumb")
        $thumbNode.SetAttribute("aspect", "thumb")
        $thumbNode.InnerText = $Metadata.ThumbUrl
        [void]$movie.AppendChild($thumbNode)
    }
    
    # Video resolution info
    if ($Metadata.Width -and $Metadata.Height) {
        $fileinfoNode = $xml.CreateElement("fileinfo")
        $streamdetailsNode = $xml.CreateElement("streamdetails")
        $videoNode = $xml.CreateElement("video")
        
        $widthNode = $xml.CreateElement("width")
        $widthNode.InnerText = $Metadata.Width
        [void]$videoNode.AppendChild($widthNode)
        
        $heightNode = $xml.CreateElement("height")
        $heightNode.InnerText = $Metadata.Height
        [void]$videoNode.AppendChild($heightNode)
        
        $codecNode = $xml.CreateElement("codec")
        $codecNode.InnerText = "h264"
        [void]$videoNode.AppendChild($codecNode)
        
        [void]$streamdetailsNode.AppendChild($videoNode)
        [void]$fileinfoNode.AppendChild($streamdetailsNode)
        [void]$movie.AppendChild($fileinfoNode)
    }
    
    # GUID
    if ($Metadata.Guid) {
        $uniqueidNode = $xml.CreateElement("uniqueid")
        $uniqueidNode.SetAttribute("type", "mediaccc")
        $uniqueidNode.SetAttribute("default", "true")
        $uniqueidNode.InnerText = $Metadata.Guid
        [void]$movie.AppendChild($uniqueidNode)
    }
    
    # Conference info as studio
    if ($Metadata.Conference) {
        $studioNode = $xml.CreateElement("studio")
        $studioNode.InnerText = $Metadata.Conference
        [void]$movie.AppendChild($studioNode)
    }
    
    # Source link
    if ($Metadata.FrontendLink) {
        $commentNode = $xml.CreateElement("comment")
        $commentNode.InnerText = "Source: $($Metadata.FrontendLink)"
        [void]$movie.AppendChild($commentNode)
    }
    
    if (-not $DryRun) {
        $settings = New-Object System.Xml.XmlWriterSettings
        $settings.Indent = $true
        $settings.IndentChars = "  "
        $settings.Encoding = [System.Text.Encoding]::UTF8
        
        $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
        $xml.Save($writer)
        $writer.Close()
        
        $script:Stats.NfoFilesCreated++
    }
    else {
        Write-Host "  [DryRun] Would create: $Path" -ForegroundColor DarkGray
    }
}

function New-STRMFile {
    param(
        [string]$Path,
        [string]$StreamUrl
    )
    
    if ((Test-Path -LiteralPath $Path) -and -not $Force) {
        Write-Verbose "STRM exists: $Path"
        $script:Stats.Skipped++
        return
    }
    
    if (-not $DryRun) {
        # Use -LiteralPath to avoid wildcard interpretation (e.g., brackets, underscores)
        $StreamUrl | Out-File -LiteralPath $Path -Encoding ascii -NoNewline
        $script:Stats.StrmFilesCreated++
    }
    else {
        Write-Host "  [DryRun] Would create: $Path" -ForegroundColor DarkGray
        Write-Host "  [DryRun] URL: $StreamUrl" -ForegroundColor DarkGray
    }
}

function Get-ConferenceFromAPI {
    param([string]$ConferenceUrl)
    
    # Extract endpoint from full URL (remove base API URL)
    $endpoint = $ConferenceUrl -replace '^https?://[^/]+/public/', ''
    Write-Verbose "Fetching conference: $endpoint"
    return Invoke-APIRequest -Endpoint $endpoint
}

function Get-EventFromAPI {
    param([string]$EventUrl)
    
    # Extract endpoint from full URL (remove base API URL)
    $endpoint = $EventUrl -replace '^https?://[^/]+/public/', ''
    Write-Verbose "Fetching event: $endpoint"
    return Invoke-APIRequest -Endpoint $endpoint
}

#endregion

#region Main Processing Functions

function Process-Event {
    param(
        [object]$EventSummary,
        [string]$BasePath,
        [string]$ConferenceTitle
    )
    
    try {
        # Fetch full event details including recordings
        $eventDetails = Get-EventFromAPI -EventUrl $EventSummary.url
        if (-not $eventDetails) {
            Write-Log "Skipping event (API fetch failed): $($EventSummary.title)" -Level WARN
            return
        }
        
        # Get best video recording (MP4 preferred, WebM fallback)
        $bestRecording = Get-BestVideoRecording -Recordings $eventDetails.recordings
        if (-not $bestRecording) {
            Write-Log "No video recording (MP4/WebM) found for: $($EventSummary.title)" -Level WARN
            $script:Stats.Skipped++
            return
        }
        
        # Log format being used
        $format = if ($bestRecording.mime_type -eq 'video/mp4') { 'MP4' } else { 'WebM' }
        Write-Verbose "Using $format for: $($EventSummary.title) (${bestRecording.width}x${bestRecording.height})"
        
        # Sanitize title for filename
        $safeTitle = Get-SanitizedFilename -Filename $eventDetails.title
        
        # Create .strm file
        $strmPath = Join-Path $BasePath "$safeTitle.strm"
        New-STRMFile -Path $strmPath -StreamUrl $bestRecording.recording_url
        
        # Prepare metadata for NFO
        $metadata = @{
            Title = $eventDetails.title
            Subtitle = $eventDetails.subtitle
            Description = $eventDetails.description
            Length = $eventDetails.length
            ReleaseDate = $eventDetails.release_date
            Tags = $eventDetails.tags
            Persons = $eventDetails.persons
            PosterUrl = $eventDetails.poster_url
            ThumbUrl = $eventDetails.thumb_url
            Width = $bestRecording.width
            Height = $bestRecording.height
            Guid = $eventDetails.guid
            Conference = $ConferenceTitle
            FrontendLink = $eventDetails.frontend_link
        }
        
        # Create .nfo file
        $nfoPath = Join-Path $BasePath "$safeTitle.nfo"
        New-NFOFile -Path $nfoPath -Metadata $metadata
        
        Write-Verbose "Processed: $safeTitle (${bestRecording.width}x${bestRecording.height})"
        $script:Stats.EventsProcessed++
        
    }
    catch {
        Write-Log "Error processing event $($EventSummary.title): $_" -Level ERROR
        $script:Stats.Errors++
    }
}

function Process-Conference {
    param([object]$Conference)
    
    try {
        $acronym = $Conference.acronym
        Write-Log "Processing conference: $($Conference.title) ($acronym)" -Level INFO
        
        # Fetch full conference data with events
        $conferenceData = Get-ConferenceFromAPI -ConferenceUrl $Conference.url
        if (-not $conferenceData) {
            Write-Log "Failed to fetch conference data for: $acronym" -Level ERROR
            return
        }
        
        $events = $conferenceData.events
        if (-not $events -or $events.Count -eq 0) {
            Write-Log "No events found for: $acronym" -Level WARN
            return
        }
        
        # Use webgen_location as-is for hierarchical path
        # Example: "conferences/sigint/2013", "congress/35C3/wikipakawg", "events/chaosseminar", "documentations/c3gelb"
        $webgenLocation = $Conference.webgen_location
        
        # Create full directory path using the complete webgen_location
        $conferencePath = Join-Path $OutputPath $webgenLocation
        
        if (-not $DryRun) {
            if (-not (Test-Path $conferencePath)) {
                New-Item -Path $conferencePath -ItemType Directory -Force | Out-Null
                Write-Verbose "Created directory: $conferencePath"
            }
        }
        else {
            Write-Host "[DryRun] Would create directory: $conferencePath" -ForegroundColor DarkGray
        }
        
        # Process all events in this conference
        Write-Log "Processing $($events.Count) events in $acronym..." -Level INFO
        
        $eventCounter = 0
        foreach ($event in $events) {
            $eventCounter++
            Write-Progress -Activity "Processing $acronym" `
                          -Status "Event $eventCounter of $($events.Count): $($event.title)" `
                          -PercentComplete (($eventCounter / $events.Count) * 100)
            
            Process-Event -EventSummary $event -BasePath $conferencePath -ConferenceTitle $Conference.title
        }
        
        Write-Progress -Activity "Processing $acronym" -Completed
        $script:Stats.ConferencesProcessed++
        
    }
    catch {
        Write-Log "Error processing conference $($Conference.acronym): $_" -Level ERROR
        $script:Stats.Errors++
    }
}

#endregion

#region Main Execution

function Main {
    Write-Log "=== Media CCC Library Generator for Jellyfin ===" -Level SUCCESS
    Write-Log "Output Path: $OutputPath" -Level INFO
    Write-Log "API Base: $API_BASE_URL" -Level INFO
    
    if ($DryRun) {
        Write-Log "DRY RUN MODE - No files will be created" -Level WARN
    }
    
    # Create output directory
    if (-not $DryRun) {
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
            Write-Log "Created output directory: $OutputPath" -Level SUCCESS
        }
    }
    
    # Fetch all conferences
    Write-Log "Fetching conferences list from API..." -Level INFO
    $conferencesData = Invoke-APIRequest -Endpoint "conferences"
    
    if (-not $conferencesData) {
        Write-Log "Failed to fetch conferences from API" -Level ERROR
        return
    }
    
    $conferences = $conferencesData.conferences
    Write-Log "Found $($conferences.Count) conferences" -Level SUCCESS
    
    # Apply filter if specified
    if ($ConferenceFilter) {
        $filterList = $ConferenceFilter -split ',' | ForEach-Object { $_.Trim() }
        $conferences = $conferences | Where-Object { $filterList -contains $_.acronym }
        Write-Log "Filtered to $($conferences.Count) conferences: $ConferenceFilter" -Level INFO
    }
    
    # Process conferences in parallel (PowerShell 7+)
    Write-Log "Processing conferences in parallel (max 5 concurrent)..." -Level INFO
    
    $totalConferences = $conferences.Count
    $progressTracker = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
    
    $conferences | ForEach-Object -Parallel {
        # Import functions and variables into parallel runspace
        $API_BASE_URL = $using:API_BASE_URL
        $OutputPath = $using:OutputPath
        $DryRun = $using:DryRun
        $Force = $using:Force
        $LogFile = $using:LogFile
        $VerbosePreference = $using:VerbosePreference
        $progressTracker = $using:progressTracker
        $totalConferences = $using:totalConferences
        
        # Re-define helper functions in parallel scope
        function Write-Log {
            param(
                [string]$Message,
                [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
                [string]$Level = 'INFO'
            )
            
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logMessage = "[$timestamp] [$Level] $Message"
            
            $color = switch ($Level) {
                'INFO'    { 'Cyan' }
                'WARN'    { 'Yellow' }
                'ERROR'   { 'Red' }
                'SUCCESS' { 'Green' }
            }
            
            Write-Host $logMessage -ForegroundColor $color
            
            # Thread-safe logging
            $mutex = New-Object System.Threading.Mutex($false, "MediaCCCLogMutex")
            try {
                [void]$mutex.WaitOne()
                Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
            }
            finally {
                $mutex.ReleaseMutex()
                $mutex.Dispose()
            }
        }
        
        function Invoke-APIRequest {
            param(
                [string]$Endpoint,
                [int]$RetryCount = 3
            )
            
            $url = "$API_BASE_URL/$Endpoint"
            $attempt = 0
            
            while ($attempt -lt $RetryCount) {
                try {
                    Write-Verbose "Fetching: $url"
                    $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 30
                    return $response
                }
                catch {
                    $attempt++
                    if ($attempt -ge $RetryCount) {
                        Write-Log "Failed to fetch $url after $RetryCount attempts: $_" -Level ERROR
                        return $null
                    }
                    Write-Log "Retry $attempt/$RetryCount for $url" -Level WARN
                    Start-Sleep -Seconds (2 * $attempt)
                }
            }
        }
        
        function Get-SanitizedFilename {
            param([string]$Filename)
            
            $invalid = [System.IO.Path]::GetInvalidFileNameChars()
            $sanitized = $Filename
            
            foreach ($char in $invalid) {
                $sanitized = $sanitized.Replace($char, '_')
            }
            
            $sanitized = $sanitized.Replace(':', ' -')
            $sanitized = $sanitized.Replace('/', '-')
            $sanitized = $sanitized.Replace('\', '-')
            $sanitized = $sanitized.Replace('|', '-')
            $sanitized = $sanitized.Replace('"', "'")
            
            $sanitized = $sanitized.Trim()
            $sanitized = $sanitized -replace '\s+', ' '
            $sanitized = $sanitized -replace '_+', '_'
            
            if ($sanitized.Length -gt 200) {
                $sanitized = $sanitized.Substring(0, 200).Trim()
            }
            
            return $sanitized
        }
        
        function Get-BestVideoRecording {
            param([array]$Recordings)
            
            $videoRecordings = $Recordings | Where-Object { 
                $_.mime_type -in @('video/mp4', 'video/webm')
            }
            
            if ($videoRecordings.Count -eq 0) {
                return $null
            }
            
            $mp4Videos = $videoRecordings | Where-Object { $_.mime_type -eq 'video/mp4' }
            $webmVideos = $videoRecordings | Where-Object { $_.mime_type -eq 'video/webm' }
            
            if ($mp4Videos.Count -gt 0) {
                $best = $mp4Videos | Sort-Object -Property @{Expression={$_.height}; Descending=$true}, @{Expression={$_.width}; Descending=$true} | Select-Object -First 1
                return $best
            }
            
            if ($webmVideos.Count -gt 0) {
                $best = $webmVideos | Sort-Object -Property @{Expression={$_.height}; Descending=$true}, @{Expression={$_.width}; Descending=$true} | Select-Object -First 1
                Write-Verbose "Using WebM fallback for recording (no MP4 available)"
                return $best
            }
            
            return $null
        }
        
        function New-NFOFile {
            param(
                [string]$Path,
                [hashtable]$Metadata
            )
            
            if ((Test-Path -LiteralPath $Path) -and -not $Force) {
                Write-Verbose "NFO exists: $Path"
                return @{ Skipped = 1 }
            }
            
            $xml = New-Object System.Xml.XmlDocument
            $declaration = $xml.CreateXmlDeclaration("1.0", "UTF-8", $null)
            [void]$xml.AppendChild($declaration)
            
            $movie = $xml.CreateElement("movie")
            [void]$xml.AppendChild($movie)
            
            if ($Metadata.Title) {
                $titleNode = $xml.CreateElement("title")
                $titleNode.InnerText = $Metadata.Title
                [void]$movie.AppendChild($titleNode)
                
                $origTitleNode = $xml.CreateElement("originaltitle")
                $origTitleNode.InnerText = $Metadata.Title
                [void]$movie.AppendChild($origTitleNode)
            }
            
            if ($Metadata.Subtitle) {
                $subtitleNode = $xml.CreateElement("tagline")
                $subtitleNode.InnerText = $Metadata.Subtitle
                [void]$movie.AppendChild($subtitleNode)
            }
            
            if ($Metadata.Description) {
                $plotNode = $xml.CreateElement("plot")
                $plotNode.InnerText = $Metadata.Description
                [void]$movie.AppendChild($plotNode)
                
                $outlineNode = $xml.CreateElement("outline")
                $outlineNode.InnerText = $Metadata.Description.Substring(0, [Math]::Min(200, $Metadata.Description.Length))
                [void]$movie.AppendChild($outlineNode)
            }
            
            if ($Metadata.Length) {
                $runtimeNode = $xml.CreateElement("runtime")
                $runtimeNode.InnerText = [math]::Round($Metadata.Length / 60)
                [void]$movie.AppendChild($runtimeNode)
            }
            
            if ($Metadata.ReleaseDate) {
                $releaseDateStr = if ($Metadata.ReleaseDate -is [DateTime]) {
                    $Metadata.ReleaseDate.ToString("yyyy-MM-dd")
                } elseif ($Metadata.ReleaseDate -is [string]) {
                    $Metadata.ReleaseDate
                } else {
                    $Metadata.ReleaseDate.ToString()
                }
                
                $releasedNode = $xml.CreateElement("premiered")
                $releasedNode.InnerText = $releaseDateStr
                [void]$movie.AppendChild($releasedNode)
                
                $airedNode = $xml.CreateElement("aired")
                $airedNode.InnerText = $releaseDateStr
                [void]$movie.AppendChild($airedNode)
                
                $yearNode = $xml.CreateElement("year")
                $yearNode.InnerText = $releaseDateStr.Substring(0, 4)
                [void]$movie.AppendChild($yearNode)
            }
            
            if ($Metadata.Tags) {
                foreach ($tag in $Metadata.Tags) {
                    $tagNode = $xml.CreateElement("tag")
                    $tagNode.InnerText = $tag
                    [void]$movie.AppendChild($tagNode)
                    
                    $genreNode = $xml.CreateElement("genre")
                    $genreNode.InnerText = $tag
                    [void]$movie.AppendChild($genreNode)
                }
            }
            
            if ($Metadata.Persons) {
                foreach ($person in $Metadata.Persons) {
                    $actorNode = $xml.CreateElement("actor")
                    
                    $nameNode = $xml.CreateElement("name")
                    $nameNode.InnerText = $person
                    [void]$actorNode.AppendChild($nameNode)
                    
                    $roleNode = $xml.CreateElement("role")
                    $roleNode.InnerText = "Speaker"
                    [void]$actorNode.AppendChild($roleNode)
                    
                    [void]$movie.AppendChild($actorNode)
                }
            }
            
            if ($Metadata.PosterUrl) {
                $posterNode = $xml.CreateElement("thumb")
                $posterNode.SetAttribute("aspect", "poster")
                $posterNode.InnerText = $Metadata.PosterUrl
                [void]$movie.AppendChild($posterNode)
            }
            
            if ($Metadata.ThumbUrl) {
                $thumbNode = $xml.CreateElement("thumb")
                $thumbNode.SetAttribute("aspect", "thumb")
                $thumbNode.InnerText = $Metadata.ThumbUrl
                [void]$movie.AppendChild($thumbNode)
            }
            
            if ($Metadata.Width -and $Metadata.Height) {
                $fileinfoNode = $xml.CreateElement("fileinfo")
                $streamdetailsNode = $xml.CreateElement("streamdetails")
                $videoNode = $xml.CreateElement("video")
                
                $widthNode = $xml.CreateElement("width")
                $widthNode.InnerText = $Metadata.Width
                [void]$videoNode.AppendChild($widthNode)
                
                $heightNode = $xml.CreateElement("height")
                $heightNode.InnerText = $Metadata.Height
                [void]$videoNode.AppendChild($heightNode)
                
                $codecNode = $xml.CreateElement("codec")
                $codecNode.InnerText = "h264"
                [void]$videoNode.AppendChild($codecNode)
                
                [void]$streamdetailsNode.AppendChild($videoNode)
                [void]$fileinfoNode.AppendChild($streamdetailsNode)
                [void]$movie.AppendChild($fileinfoNode)
            }
            
            if ($Metadata.Guid) {
                $uniqueidNode = $xml.CreateElement("uniqueid")
                $uniqueidNode.SetAttribute("type", "mediaccc")
                $uniqueidNode.SetAttribute("default", "true")
                $uniqueidNode.InnerText = $Metadata.Guid
                [void]$movie.AppendChild($uniqueidNode)
            }
            
            if ($Metadata.Conference) {
                $studioNode = $xml.CreateElement("studio")
                $studioNode.InnerText = $Metadata.Conference
                [void]$movie.AppendChild($studioNode)
            }
            
            if ($Metadata.FrontendLink) {
                $commentNode = $xml.CreateElement("comment")
                $commentNode.InnerText = "Source: $($Metadata.FrontendLink)"
                [void]$movie.AppendChild($commentNode)
            }
            
            if (-not $DryRun) {
                $settings = New-Object System.Xml.XmlWriterSettings
                $settings.Indent = $true
                $settings.IndentChars = "  "
                $settings.Encoding = [System.Text.Encoding]::UTF8
                
                $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
                $xml.Save($writer)
                $writer.Close()
                
                return @{ NfoCreated = 1 }
            }
            else {
                Write-Host "  [DryRun] Would create: $Path" -ForegroundColor DarkGray
                return @{}
            }
        }
        
        function New-STRMFile {
            param(
                [string]$Path,
                [string]$StreamUrl
            )
            
            if ((Test-Path -LiteralPath $Path) -and -not $Force) {
                Write-Verbose "STRM exists: $Path"
                return @{ Skipped = 1 }
            }
            
            if (-not $DryRun) {
                $StreamUrl | Out-File -LiteralPath $Path -Encoding ascii -NoNewline
                return @{ StrmCreated = 1 }
            }
            else {
                Write-Host "  [DryRun] Would create: $Path" -ForegroundColor DarkGray
                Write-Host "  [DryRun] URL: $StreamUrl" -ForegroundColor DarkGray
                return @{}
            }
        }
        
        function Get-ConferenceFromAPI {
            param([string]$ConferenceUrl)
            
            $endpoint = $ConferenceUrl -replace '^https?://[^/]+/public/', ''
            Write-Verbose "Fetching conference: $endpoint"
            return Invoke-APIRequest -Endpoint $endpoint
        }
        
        function Get-EventFromAPI {
            param([string]$EventUrl)
            
            $endpoint = $EventUrl -replace '^https?://[^/]+/public/', ''
            Write-Verbose "Fetching event: $endpoint"
            return Invoke-APIRequest -Endpoint $endpoint
        }
        
        function Process-Event {
            param(
                [object]$EventSummary,
                [string]$BasePath,
                [string]$ConferenceTitle
            )
            
            try {
                $eventDetails = Get-EventFromAPI -EventUrl $EventSummary.url
                if (-not $eventDetails) {
                    Write-Log "Skipping event (API fetch failed): $($EventSummary.title)" -Level WARN
                    return @{ Skipped = 1 }
                }
                
                $bestRecording = Get-BestVideoRecording -Recordings $eventDetails.recordings
                if (-not $bestRecording) {
                    Write-Log "No video recording (MP4/WebM) found for: $($EventSummary.title)" -Level WARN
                    return @{ Skipped = 1 }
                }
                
                $format = if ($bestRecording.mime_type -eq 'video/mp4') { 'MP4' } else { 'WebM' }
                Write-Verbose "Using $format for: $($EventSummary.title) (${bestRecording.width}x${bestRecording.height})"
                
                $safeTitle = Get-SanitizedFilename -Filename $eventDetails.title
                
                $strmPath = Join-Path $BasePath "$safeTitle.strm"
                $strmResult = New-STRMFile -Path $strmPath -StreamUrl $bestRecording.recording_url
                
                $metadata = @{
                    Title = $eventDetails.title
                    Subtitle = $eventDetails.subtitle
                    Description = $eventDetails.description
                    Length = $eventDetails.length
                    ReleaseDate = $eventDetails.release_date
                    Tags = $eventDetails.tags
                    Persons = $eventDetails.persons
                    PosterUrl = $eventDetails.poster_url
                    ThumbUrl = $eventDetails.thumb_url
                    Width = $bestRecording.width
                    Height = $bestRecording.height
                    Guid = $eventDetails.guid
                    Conference = $ConferenceTitle
                    FrontendLink = $eventDetails.frontend_link
                }
                
                $nfoPath = Join-Path $BasePath "$safeTitle.nfo"
                $nfoResult = New-NFOFile -Path $nfoPath -Metadata $metadata
                
                Write-Verbose "Processed: $safeTitle (${bestRecording.width}x${bestRecording.height})"
                
                return @{
                    EventProcessed = 1
                    StrmCreated = $strmResult.StrmCreated
                    NfoCreated = $nfoResult.NfoCreated
                    Skipped = ($strmResult.Skipped + $nfoResult.Skipped)
                }
            }
            catch {
                Write-Log "Error processing event $($EventSummary.title): $_" -Level ERROR
                return @{ Error = 1 }
            }
        }
        
        # Process the conference
        $conference = $_
        $localStats = @{
            EventsProcessed = 0
            StrmFilesCreated = 0
            NfoFilesCreated = 0
            Errors = 0
            Skipped = 0
        }
        
        try {
            $acronym = $conference.acronym
            Write-Log "Processing conference: $($conference.title) ($acronym)" -Level INFO
            
            $conferenceData = Get-ConferenceFromAPI -ConferenceUrl $conference.url
            if (-not $conferenceData) {
                Write-Log "Failed to fetch conference data for: $acronym" -Level ERROR
                return @{ Error = 1; ConferenceProcessed = 0 }
            }
            
            $events = $conferenceData.events
            if (-not $events -or $events.Count -eq 0) {
                Write-Log "No events found for: $acronym" -Level WARN
                return @{ ConferenceProcessed = 0 }
            }
            
            $webgenLocation = $conference.webgen_location
            
            # Use full webgen_location path to preserve top-level folders
            # (conferences, congress, events, documentations, etc.)
            $conferencePath = Join-Path $OutputPath $webgenLocation
            
            if (-not $DryRun) {
                if (-not (Test-Path $conferencePath)) {
                    New-Item -Path $conferencePath -ItemType Directory -Force | Out-Null
                    Write-Verbose "Created directory: $conferencePath"
                }
            }
            else {
                Write-Host "[DryRun] Would create directory: $conferencePath" -ForegroundColor DarkGray
            }
            
            Write-Log "Processing $($events.Count) events in $acronym..." -Level INFO
            
            $eventIndex = 0
            foreach ($event in $events) {
                $eventIndex++
                
                # Show progress for this conference
                $percentComplete = [Math]::Round(($eventIndex / $events.Count) * 100)
                Write-Progress -Activity "[$acronym] Processing Events" `
                              -Status "Event $eventIndex of $($events.Count): $($event.title)" `
                              -PercentComplete $percentComplete `
                              -Id ([math]::Abs($acronym.GetHashCode()))
                
                $eventResult = Process-Event -EventSummary $event -BasePath $conferencePath -ConferenceTitle $conference.title
                
                $localStats.EventsProcessed += $eventResult.EventProcessed
                $localStats.StrmFilesCreated += $eventResult.StrmCreated
                $localStats.NfoFilesCreated += $eventResult.NfoCreated
                $localStats.Errors += $eventResult.Error
                $localStats.Skipped += $eventResult.Skipped
            }
            
            # Complete the progress bar for this conference
            Write-Progress -Activity "[$acronym] Processing Events" -Completed -Id ([math]::Abs($acronym.GetHashCode()))
            
            Write-Log "Completed ${acronym}: $($localStats.EventsProcessed) events, $($localStats.StrmFilesCreated) STRM files, $($localStats.NfoFilesCreated) NFO files" -Level SUCCESS
            
            return @{
                ConferenceProcessed = 1
                EventsProcessed = $localStats.EventsProcessed
                StrmFilesCreated = $localStats.StrmFilesCreated
                NfoFilesCreated = $localStats.NfoFilesCreated
                Errors = $localStats.Errors
                Skipped = $localStats.Skipped
            }
        }
        catch {
            Write-Log "Error processing conference $($conference.acronym): $_" -Level ERROR
            return @{ Error = 1; ConferenceProcessed = 0 }
        }
        
    } -ThrottleLimit 5 | ForEach-Object {
        # Aggregate results from parallel processing
        $script:Stats.ConferencesProcessed += $_.ConferenceProcessed
        $script:Stats.EventsProcessed += $_.EventsProcessed
        $script:Stats.StrmFilesCreated += $_.StrmFilesCreated
        $script:Stats.NfoFilesCreated += $_.NfoFilesCreated
        $script:Stats.Errors += $_.Errors
        $script:Stats.Skipped += $_.Skipped
        
        # Update overall progress
        $completedCount = $script:Stats.ConferencesProcessed
        $percentComplete = if ($totalConferences -gt 0) { 
            [Math]::Round(($completedCount / $totalConferences) * 100) 
        } else { 0 }
        
        Write-Progress -Activity "Overall Progress: Processing Media CCC Library" `
                      -Status "$completedCount of $totalConferences conferences completed | $($script:Stats.EventsProcessed) events, $($script:Stats.StrmFilesCreated) STRM files, $($script:Stats.NfoFilesCreated) NFO files" `
                      -PercentComplete $percentComplete `
                      -Id 0
    }
    
    Write-Progress -Activity "Overall Progress: Processing Media CCC Library" -Completed -Id 0
    
    # Print summary
    Write-Log "`n=== Generation Complete ===" -Level SUCCESS
    Write-Log "Conferences Processed: $($script:Stats.ConferencesProcessed)" -Level INFO
    Write-Log "Events Processed: $($script:Stats.EventsProcessed)" -Level INFO
    Write-Log "STRM Files Created: $($script:Stats.StrmFilesCreated)" -Level SUCCESS
    Write-Log "NFO Files Created: $($script:Stats.NfoFilesCreated)" -Level SUCCESS
    Write-Log "Files Skipped: $($script:Stats.Skipped)" -Level INFO
    Write-Log "Errors: $($script:Stats.Errors)" -Level $(if ($script:Stats.Errors -gt 0) { 'WARN' } else { 'INFO' })
    
    if (-not $DryRun) {
        Write-Log "`nNext Steps:" -Level INFO
        Write-Log "1. Add '$OutputPath' as a library in Jellyfin" -Level INFO
        Write-Log "2. Set content type to 'Movies' or 'Other Videos'" -Level INFO
        Write-Log "3. Run library scan in Jellyfin" -Level INFO
        Write-Log "4. Jellyfin will read the .nfo files for metadata" -Level INFO
    }
}

# Entry point
try {
    Main
}
catch {
    Write-Log "Fatal error: $_" -Level ERROR
    Write-Log $_.ScriptStackTrace -Level ERROR
    exit 1
}

#endregion
