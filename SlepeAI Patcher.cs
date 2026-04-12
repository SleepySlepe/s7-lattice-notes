using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace SlepeAIPatcher
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new PatcherForm());
        }
    }

    internal sealed class UpdateManifest { public string Version; public string Channel; public List<UpdateFile> Files; public List<string> Preserve; public List<string> Notes; }
    internal sealed class UpdateFile { public string Path; public string Kind; }

    internal sealed class PatcherForm : Form
    {
        private static readonly string[] ManifestUrls =
        {
            "https://raw.githubusercontent.com/SleepySlepe/s7-lattice-notes/main/update-manifest.json",
            "https://raw.githubusercontent.com/SleepySlepe/s7-lattice-notes/master/update-manifest.json",
            "https://github.com/SleepySlepe/s7-lattice-notes/raw/refs/heads/main/update-manifest.json",
            "https://github.com/SleepySlepe/s7-lattice-notes/raw/refs/heads/master/update-manifest.json"
        };

        private static readonly string[] AllowedUpdateFiles =
        {
            "AI.lua",
            "AI_M.lua",
            "Const.lua",
            "Util.lua",
            "SlepeAI Settings.exe",
            "SlepeAI Settings.cs",
            "SlepeAI Patcher.exe",
            "SlepeAI Patcher.cs"
        };

        private static readonly string[] ProtectedUpdateFiles =
        {
            "TargetLists.lua",
            "SlepeAI Settings Profiles.json",
            "Profiles"
        };

        private readonly JavaScriptSerializer _serializer = new JavaScriptSerializer();
        private readonly TextBox _logBox;
        private readonly Button _applyButton;
        private readonly Label _statusLabel;

        public PatcherForm()
        {
            Text = "SlepeAI Patcher";
            Width = 760;
            Height = 500;
            MinimumSize = new Size(640, 420);
            StartPosition = FormStartPosition.CenterScreen;

            var root = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 4, ColumnCount = 1, Padding = new Padding(12) };
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 100f));
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            Controls.Add(root);

            var description = new Label
            {
                Dock = DockStyle.Top,
                AutoSize = true,
                Text = "Updates code/editor files from SleepySlepe/s7-lattice-notes. User settings are preserved: TargetLists.lua, profiles, and backups are never overwritten.",
                ForeColor = Color.FromArgb(65, 65, 65),
                Margin = new Padding(0, 0, 0, 10)
            };
            root.Controls.Add(description, 0, 0);

            _logBox = new TextBox
            {
                Dock = DockStyle.Fill,
                Multiline = true,
                ReadOnly = true,
                ScrollBars = ScrollBars.Vertical,
                Font = new Font("Consolas", 10f),
                BackColor = Color.White
            };
            root.Controls.Add(_logBox, 0, 1);

            _statusLabel = new Label
            {
                Dock = DockStyle.Top,
                AutoSize = true,
                Text = "Ready",
                ForeColor = Color.FromArgb(70, 70, 70),
                Font = new Font("Segoe UI", 10f, FontStyle.Bold),
                Margin = new Padding(0, 10, 0, 6)
            };
            root.Controls.Add(_statusLabel, 0, 2);

            var buttons = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true, FlowDirection = FlowDirection.RightToLeft };
            _applyButton = new Button { Text = "Apply Updates", AutoSize = true, Margin = new Padding(8, 0, 0, 0) };
            _applyButton.Click += delegate { ApplyUpdates(); };
            buttons.Controls.Add(_applyButton);
            var openFolderButton = new Button { Text = "Open Folder", AutoSize = true, Margin = new Padding(8, 0, 0, 0) };
            openFolderButton.Click += delegate { Process.Start(AppDomain.CurrentDomain.BaseDirectory); };
            buttons.Controls.Add(openFolderButton);
            root.Controls.Add(buttons, 0, 3);

            Log("Patcher folder: " + AppDomain.CurrentDomain.BaseDirectory);
            Log("Protected settings: TargetLists.lua, SlepeAI Settings Profiles.json, Profiles/, *.bak");
        }

        private void ApplyUpdates()
        {
            if (MessageBox.Show(this, "Apply updates now?\n\nClose SlepeAI Settings.exe first if it is open. This patcher will preserve local settings and profiles.", "Apply Updates", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes)
            {
                return;
            }

            _applyButton.Enabled = false;
            try
            {
                SetStatus("Checking for updates...", Color.FromArgb(70, 70, 70));
                var result = ApplyUpdatesFromManifest();
                SetStatus("Updated " + result + " file(s).", Color.FromArgb(28, 140, 64));
                Log("Done. Updated " + result + " file(s). Settings were preserved.");
            }
            catch (Exception ex)
            {
                SetStatus("Update failed", Color.FromArgb(180, 45, 45));
                Log("ERROR: " + ex.Message);
                MessageBox.Show(this, ex.Message, "Update failed", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                _applyButton.Enabled = true;
            }
        }

        private int ApplyUpdatesFromManifest()
        {
            using (var client = CreateWebClient())
            {
                string manifestUrl;
                var manifest = DownloadManifest(client, out manifestUrl);
                var rawBaseUrl = manifestUrl.Substring(0, manifestUrl.LastIndexOf('/') + 1);
                Log("Manifest version: " + (manifest.Version ?? "unknown") + " (" + (manifest.Channel ?? "unknown") + ")");

                if (manifest.Files == null || manifest.Files.Count == 0)
                {
                    throw new InvalidOperationException("The update manifest did not list any files.");
                }

                var updated = 0;
                foreach (var updateFile in manifest.Files)
                {
                    var relativePath = NormalizeUpdatePath(updateFile != null ? updateFile.Path : null);
                    if (string.IsNullOrWhiteSpace(relativePath))
                    {
                        continue;
                    }

                    if (IsProtectedUpdateFile(relativePath))
                    {
                        Log("Skipped protected file: " + relativePath);
                        continue;
                    }

                    if (IsAllowedUpdateFile(relativePath) == false)
                    {
                        Log("Skipped non-allowlisted file: " + relativePath);
                        continue;
                    }

                    var destinationPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, relativePath);
                    EnsurePathStaysInAppDirectory(destinationPath);

                    if (IsRunningExecutable(destinationPath))
                    {
                        Log("Skipped running patcher exe: " + relativePath);
                        continue;
                    }

                    var downloadUrl = rawBaseUrl + EscapeRawPath(relativePath);
                    var tempPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, ".patch-" + Path.GetFileName(relativePath) + "-" + Guid.NewGuid().ToString("N") + ".tmp");
                    Log("Downloading " + relativePath + "...");
                    client.DownloadFile(downloadUrl, tempPath);

                    BackupExistingFile(destinationPath);
                    File.Copy(tempPath, destinationPath, true);
                    File.Delete(tempPath);
                    updated++;
                    Log("Updated " + relativePath);
                }

                return updated;
            }
        }

        private WebClient CreateWebClient()
        {
            ServicePointManager.SecurityProtocol = ServicePointManager.SecurityProtocol | (SecurityProtocolType)3072;
            var client = new WebClient();
            client.Headers.Add("User-Agent", "SlepeAI-Patcher");
            client.Headers.Add("Cache-Control", "no-cache");
            return client;
        }

        private UpdateManifest DownloadManifest(WebClient client, out string manifestUrl)
        {
            Exception lastError = null;
            foreach (var url in ManifestUrls)
            {
                try
                {
                    Log("Trying manifest: " + url);
                    var text = client.DownloadString(url);
                    var manifest = _serializer.Deserialize<UpdateManifest>(text);
                    if (manifest == null)
                    {
                        throw new InvalidOperationException("The update manifest was empty.");
                    }

                    manifestUrl = url;
                    Log("Using manifest: " + url);
                    return manifest;
                }
                catch (Exception ex)
                {
                    lastError = ex;
                    Log("Manifest failed: " + ex.Message);
                }
            }

            throw new InvalidOperationException("Could not download update-manifest.json from GitHub.", lastError);
        }

        private static string NormalizeUpdatePath(string path)
        {
            if (string.IsNullOrWhiteSpace(path)) return "";
            return path.Replace('\\', '/').Trim().TrimStart('/');
        }

        private static bool IsAllowedUpdateFile(string relativePath)
        {
            return AllowedUpdateFiles.Any(file => string.Equals(file, relativePath, StringComparison.OrdinalIgnoreCase));
        }

        private static bool IsProtectedUpdateFile(string relativePath)
        {
            if (relativePath.EndsWith(".bak", StringComparison.OrdinalIgnoreCase)) return true;
            return ProtectedUpdateFiles.Any(file => string.Equals(file, relativePath, StringComparison.OrdinalIgnoreCase) || relativePath.StartsWith(file + "/", StringComparison.OrdinalIgnoreCase));
        }

        private static string EscapeRawPath(string relativePath)
        {
            return string.Join("/", relativePath.Split('/').Select(Uri.EscapeDataString).ToArray());
        }

        private static void EnsurePathStaysInAppDirectory(string path)
        {
            var basePath = Path.GetFullPath(AppDomain.CurrentDomain.BaseDirectory);
            var fullPath = Path.GetFullPath(path);
            if (fullPath.StartsWith(basePath, StringComparison.OrdinalIgnoreCase) == false)
            {
                throw new InvalidOperationException("Update path is outside the patcher folder: " + path);
            }
        }

        private static bool IsRunningExecutable(string destinationPath)
        {
            return string.Equals(Path.GetFullPath(destinationPath), Path.GetFullPath(Application.ExecutablePath), StringComparison.OrdinalIgnoreCase);
        }

        private static void BackupExistingFile(string destinationPath)
        {
            if (File.Exists(destinationPath) == false) return;
            var backupPath = destinationPath + "." + DateTime.Now.ToString("yyyyMMddHHmmss") + ".bak";
            File.Copy(destinationPath, backupPath, true);
        }

        private void Log(string message)
        {
            _logBox.AppendText("[" + DateTime.Now.ToString("HH:mm:ss") + "] " + message + Environment.NewLine);
        }

        private void SetStatus(string text, Color color)
        {
            _statusLabel.Text = text;
            _statusLabel.ForeColor = color;
            Application.DoEvents();
        }
    }
}
