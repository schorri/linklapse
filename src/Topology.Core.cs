using System;
using System.Collections.Generic;
using System.Net;
using System.Net.NetworkInformation;
using System.Threading.Tasks;

namespace InternetMonitor {
 public class TraceHop {
  public int Ttl; public string Address="",Status="";
 }
 public class PathTrace {
  public string Target,NextHop,StartedUtc,EndedUtc; public int InterfaceIndex;
  public bool RouteStable; public TraceHop[] Hops;
 }
 public class NodeProbe {
  public string Address,Status,TimestampUtc,NextHop;public int InterfaceIndex;public double Ms=-1;
 }
 public static class TopologyProbes {
  public static Task<PathTrace[]> Discover(string[] targets,int maxHops,int timeout) {
   return Task.Run(()=> {
    var tasks=new List<Task<PathTrace>>();
    foreach(string target in targets) tasks.Add(Task.Run(()=>Trace(target,maxHops,timeout)));
    Task.WaitAll(tasks.ToArray());var result=new List<PathTrace>();foreach(var t in tasks)result.Add(t.Result);return result.ToArray();
   });
  }
  static PathTrace Trace(string target,int maxHops,int timeout) {
   var before=Native.Route(target);var hops=new List<TraceHop>();
   var result=new PathTrace {Target=target,InterfaceIndex=before.InterfaceIndex,NextHop=before.NextHop,StartedUtc=DateTime.UtcNow.ToString("o")};
   using(var ping=new Ping()) {
    for(int ttl=1;ttl<=maxHops;ttl++) {
     var hop=new TraceHop {Ttl=ttl};
     try {
      var reply=ping.Send(IPAddress.Parse(target),timeout,new byte[32],new PingOptions(ttl,false));
      hop.Status=reply.Status.ToString();
      if(reply.Address!=null && !reply.Address.Equals(IPAddress.Any))hop.Address=reply.Address.ToString();
      hops.Add(hop);
      if(reply.Status==IPStatus.Success)break;
     } catch(Exception e){hop.Status="Error:"+e.GetType().Name;hops.Add(hop);break;}
    }
   }
   var after=Native.Route(target);result.RouteStable=before.Error==0&&after.Error==0&&before.InterfaceIndex==after.InterfaceIndex&&before.NextHop==after.NextHop;
   result.Hops=hops.ToArray();result.EndedUtc=DateTime.UtcNow.ToString("o");return result;
  }
  public static Task<NodeProbe[]> Probe(string[] addresses,int timeout) {
   return Task.Run(()=> {
    var tasks=new List<Task<NodeProbe>>();foreach(string address in addresses)tasks.Add(Task.Run(()=> {
     var route=Native.Route(address);var p=Probes.PingOne(address,timeout).Result;
     var after=Native.Route(address);return new NodeProbe {Address=address,Status=(route.Error==0&&after.Error==0&&route.InterfaceIndex==after.InterfaceIndex&&route.NextHop==after.NextHop)?p.Status:"RouteChanged",InterfaceIndex=route.InterfaceIndex,NextHop=route.NextHop,Ms=p.Ms,TimestampUtc=DateTime.UtcNow.ToString("o")};
    }));
    Task.WaitAll(tasks.ToArray());var results=new List<NodeProbe>();foreach(var task in tasks)results.Add(task.Result);return results.ToArray();
   });
  }
 }
}
