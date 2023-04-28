<#
.SYNOPSIS
Deploys Automai BotManager software on a Windows Server OS

.DESCRIPTION
Downloads all the necessary files from Github and extracts all installers.
Every action is logged with a transcript as well as a general log file, there is a setup log file for the Automai BotManager installer
All logs are stored in C:\Windows\Temp (if not specified) and are timestamped at the time of installation. If any errors are collected along
the way you will be prompted to be able to zip these and they can be used for later troubleshooting.

Installs the Terminal Services role, installs the Automai BotManager and allows BotManager to register with a Director Instance.

.OUTPUTS
Log files and versbose loggging is present as the script runs. To review logs either use the console or view the
log files in C:\Windows\Temp or your custom log folder location.

.NOTES
You will be prompted to reboot your server at the end of the installation, it is required to continue.

.parameter logLocation 
Log folder location, the log for the installation will be stored in C:\Temp unless changed
.parameter dateFormat 
The current date and time to be displayed in the name of the log files in "yyyy-MM-dd_HH-mm" format
.parameter Unattend
Specify this is the call for the script requires no user interaction and is included in automation

.EXAMPLE
& Windows_Deploy.ps1 -logLocation "C:\Windows\Temp" -dateFormat "yyyy-MM-dd_HH-mm"

This will install Automai BotManager, logs will be stored in C:\Windows\Temp with 
the current year-month-day_hour-minute as the filename 
#>

## Environment specific variables which can be edited here or passed in the command line

[CmdletBinding()]
    param (
        [Parameter(Mandatory=$false, HelpMessage = "Log folder location, the log for the installation will be stored in C:\Temp unless changed")]
        [ValidateNotNullOrEmpty()]
        $logLocation = "C:\Windows\Temp",

        [Parameter(Mandatory=$false, HelpMessage = "The current date and time to be displayed in the name of the log files")]
        [ValidateNotNullOrEmpty()]
        $dateFormat = "yyyy-MM-dd_HH-mm",

        [Parameter(Mandatory=$true, HelpMessage = "The Director Server to join the BotManager")]
        [ValidateNotNullOrEmpty()]
        $directorServer,

        [Parameter(Mandatory=$true, HelpMessage = "The Director Server to port used for BotManager Communication")]
        [ValidateNotNullOrEmpty()]
        $directorServerPort="8888",

        [Parameter(Mandatory=$true, HelpMessage = "The user to create for AutoLogon")]
        [ValidateNotNullOrEmpty()]
        $autologonUser,

        [Parameter(Mandatory=$true, HelpMessage = "The password for the AutoLogon user")]
        [ValidateNotNullOrEmpty()]
        $autoLogonPassword,

        [Parameter(Mandatory=$false, HelpMessage = "Specify if the script requires no user interaction and is included in automation")]
        [switch]$Unattend
)

## Fixed variables
$automaiDownload = "https://atmrap.s3.us-east-2.amazonaws.com/installers/BotManagerSetup.exe"
$DateForLogFileName = $(Get-Date -Format $dateFormat)

#Start a transcript of the script output
$transcriptRunning = Start-Transcript -Path "$logLocation\automai_transcript_$($DateForLogFileName).log"

#Function for log file creation
Function Write-Log() {

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, HelpMessage = "The error message text to be placed into the log.")]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$Message,

        [Parameter(Mandatory=$false, HelpMessage = "The error level of the event.")]
        [ValidateSet("Error","Warn","Info")]
        [string]$Level="Info",

        [Parameter(Mandatory=$false, HelpMessage = "Specify to not overwrite or overwrite the previous log file.")]
        [switch]$NoClobber
    )

    Begin
    {
        # Set VerbosePreference to Continue so that verbose messages are displayed.
        $VerbosePreference = 'Continue'
    }
    Process
    {
        # append the date to the $path variable. It will also append .log at the end
        $logLocation = $logLocation + "\automai_install_" + $DateForLogFileName+".log"

        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
        If (!(Test-Path $logLocation)) {
            Write-Verbose "Creating $logLocation."
            New-Item $logLocation -Force -ItemType File
            }

        else {
            # Nothing to see here yet.
            }

        # Format Date for our Log File
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Write message to error, warning, or verbose pipeline and specify $LevelText
        switch ($Level) {
            'Error' {
                Write-Error $Message
                $LevelText = 'ERROR:'
                }
            'Warn' {
                Write-Warning $Message
                $LevelText = 'WARNING:'
                }
            'Info' {
                Write-Verbose $Message
                $LevelText = 'INFO:'
                }
            }

        # Write log entry to $Path
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $logLocation -Append
    }
    End
    {
    }
}

#Script start
Write-Log -Message "### Script Start ###"

#Check Administrative PowerShell 
Write-Log -Message "Checking Administrative PowerShell Launch" -Level Info
if ($Host.UI.RawUI.WindowTitle -notmatch "Administrator") {
    Write-Log "Please make sure your PowerShell instance is running as administrator or the script may fail" -Level Warn
    Start-Sleep -Seconds 2
}
if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { 
    Write-Log -Message "User is an admin on this machine, proceeding." -Level info
} else {
    Write-Log -Message "User is NOT an admin on this machine, please run as an admin or the script may fail" -Level Warn
    Start-Sleep -Seconds 2
}

#Output if unattended or not
##UnattendReplace##
Write-Log -Message "Unattended mode is $Unattend" -Level Info

#Check Windows OS
try {
    #If the OS is not a server based OS then terminal services cannot be installed
    if ((Get-ComputerInfo).OsProductType -eq "Server") {
        Write-Log -Message "Operating system detected as Windows Server, proceeding" -Level Info
    } else {
        Write-Log -Message "Operating system detected as Windows Client OS, Automai cannot be installed on Windows Client OS" -Level Error
        $transciptStopped = Stop-Transcript
        Exit
    }
} catch {
    Write-Log -Message $_ -Level Error
    $transciptStopped = Stop-Transcript
}

#Install the Windows Terminal Services Role
try {
    #Check if terminal services is already installed
    $checkResult = Get-WindowsFeature rds-rd-server -Verbose

    #If the role is already installed, proceed, otherwise; install it
    if ($checkResult.InstallState -eq "Available") {
        Write-Log -Message "The windows terminal services role is not currently installed, proceeding to install it" -Level Info
        $checkResult = Install-WindowsFeature rds-rd-server -IncludeManagementTools
        if (!($checkResult.ExitCode -eq "SuccessRestartRequired")) {
            Throw "Error installing Terminal Services"
        }
    } else {
        Write-Log -Message "The terminal services role is already installed, proceeding" -Level Info
    }
} catch {
    Write-Log -Message $_ -Level Error
    $transciptStopped = Stop-Transcript
}

#BotManager Software Installation
try {
    #Download the latest software
    Write-Log -Message "Attempting to download Automai BotManager for installation" -Level Info
    Invoke-WebRequest -UseBasicParsing -Uri $automaiDownload -OutFile "$logLocation\BotManagerSetup_$($dateForLogFileName).exe"
    if (Test-Path "$logLocation\BotManagerSetup_$($dateForLogFileName).exe") {
        Write-Log -Message "BotManager software download completed successfully" -Level Info
        Start-Process "$logLocation\BotManagerSetup_$($dateForLogFileName).exe" -ArgumentList "/VERYSILENT  /SUPPRESSMSGBOXES  /BASE=$directorServer  /PORT=$directorServerPort /USERNAME=$autologonUser  /PASS=$autoLogonPassword"
        
        #Check if BotManager is running
        do {
            if (Get-Process "BotManager" -ErrorAction Ignore) {
                #Kill all processes associated with BotManager Setup
                Get-Process "BotManager" | Stop-Process -Force
                Get-Process "SSConsole" | Stop-Process -Force -ErrorAction SilentlyContinue
                Get-Process "rProcess" | Stop-Process -Force -ErrorAction SilentlyContinue
                
                Write-Log -Message "BotManager found running, killing the process so the setup can proceed" -Level Info
                Break
            }
            Start-Sleep -Seconds 10
            Write-Log -Message "Waiting for 10 seconds before checking bot manager again" -Level Info
        } while (!(Get-Process "BotManager" -ErrorAction Ignore))
        
        #Wait for the service to start - 50 seconds
        $loop = 5
        do {
            $loop--
            Start-Sleep -Seconds 10
            if ($(Get-Service -Name "Automai BotManager").Status -eq "Running") {
                Write-Log -Message "Automai BotManager installed successfully" -Level Info
                #Start BotManager UI
                Start-Process -FilePath "$($env:programFiles)\Automai\BotManager\BotManager.exe" -Wait
                break
            }
        } while ($loop -gt 0)
        
        #If the loop expired there was an issue installing
        if ($loop -eq 0) {
            Write-Log -Message "Error installing Automai Suite, please review the log in $logLocation\Automai_Setup_Log.log" -Level Info
            Throw "Error installing Automai Suite, please review the log in $logLocation\Automai_Setup_Log.log"
        }
    } else {
        Throw "Automai Software failed to download successfully, please check the download link and try again"
    }
} catch {
    Write-Log -Message $_ -Level Error
    $transciptStopped = Stop-Transcript
}

#Gather logs if there was an error
if (($error.count -gt 1) -and (!($Unattend))) {
    #Show a dialog asking the user to gather logs
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Description."
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Description."
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $title = "Automai Log Collection"
    $message = "Some errors were detected during install, would you like to collect all the installation logs to be analysed later?"
    $result = $host.ui.PromptForChoice($title, $message, $options, 1)
        
    switch ($result) {
        0{
            New-Item -ItemType Directory -Path "$logLocation\AutomaiLogs" -Force | Out-Null
            Copy-Item -Path "$logLocation\Automai_*" -Destination "$logLocation\AutomaiLogs" -Exclude "exe" -Force
            Compress-Archive -Path "$logLocation\AutomaiLogs\*" -DestinationPath "$logLocation\Automai_Logs.zip" -Force
            Write-Log -Message "Gathering setup logs for later analysis, you will find a zip file in $logLocation\Automai_Logs.zip" -Level Info
            if (Test-Path "$logLocation\Automai_Logs.zip") {
                Write-Log -Message "Zip file created successfully in $logLocation\Automai_Logs.zip" -Level Info
                Remove-Item "$logLocation\AutomaiLogs" -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                Write-Log -Message "Failure collecting log files, please collect them manually" -Level Error
                Remove-Item "$logLocation\AutomaiLogs" -Recurse -Force -ErrorAction SilentlyContinue
            }
        }1{
            Write-Log -Message "Log collection skipped"
        }            
    }   
}

#Machine reboot dialog
if (!($Unattend)) {
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Description."
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Description."
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $title = "Machine reboot required"
    $message = "Changes have been made to your machine which require it to be rebooted, do you want to do this now?"
    $result = $host.ui.PromptForChoice($title, $message, $options, 1)
    switch ($result) {
        0{
            Write-Log -Message "Machine reboot accepted" -Level Info
            Restart-Computer -Force
        }1{
            Write-Log -Message "Machine reboot skipped" -Level Warn
        }
    }
} else {
    #As we are in unattended mode, reboot the computer
    Restart-Computer -Force
}

#Script stop
Write-Log -Message "### Script Stop ###"

#End the transcript if it has not already stopped
if (!($null -ne $transciptStopped)) {
    Stop-Transcript
}
