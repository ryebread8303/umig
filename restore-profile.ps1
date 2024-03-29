#______________________________________________________________________________
# restore-profile.ps1
# O'Ryan Hedrick
# 4/3/2018
#
# This script is the counterpart to backup-profile.ps1, and copies the user
# data from external media onto the new computer.
#
#______________________________________________________________________________

#requires -Version 2.0

param(
    $testrun = $false
    )

if ($testrun=$true){$DebugPreference = "Continue"}
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
if($testrun -eq $true){$robocopyargs += "/l","/v"}

function copy-profile {
    param([string]$source)
    $folderlist = @()
    Write-Debug "The source folder is: $source"
    new-item -type directory -path $env:userprofile\Documents\migrationlogs -debugpreference ContinueSilently
    Get-ChildItem $source | ForEach-Object {if ($_.mode -like "d*") {$folderlist += $_.name}}
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
        if ($null -ne $dest) {write-debug "Starting Copy"
            & robocopy $source\$folder $dest "*.*" $robocopyargs "/log:$env:userprofile\migrationlogs\$folder.txt"
            Write-Debug "Finished copying"
        } # end if
    } #end foreeach
} # end function


function get-profilelist {
$profiles = @()
Get-ChildItem | ForEach-Object {if ($_.mode -like "d*") {$profiles += $_.name}}
} # end function


function get-drivelist {
$drives = Get-WmiObject -class win32_logicaldisk | Where-Object {$_.drivetype -eq 2} | Select-Object deviceid
$drives
} # end function

Add-Type -AssemblyName PresentationFramework

function Create-WPFWindow {
    Param($Hash)

    #Create a window object
    $Window = New-Object System.Windows.Window
    $Window.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
    $Window.Title = "Restore User Profile"
    $Window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
    $Window.ResizeMode = [System.Windows.ResizeMode]::NoResize

    # Create a button object
    $buttonDrive = New-Object System.Windows.Controls.Button
    $buttonDrive.Height = 30
    $buttonDrive.HorizontalContentAlignment = "Center"
    $buttonDrive.VerticalContentAlignment = "Center"
    $buttonDrive.FontSize = 14
    $buttonDrive.Content = "Get Drive List"
    $Hash.buttonDrive = $buttonDrive

    #Create a label
    $labelDrive = New-Object System.Windows.Controls.Label
    $labelDrive.Height = 30
    $labelDrive.HorizontalContentAlignment = "Left"
    $labelDrive.VerticalContentAlignment = "Center"
    $labelDrive.FontSize = 14
    $labelDrive.Content = "Select external drive where profiles are stored."
    $Hash.labelDrive = $labelDrive

    # Create a list box for drives
    $comboDrive = New-Object System.Windows.Controls.comboBox
    $comboDrive.Height = 30
    $comboDrive.HorizontalContentAlignment = "Left"
    $comboDrive.VerticalContentAlignment = "Center"
    $comboDrive.FontSize = 14
    $Hash.comboDrive = $comboDrive

    #Create a label
    $labelProfile = New-Object System.Windows.Controls.Label
    $labelProfile.Height = 30
    $labelProfile.HorizontalContentAlignment = "Left"
    $labelProfile.VerticalContentAlignment = "Center"
    $labelProfile.FontSize = 14
    $labelProfile.Content = "Select a profile."
    $Hash.labelProfile = $labelProfile

    # Create a combo box for profiles
    $comboProfile = New-Object System.Windows.Controls.comboBox
    $comboProfile.Height = 30
    $comboProfile.HorizontalContentAlignment = "Left"
    $comboProfile.VerticalContentAlignment = "Center"
    $comboProfile.FontSize = 14
    $Hash.comboProfile = $comboProfile
    
    # Create a button object
    $buttonBegin = New-Object System.Windows.Controls.Button
    $buttonBegin.Height = 30
    $buttonBegin.HorizontalContentAlignment = "Center"
    $buttonBegin.VerticalContentAlignment = "Center"
    $buttonBegin.FontSize = 14
    $buttonBegin.Content = "Begin Restore."
    $Hash.buttonBegin = $buttonBegin

    # Assemble the window
    $stackPanel = New-Object System.Windows.Controls.StackPanel
    $stackPanel.Margin = "10,10,10,10"
    $stackPanel.AddChild($buttonDrive)
    $stackPanel.AddChild($labelDrive)
    $stackPanel.AddChild($comboDrive)
    $stackPanel.AddChild($labelProfile)
    $stackPanel.AddChild($comboProfile)
    $stackPanel.AddChild($buttonBegin)
    $Window.AddChild($stackPanel)
    $Hash.Window = $Window
}

$Hash = @{}
Create-WPFWindow $Hash

$Hash.buttonDrive.Add_Click{
    get-drivelist | ForEach-Object {$Hash.comboDrive.AddText($_.deviceid)}
}

$Hash.comboDrive.Add_SelectionChanged{
    $thing = $hash.comboDrive.SelectedItem
    Get-ChildItem -path $thing\umig | ForEach-Object {$hash.comboProfile.AddText($_)}
}

$hash.buttonBegin.Add_Click{
    $drive = $hash.comboDrive.SelectedItem
    $TargetProfile = $hash.comboProfile.SelectedItem

    copy-profile $drive\umig\$TargetProfile
    write-debug $drive\umig\$TargetProfile
}

# Create a datacontext for the comboBox and set it
#$DataContext = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
#get-drivelist | select deviceid | ForEach-Object { Write-Debug "Add $_ to data source." ;$DataContext.Add($_) }
#$DataContext = @("e:")
#$hash.comboDrive.DataContext = $DataContext

# Create and set a binding on the comboDrive object
#$Binding = New-Object System.Windows.Data.Binding # -ArgumentList "[0]"
#$Binding.Path = "[0]"
#$Binding.Mode = [System.Windows.Data.BindingMode]::OneWay
#[void][System.Windows.Data.BindingOperations]::SetBinding($Hash.comboDrive,[System.Windows.Controls.ComboBox]::SelectedItemProperty, $Binding)

# Show the window
[void]$Hash.Window.Dispatcher.InvokeAsync{$Hash.Window.ShowDialog()}.Wait()