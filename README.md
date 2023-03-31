# PurpleAir
SmartThings Edge Driver for [PurpleAir](https://www2.purpleair.com/) air quality sensor [API](https://api.purpleair.com/#api-welcome)

#### Credit
Some of this code is a port of the Hubitat [PurpleAir AQI Virtual Sensor.groovy driver](https://github.com/pfmiller0/Hubitat/blob/main/PurpleAir%20AQI%20Virtual%20Sensor.groovy) by [pfmiller0](https://github.com/pfmiller0).

### Features
* Displays AQI, AQI category, and sensor names
* Use multiple sensors within a defined latitude/longitude coordinate box, or use a specific sensor by index number
* Automatic periodic updates

### Pre-requisites
* SmartThings Hub
* [Edgebridge server](https://github.com/toddaustin07/edgebridge) or other proxy
* PurpleAir [API key](https://develop.purpleair.com/keys)

## Installation
### Edgebridge
Install edgebridge per the instructions [here](https://github.com/toddaustin07/edgebridge/blob/main/README.md).  Be sure to use only versions that are dated March 31, 2023 or later
### Driver
* Go to this Edge driver [channel invite link](https://bestow-regional.api.smartthings.com/invite/Q1jP7BqnNNlL).
* Enroll your hub and then select the PurpleAir Driver V1 to install to your hub.
* Once the driver is available on your hub, use the SmartThings mobile app to do an *Add device / Scan for nearby devices*, and a new device will be created in whatever room in which your hub device is located.

## Configuration
In the PurpleAir device Settings screen, configure the following fields:
* **Update Interval**
  * Choose an automatic refresh interval from the list - from every minute, to every three hours
* **Averaging Period**
  * Choose averaging period for the sensor readings - from one minute, to one week
* **Search for devices**
  * Enable (turn on) to search for devices within a defined coordinate box; disable (turn off) to use a single specified sensor
* **Private key**
  * If *Search for devices* is disabled, and the desired sensor requires a private key, configure it here
* **Sensor index**
  * If *Search for devices* is disabled, provide the desired sensor index number here
* **Search box center**
  * If *Search for devices* is enabled, provide the latitude, longitude coordinates here which would represent the center of the box.  The coordinates must be provided as two comma-separated decimal numbers
* **Search box size - value**
  * If *Search for devices* is enabled, provide the number of miles or kilometers that bounds the latitudinal and longitudinal sides of the coordinate box
* **Search box size - units**
  * If *Search for devices* is enabled, choose the units (miles or kilometers) associated with the box size value provide above
* **Use weighted average?**
  * If *Search for devices* is enabled, choose whether or not to compute the average AQI of all sensors with a weighting towards those that are closer
* **Proxy Type**
  * Some form of proxy is required to allow the Edge driver access to internet endpoints.  Choose the proxy type here (edgebridge is recommended)
* **Proxy Server Address**
  * Provide the HTTP address of the proxy server in the form of 'http://\<*ip address*\>:\<*port number*\>'
* **Response Timeout**
  * Provide the desired amount of time to wait for a response from the PurpleAir servers before timing out
* **API Key**
  * Provide the API Key assigned to you from PurpleAir to access their API

### Usage
Following the configuration of all device Settings, return to the device Controls screen and use the 'swipe-down' gesture.  This will force a refresh based on your latest Settings options and the AQI, AQI Category, and Sensor sites used fields should get populated.

The data displayed will be refreshed based on the update interval configured in device Settings (e.g. every minute, every hour, etc.).

Reference the PurpleAir [map](https://map.purpleair.com/?mylocation) to see all sensors in your vicinity.

### Automations
All three fields are available for IF conditions of automation routines or Rules.  No command actions are available in this device.

### Problems
If the device appears not to be working:
* Confirm your proxy server type and address are properly configured
* Be certain you have entered your API Key correctly
* Be sure you are running a version of edgebridge dated 3/31/23 or later, if applicable
* Monitor the edgebridge (or other proxy server) console or file log to confirm that requests are being received from your hub, and forwarded to PurpleAir.  If necessary, run edgebridge with the -d command line parameter to display all sent and received data; also take note of any HTTP errors that may be returned by the PurpleAir servers. 
* Use the SmartThings [CLI](https://github.com/SmartThingsCommunity/smartthings-cli) to generate driver logs; send me a direct message in the SmartThings community for assistance in diagnosing the log output
