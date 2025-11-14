-- RageBot Loader
-- Loads ff.lua from GitHub repository
local environment = identifyexecutor and identifyexecutor() or ""
local repoUrl = "https://raw.githubusercontent.com/alott2223/dddd/refs/heads/main/ff.lua"

local function loadScript()
    local source = game:HttpGet(repoUrl)
    if string.find(string.lower(environment), "wave") and not getgenv().executed then
        run_on_actor(get_deleted_actors()[1], source)
    elseif getfflag and string.find(string.lower(tostring(getfflag("DebugRunParallelLuaOnMainThread"))), "true") and not getgenv().executed then
        loadstring(source)()
    elseif string.find(environment, "AWP") ~= nil and not getgenv().executed then
        for _, v in getactors() do
            run_on_actor(v, [[
                for _, func in getgc(false) do
                    if type(func) == "function" and islclosure(func) and debug.getinfo(func).name == "require" and string.find(debug.getinfo(func).source, "ClientLoader") then
                        ]] .. source .. [[
                        break
                    end
                end
            ]])
        end
    elseif string.find(string.lower(environment), "zenith") and not getgenv().executed then
        for _, actor in getactorthreads() do
            run_on_thread(actor, [[
                for _, func in getgc(false) do
                    if type(func) == "function" and islclosure(func) and debug.getinfo(func).name == "require" and string.find(debug.getinfo(func).source, "ClientLoader") then
                        ]] .. source .. [[
                        break
                    end
                end
            ]])
        end
    else
        queue_on_teleport(game:HttpGet("https://raw.githubusercontent.com/alott2223/dddd/refs/heads/main/loader.lua") .. "task.wait(5);" .. source)
        setfflag("DebugRunParallelLuaOnMainThread", "True")
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId)
    end
    getgenv().executed = true
end

loadScript()
