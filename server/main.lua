local fw = exports[Config.FrameworkResource]

local function dbg(src, msg)
  if not Config.DebugJobChecks then return end
  print(("[az_moneytruck][debug][%s] %s"):format(tostring(src), tostring(msg)))
end

local function getJob(src)
  local ok, j = pcall(Config.GetPlayerJob, src)
  if ok and j then return tostring(j) end
  return "civ"
end

local function ensureJob(src)
  local job = getJob(src)
  if job ~= Config.JobName then
    dbg(src, ("DENY: expected=%s got=%s"):format(Config.JobName, job))
    return false, job
  end
  return true, job
end

local function payCash(src, amount)
  amount = math.floor(tonumber(amount) or 0)
  if amount <= 0 then return end
  fw:addMoney(src, amount)
end

local function takeCash(src, amount, cb)
  amount = math.floor(tonumber(amount) or 0)
  if amount <= 0 then return cb and cb(true) end
  fw:GetPlayerMoney(src, function(err, wallet)
    if err then return cb and cb(false, "wallet_error") end
    wallet = wallet or {}
    local cash = tonumber(wallet.cash or 0) or 0
    if cash < amount then return cb and cb(false, "not_enough_cash") end
    fw:deductMoney(src, amount)
    cb(true)
  end)
end

-- /quitjob (resign) support:
-- 1) tries framework setter if available
-- 2) falls back to DB update using oxmysql or MySQL wrapper
local function getCharId(src)
  if not Config.UseAzFrameworkCharacter then return nil end
  local ok, c = pcall(function() return exports[Config.FrameworkResource]:GetPlayerCharacter(src) end)
  if ok and c then return c end
  return nil
end

local function dbUpdateJob(charId, newJob, cb)
  local t = Config.DB and Config.DB.table or 'user_characters'
  local idc = Config.DB and Config.DB.identifierColumn or 'charid'
  local jc = Config.DB and Config.DB.jobColumn or 'active_department'
  local q = ("UPDATE %s SET %s = ? WHERE %s = ?"):format(t, jc, idc)

  if exports.oxmysql and exports.oxmysql.update then
    exports.oxmysql:update(q, { newJob, charId }, function(affected)
      cb(true, affected or 0)
    end)
    return
  end

  if MySQL and MySQL.update then
    MySQL.update(q, { newJob, charId }, function(affected)
      cb(true, affected or 0)
    end)
    return
  end

  cb(false, "no_mysql")
end

local function setJob(src, newJob, cb)
  newJob = tostring(newJob or "unemployed")
  local ok, hasSetter = pcall(function()
    return type(exports[Config.FrameworkResource].setPlayerJob) == "function"
  end)
  if ok and hasSetter then
    local ok2, err = pcall(function()
      exports[Config.FrameworkResource]:setPlayerJob(src, newJob)
    end)
    if ok2 then
      cb(true, "framework")
    else
      cb(false, err or "setter_failed")
    end
    return
  end

  local charId = getCharId(src)
  if not charId then
    cb(false, "no_char")
    return
  end

  dbUpdateJob(charId, newJob, function(ok3, info)
    if ok3 then
      cb(true, "db")
      if exports[Config.FrameworkResource].sendMoneyToClient then
        pcall(function() exports[Config.FrameworkResource]:sendMoneyToClient(src) end)
      end
    else
      cb(false, info)
    end
  end)
end

_G['AZ_MONEYTRUCK_SV'] = _G['AZ_MONEYTRUCK_SV'] or {}
local SV = _G['AZ_MONEYTRUCK_SV']
SV.dbg = dbg
SV.getJob = getJob
SV.ensureJob = ensureJob
SV.payCash = payCash
SV.takeCash = takeCash
SV.setJob = setJob

RegisterCommand('az_moneytruckdebug', function(source)
  local src = source
  if src == 0 then
    print("[az_moneytruck] use this in-game")
    return
  end
  local j = getJob(src)
  dbg(src, ("job=%s"):format(j))
  TriggerClientEvent('az_moneytruck:notify', src, ("[az_moneytruck] job=%s (see server console)"):format(j))
end, false)

RegisterCommand('quitjob', function(source)
  local src = source
  if src == 0 then return end
  setJob(src, "unemployed", function(ok4, how)
    if ok4 then
      dbg(src, "quitjob OK via " .. tostring(how))
      TriggerClientEvent('az_moneytruck:notify', src, "You quit your job. (unemployed)")
    else
      dbg(src, "quitjob FAIL: " .. tostring(how))
      TriggerClientEvent('az_moneytruck:notify', src, "Could not quit job (missing setter/DB). Use Job Center.")
    end
  end)
end, false)

local active = {} -- src -> true

RegisterNetEvent('az_moneytruck:requestStart', function()
  local src = source
  local ok = _G['AZ_MONEYTRUCK_SV'].ensureJob(src)
  if not ok then
    TriggerClientEvent('az_moneytruck:notify', src, "You are not employed for Money Transport.")
    TriggerClientEvent('az_moneytruck:startDenied', src)
    return
  end
  active[src] = true
  TriggerClientEvent('az_moneytruck:startOk', src)
end)

RegisterNetEvent('az_moneytruck:pos', function(x,y,z)
  local src = source
  if not active[src] then return end
  TriggerClientEvent('az_moneytruck:blip', -1, src, x,y,z)
end)

RegisterNetEvent('az_moneytruck:stopComplete', function()
  local src = source
  if not active[src] then return end
  local ok = _G['AZ_MONEYTRUCK_SV'].ensureJob(src)
  if not ok then return end
  exports[Config.FrameworkResource]:addMoney(src, Config.PayPerStop or 450)
end)

RegisterNetEvent('az_moneytruck:finish', function()
  local src = source
  active[src] = nil
  TriggerClientEvent('az_moneytruck:blipRemove', -1, src)
end)

AddEventHandler('playerDropped', function()
  local src = source
  if active[src] then
    active[src] = nil
    TriggerClientEvent('az_moneytruck:blipRemove', -1, src)
  end
end)
