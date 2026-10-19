// MIT. Small loopback-only HTTP bridge for the local dashboard; .NET Framework 4.8.
using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Runtime.InteropServices;

#pragma warning disable 4014
namespace LinkLapse {
 public sealed class UiRequest {
  public string Method,Path,Body;
  internal int Code=200;internal string Mime="application/json; charset=utf-8",Text="{}",FilePath,DownloadName;
  internal ManualResetEventSlim Done=new ManualResetEventSlim(false);
  public void Respond(int code,string mime,string text){Code=code;Mime=mime;Text=text;Done.Set();}
  public void SendFile(string path,string mime,string downloadName){FilePath=path;Mime=mime;DownloadName=downloadName;Done.Set();}
 }
 public sealed class LocalHost:IDisposable {
  readonly TcpListener listener;readonly BlockingCollection<UiRequest> requests=new BlockingCollection<UiRequest>(32);
  readonly SemaphoreSlim slots=new SemaphoreSlim(12);volatile bool stopped;
  public string Url {get;private set;}public string Token {get;private set;}
  public LocalHost(int preferredPort){
   byte[] random=new byte[32];using(var rng=RandomNumberGenerator.Create())rng.GetBytes(random);Token=BitConverter.ToString(random).Replace("-","").ToLowerInvariant();
   listener=new TcpListener(IPAddress.Loopback,preferredPort);
   try{listener.Start(32);}catch(SocketException){listener=new TcpListener(IPAddress.Loopback,0);listener.Start(32);}
   Url="http://127.0.0.1:"+((IPEndPoint)listener.LocalEndpoint).Port;
   Task.Run(()=>Accept());
  }
  async Task Accept(){while(!stopped){TcpClient client=null;try{client=await listener.AcceptTcpClientAsync();if(!slots.Wait(0)){client.Close();continue;}var captured=client;Task.Run(()=>{try{Handle(captured);}finally{captured.Close();slots.Release();}});}catch{if(client!=null)client.Close();if(stopped)break;}}}
  static int HeaderEnd(byte[] data,int length){for(int i=3;i<length;i++)if(data[i-3]==13&&data[i-2]==10&&data[i-1]==13&&data[i]==10)return i+1;return -1;}
  void Handle(TcpClient client){
   try{client.ReceiveTimeout=5000;client.SendTimeout=15000;using(var stream=client.GetStream()){
    byte[] input=new byte[32768];int total=0,end=-1;
    while(end<0){if(total>=16384){Send(stream,413,"text/plain","Request too large",null,null);return;}int n=stream.Read(input,total,Math.Min(2048,input.Length-total));if(n==0)return;total+=n;end=HeaderEnd(input,total);}
    if(end>16384){Send(stream,413,"text/plain","Headers too large",null,null);return;}
    string[] lines=Encoding.ASCII.GetString(input,0,end).Split(new[]{"\r\n"},StringSplitOptions.None);
    string[] first=lines[0].Split(' ');if(first.Length!=3||first[2]!="HTTP/1.1"||!first[1].StartsWith("/")||first[1].StartsWith("//")){Send(stream,400,"text/plain","Invalid request",null,null);return;}
    var headers=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
    for(int i=1;i<lines.Length;i++){if(lines[i].Length==0)continue;int colon=lines[i].IndexOf(':');if(colon<1){Send(stream,400,"text/plain","Invalid header",null,null);return;}string key=lines[i].Substring(0,colon),value=lines[i].Substring(colon+1).Trim();if(headers.ContainsKey(key)){Send(stream,400,"text/plain","Duplicate header",null,null);return;}headers[key]=value;}
    string host,origin,fetchSite,token,transfer;
    if(!headers.TryGetValue("Host",out host)||host!=Url.Substring(7)){Send(stream,403,"text/plain","Invalid host",null,null);return;}
    if(headers.TryGetValue("Transfer-Encoding",out transfer)){Send(stream,400,"text/plain","Transfer encoding unsupported",null,null);return;}
    if(headers.TryGetValue("Origin",out origin)&&origin!=Url){Send(stream,403,"text/plain","Origin denied",null,null);return;}
    if(headers.TryGetValue("Sec-Fetch-Site",out fetchSite)&&fetchSite=="cross-site"){Send(stream,403,"text/plain","Cross-site request denied",null,null);return;}
    if(first[0]!="GET"&&first[0]!="POST"){Send(stream,405,"text/plain","Method denied",null,null);return;}
    if(first[1].StartsWith("/api/")&&(!headers.TryGetValue("X-LinkLapse-Token",out token)||!EqualToken(token,Token))){Send(stream,403,"text/plain","Token required",null,null);return;}
    if(first[0]=="POST"){
     string contentType;if(origin!=Url||!headers.TryGetValue("Content-Type",out contentType)||!contentType.StartsWith("application/json",StringComparison.OrdinalIgnoreCase)){Send(stream,403,"text/plain","JSON same-origin requests only",null,null);return;}
    }
    int count=0;string length;if(headers.TryGetValue("Content-Length",out length)&&(!int.TryParse(length,out count)||count<0||count>16384)){Send(stream,413,"text/plain","Invalid body size",null,null);return;}
    while(total-end<count){int n=stream.Read(input,total,Math.Min(input.Length-total,count-(total-end)));if(n==0)return;total+=n;}
    var request=new UiRequest{Method=first[0],Path=first[1].Split('?')[0],Body=Encoding.UTF8.GetString(input,end,count)};
    if(!requests.TryAdd(request)){Send(stream,503,"text/plain","Busy",null,null);return;}
    if(!request.Done.Wait(15000)){Send(stream,503,"text/plain","Application did not respond",null,null);return;}
    Send(stream,request.Code,request.Mime,request.Text,request.FilePath,request.DownloadName);
   }}catch(IOException){}catch(SocketException){}catch(ObjectDisposedException){}
  }
  static bool EqualToken(string a,string b){if(a==null||a.Length!=b.Length)return false;int diff=0;for(int i=0;i<a.Length;i++)diff|=a[i]^b[i];return diff==0;}
  static void Send(NetworkStream stream,int code,string mime,string text,string path,string download){
   byte[] bytes=path==null?Encoding.UTF8.GetBytes(text??""):null;long size=path==null?bytes.Length:new FileInfo(path).Length;
   string headers="HTTP/1.1 "+code+" "+(code==200?"OK":"Response")+"\r\nContent-Type: "+mime+"\r\nContent-Length: "+size+"\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nX-Frame-Options: DENY\r\nReferrer-Policy: no-referrer\r\nContent-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'\r\n";
   if(!String.IsNullOrEmpty(download))headers+="Content-Disposition: attachment; filename=\""+download+"\"\r\n";
   byte[] head=Encoding.ASCII.GetBytes(headers+"\r\n");stream.Write(head,0,head.Length);
   if(path==null)stream.Write(bytes,0,bytes.Length);else using(var file=File.OpenRead(path))file.CopyTo(stream);
  }
  public UiRequest Next(int waitMs){UiRequest r;return requests.TryTake(out r,waitMs)?r:null;}
  public void Dispose(){stopped=true;listener.Stop();UiRequest r;while(requests.TryTake(out r))r.Respond(503,"text/plain","Application closed");}
 }
 public sealed class ChildProcesses:IDisposable {
  [StructLayout(LayoutKind.Sequential)]struct Basic{public long ProcessTime,JobTime;public uint Flags;public UIntPtr MinWS,MaxWS;public uint Active;public UIntPtr Affinity;public uint Priority,Scheduling;}
  [StructLayout(LayoutKind.Sequential)]struct Io{public ulong ReadOps,WriteOps,OtherOps,ReadBytes,WriteBytes,OtherBytes;}
  [StructLayout(LayoutKind.Sequential)]struct Extended{public Basic Basic;public Io Io;public UIntPtr ProcessMemory,JobMemory,PeakProcess,PeakJob;}
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern IntPtr CreateJobObject(IntPtr security,string name);
  [DllImport("kernel32.dll",SetLastError=true)]static extern bool SetInformationJobObject(IntPtr job,int cls,IntPtr info,uint size);
  [DllImport("kernel32.dll",SetLastError=true)]static extern bool AssignProcessToJobObject(IntPtr job,IntPtr process);
  [DllImport("kernel32.dll")]static extern bool CloseHandle(IntPtr handle);
  IntPtr job;
  public ChildProcesses(){job=CreateJobObject(IntPtr.Zero,null);if(job==IntPtr.Zero)throw new System.ComponentModel.Win32Exception();var info=new Extended();info.Basic.Flags=0x2000;int size=Marshal.SizeOf(info);IntPtr p=Marshal.AllocHGlobal(size);try{Marshal.StructureToPtr(info,p,false);if(!SetInformationJobObject(job,9,p,(uint)size))throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());}finally{Marshal.FreeHGlobal(p);}}
  public void Track(System.Diagnostics.Process process){if(!AssignProcessToJobObject(job,process.Handle))throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());}
  public void Dispose(){if(job!=IntPtr.Zero){CloseHandle(job);job=IntPtr.Zero;}}
 }
}
