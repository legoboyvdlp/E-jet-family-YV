setprop("/instrumentation/transponder/standby-id", "2000");

var update_radios = func () {
    var distanceRemaining = getprop("/autopilot/route-manager/distance-remaining-nm");
    var fp = flightplan();
    if (fp == nil) return;
    if (distanceRemaining > 30) return;
    var rwy = fp.destination_runway;
    if (rwy == nil) return;
    var freq = rwy.ils_frequency_mhz;
    if (freq == nil) return;
    for (var i = 0; i < 2; i += 1) {
        if (getprop("/fms/radio/nav-auto[" ~ i ~ "]")) {
            setprop("/instrumentation/nav[" ~ i ~ "]/frequencies/selected-mhz", freq);
        }
    }
};

var xpdrmodes = [ 1, 4, 5, 5, 5 ];
var tcasmodes = [ 1, 1, 1, 2, 3 ];

var update_xpdr = func () {
    var mode = getprop("/fms/radio/tcas-xpdr/mode");
    var enabled = getprop("/fms/radio/tcas-xpdr/enabled");
    if (!enabled) {
        mode = 0;
    }
    var xpdr = xpdrmodes[mode];
    var tcas = tcasmodes[mode];
    setprop("/instrumentation/transponder/knob-mode", xpdr);
    setprop("/instrumentation/tcas/inputs/mode", tcas);
};

setlistener("sim/signals/fdm-initialized", func { update_xpdr(); });
setlistener("/fms/radio/tcas-xpdr/stby", func { update_xpdr(); });
setlistener("/fms/radio/tcas-xpdr/mode", func { update_xpdr(); });
