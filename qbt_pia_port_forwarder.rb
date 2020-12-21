require 'json'
require 'net/http'
require 'net/https'
require 'securerandom'
require 'socket'
require 'yaml'
require 'logger'
require 'base64'

# version number of qppf
script_version = "2.0.1"

# set up logger
@logger = Logger.new('qbt_pia.log', 10, 1024000)
@logger.info("starting qbt_pia_port_forwarder v#{script_version}")

# HELPERS
def is_expired?(time_stamp)
  time_stamp == nil || time_stamp <= Time.now
end
# ----------

def write_config
  File.open("auto_config.yml", "w") { |f| f.write @config.to_yaml }
end
# ----------

# CONFIG
def get_config
  begin
    @pia_local_ip = `ip route | head -1 | grep tun | awk '{ print $3 }'`.chomp
    @logger.info("local ip is #{@pia_local_ip}")
  rescue
    @logger.error("PIA_LOCAL_IP not found")
    exit(false)
  end

  if File.exist?("auto_config.yml")
    config_file = YAML.load_file("auto_config.yml")
    @logger.info("auto_config.yml file found successfully")

    @config = {
      user: config_file[:user],
      password: config_file[:password],
      token: config_file[:token],
      token_expiration: config_file[:token_expiration],
      port: config_file[:port],
      port_expiration: config_file[:port_expiration],
      port_renew_by: config_file[:port_renew_by],
      payload: config_file[:payload],
      signature: config_file[:signature],
      qbit_user: config_file[:qbit_user],
      qbit_pass: config_file[:qbit_pass],
      qbit_addr: config_file[:qbit_addr]
    }
  else
    config_file = YAML.load_file("initial_config.yml")
    @logger.info("auto_config.yml file not found. load data from the initial_config.yml file.")

    @config = {
      user: config_file[:pia_username],
      password: config_file[:pia_password],
      token: nil,
      token_expiration: nil,
      port: nil,
      port_expiration: nil,
      port_renew_by: nil,
      payload: nil,
      signature: nil,
      qbit_user: config_file[:qbt_username],
      qbit_pass: config_file[:qbt_password],
      qbit_addr: config_file[:qbt_addr]
    }
  end
end
# ----------

# PIA METHODS
def get_pia_token
  if is_expired?(@config[:token_expiration])
    uri = URI('https://10.0.0.1/authv3/generateToken')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    req =  Net::HTTP::Get.new(uri)
    req.basic_auth "#{@config[:user]}", "#{@config[:password]}"
    response = http.request(req)
    response_body = JSON.parse(response.body)
    @config[:token] = response_body["token"]
    @config[:token_expiration] = (Time.now + (60 * 60 * 24)) # set token expiration to 24 hours
    @logger.info("new pia token has been created")
  else
    @logger.info("using existing pia token")
  end
end

def get_pia_port
  if is_expired?(@config[:port_expiration]) and is_expired?(@config[:port_renew_by])
    response = `curl -skG --data-urlencode "token=#{@config[:token]}" "https://#{@pia_local_ip}:19999/getSignature"`
    sig = JSON.parse(response)
    @config[:payload] = sig["payload"]
    @config[:signature] = sig["signature"]
    payload = JSON.parse(Base64.decode64(@config[:payload]))
    @config[:port] = payload["port"]
    @config[:port_expiration] = (Time.now + (60 * 60 * 24 * 30)) # set port expiration to 30 days
    @logger.info("new pia port has been created")
  else
    @logger.info("using existing pia port")
  end
end

def bind_port
  response = `curl -skG --data-urlencode "payload=#{@config[:payload]}" --data-urlencode "signature=#{@config[:signature]}" "https://#{@pia_local_ip}:19999/bindPort"`
  parsed_response = JSON.parse(response)

  if parsed_response["status"] == "OK"
    @logger.info("pia's bind port api response: #{JSON.parse(response)}")
    @config[:port_renew_by] = Time.now + (60 * 16) # set port renewal timing to 16 minutes since this runs every 15
  else
    @logger.error("error binding port: #{parsed_response["message"]} - exiting")
    invalidate_expirations
    exit(false)
  end
end

def invalidate_expirations
  config[:token_expiration] = nil
  config[:port_expiration] = nil
  config[:port_renew_by] = nil
end
# ----------

# QBITTORRENT METHODS
def qbt_auth_login
  uri = URI("#{@config[:qbit_addr]}/api/v2/auth/login?username=#{@config[:qbit_user]}&password=#{@config[:qbit_pass]}")
  http = Net::HTTP.new(uri.host, uri.port)
  req =  Net::HTTP::Get.new(uri)
  response = http.request(req)
  response["set-cookie"].split(";")[0]
rescue StandardError => e
  @logger.error("qbt_auth_login - HTTP Request failed - (#{e.message})")
end

def qbt_app_preferences(sid)
  uri = URI("#{@config[:qbit_addr]}/api/v2/app/preferences")
  http = Net::HTTP.new(uri.host, uri.port)
  req =  Net::HTTP::Get.new(uri)
  req.add_field "Cookie", sid
  response = http.request(req)
  qbt_port = JSON.parse(response.body)["listen_port"]
  @logger.info("current qbit port: #{qbt_port}")
  qbt_port
rescue StandardError => e
  @logger.error("qbt_app_preferences - HTTP Request failed - (#{e.message})")
end

def qbt_app_setPreferences(sid, pia_port)
  uri = URI("#{@config[:qbit_addr]}/api/v2/app/setPreferences?json=%7B%22listen_port%22:%20#{pia_port}%7D")
  http = Net::HTTP.new(uri.host, uri.port)
  req =  Net::HTTP::Get.new(uri)
  req.add_field "Cookie", sid
  http.request(req)
rescue StandardError => e
  @logger.error("qbt_app_setPreferences - HTTP Request failed - (#{e.message})")
end
# ----------

# DO SOME WORK!
# populate config hash
get_config

# get pia token and port, and then bind port
get_pia_token
get_pia_port
bind_port

# get sid from qbit
sid = qbt_auth_login

# get existing port from qbit
qbt_port = qbt_app_preferences(sid)

# if qbit port doesn't match the pia port, update qbit
if qbt_port != @config[:port]
  response = qbt_app_setPreferences(sid, @config[:port])
  if response.code == "200"
    @logger.info("qbit's port has been updated to #{@config[:port]}")
  else
    @logger.error("qbit's port was not updated")
  end
end
# ----------


# CLEAN HOUSE
# write config hash to auto_config for the next run
write_config

# close out the logger
@logger.info("qbt_pia_port_forwarder completed at #{Time.now}")
@logger.info("----------------")
@logger.close
# ----------
