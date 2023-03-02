<#
.SYNOPSIS
Deploys Citrix Workspace App
.DESCRIPTION
Downloads and installs the Citrix Workspace App
.OUTPUTS
Log files and versbose loggging is present as the script runs. To review logs either use the console or view the
log files in C:\Windows\Temp or your custom log folder location.
.NOTES

.parameter logLocation 
Log folder location, the log for the installation will be stored in C:\Temp unless changed
.parameter dateFormat 
The current date and time to be displayed in the name of the log files in "yyyy-MM-dd_HH-mm" format
.parameter Unattend
Specify this is the call for the script requires no user interaction and is included in automation
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
        $dateFormat = "yyyy-MM-dd_HH-mm"
)

## Fixed variables
$DateForLogFileName = $(Get-Date -Format $dateFormat)

#Start a transcript of the script output
$transcriptRunning = Start-Transcript -Path "$logLocation\citrixworkspace_install_transcript_$($DateForLogFileName).log"

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

#Install Chrome
    try {        
        #Get the latest Citrix Workspace app
        $app = Get-EvergreenApp -Name "CitrixWorkspaceApp" | Where {($_.Stream -eq "Current") -and ($_.Title -match "Workspace")}
        Invoke-WebRequest -UseBasicParsing -Uri $app.URI -OutFile "$logLocation\CitrixWorkspaceApp.exe"
        #Run the Workspace App Installer
        Write-Log -Message "Installation of Citrix Workspace App started" -Level Info
        $installResult = Start-Process "$logLocation\CitrixWorkspaceApp.exe" -argumentList "/noreboot /silent ALLOW_CLIENTHOSTEDAPPSURL=1 ALLOWSAVEPWD=A ALLOWADDSTORE=A  /ALLOW_BIDIRCONTENTREDIRECTION=1 /FORCE_LAA=1 EnableCEIP=false ADDLOCAL=ReceiverInside,ICA_Client,AM,SELFSERVICE,USB,DesktopViewer,Flash,Vd3d,Webhelper,BrowserEngine" -Wait -Passthru
        Write-Log -Message "Installation of Citrix Workspace App finished" -Level Info
    } catch {
        Write-Log -Message "There has been an error installation of Chrome" -Level Error 
    }

#Script stop
Write-Log -Message "### Script Stop ###"

#End the transcript if it has not already stopped
if (!($null -ne $transciptStopped)) {
    Stop-Transcript
}

#End
