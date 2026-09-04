using System.Diagnostics;
using System.IO;
using System.Reflection;

class RunGame
{
    static void Main()
    {
        string dir     = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        string updater = Path.Combine(dir, "Update Game.exe");
        Process.Start(new ProcessStartInfo(updater) { WorkingDirectory = dir, UseShellExecute = true });
    }
}
