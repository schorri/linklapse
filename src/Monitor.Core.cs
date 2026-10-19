// MIT License; Windows 11 / .NET Framework 4.8 / Windows PowerShell 5.1.
using System;
using System.IO;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;
using System.Collections.Generic;
#pragma warning disable 4014

namespace InternetMonitor {
 public sealed class PowerGuard : IDisposable {
  [StructLayout(LayoutKind.Sequential)] struct Reason {public uint Version,Flags;public IntPtr Text;}
  [StructLayout(LayoutKind.Sequential)] struct PowerStatus {public byte AC,BatteryFlag,BatteryPercent,SystemFlag;public uint Life,FullLife;}
  [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr PowerCreateRequest(ref Reason context);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool PowerSetRequest(IntPtr request,int type);
  [DllImport("kernel32.dll")] static extern bool PowerClearRequest(IntPtr request,int type);
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
  [DllImport("kernel32.dll")] static extern bool GetSystemPowerStatus(out PowerStatus status);
  IntPtr handle; bool execution;
  public PowerGuard() {
   var reason=new Reason{Version=0,Flags=1,Text=Marshal.StringToHGlobalUni("InternetMonitor: laufende Stabilitaetsmessung")};
   try {handle=PowerCreateRequest(ref reason);} finally {Marshal.FreeHGlobal(reason.Text);}
   if(handle==IntPtr.Zero || handle==new IntPtr(-1)) {handle=IntPtr.Zero;throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());}
   if(!PowerSetRequest(handle,1)) {int e=Marshal.GetLastWin32Error();CloseHandle(handle);handle=IntPtr.Zero;throw new System.ComponentModel.Win32Exception(e);}
   execution=PowerSetRequest(handle,3);
  }
  public static string Source() {PowerStatus p;if(!GetSystemPowerStatus(out p))return "Unknown";return p.AC==1?"AC":p.AC==0?"Battery":"Unknown";}
  public void Dispose() {if(handle!=IntPtr.Zero){if(execution)PowerClearRequest(handle,3);PowerClearRequest(handle,1);CloseHandle(handle);handle=IntPtr.Zero;}}
 }
 public class WifiReading {
  public string State = "Unknown";
  public int Error;
  public int Signal = -1;
  public double RxMbps = -1, TxMbps = -1;
 }
 public class RouteReading { public int Error; public int InterfaceIndex; public string NextHop = ""; }
 public class ProbeResult {
  public string Status = "NotTested";
  public double Ms = -1;
 }
 public class WebResult : ProbeResult { public string Url; public string StartedUtc; public string EndedUtc; public int HttpCode; }
 public class SpeedResult : ProbeResult {
  public string StartedUtc, EndedUtc, Url;
  public long Bytes;
  public double Mbps, Seconds;
  public bool Capped;
 }
 public static class Native {
  public static Guid[] WifiIds() {
   IntPtr h=IntPtr.Zero,list=IntPtr.Zero;var ids=new List<Guid>();
   try {
    uint v;if(WlanOpenHandle(2,IntPtr.Zero,out v,out h)!=0) return ids.ToArray();
    if(WlanEnumInterfaces(h,IntPtr.Zero,out list)!=0) return ids.ToArray();
    int count=Marshal.ReadInt32(list),size=Marshal.SizeOf(typeof(InterfaceInfo));
    for(int i=0;i<count;i++) ids.Add(((InterfaceInfo)Marshal.PtrToStructure(IntPtr.Add(list,8+i*size),typeof(InterfaceInfo))).Id);
   } finally {if(list!=IntPtr.Zero) WlanFreeMemory(list);if(h!=IntPtr.Zero) WlanCloseHandle(h,IntPtr.Zero);}
   return ids.ToArray();
  }
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  struct InterfaceInfo {
   public Guid Id;
   [MarshalAs(UnmanagedType.ByValTStr, SizeConst=256)] public string Description;
   public int State;
  }
  [StructLayout(LayoutKind.Sequential)]
  struct RouteRow {
   public uint Dest, Mask, Policy, NextHop, IfIndex, Type, Proto, Age, NextHopAS;
   public uint Metric1, Metric2, Metric3, Metric4, Metric5;
  }
  [DllImport("wlanapi.dll")] static extern uint WlanOpenHandle(uint version, IntPtr reserved, out uint negotiated, out IntPtr handle);
  [DllImport("wlanapi.dll")] static extern uint WlanCloseHandle(IntPtr handle, IntPtr reserved);
  [DllImport("wlanapi.dll")] static extern uint WlanEnumInterfaces(IntPtr handle, IntPtr reserved, out IntPtr list);
  [DllImport("wlanapi.dll")] static extern uint WlanQueryInterface(IntPtr handle, ref Guid id, int opcode, IntPtr reserved, out uint size, out IntPtr data, out int valueType);
  [DllImport("wlanapi.dll")] static extern void WlanFreeMemory(IntPtr memory);
  [DllImport("iphlpapi.dll")] static extern uint GetBestRoute(uint dest, uint source, out RouteRow route);

  public static WifiReading Wifi(Guid id) {
   var r = new WifiReading(); IntPtr h = IntPtr.Zero, list = IntPtr.Zero, data = IntPtr.Zero;
   try {
    uint v; uint error = WlanOpenHandle(2, IntPtr.Zero, out v, out h);
    if(error != 0) { r.Error=(int)error; return r; }
    error = WlanEnumInterfaces(h, IntPtr.Zero, out list);
    if(error != 0) { r.Error=(int)error; return r; }
    int count=Marshal.ReadInt32(list), size=Marshal.SizeOf(typeof(InterfaceInfo));
    bool found=false;
    for(int i=0;i<count;i++) {
     var info=(InterfaceInfo)Marshal.PtrToStructure(IntPtr.Add(list,8+i*size),typeof(InterfaceInfo));
     if(info.Id!=id) continue;
     found=true;
     string[] states={"NotReady","Connected","AdHoc","Disconnecting","Disconnected","Associating","Discovering","Authenticating"};
     r.State=(info.State>=0 && info.State<states.Length)?states[info.State]:"Unknown";
     break;
    }
    if(!found) { r.Error=1168; return r; }
    if(r.State!="Connected") return r;
    uint bytes; int kind;
    // Newer Windows builds expose quality without location-sensitive fields.
    error=WlanQueryInterface(h,ref id,19,IntPtr.Zero,out bytes,out data,out kind);
    if(error==0 && bytes>=16) {
     r.Signal=Marshal.ReadInt32(data,4);
     r.RxMbps=(uint)Marshal.ReadInt32(data,8)/1000.0;
     r.TxMbps=(uint)Marshal.ReadInt32(data,12)/1000.0;
     return r;
    }
    if(data!=IntPtr.Zero) {WlanFreeMemory(data);data=IntPtr.Zero;}
    error=WlanQueryInterface(h,ref id,7,IntPtr.Zero,out bytes,out data,out kind); // current_connection = 7
    if(error!=0) { r.Error=(int)error; return r; }
    // WLAN_CONNECTION_ATTRIBUTES: state + mode + WCHAR profile[256], then
    // WLAN_ASSOCIATION_ATTRIBUTES. Only quality and link rates are retained.
    if(bytes<588) { r.Error=13; return r; }
    r.Signal=Marshal.ReadInt32(data,576);
    r.RxMbps=(uint)Marshal.ReadInt32(data,580)/1000.0;
    r.TxMbps=(uint)Marshal.ReadInt32(data,584)/1000.0;
   } catch { r.Error=-1; }
   finally {
    if(data!=IntPtr.Zero) WlanFreeMemory(data);
    if(list!=IntPtr.Zero) WlanFreeMemory(list);
    if(h!=IntPtr.Zero) WlanCloseHandle(h,IntPtr.Zero);
   }
   return r;
  }
  public static RouteReading Route(string ip) {
   var r=new RouteReading();
   try {
    byte[] bytes=IPAddress.Parse(ip).GetAddressBytes();
    if(bytes.Length!=4) {r.Error=87;return r;}
    RouteRow row;
    r.Error=(int)GetBestRoute(BitConverter.ToUInt32(bytes,0),0,out row);
    if(r.Error==0) {r.InterfaceIndex=(int)row.IfIndex; r.NextHop=new IPAddress(BitConverter.GetBytes(row.NextHop)).ToString();}
   } catch {r.Error=-1;}
   return r;
  }
 }
 public static class Probes {
  public static async Task<ProbeResult> PingOne(string ip, int timeout) {
   var r=new ProbeResult();
   if(String.IsNullOrEmpty(ip)) {r.Status="NoGateway";return r;}
   using(var p=new Ping()) {
    try {var reply=await p.SendPingAsync(IPAddress.Parse(ip),timeout,new byte[32]).ConfigureAwait(false);
     r.Status=reply.Status.ToString(); if(reply.Status==IPStatus.Success) r.Ms=reply.RoundtripTime;
    } catch(Exception e) {r.Status="Error:"+e.GetType().Name;}
   }
   return r;
  }
  public static async Task<ProbeResult> TcpOne(string ip,int port,int timeout) {
   var r=new ProbeResult();var sw=Stopwatch.StartNew();
   using(var client=new TcpClient(AddressFamily.InterNetwork)) {
    try {
     var pending=client.ConnectAsync(IPAddress.Parse(ip),port);
     if(await Task.WhenAny(pending,Task.Delay(timeout)).ConfigureAwait(false)!=pending) {
      r.Status="TimedOut";
      // Observe any exception after disposal, so timed-out tasks do not accumulate.
      pending.ContinueWith(t=>{var ignored=t.Exception;},TaskContinuationOptions.OnlyOnFaulted);
     } else {await pending.ConfigureAwait(false);r.Status="Success";r.Ms=sw.Elapsed.TotalMilliseconds;}
    } catch(SocketException e) {r.Status=e.SocketErrorCode==SocketError.ConnectionRefused?"Refused":"Error:"+e.SocketErrorCode;}
      catch(Exception e) {r.Status="Error:"+e.GetType().Name;}
   }
   return r;
  }
  public static ProbeResult[] Round(string[] ips,string[] tcpIps,int[] ports,int timeout,bool tcpDue) {
   var work=new List<Task<ProbeResult>>();
   foreach(var ip in ips) work.Add(PingOne(ip,timeout));
   if(tcpDue) for(int i=0;i<tcpIps.Length;i++) work.Add(TcpOne(tcpIps[i],ports[i],timeout));
   Task.WaitAll(work.ToArray());
   var results=new List<ProbeResult>();foreach(var t in work) results.Add(t.Result);
   return results.ToArray();
  }
  public static Task<WebResult[]> Web(string[] urls,int timeout) {
   return Task.Run(()=> {
    var work=new List<Task<WebResult>>();
    foreach(string url in urls) work.Add(Task.Run(()=>WebOne(url,timeout)));
    Task.WaitAll(work.ToArray());var result=new List<WebResult>();foreach(var t in work) result.Add(t.Result);
    return result.ToArray();
   });
  }
  static WebResult WebOne(string url,int timeout) {
   var r=new WebResult {Url=url,StartedUtc=DateTime.UtcNow.ToString("o")};
   var sw=Stopwatch.StartNew();HttpWebRequest request=null;
   try {
    request=(HttpWebRequest)WebRequest.Create(url);
    request.AllowAutoRedirect=false; request.Timeout=timeout;request.ReadWriteTimeout=timeout;
    request.KeepAlive=false;request.UserAgent="LocalInternetMonitor/1.0";
    // A timer also bounds slow DNS/proxy discovery. Certificates remain validated normally.
    using(var timer=new Timer(o=>{try{request.Abort();}catch{}},null,timeout,Timeout.Infinite))
    using(var response=(HttpWebResponse)request.GetResponse()) {
     r.HttpCode=(int)response.StatusCode;
     r.Status=r.HttpCode==200?"Success":"UnexpectedHttpCode";
     r.Ms=sw.Elapsed.TotalMilliseconds;
    }
   } catch(WebException e) {
    r.Status="Error:"+e.Status;
    if(e.Response!=null) {using(var response=e.Response) {var http=response as HttpWebResponse;if(http!=null) r.HttpCode=(int)http.StatusCode;}}
   } catch(Exception e) {r.Status="Error:"+e.GetType().Name;}
   finally {r.EndedUtc=DateTime.UtcNow.ToString("o");}
   return r;
  }
  public static Task<SpeedResult> Speed(string baseUrl,int maxBytes,int maxSeconds,double capMbps) {
   return Task.Run(()=> {
    var r=new SpeedResult {StartedUtc=DateTime.UtcNow.ToString("o"),Url=baseUrl,Capped=capMbps>0};
    var sw=Stopwatch.StartNew(); HttpWebRequest request=null;
    try {
     string url=baseUrl+(baseUrl.Contains("?")?"&":"?")+"bytes="+maxBytes+"&localmonitor="+DateTime.UtcNow.Ticks;
     request=(HttpWebRequest)WebRequest.Create(url);
     request.Timeout=maxSeconds*1000;request.ReadWriteTimeout=maxSeconds*1000;
     request.AllowAutoRedirect=false;request.KeepAlive=false;request.Proxy=null;
     request.UserAgent="LocalInternetMonitor/1.0";request.Headers[HttpRequestHeader.CacheControl]="no-cache";
     using(var timer=new Timer(o=>{try{request.Abort();}catch{}},null,maxSeconds*1000,Timeout.Infinite))
     using(var response=(HttpWebResponse)request.GetResponse()) {
      if((int)response.StatusCode!=200) throw new IOException("UnexpectedHttpCode");
      using(var stream=response.GetResponseStream()) {
       var buffer=new byte[16384];int n;
       while(r.Bytes<maxBytes && (n=stream.Read(buffer,0,(int)Math.Min(buffer.Length,maxBytes-r.Bytes)))>0) {
        r.Bytes+=n;
        if(capMbps>0) {
         double wait=r.Bytes*8.0/(capMbps*1000000)-sw.Elapsed.TotalSeconds;
         if(wait>0) Thread.Sleep((int)Math.Min(wait*1000,1000));
        }
       }
      }
     }
     r.Status=r.Bytes==maxBytes?"Success":"Partial";
    } catch(Exception e) {r.Status="PartialOrError:"+e.GetType().Name;}
    r.Seconds=sw.Elapsed.TotalSeconds;r.Ms=sw.Elapsed.TotalMilliseconds;
    if(r.Seconds>0) r.Mbps=r.Bytes*8.0/r.Seconds/1000000;
    r.EndedUtc=DateTime.UtcNow.ToString("o");return r;
   });
  }
 }
}
