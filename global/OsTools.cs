using Godot;
using System;
using System.IO;
using Environment = System.Environment;
using Mutex = System.Threading.Mutex;

public partial class OsTools : Node
{
    public void CheckSingleInstance()
    {
        // if another instance is launched...
        // using var mutex = new Mutex(true, "MvLOModLoaderA", out var createdNew);
        // if (createdNew)
        // {
        //     GD.Print("C#: no other instances found!");
        // }
        // else
        // {
        //     GD.Print("C#: another instance is already running...");
        // }
    }
    
    public string GetDekstopPath()
    {
        return Environment.GetFolderPath(Environment.SpecialFolder.Desktop);
    }

    public Error CreateFileShortcut(string description, string sourcePath, string extraArgs = "")
    {
        GD.Print($"C#: Creating shortcut {sourcePath} >> {GetDekstopPath()}...");
        var osName = OS.GetName();

        switch (osName)
        {
            case "Windows":
                return CreateFileShortcutWindows(description, sourcePath, extraArgs);
            case "Linux":
                return CreateFileShortcutLinux(description, sourcePath, extraArgs);
            default:
                GD.PrintErr($"C#: Shortcut creation failed: {osName} is incompatible!!");
                return Error.Failed;
        }
    }

    private Error CreateFileShortcutWindows(string description, string sourcePath, string extraArgs = "")
    {
        var script = $"""
                      Set shell = CreateObject("Wscript.Shell")
                      target = shell.SpecialFolders("Desktop") & "\" & "{description}" + ".lnk"
                      Set shortcut = shell.CreateShortcut(target)
                      shortcut.TargetPath = "{sourcePath}"
                      shortcut.Description = ""
                      """;
        if (!string.IsNullOrEmpty(extraArgs)) script += $"\nshortcut.Arguments = \"{extraArgs}\"";
        script += "\nshortcut.Save";
        
        var tempFile = Path.Combine(Path.GetTempPath(), "win-shortcutizer.vbs");
        File.WriteAllText(tempFile, script);
        var process = new System.Diagnostics.Process();
        process.StartInfo.FileName = "wscript.exe";
        process.StartInfo.Arguments = tempFile;
        process.StartInfo.CreateNoWindow = true;
        process.StartInfo.UseShellExecute = false;
        process.StartInfo.RedirectStandardOutput = true;
        process.StartInfo.RedirectStandardError = true;
        process.Start();
        process.WaitForExit();
        
        var exitCode = process.ExitCode;
        if (exitCode == 0)
        {
            GD.Print("C#: Done.");
            return Error.Ok;
        }
        GD.PrintErr($"C#: Shortcut creation failed: {process.StandardError.ReadToEnd()}");
        return Error.Failed;
    }

    private Error CreateFileShortcutLinux(string description, string sourcePath, string extraArgs = "")
    {
        var script = $"""
                      [Desktop Entry]
                      Name={description}
                      Exec={sourcePath} {extraArgs}
                      Terminal=false
                      Type=Application
                      StartupNotify=true
                      """;
        
        var desktopFile = Path.Combine(GetDekstopPath(), $"{description}.desktop");
        File.WriteAllText(desktopFile, script);
        var process = new System.Diagnostics.Process();
        process.StartInfo.FileName = "chmod";
        process.StartInfo.Arguments = $"+x {desktopFile}";
        process.StartInfo.UseShellExecute = false;
        process.StartInfo.RedirectStandardOutput = true;
        process.StartInfo.RedirectStandardError = true;
        process.StartInfo.CreateNoWindow = true;
        process.Start();
        process.WaitForExit();
        
        var exitCode = process.ExitCode;
        if (exitCode == 0)
        {
            GD.Print("C#: Done.");
            return Error.Ok;
        }
        GD.PrintErr($"C#: Shortcut creation failed: {process.StandardError.ReadToEnd()}");
        return Error.Failed;
    }
}
