#______________________________________________________________________________
# backup-profile.ps1
# O'Ryan Hedrick
# 4/3/2018
# 
# This script copies files and folders from the users profile to external media
# for the purpose of migrating a user from one computer to another.
# 
# The script uses PowerShell 2, and should run on any Winows 7 machine without
# having to install software.
# _____________________________________________________________________________

#requires -Version 2.0
param(
    [switch]
    $TestRun
    )


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
    /xf * do not copy files, just the directory structure
    /v verbose output
#>
if($TestRun){$robocopyargs += "/xf","*","/v"}

function show-menu {
    <# 
    .Synopsis 
      Display a menu on the console. 
    .Parameter title
      This is a string that sets the title of the menu prompt
    .Parameter message
      This is a string that sets the detailed message in the menu prompt.
    .Parameter options
      This is an array of strings that sets the available options.
    .Parameter default
      This is an integer that sets the index of the default option.
    .Notes 
    NAME: Show-menu 
    AUTHOR: O'Ryan Hedrick 
    LASTEDIT: 8/17/2015 
    KEYWORDS: 
    #> 
    param(
        [parameter(mandatory=$true,position=0)][string]$title,
        [parameter(mandatory=$true,position=1)][string]$message,
        [parameter(mandatory=$false,position=2)][string[]]$options = @("&Yes","&No"),
        [parameter(mandatory=$false,position=3)][int]$default = 0
        )
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]$options
    $result = $host.ui.PromptForChoice($title, $message, $choices, $default)
    $options[$result]
}


function get-drivelist {
$drives = Get-WmiObject -class win32_logicaldisk | Where-Object {($_.drivetype -eq 2) -or ($_.drivetype -eq 3)} | Select-Object deviceid
$drives.deviceid
} # end function

# $folderlist is an array of all the folders to be copied
$folderlist = @("$env:userprofile\Documents",
    "$env:userprofile\Links",
    "$env:userprofile\Favorites",
    "$env:userprofile\Desktop",
    "$env:userprofile\Pictures",
    "$env:userprofile\Videos",
    "$env:userprofile\appdata\local\Microsoft\Windows\History",
    "$env:userprofile\appdata\local\Microsoft\Windows\Themes",
    "$env:appdata\Microsoft\Signatures",
    "$env:appdata\Microsoft\Templates",
    "$env:appdata\Microsoft\Sticky Notes")

#determine path to copy data to
$logicaldrives = get-drivelist
$targetdrive = show-menu -title "Target Drive" -message "Select an external drive to copy user data to." -options $logicaldrives
$target = "$targetdrive\umig\$env:username"
write-debug $target

#create a new folder to copy userdata to. If the folder already exists, error out so that the previously made backup can be moved or deleted.
if (test-path $target) {
    [system.reflection.assembly]::loadwithpartialname("system.windows.forms") | Out-Null
    [system.windows.forms.messagebox]::show("The destination folder $target already exists. Please delete or rename that folder and try again.", "Destination already exists") | Out-Null
    exit
} # end if
New-Item -ItemType directory -path $target -ErrorAction silentlycontinue

# for each folder in $folderlist, use robocopy to copy the folder and create a log file that details copy stats and a list of files copied
# the variable folderlist is piped to foreach-object, and each object passed is used as the source folder in the robocopy command
$folderlist | 
ForEach-object {
    $opts =  $null
    $dest = split-path $_ -leaf
    $opts = $robocopyargs + "-log:$target\$dest.txt"
    & robocopy $_ $target\$dest "*.*" $opts
} # end ForEach-object