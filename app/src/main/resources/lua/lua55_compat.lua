-- Lua 5.5 对旧脚本的最小兼容层
-- 只补齐旧项目实际使用到的接口，不改变 5.5 的核心语义

local _G = _G

if not _G.loadstring then
  function _G.loadstring(chunk, chunkname, mode, env)
    -- Lua 5.5 的 load 显式收到 nil env 时，代码块会得到空 _ENV；
    -- 旧 loadstring 不传 env 时应当继承全局环境。
    if env ~= nil then
      return load(chunk, chunkname, mode or "bt", env)
    end
    return load(chunk, chunkname, mode or "bt")
  end
end

if not _G.unpack then
  _G.unpack = table.unpack
end

if not math.mod then
  math.mod = math.fmod
end

if not math.pow then
  math.pow = function(x, y) return x ^ y end
end

if not math.log10 then
  math.log10 = function(x) return math.log(x, 10) end
end

if not table.getn then
  table.getn = function(t) return #t end
end

if not table.maxn then
  table.maxn = function(t)
    local max = 0
    for k in pairs(t) do
      if type(k) == "number" and k > max then max = k end
    end
    return max
  end
end

if not string.gfind then
  string.gfind = string.gmatch
end

if not package.seeall then
  function package.seeall(M)
    return setmetatable(M, { __index = _G })
  end
end

if not _G.module then
  function _G.module(name, ...)
    local M = package.loaded[name]
    if type(M) ~= "table" then
      M = {}
      package.loaded[name] = M
    end
    M._NAME = name
    M._M = M
    M._PACKAGE = name:match("(.+)%.") or ""

    local caller = debug.getinfo(2, "f").func
    for i = 1, math.huge do
      local upname = debug.getupvalue(caller, i)
      if not upname then break end
      if upname == "_ENV" then
        debug.setupvalue(caller, i, M)
        break
      end
    end

    for i = 1, select("#", ...) do
      local initializer = select(i, ...)
      if type(initializer) == "function" then
        initializer(M)
      end
    end
    return M
  end
end

if not _G.bit32 then
  local function u32(n)
    return n & 0xFFFFFFFF
  end
  local function fold(op, initial, ...)
    local result = initial
    for i = 1, select("#", ...) do
      result = op(result, u32(select(i, ...)))
    end
    return u32(result)
  end
  local bit32 = {}
  function bit32.band(...) return fold(function(a, b) return a & b end, 0xFFFFFFFF, ...) end
  function bit32.bor(...) return fold(function(a, b) return a | b end, 0, ...) end
  function bit32.bxor(...) return fold(function(a, b) return a ~ b end, 0, ...) end
  function bit32.bnot(n) return u32(~u32(n)) end
  function bit32.btest(...) return bit32.band(...) ~= 0 end
  function bit32.lshift(n, disp) return u32(u32(n) << (disp & 31)) end
  function bit32.rshift(n, disp) return u32(u32(n) >> (disp & 31)) end
  function bit32.arshift(n, disp)
    local value = u32(n)
    if disp >= 32 or disp <= -32 then return 0 end
    if disp >= 0 then
      if value & 0x80000000 ~= 0 then
        return u32((value >> disp) | (0xFFFFFFFF << (32 - disp)))
      end
      return u32(value >> disp)
    end
    return bit32.lshift(value, -disp)
  end
  function bit32.extract(n, field, width)
    width = width or 1
    return u32(u32(n) >> field) & ((1 << width) - 1)
  end
  function bit32.replace(n, value, field, width)
    width = width or 1
    local mask = ((1 << width) - 1) << field
    return u32((u32(n) & ~mask) | ((u32(value) << field) & mask))
  end
  _G.bit32 = bit32
end
