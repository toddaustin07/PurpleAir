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
