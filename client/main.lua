function az_moneytruck_notify(msg)
  BeginTextCommandThefeedPost("STRING")
  AddTextComponentSubstringPlayerName(tostring(msg))
  EndTextCommandThefeedPostTicker(false, false)
end

function az_moneytruck_help(msg)
  BeginTextCommandDisplayHelp("STRING")
  AddTextComponentSubstringPlayerName(tostring(msg))
  EndTextCommandDisplayHelp(0, false, true, -1)
end

function az_moneytruck_doAction(label, ms)
  local ped = PlayerPedId()
  FreezeEntityPosition(ped, true)
  local start = GetGameTimer()
  while GetGameTimer() - start < ms do
    Wait(0)
    DisableAllControlActions(0)
    BeginTextCommandPrint("STRING")
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandPrint(1, true)
  end
  FreezeEntityPosition(ped, false)
end

RegisterNetEvent('az_moneytruck:notify', function(msg) az_moneytruck_notify(msg) end)



local active = false
local idx = 1
local routeBlip = nil
local truck = nil
local otherBlips = {}

local function setRoute(pos)
  if routeBlip then RemoveBlip(routeBlip) end
  routeBlip = AddBlipForCoord(pos.x,pos.y,pos.z)
  SetBlipSprite(routeBlip, 500)
  SetBlipColour(routeBlip, 1)
  SetBlipScale(routeBlip, 0.85)
  SetBlipRoute(routeBlip, true)
  BeginTextCommandSetBlipName("STRING"); AddTextComponentString("Money Stop"); EndTextCommandSetBlipName(routeBlip)
end

RegisterNetEvent('az_moneytruck:blip', function(owner, x,y,z)
  if owner == GetPlayerServerId(PlayerId()) then return end
  local b = otherBlips[owner]
  if not b then
    b = AddBlipForCoord(x,y,z)
    SetBlipSprite(b, 67)
    SetBlipColour(b, 1)
    SetBlipScale(b, 0.9)
    BeginTextCommandSetBlipName("STRING"); AddTextComponentString("Money Truck"); EndTextCommandSetBlipName(b)
    otherBlips[owner] = b
  else
    SetBlipCoords(b, x,y,z)
  end
end)

RegisterNetEvent('az_moneytruck:blipRemove', function(owner)
  local b = otherBlips[owner]
  if b then RemoveBlip(b) end
  otherBlips[owner] = nil
end)

RegisterCommand('moneytruck', function()
  if active then az_moneytruck_notify("Already on a run.") return end
  TriggerServerEvent('az_moneytruck:requestStart')
end)

RegisterNetEvent('az_moneytruck:startDenied', function() active = false end)

RegisterNetEvent('az_moneytruck:startOk', function()
  local ped = PlayerPedId()
  local p = GetEntityCoords(ped)
  local model = joaat(Config.VehicleModel or "stockade")
  RequestModel(model); while not HasModelLoaded(model) do Wait(10) end
  truck = CreateVehicle(model, p.x+2.0, p.y, p.z, GetEntityHeading(ped), true, false)
  SetPedIntoVehicle(ped, truck, -1)
  SetVehicleDoorsLocked(truck, 1)

  active = true
  idx = 1
  setRoute(Config.Banks[idx])
  az_moneytruck_notify("Money transport started. Everyone can see you. Press G at each bank stop.")

  CreateThread(function()
    while active and DoesEntityExist(truck) do
      local c = GetEntityCoords(truck)
      TriggerServerEvent('az_moneytruck:pos', c.x,c.y,c.z)
      Wait(1000)
    end
  end)
end)

CreateThread(function()
  while true do
    Wait(0)
    if not active then goto cont end

    if not DoesEntityExist(truck) then
      active = false
      if routeBlip then RemoveBlip(routeBlip) routeBlip=nil end
      TriggerServerEvent('az_moneytruck:finish')
      goto cont
    end

    local pos = Config.Banks[idx]
    local p = GetEntityCoords(PlayerPedId())
    local dist = #(p - pos)

    if dist < 30.0 then
      DrawMarker(2, pos.x,pos.y,pos.z+0.2, 0,0,0, 0,180,0, 0.55,0.55,0.55, 230,57,70,170, false,true,2,false,nil,nil,false)
    end
    if dist < 3.0 then
      az_moneytruck_help("Press ~INPUT_DETONATE~ to transfer money")
      if IsControlJustPressed(0, Config.ActionKey) then
        az_moneytruck_doAction("Transferring...", 3000)
        TriggerServerEvent('az_moneytruck:stopComplete')
        idx = idx + 1
        if idx > #Config.Banks then
          active = false
          if routeBlip then RemoveBlip(routeBlip) routeBlip=nil end
          az_moneytruck_notify("Run complete.")
          TriggerServerEvent('az_moneytruck:finish')
        else
          setRoute(Config.Banks[idx])
          az_moneytruck_notify("Next bank...")
        end
      end
    end
    ::cont::
  end
end)
