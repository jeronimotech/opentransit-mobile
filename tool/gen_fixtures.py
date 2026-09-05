import json, math, random, os
random.seed(7)
OUT = "assets/fixtures"
BASE = "2026-09-04T08:00:00-05:00"
import datetime as dt
TZ = dt.timezone(dt.timedelta(hours=-5))
base = dt.datetime(2026,9,4,8,0,0,tzinfo=TZ)
def t(sec): return (base + dt.timedelta(seconds=sec)).isoformat()

def _enc(v):
    v = ~(v << 1) if v < 0 else (v << 1)
    out = ""
    while v >= 0x20:
        out += chr((0x20 | (v & 0x1f)) + 63); v >>= 5
    return out + chr(v + 63)
def encode(pts):  # [(lat,lon)]
    out, plat, plon = "", 0, 0
    for lat, lon in pts:
        la, lo = round(lat*1e5), round(lon*1e5)
        out += _enc(la-plat) + _enc(lo-plon); plat, plon = la, lo
    return out
def dens(pts, n=6):
    o=[]
    for (a,b),(c,d) in zip(pts, pts[1:]):
        for i in range(n):
            f=i/n; o.append((a+(c-a)*f + random.uniform(-0.0002,0.0002)*(0 if i==0 else 1), b+(d-b)*f + random.uniform(-0.0002,0.0002)*(0 if i==0 else 1)))
    o.append(pts[-1]); return o
def hav(a,b):
    R=6371000; p1,p2=math.radians(a[0]),math.radians(b[0]); dp=p2-p1; dl=math.radians(b[1]-a[1])
    x=math.sin(dp/2)**2+math.cos(p1)*math.cos(p2)*math.sin(dl/2)**2; return 2*R*math.asin(math.sqrt(x))
def length(pts): return sum(hav(a,b) for a,b in zip(pts,pts[1:]))
geom=lambda pts: {"encoded": encode(pts), "precision": 5}

COMP_COLOR={"trunk":"#D32F2F","feeder":"#2E7D32","dual":"#6A1B9A","zonal":"#1565C0","cable":"#EF6C00"}
def route(id, short, long, comp="trunk", mode="BUS", agency="1"):
    return {"id": f"bogota:{id}", "shortName": short, "longName": long, "color": COMP_COLOR[comp],
            "textColor": "#FFFFFF", "mode": mode, "agencyId": agency, "component": comp}
R_B10=route("B10","B10","Portal Norte - Portal Sur")
R_K43=route("K43","K43","Portal Norte - Ricaurte")
R_G12=route("G12","G12","Ricaurte - Portal Sur")
R_B74=route("B74","B74","Portal Norte - Museo Nacional")
R_P500=route("P500","P500","Portal Norte - Cl 170","zonal","BUS","4")
R_A61=route("A61","A61","Portal Norte - Usaquén","zonal","BUS","4")
R_L10=route("L10","L10","TransMiCable Portal Tunal - Mirador","cable","CABLE_CAR","7")
R_F1=route("1-1","1-1","Portal Norte - Cl 175 (alimentador)","feeder","BUS","2")
ROUTES=[R_B10,R_K43,R_G12,R_B74,R_P500,R_A61,R_L10,R_F1]

def stop(id, name, lat, lon, comp="trunk", station=True, code=None, parent=None):
    return {"id": f"bogota:{id}", "code": code, "name": name, "lat": lat, "lon": lon,
            "locationType": "station" if station else "stop", "component": comp,
            "wheelchair": "accessible" if station else "unknown", "parentStationId": parent}
S_PN=stop("PN","Portal Norte",4.7546,-74.0459)
S_C100=stop("C100","Calle 100",4.6858,-74.0553)
S_C76=stop("C76","Calle 76",4.6653,-74.0620)
S_C45=stop("C45","Calle 45",4.6320,-74.0705)
S_AVJ=stop("AVJ","Av. Jiménez",4.6008,-74.0763)
S_RIC=stop("RIC","Ricaurte",4.6118,-74.0930)
S_NQS30=stop("NQS30","NQS - Calle 30 Sur",4.5850,-74.1180)
S_PS=stop("PS","Portal Sur",4.5978,-74.1616)
S_CL170=stop("Z170","Autopista Norte - Cl 170",4.7530,-74.0475,"zonal",False,"A1234")
S_CL175=stop("Z175","Cra 20 - Cl 175",4.7590,-74.0450,"feeder",False,"A1250")
S_USQ=stop("ZUSQ","Cra 7 - Cl 116 (Usaquén)",4.6980,-74.0320,"zonal",False,"B2001")
S_MUSEO=stop("MUSEO","Museo Nacional",4.6150,-74.0690)
STOPS=[S_PN,S_C100,S_C76,S_C45,S_AVJ,S_RIC,S_NQS30,S_PS,S_CL170,S_CL175,S_USQ,S_MUSEO]

def place(s=None, name=None, lat=None, lon=None, arr=None, dep=None):
    if s: return {"name": s["name"], "lat": s["lat"], "lon": s["lon"], "stopId": s["id"], "stopCode": s["code"], "arrival": arr, "departure": dep, "component": s["component"]}
    return {"name": name, "lat": lat, "lon": lon, "stopId": None, "stopCode": None, "arrival": arr, "departure": dep, "component": None}

ORIG=(4.7560,-74.0440); DEST=(4.5990,-74.1600)
TRUNK_N=[ (S_PN["lat"],S_PN["lon"]),(4.7300,-74.0500),(S_C100["lat"],S_C100["lon"]),(S_C76["lat"],S_C76["lon"]),(4.6480,-74.0660),(S_C45["lat"],S_C45["lon"]),(S_AVJ["lat"],S_AVJ["lon"]) ]
TRUNK_S=[ (S_AVJ["lat"],S_AVJ["lon"]),(S_RIC["lat"],S_RIC["lon"]),(S_NQS30["lat"],S_NQS30["lon"]),(4.5900,-74.1400),(S_PS["lat"],S_PS["lon"]) ]
SHAPE_B10=dens(TRUNK_N+TRUNK_S[1:])
SHAPE_K43=dens(TRUNK_N+[TRUNK_S[1]])
SHAPE_G12=dens(TRUNK_S[1:])
SHAPE_B74=dens(TRUNK_N[:-1]+[(S_MUSEO["lat"],S_MUSEO["lon"])])
SHAPE_P500=dens([(S_CL170["lat"],S_CL170["lon"]),(4.7480,-74.0520),(4.7400,-74.0560),(S_C100["lat"],S_C100["lon"])])

def walk_leg(a, b, start, secs, steps):
    pts=dens([a,b],4); d=int(length(pts))
    return {"mode":"WALK","transit":False,"startTime":t(start),"endTime":t(start+secs),"durationSeconds":secs,
            "distanceMeters":d,"from":a_pl,"to":b_pl,"route":None,"headsign":None,"agency":None,"tripId":None,
            "realtime":False,"realtimeState":None,"delaySeconds":None,"geometry":geom(pts),"intermediateStops":[],
            "steps":steps,"alerts":[]}
def W(frm_pl,to_pl,start,secs,steps):
    global a_pl,b_pl; a_pl,b_pl=frm_pl,to_pl
    return walk_leg((frm_pl["lat"],frm_pl["lon"]),(to_pl["lat"],to_pl["lon"]),start,secs,steps)
def step(instr,d,lat,lon,rel,street): return {"instruction":instr,"distanceMeters":d,"lat":lat,"lon":lon,"relativeDirection":rel,"streetName":street}

def bus_leg(rt, frm, to, shape, start, secs, headsign, inter, rtime=True, delay=120, trip="T1"):
    return {"mode":rt["mode"],"transit":True,"startTime":t(start),"endTime":t(start+secs),"durationSeconds":secs,
            "distanceMeters":int(length(shape)),"from":place(frm,dep=t(start)),"to":place(to,arr=t(start+secs)),
            "route":rt,"headsign":headsign,"agency":{"id":rt["agencyId"],"name":"TransMilenio S.A."},"tripId":f"bogota:{trip}",
            "realtime":rtime,"realtimeState":"UPDATED" if rtime else "SCHEDULED","delaySeconds":delay if rtime else None,
            "geometry":geom(shape),"intermediateStops":[place(s,arr=t(start+i*400)) for i,s in enumerate(inter,1)],"steps":[],"alerts":[]}

ALERT_B10={"id":"al-1","cause":"CONSTRUCTION","effect":"DETOUR","severity":"WARNING",
  "header":"Desvío en Av. Caracas por obras del Metro","description":"Las rutas troncales que circulan por la Av. Caracas entre Calle 26 y Calle 19 tienen desvío temporal por obras de la Línea 1 del Metro. Tiempo adicional estimado: 8 minutos.",
  "url":"https://www.transmilenio.gov.co","start":t(-86400*3),"end":t(86400*20),"routeIds":[R_B10["id"],R_K43["id"]],"stopIds":[S_AVJ["id"]],"routes":[R_B10,R_K43]}
ALERT_L10={"id":"al-2","cause":"MAINTENANCE","effect":"NO_SERVICE","severity":"SEVERE",
  "header":"TransMiCable sin servicio por mantenimiento","description":"El servicio de cable se suspende hoy entre 9:00 y 14:00 por mantenimiento programado. Habrá ruta alimentadora de contingencia.",
  "url":None,"start":t(3600),"end":t(6*3600),"routeIds":[R_L10["id"]],"stopIds":[],"routes":[R_L10]}
ALERT_INFO={"id":"al-3","cause":"OTHER_CAUSE","effect":"OTHER_EFFECT","severity":"INFO",
  "header":"Nueva ruta zonal P500","description":"Desde el 1 de septiembre la ruta P500 conecta la Calle 170 con la Calle 100 cada 10 minutos en hora pico.",
  "url":None,"start":t(-86400*4),"end":None,"routeIds":[R_P500["id"]],"stopIds":[],"routes":[R_P500]}

o_pl=place(name="Cra 45 # 174-20",lat=ORIG[0],lon=ORIG[1]); d_pl=place(name="Cl 57 Sur # 75-10",lat=DEST[0],lon=DEST[1])
steps1=[step("Camina hacia el sur por la Carrera 45",120,4.7558,-74.0442,"DEPART","Carrera 45"),step("Gira a la derecha hacia la Autopista Norte",90,4.7550,-74.0450,"RIGHT","Autopista Norte")]
steps2=[step("Sal de la estación hacia la Calle 57 Sur",150,4.5985,-74.1610,"DEPART","Calle 57 Sur"),step("Continúa por la Calle 57 Sur",110,4.5988,-74.1605,"CONTINUE","Calle 57 Sur")]
it1_legs=[W(o_pl,place(S_PN),0,240,steps1),
          {**bus_leg(R_B10,S_PN,S_PS,SHAPE_B10,300,3300,"Portal Sur",[S_C100,S_C76,S_C45,S_AVJ,S_RIC,S_NQS30],True,120,"B10-0800"),"alerts":[ALERT_B10]},
          W(place(S_PS),d_pl,3660,200,steps2)]
it1={"id":"it-0","startTime":t(0),"endTime":t(3860),"durationSeconds":3860,"walkDistanceMeters":it1_legs[0]["distanceMeters"]+it1_legs[2]["distanceMeters"],
     "walkTimeSeconds":440,"waitingTimeSeconds":60,"transfers":0,"fare":None,"accessible":True,"legs":it1_legs}
it2_legs=[W(o_pl,place(S_PN),0,240,steps1),
          bus_leg(R_K43,S_PN,S_RIC,SHAPE_K43,420,2100,"Ricaurte",[S_C100,S_C76,S_C45,S_AVJ],True,-60,"K43-0807"),
          bus_leg(R_G12,S_RIC,S_PS,SHAPE_G12,2700,1200,"Portal Sur",[S_NQS30],False,None,"G12-0845"),
          W(place(S_PS),d_pl,3900,200,steps2)]
it2={"id":"it-1","startTime":t(0),"endTime":t(4100),"durationSeconds":4100,"walkDistanceMeters":it2_legs[0]["distanceMeters"]+it2_legs[3]["distanceMeters"],
     "walkTimeSeconds":440,"waitingTimeSeconds":360,"transfers":1,"fare":None,"accessible":True,"legs":it2_legs}
w3=W(o_pl,place(S_CL170),0,180,[step("Camina hacia la Calle 170",150,4.7555,-74.0445,"DEPART","Calle 170")])
it3_legs=[w3,
          bus_leg(R_P500,S_CL170,S_C100,SHAPE_P500,600,1500,"Calle 100",[],True,300,"P500-0810"),
          W(place(S_C100),place(S_C100),2100,120,[step("Cruza el puente peatonal a la estación Calle 100",120,4.6858,-74.0553,"CONTINUE","Calle 100")]),
          bus_leg(R_B10,S_C100,S_PS,dens(TRUNK_N[2:]+TRUNK_S[1:]),2400,2700,"Portal Sur",[S_C76,S_C45,S_AVJ,S_RIC,S_NQS30],False,None,"B10-0840"),
          W(place(S_PS),d_pl,5100,200,steps2)]
it3={"id":"it-2","startTime":t(0),"endTime":t(5300),"durationSeconds":5300,"walkDistanceMeters":sum(l["distanceMeters"] for l in it3_legs if l["mode"]=="WALK"),
     "walkTimeSeconds":500,"waitingTimeSeconds":720,"transfers":1,"fare":None,"accessible":None,"legs":it3_legs}
plan={"from":o_pl,"to":d_pl,"itineraries":[it1,it2,it3],"router":{"engine":"otp","version":"2.10.0","realtime":True},"warnings":[]}

city={"id":"bogota","name":"Bogotá","country":"CO","timezone":"America/Bogota","locale":"es-CO",
 "center":{"lat":4.6534,"lon":-74.0836},"bbox":[-74.45,3.95,-73.85,4.90],"defaultZoom":12,
 "modes":["WALK","BUS","CABLE_CAR","BICYCLE"],"branding":{"primaryColor":"#D32F2F","logoUrl":None},
 "features":{"realtimeVehicles":True,"tripUpdates":True,"alerts":True,"fares":False,"bikeShare":False},
 "agencies":[{"id":"1","name":"TransMilenio Troncal","component":"trunk","color":"#D32F2F"},{"id":"2","name":"Alimentadores","component":"feeder","color":"#2E7D32"},
   {"id":"3","name":"Dual","component":"dual","color":"#6A1B9A"},{"id":"4","name":"Zonal Urbano","component":"zonal","color":"#1565C0"},
   {"id":"5","name":"Zonal Complementario","component":"zonal","color":"#1565C0"},{"id":"6","name":"Zonal Especial","component":"zonal","color":"#1565C0"},
   {"id":"7","name":"TransMiCable","component":"cable","color":"#EF6C00"}],
 "attribution":"Datos: TRANSMILENIO S.A. (GTFS) · Mapa: © OpenMapTiles © OpenStreetMap contributors"}
city2={**city,"id":"medellin","name":"Medellín","center":{"lat":6.2442,"lon":-75.5812},"bbox":[-75.75,6.10,-75.45,6.40],"branding":{"primaryColor":"#00838F","logoUrl":None},
 "modes":["WALK","BUS","SUBWAY","TRAM","CABLE_CAR"],"features":{"realtimeVehicles":False,"tripUpdates":False,"alerts":False,"fares":False,"bikeShare":True},
 "agencies":[{"id":"1","name":"Metro de Medellín","component":"rail","color":"#00838F"}],"attribution":"Datos: Metro de Medellín (GTFS) · Mapa: © OpenMapTiles © OpenStreetMap contributors"}

def dep(rt, headsign, off, rtime, delay=None, canceled=False, trip="x"):
    return {"route":rt,"headsign":headsign,"tripId":f"bogota:{trip}","scheduledTime":t(off),"realtimeTime":t(off+(delay or 0)) if rtime else None,
            "realtime":rtime,"delaySeconds":delay if rtime else None,"canceled":canceled,"vehicleId":"V4021" if rtime else None,"stopSequence":1}
departures={"stop":S_PN,"generatedAt":t(0),"departures":[
  dep(R_B10,"Portal Sur",180,True,120,trip="B10-0803"),dep(R_K43,"Ricaurte",420,True,-60,trip="K43-0807"),dep(R_B74,"Museo Nacional",540,False,trip="B74-0809"),
  dep(R_B10,"Portal Sur",780,False,trip="B10-0813"),dep(R_K43,"Ricaurte",1020,False,canceled=True,trip="K43-0817"),dep(R_B74,"Museo Nacional",1200,False,trip="B74-0820"),
  dep(R_B10,"Portal Sur",1380,False,trip="B10-0823"),dep(R_K43,"Ricaurte",1620,False,trip="K43-0827")]}
stop_routes={S_PN["id"]:[R_B10,R_K43,R_B74],S_C100["id"]:[R_B10,R_K43,R_B74,R_P500],S_PS["id"]:[R_B10,R_G12],S_RIC["id"]:[R_K43,R_G12,R_B10],
  S_CL170["id"]:[R_P500],S_CL175["id"]:[R_F1],S_USQ["id"]:[R_A61]}
stops_detail={s["id"]:{**s,"routes":stop_routes.get(s["id"],[R_B10]),"parentStation":None,"children":[]} for s in STOPS}
nearby={"stops":[{**s,"distanceMeters":int(hav(ORIG,(s["lat"],s["lon"])))} for s in STOPS]}

def pattern(id,headsign,dir,shape,stops): return {"id":id,"headsign":headsign,"directionId":dir,"geometry":geom(shape),"stops":stops}
route_detail={
 R_B10["id"]:{**R_B10,"patterns":[pattern("B10:0","Portal Sur",0,SHAPE_B10,[S_PN,S_C100,S_C76,S_C45,S_AVJ,S_RIC,S_NQS30,S_PS]),pattern("B10:1","Portal Norte",1,list(reversed(SHAPE_B10)),[S_PS,S_NQS30,S_RIC,S_AVJ,S_C45,S_C76,S_C100,S_PN])],"alerts":[ALERT_B10]},
 R_K43["id"]:{**R_K43,"patterns":[pattern("K43:0","Ricaurte",0,SHAPE_K43,[S_PN,S_C100,S_C76,S_C45,S_AVJ,S_RIC])],"alerts":[ALERT_B10]},
 R_G12["id"]:{**R_G12,"patterns":[pattern("G12:0","Portal Sur",0,SHAPE_G12,[S_RIC,S_NQS30,S_PS])],"alerts":[]},
 R_B74["id"]:{**R_B74,"patterns":[pattern("B74:0","Museo Nacional",0,SHAPE_B74,[S_PN,S_C100,S_C76,S_C45,S_MUSEO])],"alerts":[]},
 R_P500["id"]:{**R_P500,"patterns":[pattern("P500:0","Calle 100",0,SHAPE_P500,[S_CL170,S_C100])],"alerts":[ALERT_INFO]},
 R_A61["id"]:{**R_A61,"patterns":[pattern("A61:0","Usaquén",0,dens([(S_PN["lat"],S_PN["lon"]),(4.7200,-74.0350),(S_USQ["lat"],S_USQ["lon"])]),[S_PN,S_USQ])],"alerts":[]},
 R_L10["id"]:{**R_L10,"patterns":[pattern("L10:0","Mirador",0,dens([(4.5720,-74.1310),(4.5650,-74.1400),(4.5600,-74.1480)]),[stop("TUN","Portal Tunal",4.5720,-74.1310,"cable"),stop("MIR","Mirador del Paraíso",4.5600,-74.1480,"cable")])],"alerts":[ALERT_L10]},
 R_F1["id"]:{**R_F1,"patterns":[pattern("F1:0","Cl 175",0,dens([(S_PN["lat"],S_PN["lon"]),(S_CL175["lat"],S_CL175["lon"])]),[S_PN,S_CL175])],"alerts":[]},
}
network={"feedVersion":"20260904","shapes":[{"id":k,"routeId":v["id"],"component":v["component"],"color":v["color"],"geometry":v["patterns"][0]["geometry"]} for k,v in [(rid.split(':')[1],r) for rid,r in route_detail.items()]]}

vehicles=[]; vid=4000
for rt, shape in [(R_B10,SHAPE_B10),(R_K43,SHAPE_K43),(R_G12,SHAPE_G12),(R_B74,SHAPE_B74),(R_P500,SHAPE_P500),(R_A61,route_detail[R_A61["id"]]["patterns"][0]["stops"] and dens([(S_PN["lat"],S_PN["lon"]),(4.7200,-74.0350),(S_USQ["lat"],S_USQ["lon"])]))]:
    for k in range(7 if rt["component"]=="trunk" else 3):
        i=random.randrange(len(shape)-1); lat,lon=shape[i]; nlat,nlon=shape[i+1]
        br=(math.degrees(math.atan2(nlon-lon,nlat-lat))+360)%360; vid+=1
        vehicles.append({"id":f"V{vid}","label":f"{'Z' if rt['component']!='trunk' else 'T'}{vid}","routeId":rt["id"],"routeShortName":rt["shortName"],"tripId":f"bogota:{rt['shortName']}-{vid}",
          "tripResolved":random.random()>0.11,"component":rt["component"],"lat":round(lat,5),"lon":round(lon,5),"bearing":round(br),"timestamp":t(-random.randint(5,40)),
          "stopId":None,"stopSequence":None,"occupancy":random.choice(["MANY_SEATS_AVAILABLE","FEW_SEATS_AVAILABLE","STANDING_ROOM_ONLY",None])})
frame={"type":"full","seq":1,"generatedAt":t(0),"feedTimestamp":t(-12),"count":len(vehicles),"health":{"entityAgeP50Seconds":20,"pctTripResolved":89.1,"httpStatus":200},"vehicles":vehicles}
v0=vehicles[0]
vehicle_detail={**v0,"route":R_B10,"trip":{"id":v0["tripId"],"resolved":True,"headsign":"Portal Sur"},"shape":geom(SHAPE_B10),"currentStop":S_C100,"nextStop":S_C76,
  "etaSeconds":240,"delaySeconds":120,"history":{"points":[[lon,lat,int((base+dt.timedelta(seconds=-600+i*60)).timestamp())] for i,(lat,lon) in enumerate(SHAPE_B10[:10])],"avgKmh":24.5},"alerts":[ALERT_B10]}

geocode=[
 {"id":f"stop:{s['id']}","name":s["name"],"label":("Estación troncal" if s["component"]=="trunk" else "Paradero zonal")+" · Bogotá","lat":s["lat"],"lon":s["lon"],"type":s["locationType"],"stopId":s["id"],"component":s["component"],"source":"gtfs"} for s in STOPS]+[
 {"id":"photon:1","name":"Aeropuerto El Dorado","label":"Aeropuerto · Fontibón","lat":4.7016,"lon":-74.1469,"type":"poi","stopId":None,"component":None,"source":"photon"},
 {"id":"photon:2","name":"Universidad Nacional de Colombia","label":"Universidad · Teusaquillo","lat":4.6363,"lon":-74.0836,"type":"poi","stopId":None,"component":None,"source":"photon"},
 {"id":"photon:3","name":"Plaza de Bolívar","label":"Plaza · La Candelaria","lat":4.5981,"lon":-74.0758,"type":"poi","stopId":None,"component":None,"source":"photon"},
 {"id":"photon:4","name":"Centro Comercial Andino","label":"Centro comercial · Chapinero","lat":4.6670,"lon":-74.0530,"type":"poi","stopId":None,"component":None,"source":"photon"},
 {"id":"photon:5","name":"Calle 26","label":"Calle · Bogotá","lat":4.6250,"lon":-74.0900,"type":"street","stopId":None,"component":None,"source":"photon"},
 {"id":"photon:6","name":"Parque Simón Bolívar","label":"Parque · Teusaquillo","lat":4.6584,"lon":-74.0939,"type":"poi","stopId":None,"component":None,"source":"photon"},
]
health={"static":{"feedVersion":"20260904","fetchedAt":t(-3600),"routes":1024,"stops":8309},"realtime":{"lastFetchAt":t(-12),"entityAgeP50Seconds":20,"vehicles":len(vehicles),"pctTripResolved":89.1,"alerts":3},"router":{"up":True,"version":"2.10.0","graphBuiltAt":t(-86400)}}


# ───────────── v1.1 additions (components, fares, config, service windows, board, next, pois) ─────────────
city["components"]=[{"id":"trunk","label":"Troncal","color":"#D32F2F","icon":"brt"},{"id":"feeder","label":"Alimentador","color":"#2E7D32","icon":"bus"},
  {"id":"dual","label":"Dual","color":"#6A1B9A","icon":"bus"},{"id":"zonal","label":"Zonal","color":"#1565C0","icon":"bus"},{"id":"cable","label":"TransMiCable","color":"#EF6C00","icon":"cable"}]
city["fares"]={"currency":"COP","base":3200,"transfer":0,"transferWindowMinutes":110,"maxTransfers":2,"note":"Valores configurables; verificar con tarifa vigente","estimated":True}
city["config"]={"vehiclePollSeconds":15,"departuresRefreshSeconds":20,"features":{"liveVehicles":True,"board":True,"pois":True,"followAlong":True,"bike":True},
  "minAppVersion":{"ios":"0.1.0","android":"0.1.0"},"maintenance":{"active":False,"message":None}}
city["links"]={"pqrs":"https://www.transmilenio.gov.co/publicaciones/147212/pqrs/","recharge":"https://www.tullaveplus.gov.co","support":"https://www.transmilenio.gov.co","privacy":None}
city["services"]=[{"id":"recharge","label":"Recargar tullave","icon":"card","url":"https://www.tullaveplus.gov.co","kind":"external"},
  {"id":"pqrs","label":"PQRS","icon":"help","url":"https://www.transmilenio.gov.co/publicaciones/147212/pqrs/","kind":"external"}]
city2["components"]=[{"id":"rail","label":"Metro","color":"#00838F","icon":"rail"}]
city2["fares"]={"currency":"COP","base":3350,"transfer":0,"transferWindowMinutes":90,"maxTransfers":1,"note":"Tarifa estimada","estimated":True}
city2["config"]=city["config"]; city2["links"]={"pqrs":None,"recharge":None,"support":"https://www.metrodemedellin.gov.co","privacy":None}; city2["services"]=[]

for r in ROUTES:
    r["serviceWindow"]={"start":"04:00","end":"23:00","active":True,"nextStart":None,"source":"gtfs"}
R_L10["serviceWindow"]={"start":"05:00","end":"09:00","active":False,"nextStart":"14:00","source":"gtfs"}
R_F1["serviceWindow"]={"start":"04:30","end":"22:00","active":True,"nextStart":None,"source":"gtfs"}

for s_ in STOPS:
    s_["accessibility"]={"wheelchair":s_["wheelchair"],"source":"gtfs" if s_["wheelchair"]!="unknown" else "none","verified":False,
                         "note":"Dato del feed no verificado" if s_["wheelchair"]!="unknown" else None}

def fare_for(it):
    n=sum(1 for l in it["legs"] if l["transit"])
    if n==0: return None
    transfers=min(n-1, 2)
    return {"amount":3200+0*transfers,"currency":"COP","estimated":True,"breakdown":[{"label":"Pasaje","amount":3200}]+([{"label":"Transbordo","amount":0}] if transfers else [])}
for it in (it1,it2,it3): it["fare"]=fare_for(it)

def _mins(off): return int(round(off/60))
board={"stop":S_PN,"generatedAt":t(0),"freshness":{"realtime":True,"ageSeconds":18,"stale":False},"rows":[
  {"route":R_B10,"headsign":"Portal Sur","next":[{"time":t(300),"minutes":5,"realtime":True,"delaySeconds":120,"tripId":"bogota:B10-0803","vehicleId":"V4021"},
                                                {"time":t(780),"minutes":13,"realtime":False,"delaySeconds":None,"tripId":"bogota:B10-0813","vehicleId":None},
                                                {"time":t(1380),"minutes":23,"realtime":False,"delaySeconds":None,"tripId":"bogota:B10-0823","vehicleId":None}]},
  {"route":R_K43,"headsign":"Ricaurte","next":[{"time":t(360),"minutes":6,"realtime":True,"delaySeconds":-60,"tripId":"bogota:K43-0807","vehicleId":"V4022"},
                                             {"time":t(1620),"minutes":27,"realtime":False,"delaySeconds":None,"tripId":"bogota:K43-0827","vehicleId":None}]},
  {"route":R_B74,"headsign":"Museo Nacional","next":[{"time":t(540),"minutes":9,"realtime":False,"delaySeconds":None,"tripId":"bogota:B74-0809","vehicleId":None},
                                                    {"time":t(1200),"minutes":20,"realtime":False,"delaySeconds":None,"tripId":"bogota:B74-0820","vehicleId":None}]},
]}
vb10=[v for v in vehicles if v["routeId"]==R_B10["id"]]
nxt={"stop":S_PN,"route":R_B10,"freshness":{"realtime":True,"ageSeconds":18,"stale":False},"next":[
  {"minutes":4,"time":t(240),"source":"live","vehicle":vb10[0],"stopsAway":2,"distanceMeters":1450,"tripId":vb10[0]["tripId"]},
  {"minutes":11,"time":t(660),"source":"estimated","vehicle":vb10[1],"stopsAway":5,"distanceMeters":4200,"tripId":vb10[1]["tripId"]},
  {"minutes":23,"time":t(1380),"source":"scheduled","vehicle":None,"stopsAway":None,"distanceMeters":None,"tripId":"bogota:B10-0823"},
]}
def poi(i,typ,name,lat,lon,wc=None): return {"type":"Feature","id":f"osm:{i}","properties":{"id":f"osm:{i}","type":typ,"name":name,"source":"osm","osmId":i,"wheelchair":wc},"geometry":{"type":"Point","coordinates":[lon,lat]}}
pois={"type":"FeatureCollection","features":[
  poi(1001,"bike_parking","Cicloparqueadero Portal Norte",4.7552,-74.0465,"yes"),poi(1002,"toilets","Baños Portal Norte",4.7548,-74.0455),
  poi(1003,"atm","Cajero Portal Norte",4.7543,-74.0462),poi(1004,"library","BiblioEstación Portal Norte",4.7549,-74.0450),
  poi(1005,"bike_parking","Cicloparqueadero Calle 100",4.6862,-74.0549,"yes"),poi(1006,"health","Punto de salud Av. Jiménez",4.6010,-74.0770),
  poi(1007,"bike_parking","Cicloparqueadero Portal Sur",4.5982,-74.1620,"yes"),poi(1008,"toilets","Baños Portal Sur",4.5975,-74.1612),
  poi(1009,"atm","Cajero Ricaurte",4.6120,-74.0925),poi(1010,"library","BiblioEstación Ricaurte",4.6115,-74.0935)]}
health["realtime"].update({"enabled":True,"stale":False,"staleSeconds":None})

os.makedirs(OUT,exist_ok=True)
files={"cities":{"cities":[city,city2]},"plan":plan,"stops_nearby":nearby,"stops":stops_detail,"departures":departures,
       "routes":{"routes":ROUTES},"route_detail":route_detail,"network":network,"vehicles":frame,"vehicle_detail":vehicle_detail,
       "alerts":{"alerts":[ALERT_B10,ALERT_L10,ALERT_INFO]},"geocode":{"results":geocode},"health":health,"board":board,"next":nxt,"pois":pois}
for k,v in files.items():
    json.dump(v,open(f"{OUT}/{k}.json","w"),ensure_ascii=False,indent=1)
print({k:os.path.getsize(f"{OUT}/{k}.json") for k in files})


# ───────────── v1.2 shared bikes (Tembici Bogotá, GBFS) ─────────────
TEMBICI={"id":"tembici","name":"Tembici Bogotá","network":"tembici_bogota",
  "gbfsUrl":"https://bogota.publicbikesystem.net/customer/gbfs/v3.0/gbfs.json","color":"#00A859","url":"https://tembici.com.co/",
  "apps":{"ios":"https://apps.apple.com/co/app/id1454932002","android":"https://play.google.com/store/apps/details?id=com.tembici.app"},
  "pricingSummary":"Pase diario $11.000 · mensual $31.990","formFactors":["bicycle","scooter"]}
city["features"]["bikeShare"]=True
city["config"]["features"]["bikeShare"]=True
city["mobility"]={"bikeShare":[TEMBICI]}
# A second city with TWO networks proves nothing is single-provider.
city2["mobility"]={"bikeShare":[
  {"id":"encicla","name":"EnCicla","network":"encicla_medellin","gbfsUrl":"https://example.org/encicla/gbfs.json","color":"#0B7A3B","url":"https://www.encicla.gov.co/","apps":{"ios":None,"android":None},"pricingSummary":"Gratis con Cívica","formFactors":["bicycle"]},
  {"id":"movo","name":"Movo","network":"movo_medellin","gbfsUrl":"https://example.org/movo/gbfs.json","color":"#7B1FA2","url":"https://example.org/movo","apps":{"ios":None,"android":None},"pricingSummary":"Desde $2.000 por viaje","formFactors":["scooter"]}]}

# 60 Tembici-like docking stations between Chapinero and Usaquén.
random.seed(11)
rstations=[]
for i in range(60):
    lat=round(random.uniform(4.640,4.705),6); lon=round(random.uniform(-74.072,-74.030),6)
    cl=int(round((lat-4.5978)/0.00093))+57; kr=int(round((-74.0836-lon)/0.00095))+7
    cap=random.choice([11,15,19,23,27]); bikes=random.randint(0,cap-2); eb=random.randint(0,min(4,bikes)); docks=cap-bikes-random.randint(0,2)
    rstations.append({"id":f"tembici:{i+1}","networkId":"tembici","name":f"{i+1:03d} - CL {cl} con KR {kr}","lat":lat,"lon":lon,
      "capacity":cap,"vehiclesAvailable":bikes,"ebikesAvailable":eb,"docksAvailable":max(docks,0),
      "isInstalled":True,"isRenting":bikes>0 or random.random()>0.1,"isReturning":True,"lastReported":t(-random.randint(5,90))})
# Two named stations used by the rental itineraries.
ST_93={"id":"tembici:12","networkId":"tembici","name":"012 - CL 93 con KR 13","lat":4.6772,"lon":-74.0500,"capacity":19,"vehiclesAvailable":6,"ebikesAvailable":2,"docksAvailable":13,"isInstalled":True,"isRenting":True,"isReturning":True,"lastReported":t(-18)}
ST_100={"id":"tembici:31","networkId":"tembici","name":"031 - CL 100 con KR 15 (TransMilenio)","lat":4.6852,"lon":-74.0548,"capacity":23,"vehiclesAvailable":3,"ebikesAvailable":0,"docksAvailable":4,"isInstalled":True,"isRenting":True,"isReturning":True,"lastReported":t(-25)}
rstations[11]=ST_93; rstations[30]=ST_100
rental_networks={"networks":[{**TEMBICI,"systemId":"bogota_bike","timezone":"America/Bogota","stations":len(rstations),
  "vehicleTypes":[{"id":"FIT","formFactor":"bicycle","propulsion":"human","name":"Clásica"},{"id":"EFIT","formFactor":"bicycle","propulsion":"electric_assist","name":"Eléctrica"},{"id":"CHLOE","formFactor":"scooter","propulsion":"electric","name":"Patineta"}],
  "pricingPlans":[{"id":"daily","name":"Pase diario","price":11000,"currency":"COP","description":"Viajes de hasta 45 min durante 24 h","isTaxable":False},{"id":"monthly","name":"Mensual","price":31990,"currency":"COP","description":"Viajes de hasta 45 min todo el mes","isTaxable":False}],
  "lastFetchAt":t(-12),"up":True}]}
rental_stations={"generatedAt":t(0),"ttlSeconds":30,"stations":rstations}

def rplace(st, arr=None, dep=None): return {"name":st["name"],"lat":st["lat"],"lon":st["lon"],"stopId":None,"stopCode":None,"arrival":arr,"departure":dep,"component":None,"rentalStationId":st["id"]}
def rental_leg(frm, to, start, secs, shape, price=True):
    return {"mode":"BICYCLE","transit":False,"startTime":t(start),"endTime":t(start+secs),"durationSeconds":secs,"distanceMeters":int(length(shape)),
            "from":rplace(frm,dep=t(start)),"to":rplace(to,arr=t(start+secs)),"route":None,"headsign":None,"agency":None,"tripId":None,
            "realtime":False,"realtimeState":None,"delaySeconds":None,"geometry":geom(shape),"intermediateStops":[],"steps":[],"alerts":[],
            "rental":{"networkId":"tembici","networkName":"Tembici Bogotá","color":"#00A859","vehicleType":"bicycle",
                      "pickup":{**frm,"stationId":frm["id"]},"dropoff":{**to,"stationId":to["id"]},"freeFloating":False,
                      "priceEstimate":{"amount":11000,"currency":"COP","label":"Pase diario","estimated":True} if price else None}}
P93=place(name="Parque de la 93",lat=4.6766,lon=-74.0483); P100=place(name="Calle 100 - Marketmedios",lat=4.6841,lon=-74.0517)
rw1=W(P93,rplace(ST_93),0,120,[step("Camina hacia la Calle 93",90,4.6768,-74.0490,"DEPART","Calle 93")])
bike_shape=dens([(ST_93["lat"],ST_93["lon"]),(4.6800,-74.0520),(4.6830,-74.0540),(ST_100["lat"],ST_100["lon"])],5)
rleg=rental_leg(ST_93,ST_100,180,540,bike_shape)
rw2=W(rplace(ST_100),P100,780,150,[step("Camina hacia la estación Calle 100",120,4.6848,-74.0530,"DEPART","Calle 100")])
itr0={"id":"it-r0","startTime":t(0),"endTime":t(930),"durationSeconds":930,"walkDistanceMeters":rw1["distanceMeters"]+rw2["distanceMeters"],
      "walkTimeSeconds":270,"waitingTimeSeconds":60,"transfers":0,"accessible":None,"legs":[rw1,rleg,rw2],"rentalLegs":1,"modesUsed":["WALK","BICYCLE_RENTAL"],
      "fare":{"amount":11000,"currency":"COP","estimated":True,"breakdown":[{"label":"Tembici · pase diario","amount":11000,"kind":"rental"}]}}
rw3=W(rplace(ST_100),place(S_C100),780,120,[step("Cruza el puente peatonal a la estación Calle 100",120,4.6858,-74.0553,"CONTINUE","Calle 100")])
rbus=bus_leg(R_B10,S_C100,S_PS,dens(TRUNK_N[2:]+TRUNK_S[1:]),1080,2700,"Portal Sur",[S_C76,S_C45,S_AVJ,S_RIC,S_NQS30],True,60,"B10-0818")
rw4=W(place(S_PS),d_pl,3780,200,steps2)
itr1={"id":"it-r1","startTime":t(0),"endTime":t(3980),"durationSeconds":3980,"walkDistanceMeters":rw1["distanceMeters"]+rw3["distanceMeters"]+rw4["distanceMeters"],
      "walkTimeSeconds":440,"waitingTimeSeconds":180,"transfers":0,"accessible":None,"legs":[rw1,rleg,rw3,rbus,rw4],"rentalLegs":1,"modesUsed":["WALK","BICYCLE_RENTAL","BUS"],
      "fare":{"amount":14200,"currency":"COP","estimated":True,"breakdown":[{"label":"Pasaje","amount":3200,"kind":"transit"},{"label":"Tembici · pase diario","amount":11000,"kind":"rental"}]}}
plan_rental={"itineraries":[itr0,itr1]}
health["rental"]={"networks":[{"id":"tembici","up":True,"stations":len(rstations),"vehiclesAvailable":sum(s["vehiclesAvailable"] for s in rstations),"ageSeconds":12}]}

for k,v in {"cities":{"cities":[city,city2]},"health":health,"rental_networks":rental_networks,"rental_stations":rental_stations,"plan_rental":plan_rental}.items():
    json.dump(v,open(f"{OUT}/{k}.json","w"),ensure_ascii=False,indent=1)
print("rental fixtures:", {k:os.path.getsize(f"{OUT}/{k}.json") for k in ("rental_networks","rental_stations","plan_rental")})


# ───────────── v1.4 on-demand mobility (taxi, ride-hailing) ─────────────
# Provider names live ONLY here (fixtures) and in the API's city YAML.
TARIFF={"id":"bogota-taxi-2026","name":"Tarifa oficial de taxi 2026","currency":"COP","flagFall":4500,"unitPrice":159,"unitMeters":100,"unitSeconds":30,"minimumFare":8000,
  "surcharges":[{"id":"night","label":"Nocturno / dominical / festivo","amount":3800,"when":{"nightFrom":"19:00","nightTo":"06:00","sundays":True,"holidays":True}},
                {"id":"airport","label":"Aeropuerto","amount":8000,"when":{"zones":["airport"]}},
                {"id":"door","label":"Puerta a puerta","amount":1500,"when":{"optional":True}}],
  "zones":[{"id":"airport","name":"Aeropuerto El Dorado","polygon":[[-74.16,4.68],[-74.13,4.68],[-74.13,4.72],[-74.16,4.72]]}],
  "source":{"label":"Decreto Distrital 042 de 2026","url":"https://bogota.gov.co/mi-ciudad/movilidad/en-firme-el-decreto-que-fija-las-tarifas-de-taxi-en-bogota-en-2026"},
  "validFrom":"2026-02-12","note":"Estimación según tarifa oficial; el taxímetro manda."}
def prov(id,name,kind,color,text,est,handoff,order,apps=None,web=None,template=None):
    return {"id":id,"name":name,"kind":kind,"color":color,"textColor":text,"logoUrl":None,
            "estimate":est,"handoff":{"kind":handoff,"template":template,"web":web,"apps":apps or {"ios":None,"android":None},"scheme":None},
            "enabled":True,"order":order}
ONDEMAND=[
  prov("taxi","Taxi","taxi","#F2C200","#111111",{"kind":"tariff","tariffId":TARIFF["id"]},"url",1,
       apps={"ios":"https://apps.apple.com/co/app/id511140577","android":"https://play.google.com/store/apps/details?id=com.taxislibres.app"},web="https://www.taxislibres.com.co/"),
  prov("uber","Uber","ridehail","#000000","#FFFFFF",{"kind":"none"},"template",2,
       apps={"ios":"https://apps.apple.com/co/app/id368677368","android":"https://play.google.com/store/apps/details?id=com.ubercab"},web="https://m.uber.com/",
       template="https://m.uber.com/looking?client_id={clientId}&pickup={pickupJson}&drop[0]={dropoffJson}"),
  prov("cabify","Cabify","ridehail","#7145D6","#FFFFFF",{"kind":"none"},"url",3,
       apps={"ios":"https://apps.apple.com/co/app/id476087442","android":"https://play.google.com/store/apps/details?id=com.cabify.rider"},web="https://cabify.com/co"),
  prov("didi","DiDi","ridehail","#FF7F41","#111111",{"kind":"none"},"url",4,
       apps={"ios":"https://apps.apple.com/co/app/id1362320138","android":"https://play.google.com/store/apps/details?id=com.didiglobal.passenger"},web="https://web.didiglobal.com/co/"),
  prov("indrive","inDrive","ridehail","#A6E22E","#111111",{"kind":"none"},"url",5,
       apps={"ios":"https://apps.apple.com/co/app/id780125801","android":"https://play.google.com/store/apps/details?id=sinet.startup.inDriver"},web="https://indrive.com/"),
]
POLICY={"maxDirectDistanceKm":40,"firstLastMile":True,"maxFeederKm":8,"showWhenTransitFaster":True}
city["features"]["onDemand"]=True; city["config"]["features"]["onDemand"]=True
city["mobility"].update({"taxiTariffs":[TARIFF],"onDemand":ONDEMAND,"onDemandPolicy":POLICY})
# Second city: two providers (a taxi with its own tariff, one app) — parametrised, not Bogotá-shaped.
TARIFF2={**TARIFF,"id":"medellin-taxi-2026","name":"Tarifa de taxi Medellín 2026","flagFall":4000,"unitPrice":140,"minimumFare":7500,"source":{"label":"Resolución AMVA 2026","url":"https://www.metropol.gov.co/"},"zones":[]}
city2["features"]["onDemand"]=True; city2["config"]["features"]["onDemand"]=True
city2["mobility"].update({"taxiTariffs":[TARIFF2],"onDemand":[
  prov("taxi","Taxi Medellín","taxi","#FFC107","#111111",{"kind":"tariff","tariffId":TARIFF2["id"]},"none",1),
  prov("app-x","Ride App X","ridehail","#0097A7","#FFFFFF",{"kind":"none"},"url",2,web="https://example.org/ride-x")],"onDemandPolicy":POLICY})

def pub(p): return {**{k:v for k,v in p.items() if k!="handoff"},"handoff":{"kind":p["handoff"]["kind"],"hasTemplate":bool(p["handoff"]["template"]),"web":p["handoff"]["web"],"apps":p["handoff"]["apps"],"scheme":None}}
ondemand_providers={"providers":[pub(p) for p in ONDEMAND]}

def taxi_price(meters, secs, night=False):
    units=-(-meters//100); wait=max(0,int((secs-meters/(30*1000/3600))//30))
    fare=max(8000, 4500+(units+wait)*159); lines=[{"id":"base","label":"Tarifa oficial de taxi 2026","amount":fare}]; applied=[]
    if night: fare+=3800; lines.append({"id":"night","label":"Nocturno / dominical / festivo","amount":3800}); applied.append("night")
    fare=int(round(fare/100.0))*100
    return {"amount":fare,"min":int(round(fare*0.9/100.0))*100,"max":int(round(fare*1.1/100.0))*100,"currency":"COP","estimated":True,"breakdown":lines,"surchargesApplied":applied}
def handoff_url(pid, frm, to): return f"https://api.example.org/v1/cities/bogota/ondemand/handoff?providerId={pid}&fromLat={frm['lat']}&fromLon={frm['lon']}&toLat={to['lat']}&toLon={to['lon']}&fromName={frm['name'].replace(' ','+')}&toName={to['name'].replace(' ','+')}"
def options(frm, to, meters, secs):
    out=[]
    for p in ONDEMAND:
        out.append({"providerId":p["id"],"name":p["name"],"color":p["color"],"price":taxi_price(meters,secs) if p["estimate"]["kind"]=="tariff" else None,
                    "waitSeconds":240 if p["id"]=="taxi" else None,"handoffUrl":handoff_url(p["id"],frm,to),"source":"tariff" if p["estimate"]["kind"]=="tariff" else "none"})
    return out
def car_leg(frm_pl, to_pl, start, secs, shape):
    meters=int(length(shape))
    return {"mode":"CAR","transit":False,"startTime":t(start),"endTime":t(start+secs),"durationSeconds":secs,"distanceMeters":meters,
            "from":{**frm_pl,"departure":t(start)},"to":{**to_pl,"arrival":t(start+secs)},"route":None,"headsign":None,"agency":None,"tripId":None,
            "realtime":False,"realtimeState":None,"delaySeconds":None,"geometry":geom(shape),"intermediateStops":[],"steps":[],"alerts":[],
            "onDemand":{"kind":"taxi","providers":options(frm_pl,to_pl,meters,secs),"recommendedProviderId":"taxi"}}
# Direct ride: origin → destination by car along the trunk corridor.
car_shape=dens([ORIG]+TRUNK_N[1:]+TRUNK_S[1:]+[DEST],3)
cleg=car_leg(o_pl,d_pl,0,2280,car_shape)
tp=cleg["onDemand"]["providers"][0]["price"]
ito0={"id":"it-od0","startTime":t(0),"endTime":t(2280),"durationSeconds":2280,"walkDistanceMeters":0,"walkTimeSeconds":0,"waitingTimeSeconds":240,"transfers":0,"accessible":None,
      "legs":[cleg],"rentalLegs":0,"modesUsed":["CAR_ONDEMAND"],"source":"ondemand",
      "fare":{"amount":tp["amount"],"currency":"COP","estimated":True,"breakdown":[{"label":"Taxi (estimado)","amount":tp["amount"],"kind":"ondemand"}]}}
# First-mile combo: taxi to Calle 100, then the trunk bus to Portal Sur.
feeder_shape=dens([ORIG,(4.7400,-74.0480),(4.7100,-74.0520),(S_C100["lat"],S_C100["lon"])],4)
fleg=car_leg(o_pl,place(S_C100),0,780,feeder_shape)
fbus=bus_leg(R_B10,S_C100,S_PS,dens(TRUNK_N[2:]+TRUNK_S[1:]),960,2700,"Portal Sur",[S_C76,S_C45,S_AVJ,S_RIC,S_NQS30],True,60,"B10-0816")
fw=W(place(S_PS),d_pl,3660,200,steps2)
fp=fleg["onDemand"]["providers"][0]["price"]
ito1={"id":"it-od1","startTime":t(0),"endTime":t(3860),"durationSeconds":3860,"walkDistanceMeters":fw["distanceMeters"],"walkTimeSeconds":200,"waitingTimeSeconds":420,"transfers":0,"accessible":None,
      "legs":[fleg,fbus,fw],"rentalLegs":0,"modesUsed":["CAR_ONDEMAND","BUS","WALK"],"source":"ondemand",
      "fare":{"amount":fp["amount"]+3200,"currency":"COP","estimated":True,"breakdown":[{"label":"Taxi (estimado)","amount":fp["amount"],"kind":"ondemand"},{"label":"Pasaje","amount":3200,"kind":"transit"}]}}
plan_ondemand={"itineraries":[ito0,ito1]}
health["ondemand"]={"providers":len(ONDEMAND),"tariffs":1,"routerCar":True}
for k,v in {"cities":{"cities":[city,city2]},"health":health,"ondemand_providers":ondemand_providers,"plan_ondemand":plan_ondemand}.items():
    json.dump(v,open(f"{OUT}/{k}.json","w"),ensure_ascii=False,indent=1)
print("ondemand fixtures:", {k:os.path.getsize(f"{OUT}/{k}.json") for k in ("ondemand_providers","plan_ondemand")}, "direct taxi price", tp, "feeder", fp["amount"])
