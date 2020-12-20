## **V2 Beta**

# qBittorrent-PIA-Port-Forwarder V2

### A Ruby script for automatically setting qBittorrents listening port while connected to PIA VPN

**Config**\
Enter your QBT credentials and IP address:port, and then enter your PIA credentials.

**Environment**\
This script was tested with Ruby 2.5.3.

**Usage**\
Enter your credentials into the initial_config.yml file. Run the script with `ruby qbt_pia_port_forwarder.rb`. If you wish to force a port change, simply delete the auto_config.yml file and run the script. I recommend executing the script every 15 minutes with cron or a similar service.
