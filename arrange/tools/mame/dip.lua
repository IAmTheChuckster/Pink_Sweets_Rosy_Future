local function field(port, mask)
  for _, f in pairs(manager.machine.ioport.ports[port].fields) do if f.mask == mask then return f end end
  error("nofield")
end
local F = { U=field(":PORT_D",0x01), D=field(":PORT_D",0x02), L=field(":PORT_D",0x04), R=field(":PORT_D",0x08),
  A=field(":PORT_D",0x10), B=field(":PORT_D",0x20), X=field(":DSW",0x01), S=field(":PORT_C",0x10), K=field(":PORT_C",0x04) }
local sched = {}
for line in io.lines(os.getenv("SCHED")) do
  line=line:gsub("#.*","")
  local f,t=line:match("^%s*(%d+)%s+(%S+)")
  if f then sched[#sched+1]={tonumber(f),t} end
end
local snaps = {}
for v in (os.getenv("SNAPS") or ""):gmatch("%d+") do snaps[tonumber(v)] = true end
local n=0
emu.register_frame_done(function()
  n=n+1
  local tok="-"
  for _,e in ipairs(sched) do if e[1]<=n then tok=e[2] end end
  for k,f in pairs(F) do if k~="X" or os.getenv("USEX") then f:set_value(tok:find(k,1,true) and 1 or 0) end end
  if snaps[n] then manager.machine.video:snapshot() end
end)
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local lf = io.open("/tmp/memlog.txt","w")
local k=0
emu.register_frame_done(function()
  k=k+1
  if k>=1400 and k%40==0 and k<3600 then
    lf:write(string.format("%d eff=%02x flag=%02x arrx=%02x ext1=%08x ext2=%08x dipext=%02x real=%02x\n",k,mem:read_u8(0x0C7E01FC),mem:read_u8(0x0C7E0003),mem:read_u8(0x0C3AE487),mem:read_u32(0x0C5C009C),mem:read_u32(0x0C4AFAF0),mem:read_u8(0x0C3B0A7C),mem:read_u8(0x0C4535F7))); lf:flush()
  end
end)
