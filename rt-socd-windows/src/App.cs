// Rapid Trigger & SOCD Tester for Windows.
// A small native window (WinForms + WebView2) that hosts the same tester page as the browser extension.
// Compiled with the C# compiler built into Windows (.NET Framework 4.8), see build.ps1.

using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

[assembly: AssemblyTitle("Rapid Trigger & SOCD Tester")]
[assembly: AssemblyDescription("Test rapid trigger tap speed and SOCD / Snap Tap on Hall effect and TMR keyboards.")]
[assembly: AssemblyCompany("HLPlanet")]
[assembly: AssemblyProduct("Rapid Trigger & SOCD Tester by HLPlanet")]
[assembly: AssemblyCopyright("HLPlanet.com")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

namespace HLPlanet.RtSocdTester
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }
    }

    class MainForm : Form
    {
        // The tester files are served from the "web" folder under this made-up https host
        const string Host = "app.rt-socd.example";
        const string StartUrl = "https://" + Host + "/tester.html?tab=1&app=windows";
        const string RuntimeDownloadUrl = "https://go.microsoft.com/fwlink/p/?LinkId=2124703";

        readonly WebView2 web = new WebView2();

        public MainForm()
        {
            Text = "Rapid Trigger & SOCD Tester by HLPlanet";
            Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            BackColor = Color.FromArgb(15, 18, 24);
            StartPosition = FormStartPosition.CenterScreen;

            // Size in 96-DPI pixels, scaled for high-DPI screens
            float scale = DeviceDpi / 96f;
            ClientSize = new Size((int)(820 * scale), (int)(640 * scale));
            MinimumSize = new Size((int)(520 * scale), (int)(560 * scale));

            web.Dock = DockStyle.Fill;
            web.DefaultBackgroundColor = BackColor;
            Controls.Add(web);

            Load += async (sender, e) => await InitAsync();
        }

        [System.Runtime.InteropServices.DllImport("dwmapi.dll")]
        static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);

        // Dark title bar to match the app (Windows 10 20H1+ and Windows 11; ignored on older versions)
        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            int dark = 1;
            DwmSetWindowAttribute(Handle, 20, ref dark, sizeof(int)); // DWMWA_USE_IMMERSIVE_DARK_MODE
        }

        async Task InitAsync()
        {
            string webRoot = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "web");
            // Keep browser data in AppData, so the app also works when installed in Program Files
            string dataDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "HLPlanet", "RT-SOCD-Tester");

            try
            {
                CoreWebView2Environment env = await CoreWebView2Environment.CreateAsync(null, dataDir);
                await web.EnsureCoreWebView2Async(env);
            }
            catch (WebView2RuntimeNotFoundException)
            {
                DialogResult answer = MessageBox.Show(
                    "This app needs the Microsoft Edge WebView2 Runtime, which is part of Windows 11 " +
                    "but may be missing on older Windows 10 PCs.\n\nOpen the download page now?",
                    Text, MessageBoxButtons.YesNo, MessageBoxIcon.Information);
                if (answer == DialogResult.Yes) OpenExternal(RuntimeDownloadUrl);
                Close();
                return;
            }

            CoreWebView2 core = web.CoreWebView2;
            CoreWebView2Settings settings = core.Settings;
            settings.AreBrowserAcceleratorKeysEnabled = false; // F5, Ctrl+F, Ctrl+P... are test keys here, not browser shortcuts
            settings.AreDefaultContextMenusEnabled = false;
            settings.AreDevToolsEnabled = false;
            settings.IsZoomControlEnabled = false;
            settings.IsStatusBarEnabled = false;
            settings.IsSwipeNavigationEnabled = false;

            core.SetVirtualHostNameToFolderMapping(Host, webRoot, CoreWebView2HostResourceAccessKind.DenyCors);

            // Links (to hlplanet.com) open in the user's normal browser, never inside the app
            core.NewWindowRequested += (sender, e) =>
            {
                e.Handled = true;
                OpenExternal(e.Uri);
            };
            core.NavigationStarting += (sender, e) =>
            {
                if (!e.Uri.StartsWith("https://" + Host + "/", StringComparison.OrdinalIgnoreCase))
                {
                    e.Cancel = true;
                    OpenExternal(e.Uri);
                }
            };

            web.Source = new Uri(StartUrl);
            web.Focus();
        }

        static void OpenExternal(string url)
        {
            if (!url.StartsWith("https://", StringComparison.OrdinalIgnoreCase)) return;
            try
            {
                Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
            }
            catch (Exception)
            {
                // No default browser configured: nothing sensible to do
            }
        }
    }
}
