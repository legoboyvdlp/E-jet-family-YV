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

var checkDmeHold = func (n) {
    var source = getprop("/instrumentation/dme[" ~ n ~ "]/frequencies/source");
    return (substr(source, 0, 20)  != "/instrumentation/nav");
};

var setDmeHold = func (n, hold) {
    if (hold) {
        setprop(
            "/instrumentation/dme[" ~ n ~ "]/frequencies/source",
            "/instrumentation/dme[" ~ n ~ "]/frequencies/selected-mhz");
    }
    else {
        setprop(
            "/instrumentation/dme[" ~ n ~ "]/frequencies/source",
            "/instrumentation/nav[" ~ n ~ "]/frequencies/selected-mhz");
    }
};

var updateDmeHold = func (n) {
    if (getprop("/instrumentation/dme[" ~ n ~ "]/hold")) {
        setDmeHold(n, 1);
    }
    else {
        setDmeHold(n, 0);
    }
};

setprop("/instrumentation/dme[0]/hold", 0);
setprop("/instrumentation/dme[1]/hold", 0);
updateDmeHold(0);
updateDmeHold(1);

setlistener("sim/signals/fdm-initialized", func {
    update_xpdr();
});

setlistener("/fms/radio/tcas-xpdr/stby", func { update_xpdr(); });
setlistener("/fms/radio/tcas-xpdr/mode", func { update_xpdr(); });
setlistener("/instrumentation/dme[0]/hold", func { updateDmeHold(0); });
setlistener("/instrumentation/dme[1]/hold", func { updateDmeHold(1); });
