# Embraer E-Jet family MCDU.

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

var xpdrModeLabels = [
    "STBY",
    "ALT-OFF",
    "ALT-ON",
    "TA",
    "TA/RA",
];


var widgetProps = {
    # key      property                                             type
    "NAV1A": [ "/instrumentation/nav[0]/frequencies/selected-mhz",  "NAV" ],
    "NAV1S": [ "/instrumentation/nav[0]/frequencies/standby-mhz",   "NAV" ],
    "NAV1ID": [ "/instrumentation/nav[0]/nav-id",                   "STR" ],
    "DME1H": [ "/instrumentation/dme[0]/frequencies/source",       "DMEH" ],
    "NAV1AUTO": [ "/fms/radio/nav-auto[0]",                       "ONOFF" ],
    "NAV2A": [ "/instrumentation/nav[1]/frequencies/selected-mhz",  "NAV" ],
    "NAV2S": [ "/instrumentation/nav[1]/frequencies/standby-mhz",   "NAV" ],
    "NAV2ID": [ "/instrumentation/nav[1]/nav-id",                   "STR" ],
    "DME2H": [ "/instrumentation/dme[1]/frequencies/source",       "DMEH" ],
    "NAV2AUTO": [ "/fms/radio/nav-auto[1]",                       "ONOFF" ],
    "COM1A": [ "/instrumentation/comm[0]/frequencies/selected-mhz", "COM" ],
    "COM1S": [ "/instrumentation/comm[0]/frequencies/standby-mhz",  "COM" ],
    "COM2A": [ "/instrumentation/comm[1]/frequencies/selected-mhz", "COM" ],
    "COM2S": [ "/instrumentation/comm[1]/frequencies/standby-mhz",  "COM" ],
    "ADF1A": [ "/instrumentation/adf[0]/frequencies/selected-khz",  "ADF" ],
    "ADF1S": [ "/instrumentation/adf[0]/frequencies/standby-khz",   "ADF" ],
    "ADF2A": [ "/instrumentation/adf[1]/frequencies/selected-khz",  "ADF" ],
    "ADF2S": [ "/instrumentation/adf[1]/frequencies/standby-khz",   "ADF" ],
    "XPDRA": [ "/instrumentation/transponder/id-code",             "XPDR" ],
    "XPDRS": [ "/instrumentation/transponder/standby-id",          "XPDR" ],
    "XPDRON": [ "/fms/radio/tcas-xpdr/enabled",                  "XPDRON" ],
    "XPDRMD": [ "/fms/radio/tcas-xpdr/mode",                     "XPDRMD" ],
    "FLTID": [ "/sim/multiplay/callsign",                           "STR" ],
    "PALT": [ "/instrumentation/altimeter/pressure-alt-ft",         "ALT" ],
};

var propTypes = {
    # key        type     min    max
    "COM":    [   "mhz",  118.0, 137.0 ],
    "NAV":    [   "mhz",  108.0, 118.0 ],
    "ADF":    [   "khz",  190.0, 999.0 ],
    "XPDR":   [  "xpdr",    nil,   nil ],
    "DMEH":   [  "dmeh",    nil,   nil ],
    "ONOFF":  [  "bool",      0,     1 ],
    "STR":    [   "str",    nil,   nil ],
    "XPDRON": [ "xpdron",     0,     1 ],
    "XPDRMD": [ "xpdrmd",     1,     4 ],
    "ALT":    [    "ft",  -5000, 60000 ],
};

var validate = func (val, ty) {
    if (ty[1] != nil and val < ty[1]) return 0;
    if (ty[2] != nil and val > ty[2]) return 0;
    return 1;
};

var Module = {
    new: func (mcdu, mode, n) {
        var m = { parents: [Module] };
        m.mcdu = mcdu;
        m.page = 0;
        m.active = 0;
        m.listeners = {};
        m.mode = (Module.modes[mode])(n);
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
        "RADIO": func (n) {
            return {
                title: "RADIO",
                pages: [
                    {
                        widgets: {
                            #               x   y      fmt                     flags  w
                            "COM1A":    [[  1,  2, "%7.3f",  mcdu_large |  mcdu_green, 7 ]],
                            "COM1S":    [[  1,  4, "%7.3f",  mcdu_large | mcdu_yellow, 7 ]],
                            "COM2A":    [[ 16,  2, "%7.3f",  mcdu_large |  mcdu_green, 7 ]],
                            "COM2S":    [[ 16,  4, "%7.3f",  mcdu_large | mcdu_yellow, 7 ]],
                            "NAV1A":    [[  1,  6, "%6.2f",  mcdu_large |  mcdu_green, 6 ]],
                            "NAV1S":    [[  1,  8, "%6.2f",  mcdu_large | mcdu_yellow, 6 ]],
                            "NAV2A":    [[ 17,  6, "%6.2f",  mcdu_large |  mcdu_green, 6 ]],
                            "NAV2S":    [[ 17,  8, "%6.2f",  mcdu_large | mcdu_yellow, 6 ]],
                            "XPDRA":    [[ 19, 10, "%04s",   mcdu_large |  mcdu_green, 4 ]],
                            "NAV1AUTO": [[  8,  5, "?FMS",    mcdu_large |  mcdu_blue, 4 ],
                                         [  8,  6, "?AUTO",   mcdu_large |  mcdu_blue, 4 ]],
                            "NAV2AUTO": [[ 12,  5, "?FMS",    mcdu_large |  mcdu_blue, 4 ],
                                         [ 12,  6, "?AUTO",   mcdu_large |  mcdu_blue, 4 ]],
                            "XPDRON":   [[  1, 12, "XPDRON", mcdu_large | mcdu_green, 10 ]],
                        },
                        static: [
                            [  0,  1, up_down_arrow,            mcdu_large | mcdu_white ],
                            [  1,  1, "COM1",                   mcdu_white ],
                            [  0,  4, left_triangle,            mcdu_large | mcdu_white ],

                            [ 23,  1, up_down_arrow,            mcdu_large | mcdu_white ],
                            [ 19,  1, "COM2",                   mcdu_white ],
                            [ 23,  4, right_triangle,           mcdu_large | mcdu_white ],

                            [  0,  5, up_down_arrow,            mcdu_large | mcdu_white ],
                            [  1,  5, "NAV1",                   mcdu_white ],
                            [  0,  8, left_triangle,            mcdu_large | mcdu_white ],

                            [ 23,  5, up_down_arrow,            mcdu_large | mcdu_white ],
                            [ 19,  5, "NAV2",                   mcdu_white ],
                            [ 23,  8, right_triangle,           mcdu_large | mcdu_white ],

                            [ 19,  9, "XPDR",                   mcdu_white ],
                            [ 23, 10, right_triangle,           mcdu_large | mcdu_white ],
                            [ 18, 11, "IDENT",                  mcdu_white ],
                            [ 18, 12, "IDENT",                  mcdu_large | mcdu_white ],
                            [ 23, 12, black_square,             mcdu_large | mcdu_white ],
                            [  0, 10, left_triangle,            mcdu_large | mcdu_white ],
                            [  1, 10, "TCAS/XPDR",              mcdu_large | mcdu_white ],
                            [  0, 12, left_right_arrow,         mcdu_large | mcdu_white ],
                        ],
                        dividers: [0, 1, 3, 4],
                        handlers: {
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
                        widgets: {
                            #            x   y      fmt                     flags  w
                            "ADF1A": [[  1,  2, "%5.1f", mcdu_large |  mcdu_green, 5 ]],
                            "ADF1S": [[  1,  4, "%5.1f", mcdu_large | mcdu_yellow, 5 ]],
                            "ADF2A": [[ 18,  2, "%5.1f", mcdu_large |  mcdu_green, 5 ]],
                            "ADF2S": [[ 18,  4, "%5.1f", mcdu_large | mcdu_yellow, 5 ]],
                        },
                        static: [
                            [ 1, 1, "ADF1",         mcdu_white ],
                            [ 0, 4, left_triangle,  mcdu_large | mcdu_white ],
                            [19, 1, "ADF2",         mcdu_white ],
                            [23, 4, right_triangle, mcdu_large | mcdu_white ],
                        ],
                        dividers: [0, 1, 2, 3, 4],
                        handlers: {
                            "L1": [ "freqswap", ["ADF1"] ],
                            "R1": [ "freqswap", ["ADF2"] ],
                            "L2": [ "propsel", ["ADF1S"] ],
                            "R2": [ "propsel", ["ADF2S"] ],
                        }
                    }
                ]
            };
        },
        "NAV": func (n) {
            var widgets = {};
            #                                 x   y      fmt         flags                     w
            widgets["NAV" ~ n ~ "A"] =    [[  1,  2, "%6.2f",        mcdu_large |  mcdu_green, 6 ]];
            widgets["NAV" ~ n ~ "S"] =    [[  1,  4, "%6.2f",        mcdu_large | mcdu_yellow, 6 ]];
            widgets["DME" ~ n ~ "H"] =    [[ 17,  4, "OFFON",        mcdu_large |  mcdu_green, 6 ]];
            widgets["NAV" ~ n ~ "AUTO"] = [[ 17, 10, "OFFON",        mcdu_large |  mcdu_green, 6 ]];
            return {
                title: "NAV " ~ n,
                pages: [
                    {
                        widgets: widgets,
                        static: [
                            [  1,  1, "ACTIVE",                 mcdu_white ],
                            [  0,  2, up_down_arrow, mcdu_large | mcdu_white ],
                            [  1,  3, "PRESET",                 mcdu_white ],
                            [  0,  4, left_triangle, mcdu_large | mcdu_white ],
                            [ 15,  3, "DME HOLD",               mcdu_white ],
                            [ 15,  9, "FMS AUTO",               mcdu_white ],
                            [  0, 12, left_triangle, mcdu_large | mcdu_white ],
                            [  1, 12, "MEMORY", mcdu_large | mcdu_white ],
                            [ 14, 12, "RADIO 1/2", mcdu_large | mcdu_white ],
                            [ 23, 12, right_triangle, mcdu_large | mcdu_white ],
                        ],
                        dividers: [],
                        handlers: {
                            "L1": [ "freqswap", ["NAV" ~ n] ],
                            "L2": [ "propsel", ["NAV" ~ n ~ "S"] ],
                            "R2": [ "toggledme", ["DME" ~ n ~ "H", "NAV" ~ n ~ "A"] ],
                            "R5": [ "toggle", ["NAV" ~ n ~ "AUTO"] ],
                            "R6": [ "ret", [] ],
                        }
                    }
                ]
            };
        },
        "COM": func (n) {
            var widgets = {};
            #                                 x   y      fmt         flags                     w
            widgets["COM" ~ n ~ "A"] =    [[  1,  2, "%7.3f",        mcdu_large |  mcdu_green, 7 ]];
            widgets["COM" ~ n ~ "S"] =    [[  1,  4, "%7.3f",        mcdu_large | mcdu_yellow, 7 ]];
            return {
                title: "COM " ~ n,
                pages: [
                    {
                        widgets: widgets,
                        static: [
                            [  1,  1, "ACTIVE",                 mcdu_white ],
                            [  0,  2, up_down_arrow, mcdu_large | mcdu_white ],
                            [  1,  3, "PRESET",                 mcdu_white ],
                            [  0,  4, left_triangle, mcdu_large | mcdu_white ],
                            [  1,  5, "MEM TUNE",               mcdu_white ],
                            [ 16,  1, "SQUELCH",                mcdu_white ],
                            [ 19,  3, "MODE",                   mcdu_white ],
                            [ 19,  5, "FREQ",                   mcdu_white ],
                            [  0, 12, left_triangle, mcdu_large | mcdu_white ],
                            [  1, 12, "MEMORY", mcdu_large | mcdu_white ],
                            [ 14, 12, "RADIO 1/2", mcdu_large | mcdu_white ],
                            [ 23, 12, right_triangle, mcdu_large | mcdu_white ],
                        ],
                        dividers: [],
                        handlers: {
                            "L1": [ "freqswap", ["COM" ~ n] ],
                            "L2": [ "propsel", ["COM" ~ n ~ "S"] ],
                            "R6": [ "ret", [] ],
                        }
                    }
                ]
            };
        },
        "XPDR": func (n) {
            var widgets = {};
            #                         x   y     fmt         flags               w
            widgets["XPDRA"] =    [[  1,  2, "%04s",  mcdu_large |  mcdu_green, 4 ]];
            widgets["XPDRS"] =    [[  1,  4, "%04s",  mcdu_large | mcdu_yellow, 4 ]];
            widgets["PALT"]  =    [[ 18,  2, "%5.0f", mcdu_large |  mcdu_green, 5 ]];
            widgets["FLTID"] =    [[ 17,  4, "%6s",   mcdu_large |  mcdu_green, 6 ]];
            return {
                title: "TCAS/XPDR",
                pages: [
                    {
                        widgets: widgets,
                        static: [
                            [  1,  1, "ACTIVE",                 mcdu_white ],
                            [  0,  2, up_down_arrow,            mcdu_large | mcdu_white ],
                            [  1,  3, "PRESET",                 mcdu_white ],
                            [  0,  4, left_triangle,            mcdu_large | mcdu_white ],
                            [ 11,  1, "PRESSURE ALT",           mcdu_white ],
                            [ 17,  3, "FLT ID",                 mcdu_white ],
                            [ 23,  4, right_triangle,           mcdu_large | mcdu_white ],
                            [ 19,  5, "FREQ",                   mcdu_white ],
                            [  1,  9, "XPDR SEL",               mcdu_large | mcdu_white ],
                            [  1, 10, "XPDR 1",                 mcdu_large | mcdu_green ],
                            [  8, 10, "XPDR 2",                 mcdu_white ],
                            [ 18, 10, "IDENT",                  mcdu_large | mcdu_white ],
                            [ 23, 10, black_square,             mcdu_large | mcdu_white ],
                            [ 14, 12, "RADIO 1/2",              mcdu_large | mcdu_white ],
                            [ 23, 12, right_triangle,           mcdu_large | mcdu_white ],
                        ],
                        dividers: [],
                        handlers: {
                            "L1": [ "freqswap", ["XPDR"] ],
                            "L2": [ "propsel", ["XPDRS"] ],
                            "R2": [ "propsel", ["FLTID"] ],
                            "R5": [ "ident", [] ],
                            "R6": [ "ret", [] ],
                        }
                    },
                    {
                        widgets: {
                            "XPDRMD": [[ 1, 2, xpdrModeLabels, mcdu_large | mcdu_green, 23 ]]
                        },
                        static: [
                            [  1,  1, "TCAS/XPDR MODE",         mcdu_white ],
                            [  0,  2, black_square,             mcdu_large | mcdu_white ],
                            [  1,  4, "ALT RANGE",              mcdu_white ],
                            [ 14, 12, "RADIO 1/2",              mcdu_large | mcdu_white ],
                            [ 23, 12, right_triangle,           mcdu_large | mcdu_white ],
                        ],
                        dividers: [],
                        handlers: {
                            "L1": [ "propcycle", ["XPDRMD"] ],
                            "R6": [ "ret", [] ],
                        }
                    }
                ]
            };
        },
    },

    getNumPages: func () {
        return size(me.mode.pages);
    },

    onPageChanged: func () {
        me.selectedKey = nil;
    },

    drawFreq: func (key) {
        var wprop = widgetProps[key];
        var val = getprop(wprop[0]);
        var ty = propTypes[wprop[1]];
        var widgets = me.mode.pages[me.page].widgets[key];
        if (widgets == nil) { widgets = []; }
        foreach (var widget; widgets) {
            if (widgetProps[key][1] == "DMEH") {
                # some magic needed unfortunately
                if (substr(val, 0, size("/instrumentation/dme")) == "/instrumentation/dme" or val == '') {
                    # assigned to its own freq = DME HOLD
                    val = 1;
                }
                else {
                    # assigned to something other than its own freq
                    val = 0;
                }
            }
            var str = "";
            var f = widget[2];
            if (typeof(f) == "scalar") {
                if (substr(f, 0, 1) == "?") {
                    if (val) {
                        me.mcdu.print(widget[0], widget[1], substr(f, 1), widget[3]);
                    }
                    else {
                        # clear out the space
                        for (var x = 0; x < (size(f) - 1); x += 1) {
                            me.mcdu.print(widget[0] + x, widget[1], " ", 0);
                        }
                    }
                }
                else if (f == "ONOFF") {
                    me.mcdu.print(widget[0], widget[1], "ON", val ? widget[3] : 0);
                    me.mcdu.print(widget[0] + 3, widget[1], "OFF", val ? 0 : widget[3]);
                }
                else if (f == "OFFON") {
                    me.mcdu.print(widget[0], widget[1], "OFF", val ? 0 : widget[3]);
                    me.mcdu.print(widget[0] + 4, widget[1], "ON", val ? widget[3] : 0);
                }
                else if (f == "XPDRON") {
                    var mode = getprop(widgetProps["XPDRMD"][0]);
                    var label = xpdrModeLabels[mode];
                    me.mcdu.print(widget[0], widget[1], "STBY", val ? 0 : widget[3]);
                    me.mcdu.print(widget[0] + 5, widget[1], label, val ? widget[3] : 0);
                }
                else {
                    str = sprintf(f, val);
                    me.mcdu.print(widget[0], widget[1], str, widget[3]);
                }
            }
            else if (typeof(f) == "vector") {
                var min = ty[1] or 0;
                var max = ty[2] or size(f);
                var x = widget[0];
                var y = widget[1];

                for (var v = min; v <= max; v += 1) {
                    var str = f[v];
                    if (x != widget[0] and x + size(str) > cells_x) {
                        x = widget[0];
                        y += 1;
                    }
                    me.mcdu.print(x, y, str, (val == v) ? widget[3] : 0);
                    x += size(str) + 1;
                }
            }
            else {
                print("UNKNOWN FORMAT TYPE: ", typeof(f));
                str = val ~ "";
                me.mcdu.print(widget[0], widget[1], str, widget[3]);
            }
        }
    },

    drawFocusBox: func () {
        if (me.selectedKey == nil) {
            me.mcdu.clearFocusBox();
        }
        else {
            var widget = me.mode.pages[me.page].widgets[me.selectedKey][0];
            if (widget != nil) {
                me.mcdu.setFocusBox(widget[0], widget[1], widget[4]);
            }
        }
    },

    redraw: func () {
        var currentPage = me.mode.pages[me.page];
        foreach (var s; currentPage.static) {
            me.mcdu.print(s[0], s[1], s[2], s[3]);
        }
        foreach (var key; keys(currentPage.widgets)) {
            me.drawFreq(key);
        }
        foreach (var d; currentPage.dividers) {
            me.mcdu.showDivider(d);
        }
        me.drawFocusBox();
    },

    activate: func () {
        var activateFreq = func (k) {
            me.listeners[k] = setlistener(widgetProps[k][0], func (changed) {
                me.drawFreq(k);
            });
        };
        foreach (var page; me.mode.pages) {
            foreach (var key; keys(page.widgets)) {
                activateFreq(key);
            }
        }
    },

    deactivate: func () {
        foreach (var key; keys(me.listeners)) {
            if (me.listeners[key] != nil) {
                removelistener(me.listeners[key]);
                delete(me.listeners, key);
            }
        }
    },

    freqswap: func (keyBase) {
        var prop1 = widgetProps[keyBase ~ "A"][0];
        var prop2 = widgetProps[keyBase ~ "S"][0];
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
            var prop = widgetProps[key][0];
            var ty = propTypes[widgetProps[key][1]];
            if (validate(val, ty)) {
                setprop(prop, val);
            }
            else {
                # TODO: issue error message in scratchpad
            }
        }
    },

    propcycle: func (key) {
        var wprop = widgetProps[key];
        var prop = wprop[0];
        var ty = propTypes[wprop[1]];
        var val = getprop(prop);
        var min = ty[1];
        var max = ty[2];
        val += 1;
        if (min != nil and max != nil and val > max) {
            val = min;
        }
        if (min != nil and val < min) {
            val = min;
        }
        setprop(prop, val);
        me.drawFreq(key);
    },

    propdial: func (digit) {
        if (me.selectedKey == nil) {
            return;
        }
        var prop = widgetProps[me.selectedKey];
        var ps = me.mode.pages[me.page][me.selectedKey];
        var val = getprop(prop[0]);
        var ty = propTypes[prop[1]];

        if (ty[0] == "xpdr") {
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

            val = sprintf("%04o", val);
        }
        else if (ty[0] == "mhz") {
            if (digit == 1) {
                val += 0.01;
            }
            else if (digit == 2) {
                val += 0.1;
            }
            else if (digit == 3) {
                val += 1;
            }
            else if (digit == 4) {
                val += 10;
            }
            else if (digit == -1) {
                val -= 0.01;
            }
            else if (digit == -2) {
                val -= 0.1;
            }
            else if (digit == -3) {
                val -= 1;
            }
            else if (digit == -4) {
                val -= 10;
            }
        }
        else if (ty[0] == "khz") {
            if (digit == 1) {
                val += 0.5;
            }
            else if (digit == 2) {
                val += 1;
            }
            else if (digit == 3) {
                val += 10;
            }
            else if (digit == 4) {
                val += 100;
            }
            else if (digit == -1) {
                val -= 0.5;
            }
            else if (digit == -2) {
                val -= 1;
            }
            else if (digit == -3) {
                val -= 10;
            }
            else if (digit == -4) {
                val -= 100;
            }
        }
        if (ty[1] != nil) { val = math.max(ty[1], val); }
        if (ty[2] != nil) { val = math.min(ty[2], val); }
        setprop(prop[0], val);
        me.drawFreq(me.selectedKey);
    },

    toggle: func (key) {
        var prop = widgetProps[key][0];
        fgcommand("property-toggle", { "property": prop });
        me.drawFreq(key);
    },

    toggledme: func (key, target) {
        var prop = widgetProps[key][0];
        var target = widgetProps[target][0];
        if (getprop(prop) != target) {
            setprop(prop, target);
        }
        else {
            setprop(prop, '');
        }
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
        var c = me.mode.pages[me.page].handlers[cmd];
        if (c == nil) { c = me.defHandlers[cmd]; }
        var funcs = {
            "propdial": me.propdial,
            "freqswap": me.freqswap,
            "propsel": me.propsel,
            "propcycle": me.propcycle,
            "toggle": me.toggle,
            "toggledme": me.toggledme,
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
            g: nil
        };
        m.initCanvas();
        setlistener("/instrumentation/mcdu[" ~ n ~ "]/command", func () {
            m.handleCommand();
        });
        return m;
    },

    makeModule: {
        "RADIO": func (mcdu) { return Module.new(mcdu, "RADIO", 1); },
        "XPDR": func (mcdu) { return Module.new(mcdu, "XPDR", 1); },
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
            me.activeModule = me.makeModule[module](me);
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
        var i = y * cells_x + x;
        if (y < 0 or y >= cells_y) {
            return;
        }
        for (var p = 0; p < size(str); p += 1) {
            var q = 0;
            while (p + q < size(str) and str[p + q] > 127) {
                q += 1;
            }
            var c = substr(str, p, q + 1);
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
});
