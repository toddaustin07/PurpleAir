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
  
  Fronius Inverter return data parser module

--]]

local log = require "log"
local json = require "dkjson"



local function sensorAverage(sensors, field)
  
  local sum = 0

  for _, sensor in ipairs(sensors) do
    sum = sum + sensor[field]
  end
  
  --log.debug ('Regular average:', sum / #sensors)
  return sum / #sensors
end


local function sensorAverageWeighted(sensors, field) 

  local count = 0.0
  local sum = 0.0
  local distances = {}
  local nearest = 0.0
  
  -- Weighted average. First find nearest sensor. Then divide sensors distances by nearest distance to get weights.
  for i, sensor in ipairs(sensors) do
    distances[i] = sensor.distance
    log.debug ('Distance=', sensor.distance)
  end
  
  nearest = math.min(table.unpack(distances))
    
  for _, sensor in ipairs(sensors) do
    local val = sensor[field]
    local weight = nearest / sensor.distance
    sum = sum + (val * weight)
    count = count + weight
  end
  log.debug ('Weighted average=', sum / count)
  return sum / count
end


-- AQILinear functions from https://www.airnow.gov/aqi/aqi-calculator/
local function AQILinear(AQIhigh, AQIlow, Conchigh, Conclow, Concentration)
	
  return math.floor((((Concentration-Conclow)/(Conchigh-Conclow))*(AQIhigh-AQIlow)+AQIlow)+ 0.5)
end


local function calcAQI(partCount)
  
  if (partCount >= 0) and (partCount < 12.1) then
    return AQILinear(50,0,12,0,partCount)
    
  elseif (partCount >= 12.1) and (partCount < 35.5) then
    return AQILinear(100,51,35.4,12.1,partCount)
	  
  elseif (partCount >= 35.5) and (partCount < 55.5) then
    return AQILinear(150,101,55.4,35.5,partCount)
	  
  elseif (partCount >= 55.5) and (partCount < 150.5) then
    return AQILinear(200,151,150.4,55.5,partCount)
	  
  elseif (partCount >= 150.5) and (partCount < 250.5) then
    return AQILinear(300,201,250.4,150.5,partCount)
	  
  elseif (partCount >= 250.5) and (partCount < 350.5) then
    return AQILinear(400,301,350.4,250.5,partCount)
	  
  elseif (partCount >= 350.5) and (partCount < 500.5) then
    return AQILinear(500,401,500.4,350.5,partCount)
	  
  elseif partCount >= 500.5 then
    return math.floor(partCount + 0.5)
    
  else
    return -1
  end
end


local function getCategory(AQI)
  if (AQI >= 0) and (AQI <= 50) then
    return "Good"
  elseif (AQI > 50) and (AQI <= 100) then
    return "Moderate"
  elseif (AQI > 100) and (AQI <= 150) then
    return "Unhealthy for sensitive groups"
  elseif (AQI > 150) and (AQI <= 200) then
    return "Unhealthy"
  elseif (AQI > 200) and (AQI <= 300) then
    return "Very unhealthy"
  elseif (AQI > 300) and (AQI <= 500) then
    return "Hazardous"
  elseif AQI > 500 then
    return "Extremely hazardous!"
  else
    return "out of bounds"
  end
end


local function distance(coorda, coordb)
  if (coorda == nil) or (coordb == nil) then; return 0.0; end
  
  -- Haversine function from http://www.movable-type.co.uk/scripts/latlong.html
  local R = 6371000 				-- meters
  local lat1 = math.rad(coorda[1])
  local lat2 = math.rad(coordb[1])
  local delta_lat = math.rad(coordb[1]-coorda[1])
  local delta_long = math.rad(coordb[2]-coorda[2])

  local a = math.sin(delta_lat/2) * math.sin(delta_lat/2) + math.cos(lat1) * math.cos(lat2) * math.sin(delta_long/2) * math.sin(delta_long/2);
  local c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));

  local d = (R * c) / 1000; 	-- in km
  return d / 1.609 		-- in miles
end


local function getSites(sensors)

  if #sensors == 0 then; return 'none'; end
  
  local sitelist = {}
  local sep = ''

  for i, sensor in ipairs(sensors) do
    sitelist[i] = sensor.site
  end
  
  return sitelist

end


local function get_aqi(device, response, center_coords)

  local f_index = {}
  local aqiValue = -1
  local aqiCategory = ' '
  local sensorData = {}
  local sites
  local sensors = {}
  
  
  for i, field in ipairs(response.fields) do
    f_index[field] = i
  end
	
  if device.preferences.search == true then
    -- Filter out lower quality devices
    for _, datalist in ipairs(response.data) do
      if datalist[f_index['confidence']] >= 90 then
	table.insert(sensorData, datalist)
      end
      
    end

  else
    sensorData[1] = response.data[1]
  end

  -- initialize sensor maps
  local sensor_coords = {}
  
  for _, sensor in ipairs(sensorData) do
    sensor_coords = {sensor[f_index['latitude']], sensor[f_index['longitude']]}
    
    table.insert(sensors, {
			    ['site'] = sensor[f_index['name']],
			    ['part_count'] = sensor[f_index[PERIODS[device.preferences.avgperiod]]],
			    ['confidence'] = sensor[f_index['confidence']],
			    ['distance'] = distance(center_coords, sensor_coords),
			    ['coords'] = sensor_coords
			  })
  end

  if (device.preferences.weighted == true) and (device.preferences.search == true) then
    aqiValue = calcAQI(sensorAverageWeighted(sensors, 'part_count'))
  else
    aqiValue = calcAQI(sensorAverage(sensors, 'part_count'))
  end
  
  
  return aqiValue, getCategory(aqiValue), getSites(sensors)
  
end


return {

  parsedata = function(device, response, center_coords)
  
    local dataobj, pos, err = json.decode (response, 1, nil)
    if err then
      log.error ("JSON decode error:", err)
      return nil
    end
    
    local parsed_data = {
			  ['aqi'] = 0,
			  ['category'] = ' ',
			  ['sites'] = {},
			}

    parsed_data.aqi, parsed_data.category, parsed_data.sites = get_aqi(device, dataobj, center_coords)
    
    return parsed_data

  end

}
