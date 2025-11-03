# Media CCC Library Generator - Quick Examples

## Test with a single conference (Dry Run)
.\Generate-MediaCCCLibrary.ps1 -ConferenceFilter "38c3" -OutputPath "./test-output" -DryRun -Verbose

## Generate recent Chaos Communication Congresses
.\Generate-MediaCCCLibrary.ps1 -OutputPath "D:\Jellyfin\MediaCCC" -ConferenceFilter "38c3,37c3,36c3,35c3,34c3"

## Generate all Camp events
.\Generate-MediaCCCLibrary.ps1 -OutputPath "D:\Jellyfin\MediaCCC" -ConferenceFilter "camp2023,camp2019,camp2015"

## Update existing library (overwrite files)
.\Generate-MediaCCCLibrary.ps1 -OutputPath "D:\Jellyfin\MediaCCC" -ConferenceFilter "38c3" -Force

## Generate everything (WARNING: Takes 30-60 minutes, creates 30,000+ files)
.\Generate-MediaCCCLibrary.ps1 -OutputPath "D:\Jellyfin\MediaCCC"

## Find conference acronyms
# Browse https://media.ccc.de/b/conferences or use the API:
# https://api.media.ccc.de/public/conferences

## Popular conferences to consider:
# - Congress: 38c3, 37c3, 36c3, 35c3, 34c3, 33c3, 32c3, 31c3, 30c3
# - Camp: camp2023, camp2019, camp2015
# - GPN: gpn22, gpn21, gpn20, gpn19
# - FrOSCon: froscon2023, froscon2022, froscon2021
# - FOSDEM: fosdem2024, fosdem2023, fosdem2022
# - Security: mrmcd2023, eh2022, divoc2022
