<#
.SYNOPSIS
Deploys Automai software on a Windows Server OS

.DESCRIPTION
Downloads all the necessary files from Github and extracts all installers and assets for installation and file placement.
Every action is logged with a transcript as well as a general log file, there is a setup log file for the Automai installer
All logs are stored in C:\Windows\Temp (if not specified) and are timestamped at the time of installation. If any errors are collected along
the way you will be prompted to be able to zip these and they can be used for later troubleshooting.

Installs the Terminal Services role, installs the full Automai Suite, Create a file share for everyone to access which
contains pre-requisites for the EUC workloads to run, places all necessary content in this folder and places the 
EUC Workloads in users documents to be accessed by scenario builder on first run.

.OUTPUTS
Log files and versbose loggging is present as the script runs. To review logs either use the console or view the
log files in C:\Windows\Temp or your custom log folder location.

.NOTES
You will be prompted to reboot your server at the end of the installation, it is required to continue.

.parameter folderShare 
The name of the folder that will be created as a share for sessions to access
.parameter shareName 
The name of the share that all assets will be placed in
.parameter logLocation 
Log folder location, the log for the installation will be stored in C:\Temp unless changed
.parameter dateFormat 
The current date and time to be displayed in the name of the log files in "yyyy-MM-dd_HH-mm" format
.parameter shareUser 
The user or group that will have write access to the share created
.parameter Unattend
Specify this is the call for the script requires no user interaction and is included in automation

.EXAMPLE
& Windows_Deploy.ps1 -folderShare "C:\Automai" -shareName "Automai" -logLocation "C:\Windows\Temp" -dateFormat "yyyy-MM-dd_HH-mm" -shareUser "Everyone"

This will create a folder in C:\Automai and share it with the share name of Automai with Everyone having modify access, 
logs will be stored in C:\Windows\Temp with the current year-month-day_hour-minute as the filename 
#>

## Environment specific variables which can be edited here or passed in the command line
[CmdletBinding()]
    param (
        [Parameter(Mandatory=$false, HelpMessage = "The name of the folder that will be created as a share for sessions to access")]
        [ValidateNotNullOrEmpty()]
        $folderShare = "C:\Automai", 

        [Parameter(Mandatory=$false, HelpMessage = "The name of the share that all assets will be placed in")]
        [ValidateNotNullOrEmpty()]
        $shareName = "Automai",

        [Parameter(Mandatory=$false, HelpMessage = "Log folder location, the log for the installation will be stored in C:\Temp unless changed")]
        [ValidateNotNullOrEmpty()]
        $logLocation = "C:\Windows\Temp",

        [Parameter(Mandatory=$false, HelpMessage = "The current date and time to be displayed in the name of the log files")]
        [ValidateNotNullOrEmpty()]
        $dateFormat = "yyyy-MM-dd_HH-mm",

        [Parameter(Mandatory=$false, HelpMessage = "The user or group that will have write access to the share created")]
        [ValidateNotNullOrEmpty()]
        $shareUser = "Everyone",

        [Parameter(Mandatory=$false, HelpMessage = "Specify if the script requires no user interaction and is included in automation")]
        [switch]$Unattend
)

## Fixed variables
$automaiDownload = "https://atmrap.s3.us-east-2.amazonaws.com/installers/testing/23.1.1/AutomaiSuite.exe"
$assetsDownload = "https://github.com/automai/AutomaiSuite-Deployment/raw/main/Assets/Share_Data.zip"
$workloadsDownload = "https://github.com/automai/AutomaiSuite-EUCScenarios/raw/main/EUC%20Workloads.zip"
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

#Create a folder share for session hosts to access specific automai files
try {
    #If the folder does not exist, create it
    if (Test-Path $FolderShare) {
        Write-Log -Message "Folder share in $($FolderShare) already exists, proceeding"
    } else {
        Write-Log -Message "Folder in $($FolderShare) does not exist creating it"
        New-Item -ItemType Directory -Path $FolderShare | Out-Null
    }
    #Double check everything was created correctly
    if (Test-Path $FolderShare) {
        Write-Log -Message "Folder in $($FolderShare) created successfully" -Level Info
    } else {
        Write-Log -Message "Error creating folder in $($FolderShare)" -Level Error
        Throw "Error creating folder in $($FolderShare)"
    }
} catch {
    Write-Log -Message $_ -Level Error
    $transciptStopped = Stop-Transcript
}

#Create share permissions
try {
    $checkResult = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
    #Check if the share already exists
    if ($checkResult.Name -eq $ShareName) {
        Write-Log -Message "Folder share in $($FolderShare) already exists, proceeding" -Level Info
    } else {
        Write-Log -Message "Folder share in $($FolderShare) not found, creating it" -Level Info
        New-SmbShare -Name "Automai" -Path $FolderShare -ChangeAccess $shareUser | Out-Null
    }    
} catch {
    Write-Log -Message $_ -Level Error
    $transciptStopped = Stop-Transcript
}

#Set permissions on the folder share
try {
    #Check the current access list and amend it
    $ACL = Get-Acl -Path $FolderShare
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($shareUser,"Modify","Allow")
    $ACL.SetAccessRule($accessRule)
    $ACL | Set-Acl -Path $folderShare
    Write-Log -Message "Successfully applied security permissions on $($folderShare)" -Level Info
} catch {
    Write-Log -Message $_ -Level Error
    $transciptStopped = Stop-Transcript
}

#Automai Software Installation
try {
    #Download the latest software
    Write-Log -Message "Attempting to download Automai Suite for installation" -Level Info
    Invoke-WebRequest -UseBasicParsing -Uri $automaiDownload -OutFile "$logLocation\AutomaiSuite_$($dateForLogFileName).exe"
    if (Test-Path "$logLocation\AutomaiSuite_$($dateForLogFileName).exe") {
        Write-Log -Message "AutomaiSuite software download completed successfully" -Level Info
        Start-Process -FilePath "$logLocation\AutomaiSuite_$($dateForLogFileName).exe" -ArgumentList "/VERYSILENT /LOG=$logLocation\Automai_Setup_Log.log /FORCECLOSEAPPLICATIONS"
        #Check if BotManager is running
        do {
            if (Get-Process "BotManager" -ErrorAction Ignore) {
                Get-Process "BotManager" | Stop-Process -Force
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
                Write-Log -Message "Automai Suite installed successfully" -Level Info
                break
            }
        } while ($loop -gt 0)
        
        #If the loop expired there was an issue installing
        if ($loop -eq 0) {
            Write-Log -Message "Error installing Automai Suite, please review the log in $logLocation\Automai_Setup_Log.log" -Level Info
            Throw "Error installing Automai Suite, please review the log in $logLocation\Automai_Setup_Log.log"
        }
    } else {
        Write-Log -Message "Software failed to download successfully, please check the download link and try again" -Level Error
        Throw "Software failed to download successfully, please check the download link and try again"
    }
} catch {
    Write-Log -Message $_ -Level Error
    $transciptStopped = Stop-Transcript
}

#Download and Configure Assets
try {
    Write-Log -Message "Attempting to download Automai Suite Assets" -Level Info
    Invoke-WebRequest -UseBasicParsing -Uri $assetsDownload -OutFile "$($folderShare)\AutomaiAssets_$($dateForLogFileName).zip"
    Invoke-WebRequest -UseBasicParsing -Uri $workloadsDownload -OutFile "$($folderShare)\EUCWorkloads_$($dateForLogFileName).zip"
    if (Test-Path "$($folderShare)\AutomaiAssets_$($dateForLogFileName).zip") {
        Write-Log -Message "Automai assets download completed successfully" -Level Info
        Expand-Archive -Path "$($folderShare)\AutomaiAssets_$($dateForLogFileName).zip" -DestinationPath $folderShare -Force
        if ((Test-Path "$($folderShare)\AIChannel.zip") -and (Test-Path "$($folderShare)\Content.zip")) {
            Write-Log -Message "Assets are complete and ready to be installed" -Level Info
            Expand-Archive -Path "$($folderShare)\AIChannel.zip" -DestinationPath "$($folderShare)\AIChannel" -Force
            Expand-Archive -Path "$($folderShare)\Content.zip" -DestinationPath $folderShare -Force
            Expand-Archive -Path "$($folderShare)\EUCWorkloads_$($dateForLogFileName).zip" -DestinationPath "$($folderShare)" -Force
            Write-Log -Message "Assets all extracted to $folderShare" -Level Info 
            if ("$folderShare\Content") {
              Write-Log -Message "Share content is located in \\$([System.Net.Dns]::GetHostByName($env:computerName).HostName)\$shareName\Content" -Level Info  
              Write-Log -Message "AI Channel is located in \\$([System.Net.Dns]::GetHostByName($env:computerName).HostName)\$shareName\Content" -Level Info
            } else {
                Write-Log -Message "There is an issue with the assets zip file and it is not complete or corrupted, contact automai support" -Level Error
                Throw "There is an issue with the assets zip file and it is not complete or corrupted, contact automai support"
            }
        } else {
            Write-Log -Message "There is an issue with the assets zip file and it is not complete or corrupted, contact automai support" -Level Error
            Throw "There is an issue with the assets zip file and it is not complete or corrupted, contact automai support"
        }
    } else {
        Write-Log -Message "Assets failed to download successfully, please check the download link and try again" -Level Error
        Throw "Assets failed to download successfully, please check the download link and try again"
    }
} catch {
    Write-Log -Message $_ -Level Error
    $transciptStopped = Stop-Transcript
}

#Copy workloads into ScenarioBuilder
try {
    if (Test-Path "$($folderShare)\EUC Workloads") {
        Write-Log -Message "Workloads are complete and ready to be installed" -Level Info
        #Check ScenarioBuilder folder before copy
        if (!(Test-Path "$($env:userprofile)\Documents\ScenarioBuilder")) {
            Write-Log -Message "ScenarioBuilder folder does not exist, creating it" -Level Info
            New-Item -ItemType Directory -Path "$($env:userprofile)\Documents\ScenarioBuilder" -Force | Out-Null
        }
        Write-Log -Message "Copying Scenarios into ScenarioBuilder" -Level Info
        Copy-Item -Path "$($folderShare)\EUC Workloads" -Destination "$($env:userprofile)\Documents\ScenarioBuilder" -Recurse -Force
        Write-Log -Message "Scenarios copied successfully" -Level Info
    } else {
        Write-Log -Message "There is an issue with the EUC Workloads zip file and it is not complete or corrupted, contact automai support" -Level Error
        Throw "There is an issue with the EUC Workloads zip file and it is not complete or corrupted, contact automai support"
    }
} catch {
    Write-Log -Message $_ -Level Error
    $transciptStopped = Stop-Transcript
}

#Output the relevant information to login
Write-Log -Message "NOTE THIS INFORMATION TO PROCEED AND GET STARTED" -Level Info  
Write-Log -Message "Share content is located in \\$([System.Net.Dns]::GetHostByName($env:computerName).HostName)\$shareName\Content" -Level Info  
Write-Log -Message "AI Channel is located in \\$([System.Net.Dns]::GetHostByName($env:computerName).HostName)\$shareName\Content" -Level Info
Write-Log -Message "Workloads are locationed in $($env:userprofile)\Documents\ScenarioBuilder\EUC Workloads" -Level Info
Write-Log -Message "Access Automai director by accessing http://$([System.Net.Dns]::GetHostByName($env:computerName).HostName):8888" -Level Info
Write-Log -Message "Username: admin - Password: automai" -Level Info

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
