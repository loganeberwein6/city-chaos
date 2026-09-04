using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Reflection;
using System.Threading;
using System.Windows.Forms;

// ── Shared game/update logic ──────────────────────────────────────────────────

static class Game
{
    const string Owner   = "loganeberwein6";
    const string Repo    = "city-chaos";
    const string Branch  = "main";
    const string VerFile = "version.txt";

    public static string Dir =>
        Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);

    static string ZipUrl =>
        $"https://github.com/{Owner}/{Repo}/archive/refs/heads/{Branch}.zip";

    static string RawVerUrl =>
        $"https://raw.githubusercontent.com/{Owner}/{Repo}/{Branch}/{VerFile}";

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

        try { File.Delete(tmp); }    catch { }
        try { Directory.Delete(tmpDir, true); } catch { }
    }

    static void CopyDir(string src, string dst)
    {
        Directory.CreateDirectory(dst);
        foreach (string file in Directory.GetFiles(src, "*", SearchOption.AllDirectories))
        {
            string name = Path.GetFileName(file);
            if (name.StartsWith("Godot_v") && name.EndsWith(".exe")) continue;
            if (name == "Update Game.exe") continue;

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

// ── Entry point ───────────────────────────────────────────────────────────────

class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        if (Array.IndexOf(args, "--silent") >= 0)
        {
            // Called from Run Game.exe — update silently, no window
            try
            {
                int local  = Game.ReadLocalVersion();
                int remote = Game.FetchRemoteVersion();
                if (remote > local) { Game.DownloadAndApply(); Game.WriteLocalVersion(remote); }
            }
            catch { }
            Game.Launch();
            return;
        }

        // Run directly — show progress window
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new LauncherForm());
    }
}

// ── Progress window (shown only when Update Game.exe is double-clicked) ───────

class LauncherForm : Form
{
    Label _lbl;

    public LauncherForm()
    {
        Text            = "City Chaos";
        ClientSize      = new Size(300, 90);
        FormBorderStyle = FormBorderStyle.FixedSingle;
        StartPosition   = FormStartPosition.CenterScreen;
        MaximizeBox     = false;
        MinimizeBox     = false;

        _lbl = new Label
        {
            Text      = "Checking for updates...",
            Dock      = DockStyle.Fill,
            TextAlign = ContentAlignment.MiddleCenter,
            Font      = new Font("Segoe UI", 10f)
        };
        Controls.Add(_lbl);

        var w = new BackgroundWorker();
        w.DoWork             += DoWork;
        w.RunWorkerCompleted += Done;
        w.RunWorkerAsync();
    }

    void Say(string s) =>
        Invoke((Action)(() => _lbl.Text = s));

    void DoWork(object sender, DoWorkEventArgs e)
    {
        try
        {
            int local  = Game.ReadLocalVersion();
            int remote = Game.FetchRemoteVersion();
            Say($"Local v{local}  ·  Remote v{remote}");
            Thread.Sleep(500);

            if (remote > local)
            {
                Say($"Downloading v{local} → v{remote}...");
                Game.DownloadAndApply();
                Game.WriteLocalVersion(remote);
                Say("Done!");
                Thread.Sleep(600);
            }
            else
            {
                Say("Up to date! Starting...");
                Thread.Sleep(400);
            }
        }
        catch
        {
            Say("Offline — starting game...");
            Thread.Sleep(600);
        }
    }

    void Done(object sender, RunWorkerCompletedEventArgs e)
    {
        Game.Launch();
        Application.Exit();
    }
}
