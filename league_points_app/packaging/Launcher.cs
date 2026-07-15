using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Windows.Forms;

// Single-file distributable launcher for League Points Calculator.
//
// The Flutter Windows build (`flutter build windows --release`) produces a
// folder, not a single file, so this wraps that folder (zipped) as an
// embedded resource inside a small .NET launcher exe. On launch it extracts
// the embedded zip to %LOCALAPPDATA%\LeaguePointsApp\ (wiping any previous
// copy first, so it's always current) and starts league_points_app.exe from
// there.
//
// Rebuild recipe (see wiki.md §9.12):
//   1. flutter build windows --release
//   2. Zip the contents of build\windows\x64\runner\Release\ to a zip file
//      (e.g. league_points_app\dist\league_points_app_windows.zip)
//   3. csc /nologo /target:winexe /platform:x64 /out:LeaguePointsApp.exe
//        /resource:<zip path>,app.zip
//        /reference:System.IO.Compression.FileSystem.dll
//        /reference:System.IO.Compression.dll
//        /reference:System.Windows.Forms.dll
//        Launcher.cs
class Launcher
{
    static void Main()
    {
        try
        {
            string targetDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "LeaguePointsApp");

            if (Directory.Exists(targetDir))
            {
                Directory.Delete(targetDir, true);
            }
            Directory.CreateDirectory(targetDir);

            var asm = Assembly.GetExecutingAssembly();
            using (var resourceStream = asm.GetManifestResourceStream("app.zip"))
            using (var archive = new ZipArchive(resourceStream, ZipArchiveMode.Read))
            {
                archive.ExtractToDirectory(targetDir);
            }

            string exePath = Path.Combine(targetDir, "league_points_app.exe");
            Process.Start(new ProcessStartInfo(exePath)
            {
                WorkingDirectory = targetDir,
                UseShellExecute = true,
            });
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                "League Points Calculator failed to start:\n\n" + ex,
                "Launch error",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
    }
}
