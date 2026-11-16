' Runs a console program with no window and returns its exit code. It is the action of the scheduled task of
' tools/board-watch.ps1 (ADR 0007): Windows Terminal draws a window for any console program a task starts,
' even with -WindowStyle Hidden; wscript does not.
' Usage: wscript.exe //B //Nologo run-hidden.vbs <program> [arguments...]
Option Explicit
Dim shell, command, index, argument
If WScript.Arguments.Count = 0 Then WScript.Quit 2
command = ""
For index = 0 To WScript.Arguments.Count - 1
    argument = WScript.Arguments(index)
    ' WScript strips the quotes of each argument: put them back where a space needs them.
    If InStr(argument, " ") > 0 Then argument = Chr(34) & argument & Chr(34)
    command = command & argument & " "
Next
Set shell = CreateObject("WScript.Shell")
WScript.Quit shell.Run(Trim(command), 0, True)
