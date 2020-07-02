# Embraer E-Jet family MCDU.

mcdu_colors = [
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

var Module = {
    init: func (mcdu) {
        me.mcdu = mcdu;
        me.page = 0;
        me.active = 0;
        me.title = "GENERIC";
    },

    getNumPages: func () { return 1; },

    drawPager: func () {
        me.mcdu.print(21, 0, sprintf("%1d/%1d", me.page + 1, me.getNumPages()), 0);
    },

    drawTitle: func () {
        var x = math.floor((cells_x - 3 - size(me.title)) / 2);
        me.mcdu.print(x, 0, me.title, 0x10);
    },

    fullRedraw: func () {
        me.mcdu.clear();
        me.drawTitle();
        me.drawPager();
        me.redraw();
    },

    redraw: func () {
    },

    handleCommand: func (cmd) {
    },

    nextPage: func () {
        if (me.page < me.getNumPages() - 1) {
            me.page += 1;
            me.drawPager();
            me.redraw();
        }
    },

    prevPage: func () {
        if (me.page > 0) {
            me.page -= 1;
            me.drawPager();
            me.redraw();
        }
    },

    activate: func () {
    },

    deactivate: func () {
    }
};

var radioProps = {
    "NAV1A": "/instrumentation/nav[0]/frequencies/selected-mhz",
    "NAV1S": "/instrumentation/nav[0]/frequencies/standby-mhz",
    "NAV2A": "/instrumentation/nav[1]/frequencies/selected-mhz",
    "NAV2S": "/instrumentation/nav[1]/frequencies/standby-mhz",
    "COM1A": "/instrumentation/comm[0]/frequencies/selected-mhz",
    "COM1S": "/instrumentation/comm[0]/frequencies/standby-mhz",
    "COM2A": "/instrumentation/comm[1]/frequencies/selected-mhz",
    "COM2S": "/instrumentation/comm[1]/frequencies/standby-mhz",
};

var radioPos = {
    "COM1A": [  1, 2, "%7.3f", 0x10 | mcdu_green ],
    "COM1S": [  1, 4, "%7.3f", 0x10 | mcdu_yellow ],
    "COM2A": [ 16, 2, "%7.3f", 0x10 | mcdu_green ],
    "COM2S": [ 16, 4, "%7.3f", 0x10 | mcdu_yellow ],
    "NAV1A": [  1, 6, "%7.3f", 0x10 | mcdu_green ],
    "NAV1S": [  1, 8, "%7.3f", 0x10 | mcdu_yellow ],
    "NAV2A": [ 16, 6, "%7.3f", 0x10 | mcdu_green ],
    "NAV2S": [ 16, 8, "%7.3f", 0x10 | mcdu_yellow ],
};

var RadioModule = {
    keysPage1: [
        "COM1A", "COM1S",
        "COM2A", "COM2S",
        "NAV1A", "NAV1S",
        "NAV2A", "NAV2S",
    ],

    new: func (mcdu) {
        var m = { parents: [RadioModule, Module] };
        m.init(mcdu);
        m.title = "RADIO";
        m.listeners = {};
        return m;
    },

    getNumPages: func () {
        return 2;
    },

    drawFreq: func (key) {
        var val = getprop(radioProps[key]);
        var pos = radioPos[key];
        me.mcdu.print(pos[0], pos[1], sprintf(pos[2], val), pos[3]);
    },

    redraw: func () {
        if (me.page == 0) {
            me.mcdu.print( 1, 1, "COM1", mcdu_white);
            me.mcdu.print( 0, 4, left_triangle, mcdu_white);
            me.mcdu.print(19, 1, "COM2", mcdu_white);
            me.mcdu.print(23, 4, right_triangle, mcdu_white);
            me.mcdu.print( 1, 5, "NAV1", mcdu_white);
            me.mcdu.print( 0, 8, left_triangle, mcdu_white);
            me.mcdu.print(19, 5, "NAV2", mcdu_white);
            me.mcdu.print(23, 8, right_triangle, mcdu_white);
            foreach (var key; RadioModule.keysPage1) {
                me.drawFreq(key);
            }
        }
        else if (me.page == 1) {
        }
    },

    activate: func () {
        foreach (var key; keys(radioProps)) {
            me.listeners[key] = setlistener(radioProps[key], func () {
                me.drawFreq(key);
            });
        }
    },

    deactivate: func () {
        foreach (var key; keys(radioProps)) {
            if (me.listeners[key] != nil) {
                removelistener(me.listeners[key]);
                delete(me.listeners, key);
            }
        }
    },

    handleCommand: func (cmd) {
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
            screenbuf: [],
            screenbufElems: [],
            modules: {},
            activeModule: nil,
            g: nil
        };
        m.initCanvas();
        m.modules["RADIO"] = RadioModule.new(m);
        setlistener("/instrumentation/mcdu[" ~ n ~ "]/command", func () {
            m.handleCommand();
        });
        return m;
    },

    activateModule: func (moduleName) {
        if (me.activeModule != nil) {
            me.activeModule.deactivate();
        }
        me.activeModule = me.modules[moduleName];
        if (me.activeModule != nil) {
            me.activeModule.activate();
            me.activeModule.fullRedraw();
        }
        else {
            me.clear();
        }
    },

    handleCommand: func () {
        var cmd = me.commandprop.getValue();
        print("MCDU" ~ me.num ~ ": ", cmd);
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
            me.scratchpad = "";
            me.scratchpadElem.setText(me.scratchpad);
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
        print("Init canvas...");
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
                elem.setTranslation(x * cell_w + margin_left, y * cell_h + margin_top + cell_h);
                append(me.screenbuf, [" ", 0]);
                append(me.screenbufElems, elem);
                i += 1;
            }
        }

        me.repaintScreen();

        me.scratchpadElem = me.g.createChild("text", "scratchpad");
        me.scratchpadElem.setText("----");
        me.scratchpadElem.setFontSize(font_size_large);
        me.scratchpadElem.setFont("LiberationFonts/LiberationMono-Regular.ttf");
        me.scratchpadElem.setColor(1,1,1);
        me.scratchpadElem.setTranslation(margin_left, (cells_y + 1) * cell_h + margin_top);
    },

    clear: func () {
        var i = 0;
        for (i = 0; i < num_cells; i += 1) {
            me.screenbuf[i] = [" ", 0];
            me.repaintCell(i);
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
        var largeSize = flags & 0x10;
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
