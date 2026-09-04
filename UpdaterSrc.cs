using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Reflection;
using System.Threading;

class Updater
{
    const string Owner      = "loganeberwein6";
    const string Repo       = "city-chaos";
    const string Branch     = "main";
    const string VerFile    = "version.txt";
    const string GameExe    = "Run Game.exe";

    static string ZipUrl    => $"https://github.com/{Owner}/{Repo}/archive/refs/heads/{Branch}.zip";
    static string RemoteVer => $"https://raw.githubusercontent.com/{Owner}/{Repo}/{Branch}/{VerFile}";

    static string GameDir => Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);

    // ── Version helpers ────────────────────────────────────────────────────────

    static int ReadLocalVersion()
    {
        string path = Path.Combine(GameDir, VerFile);
        if (!File.Exists(path)) return 0;
        return int.TryParse(File.ReadAllText(path).Trim(), out int v) ? v : 0;
    }

    static int FetchRemoteVersion()
    {
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
        var wc = new WebClient();
        wc.Headers["User-Agent"] = "CityChaosupdater/2.0";
        string text = wc.DownloadString(RemoteVer);
        return int.TryParse(text.Trim(), out int v) ? v : 0;
    }

    static void WriteLocalVersion(int v)
    {
        File.WriteAllText(Path.Combine(GameDir, VerFile), v.ToString());
    }

    // ── Update ─────────────────────────────────────────────────────────────────

    static void DownloadAndApply()
    {
        string tmpZip     = Path.Combine(Path.GetTempPath(), "city_chaos_update.zip");
        string tmpExtract = Path.Combine(Path.GetTempPath(), "city_chaos_update");

        Console.WriteLine("  Downloading...");
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
        var wc = new WebClient();
        wc.Headers["User-Agent"] = "CityChaosupdater/2.0";
        wc.DownloadFile(ZipUrl, tmpZip);

        Console.WriteLine("  Extracting...");
        if (Directory.Exists(tmpExtract))
            Directory.Delete(tmpExtract, true);
        ZipFile.ExtractToDirectory(tmpZip, tmpExtract);

        string[] roots = Directory.GetDirectories(tmpExtract);
        if (roots.Length == 0) throw new Exception("Empty ZIP.");
        CopyDirectory(roots[0], GameDir);

        File.Delete(tmpZip);
        Directory.Delete(tmpExtract, true);
    }

    static void CopyDirectory(string src, string dst)
    {
        Directory.CreateDirectory(dst);
        foreach (string file in Directory.GetFiles(src, "*", SearchOption.AllDirectories))
        {
            string name = Path.GetFileName(file);
            if (name.StartsWith("Godot_v") && name.EndsWith(".exe")) continue;
            if (name == "Update Game.exe") continue; // can't overwrite running exe

            string rel  = file.Substring(src.Length).TrimStart(Path.DirectorySeparatorChar, '/');
            string dest = Path.Combine(dst, rel);
            Directory.CreateDirectory(Path.GetDirectoryName(dest));
            File.Copy(file, dest, true);
        }
    }

    // ── Launch ─────────────────────────────────────────────────────────────────

    static void LaunchGame()
    {
        string path = Path.Combine(GameDir, GameExe);
        if (!File.Exists(path))
        {
            // Fallback: find any Godot exe and run it with --path .
            string[] godotExes = Directory.GetFiles(GameDir, "Godot_v*.exe");
            if (godotExes.Length > 0)
            {
                var psi = new ProcessStartInfo(godotExes[0], "--path .")
                    { WorkingDirectory = GameDir, UseShellExecute = true };
                Process.Start(psi);
                return;
            }
            Console.WriteLine($"ERROR: Could not find {GameExe}.");
            Console.WriteLine("Press Enter to exit.");
            Console.ReadLine();
            return;
        }
        Process.Start(new ProcessStartInfo(path) { WorkingDirectory = GameDir, UseShellExecute = true });
    }

    // ── Entry point ────────────────────────────────────────────────────────────

    [STAThread]
    static void Main()
    {
        Console.Title = "City Chaos Launcher";
        Console.WriteLine("+--------------------------+");
        Console.WriteLine("|   City Chaos Launcher    |");
        Console.WriteLine("+--------------------------+");
        Console.WriteLine();

        int local = ReadLocalVersion();
        Console.Write($"Local version : {local}\nRemote version: ");

        int remote = 0;
        bool online = false;
        try
        {
            remote = FetchRemoteVersion();
            online = true;
            Console.WriteLine(remote);
        }
        catch
        {
            Console.WriteLine("(offline)");
        }

        if (online && remote > local)
        {
            Console.WriteLine($"\nUpdate available! ({local} → {remote})");
            try
            {
                DownloadAndApply();
                WriteLocalVersion(remote);
                Console.WriteLine("  Done! Relaunching...");
                Thread.Sleep(400);
                Process.Start(new ProcessStartInfo(
                    Assembly.GetExecutingAssembly().Location)
                    { WorkingDirectory = GameDir, UseShellExecute = true });
                Environment.Exit(0);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  Update failed: {ex.Message}");
                Console.WriteLine("  Launching current version...");
            }
        }
        else
        {
            Console.WriteLine("\nAlready up to date.");
        }

        Console.WriteLine("\nStarting game...");
        Thread.Sleep(300);
        LaunchGame();
    }
}
