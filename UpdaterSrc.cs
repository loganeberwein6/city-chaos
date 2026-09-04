using System;
using System.ComponentModel;
using System.Drawing;
using System.Threading;
using System.Windows.Forms;

class Program
{
    [STAThread]
    static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new LauncherForm());
    }
}

class LauncherForm : Form
{
    Label _status;
    Label _history;

    public LauncherForm()
    {
        Text            = "City Chaos";
        ClientSize      = new Size(390, 120);
        FormBorderStyle = FormBorderStyle.FixedSingle;
        StartPosition   = FormStartPosition.CenterScreen;
        MaximizeBox     = false;
        MinimizeBox     = false;

        _status = new Label
        {
            Text      = "Checking for updates...",
            Location  = new Point(0, 28),
            Size      = new Size(390, 26),
            TextAlign = ContentAlignment.MiddleCenter,
            Font      = new Font("Segoe UI", 10.5f)
        };
        Controls.Add(_status);

        _history = new Label
        {
            Text      = Game.ReadLastResult() ?? "No previous update history.",
            Location  = new Point(0, 76),
            Size      = new Size(390, 20),
            TextAlign = ContentAlignment.MiddleCenter,
            Font      = new Font("Segoe UI", 8f),
            ForeColor = SystemColors.GrayText
        };
        Controls.Add(_history);

        var w = new BackgroundWorker();
        w.DoWork             += DoWork;
        w.RunWorkerCompleted += Done;
        w.RunWorkerAsync();
    }

    void Say(string s) => Invoke((Action)(() => _status.Text = s));

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
                Game.RecordResult(downloaded: true, fromVer: local, toVer: remote);
                Say($"Updated to v{remote}!");
                Thread.Sleep(700);
            }
            else
            {
                Game.RecordResult(downloaded: false, fromVer: local, toVer: local);
                Say($"Up to date!  (v{local})");
                Thread.Sleep(500);
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
