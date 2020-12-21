# qBittorrent-PIA-Port-Forwarder V2

### A Ruby script for automatically setting qBittorrents listening port while connected to PIA VPN

**Requirements**\
Given that this is a Ruby script, it requires a Ruby environment. This script was tested with Ruby 2.6.5. If you need help installing and managing your environment, I'd recommend [RVM](https://rvm.io/).

The script requires an active PIA VPN connection with the following attributes:
* OpenVPN (This may work with WireGuard, but it hasn't been tested)
* A server outside of the US.

It was build for use on Ubuntu Server, but developed on a Mac. The only additional tools needed on Mac were [Homebrew](https://brew.sh/) with the `iproute2mac` package installed.

You will also need Cron, or a similar service. The script needs to be executed every 15 minutes to maintain your forwarded port. In Ubuntu, I use cron via `crontab -e` with an entry similar to this:

```
*/15 * * * * /bin/bash -c -l 'cd /home/clajiness/scripts/qBittorrent-PIA-Port-Forwarder; /home/clajiness/.rvm/rubies/ruby-2.6.5/bin/ruby qbt_pia_port_forwarder.rb'
```

**Config**\
To set up the script, use `initial_config.yml.example` to create your `initial_config.yml` file. `cp initial_config.yml.example initial_config.yml` should work fine. Then, populate your new `initial_config.yml` file with the required data. Once complete, save your file and set up your cron job.

**Usage**\
Run the script with `ruby qbt_pia_port_forwarder.rb`. If you wish to force a port change, simply delete the auto_config.yml file and run the script again. Again, I recommend executing the script every 15 minutes with cron or a similar service. If it's not ran every 15 minutes, you will lose your forwarded port.
