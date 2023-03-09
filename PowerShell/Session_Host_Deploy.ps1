<#
.SYNOPSIS
Deploys all required applications for Automai workloads on a Windows Server OS

.DESCRIPTION
Installs the Terminal Services role, installs all applications required using Chocolatey and the EverGreen PowerShell module, the purpose of this script
is to provision a Windows Server that is readily able to run the Automai EUC workloads.
Software Installs:
- Microsoft Office 365 Apps
- Mozilla Firefox
- Google Chrome Enterprise
- Microsoft Edge Chromium

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
.parameter SBInstall
Specify if Scenario Builder should be downloaded and installed

.EXAMPLE
& Session_Host_Deploy.ps1

This will install chocolatey, the evergreen powershell module and perform all necessary software installs
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

        [Parameter(Mandatory=$false, HelpMessage = "Specify if the script requires no user interaction and is included in automation")]
        [switch]$Unattend,

        [Parameter(Mandatory=$false, HelpMessage = "Specify if Scenario Builder should be downloaded and installed")]
        [switch]$SBInstall
)

## Fixed variables
$automaiDownload = "https://atmrap.s3.us-east-2.amazonaws.com/installers/testing/23.1.1/AutomaiSuite.exe"
$innoExtractor = "https://raw.githubusercontent.com/automai/AutomaiSuite-Deployment/main/Assets/innoextract.exe"
$officeXML = "https://raw.githubusercontent.com/automai/AutomaiSuite-Deployment/main/Assets/Office.xml"
$DateForLogFileName = $(Get-Date -Format $dateFormat)

#Start a transcript of the script output
$transcriptRunning = Start-Transcript -Path "$logLocation\software_install_transcript_$($DateForLogFileName).log"

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
        $logLocation = $logLocation + "\software_install_" + $DateForLogFileName+".log"

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
##NoReboot##
##SBInstall##
##DirectorServer##
Write-Log -Message "Unattended mode is $Unattend" -Level Info
Write-Log -Message "No reboot required is $noReboot" -Level Info
Write-Log -Message "Scenario Builder install is $SBInstall" -Level Info

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

#Install chocolatey
try {
    #Command line downloads and run the install script for chocolatey
    Write-Log -Message "Installation of the Chocolatey started" -Level Info
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Write-Log -Message "Installation of the Chocolatey finished" -Level Info
} catch {
    Write-Log -Message $_ -Level Error
    $transciptStopped = Stop-Transcript
}

#Install NuGet Package Provider
Install-PackageProvider -Name NuGet -RequiredVersion 2.8.5.201 -Force

#Install Evergreen Module#
try {
    Write-Log -Message "Installation of the Evergreen module started" -Level Info
    Install-Module -Name Evergreen -Force
    Write-Log -Message "Installation of the Evergreen module finished" -Level Info
    Import-Module -Name Evergreen
} catch {
    Write-Log -Message $_ -Level Error
    $transciptStopped = Stop-Transcript
}

#Install Chocolately Apps
try {
    #Install Office
    try {        
        #Get the latest office version
        $app = Get-EvergreenApp -Name "Microsoft365Apps" | Where {$_.Channel -eq "MonthlyEnterprise"} | Sort Version | Select -First 1
        #Download the office XML file
        Invoke-WebRequest -UseBasicParsing -Uri $officeXML -OutFile "$logLocation\Office.xml"
        Invoke-WebRequest -UseBasicParsing -Uri $app.URI -OutFile "$logLocation\Office_Setup.exe"
        #Run the office installer
        Write-Log -Message "Installation of Office 365 started" -Level Info
        $installResult = Start-Process "$logLocation\Office_Setup.exe" "/configure $logLocation\Office.xml" -Wait -Passthru
        Write-Log -Message "Installation of Office 365 completed" -Level Info
    } catch {
        Write-Log -Message "There has been an error installation of Office" -Level Error 
    }

    #Install Firefox
    try {       
        Write-Log -Message "Installation of firefox started" -Level Info 
        $installResult = Start-Process choco -ArgumentList "install firefoxesr /NoAutoUpdate /RemoveDistributionDir -y" -Wait -PassThru
        Write-Log -Message "Installation of firefox completed" -Level Info
    } catch {
        Write-Log -Message "There has been an error installation Firefox" -Level Error 
    }

    #Install Chrome
    try {        
        #Get the latest Chrome version
        $app = Get-EvergreenApp -Name "GoogleChrome" | Where {($_.Channel -eq "stable") -and ($_.Architecture -eq "x86")} | sort version | Select -First 1
        Invoke-WebRequest -UseBasicParsing -Uri $app.URI -OutFile "$logLocation\Chrome_Setup.msi"
        #Run the office installer
        Write-Log -Message "Installation of chrome started" -Level Info
        $installResult = Start-Process msiexec -argumentList "/i $logLocation\Chrome_Setup.msi ALLUSERS=1 NOGOOGLEUPDATEPING=1 /qn" -Wait -Passthru
        Write-Log -Message "Installation of chrome finished" -Level Info
    } catch {
        Write-Log -Message "There has been an error installation of Chrome" -Level Error 
    }

    #Install MSEdge
    try {        
        #Get the latest MSEdge version
        $app = Get-EvergreenApp -Name "MicrosoftEdge" | Where {($_.Channel -eq "stable") -and ($_.Architecture -eq "x86")} | sort version | Select -First 1
        Invoke-WebRequest -UseBasicParsing -Uri $app.URI -OutFile "$logLocation\MSEdge.msi"
        #Run the office installer
        Write-Log -Message "Installation of MSEdge started" -Level Info
        $installResult = Start-Process msiexec -argumentList "/i $logLocation\MSEdge.msi ALLUSERS=1 REBOOT=ReallySupress /qn" -Wait -Passthru
        Write-Log -Message "Installation of MSEdge finished" -Level Info
    } catch {
        Write-Log -Message "There has been an error installation of Chrome" -Level Error 
    }

} catch {
    Write-Log -Message $_ -Level Error
    $transciptStopped = Stop-Transcript
}

#Automai Scenario Builder Installation
try {
    if ($SBInstall) {
        #Download the latest software
        Write-Log -Message "Attempting to download Automai Suite for installation" -Level Info
        Invoke-WebRequest -UseBasicParsing -Uri $automaiDownload -OutFile "$logLocation\AutomaiSuite_$($dateForLogFileName).exe"
        if (Test-Path "$logLocation\AutomaiSuite_$($dateForLogFileName).exe") {
            Write-Log -Message "AutomaiSuite software download completed successfully" -Level Info
            
            #Download Inno Extractor to extract the setup files for individual components
            Write-Log -Message "Attempting to download inno extractor" -Level Info
            Invoke-WebRequest -UseBasicParsing -Uri $innoExtractor -OutFile "$logLocation\innoextract.exe"
                        
            #Check inno extract
            if (Test-Path "$logLocation\innoextract.exe") {
                Write-Log -Message "Inno extractor downloaded successfully" -Level Info
                Start-Process -FilePath "$logLocation\innoextract.exe" -ArgumentList "$logLocation\AutomaiSuite_$($dateForLogFileName).exe"
                if (Test-Path "$logLocation\tmp\SBSetup.exe") {
                    if ($directorServer) {
                        Start-Process -FilePath "$logLocation\tmp\SBSetup.exe" -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /BASE=$directorServer /PORT=8888 /LOG=$logLocation\SB_Setup_Log.log"
                    } else {6
                        Start-Process -FilePath "$logLocation\tmp\SBSetup.exe" -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /LOG=$logLocation\SB_Setup_Log.log"
                    }
                } else {
                    Write-Log -Message "Scenario Builder could not be extracted from the Automai Suite download, Scenario Builder will not be installed" -Level Error
                }
            } else {
                Write-Log -Message "Inno extractor could not be downloaded and Scenario Builder will not be installed" -Level Error
            }
        }
    } else {
        Write-Log -Message "Software failed to download successfully, please check the download link and try again" -Level Error
        Throw "Software failed to download successfully, please check the download link and try again"
    }
} catch {
    Write-Log -Message $_ -Level Error
    $transciptStopped = Stop-Transcript
}

#Gather logs if there was an error
if (($error.count -gt 1) -and (!($Unattend))) {
    #Show a dialog asking the user to gather logs
    Write-Log -Message "Errors encountered - prompting user" -Level Info
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Description."
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Description."
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $title = "Automai Log Collection"
    $message = "Some errors were detected during install, would you like to collect all the installation logs to be analysed later?"
    [int]$result = $host.ui.PromptForChoice($title, $message, $options, 1) | Get-Member
        
    switch ($result) {
        0{
            New-Item -ItemType Directory -Path "$logLocation\AutomaiLogs" -Force | Out-Null
            Copy-Item -Path "$logLocation\software_install*" -Destination "$logLocation\AutomaiLogs" -Force
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
    Write-Log -Message "Not unattended - prompting user for reboot" -Level Info
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Description."
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Description."
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $title = "Machine reboot required"
    $message = "Changes have been made to your machine which require it to be rebooted, do you want to do this now?"
    [int]$result = $host.ui.PromptForChoice($title, $message, $options, 1)
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
    if (!($noReboot)) {
        Restart-Computer -Force
    }
}

#Script stop
Write-Log -Message "### Script Stop ###"

#End the transcript if it has not already stopped
if (!($null -ne $transciptStopped)) {
    Stop-Transcript
}

#End
