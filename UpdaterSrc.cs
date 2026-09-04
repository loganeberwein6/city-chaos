using System;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Reflection;
using System.Windows.Forms;

class Updater
{
    const string ZipUrl = "https://github.com/loganeberwein6/city-chaos/archive/refs/heads/main.zip";

    [STAThread]
    static void Main()
    {
        string gameDir    = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        string tmpZip     = Path.Combine(Path.GetTempPath(), "city_chaos_update.zip");
        string tmpExtract = Path.Combine(Path.GetTempPath(), "city_chaos_update");

        try
        {
            Console.WriteLine("Downloading latest update from GitHub...");

            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            using (var wc = new WebClient())
            {
                wc.Headers["User-Agent"] = "CityChaosupdater/1.0";
                wc.DownloadFile(ZipUrl, tmpZip);
            }
            Console.WriteLine("Download complete. Applying update...");

            if (Directory.Exists(tmpExtract))
                Directory.Delete(tmpExtract, true);

            ZipFile.ExtractToDirectory(tmpZip, tmpExtract);

            string[] extracted = Directory.GetDirectories(tmpExtract);
            if (extracted.Length == 0)
                throw new Exception("Empty ZIP returned from GitHub.");

            string srcRoot = extracted[0];
            CopyDirectory(srcRoot, gameDir);

            File.Delete(tmpZip);
            Directory.Delete(tmpExtract, true);

            Console.WriteLine("Update applied successfully!");
            MessageBox.Show(
                "Game updated successfully!\nLaunch it with 'Run Game.exe'.",
                "City Chaos Updater",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information);
        }
        catch (Exception ex)
        {
            Console.WriteLine("Update failed: " + ex.Message);
            MessageBox.Show(
                "Update failed:\n" + ex.Message,
                "City Chaos Updater",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
    }

    static void CopyDirectory(string src, string dst)
    {
        Directory.CreateDirectory(dst);
        foreach (string file in Directory.GetFiles(src, "*", SearchOption.AllDirectories))
        {
            string name = Path.GetFileName(file);
            // Skip large engine binary — laptops keep their own copy
            if (name.StartsWith("Godot_v") && name.EndsWith(".exe")) continue;
            // Don't overwrite the updater itself while it's running
            if (name == "Update Game.exe") continue;

            string rel  = file.Substring(src.Length).TrimStart(
                Path.DirectorySeparatorChar, '/');
            string dest = Path.Combine(dst, rel);
            Directory.CreateDirectory(Path.GetDirectoryName(dest));
            File.Copy(file, dest, true);
        }
    }
}
