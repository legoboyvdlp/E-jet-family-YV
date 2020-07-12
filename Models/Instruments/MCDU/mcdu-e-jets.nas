# Embraer E-Jet family MCDU.
#
# E190 AOM:
# - p1582: T/O DATASET menu
# - p1761: MCDU CONTROLS
# - p1804: RADIO COMMUNICATION SYSTEM
# - p1822: ACARS etc.
# - p1859: IRS
# - p1901: Preflight flow

# -------------- UTILITY CRUFT -------------- 

var utf8NumBytes = func (c) {
    if ((c & 0x80) == 0x00) { return 1; }
    if ((c & 0xE0) == 0xC0) { return 2; }
    if ((c & 0xF0) == 0xE0) { return 3; }
    if ((c & 0xF8) == 0xF0) { return 4; }
    printf("UTF8 error (%d / %02x)", c, c);
    return 1;
};

var parseOctal = func (s) {
    var val = 0;
    for (var i = 0; i < size(s); i += 1) {
        val = val * 8;
        var c = s[i];
        if (c < 48 or c > 55) {
            return nil;
        }
        val += c - 48;
    }
    return val;
};

var vecfind = func (needle, haystack) {
    forindex (var i; haystack) {
        if (haystack[i] == needle) {
            return i;
        }
    }
    return -1;
};

var swapProps = func (prop1, prop2) {
    fgcommand("property-swap", {
        "property[0]": prop1,
        "property[1]": prop2
    });
};

var prepended = func (val, vec) {
    var result = [val];
    foreach (var v; vec) {
        append(result, v);
    }
    return result;
};

var lsks =
    { "L1": 1
    , "L2": 3
    , "L3": 5
    , "L4": 7
    , "L5": 9
    , "L6": 11
    , "R1": 2
    , "R2": 4
    , "R3": 6
    , "R4": 8
    , "R5": 10
    , "R6": 12
    };

var lskIndex = func (cmd) {
    if (contains(lsks, cmd)) {
        return lsks[cmd];
    }
    else {
        return 0;
    }
};

var isLSK = func (cmd) { return (lskIndex(cmd) != 0); }

var dials =
    { "INC1": 1
    , "INC2": 2
    , "INC3": 3
    , "INC4": 4
    , "DEC1": -1
    , "DEC2": -2
    , "DEC3": -3
    , "DEC4": -4
    };

var dialIndex = func (cmd) {
    if (contains(dials, cmd)) {
        return dials[cmd];
    }
    else {
        return 0;
    }
};

var isDial = func (cmd) { return (dialIndex(cmd) != 0); }

# -------------- CONSTANTS -------------- 

var mcdu_colors = [
    [1,1,1],
    [1,0,0],
    [1,1,0],
    [0,1,0],
    [0,1,1],
    [0,0.5,1],
    [1,0,1],
    [1,1,1],
];

var mcdu_white = 0;
var mcdu_red = 1;
var mcdu_yellow = 2;
var mcdu_green = 3;
var mcdu_cyan = 4;
var mcdu_blue = 5;
var mcdu_magenta = 6;

var mcdu_large = 0x10;

var cell_w = 18;
var cell_h = 27;
var cells_x = 24;
var cells_y = 13;
var num_cells = cells_x * cells_y;
var margin_left = 40;
var margin_top = 24;
var font_size_small = 20;
var font_size_large = 26;

var left_triangle = "◄";
var right_triangle = "►";
var left_right_arrow = "↔";
var up_down_arrow = "↕";
var black_square = "■";

var xpdrModeLabels = [
    "STBY",
    "ALT-OFF",
    "ALT-ON",
    "TA",
    "TA/RA",
];

var keyProps = {
    # Radios
    "NAV1A": "/instrumentation/nav[0]/frequencies/selected-mhz",
    "NAV1S": "/instrumentation/nav[0]/frequencies/standby-mhz",
    "NAV1ID": "/instrumentation/nav[0]/nav-id",
    "DME1H": "/instrumentation/dme[0]/hold",
    "NAV1AUTO": "/fms/radio/nav-auto[0]",
    "NAV2A": "/instrumentation/nav[1]/frequencies/selected-mhz",
    "NAV2S": "/instrumentation/nav[1]/frequencies/standby-mhz",
    "NAV2ID": "/instrumentation/nav[1]/nav-id",
    "DME2H": "/instrumentation/dme[1]/hold",
    "NAV2AUTO": "/fms/radio/nav-auto[1]",
    "COM1A": "/instrumentation/comm[0]/frequencies/selected-mhz",
    "COM1S": "/instrumentation/comm[0]/frequencies/standby-mhz",
    "COM2A": "/instrumentation/comm[1]/frequencies/selected-mhz",
    "COM2S": "/instrumentation/comm[1]/frequencies/standby-mhz",
    "ADF1A": "/instrumentation/adf[0]/frequencies/selected-khz",
    "ADF1S": "/instrumentation/adf[0]/frequencies/standby-khz",
    "ADF2A": "/instrumentation/adf[1]/frequencies/selected-khz",
    "ADF2S": "/instrumentation/adf[1]/frequencies/standby-khz",
    "XPDRA": "/instrumentation/transponder/id-code",
    "XPDRS": "/instrumentation/transponder/standby-id",
    "XPDRON": "/fms/radio/tcas-xpdr/enabled",
    "XPDRMD": "/fms/radio/tcas-xpdr/mode",
    "PALT": "/instrumentation/altimeter/pressure-alt-ft",
    "XPDRID": "/instrumentation/transponder/inputs/ident-btn",

    # Misc
    "ACTYPE": "/sim/aircraft",
    "ENGINE": "/sim/engine",
    "FGVER": "/sim/version/flightgear",

    # Date/Time
    "ZHOUR": "/sim/time/utc/hour",
    "ZMIN": "/sim/time/utc/minute",
    "ZSEC": "/sim/time/utc/second",
    "ZDAY": "/sim/time/utc/day",
    "ZMON": "/sim/time/utc/month",
    "ZYEAR": "/sim/time/utc/year",

    # Position
    "FLTID": "/sim/multiplay/callsign",
    "GPSLAT": "/instrumentation/gps/indicated-latitude-deg",
    "GPSLON": "/instrumentation/gps/indicated-longitude-deg",
    "RAWLAT": "/position/latitude-deg",
    "RAWLON": "/position/longitude-deg",
    "POSLOADED1": "/fms/position-loaded[0]",
    "POSLOADED2": "/fms/position-loaded[1]",
    "POSLOADED3": "/fms/position-loaded[2]",

    # Airspeeds
    "VREF": "/controls/flight/vref",
    "VAP": "/controls/flight/vappr",
    "VAC": "/controls/flight/vac",
    "V1": "/controls/flight/v1",
    "V2": "/controls/flight/v2",
    "VR": "/controls/flight/vr",
    "VFS": "/controls/flight/vfs",
    "VF": "/controls/flight/vf",
    "VF1": "/controls/flight/vf1",
    "VF2": "/controls/flight/vf2",
    "VF3": "/controls/flight/vf3",
    "VF4": "/controls/flight/vf4",
    "VF5": "/controls/flight/vf5",
    "VF6": "/controls/flight/vf6",
};

var modelFactory = func (key) {
    # for now, only PropModel can be loaded supported
    if (contains(keyProps, key)) {
        return PropModel.new(key);
    }
    else {
        return BaseModel.new();
    }
};

# -------------- MODELS -------------- 

var BaseModel = {
    new: func () {
        return {
            parents: [BaseModel]
        };
    },

    get: func () { return nil; },
    put: func (val) { },
    getKey: func () { return nil; },
    subscribe: func (f) { return nil; },
    unsubscribe: func (l) { },
};

var PropModel = {
    new: func (key) {
        var m = BaseModel.new();
        m.parents = prepended(PropModel, m.parents);
        m.key = key;
        m.prop = props.globals.getNode(keyProps[key]);
        return m;
    },

    getKey: func () {
        return me.key;
    },

    get: func () {
        if (me.prop != nil) {
            return me.prop.getValue();
        }
        else {
            return nil;
        }
    },

    set: func (val) {
        if (me.prop != nil) {
            me.prop.setValue(val);
        }
    },

    subscribe: func (f) {
        if (me.prop != nil) {
            return setlistener(me.prop, func () {
                var val = me.prop.getValue();
                f(val);
            });
        }
    },

    unsubscribe: func (l) {
        removelistener(l);
    },
};

# -------------- VIEWS -------------- 

var BaseView = {
    new: func (x, y, flags) {
        return {
            parents: [BaseView],
            x: x,
            y: y,
            w: 0,
            flags: flags
        };
    },

    getW: func () {
        return me.w;
    },

    getH: func () {
        return 1;
    },

    getL: func () {
        return me.x;
    },

    getT: func () {
        return me.y;
    },

    getKey: func () {
        return nil;
    },

    # Draw the widget to the given MCDU.
    draw: func (mcdu, val) {
    },

    # Fetch current value and draw the widget to the given MCDU.
    drawAuto: func (mcdu) {
    },

    activate: func (mcdu) {
    },

    deactivate: func () {
    },
};

var StaticView = {
    new: func (x, y, txt, flags) {
        var m = BaseView.new(x, y, flags);
        m.parents = prepended(StaticView, m.parents);
        m.w = size(txt);
        m.txt = txt;
        return m;
    },

    drawAuto: func (mcdu) {
        mcdu.print(me.x, me.y, me.txt, me.flags);
    },

    draw: func (mcdu, ignored) {
        me.drawAuto(mcdu);
    },
};

var ModelView = {
    new: func (x, y, flags, model) {
        var m = BaseView.new(x, y, flags);
        m.parents = prepended(ModelView, m.parents);
        if (typeof(model) == "scalar") {
            m.model = modelFactory(model);
        }
        else {
            m.model = model;
        }
        m.listeners = [];
        return m;
    },

    getKey: func () {
        if (me.model == nil) return nil;
        return me.model.getKey();
    },

    drawAuto: func (mcdu) {
        var val = me.model.get();
        me.draw(mcdu, val);
    },


    activate: func (mcdu) {
        var listener = me.model.subscribe(func (val) {
            me.draw(mcdu, val);
        });
        if (listener != nil) {
            append(me.listeners, listener);
        }
    },

    deactivate: func () {
        foreach (listener; me.listeners) {
            me.model.unsubscribe(listener);
        }
        me.listeners = [];
    },
};

var ToggleView = {
    new: func (x, y, flags, model, txt) {
        var m = ModelView.new(x, y, flags, model);
        m.parents = prepended(ToggleView, m.parents);
        m.w = size(txt);
        m.txt = txt;
        m.clear = "";
        while (size(m.clear) < size(txt)) {
            m.clear ~= " ";
        }
        return m;
    },

    draw: func (mcdu, val) {
        mcdu.print(me.x, me.y, val ? me.txt : me.clear, me.flags);
    },
};

var FormatView = {
    new: func (x, y, flags, model, w, fmt = nil, mapping = nil) {
        var m = ModelView.new(x, y, flags, model);
        m.parents = prepended(FormatView, m.parents);
        m.mapping = mapping;
        m.w = w;
        if (fmt == nil) { fmt = "%" ~ w ~ "s"; }
        m.fmt = fmt;
        return m;
    },

    draw: func (mcdu, val) {
        if (me.mapping != nil) {
            if (typeof(me.mapping) == "func") {
                val = me.mapping(val);
            }
            else {
                val = me.mapping[val];
            }
        }
        mcdu.print(me.x, me.y, sprintf(me.fmt, val), me.flags);
    },
};

var GeoView = {
    new: func (x, y, flags, model, latlon) {
        var m = ModelView.new(x, y, flags, model);
        m.parents = prepended(GeoView, m.parents);
        if (latlon == "LAT") {
            m.w = 8;
            m.fmt = "%1s%02d°%04.1f";
            m.dirs = ["S", "N"];
        }
        else {
            m.w = 9;
            m.fmt = "%1s%03d°%04.1f";
            m.dirs = ["W", "E"];
        }
        return m;
    },

    draw: func (mcdu, val) {
        var dir = (val < 0) ? (me.dirs[0]) : (me.dirs[1]);
        var degs = math.abs(val);
        var mins = math.fmod(degs * 60, 60);
        mcdu.print(me.x, me.y, sprintf(me.fmt, dir, degs, mins), me.flags);
    },
};

var StringView = {
    new: func (x, y, flags, model, w) {
        var m = ModelView.new(x, y, flags, model);
        m.parents = prepended(StringView, m.parents);
        m.w = w;
        return m;
    },

    draw: func (mcdu, val) {
        if (size(val) > me.w) {
            val = substr(val, 0, me.w);
        }
        if (size(val) < me.w) {
            if (me.x >= cells_x / 2) {
                # right-align
                val = sprintf("%" ~ me.w ~ "s", val);
            }
            else {
                # left-align
                val = sprintf("%-" ~ me.w ~ "s", val);
            }
        }
        mcdu.print(me.x, me.y, val, me.flags);
    },
};

var CycleView = {
    new: func (x, y, flags, model, values = nil, labels = nil, wide = nil) {
        if (values == nil) { values = [0, 1]; }
        if (labels == nil) { labels = ["OFF", "ON"]; }
        if (wide == nil) { wide = 0; }

        var m = ModelView.new(x, y, flags, model);
        m.parents = prepended(CycleView, m.parents);
        m.values = values;
        m.labels = labels;
        m.wide = wide;
        if (m.wide) {
            m.w = cells_x;
            m.x = 0;
        }
        else {
            m.w = -1;
            foreach (var val; values) {
                var label = (typeof(labels) == "func") ? labels(val) : labels[val];
                m.w += size(label) + 1;
            }
        }
        return m;
    },

    draw: func (mcdu, val) {
        if (me.wide) {
            if (size(me.values) == 2) {
                mcdu.print(cells_x / 2 - 1, me.y, "OR", mcdu_large | mcdu_white);
                if (val == me.values[0]) {
                    mcdu.print(1, me.y, sprintf("%-" ~ (cells_x / 2 - 2) ~ "s", me.labels[0]), me.flags);
                    mcdu.print(cells_x / 2 + 1, me.y, sprintf("%-" ~ (cells_x / 2 - 2) ~ "s", me.labels[1]) ~ right_triangle, mcdu_large | mcdu_white);
                }
                else {
                    mcdu.print(0, me.y, left_triangle ~ sprintf("%-" ~ (cells_x / 2 - 2) ~ "s", me.labels[0]), mcdu_large | mcdu_white);
                    mcdu.print(cells_x / 2 + 1, me.y, sprintf("%-" ~ (cells_x / 2 - 2) ~ "s", me.labels[1]), me.flags);
                }
            }
            else {
                mcdu.print(1, me.y, sprintf("%-" ~ (cells_x - 4) ~ "s", me.labels[val], me.flags));
                mcdu.print(cells_x - 3, me.y, "OR" ~ right_triangle, mcdu_large | mcdu_white);
            }
        }
        else {
            var x = me.x;
            foreach (var v; me.values) {
                var label = (typeof(me.labels) == "func") ? me.labels(v) : me.labels[v];
                if (label == nil) { continue; }
                mcdu.print(x, me.y, label, (v == val) ? me.flags : 0);
                x += size(label) + 1;
            }
        }
    },
};


var FreqView = {
    new: func (x, y, flags, model, ty = nil) {
        var m = ModelView.new(x, y, flags, model);
        m.parents = prepended(FreqView, m.parents);
        if (ty == nil) {
            var k = m.model.getKey();
            if (k != nil) {
                ty = substr(k, 0, 3);
            }
        }
        m.mode = ty;
        if (ty == "COM") {
            m.w = 7;
            m.fmt = "%7.3f";
        }
        else if (ty == "NAV") {
            m.w = 6;
            m.fmt = "%6.2f";
        }
        else if (ty == "ADF") {
            m.w = 5;
            m.fmt = "%5.1f";
        }
        else {
            m.w = 7;
            m.fmt = "%7.3f";
        }
        return m;
    },

    draw: func (mcdu, val) {
        mcdu.print(me.x, me.y, sprintf(me.fmt, val), me.flags);
    },

};


# -------------- CONTROLLERS -------------- 

var BaseController = {
    new: func () {
        return {
            parents: [BaseController]
        };
    },

    getKey: func () {
        return nil;
    },

    # Process a select event. The 'boxed' argument indicates that the
    # controller's key is currently boxed.
    select: func (owner, boxed) {
        return nil;
    },

    # Process a send event.
    # Scratchpad contents is sent as the value.
    # Return updated scratchpad contents to indicate acceptance, or nil to
    # keep scratchpad value unchanged and signal rejection.
    send: func (owner, val) {
        return nil;
    },

    # Process a dialling event.
    dial: func (owner, digit) {
        return nil;
    },
};

var ModelController = {
    new: func (model) {
        var m = BaseController.new();
        m.parents = prepended(ModelController, m.parents);
        if (typeof(model) == "scalar") {
            m.model = modelFactory(model);
        }
        else {
            m.model = model;
        }
        return m;
    },

    getKey: func () {
        if (me.model == nil) return nil;
        return me.model.getKey();
    },

    # Parse a raw string into a formatted value.
    # Return the parsed value, or nil if the parse failed.
    parse: func (val) {
        return val;
    },

    # Pass a "set value" request to the underlying model.
    set: func (val) {
        val = me.parse(val);
        if (val != nil and me.model != nil) {
            me.model.set(val);
        }
        return val;
    },

    send: func (owner, val) {
        if (me.set(val) == nil) {
            # TODO: issue error message on scratchpad
        }
    },
};

var SubmodeController = {
    new: func (submode) {
        var m = BaseController.new();
        m.parents = prepended(SubmodeController, m.parents);
        m.submode = submode;
        return m;
    },

    select: func (owner, boxed) {
        if (me.submode == nil or me.submode == 'ret') {
            owner.ret();
        }
        else {
            owner.goto(me.submode);
        }
    },
};

var TriggerController = {
    new: func (model) {
        var m = ModelController.new(model);
        m.parents = prepended(TriggerController, m.parents);
        return m;
    },

    select: func (owner, ignore) {
        if (me.model != nil) {
            me.model.set(1);
        }
    },

    send: func (owner, scratch) {
        if (scratch != '') {
            # TODO: warning
        }
        me.select(owner, nil);
    },
};

var CycleController = {
    new: func (model, values = nil) {
        var m = ModelController.new(model);
        m.parents = prepended(CycleController, m.parents);
        if (values == nil) {
            values = [0, 1];
        }
        m.values = values;
        return m;
    },

    cycle: func () {
        var val = me.model.get();
        # find the value in our values vector
        var index = 0;
        while (index < size(me.values) and me.values[index] != val) {
            index += 1;
        }
        index += 1;

        if (index >= size(me.values)) {
            # wrap around
            index = 0;
        }

        val = me.values[index];
        me.model.set(val);
    },

    select: func (owner, ignore) {
        me.cycle();
    },

    send: func (owner, scratch) {
        if (scratch != '') {
            # TODO: warning
        }
        me.cycle();
    },
};

var TransponderController = {
    new: func (model, goto = nil) {
        var m = ModelController.new(model);
        m.parents = prepended(TransponderController, m.parents);
        m.goto = goto;
        return m;
    },

    parse: func (val) {
        val = parseOctal(val);
        if (val == nil or val < 0 or val > 0o7777) { return nil; }
        val = sprintf("%04o", val);
        return val;
    },

    select: func (owner, boxed) {
        if (boxed) {
            if (me.goto == nil) {
                return nil;
            }
            else if (me.goto == "ret") {
                owner.ret();
            }
            else {
                owner.goto(me.goto);
            }
        }
        else {
            owner.box(me.model.getKey());
        }
    },

    dial: func (owner, digit) {
        var val = me.model.get();
        val = ('0o' ~ val) + 0;

        if (digit == 1) {
            val = (val & 0o7770) | ((val + 1) & 0o7)
        }
        else if (digit == 2) {
            val = (val & 0o7707) | ((val + 0o10) & 0o70)
        }
        else if (digit == 3) {
            val = (val & 0o7077) | ((val + 0o100) & 0o700)
        }
        else if (digit == 4) {
            val = (val & 0o0777) | ((val + 0o1000) & 0o7000)
        }
        else if (digit == -1) {
            val = (val & 0o7770) | ((val - 1) & 0o7)
        }
        else if (digit == -2) {
            val = (val & 0o7707) | ((val - 0o10) & 0o70)
        }
        else if (digit == -3) {
            val = (val & 0o7077) | ((val - 0o100) & 0o700)
        }
        else if (digit == -4) {
            val = (val & 0o0777) | ((val - 0o1000) & 0o7000)
        }

        me.model.set(sprintf("%04o", val));
    },
};

var PropSwapController = {
    new: func (key1, key2) {
        var m = BaseController.new();
        m.parents = prepended(PropSwapController, m.parents);
        m.key1 = key1;
        m.key2 = key2;
        m.prop1 = keyProps[key1];
        m.prop2 = keyProps[key2];
        return m;
    },

    getKey: func () {
        return me.key1;
    },

    select: func (owner, boxed) {
        swapProps(me.prop1, me.prop2);
    },
};

var ValueController = {
    new: func (key, options = nil) {
        var m = ModelController.new(key);
        m.parents = prepended(ValueController, m.parents);

        if (options == nil) {
            options = {};
        }
        var scale = contains(options, "scale") ? options["scale"] : 1;
        m.amounts = [ scale, scale * 10, scale * 100, scale * 1000 ];
        m.min = contains(options, "min") ? options["min"] : 0;
        m.max = contains(options, "max") ? options["max"] : 500;
        m.goto = contains(options, "goto") ? options["goto"] : nil;
        m.boxable = contains(options, "boxable") ? options["boxable"] : 0;
        return m;
    },

    parse: func (val) {
        if (val >= me.min and val <= me.max) { return val; }
        return nil;
    },

    select: func (owner, boxed) {
        if (boxed) {
            if (me.goto == nil) {
                return nil;
            }
            else if (me.goto == "ret") {
                owner.ret();
            }
            else {
                owner.goto(me.goto);
            }
        }
        else {
            if (me.boxable) {
                owner.box(me.model.getKey());
            }
        }
    },

    dial: func (owner, digit) {
        if (digit == 0) {
            return;
        }
        var adigit = math.abs(digit) - 1;
        var amount = me.amounts[adigit];
        var val = me.model.get();
        if (digit > 0) {
            val = math.min(me.max, val + amount);
        }
        else {
            val = math.max(me.min, val - amount);
        }
        me.model.set(val);
    },
};

var FreqController = {
    new: func (key, goto = nil, ty = nil) {
        var m = ModelController.new(key);
        m.parents = prepended(FreqController, m.parents);
        m.goto = goto;
        if (ty == nil) {
            ty = substr(key, 0, 3);
        }
        m.mode = ty;
        if (ty == "COM") {
            m.amounts = [0.01, 0.1, 1.0, 10.0];
            m.min = 118.0;
            m.max = 137.0;
        }
        else if (ty == "NAV") {
            m.amounts = [0.01, 0.1, 1.0, 10.0];
            m.min = 108.0;
            m.max = 118.0;
        }
        else if (ty == "ADF") {
            m.amounts = [1, 1, 10, 100];
            m.min = 190.0;
            m.max = 999.0;
        }
        else {
            m.amounts = [0.01, 0.1, 1.0, 10.0];
            m.min = 0.0;
            m.max = 999.99;
        }
        return m;
    },

    parse: func (val) {
        if (val >= me.min and val <= me.max) { return val; }
        if (val + 100 >= me.min and val + 100 <= me.max and me.mode != "ADF") { return val + 100; }
        if (val / 10.0 >= me.min and val / 10.0 <= me.max) { return val / 10.0; }
        if (val / 100.0 >= me.min and val / 100.0 <= me.max) { return val / 100.0; }
        if (val / 10.0 + 100 >= me.min and val / 10.0 + 100 <= me.max and me.mode != "ADF") { return val / 10.0 + 100.0; }
        if (val / 100.0 + 100 >= me.min and val / 100.0 + 100 <= me.max and me.mode != "ADF") { return val / 100.0 + 100.0; }
        return nil;
    },

    select: func (owner, boxed) {
        if (boxed) {
            if (me.goto == nil) {
                return nil;
            }
            else if (me.goto == "ret") {
                owner.ret();
            }
            else {
                owner.goto(me.goto);
            }
        }
        else {
            owner.box(me.model.getKey());
        }
    },

    dial: func (owner, digit) {
        if (digit == 0) {
            return;
        }
        var adigit = math.abs(digit) - 1;
        var amount = me.amounts[adigit];
        var val = me.model.get();
        if (digit > 0) {
            val = math.min(me.max, val + amount);
        }
        else {
            val = math.max(me.min, val - amount);
        }
        me.model.set(val);
    },
};

# -------------- MODULES -------------- 

var BaseModule = {
    new: func (mcdu, parentModule) {
        var m = { parents: [BaseModule] };
        m.page = 0;
        m.parentModule = parentModule;
        var maxw = math.round(cells_x / 2) - 1;
        m.ptitle = nil;
        if (parentModule != nil) {
            m.ptitle = sprintf("%s %d/%d",
                parentModule.getTitle(),
                parentModule.page + 1,
                parentModule.getNumPages());
        }
        if (m.ptitle != nil and size(m.ptitle) > maxw) {
            m.ptitle = parentModule.getTitle();
        }
        if (m.ptitle != nil and size(m.ptitle) > maxw) {
            m.ptitle = substr(m.ptitle, 0, maxw);
        }
        m.mcdu = mcdu;

        m.views = [];
        m.controllers = {};
        m.dividers = [];
        m.boxedController = nil;
        m.boxedView = nil;

        return m;
    },

    getNumPages: func () {
        return 1;
    },

    getTitle: func() {
        return "MODULE";
    },

    loadPage: func (n) {
        me.loadPageItems(n);
        foreach (var view; me.views) {
            view.activate(me.mcdu);
        }
    },

    unloadPage: func () {
        me.boxedView = nil;
        me.boxedController = nil;
        foreach (var view; me.views) {
            view.deactivate();
        }
        me.views = [];
        me.controllers = {};
    },

    loadPageItems: func (n) {
        # Override to load the views and controllers and dividers for the current page
    },

    findView: func (key) {
        if (key == nil) {
            return nil;
        }
        foreach (var view; me.views) {
            if (view.getKey() == key) {
                return view;
            }
        }
        return nil;
    },

    findController: func (key) {
        if (key == nil) {
            return nil;
        }
        foreach (var i; keys(me.controllers)) {
            var controller = me.controllers[i];
            if (controller != nil and controller.getKey() == key) {
                return controller;
            }
        }
        return nil;
    },

    drawFocusBox: func () {
        if (me.boxedView == nil) {
            me.mcdu.clearFocusBox();
        }
        else {
            me.mcdu.setFocusBox(
                me.boxedView.getL(),
                me.boxedView.getT(),
                me.boxedView.getW());
        }
    },

    drawPager: func () {
        me.mcdu.print(21, 0, sprintf("%1d/%1d", me.page + 1, me.getNumPages()), 0);
    },

    drawTitle: func () {
        var title = me.getTitle();
        var x = math.floor((cells_x - 3 - size(title)) / 2);
        me.mcdu.print(x, 0, title, mcdu_large | mcdu_white);
    },

    redraw: func () {
        foreach (var view; me.views) {
            view.drawAuto(me.mcdu);
        }
        var dividers = me.dividers;
        if (dividers == nil) { dividers = [] };
        for (var d = 0; d < 7; d += 1) {
            if (vecfind(d, dividers) == -1) {
                me.mcdu.hideDivider(d);
            }
            else {
                me.mcdu.showDivider(d);
            }
        }
        me.drawFocusBox();
    },


    fullRedraw: func () {
        me.mcdu.clear();
        me.drawTitle();
        me.drawPager();
        me.redraw();
    },

    nextPage: func () {
        if (me.page < me.getNumPages() - 1) {
            me.unloadPage();
            me.page += 1;
            me.loadPage(me.page);
            me.fullRedraw();
        }
    },

    prevPage: func () {
        if (me.page > 0) {
            me.unloadPage();
            me.page -= 1;
            me.loadPage(me.page);
            me.selectedKey = nil;
            me.fullRedraw();
        }
    },

    goto: func (target) {
        me.mcdu.pushModule(target);
    },

    ret: func () {
        me.mcdu.popModule();
    },

    activate: func () {
        me.loadPage(me.page);
    },

    deactivate: func () {
        me.unloadPage();
    },

    box: func (key) {
        me.boxedController = me.findController(key);
        me.boxedView = me.findView(key);
        me.drawFocusBox();
    },

    handleCommand: func (cmd) {
        var controller = me.controllers[cmd];
        if (isLSK(cmd)) {
            var scratch = me.mcdu.popScratchpad();
            if (controller != nil) {
                var boxed = (me.boxedController != nil and
                             me.boxedController.getKey() == controller.getKey());
                if (scratch == '') {
                    controller.select(me, boxed);
                }
                else {
                    controller.send(me, scratch);
                }
            }
        }
        else if (isDial(cmd)) {
            var digit = dialIndex(cmd);
            if (me.boxedController != nil) {
                me.boxedController.dial(me, digit);
            }
        }
    },

};

var LandingPerfModule = {
    new: func (mcdu, parentModule) {
        var m = BaseModule.new(mcdu, parentModule);
        m.parents = prepended(LandingPerfModule, m.parents);
        return m;
    },

    getNumPages: func () { return 2; },
    getTitle: func () { return "LANDING"; },

    loadPageItems: func (n) {
        if (n == 0) {
            me.views = [
                StaticView.new(1, 1, "RWY OAT", mcdu_white),
                # TemperatureView.new(0, 2, "OAT-TO", mcdu_white),
                StaticView.new(0, 2, "+??°C/+??°F", mcdu_white),
                StaticView.new(cells_x - 8, 1, "LND WGT", mcdu_white),
                FormatView.new(15, 2, mcdu_white, "WGT-LND", 8, "%6.0fLB"),
                StaticView.new(1, 3, "APPROACH FLAP", mcdu_white),
                StaticView.new(1, 5, "LANDING FLAP", mcdu_white),
                StaticView.new(1, 7, "ICE", mcdu_white),
                StaticView.new(1, 9, "APPROACH TYPE", mcdu_white),
                StaticView.new(0, 12, left_triangle ~ "PERF DATA", mcdu_white | mcdu_large),
                StaticView.new(14, 12, "T.O. DATA" ~ right_triangle, mcdu_white | mcdu_large),
            ];
        }
        else if (n == 1) {
            me.views = [
                StaticView.new(1, 1, "VREF", mcdu_white),
                FormatView.new(0, 2, mcdu_large | mcdu_white, "VREF", 3),
                StaticView.new(1, 3, "VAP", mcdu_white),
                FormatView.new(0, 4, mcdu_large | mcdu_white, "VAP", 3),
                StaticView.new(1, 5, "VAC", mcdu_white),
                FormatView.new(0, 6, mcdu_large | mcdu_white, "VAC", 3),
                StaticView.new(1, 7, "VFS", mcdu_white),
                FormatView.new(0, 8, mcdu_large | mcdu_white, "VFS", 3),
            ];
            me.controllers = {
                "L1": ValueController.new("VREF"),
                "L2": ValueController.new("VAP"),
                "L3": ValueController.new("VAC"),
                "L4": ValueController.new("VFS"),
            };
        }
    },
};

var IndexModule = {
    new: func (mcdu, parentModule, title, items) {
        var m = BaseModule.new(mcdu, parentModule);
        m.parents = prepended(IndexModule, m.parents);
        m.items = items;
        m.title = title;
        return m;
    },

    getNumPages: func () {
        return math.ceil(size(me.items) / 12);
    },

    getTitle: func () { return me.title; },

    loadPageItems: func (n) {
        var items = subvec(me.items, n * 12, 12);
        var i = 0;
        me.views = [];
        me.controllers = {};
        # left side
        for (i = 0; i < 6; i += 1) {
            var item = items[i];
            var lsk = "L" ~ (i + 1);
            if (item != nil) {
                append(me.views,
                    StaticView.new(0, 2 + i * 2, left_triangle ~ item[1], mcdu_large | mcdu_white));
                if (item[0] != nil) {
                    me.controllers[lsk] =
                        SubmodeController.new(item[0]);
                }
            }
        }
        # right side
        for (i = 0; i < 6; i += 1) {
            var item = items[i + 6];
            var lsk = "R" ~ (i + 1);
            if (item != nil) {
                append(me.views,
                    StaticView.new(23 - size(item[1]), 2 + i * 2, item[1] ~ right_triangle, mcdu_large | mcdu_white));
                if (item[0] != nil) {
                    me.controllers[lsk] =
                        SubmodeController.new(item[0]);
                }
            }
        }
    },
};

var TransponderModule = {
    new: func (mcdu, parentModule) {
        var m = BaseModule.new(mcdu, parentModule);
        m.parents = prepended(TransponderModule, m.parents);
        return m;
    },

    getNumPages: func () { return 2; },
    getTitle: func () { return "TCAS/XPDR"; },

    loadPageItems: func (n) {
        if (n == 0) {
            me.views = [
                FormatView.new(1, 2, mcdu_large |  mcdu_green, "XPDRA", 4),
                FormatView.new(1, 4, mcdu_large | mcdu_yellow, "XPDRS", 4),
                FormatView.new(18, 2, mcdu_large | mcdu_green, "PALT", 5, "%5.0f"),
                StringView.new(17, 4, mcdu_large | mcdu_green, "FLTID", 6),
                StaticView.new(  1,  1, "ACTIVE",                 mcdu_white ),
                StaticView.new(  0,  2, up_down_arrow,            mcdu_large | mcdu_white ),
                StaticView.new(  1,  3, "PRESET",                 mcdu_white ),
                StaticView.new(  0,  4, left_triangle,            mcdu_large | mcdu_white ),
                StaticView.new( 11,  1, "PRESSURE ALT",           mcdu_white ),
                StaticView.new( 17,  3, "FLT ID",                 mcdu_white ),
                StaticView.new( 23,  4, right_triangle,           mcdu_large | mcdu_white ),
                StaticView.new( 19,  5, "FREQ",                   mcdu_white ),
                StaticView.new(  1,  9, "XPDR SEL",               mcdu_large | mcdu_white ),
                StaticView.new(  1, 10, "XPDR 1",                 mcdu_large | mcdu_green ),
                StaticView.new(  8, 10, "XPDR 2",                 mcdu_white ),
                StaticView.new( 18, 10, "IDENT",                  mcdu_large | mcdu_white ),
                StaticView.new( 23, 10, black_square,             mcdu_large | mcdu_white ),
                StaticView.new( 22 - size(me.ptitle), 12, me.ptitle, mcdu_large | mcdu_white ),
                StaticView.new( 23, 12, right_triangle,           mcdu_large | mcdu_white ),
            ];
            me.controllers = {
                "L1": PropSwapController.new("XPDRA", "XPDRS"),
                "L2": TransponderController.new("XPDRS"),
                "R2": ModelController.new("FLTID"),
                "R5": TriggerController.new("XPDRID"),
                "R6": SubmodeController.new("ret"),
            };
        }
        else if (n == 1) {
            me.views = [
                CycleView.new(1, 2, mcdu_large | mcdu_green, "XPDRMD", [4,3,2,1], xpdrModeLabels),
                StaticView.new(  1,  1, "TCAS/XPDR MODE",         mcdu_white ),
                StaticView.new(  0,  2, black_square,             mcdu_large | mcdu_white ),
                StaticView.new(  1,  4, "ALT RANGE",              mcdu_white ),
                StaticView.new( 14, 12, "RADIO 1/2",              mcdu_large | mcdu_white ),
                StaticView.new( 23, 12, right_triangle,           mcdu_large | mcdu_white ),
            ];
            me.controllers = {
                "L1": CycleController.new("XPDRMD", [4,3,2,1]),
                "R6": SubmodeController.new("ret"),
            };
        }
    },
};

var RadioModule = {
    new: func (mcdu, parentModule) {
        var m = BaseModule.new(mcdu, parentModule);
        m.parents = prepended(RadioModule, m.parents);
        return m;
    },

    getNumPages: func () { return 2; },
    getTitle: func () { return "RADIOS"; },

    loadPageItems: func (n) {
        if (n == 0) {
            me.views = [
                FreqView.new(1, 2, mcdu_large | mcdu_green, "COM1A"),
                FreqView.new(1, 4, mcdu_large | mcdu_yellow, "COM1S"),
                FreqView.new(16, 2, mcdu_large | mcdu_green, "COM2A"),
                FreqView.new(16, 4, mcdu_large | mcdu_yellow, "COM2S"),

                FreqView.new(1, 6, mcdu_large | mcdu_green, "NAV1A"),
                FreqView.new(1, 8, mcdu_large | mcdu_yellow, "NAV1S"),
                FreqView.new(17, 6, mcdu_large | mcdu_green, "NAV2A"),
                FreqView.new(17, 8, mcdu_large | mcdu_yellow, "NAV2S"),

                FormatView.new(19, 10, mcdu_large | mcdu_green, "XPDRA", 4),

                ToggleView.new(8, 5, mcdu_large | mcdu_blue, "NAV1AUTO", "FMS"),
                ToggleView.new(8, 6, mcdu_large | mcdu_blue, "NAV1AUTO", "AUTO"),
                ToggleView.new(12, 5, mcdu_large | mcdu_blue, "NAV2AUTO", "FMS"),
                ToggleView.new(12, 6, mcdu_large | mcdu_blue, "NAV2AUTO", "AUTO"),

                CycleView.new(1, 12, mcdu_large | mcdu_green, "XPDRON",
                    [0, 1],
                    func (n) { return (n ? xpdrModeLabels[getprop(keyProps["XPDRMD"])] : "STBY"); }),

                StaticView.new(  1,  1, "COM1",                   mcdu_white ),
                StaticView.new(  0,  2, up_down_arrow,            mcdu_large | mcdu_white ),
                StaticView.new(  0,  4, left_triangle,            mcdu_large | mcdu_white ),

                StaticView.new( 19,  1, "COM2",                   mcdu_white ),
                StaticView.new( 23,  2, up_down_arrow,            mcdu_large | mcdu_white ),
                StaticView.new( 23,  4, right_triangle,           mcdu_large | mcdu_white ),

                StaticView.new(  1,  5, "NAV1",                   mcdu_white ),
                StaticView.new(  0,  6, up_down_arrow,            mcdu_large | mcdu_white ),
                StaticView.new(  0,  8, left_triangle,            mcdu_large | mcdu_white ),

                StaticView.new( 19,  5, "NAV2",                   mcdu_white ),
                StaticView.new( 23,  6, up_down_arrow,            mcdu_large | mcdu_white ),
                StaticView.new( 23,  8, right_triangle,           mcdu_large | mcdu_white ),

                StaticView.new( 19,  9, "XPDR",                   mcdu_white ),
                StaticView.new( 23, 10, right_triangle,           mcdu_large | mcdu_white ),
                StaticView.new( 18, 11, "IDENT",                  mcdu_white ),
                StaticView.new( 18, 12, "IDENT",                  mcdu_large | mcdu_white ),
                StaticView.new( 23, 12, black_square,             mcdu_large | mcdu_white ),

                StaticView.new(  0, 10, left_triangle ~ "TCAS/XPDR",              mcdu_large | mcdu_white ),
                StaticView.new(  0, 12, left_right_arrow,         mcdu_large | mcdu_white ),
            ];
            me.dividers = [0, 1, 3, 4];
            me.controllers = {
                "L1": PropSwapController.new("COM1A", "COM1S"),
                "L2": FreqController.new("COM1S", "COM1"),
                "L3": PropSwapController.new("NAV1A", "NAV1S"),
                "L4": FreqController.new("NAV1S", "NAV1"),
                "L5": SubmodeController.new("XPDR"),
                "L6": CycleController.new("XPDRON"),
                "R1": PropSwapController.new("COM2A", "COM2S"),
                "R2": FreqController.new("COM2S", "COM2"),
                "R3": PropSwapController.new("NAV2A", "NAV2S"),
                "R4": FreqController.new("NAV2S", "NAV2"),
                "R5": TransponderController.new("XPDRA", "XPDR"),
                "R6": TriggerController.new("XPDRID"),
            };
        }
        else if (n == 1) {
            me.views = [
                FreqView.new(1, 2, mcdu_large | mcdu_green, "ADF1A"),
                FreqView.new(1, 4, mcdu_large | mcdu_yellow, "ADF1S"),
                FreqView.new(18, 2, mcdu_large | mcdu_green, "ADF2A"),
                FreqView.new(18, 4, mcdu_large | mcdu_yellow, "ADF2S"),
                StaticView.new( 1, 1, "ADF1", mcdu_white ),
                StaticView.new( 0, 4, left_triangle, mcdu_large | mcdu_white ),
                StaticView.new(19, 1, "ADF2", mcdu_white ),
                StaticView.new(23, 4, right_triangle, mcdu_white ),
            ];
            me.dividers = [0, 1, 2, 3, 4];
            me.controllers = {
                "L1": PropSwapController.new("ADF1A", "ADF1S"),
                "R1": PropSwapController.new("ADF2A", "ADF2S"),
                "L2": FreqController.new("ADF1S"),
                "R2": FreqController.new("ADF2S"),
            };
        }
    },
};

var NavIdentModule = {
    new: func (mcdu, parentModule) {
        var m = BaseModule.new(mcdu, parentModule);
        m.parents = prepended(NavIdentModule, m.parents);
        return m;
    },

    getTitle: func () { return "NAV IDENT"; },
    getNumPages: func () { return 1; },

    loadPageItems: func (n) {
        if (n == 0) { 
            me.views = [
                StaticView.new( 2,  1, "DATE", mcdu_white),
                FormatView.new( 1, 2, mcdu_large | mcdu_white, "ZDAY", 2, "%02d"),
                FormatView.new( 3, 2, mcdu_large | mcdu_white, "ZMON", 3, "%3s",
                    [ "XXX", "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" ]),
                FormatView.new( 6, 2, mcdu_large | mcdu_white, "ZYEAR", 2, "%02d",
                    func (y) { return math.mod(y, 100); }),
                StaticView.new( 2,  3, "UTC", mcdu_white),
                FormatView.new( 1, 4, mcdu_large | mcdu_white, "ZHOUR", 2, "%02d"),
                FormatView.new( 3, 4, mcdu_large | mcdu_white, "ZMIN", 2, "%02d"),
                StaticView.new( 6,  4, "Z", mcdu_white),
                StaticView.new( 2,  5, "SW", mcdu_white),
                FormatView.new( 1,  6, mcdu_large | mcdu_white, "FGVER", 10, "%-10s"),
                StaticView.new(11,  5, "NDS V3.01 16M", mcdu_white),
                StaticView.new(12,  6, "WORLD3-301", mcdu_large | mcdu_white),
                StaticView.new( 0, 12, left_triangle ~ "MAINTENANCE", mcdu_large | mcdu_white),
                StaticView.new(12, 12, "   POS INIT" ~ right_triangle, mcdu_large | mcdu_white),
            ];
            me.controllers = {
                "R6": SubmodeController.new("POSINIT"),
            };
        }
    },
};

var PosInitModule = {
    new: func (mcdu, parentModule) {
        var m = BaseModule.new(mcdu, parentModule);
        m.parents = prepended(PosInitModule, m.parents);
        return m;
    },

    getTitle: func () { return "POSITION INIT"; },
    getNumPages: func () { return 1; },

    loadPageItems: func (n) {
        if (n == 0) {
            me.views = [
                StaticView.new(1,  1, "LAST POS",              mcdu_white),
                GeoView.new(0,  2, mcdu_large | mcdu_green, "RAWLAT",  "LAT"),
                GeoView.new(9,  2, mcdu_large | mcdu_green, "RAWLON",  "LON"),
                ToggleView.new(17, 1, mcdu_white, "POSLOADED1", "LOADED"),
                StaticView.new(       19,  2, "LOAD" ~ right_triangle, mcdu_large | mcdu_white),

                StaticView.new(        1,  5, "GPS1 POS",              mcdu_white),
                GeoView.new(0,  6, mcdu_large | mcdu_green, "GPSLAT",  "LAT"),
                GeoView.new(9,  6, mcdu_large | mcdu_green, "GPSLON",  "LON"),
                ToggleView.new(17, 5, mcdu_white, "POSLOADED3", "LOADED"),
                StaticView.new(       19,  6, "LOAD" ~ right_triangle, mcdu_large | mcdu_white),
                StaticView.new(        0, 12, left_triangle ~ "POS SENSORS", mcdu_large | mcdu_white),
            ];
            me.controllers = {
                "R1": TriggerController.new("POSLOADED1"),
                "R3": TriggerController.new("POSLOADED3"),
            };
            if (me.ptitle != nil) {
                me.controllers["R6"] = SubmodeController.new("ret");
                append(me.views,
                     StaticView.new(22 - size(me.ptitle), 12, me.ptitle ~ right_triangle, mcdu_large));
            }
        }
    },
};

var NavRadioDetailsModule = {
    new: func (mcdu, parentModule, navNum) {
        var m = BaseModule.new(mcdu, parentModule);
        m.parents = prepended(NavComRadioDetailsModule, m.parents);
        m.navNum = navNum;
        return m;
    },

    getNumPages: func () { return 1; },
    getTitle: func () { return "NAV" ~ navNum; },

    loadPageItems: func (n) {
        if (n == 0) {
            me.views = [
                FreqView.new(1, 2, mcdu_large |  mcdu_green, "NAV" ~ me.navNum ~ "A"),
                FreqView.new(1, 4, mcdu_large |  mcdu_yellow, "NAV" ~ me.navNum ~ "S"),
                CycleView.new(17, 4, mcdu_large | mcdu_green, "DME" ~ me.navNum ~ "H"),
                CycleView.new(17, 10, mcdu_large | mcdu_green, "NAV" ~ me.navNum ~ "AUTO"),
                StaticView.new(  1,  1, "ACTIVE",                 mcdu_white ),
                StaticView.new(  0,  2, up_down_arrow, mcdu_large | mcdu_white ),
                StaticView.new(  1,  3, "PRESET",                 mcdu_white ),
                StaticView.new(  0,  4, left_triangle, mcdu_large | mcdu_white ),
                StaticView.new( 15,  3, "DME HOLD",               mcdu_white ),
                StaticView.new( 15,  9, "FMS AUTO",               mcdu_white ),
                StaticView.new(  0, 12, left_triangle, mcdu_large | mcdu_white ),
                StaticView.new(  1, 12, "MEMORY", mcdu_large | mcdu_white ),
                StaticView.new( 14, 12, me.ptitle, mcdu_large | mcdu_white ),
                StaticView.new( 23, 12, right_triangle, mcdu_large | mcdu_white ),
            ];
            me.controllers = {
                "L1": PropSwapController.new("NAV" ~ me.navNum ~ "S", "NAV" ~ me.navNum ~ "A"),
                "L2": FreqController.new("NAV" ~ me.navNum ~ "S"),
                "R2": CycleController.new("DME" ~ me.navNum ~ "H"),
                "R5": CycleController.new("NAV" ~ me.navNum ~ "AUTO"),
                "R6": SubmodeController.new("ret"),
            };
        }
    },
};

var ComRadioDetailsModule = {
    new: func (mcdu, parentModule, navNum) {
        var m = BaseModule.new(mcdu, parentModule);
        m.parents = prepended(ComComRadioDetailsModule, m.parents);
        m.navNum = navNum;
        return m;
    },

    getNumPages: func () { return 1; },
    getTitle: func () { return "COM" ~ navNum; },

    loadPageItems: func (n) {
        if (n == 0) {
            me.views = [
                FreqView.new(1, 2, mcdu_large |  mcdu_green, "COM" ~ me.navNum ~ "A"),
                FreqView.new(1, 4, mcdu_large |  mcdu_yellow, "COM" ~ me.navNum ~ "S"),
                StaticView.new(  1,  1, "ACTIVE",                 mcdu_white ),
                StaticView.new(  0,  2, up_down_arrow, mcdu_large | mcdu_white ),
                StaticView.new(  1,  3, "PRESET",                 mcdu_white ),
                StaticView.new(  0,  4, left_triangle, mcdu_large | mcdu_white ),
                StaticView.new(  1,  5, "MEM TUNE",               mcdu_white ),
                StaticView.new( 16,  1, "SQUELCH",                mcdu_white ),
                StaticView.new( 19,  3, "MODE",                   mcdu_white ),
                StaticView.new( 19,  5, "FREQ",                   mcdu_white ),
                StaticView.new(  0, 12, left_triangle, mcdu_large | mcdu_white ),
                StaticView.new(  1, 12, "MEMORY", mcdu_large | mcdu_white ),
                StaticView.new( 14, 12, me.ptitle, mcdu_large | mcdu_white ),
                StaticView.new( 23, 12, right_triangle, mcdu_large | mcdu_white ),
            ];
            me.controllers = {
                "L1": PropSwapController.new("COM" ~ me.navNum ~ "S", "COM" ~ me.navNum ~ "A"),
                "L2": FreqController.new("COM" ~ me.navNum ~ "S"),
                "R6": SubmodeController.new("ret"),
            };
        }
    },
};

# -------------- MCDU -------------- 

var MCDU = {
    new: func (n) {
        var m = {
            parents: [MCDU],
            num: n,
            commandprop: props.globals.getNode("/instrumentation/mcdu[" ~ n ~ "]/command"),
            display: nil,
            scratchpad: "",
            scratchpadElem: nil,
            dividers: [],
            screenbuf: [],
            screenbufElems: [],
            activeModule: nil,
            moduleStack: [],
            powered: 0,
            g: nil
        };
        m.initCanvas();
        setlistener("/instrumentation/mcdu[" ~ n ~ "]/command", func () {
            m.handleCommand();
        });
        return m;
    },

    powerOn: func () {
        if (!me.powered) {
            me.powered = 1;
            me.gotoModule("RADIO");
        }
    },

    powerOff: func () {
        if (me.powered) {
            me.powered = 0;
            me.gotoModule(nil);
        }
    },

    makeModule: {
        # Radio modules
        "RADIO": func(mcdu, parent) { return RadioModule.new(mcdu, parent); },
        "NAV1": func (mcdu, parent) { return NavRadioDetailsModule.new(mcdu, parent, 1); },
        "NAV2": func (mcdu, parent) { return NavRadioDetailsModule.new(mcdu, parent, 2); },
        "COM1": func (mcdu, parent) { return ComRadioDetailsModule.new(mcdu, parent, 1); },
        "COM2": func (mcdu, parent) { return ComRadioDetailsModule.new(mcdu, parent, 2); },
        "XPDR": func (mcdu, parent) { return TransponderModule.new(mcdu, parent); },

        # Index modules
        "NAVINDEX": func(mcdu, parent) { return IndexModule.new(mcdu, parent,
                        "NAV INDEX",
                        [ # PAGE 1
                          [ "NAVIDENT", "NAV IDENT" ]
                        , [ nil, "WPT LIST" ]
                        , [ nil, "FPL LIST" ]
                        , [ nil, "POS SENSORS" ]
                        , [ nil, "FIX INFO" ]
                        , [ nil, "DEPARTURE" ]

                        , nil
                        , nil
                        , [ nil, "FLT SUM" ]
                        , nil
                        , [ nil, "HOLD" ]
                        , [ nil, "ARRIVAL" ]

                          # PAGE 2
                        , [ "POSINIT", "POS INIT" ]
                        , [ nil, "DATA LOAD" ]
                        , [ nil, "PATTERNS" ]
                        , nil
                        , nil
                        , nil

                        , [ nil, "CONVERSION" ]
                        , [ nil, "MAINTENANCE" ]
                        , [ nil, "CROSS PTS" ]
                        , nil
                        , nil
                        , nil
                        ]); },
        "PERFINDEX": func(mcdu, parent) { return IndexModule.new(mcdu, parent,
                        "PERF INDEX",
                        [ # PAGE 1
                          [ nil, "PERF INIT" ],
                          [ nil, "PERF PLAN" ],
                          [ nil, "CLIMB" ],
                          [ nil, "DESCENT" ],
                          [ nil, "INIT<--WHAT" ],
                          [ nil, "INIT<-STORE" ],

                          [ nil, "PERF DATA" ],
                          [ nil, "TAKEOFF" ],
                          [ nil, "CRUISE" ],
                          [ "PERF-LANDING", "LANDING" ],
                          [ nil, "-IF -->DATA" ],
                          [ nil, "D FPL->DATA" ],

                          # PAGE 2
                        ]); },

        # Perf
        "PERF-LANDING": func (mcdu, parent) { return LandingPerfModule.new(mcdu, parent); },

        # Nav
        "NAVIDENT": func (mcdu, parent) { return NavIdentModule.new(mcdu, parent); },
        "POSINIT": func (mcdu, parent) { return PosInitModule.new(mcdu, parent); },
    },

    pushModule: func (moduleName) {
        if (me.activeModule != nil) {
            append(me.moduleStack, me.activeModule);
        }
        me.activateModule(moduleName);
    },

    gotoModule: func (moduleName) {
        me.moduleStack = [];
        me.activateModule(moduleName);
    },

    popModule: func () {
        var target = pop(me.moduleStack);
        me.activateModule(target);
    },

    activateModule: func (module) {
        if (me.activeModule != nil) {
            me.activeModule.deactivate();
        }
        var parent = me.activeModule;
        if (typeof(module) == "scalar") {
            var factory = me.makeModule[module];
            if (factory == nil) {
                me.activeModule = nil;
            }
            else {
                me.activeModule = factory(me, parent);
            }
        }
        else {
            me.activeModule = module;
        }
        if (me.activeModule != nil) {
            me.activeModule.activate();
            me.activeModule.fullRedraw();
        }
        else {
            me.clear();
        }
    },

    peekScratchpad: func () {
        return me.scratchpad;
    },

    popScratchpad: func () {
        var val = me.scratchpad;
        me.scratchpad = "";
        me.scratchpadElem.setText(me.scratchpad);
        return val;
    },

    setScratchpad: func (str) {
        me.scratchpad = str;
        me.scratchpadElem.setText(me.scratchpad);
    },

    handleCommand: func () {
        if (!me.powered) {
            # if not powered, don't do anything
            return;
        }
        var cmd = me.commandprop.getValue();
        if (size(cmd) == 1) {
            # this is a "char" command
            me.scratchpad = me.scratchpad ~ cmd;
            me.scratchpadElem.setText(me.scratchpad);
        }
        else if (cmd == "DEL") {
            var l = size(me.scratchpad);
            if (l > 0) {
                me.scratchpad = substr(me.scratchpad, 0, l - 1);
                me.scratchpadElem.setText(me.scratchpad);
            }
        }
        else if (cmd == "CLR") {
            me.popScratchpad();
        }
        else if (cmd == "RADIO") {
            me.activateModule("RADIO");
        }
        else if (cmd == "PERF") {
            me.activateModule("PERFINDEX");
        }
        else if (cmd == "NAV") {
            me.activateModule("NAVINDEX");
        }
        else if (cmd == "NEXT") {
            if (me.activeModule != nil) {
                me.activeModule.nextPage();
            }
        }
        else if (cmd == "PREV") {
            if (me.activeModule != nil) {
                me.activeModule.prevPage();
            }
        }
        else {
            if (me.activeModule != nil) {
                me.activeModule.handleCommand(cmd);
            }
        }
    },

    initCanvas: func () {
        me.display = canvas.new({
            "name": "MCDU" ~ me.num,
            "size": [512,512],
            "view": [512,512],
            "mipmapping": 1
        });
        me.display.addPlacement({"node": "MCDU" ~ me.num});
        me.g = me.display.createGroup();

        var x = 0;
        var y = 0;
        var i = 0;
        for (y = 0; y < cells_y; y += 1) {
            for (x = 0; x < cells_x; x += 1) {
                var elem = me.g.createChild("text", "screenbuf_" ~ i);
                elem.setText("X");
                elem.setColor(1,1,1);
                elem.setFontSize(font_size_large);
                elem.setFont("LiberationFonts/LiberationMono-Regular.ttf");
                elem.setTranslation(x * cell_w + margin_left + cell_w * 0.5, y * cell_h + margin_top + cell_h);
                elem.setAlignment('center-baseline');
                append(me.screenbuf, [" ", 0]);
                append(me.screenbufElems, elem);
                i += 1;
            }
        }

        me.repaintScreen();

        me.scratchpadElem = me.g.createChild("text", "scratchpad");
        me.scratchpadElem.setText("");
        me.scratchpadElem.setFontSize(font_size_large);
        me.scratchpadElem.setFont("LiberationFonts/LiberationMono-Regular.ttf");
        me.scratchpadElem.setColor(1,1,1);
        me.scratchpadElem.setTranslation(margin_left, (cells_y + 1) * cell_h + margin_top);

        # Dividers
        # Vertical
        var d = nil;
        var cx = margin_left + cells_x * cell_w / 2;

        d = me.g.createChild("path");
        d.moveTo(cx, margin_top + cell_h + 4);
        d.vertTo(margin_top + cell_h * 5 + 4);
        d.setColor(1,1,1);
        d.setStrokeLineWidth(2);
        d.hide();
        append(me.dividers, d);

        d = me.g.createChild("path");
        d.moveTo(cx, margin_top + cell_h * 5 + 4);
        d.vertTo(margin_top + cell_h * 9 + 4);
        d.setColor(1,1,1);
        d.setStrokeLineWidth(2);
        d.hide();
        append(me.dividers, d);

        d = me.g.createChild("path");
        d.moveTo(cx, margin_top + cell_h * 9 + 4);
        d.vertTo(margin_top + cell_h * 13 + 4);
        d.setColor(1,1,1);
        d.setStrokeLineWidth(2);
        d.hide();
        append(me.dividers, d);

        # Horizontal
        d = me.g.createChild("path");
        d.moveTo(margin_left, margin_top + cell_h * 5 + 4);
        d.horizTo(margin_left + cells_x * cell_w);
        d.setColor(1,1,1);
        d.setStrokeLineWidth(2);
        d.hide();
        append(me.dividers, d);

        d = me.g.createChild("path");
        d.moveTo(margin_left, margin_top + cell_h * 9 + 4);
        d.horizTo(margin_left + cells_x * cell_w);
        d.setColor(1,1,1);
        d.setStrokeLineWidth(2);
        d.hide();
        append(me.dividers, d);

        # Focus box
        me.focusBoxElem = me.g.createChild("path");
        me.focusBoxElem.setColor(1,1,1);
        me.focusBoxElem.setStrokeLineWidth(2);
        me.focusBoxElem.hide();
    },

    setFocusBox: func (x, y, w) {
        me.focusBoxElem.reset();
        me.focusBoxElem.rect(
            margin_left + x * cell_w,
            margin_top + y * cell_h + 4,
            cell_w * w, cell_h);
        me.focusBoxElem.setColor(1,1,1);
        me.focusBoxElem.setStrokeLineWidth(2);
        me.focusBoxElem.show();
    },

    clearFocusBox: func () {
        me.focusBoxElem.hide();
    },

    clear: func () {
        var i = 0;
        for (i = 0; i < num_cells; i += 1) {
            me.screenbuf[i] = [" ", 0];
            me.repaintCell(i);
        }
        for (i = 0; i < size(me.dividers); i += 1) {
            me.dividers[i].hide();
        }
        me.clearFocusBox();
    },

    showDivider: func (i) {
        if (i >= 0 and i < size(me.dividers)) {
            me.dividers[i].show();
        }
    },

    hideDivider: func (i) {
        if (i >= 0 and i < size(me.dividers)) {
            me.dividers[i].hide();
        }
    },

    repaintScreen: func () {
        var i = 0;
        for (i = 0; i < num_cells; i += 1) {
            me.repaintCell(i);
        }
    },

    repaintCell: func (i) {
        var elem = me.screenbufElems[i];
        var flags = me.screenbuf[i][1];
        var colorIndex = flags & 0x07;
        var largeSize = flags & mcdu_large;
        var color = mcdu_colors[colorIndex];
        elem.setText(me.screenbuf[i][0]);
        elem.setColor(color[0], color[1], color[2]);
        if (largeSize) {
            elem.setFontSize(font_size_large);
        }
        else {
            elem.setFontSize(font_size_small);
        }
    },

    print: func (x, y, str, flags) {
        if (typeof(str) != "scalar") {
            printf("Warning: tried to print object of type %s", typeof(str));
            return;
        }
        str = str ~ '';
        var i = y * cells_x + x;
        if (y < 0 or y >= cells_y) {
            return;
        }
        for (var p = 0; p < size(str); ) {
            var q = utf8NumBytes(str[p]);
            var c = substr(str, p, q);
            p += q;
            if (x >= 0) {
                me.screenbuf[i] = [c, flags];
                me.repaintCell(i);
            }
            i += 1;
            x += 1;
            if (x >= cells_x) {
                break;
            }
        }
    }
};

var mcdu0 = nil;
var mcdu1 = nil;

setlistener("/sim/signals/fdm-initialized", func () {
    mcdu0 = MCDU.new(0);
    mcdu1 = MCDU.new(1);
    setlistener("/systems/electrical/outputs/efis", func () {
        if (getprop("/systems/electrical/outputs/efis") < 15.0) {
            mcdu0.powerOff();
            mcdu1.powerOff();
        }
        else {
            mcdu0.powerOn();
            mcdu1.powerOn();
        }
    });
});
