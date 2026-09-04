using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;

class RunGame
{
    static void Main()
    {
        string dir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        string[] exes = Directory.GetFiles(dir, "Godot_v*.exe");
        if (exes.Length == 0) return;
        Array.Sort(exes);
        Process.Start(new ProcessStartInfo(exes[exes.Length - 1], "--path .")
            { WorkingDirectory = dir, UseShellExecute = true });
    }
}
