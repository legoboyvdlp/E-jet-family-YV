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
