#!/usr/bin/env python3
"""unofficial fellow corvo kettle: tiny local server for the control panel.
serves index.html and turns clicks into verified kettle-api calls.
listens on localhost only, and refuses requests from other websites."""
import json, os, sys, time, urllib.request
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from importlib.machinery import SourceFileLoader

HERE = os.path.dirname(os.path.abspath(__file__))
kapi = SourceFileLoader("kapi", os.environ.get("KETTLE_API", os.path.expanduser("~/.local/bin/kettle-api"))).load_module()
PORT = int(os.environ.get("KETTLE_PANEL_PORT", "8737"))
_info = {"at": 0, "data": None}

def info():
    # firmware rarely changes; re-read every 10 minutes
    if _info["data"] is None or time.time() - _info["at"] > 600:
        try:
            _info["data"] = kapi.info()
        except BaseException:
            pass
        _info["at"] = time.time()
    return _info["data"] or {"model": kapi.MODEL}

def live():
    try:
        return kapi.status()
    except Exception:
        return None

def state():
    if not kapi.IP:
        return {"online": False, "unconfigured": True, "info": {"model": kapi.MODEL}}
    t = live()
    if not t:
        return {"online": False, "info": _info["data"] or {"model": kapi.MODEL}}
    try:
        s = kapi.read(); s.pop("_hex", None)
    except BaseException:
        s = None
    return {"online": True, "live": t, "settings": s, "info": info()}

def run(fn, *args):
    try:
        return {"ok": True, "msg": fn(*args)}
    except SystemExit as e:
        return {"ok": False, "msg": str(e)}
    except Exception as e:
        return {"ok": False, "msg": f"couldn't reach the kettle ({e.__class__.__name__})"}

def heat(on):
    kapi.cli("setstate S_Heat" if on else "setstate S_Off")
    return "heating" if on else "stopped"

def beep():
    kapi.cli("buz 880 1000 150"); return "beep!"

ACTIONS = {
    "on":       lambda a: run(heat, True),
    "off":      lambda a: run(heat, False),
    "beep":     lambda a: run(beep),
    "temp":     lambda a: run(kapi.set_temp, a["value"]),
    "set":      lambda a: run(kapi.SETTERS[a["key"]], a["value"]) if a.get("key") in kapi.SETTERS
                          else {"ok": False, "msg": "unknown setting"},
    "clock":    lambda a: run(kapi.set_clock, a.get("value")),
    "schedule": lambda a: run(kapi.schedule, a["time"], a["temp"], a["mode"]),
    "unschedule": lambda a: run(kapi.schedule_off),
}

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def send(self, code, body, ctype="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            with open(os.path.join(HERE, "index.html"), "rb") as f:
                return self.send(200, f.read(), "text/html; charset=utf-8")
        if self.path == "/state":
            return self.send(200, state())
        self.send(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/action":
            return self.send(404, {"error": "not found"})
        # only accept same-origin requests from this page
        origin = self.headers.get("Origin", "")
        if origin and origin not in (f"http://localhost:{PORT}", f"http://127.0.0.1:{PORT}"):
            return self.send(403, {"ok": False, "msg": "forbidden"})
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
            fn = ACTIONS.get(body.get("action"))
            if not fn:
                return self.send(400, {"ok": False, "msg": "unknown action"})
            self.send(200, fn(body))
        except (KeyError, ValueError, TypeError) as e:
            self.send(400, {"ok": False, "msg": f"bad request: {e}"})

if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
