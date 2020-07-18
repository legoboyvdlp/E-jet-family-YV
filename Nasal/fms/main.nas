var fast_update = func () {
    update_fms_speed();
};

var slow_update = func () {
    vnav.update();
    update_radios();
};

var activeRoute = nil;
var modifiedRoute = nil;

var modifiedFlightplan = nil;

var getModifyableFlightplan = func () {
    if (modifiedFlightplan == nil) {
        var fp = flightplan();
        if (fp == nil) {
            modifiedFlightplan = createFlightplan();
        }
        else {
            modifiedFlightplan = flightplan().clone();
        }
    }
    return modifiedFlightplan;
};

var commitFlightplan = func () {
    if (modifiedFlightplan != nil) {
        var current = modifiedFlightplan.current;
        modifiedFlightplan.activate();
        modifiedFlightplan.current = current;
        modifiedFlightplan = nil;
    }
    return flightplan();
};

var discardFlightplan = func () {
    modifiedFlightplan = nil;
    return flightplan();
};

setlistener("autopilot/route-manager/signals/edited", func {
    modifiedRoute = nil;
    activeRoute = Route.new(flightplan());
});

setlistener("sim/signals/fdm-initialized", func {
	var tfast = maketimer(0.1, func () { fast_update(); });
    tfast.simulatedTime = 1;
    tfast.singleShot = 0;
	tfast.start();

	var tslow = maketimer(1, func () { slow_update(); });
    tslow.simulatedTime = 1;
    tslow.singleShot = 0;
	tslow.start();
});
