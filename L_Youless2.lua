--[==[
Module L_Youless2.lua
Written by V. Pathuis (Vinx)
Only supports UI7
V1.0 - 28 December 2019
Initial version. 
Support for LS110 & LS120
Support for Watt & KWH
Support for S0 Watt & KWH, optional as child device (LS120 only)

Youless: http://youless.nl
Uses YouLess API as described here: http://wiki.td-er.nl/index.php?title=YouLess

--]==]

local HA_SERVICE = "urn:micasaverde-com:serviceId:HaDevice1"
local ENERGY_SERVICE = "urn:micasaverde-com:serviceId:EnergyMetering1"
local YOULESS_SERVICE = "urn:youless-nl:serviceId:YouLess"
local YOULESS_INTERVAL = 60
local YOULESS_MODEL = ""
local YOULESS_S0_ALTID = "YouLess_S0"
local YOULESS_DEVICE = 0

function findChild(parentDevice, label)
    for k, v in pairs(luup.devices) do
        if (v.device_num_parent == parentDevice and v.id == label) then
            return k
        end
    end
end

local function readYouLess()
    status,page = luup.inet.wget(YOULESS_URL_ACTUAL)

    -- read pwr (watts)
    local watts = string.match(page,'"pwr":(.-),')
    if (watts ~= nil and watts ~= '') then
        watts = tonumber(watts)
        luup.variable_set(ENERGY_SERVICE, "Watts", watts, YOULESS_DEVICE)
        luup.log("YouLess pwr (watts)="..watts)
    else 
        luup.log("Response from YouLess respons invalid: does not contain pwr")
        luup.variable_set(HA_SERVICE,"CommFailure",1, YOULESS_DEVICE)
    end

    -- read cnt (kwh)
    local kwh =  string.match(page,'"cnt":"(.-)"')
    if (kwh ~= nil and kwh ~= '') then
        kwh = string.gsub(kwh,",",".")
        kwh = tonumber(kwh)
        luup.variable_set(ENERGY_SERVICE,"KWH", kwh, YOULESS_DEVICE)
        luup.log("YouLess kwh (cnt)=".. kwh)
    else 
        luup.log("Response from YouLess respons invalid: does not contain cnt")
        luup.variable_set(HA_SERVICE,"CommFailure",1, YOULESS_DEVICE)
    end

    if (YOULESS_MODEL ~= "LS110") then -- following variables are not supported by LS110
        childS0id = findChild(YOULESS_DEVICE, YOULESS_S0_ALTID)
        if (childS0id ~= nil) then
            luup.log("Child S0: " .. childS0id)
        else
            luup.log("No child S0 found")
        end

        -- read watts s0 (ps0)
        local wattss0 = string.match(page,'"ps0":(.-),')
        if (wattss0 ~= nil and wattss0 ~= '') then
            wattss0 = tonumber(wattss0)
            luup.log("YouLess ps0="..wattss0)
            luup.variable_set(ENERGY_SERVICE, "Watts_S0", wattss0, YOULESS_DEVICE)
            if ((childS0id or "") ~= "") then
                luup.variable_set(ENERGY_SERVICE, "Watts", wattss0, childS0id)
            end
        else 
            luup.log("No ps0 found")
        end

        -- read kwh s0 (cs0)
        local kwhs0 =  string.match(page,'"cs0":"(.-)"')
        if (kwhs0 ~= nil and kwhs0 ~= '') then
            kwhs0 = string.gsub( kwhs0, "%s+", "")
            kwhs0 = string.gsub(kwhs0,",",".")
            kwhs0 = tonumber(kwhs0)
            luup.variable_set(ENERGY_SERVICE,"KWH_S0", kwhs0, YOULESS_DEVICE)
            if ((childS0id or "") ~= "") then
                luup.variable_set(ENERGY_SERVICE, "KWH", kwhs0, childS0id)
            end
            luup.log("YouLess kwhs0=".. kwhs0)
        else 
            luup.log("No cs0 found")
        end
    end
end

function refreshCache()
    readYouLess()
    luup.call_timer("refreshCache", 1, YOULESS_INTERVAL, "")
end

function Youless_Init(youless_device)
    luup.log("Starting YouLess2")
    YOULESS_DEVICE = youless_device
    YOULESS_IP = luup.attr_get('ip',YOULESS_DEVICE)
    
    if (YOULESS_IP == nil or YOULESS_IP == "") then
        return false, "No IP specified. Visit the Advanced tab to specify the Youless ip-address and reload luup.", string.format("%s[%d]", luup.devices[YOULESS_DEVICE].description, youless_device)
    end
    
    YOULESS_URL_ACTUAL = "http://" .. YOULESS_IP .. "/a?f=j"
    YOULESS_URL_DEVICE = "http://" .. YOULESS_IP .. "/d"

    -- check the connection
    local status, page = luup.inet.wget(YOULESS_URL_ACTUAL)
    if ((status or 0) ~= 0) then
        return false, "Connection to YouLess failed. Verify the Youless ip-address.", string.format("%s[%d]", luup.devices[YOULESS_DEVICE].description, YOULESS_DEVICE)
    end

    status,page = luup.inet.wget(YOULESS_URL_DEVICE)
    if ((status or 0) ~= 0) then
        YOULESS_MODEL = "LS110" -- device page not available, therefore assuming LS110
        luup.variable_set(ENERGY_SERVICE, "Model", YOULESS_MODEL, YOULESS_DEVICE)
        luup.log("YouLess model="..YOULESS_MODEL)
    else 
        local model = string.match(page,'"model":"(.-)",')
        if (model ~= nil and model ~= '') then
            YOULESS_MODEL = string.gsub( model, "%s+", "") 
            luup.variable_set(ENERGY_SERVICE, "Model", YOULESS_MODEL, YOULESS_DEVICE)
            luup.log("YouLess model="..YOULESS_MODEL)
        else 
            luup.log("Found device page, but failed to get model name")
        end
    end

    luup.log("Youless found at " .. YOULESS_IP)

    if ((YOULESS_MODEL or "") ~= "LS110") then
        local ChildDeviceS0 = luup.variable_get(YOULESS_SERVICE, "ChildDeviceS0", YOULESS_DEVICE)
        -- create variables if they don't exist
        if ((ChildDeviceS0 or "") == "") then
            luup.variable_set(YOULESS_SERVICE, "ChildDeviceS0", 0, YOULESS_DEVICE)
        end

        -- create child devices if needed
        local child_devices = luup.chdev.start(YOULESS_DEVICE)
        if (ChildDeviceS0 == "1") then
            luup.log("Adding child device for YouLess S0")
            local init=ENERGY_SERVICE .. ",ActualUsage=1\n" .. 
                ENERGY_SERVICE .. ",Watts=0\n" .. 
                ENERGY_SERVICE .. ",KWH=0\n"

            luup.chdev.append(YOULESS_DEVICE, 
                child_devices, -- handle
                YOULESS_S0_ALTID, -- altid
                "YouLess S0", -- device name
                "", -- device_type, derived from the device file
                "D_PowerMeter1.xml", -- device file for given device
                "", -- Implementation file
                init, -- initiating variables
                true) -- embedded
        end
        luup.chdev.sync(YOULESS_DEVICE, child_devices)
    end

    readYouLess()
    luup.set_failure(0, YOULESS_DEVICE)
    luup.call_timer("refreshCache", 1, YOULESS_INTERVAL, "")
end
