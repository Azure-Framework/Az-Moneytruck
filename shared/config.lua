Config = Config or {}

Config.FrameworkResource = Config.FrameworkResource or 'Az-Framework'
Config.DebugJobChecks = Config.DebugJobChecks ~= false
Config.JobName = 'moneytruck'

-- Job Center DB mapping (used for /quitjob if no framework setter is available)
Config.DB = Config.DB or {
  table            = 'user_characters',
  identifierColumn = 'charid',
  jobColumn        = 'active_department'
}
Config.UseAzFrameworkCharacter = (Config.UseAzFrameworkCharacter ~= false)

-- Uses Az-Framework export you provided:
-- exports['Az-Framework']:getPlayerJob(source)
Config.GetPlayerJob = Config.GetPlayerJob or function(source)
    local ok, job = pcall(function()
        return exports[Config.FrameworkResource]:getPlayerJob(source)
    end)
    if ok then
        if type(job) == 'table' then
            job = job.name or job.job or job.label or job.id
        end
        if job ~= nil then
            local s = tostring(job):gsub("^%s+",""):gsub("%s+$","")
            if s ~= "" then return string.lower(s) end
        end
    end
    return 'civ'
end

Config.InteractKey = Config.InteractKey or 38 -- E
Config.ActionKey   = Config.ActionKey or 47 -- G



Config.VehicleModel = "stockade"
Config.PayPerStop = 450
Config.Banks = {
  vector3(150.2, -1040.1, 29.3),
  vector3(-1212.9, -330.9, 37.8),
  vector3(-2962.6, 482.9, 15.7),
  vector3(314.2, -278.9, 54.2),
}
