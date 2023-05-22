' Automai AIChannel launch script
' Must launch with Argument of "citrix", "avd", "rdp", or a UNC path
On Error Resume Next
Set objShell = WScript.CreateObject("WScript.Shell")
If WScript.Arguments.Count > 0 Then
    strRDSEnv = LCase(WScript.Arguments(0))
Else
    WScript.Echo "Please specify the remote desktop environment or UNC path as the first argument"
    WScript.Quit
End If

' Set the AIChannel path based on the remote desktop environment
Select Case strRDSEnv
    Case "citrix"
        aichannelpath = """\\Client\C$\Program Files\Automai\AIChannel\AIChannel.exe"""
    Case "avd", "rdp"
        aichannelpath = """\\TSClient\C\Program Files\Automai\AIChannel\AIChannel.exe"""
    Case Else
        If Left(strRDSEnv, 2) = "\\" Then
            aichannelpath = """" & strRDSEnv & "\Automai\AIChannel\AIChannel.exe"""
        Else
            WScript.Echo "Invalid remote desktop environment or UNC path specified. Please use citrix, avd, rdp, or a UNC path starting with \\."
            WScript.Quit
        End If
End Select

' Launch AIChannel via remote drive mapping
objShell.Run aichannelpath, 0, True
