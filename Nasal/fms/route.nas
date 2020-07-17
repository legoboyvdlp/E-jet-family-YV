var Route =  {
    new: func (fp = nil) {
        var m = {
            parents: [Route],
            departure: nil,
            departureRunway: nil,
            destination: nil,
            destinationRunway: nil,
            sid: nil,
            sidTransition: nil,
            star: nil,
            starTransition: nil,
            iap: nil,
            enroute: [],
        };
        if (fp != nil) {
            m.fillFromFlightplan(fp);
        }
        return m;
    },

    fillFromFlightplan: func (fp) {
        me.departure = fp.departure;
        me.departureRunway = fp.departure_runway;
        me.destination = fp.destination;
        me.destinationRunway = fp.destination_runway;
        me.sid = fp.sid;
        me.star = fp.star;
        me.sidTransition = fp.sid_trans;
        me.starTransition = fp.star_trans;
        me.iap = fp.approach;
        # start at 1, because we want to skip the departure
        for (var i = 1; i < fp.getPlanSize(); i += 1) {
            var wp = fp.getWP(i);
            if (wp.wp_parent == nil and wp.wp_type != 'basic' and wp.wp_type != "runway") {
                # not owned by a procedure, let's append it!
                printf("%6s %s", wp.id, wp.wp_type);
                append(me.enroute, ["DCT", wp]);
            }
        }
    },

    getLegs: func () {
        var legs = [];
        if (me.sid != nil) {
            var sidID = me.sid.id;
            var wp = me.sid.route()[-1];
            if (me.sidTransition != nil) {
                sidID ~= "." ~ me.sidTransition.id;
                wp = me.sidTransition.route()[-1];
            }
            append(legs, [sidID, wp]);
        }
        foreach (var wpp; me.enroute) {
            append(legs, wpp);
        }
        if (me.destination != nil) {
            var lastWP = me.destination;
            var firstArrivalWP = nil;
            var arrivalRoute = [];
            if (me.star != nil) {
                firstArrivalWP = me.star.route()[0];
                append(arrivalRoute, me.star.id);
            }
            if (me.starTransition != nil) {
                if (firstArrivalWP == nil) {
                    firstArrivalWP = me.starTransition.route()[0];
                }
                append(arrivalRoute, me.starTransition.id);
            }
            if (me.iap != nil) {
                if (firstArrivalWP == nil) {
                    firstArrivalWP = me.iap.route()[0];
                }
                append(arrivalRoute, me.iap.id);
            }
            if (size(arrivalRoute) == 0) {
                legRouteName = "DCT";
            }
            else {
                legRouteName = "";
                foreach (var part; arrivalRoute) {
                    printf("Append %s", part);
                    if (legRouteName == "") {
                        legRouteName = part;
                    }
                    else {
                        legRouteName = legRouteName ~ "." ~ part;
                    }
                    printf("Route name is now: %s", legRouteName);
                }
            }
            if (firstArrivalWP != nil) {
                append(legs, ["DCT", firstArrivalWP]);
            }
            append(legs, [legRouteName, lastWP]);
        }
        return legs;
    },
};
