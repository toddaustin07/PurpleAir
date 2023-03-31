--[[
  Copyright 2023 Todd Austin

  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
  except in compliance with the License. You may obtain a copy of the License at:

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software distributed under the
  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
  either express or implied. See the License for the specific language governing permissions
  and limitations under the License.


  DESCRIPTION
  
  Purple Air driver

--]]

-- Edge libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local cosock = require "cosock"                 -- just for time
local socket = require "cosock.socket"          -- just for time
local comms = require "comms"
local parser = require "parser"
local log = require "log"

-- Module variables
local thisDriver = {}
local initialized = false

-- Constants
local DEVICE_PROFILE = 'purpleair.v1'
PERIODS = {
                      ["pm1min"] = "pm2.5",
                      ["pm10min"] = "pm2.5_10minute",
                      ["pm30min"] = "pm2.5_30minute",
                      ["pm60min"] = "pm2.5_60minute",
                      ["pm6hr"] = "pm2.5_6hour",
                      ["pm24hr"] = "pm2.5_24hour", 
                      ["pm1wk"] = "pm2.5_1week"
                    }


-- Custom capabilities
local cap_sites = capabilities['partyvoice23922.aqisites']
local cap_category = capabilities['partyvoice23922.aqicategory']

local function build_html(list)

  local html_list = ''

  for _, item in ipairs(list) do
    html_list = html_list .. '<tr><td>' .. item .. '</td></tr>\n'
  end

  local html =  {
                  '<!DOCTYPE html>\n',
                  '<HTML>\n',
                  '<HEAD>\n',
                  '<style>\n',
                  'table, td {\n',
                  '  border: 1px solid black;\n',
                  '  border-collapse: collapse;\n',
                  '  font-size: 14px;\n',
                  '  padding: 3px;\n',
                  '}\n',
                  '</style>\n',
                  '</HEAD>\n',
                  '<BODY>\n',
                  '<table>\n',
                  html_list,
                  '</table>\n',
                  '</BODY>\n',
                  '</HTML>\n'
                }
    
  return (table.concat(html))
end

local function update_device(device, data)

  if data then
  
    device:emit_event(capabilities.airQualitySensor.airQuality(data.aqi))
    device:emit_event(cap_category.category(data.category))
    device:emit_event(cap_sites.sites(build_html(data.sites)))
  
  end

end


-- Returns miles per degree for a given latitude
local function distance2degrees(latitude)
  local latMilesPerDegree = 69.172 * math.cos(math.rad(latitude))
  local longMilesPerDegree = 68.972
  
  return {latMilesPerDegree, longMilesPerDegree}
end


local function buildqparms(parmtable)

  local parmstring = '?'
  local more = ''

  for key, value in pairs(parmtable) do
    
    parmstring = parmstring .. more .. key .. '=' .. tostring(value) 
    more = '&'
  
  end

  return parmstring

end


local function do_refresh(device)


  local ip, port = comms.validate_address(device.preferences.proxyaddr:match('http[s]*://(.+)$'))
  
  if ip and port then
  
    local url="http://" .. ip .. ":" .. tostring(port) .. "/api/forward?url=https://api.purpleair.com/v1/sensors"
    local query_fields=string.format("name,%s,latitude,longitude,confidence", PERIODS[device.preferences.avgperiod])
    local httpQuery = {}
    local coords
    
    if device.preferences.search == true then
    
      local lat_str, long_str = device.preferences.center:match('([%d%-%.]+)[%, ]*([%d%-%.]+)$')
      coords = {}
      coords[1] = tonumber(lat_str)
      coords[2] = tonumber(long_str)
      
      if not (coords[1] and coords[2]) then
        log.warn ('Box center coordinates not defined')
        return
      end
    
      local dist2deg = distance2degrees(coords[1])
      local range = {}
          
      log.debug ('Box size units:', device.preferences.sizeunits)
      if device.preferences.sizeunits == 'miles' then
        range = {device.preferences.sizevalue/dist2deg[1], device.preferences.sizevalue/dist2deg[2]}
      else         -- Convert to km
        range = {(device.preferences.sizevalue/1.609)/dist2deg[1], (device.preferences.sizevalue/1.609)/dist2deg[2]}
      end
      
      url = url .. buildqparms({["fields"] = query_fields,
                                ["location_type"] = "0",
                                ["max_age"] = 3600,
                                ["nwlat"] = coords[1] + range[1],
                                ["nwlng"] = coords[2] - range[2],
                                ["selat"] = coords[1] - range[1],
                                ["selng"] = coords[2] + range[2]})
      
    else
      if device.preferences.readkey ~= 'null' then
        url = url .. buildqparms({["fields"] = query_fields,
                                  ["read_key"] = device.preferences.readkey,
                                  ["show_only"] = device.preferences.sensorindex})
      else
        url = url .. buildqparms({["fields"] = query_fields, ["show_only"] = device.preferences.sensorindex})
      end
    end
    
    log.debug ('url:', url)
    
    local headers = {['Accept']='application/json', ['X-API-Key']=device.preferences.apikey, ['Host']='api.purpleair.com'}
    
    local ret, response = comms.issue_request(device, method, url, nil, headers)
    
    if ret == 'OK' then
      update_device(device, parser.parsedata(device, response, coords))
    end
    
  else
    log.warn('Invalid proxy address configured')
  end
end


local function setup_periodic_refresh(driver, device)

  if device:get_field('refreshtimer') then
    driver:cancel_timer(device:get_field('refreshtimer'))
  end
  
  local timervalue =  {
                        ['1min'] = 60,
                        ['5min'] = 300,
                        ['10min'] = 600,
                        ['15min'] = 900,
                        ['30min'] = 1800,
                        ['60min'] = 3600,
                        ['180min'] = 10800
                      }

  local refreshtimer = driver:call_on_schedule(timervalue[device.preferences.interval], function()
      do_refresh(device)
    end)
    
  device:set_field('refreshtimer', refreshtimer)

end

-----------------------------------------------------------------------
--                    COMMAND HANDLERS
-----------------------------------------------------------------------

local function handle_refresh(_, device, command)

  do_refresh(device)
  
end

------------------------------------------------------------------------
--                REQUIRED EDGE DRIVER HANDLERS
------------------------------------------------------------------------

-- Lifecycle handler to initialize existing devices AND newly discovered devices
local function device_init(driver, device)
  
  log.debug(device.id .. ": " .. device.device_network_id .. "> INITIALIZING")

  device.thread:queue_event(do_refresh, device)
  
  setup_periodic_refresh(driver, device)
  
  initialized = true
  
end


-- Called when device was just created in SmartThings
local function device_added (driver, device)

  log.info(device.id .. ": " .. device.device_network_id .. "> ADDED")

  local init_data = {
			  ['aqi'] = 0,
        ['category'] = ' ',
        ['sites'] = {' '},
			}
  
  update_device(device, init_data)
  
end


-- Called when SmartThings thinks the device needs provisioning
local function device_doconfigure (_, device)

  -- Nothing to do here!

end


-- Called when device was deleted via mobile app
local function device_removed(driver, device)
  
  log.warn(device.id .. ": " .. device.device_network_id .. "> removed")
  
  driver:cancel_timer(device:get_field('refreshtimer'))
  
  initialized = false
  
end


local function handler_driverchanged(driver, device, event, args)

  log.debug ('*** Driver changed handler invoked ***')

end

local function shutdown_handler(driver, event)

  log.info ('*** Driver being shut down ***')

end


local function handler_infochanged (driver, device, event, args)

  log.debug ('Info changed handler invoked')

  -- Did preferences change?
  if args.old_st_store.preferences then
  
    if args.old_st_store.preferences.request ~= device.preferences.request then 
      log.info ('Request string changed to: ', device.preferences.request)
      
      device.thread:queue_event(do_refresh, device)
      
    elseif args.old_st_store.preferences.interval ~= device.preferences.interval then 
      log.info ('Refresh fequency changed to: ', device.preferences.interval)
      
      setup_periodic_refresh(driver, device)
    end
  else
    log.warn ('Old preferences missing')
  end  
     
end


-- Create Device
local function discovery_handler(driver, _, should_continue)

  if not initialized then

    log.info("Creating device")

    local MFG_NAME = 'TAUSTIN'
    local MODEL = 'PurpleAirV1'
    local VEND_LABEL = 'Purple Air V1'
    local ID = 'PurpleAirV1' .. tostring(socket.gettime())
    local PROFILE = DEVICE_PROFILE

    -- Create master creator device

    local create_device_msg = {
                                type = "LAN",
                                device_network_id = ID,
                                label = VEND_LABEL,
                                profile = PROFILE,
                                manufacturer = MFG_NAME,
                                model = MODEL,
                                vendor_provided_label = VEND_LABEL,
                              }

    assert (driver:try_create_device(create_device_msg), "failed to create device")

    log.debug("Exiting device creation")

  else
    log.info ('Purple Air device already created')
  end
end


-----------------------------------------------------------------------
--        DRIVER MAINLINE: Build driver context table
-----------------------------------------------------------------------
thisDriver = Driver("thisDriver", {
  discovery = discovery_handler,
  lifecycle_handlers = {
    init = device_init,
    added = device_added,
    driverSwitched = handler_driverchanged,
    infoChanged = handler_infochanged,
    doConfigure = device_doconfigure,
    removed = device_removed
  },
  driver_lifecycle = shutdown_handler,
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = handle_refresh,
    },
  }
})

log.info ('Purple Air v1.0 Started')

thisDriver:run()
