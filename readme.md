<a name="readme-top"></a>
<base target="_blank">
<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->

[![LinkedIn][linkedin-shield]][linkedin-url]
[![Twitter][twitter-shield]][twitter-url]

<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://www.automai.com/" target="_blank">
    <img src="https://www.automai.com/wp-content/uploads/2020/11/automai.svg" title="automai" alt="Logo" width="200" height="100">
  </a>

  <h3 align="center">EUC Automated Deployment</h3>

  <p align="center">
    A collection of scripts and tools to aid in the deployment of Automai software in an EUC environment
  </p>
</div>


<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <il><a href="#about-the-project">About The Project</a></il>
    <il><a href="#getting-started-videos">About The Project</a></il>
    <li><a href="#automai-server-deployment">Automai Management Server Deployment</a></li>   
    <ul><a href="#getting-started">Getting Started</a></ul>
    <ul><a href="#default-settings">Default Settings</a></ul>
    <ul><a href="#settings-customisation">Customising Settings</a></ul>
    <li><a href="#automai-session-server-deployment">Automai Session Server Deployment</a></li>
    <ul><a href="#asgetting-started">Getting Started</a></ul>
    <ul><a href="#asdefault-settings">Default Settings</a></ul>
    <li><a href="#automai-botmanager-deployment">Automai BotManager Deployment</a></li>
    <ul><a href="#bmdefault-settings">Default Settings</a></ul>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
## About The Project<a name="about-the-project"></a>

Automai Suite is a set of software tools that allow synthetic user testing and robotic process automation to be performed in a Windows environment. These tools are specifically addressing the end user computing industry.

There are three scripts within the PowerShell folder:
- Windows_Deploy.ps1 - This script will deploy an Automai Management Server on a Windows Server OS.
- Session_Hos_Deploy.ps1 - This script will deploy all required software and roles on Windows Server OS for the EUC test scenarios.
- BotManager_Deploy.ps1 - This script will deploy just the BotManager component of the automai suite.

 **ALL SCRIPTS MUST BE RUN FROM AN ADMINISTRATIVE POWERSHELL INSTANCE**

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Getting Started Videos
<a name="getting-started-videos"></a>
<p>There are several YouTube videos available which will walk you through the process of setting up an Automai PoC environment.</p>
<a href="https://www.youtube.com/watch?v=K4TD_PXHlOc" target="_blank">Automai Product Installation</a><br>
<a href="https://www.youtube.com/watch?v=l2iCA6Sc_68" target="_blank">Automai Product Licensing</a><br>
<a href="https://www.youtube.com/watch?v=mjC3qP4jypQ" target="_blank">Automai Workloads and Configuration</a><br>

## Automai Server Deployment
<a name="automai-server-deployment"></a>

<!-- GETTING STARTED -->
## Getting Started<a name="getting-started"></a>

All files necessary to deploy an Automai server with all components are stored in this repository. All that is needed to get started is the following command in an administrative PowerShell window on a Windows Server OS (2016 or above).

```sh
  Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/automai/AutomaiSuite-Deployment/main/PowerShell/Windows_Deploy.ps1'))
  ```
This command will automatically download the PowerShell script required and begin the installation process of all components.

### Default Settings<a name="default-settings"></a>
By default the script ran with no paramaters in Getting Started will perform the following actions:
1. Install the Windows Remote Desktop Services role
2. Install all Automai products in the default location of C:\Program Files
3. Create a folder in C: called Automai
4. Share the C:\Automai folder for "Everyone" to have modify access
5. Download assets for EUC and place then in C:\Automai
6. Download EUC workloads for Scenario Builder and place them in the current users documents
7. Create log files for all actions in C:\Windows\Temp
8. Prompt for log collection and will zip the logs up to be attached to a github issue later if there are any errors
9. Prompt for a reboot after all actions are complete

### Customising Settings<a name="settings-customisation"></a>
The script itself has a number of parameters, for a more customised deployment you may want to download the script and run it from PowerShell specifying any of the below parameters.

1. folderShare 
The name of the folder that will be created as a share for sessions to access
2. shareName 
The name of the share that all assets will be placed in
3. logLocation 
Log folder location, the log for the installation will be stored in C:\Temp unless changed
4. dateFormat 
The current date and time to be displayed in the name of the log files in "yyyy-MM-dd_HH-mm" format
5. shareUser 
The user or group that will have write access to the share created

_Below is an example of a command that can be run customising these parameters_

```sh
  & Windows_Deploy.ps1 -folderShare "C:\Automai" -shareName "Automai" -logLocation "C:\Windows\Temp" -dateFormat "yyyy-MM-dd_HH-mm" -shareUser "Everyone"
  ```
  This will create a folder in C:\Automai and share it with the share name of Automai with Everyone having modify access, logs will be stored in C:\Windows\Temp with the current year-month-day_hour-minute as the filename 

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Session Server Deployment 
<a name="automai-session-server-deployment"></a>

<!-- GETTING STARTED -->
## Getting Started<a name="asgetting-started"></a>

The only thing necessary to be able to deploy all applications to a session servers to work with the latest Automai EUC Workloads is in this repository. All that needs to be run is a single script which will handle everything else. Office, Chrome and MSEdge come directly from the vendors site, Firefox uses Chocolatey for its installation.

Below is an example command you can run to kick off the process.

```sh
  Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/automai/AutomaiSuite-Deployment/main/PowerShell/Session_Host_Deploy.ps1'))
  ```
This command will automatically download the PowerShell script required and begin the installation process of all software.

### Default Settings<a name="asdefault-settings"></a>
By default the script ran with no paramaters in Getting Started will perform the following actions:
1. Install the Windows Remote Desktop Services role
2. Install Office 365 Apps in Shared Computer Activation Mode
3. Install Google Chrome
4. Install Mozilla FireFox
5. Install Microsoft Edge Chromium
7. Create log files for all actions in C:\Windows\Temp
8. Prompt for log collection and will zip the logs up to be attached to a github issue later if there are any errors
9. Prompt for a reboot after all actions are complete

## Automai BotManager Deployment
<a name="automai-BotManager-deployment"></a>

<!-- GETTING STARTED -->
## Getting Started<a name="bmgetting-started"></a>

All files necessary to deploy an Automai BotManager are stored in this repository. All that is needed to get started is the following commands in an administrative PowerShell window on a Windows Server OS (2016 or above).

```sh
  Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/automai/AutomaiSuite-Deployment/main/PowerShell/BotManager_Deploy.ps1'))| Out-File "$($env:temp)\BotManager_Deploy.ps1"; & "$($env:temp)\BotManager_Deploy.ps1"
  ```

This command will automatically download the PowerShell script required and begin the installation process of all components. You will be prompted for specific variables.

You will need to supply:
- The name/IP of your Director Server
- The port Director uses to communicate (8888) by default
- The name of a location local to setup as an autologon account
- The password for the autologon account

### Default Settings<a name="bmdefault-settings"></a>
By default the script has to have the relevant parameters supplied to be able to run, the following actions will be performed:
1. Download the BotManager installer
2. Install BotManager with the provided parameters
3. Configure Windows Registry with AutoLogon Details
4. Share the C:\Automai folder for "Everyone" to have modify access

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- LICENSE -->
## License<a name="license"></a>

Distributed under the GNU 3 License. See `LICENSE` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- CONTACT -->
## Contact<a name="contact"></a>

Automai Corporation - [@AutomaiCorp](https://twitter.com/AutomaiCorp)

Project Link: [https://github.com/automai/AutomaiSuite-Deployment](https://github.com/automai/AutomaiSuite-Deployment)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[license-url]: https://raw.githubusercontent.com/automai/AutomaiSuite-Deployment/main/LICENSE{:target="_blank"}
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=for-the-badge&logo=linkedin&colorB=555
[linkedin-url]: https://www.linkedin.com/company/automai-corp/{:target="_blank"}
[twitter-shield]: https://img.shields.io/badge/-twitter-black.svg?style=for-the-badge&logo=twitter&colorB=555
[twitter-url]: https://twitter.com/AutomaiCorp{:target="_blank"}
