# qBittorrent-PIA-Port-Forwarder

### A Ruby script for automatically setting qBittorrents listening port while connected to PIA VPN

**Config**

Enter your QBT credentials and IP address, and then enter your PIA credentials.

**Environment**

This script was tested with Ruby 2.5.3.

**Usage**

Run the script with `ruby qbt_pia_port_forwarder.rb`. It will create a text file named `pia_client_id_file.txt` for storing your client ID. If you wish to force a port change, simply delete the text file and run the script. I recommend executing the script with cron or a similar service.
