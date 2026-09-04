// Run Game.exe — silent updater that can replace Update Game.exe (since it's not running).
// Update Game.exe runs separately with a GUI and can replace Run Game.exe.
class RunGame
{
    static void Main()
    {
        try
        {
            int local  = Game.ReadLocalVersion();
            int remote = Game.FetchRemoteVersion();
            if (remote > local)
            {
                Game.DownloadAndApply();
                Game.WriteLocalVersion(remote);
                Game.RecordResult(downloaded: true, fromVer: local, toVer: remote);
            }
            else
            {
                Game.RecordResult(downloaded: false, fromVer: local, toVer: local);
            }
        }
        catch { }
        Game.Launch();
    }
}
