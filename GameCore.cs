using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Reflection;

// Shared update logic compiled into both Update Game.exe and Run Game.exe.
// Each binary skips overwriting itself but can replace the other.
static class Game
{
    const string Owner   = "loganeberwein6";
    const string Repo    = "city-chaos";
    const string Branch  = "main";
    const string VerFile = "version.txt";
    const string LogFile = "update_log.txt";

    static readonly string _selfName = GetSelfName();

    static string GetSelfName()
    {
        try   { return Path.GetFileName(Process.GetCurrentProcess().MainModule.FileName); }
        catch { return Path.GetFileName(Assembly.GetExecutingAssembly().Location); }
    }

    public static string Dir
    {
        get
        {
            try   { return Path.GetDirectoryName(Process.GetCurrentProcess().MainModule.FileName); }
            catch { return Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location); }
        }
    }

    static string ZipUrl    => $"https://github.com/{Owner}/{Repo}/archive/refs/heads/{Branch}.zip";
    static string RawVerUrl => $"https://raw.githubusercontent.com/{Owner}/{Repo}/{Branch}/{VerFile}";

    public static int ReadLocalVersion()
    {
        string p = Path.Combine(Dir, VerFile);
        return File.Exists(p) && int.TryParse(File.ReadAllText(p).Trim(), out int v) ? v : 0;
    }

    public static int FetchRemoteVersion()
    {
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
        var wc = new WebClient();
        wc.Headers["User-Agent"] = "CityChaosupdater/2.0";
        return int.TryParse(wc.DownloadString(RawVerUrl).Trim(), out int v) ? v : 0;
    }

    public static void WriteLocalVersion(int v) =>
        File.WriteAllText(Path.Combine(Dir, VerFile), v.ToString());

    public static void RecordResult(bool downloaded, int fromVer, int toVer)
    {
        string line = $"{DateTime.Now:yyyy-MM-dd HH:mm}|{(downloaded ? "downloaded" : "uptodate")}|{fromVer}|{toVer}";
        try { File.WriteAllText(Path.Combine(Dir, LogFile), line); } catch { }
    }

    public static string ReadLastResult()
    {
        string p = Path.Combine(Dir, LogFile);
        if (!File.Exists(p)) return null;
        string[] parts = File.ReadAllText(p).Trim().Split('|');
        if (parts.Length < 4) return null;
        if (parts[1] == "downloaded")
            return $"Last update: {parts[0]}  —  Downloaded v{parts[2]} → v{parts[3]}";
        return $"Last check: {parts[0]}  —  Already up to date (v{parts[3]})";
    }

    public static void DownloadAndApply()
    {
        string tmp    = Path.Combine(Path.GetTempPath(), "city_chaos_update.zip");
        string tmpDir = Path.Combine(Path.GetTempPath(), "city_chaos_update");

        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
        var wc = new WebClient();
        wc.Headers["User-Agent"] = "CityChaosupdater/2.0";
        wc.DownloadFile(ZipUrl, tmp);

        if (Directory.Exists(tmpDir)) Directory.Delete(tmpDir, true);
        ZipFile.ExtractToDirectory(tmp, tmpDir);

        string[] roots = Directory.GetDirectories(tmpDir);
        if (roots.Length == 0) throw new Exception("Empty ZIP from GitHub.");
        CopyDir(roots[0], Dir);

        try { File.Delete(tmp); }           catch { }
        try { Directory.Delete(tmpDir, true); } catch { }
    }

    // Each binary skips only itself so the other exe can always be updated.
    static void CopyDir(string src, string dst)
    {
        Directory.CreateDirectory(dst);
        foreach (string file in Directory.GetFiles(src, "*", SearchOption.AllDirectories))
        {
            string name = Path.GetFileName(file);
            if (name.StartsWith("Godot_v") && name.EndsWith(".exe")) continue;
            if (string.Equals(name, _selfName, StringComparison.OrdinalIgnoreCase)) continue;

            string rel  = file.Substring(src.Length).TrimStart(Path.DirectorySeparatorChar, '/');
            string dest = Path.Combine(dst, rel);
            Directory.CreateDirectory(Path.GetDirectoryName(dest));
            try { File.Copy(file, dest, true); } catch { }
        }
    }

    public static void Launch()
    {
        string[] exes = Directory.GetFiles(Dir, "Godot_v*.exe");
        if (exes.Length == 0) return;
        Array.Sort(exes);
        Process.Start(new ProcessStartInfo(exes[exes.Length - 1], "--path .")
            { WorkingDirectory = Dir, UseShellExecute = true });
    }
}
