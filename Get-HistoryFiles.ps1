function Get-HistoryFiles {
<#
.SYNOPSIS
    Get-HistoryFiles attempts to locate History database files for commonly used enterprise browsers such as Google Chrome, Microsoft Edge and Mozilla Firefox.

.DESCRIPTION
    Get-HistoryFiles allows you to locate History database files for common web browsers. If run with no arguments, it will attempt to locate
    and enuemrate the full paths for all History files discovered. If run with the -Gather argument, it will attempt to stage
    the history files into a disparate location before archiving it for easy retrieval.

.PARAMETER TargetUser
    Specifies the User ID (SamAccountName) of the target user whose History files you wish to retrieve.
    This is important because the History files are typically located within a specific user profile. If not

.PARAMETER Destination
    This is the location in which the discovered History files and ZIP archive will be staged for retrieval.
    This argument has no effect unless the -Gather argument is also specified. If unspecified, the default 
    staging location is $env:APPDATA.

.PARAMETER Gather
    Specifying this switch instructs Get-HistoryFiles to attempt to stage and archive the discovered History files
    to the staging Destination. The staging directory will be removed leaving only the final archive.

.PARAMETER Suppress
    If specified, all output from this script should be suppressed including errors and writes to the stdout stream.

.EXAMPLE
    If you just want to quickly find where a user's History files reside, you can run the following:

    Get-HistoryFiles -TargetUser "USERNAME"

.EXAMPLE 
    To gather and archive all of the History files of the target user's default AppData directory ($env:APPDATA) with Verbose logging
    you could run the following:

    Get-HistoryFiles -TargetUser "USERNAME" -Gather -Verbose

.LINK
    None
#>
    [CmdletBinding()]
    Param (
        [Parameter()]
        [string]
        $TargetUser = $env:USERNAME,
        [Parameter()]
        [string]
        $Destination = $env:APPDATA,
        [Parameter()]
        [switch]$Gather,
        [Parameter()]
        [switch]$Suppress
    )

    If ($Suppress) {
        $ErrorActionPreference = 'SilentlyContinue'
        $VerbosePreference = 'SilentlyContinue'
    }

    $masterHash = [ordered]@{
        TargetInfo = @{
            Computer = (Get-CimInstance -ClassName Win32_ComputerSystem).Name;
            OutPath = $Destination
        }

        HistoryPaths = @{
        Chrome = "$env:SystemDrive\Users\$TargetUser\AppData\Local\Google\Chrome\User Data";
        Edge = "$env:SystemDrive\Users\$TargetUser\AppData\Local\Microsoft\Edge\User Data";
        Firefox = "$env:SystemDrive\Users\$TargetUser\AppData\Roaming\Mozilla\Firefox";
        }

        Guid = (New-Guid | select -expand Guid)
    }

    Write-Verbose "GUID: $($masterHash.Guid)"
    Write-Verbose "Searching for history files..."

    try {
        $testPaths = @{
            isChrome = (Get-ChildItem -Path $masterHash.HistoryPaths.Chrome -Filter "History" -Recurse | select -expand FullName)
            isEdge = (Get-ChildItem -Path $masterHash.HistoryPaths.Edge -Filter "History" -Recurse | select -expand FullName)
            isFirefox = (Get-ChildItem -Path $masterHash.HistoryPaths.Firefox -Filter "places.sqlite" -Recurse | select -expand FullName)
        }

        $arrFiles = @()

        Write-Verbose "Chrome files found:"
        ForEach ($path in $testPaths.isChrome) {
            Write-Verbose $path
            $arrFiles += $path
        }
        Write-Verbose "Edge files found:"
        ForEach ($path in $testPaths.isEdge) {
            Write-Verbose $path
            $arrFiles += $path
        }
        Write-Verbose "Firefox files found:"
        ForEach ($path in $testPaths.isFirefox) {
            Write-Verbose $path
            $arrFiles += $path
        }
        If (!($Suppress)) {
            Write-Output "The follow history files were located:"
            Write-Output $arrFiles
        }
    } catch {
        Write-Error $Error
    }

        If ($Gather) {
            try {
                If (!(Test-Path -Path "$($masterHash.TargetInfo.OutPath)\$($masterHash.Guid)\")) {
                    New-Item -Path "$($masterHash.TargetInfo.OutPath)" -ItemType Directory -Name "$($masterHash.Guid)" -Force | Out-Null
                }

                New-Item -Path "$($masterHash.TargetInfo.OutPath)\$($masterHash.Guid)" -ItemType File -Name "$($masterHash.Guid).log" -Force | Out-Null
                $logFile = "$($masterHash.TargetInfo.OutPath)\$($masterHash.Guid)\$($masterHash.Guid).log"
                Add-Content -Path $logFile -Value "[INFO] Get-HistoryFiles`n[INFO] JobID: $($masterHash.Guid)`n[INFO] Hostname: $($masterHash.TargetInfo.Computer)`n[INFO] User: $TargetUser"
                $copyIncrement = 0
                ForEach ($file in $arrFiles) {
                    Write-Verbose "Copying $($file) to $($masterHash.TargetInfo.OutPath)"
                    Copy-Item -Path $file -Destination "$($masterHash.TargetInfo.OutPath)\$($masterHash.Guid)\history_db_$($copyIncrement)"
                    Add-Content -Path $logFile -Value "[INFO] $file copied to $($masterHash.TargetInfo.OutPath)\$($masterHash.Guid)\history_db_$($copyIncrement)"
                    $copyIncrement++
                }
                Add-Content -Path $logFile -Value "[INFO] Job completion at $(Get-Date)"
                Write-Verbose "[SUCCESS] Files copied!"

                $splatCompression = @{
                    Path = "$($masterHash.TargetInfo.OutPath)\$($masterHash.Guid)\"
                    CompressionLevel = "Fastest"
                    DestinationPath = "$($masterHash.TargetInfo.OutPath)\$($masterHash.Guid).zip"
                }

                Write-Verbose "Compressing retrieved files to archive"
                try {
                    Compress-Archive @splatCompression -Force
                    Write-Verbose "[SUCCESS] Compression finished!"
                } catch {
                    Write-Error $Error
                }

            } catch {
                Write-Error $Error
            } finally {
                Write-Verbose "Attempting to clean up staging artifacts"
                try {
                    Remove-Item -Path "$($masterHash.TargetInfo.OutPath)\$($masterHash.Guid)\" -Recurse -Force
                    Write-Verbose "[SUCCESS] Staging artifacts cleaned!"
                } catch {
                    Write-Error $Error
                }
            }
        }

}