#______________________________________________________________________________
# restore-profile.ps1
# O'Ryan Hedrick
# 5/22/2018
#
# This script is the counterpart to backup-profile.ps1, and copies the user
# data from external media onto the new computer.
#
#______________________________________________________________________________

#requires -Version 2.0

param(
    [switch]$testrun
    )

if ($testrun){$DebugPreference = "Continue"}
Write-Debug "Test Run"
<#
    Use the following arguments with robocopy.exe:
    /e copy all subdirectories, including empty ones
    /r:3 if copying a file fails, try three more times
    /w:5 if copying a file fails, wait 5 seconds before trying again
    /np do not display progress information, since no output is being sent to console
    /xj exclude junctions
#>
$robocopyargs = @('/e','/r:3','/w:5','/np','/xj')
<#
    If this is a testrun, use the following extra arguments
    /l only list files, do not copy
    /v verbose output
#>
if($testrun){$robocopyargs += "/l","/v"}

<#
    .SYNOPSIS
    Copy user specific data from the backup to a new machine.
    
    .DESCRIPTION
    The function is meant to be used in the restore-profile.ps1 part of UMIG.
    
    .PARAMETER Source
    This is a string containing the path to the user's data backup created by 
    the backup-profile.ps1 part of UMIG
    
    .INPUTS
    This function does not accept input from the pipeline.
    
    .OUTPUTS
    None.

    .EXAMPLES
    copy-profile F:\umig\oryan
    
    .NOTES
    Author: O'Ryan Hedrick
    Date: 05/22/2018
#>
function copy-profile {
    param([string]$source)
    # Initialize an empty array to hold the list of folders found in the backup
    $folderlist = @()
    # set the folder to create to hold logs from Robocopy
    $logfolder = "$env:userprofile\migrationlogs"
    Write-Debug "The source folder is: $source"
    Write-Debug "Logging to $logfolder"
    # if the log folder doesn't exist, create it
    if (-not(test-path $logfolder)){new-item -type directory -path $logfolder}
    # create the list of folders found in the backup
    gci $source | % {if ($_.mode -like "d*") {$folderlist += $_.name}}
    # for each folder, lookup where it should be copied to and use robocopy to
    # copy it
    foreach ($folder in $folderlist){
        switch ($folder){
            "Documents" {$dest = "$env:userprofile\Documents"}
            "Links" {$dest = "$env:userprofile\Links"}
            "Favorites" {$dest = "$env:userprofile\Favorites"}
            "Desktop" {$dest = "$env:userprofile\Desktop"}
            "Pictures" {$dest = "$env:userprofile\Pictures"}
            "Videos" {$dest = "$env:userprofile\Videos"}
            "History" {$dest = "$env:userprofile\appdata\local\Microsoft\Windows\History"}
            "Themes" {$dest = "$env:userprofile\appdata\local\Microsoft\Windows\Themes"}
            "Signatures" {$dest = "$env:appdata\Microsoft\Signatures"}
            "Templates" {$dest = "$env:appdata\Microsoft\Templates"}
            "Sticky Notes" {$dest = "$env:appdata\Microsoft\Sticky Notes"}
            default {$dest = $null}
        } # end switch
        Write-Debug "Copying from $source\$folder to $dest"
        if ($dest -ne $null) {write-debug "Starting Copy"
            & robocopy $source\$folder $dest "*.*" $robocopyargs "/log:$logfolder\$folder.txt"
            Write-Debug "Finished copying"
        } # end if
    } #end foreeach
} # end function


function get-profilelist {
param($folder)
$profiles = @()
$profiles = gci $folder | ? {$_.PSisContainer -eq $true} | select name
$profiles
} # end function


function get-drivelist {
$drivelist = @()
$drives = Get-WmiObject -class win32_logicaldisk | select deviceid
$drives
} # end function
<#
    .SYNOPSIS
    Prompt user to make a selection.
    
    .DESCRIPTION
    The new-menu function provides a cmdlet front-end to the $host.ui.promptforchoice prompts.
    
    .PARAMETER Options
    This is an array containing the options being presented to the user.
    
    .PARAMETER Caption
    This is a string containing the caption of the prompt.
    
    .PARAMETER Message
    This is a string containing the message in the prompt.

    .PARAMETER Multiple
    This is a switch that allows multiple selections from the menu

    .PARAMETER Default
    This should be an integer if Multiple is False, or an integer array if Multiple is True. This sets 
    an item or items as a default choice, so it will be selected if the user makes no selections.
    If -1, no defaults will be picked.
    
    .INPUTS
    This function does not accept input from the pipeline.
    
    .OUTPUTS
    This function outputs the index of the chosen menu option.

    .EXAMPLE
    New-Menu -Caption "Drink Selection" -Message "Pick your favorite drink" -Options @("Juice","Tea","Soda","Coffee")
    
    .NOTES
    Author: O'Ryan Hedrick
    Date: 05/21/2018
#>
function New-Menu {
    param([Parameter(mandatory = $true)][array]$Options,
        [string]$Caption,
        [string]$Message,
        [switch]$Multiple,
        $Default = -1)
    if ($Multiple) {$style = [int[]]($default)} else {$style = $default}
    $choices = [system.management.automation.host.choicedescription[]] $options
    $prompt = $host.ui.promptforchoice($caption,$message,$choices,$style)
    $prompt
} # function new-menu

# First user step is to select a drive to look for the backup on
$drivelist = get-drivelist
$driveindex = new-menu -Options $drivelist.deviceid -Caption 'Drive Select' -Message 'Please select a drive to restore from.'
$drive = $drivelist[$driveindex].deviceid

# Second user step is to select the profile within the backup folder
$profilelist = get-profilelist -folder $drive\umig
$profileindex = new-menu -Options $profilelist.name -Caption 'Profile Select' -Message 'Please select the profile to restore'
$selectedprofile = $profilelist[$profileindex].name

# start copying data
copy-profile $drive\umig\$selectedprofile