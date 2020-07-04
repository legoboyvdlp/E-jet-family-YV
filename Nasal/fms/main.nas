var fast_update = func () {
    update_fms_speed();
};

var slow_update = func () {
    update_vnav();
    update_radios();
};

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
