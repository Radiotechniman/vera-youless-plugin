# About
Plugin for Vera Home Automation for YouLess LS110 and YouLess LS120. 
Support for reading actual Watt & KWH.
Support for reading S0 port Watt & KWH and optionally create a child device
App store plugin id=9286
Supported and tested on UI7. Should also work on UI5.
No support for YouLess-password (yet)

# Install
- Upload files on the Vera
- Manually create device from Apps > Develop Apps > Create Device
- Choose "D_Youless2.xml" for Upnp Device Filename
- Choose the ip-address of the Youless for IP address
- Press Create
- Force manual luup reload
- For a seperate device for the S0-readings, set ChildDeviceS0 to 1 in the Advanced > Variables tab.
