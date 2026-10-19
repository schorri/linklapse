const assert=require('node:assert/strict');
const {assess}=require('../web/Dashboard.logic.js');
function fixture(){const t='2026-10-19T08:00:20Z',r={WifiState:'Connected',SignalPercent:70,LinkState:'Up',NetworkType:'Wireless80211',InterfaceIndex:4,GatewayRouteIfIndex:4,GatewayAddress:'192.0.2.1',GatewayStatus:'Success',GatewayMs:2,GatewayPingAlarmEligible:1};for(let i=1;i<=3;i++)Object.assign(r,{['P'+i+'Address']:'192.0.2.'+(i+1),['P'+i+'Status']:'Success',['P'+i+'Ms']:20,['P'+i+'PingAlarmEligible']:1,['P'+i+'RouteIfIndex']:4,['P'+i+'NextHop']:'192.0.2.1'});for(let i=1;i<=2;i++){r['Tcp'+i+'RouteIfIndex']=4;r['Tcp'+i+'NextHop']='192.0.2.1';}return {last:t,lastRow:r,extra:{Settings:{HighInternetLatencyMs:150,HighGatewayLatencyMs:30,WeakWifiPercent:40,Speed:{ExpectedMbps:100,SlowRatio:.5,EveryMinutes:60}},WebTests:[],Topology:{Nodes:[]}},timeline:[]};}
function tcp(d,state='ok',last=d.last){d.timeline=[{Layer:'Tcp',Segments:[{State:state,LastObservedUtc:last,SuccessfulProbes:state==='ok'?2:0}]}];}
let d=fixture();tcp(d);assert.equal(assess(d).code,'servicesReachable');
// Permanently silent targets cannot create a qualified ping fault.
for(let i=1;i<=3;i++){d.lastRow['P'+i+'PingAlarmEligible']=0;d.lastRow['P'+i+'Status']='TimedOut';}
assert.equal(assess(d).ping.state,'unavailable');assert.equal(assess(d).state,'ok');
d=fixture();d.lastRow.SignalPercent=28;assert.equal(assess(d).code,'weakSignal');
d.lastRow.WifiState='Disconnected';assert.equal(assess(d).code,'localDisconnected');
d=fixture();d.lastRow.NetworkType='Ethernet';d.lastRow.WifiState='NotApplicable';tcp(d);assert.equal(assess(d).state,'ok');
d=fixture();for(let i=1;i<=3;i++)d.lastRow['P'+i+'Status']='TimedOut';tcp(d,'loss');assert.equal(assess(d).code,'beyondGateway');
// A gateway on a different route must not support an upstream attribution.
d.lastRow.GatewayRouteIfIndex=9;assert.equal(assess(d).code,'multipleFailures');
// Successful web tests prevent declaring a complete failure despite ping/TCP faults.
d.extra.WebTests=[{Url:'https://example.invalid',Status:'Success',StartedUtc:d.last,EndedUtc:d.last}];assert.equal(assess(d).code,'icmpOnly');
d.extra.WebTests=[];tcp(d,'ok','2026-10-19T07:00:00Z');assert.equal(assess(d).serviceOk,false);
// AP management ICMP failure does not establish a forwarding failure.
d=fixture();d.extra.Topology.Nodes=[{Role:'AccessPointManagement',InterfaceIndex:4,State:'loss'}];tcp(d);assert.equal(assess(d).code,'servicesReachable');
d.extra.SpeedTests=[{Status:'Success',StartedUtc:d.last,Mbps:20,RateCapped:'True'}];assert.equal(assess(d).slow,false);
d.extra.SpeedTests[0].RateCapped='False';assert.equal(assess(d).code,'slowSample');
d.extra.SpeedTests[0].Status='Partial';assert.equal(assess(d).slow,false);
console.log('PASS: silent ping; Wi-Fi; Ethernet; mixed paths; fresh services; stale services; AP control plane; capped/partial speed.');
