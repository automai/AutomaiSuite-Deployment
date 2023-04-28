' Automai AIChannel launch sciript
' Must launch with Argument of "citrix, avd, or rdp" 
on error resume next
Set objShell = WScript.CreateObject("WScript.Shell")
If WScript.Arguments.Count > 0 Then
    strRDSEnv = LCase(WScript.Arguments(0))
Else
    WScript.Echo "Please specify the remote desktop environment as the first argument (citrix, avd, or rdp)"
    WScript.Quit
End If

' Set the AIChannel path based on the remote desktop environment
If strRDSEnv = "citrix" Then
    aichannelpath = """\\Client\C$\Program Files\Automai\AIChannel\AIChannel.exe"""
ElseIf strRDSEnv = "avd" Or strRDSEnv = "rdp" Then
    aichannelpath = """\\TSClient\C\Program Files\Automai\AIChannel\AIChannel.exe"""
Else
    WScript.Echo "Invalid remote desktop environment specified. Please use citrix, avd, or rdp."
    WScript.Quit
End If

' Launch AIChannel via remote drive mapping
objShell.Run aichannelpath, 0, True
