using System;
using System.IO;
using System.Diagnostics;
using System.Windows.Forms;
[assembly:System.Reflection.AssemblyTitle("LinkLapse")]
[assembly:System.Reflection.AssemblyDescription("Free Wi-Fi & Internet Stability Monitor")]
[assembly:System.Reflection.AssemblyVersion("0.1.0.0")]
static class Launcher {
 [STAThread]static int Main(){
  string root=AppDomain.CurrentDomain.BaseDirectory;
  try{
   string script=Path.Combine(root,"src","UiHost.ps1");if(!File.Exists(script))throw new IOException("Please extract the complete ZIP before opening LinkLapse.\nBitte das ZIP vollstaendig entpacken.");
   var start=new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),"WindowsPowerShell","v1.0","powershell.exe"));
   start.Arguments="-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \""+script+"\" -LauncherPid "+Process.GetCurrentProcess().Id;
   start.WorkingDirectory=root;start.UseShellExecute=false;start.CreateNoWindow=true;start.WindowStyle=ProcessWindowStyle.Hidden;
   using(var child=Process.Start(start)){child.WaitForExit();if(child.ExitCode!=0){string log=Path.Combine(root,"data","ui-error.log");throw new IOException("LinkLapse could not start.\nLinkLapse konnte nicht gestartet werden.\n\n"+(File.Exists(log)?File.ReadAllText(log):"Windows may have blocked the PowerShell process.\nWindows hat moeglicherweise den PowerShell-Prozess blockiert."));}}
   return 0;
  }catch(Exception e){MessageBox.Show(e.Message,"LinkLapse",MessageBoxButtons.OK,MessageBoxIcon.Error);return 1;}
 }
}
