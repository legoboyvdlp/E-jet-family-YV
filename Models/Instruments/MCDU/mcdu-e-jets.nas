# Embraer E-Jet family MCDU.
#
# E190 AOM:
# - p1582: T/O DATASET menu
# - p1761: MCDU CONTROLS
# - p1804: RADIO COMMUNICATION SYSTEM
# - p1822: ACARS etc.
# - p1859: IRS
# - p1901: Preflight flow

var swapProps = func (prop1, prop2) {
    fgcommand("property-swap", {
        "property[0]": prop1,
        "property[1]": prop2
    });
};

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
};

var BaseView = {
    new: func (key, x, y, flags) {
        return {
            parents: [BaseView],
            key: key,
            prop: (key == nil) ? nil : (keyProps[key]),
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

    # Draw the widget to the given MCDU.
    draw: func (mcdu) {
    },
};

var BaseController = {
    new: func (key) {
        return {
            parents: [BaseController],
            key: key,
            model: keyProps[key],
        };
    },

    # Parse a raw string into a formatted value.
    # Return the parsed value, or nil if the parse failed.
    parse: func (val) {
        return val;
    },

    # Pass a "set value" request to the underlying model.
    set: func (val) {
        val = me.parse(val);
        if (val != nil) {
            setprop(me.model, val);
        }
        return val;
    },

    # Process a select event. The 'boxed' argument indicates that the
    # controller's key is currently boxed.
    # Return value indicates desired response:
    # - nil -> no response necessary
    # - ['box', $key ] -> box the given $key
    # - ['redraw', $key ] -> redraw the given $key
    # - ['goto', $target ] -> go to the $target page
    # - ['ret'] -> return to the previous page
    select: func (boxed) {
        return nil;
    },

    # Process a send event.
    # Scratchpad contents is sent as the value.
    # Return updated scratchpad contents to indicate acceptance, or nil to
    # keep scratchpad value unchanged and signal rejection.
    send: func (val) {
        return nil;
    },

    # Process a dialling event.
    dial: func (digit) {
        return nil;
    },
};

var CycleController = {
    new: func (key, values = [0, 1]) {
        var m = BaseController.new(key);
        m.parents = [CycleController, BaseController];
        m.values = values;
    },

    cycle: func () {
        var val = getprop(me.prop);
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
        setprop(me.prop, val);
    },

    select: func (ignore) {
        me.cycle();
        return [ 'redraw', me.key ];
    },

    send: func (scratch) {
        me.cycle();
        return scratch;
        # we're not rejecting the input, we just don't need scratchpad
        # input
    },
};

var TransponderController = {
    new: func (key, x, y, flags, goto = nil) {
        var m = BaseController.new(key, x, y, flags);
        m.parents = [TransponderController, BaseController];
        return m;
    },

    parse: func (val) {
        val = parseOctal(val);
        if (val == nil or val < 0 or val > 0o7777) { return nil; }
        val = sprintf("%04o", val);
        return val;
    },

    select: func (boxed) {
        if (boxed) {
            return nil;
        }
        else {
            return ['box', me.key];
        }
    },

    dial: func (digit) {
        var val = getprop(me.prop);
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

        setprop(me.prop, sprintf("%04o", val));
    },
};


var StaticView = {
    new: func (x, y, txt, flags) {
        var m = BaseView.new(nil, x, y, flags);
        m.parents = [StaticView, BaseView];
        m.w = size(txt);
        m.txt = txt;
        return m;
    },

    draw: func (mcdu) {
        mcdu.print(me.x, me.y, me.txt, me.flags);
    },
};

var ToggleView = {
    new: func (key, x, y, flags, txt) {
        var m = BaseView.new(key, x, y, flags);
        m.parents = [ToggleView, BaseView];
        m.w = size(txt);
        m.txt = txt;
        m.clear = "";
        while (size(m.clear) < size(txt)) {
            m.clear ~= " ";
        }
        return m;
    },

    draw: func (mcdu) {
        var val = getprop(me.prop);
        mcdu.print(me.x, me.y, val ? me.txt : me.clear, me.flags);
    },
};

var FormatView = {
    new: func (key, x, y, flags, w, fmt = nil, mapping = nil) {
        var m = BaseView.new(key, x, y, flags);
        m.parents = [FormatView, BaseView];
        m.mapping = mapping;
        m.w = w;
        if (fmt == nil) { fmt = "%" ~ w ~ "s"; }
        m.fmt = fmt;
        return m;
    },

    draw: func (mcdu) {
        var val = getprop(me.prop);
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
    new: func (key, x, y, latlon, flags) {
        var m = BaseView.new(key, x, y, flags);
        m.parents = [GeoView, BaseView];
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

    draw: func (mcdu) {
        var val = getprop(me.prop);
        var dir = (val < 0) ? (me.dirs[0]) : (me.dirs[1]);
        var degs = math.abs(val);
        var mins = math.fmod(degs * 60, 60);
        mcdu.print(me.x, me.y, sprintf(me.fmt, dir, degs, mins), me.flags);
    },
};

var StringView = {
    new: func (key, x, y, flags, w) {
        var m = BaseView.new(key, x, y, flags);
        m.parents = [StringView, BaseView];
        m.w = w;
        return m;
    },

    draw: func (mcdu) {
        var val = getprop(me.prop);
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
    new: func (key, x, y, flags, values = nil, labels = nil) {
        if (values == nil) { values = [0, 1]; }
        if (labels == nil) { labels = ["OFF", "ON"]; }
        var m = BaseView.new(key, x, y, flags);
        m.parents = [CycleView, BaseView];
        m.values = values;
        m.labels = labels;
        m.w = -1;
        foreach (var val; values) {
            var label = (typeof(labels) == "func") ? labels(val) : labels[val];
            m.w += size(label) + 1;
        }
        return m;
    },

    draw: func (mcdu) {
        var val = getprop(me.prop);
        var x = me.x;
        foreach (var v; me.values) {
            var label = (typeof(me.labels) == "func") ? me.labels(v) : me.labels[v];
            if (label == nil) { continue; }
            mcdu.print(x, me.y, label, (v == val) ? me.flags : 0);
            x += size(label) + 1;
        }
    },
};


var FreqView = {
    new: func (key, x, y, flags, ty = nil) {
        var m = BaseView.new(key, x, y, flags);
        m.parents = [FreqView, BaseView];
        if (ty == nil) {
            ty = substr(key, 0, 3);
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
    draw: func (mcdu) {
        var val = getprop(me.prop);
        mcdu.print(me.x, me.y, sprintf(me.fmt, val), me.flags);
    },

};

var FreqController = {
    new: func (key, ty = nil) {
        var m = BaseController.new(key);
        m.parents = [FreqController, BaseView];
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
            m.amounts = [0.1, 1, 10, 100];
            m.min = 190.0;
            m.max = 999.9;
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

    select: func (boxed) {
        if (boxed) {
            return nil;
        }
        else {
            return ['box', me.key];
        }
    },


    dial: func (digit) {
        if (digit == 0) {
            return;
        }
        var adigit = math.abs(digit) - 1;
        var amount = me.amounts[adigit];
        var val = getprop(me.prop);
        if (digit > 0) {
            val = math.min(me.max, val + amount);
        }
        else {
            val = math.max(me.min, val - amount);
        }
        setprop(me.prop, val);
    },
};

var Module = {
    new: func (mcdu, mode, n) {
        var m = { parents: [Module] };
        m.mcdu = mcdu;
        m.page = 0;
        m.active = 0;
        m.listeners = [];
        var modeFactory = Module.modes[mode];
        var parentModule = mcdu.activeModule;
        var ptitle = nil;
        var maxw = math.round(cells_x / 2) - 1;
        if (parentModule != nil) {
            ptitle = sprintf("%s %d/%d",
                parentModule.mode.title,
                parentModule.page + 1,
                parentModule.getNumPages());
        }
        if (ptitle != nil and size(ptitle) > maxw) {
            ptitle = parentModule.mode.title;
        }
        if (ptitle != nil and size(ptitle) > maxw) {
            ptitle = substr(ptitle, 0, maxw);
        }

        var mode = (Module.modes[mode])(ptitle, n);
        m.pages = mode.pages;
        m.title = m.mode.title;
        m.selectedKey = nil;
        return m;
    },

    drawPager: func () {
        me.mcdu.print(21, 0, sprintf("%1d/%1d", me.page + 1, me.getNumPages()), 0);
    },

    drawTitle: func () {
        var x = math.floor((cells_x - 3 - size(me.title)) / 2);
        me.mcdu.print(x, 0, me.title, mcdu_large | mcdu_white);
    },

    fullRedraw: func () {
        me.mcdu.clear();
        me.drawTitle();
        me.drawPager();
        me.redraw();
    },

    nextPage: func () {
        if (me.page < me.getNumPages() - 1) {
            me.page += 1;
            me.onPageChanged();
            me.fullRedraw();
        }
    },

    prevPage: func () {
        if (me.page > 0) {
            me.page -= 1;
            me.onPageChanged();
            me.fullRedraw();
        }
    },

    defHandlers: {
        "INC1": [ "propdial", [ 1 ] ],
        "DEC1": [ "propdial", [ -1 ] ],
        "INC2": [ "propdial", [ 2 ] ],
        "DEC2": [ "propdial", [ -2 ] ],
        "INC3": [ "propdial", [ 3 ] ],
        "DEC3": [ "propdial", [ -3 ] ],
        "INC4": [ "propdial", [ 4 ] ],
        "DEC4": [ "propdial", [ -4 ] ],
    },

    modes: {
        "NAVINDEX": func (ptitle, n) {
            return {
                title: "NAV INDEX",
                pages: [
                    {
                        views: [
                            StaticView.new( 0,  2, left_triangle ~ "NAV IDENT  ", mcdu_large | mcdu_white),
                            StaticView.new( 0,  4, left_triangle ~ "WPT LIST   ", mcdu_large | mcdu_white),
                            StaticView.new( 0,  6, left_triangle ~ "FPL LIST   ", mcdu_large | mcdu_white),
                            StaticView.new( 0,  8, left_triangle ~ "POS SENSORS", mcdu_large | mcdu_white),
                            StaticView.new( 0, 10, left_triangle ~ "FIX INFO   ", mcdu_large | mcdu_white),
                            StaticView.new( 0, 12, left_triangle ~ "DEPARTURE  ", mcdu_large | mcdu_white),
                            StaticView.new(12,  6, "    FLT SUM" ~ right_triangle, mcdu_large | mcdu_white),
                            StaticView.new(12, 10, "       HOLD" ~ right_triangle, mcdu_large | mcdu_white),
                            StaticView.new(12, 12, "    ARRIVAL" ~ right_triangle, mcdu_large | mcdu_white),
                        ],
                        controllers: {
                            "L1": [ "goto", ["NAVIDENT"] ],
                        }
                    },
                    {
                        views: [
                            StaticView.new( 0,  2, left_triangle ~ "POS INIT   ", mcdu_large | mcdu_white),
                            StaticView.new( 0,  4, left_triangle ~ "DATA LOAD  ", mcdu_large | mcdu_white),
                            StaticView.new( 0,  6, left_triangle ~ "PATTERNS   ", mcdu_large | mcdu_white),
                            StaticView.new(12,  2, " CONVERSION" ~ right_triangle, mcdu_large | mcdu_white),
                            StaticView.new(12,  4, "MAINTENANCE" ~ right_triangle, mcdu_large | mcdu_white),
                            StaticView.new(12,  6, "  CROSS PTS" ~ right_triangle, mcdu_large | mcdu_white),
                        ],
                        controllers: {
                            "L1": [ "goto", ["POSINIT"] ]
                        }
                    }
                ]
            };
        },
        "NAVIDENT": func (ptitle, n) {
            return {
                title: "NAV IDENT",
                pages: [
                    {
                        views: [
                            StaticView.new( 2,  1, "DATE", mcdu_white),
                            FormatView.new("ZDAY", 1, 2, mcdu_large | mcdu_white, 2, "%02d"),
                            FormatView.new("ZMON", 3, 2, mcdu_large | mcdu_white, 3, "%3s",
                                [ "XXX", "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" ]),
                            FormatView.new("ZYEAR", 6, 2, mcdu_large | mcdu_white, 2, "%02d",
                                func (y) { return math.mod(y, 100); }),
                            StaticView.new( 2,  3, "UTC", mcdu_white),
                            FormatView.new("ZHOUR", 1, 4, mcdu_large | mcdu_white, 2, "%02d"),
                            FormatView.new("ZMIN", 3, 4, mcdu_large | mcdu_white, 2, "%02d"),
                            StaticView.new( 6,  4, "Z", mcdu_white),
                            StaticView.new( 2,  5, "SW", mcdu_white),
                            FormatView.new("FGVER", 1,  6, mcdu_large | mcdu_white, 10, "%-10s"),
                            StaticView.new(11,  5, "NDS V3.01 16M", mcdu_white),
                            StaticView.new(12,  6, "WORLD3-301", mcdu_large | mcdu_white),
                            StaticView.new( 0, 12, left_triangle ~ "MAINTENANCE", mcdu_large | mcdu_white),
                            StaticView.new(12, 12, "   POS INIT" ~ right_triangle, mcdu_large | mcdu_white),
                        ],
                        controllers: {
                            "R6": [ "goto", ["POSINIT"] ]
                        }
                    },
                ]
            };
        },
        "POSINIT": func (ptitle, n) {
            var m = {
                title: "POSITION INIT",
                pages: [
                    {
                        views: [
                            StaticView.new(        1,  1, "LAST POS",              mcdu_white),
                            GeoView.new("RAWLAT",  0,  2, "LAT",      mcdu_large | mcdu_green),
                            GeoView.new("RAWLON",  9,  2, "LON",      mcdu_large | mcdu_green),
                            ToggleView.new("POSLOADED1", 17,  1, mcdu_white, "LOADED"),
                            StaticView.new(       19,  2, "LOAD" ~ right_triangle, mcdu_large | mcdu_white),

                            StaticView.new(        1,  5, "GPS1 POS",              mcdu_white),
                            GeoView.new("GPSLAT",  0,  6, "LAT",      mcdu_large | mcdu_green),
                            GeoView.new("GPSLON",  9,  6, "LON",      mcdu_large | mcdu_green),
                            ToggleView.new("POSLOADED3", 17,  5, mcdu_white, "LOADED"),
                            StaticView.new(       19,  6, "LOAD" ~ right_triangle, mcdu_large | mcdu_white),
                            StaticView.new(        0, 12, left_triangle ~ "POS SENSORS", mcdu_large | mcdu_white),
                        ],
                        controllers: {
                            "R1": [ "enable", ["POSLOADED1"] ]
                            "R3": [ "enable", ["POSLOADED3"] ]
                        }
                    }
                ]
            };
            if (ptitle != nil) {
                m.pages[0].controllers["R6"] = [ "ret", [] ];
                append(
                    m.pages[0].views,
                    StaticView.new(22 - size(ptitle), 12, ptitle, mcdu_large));
                append(
                    m.pages[0].views,
                    StaticView.new(23, 12, right_triangle, mcdu_large));
            }
            return m;
        },
        "RADIO": func (ptitle, n) {
            return {
                title: "RADIO",
                pages: [
                    {
                        views: [
                            FreqView.new("COM1A",  1, 2, mcdu_large | mcdu_green),
                            FreqView.new("COM1S",  1, 4, mcdu_large | mcdu_yellow),
                            FreqView.new("COM2A", 16, 2, mcdu_large | mcdu_green),
                            FreqView.new("COM2S", 16, 4, mcdu_large | mcdu_yellow),

                            FreqView.new("NAV1A",  1, 6, mcdu_large | mcdu_green),
                            FreqView.new("NAV1S",  1, 8, mcdu_large | mcdu_yellow),
                            FreqView.new("NAV2A", 17, 6, mcdu_large | mcdu_green),
                            FreqView.new("NAV2S", 17, 8, mcdu_large | mcdu_yellow),

                            TransponderView.new("XPDRA", 19, 10, mcdu_large | mcdu_green),

                            ToggleView.new("NAV1AUTO",  8, 5, mcdu_large | mcdu_blue, "FMS"),
                            ToggleView.new("NAV1AUTO",  8, 6, mcdu_large | mcdu_blue, "AUTO"),
                            ToggleView.new("NAV2AUTO", 12, 5, mcdu_large | mcdu_blue, "FMS"),
                            ToggleView.new("NAV2AUTO", 12, 6, mcdu_large | mcdu_blue, "AUTO"),

                            CycleView.new("XPDRON", 1, 12, mcdu_large | mcdu_green,
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

                            StaticView.new(  1, 10, "TCAS/XPDR",              mcdu_large | mcdu_white ),
                            StaticView.new(  0, 12, left_right_arrow,         mcdu_large | mcdu_white ),
                        ],
                        dividers: [0, 1, 3, 4],
                        controllers: {
                            "L1": [ "freqswap", ["COM1"] ],
                            "L2": [ "propsel", ["COM1S", "COM1"] ],
                            "L3": [ "freqswap", ["NAV1"] ],
                            "L4": [ "propsel", ["NAV1S", "NAV1"] ],
                            "L5": [ "goto", ["XPDR"] ],
                            "L6": [ "toggle", ["XPDRON"] ],
                            "R1": [ "freqswap", ["COM2"] ],
                            "R2": [ "propsel", ["COM2S", "COM2"] ],
                            "R3": [ "freqswap", ["NAV2"] ],
                            "R4": [ "propsel", ["NAV2S", "NAV2"] ],
                            "R5": [ "propsel", ["XPDRA", "XPDR"] ],
                            "R6": [ "ident", [] ],
                        }
                    },
                    {
                        views: [
                            FreqView.new("ADF1A",  1, 2, mcdu_large | mcdu_green),
                            FreqView.new("ADF1S",  1, 4, mcdu_large | mcdu_yellow),
                            FreqView.new("ADF2A", 18, 2, mcdu_large | mcdu_green),
                            FreqView.new("ADF2S", 18, 4, mcdu_large | mcdu_yellow),
                            StaticView.new( 1, 1, "ADF1",         mcdu_white ),
                            StaticView.new( 0, 4, left_triangle,  mcdu_large | mcdu_white ),
                            StaticView.new(19, 1, "ADF2",         mcdu_white ),
                            StaticView.new(23, 4, right_triangle, mcdu_large | mcdu_white ),
                        ],
                        dividers: [0, 1, 2, 3, 4],
                        controllers: {
                            "L1": [ "freqswap", ["ADF1"] ],
                            "R1": [ "freqswap", ["ADF2"] ],
                            "L2": [ "propsel", ["ADF1S"] ],
                            "R2": [ "propsel", ["ADF2S"] ],
                        }
                    }
                ]
            };
        },
        "NAV": func (ptitle, n) {
            return {
                title: "NAV " ~ n,
                pages: [
                    {
                        views: [
                            FreqView.new("NAV" ~ n ~ "A",      1,  2, mcdu_large |  mcdu_green),
                            FreqView.new("NAV" ~ n ~ "S",      1,  4, mcdu_large |  mcdu_yellow),
                            CycleView.new("DME" ~ n ~ "H",    17, 4, mcdu_large | mcdu_green),
                            CycleView.new("NAV" ~ n ~ "AUTO", 17, 10, mcdu_large | mcdu_green),
                            StaticView.new(  1,  1, "ACTIVE",                 mcdu_white ),
                            StaticView.new(  0,  2, up_down_arrow, mcdu_large | mcdu_white ),
                            StaticView.new(  1,  3, "PRESET",                 mcdu_white ),
                            StaticView.new(  0,  4, left_triangle, mcdu_large | mcdu_white ),
                            StaticView.new( 15,  3, "DME HOLD",               mcdu_white ),
                            StaticView.new( 15,  9, "FMS AUTO",               mcdu_white ),
                            StaticView.new(  0, 12, left_triangle, mcdu_large | mcdu_white ),
                            StaticView.new(  1, 12, "MEMORY", mcdu_large | mcdu_white ),
                            StaticView.new( 14, 12, ptitle, mcdu_large | mcdu_white ),
                            StaticView.new( 23, 12, right_triangle, mcdu_large | mcdu_white ),
                        ],
                        controllers: {
                            "L1": [ "freqswap", ["NAV" ~ n] ],
                            "L2": [ "propsel", ["NAV" ~ n ~ "S"] ],
                            "R2": [ "toggle", ["DME" ~ n ~ "H"] ],
                            "R5": [ "toggle", ["NAV" ~ n ~ "AUTO"] ],
                            "R6": [ "ret", [] ],
                        }
                    }
                ]
            };
        },
        "COM": func (ptitle, n) {
            return {
                title: "COM " ~ n,
                pages: [
                    {
                        views: [
                            FreqView.new("COM" ~ n ~ "A",  1,  2, mcdu_large |  mcdu_green),
                            FreqView.new("COM" ~ n ~ "S",  1,  4, mcdu_large | mcdu_yellow),
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
                            StaticView.new( 14, 12, ptitle, mcdu_large | mcdu_white ),
                            StaticView.new( 23, 12, right_triangle, mcdu_large | mcdu_white ),
                        ],
                        controllers: {
                            "L1": [ "freqswap", ["COM" ~ n] ],
                            "L2": [ "propsel", ["COM" ~ n ~ "S"] ],
                            "R6": [ "ret", [] ],
                        }
                    }
                ]
            };
        },
        "XPDR": func (ptitle, n) {
            return {
                title: "TCAS/XPDR",
                pages: [
                    {
                        views: [
                            TransponderView.new("XPDRA",  1,  2, mcdu_large |  mcdu_green),
                            TransponderView.new("XPDRS",  1,  4, mcdu_large | mcdu_yellow),
                            FormatView.new("PALT", 18, 2, mcdu_large | mcdu_green, 5, "%5.0f"),
                            StringView.new("FLTID", 17, 4, mcdu_large | mcdu_green, 6),
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
                            StaticView.new( 14, 12, ptitle,              mcdu_large | mcdu_white ),
                            StaticView.new( 23, 12, right_triangle,           mcdu_large | mcdu_white ),
                        ],
                        controllers: {
                            "L1": [ "freqswap", ["XPDR"] ],
                            "L2": [ "propsel", ["XPDRS"] ],
                            "R2": [ "propsel", ["FLTID"] ],
                            "R5": [ "ident", [] ],
                            "R6": [ "ret", [] ],
                        }
                    },
                    {
                        views: [
                            CycleView.new("XPDRMD", 1, 2, mcdu_large | mcdu_green, [4,3,2,1], xpdrModeLabels),
                            StaticView.new(  1,  1, "TCAS/XPDR MODE",         mcdu_white ),
                            StaticView.new(  0,  2, black_square,             mcdu_large | mcdu_white ),
                            StaticView.new(  1,  4, "ALT RANGE",              mcdu_white ),
                            StaticView.new( 14, 12, "RADIO 1/2",              mcdu_large | mcdu_white ),
                            StaticView.new( 23, 12, right_triangle,           mcdu_large | mcdu_white ),
                        ],
                        dividers: [],
                        controllers: {
                            "L1": [ "propcycle", ["XPDRMD"] ],
                            "R6": [ "ret", [] ],
                        }
                    }
                ]
            };
        },
    },

    getNumPages: func () {
        return size(me.pages);
    },

    onPageChanged: func () {
        me.selectedKey = nil;
    },

    drawFreq: func (key) {
        foreach (var widget; me.pages[me.page].views) {
            if (widget.key == key) {
                widget.draw(me.mcdu);
            }
        }
    },

    findView: func (key) {
        if (key == nil) {
            return nil;
        }
        foreach (var widget; me.pages[me.page].views) {
            if (widget.key == key) {
                return widget;
            }
        }
        return nil;
    },

    drawFocusBox: func () {
        var widget = me.findView(me.selectedKey);
        if (widget == nil) {
            me.mcdu.clearFocusBox();
        }
        else {
            me.mcdu.setFocusBox(widget.getL(), widget.getT(), widget.getW());
        }
    },

    redraw: func () {
        var currentPage = me.pages[me.page];
        foreach (var widget; me.pages[me.page].views) {
            widget.draw(me.mcdu);
        }
        if (contains(currentPage, "dividers")) {
            foreach (var d; currentPage.dividers) {
                me.mcdu.showDivider(d);
            }
        }
        me.drawFocusBox();
    },

    activate: func () {
        var activateFreq = func (k) {
            if (k == nil) {
                return;
            }
            append(me.listeners, setlistener(keyProps[k], func (changed) {
                me.drawFreq(k);
            }));
        };
        foreach (var page; me.pages) {
            foreach (var widget; page.views) {
                activateFreq(widget.key);
            }
        }
    },

    deactivate: func () {
        foreach (var listener; me.listeners) {
            removelistener(listener);
        }
        me.listeners = [];
    },

    freqswap: func (keyBase) {
        var prop1 = keyProps[keyBase ~ "A"];
        var prop2 = keyProps[keyBase ~ "S"];
        swapProps(prop1, prop2);
    },

    propsel: func (key, link = nil, boxable = 1) {
        var val = me.mcdu.popScratchpad();
        if (val == "") {
            if (boxable) {
                if (me.selectedKey == key) {
                    if (link != nil) {
                        me.mcdu.pushModule(link);
                    }
                }
                else {
                    me.selectedKey = key;
                    me.drawFocusBox();
                }
            }
        }
        else {
            var widget = me.findView(key);
            if (widget == nil) {
                # TODO: issue error message in scratchpad
            }
            else {
                # TODO: issue error message in scratchpad if parse failed
                widget.set(val);
            }
        }
    },

    enable: func (key, val = 1) {
        var prop = keyProps[key];
        setprop(prop, val);
        me.drawFreq(key);
    },

    propcycle: func (key) {
        var widget = me.findView(key);
        widget.cycle();
        me.drawFreq(key);
    },

    propdial: func (digit) {
        var widget = me.findView(me.selectedKey);
        widget.dial(digit);
        me.drawFreq(me.selectedKey);
    },

    toggle: func (key) {
        var prop = keyProps[key];
        fgcommand("property-toggle", { "property": prop });
        me.drawFreq(key);
    },

    ident: func () {
        setprop("/instrumentation/transponder/inputs/ident-btn", 1);
    },

    goto: func (target) {
        me.mcdu.pushModule(target);
    },

    ret: func () {
        me.mcdu.popModule();
    },

    handleCommand: func (cmd) {
        var c = me.pages[me.page].handlers[cmd];
        if (c == nil) { c = me.defHandlers[cmd]; }
        var funcs = {
            "propdial": me.propdial,
            "freqswap": me.freqswap,
            "propsel": me.propsel,
            "propcycle": me.propcycle,
            "toggle": me.toggle,
            "enable": me.enable,
            "ident": me.ident,
            "goto": me.goto,
            "ret": me.ret,
        };
        if (c != nil) {
            var f = funcs[c[0]];
            if (f != nil) {
                call(f, c[1], me);
            }
        }
    }
};

var MCDU = {
    new: func (n) {
        var m = {
            parents: [MCDU],
            num: n,
            rootprop: props.globals.getNode("/instrumentation/mcdu[" ~ n ~ "]"),
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
        "NAV1":  func (mcdu) { return Module.new(mcdu, "NAV", 1); },
        "NAV2":  func (mcdu) { return Module.new(mcdu, "NAV", 2); },
        "COM1":  func (mcdu) { return Module.new(mcdu, "COM", 1); },
        "COM2":  func (mcdu) { return Module.new(mcdu, "COM", 2); },
    },

    pushModule: func (moduleName) {
        if (me.activeModule != nil) {
            append(me.moduleStack, me.activeModule);
            me.activateModule(moduleName);
        }
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
        if (typeof(module) == "scalar") {
            var factory = me.makeModule[module];
            if (factory == nil) {
                factory = func (mcdu) { return Module.new(mcdu, module, 0); };
            }
            me.activeModule = factory(me);
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
