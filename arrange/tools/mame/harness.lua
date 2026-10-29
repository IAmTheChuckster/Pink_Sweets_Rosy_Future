-- Pink Sweets control-test harness (MAME 0.264 autoboot script)
-- Env vars:
--   PS_MODE   boot | run
--   PS_STATE  state name to save (boot) / load (run)
--   PS_SCHED  schedule file: lines "<frame> <tokens>" (tokens from U D L R A B, '-' = nothing),
--             held from that frame until the next line. '#' comments allowed.
--   PS_FRAMES number of frames to run after the state is loaded
--   PS_OUT    output prefix (writes <out>.bin per-frame dumps, <out>.log)
--   PS_DUMP   ranges to dump every frame: "addr:len,addr:len" (hex)
--   PS_SNAP   comma list of frames to snapshot
--   PS_INVULN 1 = hold P1 invulnerability counter at 120

local P1 = 0x0C49C5DC
local mode = os.getenv("PS_MODE") or "run"
local statename = os.getenv("PS_STATE") or "ingame"
local outp = os.getenv("PS_OUT") or "out"
local nframes = tonumber(os.getenv("PS_FRAMES") or "300")
local invuln = os.getenv("PS_INVULN") == "1"

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]

-- input fields by port/mask
local function field(port, mask)
  for _, f in pairs(manager.machine.ioport.ports[port].fields) do
    if f.mask == mask then return f end
  end
  error("no field " .. port .. " " .. mask)
end
local F = {
  U = field(":PORT_D", 0x01), D = field(":PORT_D", 0x02),
  L = field(":PORT_D", 0x04), R = field(":PORT_D", 0x08),
  A = field(":PORT_D", 0x10), B = field(":PORT_D", 0x20),
  K = field(":PORT_C", 0x04), S = field(":PORT_C", 0x10),
  C = field(":PORT_D", 0x40), T = field(":PORT_C", 0x20),
  X = field(":DSW", 0x01), Q = field(":PORT_D", 0x80),
}
local function setinputs(tok)
  for k, f in pairs(F) do
    f:set_value(tok:find(k, 1, true) and 1 or 0)
  end
end

local function parse_list(s)
  local t = {}
  for v in (s or ""):gmatch("[^,]+") do t[#t + 1] = v end
  return t
end

local logf = io.open(outp .. ".log", "w")
local function log(...) logf:write(string.format(...) .. "\n"); logf:flush() end

local frame = 0

if mode == "boot" then
  -- PS_BOOTSCHED: "frame tokens" lines like run mode, absolute frames from power-on
  local bs = {}
  for line in io.lines(os.getenv("PS_BOOTSCHED")) do
    line = line:gsub("#.*", "")
    local f, tok = line:match("^%s*(%d+)%s+(%S+)")
    if f then bs[#bs + 1] = { tonumber(f), tok } end
  end
  local saveat = tonumber(os.getenv("PS_SAVEAT") or "0")
  local snapevery = tonumber(os.getenv("PS_SNAPEVERY") or "0")
  emu.register_frame_done(function()
    frame = frame + 1
    local tok = "-"
    for _, e in ipairs(bs) do if e[1] <= frame then tok = e[2] end end
    setinputs(tok)
    if os.getenv("PS_BPCMD") and frame == tonumber(os.getenv("PS_FLAGAT")) then
      manager.machine.debugger:command(os.getenv("PS_BPCMD")); manager.machine.debugger:command("go")
    end
    if os.getenv("PS_BOOTDUMP") then
      if not bootbin then bootbin = io.open(outp .. ".bin", "wb") end
      local held = 0
      for i, k in ipairs({ "U", "D", "L", "R", "A", "B", "C" }) do
        if tok:find(k, 1, true) then held = held | (1 << (i - 1)) end
      end
      bootbin:write(string.pack(">I4", frame), string.pack("c1", tok:sub(1, 1)), string.pack("B", held))
      bootbin:write(mem:read_range(P1, P1 + 0x2B7, 8))
      bootbin:flush()
    end
    if os.getenv("PS_BMEM") and frame % 10 == 0 then
      local t = {}
      for _, r in ipairs(parse_list(os.getenv("PS_BMEM"))) do
        local ad, ln = r:match("(%x+):(%x+)")
        local s2 = {}
        for i = 0, tonumber(ln, 16) - 1 do s2[#s2 + 1] = string.format("%02x", mem:read_u8(tonumber(ad, 16) + i)) end
        t[#t + 1] = table.concat(s2)
      end
      log("bmem f=%d %s", frame, table.concat(t, " "))
    end
    for _, f in ipairs(parse_list(os.getenv("PS_RAMAT"))) do
      if tonumber(f) == frame then
        local fh = io.open(outp .. "_" .. f .. ".ram", "wb")
        fh:write(mem:read_range(0x0C3A0000, 0x0C7FFFFF, 8)); fh:close()
      end
    end
    if snapevery > 0 and frame % snapevery == 0 and frame >= tonumber(os.getenv("PS_SNAPFROM") or "0") then
      manager.machine.video:snapshot()
      log("snap f=%d st=%04x", frame, mem:read_u16(P1))
    end
    if saveat > 0 and frame == saveat then manager.machine:save(statename); log("saved %d", frame) end
    if frame == (saveat > 0 and saveat + 5 or tonumber(os.getenv("PS_FRAMES") or "3000")) then manager.machine:exit() end
  end)
  return
end

-- run mode
local sched = {}
for line in io.lines(os.getenv("PS_SCHED")) do
  line = line:gsub("#.*", "")
  local f, tok = line:match("^%s*(%d+)%s+(%S+)")
  if f then sched[#sched + 1] = { tonumber(f), tok } end
end
local ranges = {}
for _, r in ipairs(parse_list(os.getenv("PS_DUMP"))) do
  local a, l = r:match("(%x+):(%x+)")
  ranges[#ranges + 1] = { tonumber(a, 16), tonumber(l, 16) }
end
local snaps = {}
for _, v in ipairs(parse_list(os.getenv("PS_SNAP"))) do snaps[tonumber(v)] = true end

local binf = io.open(outp .. ".bin", "wb")
-- PS_TAP: "start-end:r|w,..." hex ranges; logs unique PC/addr pairs after load
local taps = {}
local tapcount = {}
local tapon = false
local function install_taps()
for _, spec in ipairs(parse_list(os.getenv("PS_TAP"))) do
  local a, b, kind = spec:match("(%x+)%-(%x+):(%a)")
  a = tonumber(a, 16); b = tonumber(b, 16)
  local cb = function(offset, data, mask)
    if tapon then
      local pc = cpu.state["PC"].value
      local key = string.format("%s pc=%08x addr=%08x mask=%016x", kind, pc, offset, mask)
      if os.getenv("PS_TAPFRAME") then key = string.format("t=%05d ", t) .. key end
      tapcount[key] = (tapcount[key] or 0) + 1
    end
  end
  if kind == "r" then taps[#taps + 1] = mem:install_read_tap(a, b, "t" .. #taps, cb)
  else taps[#taps + 1] = mem:install_write_tap(a, b, "t" .. #taps, cb) end
end

end
local sprcnt, sprlog = 0, nil
local spraddr = tonumber(os.getenv("PS_SPRCNT") or "0", 16)
local loaded = false
local t = -1 -- frames since load

emu.register_frame_done(function()
  frame = frame + 1
  if not loaded then
    if frame == 2 then manager.machine:load(statename) end
    if frame == 4 then loaded = true; t = 0; install_taps(); tapon = true end
    return
  end
  -- current schedule entry
  local tok = "-"
  for _, e in ipairs(sched) do if e[1] <= t then tok = e[2] end end
  if invuln then mem:write_u8(P1 + 0x28F, 120) end
  for _, f in ipairs(parse_list(os.getenv("PS_RUNRAM"))) do
    if tonumber(f) == t then
      local fh = io.open(outp .. "_" .. f .. ".ram", "wb")
      fh:write(mem:read_range(0x0C3A0000, 0x0C7FFFFF, 8)); fh:close()
    end
  end
  if os.getenv("PS_BLITLOG") then
    if not blitlog then
      blitlog = io.open(outp .. "_blit.txt", "w")
      blitaddrs = {}
      blittap = mem:install_write_tap(0x18000000, 0x1800000F, "blittap", function(o, d, m)
        if (m & 0xFFFFFFFF) ~= 0 and (o & 15) == 8 then blitaddrs[#blitaddrs + 1] = d & 0xFFFFFFFF end
        if (m >> 32) ~= 0 and (o & 15) == 8 then blitaddrs[#blitaddrs + 1] = d >> 32 end
      end)
    end
    -- parse every list started during the last frame
    local n, area, blend, cnt = 0, 0, 0, 0
    blitaddrs = { mem:read_u32(0x0C5C02A0) }
    for _, la in ipairs(blitaddrs) do
      local a = (la & 0x1FFFFFFF) | 0x0C000000
      for i = 1, 4000 do
        local w = mem:read_u16(a)
        local c = w >> 12
        if c == 0 then break
        elseif c == 1 then
          local ww = (mem:read_u16(a + 12) & 0x1FFF) + 1
          local hh = (mem:read_u16(a + 14) & 0x1FFF) + 1
          area = area + ww * hh; cnt = cnt + 1
          if (w & 0x00FF) ~= 0 then blend = blend + ww * hh end
          a = a + 20
        elseif c == 2 then
          local ww = (mem:read_u16(a + 12) & 0x1FFF) + 1
          local hh = (mem:read_u16(a + 14) & 0x1FFF) + 1
          a = a + 16 + ((ww * hh * 2 + 3) & ~3)
        elseif c == 0xC then a = a + 4
        else a = a + 2 end
      end
      n = n + 1
    end
    blitlog:write(string.format("%d %d %d %d\n", n, cnt, area, blend)); blitlog:flush()
    blitaddrs = {}
  end
  if spraddr ~= 0 then
    if not sprlog then
      sprlog = io.open(outp .. "_spr.txt", "w")
      sprtap = mem:install_read_tap(spraddr, spraddr + 7, "sprtap", function(o, d, m) sprcnt = sprcnt + 1 end)
    end
    sprlog:write(sprcnt, "\n"); sprlog:flush(); sprcnt = 0
  end
  for _, p in ipairs(parse_list(os.getenv("PS_SETL"))) do
    local f, a, v = p:match("(%d+):(%x+)=(%x+)")
    if tonumber(f) == t then mem:write_u32(tonumber(a, 16), tonumber(v, 16)) end
  end
  for _, p in ipairs(parse_list(os.getenv("PS_SETAT"))) do
    local f, a, v = p:match("(%d+):(%x+)=(%x+)")
    if tonumber(f) == t then mem:write_u8(tonumber(a, 16), tonumber(v, 16)) end
  end
  for _, p in ipairs(parse_list(os.getenv("PS_HOLDB"))) do
    local a, v = p:match("(%x+)=(%x+)")
    mem:write_u8(tonumber(a, 16), tonumber(v, 16))
  end
  for _, spec in ipairs(parse_list(os.getenv("PS_BLANK"))) do
    local row, c0, c1 = spec:match("(%d+):(%d+)%-(%d+)")
    row = tonumber(row)
    for c = tonumber(c0), tonumber(c1) do mem:write_u32(0x0C3AF5FC + row * 0x80 + c * 4, 0) end
    mem:write_u8(0x0C453604 + row, 1)
  end
  if magslot and t == magt + 3 and os.getenv("PS_POPUP") then
    -- lift the pop-up away from the ship so it can be seen
    local o = 0x0C5B68EC + 108 * magslot
    mem:write_u32(o + 44, mem:read_u32(P1 + 0x18) + (tonumber(os.getenv("PS_POPUP")) << 16))
  end
  if os.getenv("PS_DATATAP") then
    local fa = tonumber(os.getenv("PS_FLAGAT"))
    local want = tonumber(os.getenv("PS_DATATAP"), 16)
    if t == fa then
      dtap = mem:install_write_tap(0x0C000000, 0x0C7FFFFF, "dtap", function(offset, data, mask)
        for sh = 0, 48, 16 do
          if ((mask >> sh) & 0xFFFF) == 0xFFFF and ((data >> sh) & 0xFFFF) == want then
            local sp = cpu.state["R15"].value; local st = {}; for k = 0, 47 do local v = mem:read_u32(sp + k*4); if v >= 0x0C050000 and v < 0x0C110000 then st[#st+1] = string.format("%d:%08x", k, v) end end; local key = string.format("D pc=%08x pr=%08x r7=%08x stack=%s", cpu.state["PC"].value, cpu.state["PR"].value, cpu.state["R7"].value, table.concat(st, ","))
            tapcount[key] = (tapcount[key] or 0) + 1
          end
        end
      end)
    elseif t == fa + tonumber(os.getenv("PS_DTWIN") or "3") and dtap then dtap:remove(); dtap = nil end
  end
  if os.getenv("PS_TRACEAT") then
    local ta = tonumber(os.getenv("PS_TRACEAT"))
    if t == ta then manager.machine.debugger:command("trace " .. outp .. "_tr.log,maincpu,noloop"); manager.machine.debugger:command("go") end
    if t == ta + tonumber(os.getenv("PS_TRACEN") or "1") then manager.machine.debugger:command("trace off"); manager.machine.debugger:command("go") end
  end
  if os.getenv("PS_BPCMD") and t == tonumber(os.getenv("PS_FLAGAT")) then
    local dbg = manager.machine.debugger
    if dbg then
      dbg:command(os.getenv("PS_BPCMD")); dbg:command("go"); log("bp set")
    else log("no debugger") end
  end
  if os.getenv("PS_BPCMD") and t == tonumber(os.getenv("PS_FLAGAT")) + tonumber(os.getenv("PS_BPWIN") or "1") then
    manager.machine.debugger:command("bpclear"); manager.machine.debugger:command("go")
  end
  if os.getenv("PS_FLAGAT") then
    local fa = tonumber(os.getenv("PS_FLAGAT"))
    if t == fa then mem:write_u8(0x0C7E0300, 1) elseif t == fa + 1 then mem:write_u8(0x0C7E0300, 0) end
  end
  if os.getenv("PS_MAGNET") and t % tonumber(os.getenv("PS_MAGNET")) == 0 then
    -- pull one marked cracker flower (item +104 == 0xC9) onto the ship
    for sl = 0, 355 do
      local o = 0x0C5B68EC + 108 * sl
      if mem:read_u8(o + 104) == 0xC9 and mem:read_u32(o + 4) == 2 and (mem:read_u32(o) & 0x80000000) ~= 0 then
        mem:write_u32(o + 44, mem:read_u32(P1 + 0x18)); mem:write_u32(o + 48, mem:read_u32(P1 + 0x1C))
        log("magnet t=%d slot %d", t, sl)
        magslot = sl; magt = t
        break
      end
    end
  end
  if t == 0 and os.getenv("PS_GIVEHIPS") then
    for slot = 0, 1 do
      local e = 0x0C453630 + slot * 60
      mem:write_u32(e, 0xC4000004)
      mem:write_u32(e + 4, mem:read_u32(P1 + 8) >> 2)
      mem:write_u32(e + 8, 0); mem:write_u32(e + 12, 0)
      mem:write_u32(e + 20, mem:read_u32(P1 + 24)); mem:write_u32(e + 24, mem:read_u32(P1 + 28))
      mem:write_u32(e + 28, 0); mem:write_u32(e + 32, 0)
      mem:write_u32(e + 36, 0x808080); mem:write_u16(e + 40, 0); mem:write_u16(e + 42, 0)
      mem:write_u32(e + 44, 0); mem:write_u8(e + 54, 0); mem:write_u8(e + 56, 0); mem:write_u8(e + 57, slot)
    end
    mem:write_u8(P1 + 0x290, 2)
    mem:write_u32(P1 + 4, mem:read_u32(P1 + 4) | 0x08000000)
    mem:write_u8(P1 + 0x28B, 0)
    log("gave hips")
  end
  if os.getenv("PS_RETYPE") and t == tonumber(os.getenv("PS_ITEMNEAR")) then
    local sl, ty, kd = os.getenv("PS_RETYPE"):match("(%d+):(%d+):(%d+)")
    local o = 0x0C5B68EC + 108 * tonumber(sl)
    ty = tonumber(ty); kd = tonumber(kd)
    mem:write_u32(o + 4, ty); mem:write_u32(o + 8, kd); mem:write_u32(o + 12, 0)
    local desc = 0x0C1087F4 + ty * 0x20
    mem:write_u32(o + 36, mem:read_u32(desc + 8))
    local tbl = mem:read_u32(desc + 4)
    mem:write_u32(o + 16, tbl)
    local fr = mem:read_u32(tbl + kd * 16)
    mem:write_u32(o + 20, fr)
    mem:write_u32(o + 24, mem:read_u32(fr)); mem:write_u32(o + 28, mem:read_u32(fr + 4)); mem:write_u32(o + 32, mem:read_u32(fr))
    log("retype slot %s -> type %d kind %d frames %08x", sl, ty, kd, fr)
  end
  if os.getenv("PS_ITEMNEAR") and t >= tonumber(os.getenv("PS_ITEMNEAR")) and t < tonumber(os.getenv("PS_ITEMNEAR")) + 2 then
    local slot = 0x0C5B68EC + 108 * tonumber(os.getenv("PS_ITEMSLOT") or "0")
    if os.getenv("PS_ITEMXY") then
      local ix, iy = os.getenv("PS_ITEMXY"):match("(%d+),(%d+)")
      mem:write_u32(slot + 44, tonumber(iy) << 16); mem:write_u32(slot + 48, tonumber(ix) << 16)
    else
      mem:write_u32(slot + 44, mem:read_u32(P1 + 0x18) + (tonumber(os.getenv("PS_ITEMDY") or "80") << 16))
      mem:write_u32(slot + 48, mem:read_u32(P1 + 0x1C))
    end
  end
  if t == 0 then
    for _, p in ipairs(parse_list(os.getenv("PS_POKEW"))) do
      local a, v = p:match("(%x+)=(%x+)")
      mem:write_u16(tonumber(a, 16), tonumber(v, 16)); log("pokew %s=%s", a, v)
    end
  end
  if t == 0 then
    for _, p in ipairs(parse_list(os.getenv("PS_POKE"))) do
      local o, v = p:match("(%x+)=(%x+)")
      mem:write_u8(P1 + tonumber(o, 16), tonumber(v, 16)); log("poke +%s=%s", o, v)
    end
  end
  -- dump state as of end of this frame (inputs for frame t+1 are set below)
  binf:write(string.pack(">I4", t))
  binf:write(string.pack("c1", tok:sub(1, 1)))
  local held = 0
  for i, k in ipairs({ "U", "D", "L", "R", "A", "B", "C" }) do
    if tok:find(k, 1, true) then held = held | (1 << (i - 1)) end
  end
  binf:write(string.pack("B", held))
  for _, r in ipairs(ranges) do binf:write(mem:read_range(r[1], r[1] + r[2] - 1, 8)) end
  if snaps[t] then manager.machine.video:snapshot(); log("snap %d", t) end
  if os.getenv("PS_RSAVE") and t == tonumber(os.getenv("PS_RSAVE")) then manager.machine:save(os.getenv("PS_RSAVENAME") or "rsave"); log("rsaved %d", t) end
  if os.getenv("PS_BLITAT") then
    local b = tonumber(os.getenv("PS_BLITAT"))
    if t == b then local f = io.open("/root/run/blitlog.flag", "wb"); f:write("1"); f:close() end
    if t == b + 1 then os.remove("/root/run/blitlog.flag") end
  end
  if os.getenv("PS_VRAMAT") and t == tonumber(os.getenv("PS_VRAMAT")) then
    local f = io.open("/root/run/vramdump.flag", "wb"); f:write("1"); f:close(); log("vram flag %d", t)
  end
  for _, f in ipairs(parse_list(os.getenv("PS_RAMAT"))) do
    if tonumber(f) == t then
      local fh = io.open(outp .. "_" .. f .. ".ram", "wb")
      fh:write(mem:read_range(0x0C3A0000, 0x0C7FFFFF, 8)); fh:close()
    end
  end
  if os.getenv("PS_RUNSAVE") and t == tonumber(os.getenv("PS_RUNSAVEAT")) then manager.machine:save(os.getenv("PS_RUNSAVE")); log("saved %s at %d", os.getenv("PS_RUNSAVE"), t) end
  setinputs(tok)
  local hipsave = os.getenv("PS_HIPSAVE")
  if hipsave and not hipdone and mem:read_u8(P1 + 0x290) > 0 then
    hipdone = true; hipat = t; log("hip pickup at %d", t)
  end
  if hipdone and t == hipat + 30 then manager.machine:save(hipsave); log("saved %s at %d", hipsave, t) end
  t = t + 1
  if t > nframes then
    binf:close()
    local keys = {}
    for k, _ in pairs(tapcount) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do log("%s n=%d", k, tapcount[k]) end
    log("done"); manager.machine:exit() end
end)
