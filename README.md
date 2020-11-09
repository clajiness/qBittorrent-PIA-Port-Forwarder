# qBittorrent-PIA-Port-Forwarder

## Deprecated - This script will *not* work with PIA's NextGen network.

### A Ruby script for automatically setting qBittorrents listening port while connected to PIA VPN

**Config**\
Enter your QBT credentials and IP address:port, and then enter your PIA credentials.

**Environment**\
This script was tested with Ruby 2.5.3.

**Usage**\
Enter your credentials into the config.yml file. Run the script with `ruby qbt_pia_port_forwarder.rb`. It will create a YAML file named `client_id.yml` for storing your client ID. If you wish to force a port change, simply delete the YAML file and run the script. I recommend executing the script with cron or a similar service.
