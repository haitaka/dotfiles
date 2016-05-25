local awful = require("awful")
local wibox = require("wibox")
local utils = require("utils")

local widgets = {}

-- {{{ Label -- TODO
    widgets.label = 
    {
        bar = wibox.widget.textbox(),
        text = 'lbl',
        color = '#46AEDE',
        font = ''
    }

    function widgets.label:init(config)
        for key, value in pairs(config) 
        do
            self[key] = value
        end
        self.bar:set_markup(string.format(" <span font_desc=%q color=%q>%s</span> ", self.font, self.color, self.text))
    end
    function widgets.label:update()
        self:init({})
    end
-- label}}}

-- {{{ Baclight
    widgets.backlight = 
    {
        bar = wibox.widget.textbox(),
        label = 
        {
            text = {''},
            color = '#46AEDE',
            font = 'haiicons',
        },
        sys_dir = '/sys/class/backlight',
        device = 'acpi_video0',
        cur_file = 'brightness',
        max_file = 'max_brightness',
        max_val = 7,
        step = 1,
        pct_step = 14,
        cur_val = 0,
    }
    function widgets.backlight:init(config)
        for key, value in pairs(config) 
        do
            self[key] = value
        end
        local getmax_cmd = string.format('cat %s/%s/%s', self.sys_dir, self.device, self.max_file)
        self.max_val = tonumber(assert(io.popen(getmax_cmd)):read('*line'))
        self.pct_step = math.ceil(100 / self.max_val) * self.step
        local getcur_cmd = string.format('cat %s/%s/%s', self.sys_dir, self.device, self.cur_file)
        self.cur_val = tonumber(assert(io.popen(getcur_cmd)):read('*line'))
        self:bar_update()
    end
    function widgets.backlight:bar_update()
        local cur_pct = self.cur_val * self.pct_step
        if cur_pct > 100
        then
            cur_pct = 100
        end
        
        local label_id = math.floor (cur_pct / 100 * (#self.label.text)) + 1
        if label_id > #self.label.text then label_id = #self.label.text end
        local cur_pct_str = string.format('%d%%', cur_pct)
        
        markup = utils.format_bar_entry(self.label.text[label_id], cur_pct_str, self.label.color, self.label.font)
        
        self.bar:set_markup(markup)
    end
    function widgets.backlight:inc()
        if self.cur_val < self.max_val
        then
            self.cur_val = self.cur_val + self.step
        end
        local set_cmd = string.format('xbacklight -set %d -steps 1', self.cur_val * self.pct_step)
        assert(io.popen(set_cmd)):read('*line')
        
        self:bar_update()
    end
    function widgets.backlight:dec()
        if self.cur_val > 0
        then
            self.cur_val = self.cur_val - self.step
        end
        local set_cmd = string.format('xbacklight -set %d -steps 1', self.cur_val * self.pct_step)
        assert(io.popen(set_cmd)):read('*line')
        
        self:bar_update()
    end
-- backlight}}}

-- {{{ Battery
    widgets.battery = 
    {
        bar = wibox.widget.textbox(),
        label_font = 'haiicons',
        dischrg_label = 
        {
            text  = {'', '', '', ''},
            color = '#46AEDE',
        },
        chrg_label = 
        {
            text  = {''},
            color = '#94E76B',
        },
        warn_label = 
        {
            text  = {''},
            color = '#EB4509',
        },
        warn_val = 4,
        update_delay = 60,
        sys_dir = '/sys/class/power_supply',
        device = 'BAT0',
        cur_file = 'capacity',
        status_file = 'status',
    }
    function widgets.battery:init(config)
        for key, value in pairs(config) 
        do
            self[key] = value
        end
        self.timer = timer({ timeout = self.update_delay })
        self.timer:connect_signal("timeout", function() self.bar_update(self) end)
        self.timer:start()
        self:bar_update()
    end
    function widgets.battery:bar_update()
        local cap_cmd  = string.format('cat %s/%s/%s', self.sys_dir, self.device, self.cur_file)
        local capacity = tonumber(assert(io.popen(cap_cmd)):read('*line'))
        local capa_str = string.format('%d%%', capacity)
        
        local stat_cmd = string.format('cat %s/%s/%s', self.sys_dir, self.device, self.status_file)
        local status   = assert(io.popen(stat_cmd)):read('*line')
        
        local markup = 'battery widget'

        if status == "Charging" or status == "Full"
        then
            markup = utils.format_bar_entry(self.chrg_label.text[1], capa_str, self.chrg_label.color, self.label_font)
        elseif capacity > self.warn_val
        then
            local label_id = math.floor (capacity / 100 * (#self.dischrg_label.text)) + 1
            if label_id > #self.dischrg_label.text then label_id = #self.dischrg_label.text end
            
            markup = utils.format_bar_entry(self.dischrg_label.text[label_id], capa_str, self.dischrg_label.color, self.label_font)
        else
            markup = utils.format_bar_entry(self.warn_label.text[1], capa_str, self.warn_label.color, self.label_font)
        end
        
        self.bar:set_markup(markup)
    end
-- battery}}}

-- {{{ Keyboard Layout
    widgets.kblayout = 
    {
        bar = wibox.widget.textbox(),
        label = 
        {
            text  = '',
            color = '#46AEDE',
            font = 'haiicons',
        },
        layouts = {'us', 'ru'},
        client_layout = {},
    }
    function widgets.kblayout:init(config)
        for key, value in pairs(config) 
        do
            self[key] = value
        end
        assert(io.popen("setxkbmap -option caps:hyper")) -- map caps to hyper, to use it for KB switch -- maybe it shouldn't be here
        self:bar_update(nil)
    end
    function widgets.kblayout:c_connect(client)
        if not self.client_layout[client] 
        then 
            self.client_layout[client] = self.layouts[1]
        end
    end
    function widgets.kblayout:c_focus(client)
        if client
        then
            self:c_connect(client)
            local cmd = string.format("setxkbmap %s", self.client_layout[client])
            assert(io.popen(cmd))
        else
            local cmd = string.format("setxkbmap %s", self.layouts[1])
            assert(io.popen(cmd))
        end
        self:bar_update(client)
    end
    function widgets.kblayout:change(client)
        self:c_connect(client)
        local cur_layout_id = utils.get_key(self.layouts, self.client_layout[client])
        if cur_layout_id and cur_layout_id <= #self.layouts
        then
            self.client_layout[client] = self.layouts[cur_layout_id + 1]
        else
            self.client_layout[client] = self.layouts[1]
        end
        self:c_focus(client)
    end
    function widgets.kblayout:bar_update(client)
        local layout_str = self.client_layout[client] or 'us'

        local markup = utils.format_bar_entry(self.label.text, layout_str, self.label.color, self.label.font)
        
        self.bar:set_markup(markup)
    end
-- kblayout}}}

-- {{{ Volume
    widgets.volume = 
    {
        bar = wibox.widget.textbox(),
        vol_label = 
        {
            text  = {'', '', ''},
            color = '#46AEDE',
            font = 'haiicons',
        },
        muted_label = 
        {
            text  = {''},
            color = '#EB4509',
            font = 'haiicons',
        },
        channel = 'Master',
        step = 10,
        
        cur_level = 0,
        cur_muted = false,
    }
    function widgets.volume:init(config)
        for key, value in pairs(config) 
        do
            self[key] = value
        end
        self:info_update()
    end
    function widgets.volume:info_update()
        local cmd  = string.format('amixer sget %s', self.channel)
        local info = assert(io.popen(cmd)):read('*all')
        
        self.cur_level = tonumber(string.match(info, "(%d?%d?%d)%%"))
        self.cur_muted = (string.match(info, "%[(o[^%]]*)%]") == 'off')
        
        self:bar_update()
    end
    function widgets.volume:bar_update()
        local markup = 'volume'
        local volume_str = string.format('%d%%', self.cur_level)
        if self.cur_muted or self.cur_level == 0
        then
            markup = utils.format_bar_entry(self.muted_label.text[1], volume_str, self.muted_label.color, self.muted_label.font)
        else
            local label_id = math.floor (self.cur_level / 100 * (#self.vol_label.text)) + 1
            if label_id > #self.vol_label.text then label_id = #self.vol_label.text end
                
            markup = utils.format_bar_entry(self.vol_label.text[label_id], volume_str, self.vol_label.color, self.vol_label.font)
        end
        
        self.bar:set_markup(markup)
    end
    function widgets.volume:inc()
        self.cur_level = self.cur_level + self.step
        if self.cur_level > 100 then self.cur_level = 100 end
        
        self:set_val()
    end
    function widgets.volume:dec()
        self.cur_level = self.cur_level - self.step
        if self.cur_level < 0 then self.cur_level = 0 end
        
        self:set_val()
    end
    function widgets.volume:toggle()
        self.cur_muted = not self.cur_muted
        
        self:set_val()
    end
    function widgets.volume:set_val()
        local status = 'unmute'
        if self.cur_muted then status = 'mute' end
        
        local cmd  = string.format('amixer sset %s %d%% %s', self.channel, self.cur_level, status)
        local info = assert(io.popen(cmd)):read('*all')
        
        self.cur_level = tonumber(string.match(info, "(%d?%d?%d)%%"))
        self.cur_muted = (string.match(info, "%[(o[^%]]*)%]") == 'off') 
        
        self:bar_update()
    end
-- volume}}}

return widgets
