require 'json'
require 'net/http'
require 'net/https'
require 'securerandom'
require 'socket'
require 'yaml'
require 'logger'

@logger = Logger.new('qbt_pia.log', 10, 1024000)
config = YAML.load_file("config.yml")

QBT_USERNAME = config[:qbt_username].freeze
QBT_PASSWORD = config[:qbt_password].freeze
QBT_ADDR = config[:qbt_addr].freeze # ex. http://10.0.1.48:8080

PIA_USERNAME = config[:pia_username].freeze
PIA_PASSWORD = config[:pia_password].freeze
PIA_LOCAL_IP = Socket.getifaddrs.detect {|intf| !intf.addr.nil? && intf.addr.ip? && !intf.addr.ipv6? && intf.name.include?("tun")}.addr.ip_address

DAYS_TO_KEEP_PORT = config[:days_to_keep_port].freeze

def create_new_client_id_file
  @pia_client_id = SecureRandom.hex(32)
  File.open("client_id.yml", "w") do |out|
    client_id = {:client_id => @pia_client_id, :created => Time.now}
    YAML.dump(client_id, out)
  end
end

if File.exist?("client_id.yml")
  client_id_config = YAML.load_file("client_id.yml")
  created = client_id_config[:created]

  if (Time.now - created) > (60 * 60 * 24 * DAYS_TO_KEEP_PORT)
    create_new_client_id_file
  else
    @pia_client_id = client_id_config[:client_id]
  end
else
  create_new_client_id_file
end
# ----------

# PIA METHODS
def port_forward_assignment
  uri = URI("https://www.privateinternetaccess.com/vpninfo/port_forward_assignment?user=#{PIA_USERNAME}&pass=#{PIA_PASSWORD}&client_id=#{@pia_client_id}&local_ip=#{PIA_LOCAL_IP}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  req =  Net::HTTP::Post.new(uri)
  http.request(req)
rescue StandardError => e
  @logger.error("HTTP Request failed (#{e.message})")
  puts "HTTP Request failed (#{e.message})"
end
# ----------

# QBITTORRENT METHODS
def qbt_auth_login
  uri = URI("#{QBT_ADDR}/api/v2/auth/login?username=#{QBT_USERNAME}&password=#{QBT_PASSWORD}")
  http = Net::HTTP.new(uri.host, uri.port)
  req =  Net::HTTP::Get.new(uri)
  http.request(req)
rescue StandardError => e
  @logger.error("HTTP Request failed (#{e.message})")
  puts "HTTP Request failed (#{e.message})"
end

def qbt_app_preferences(sid)
  uri = URI("#{QBT_ADDR}/api/v2/app/preferences")
  http = Net::HTTP.new(uri.host, uri.port)
  req =  Net::HTTP::Get.new(uri)
  req.add_field "Cookie", sid
  http.request(req)
rescue StandardError => e
  @logger.error("HTTP Request failed (#{e.message})")
  puts "HTTP Request failed (#{e.message})"
end

def qbt_app_setPreferences(sid, pia_port)
  uri = URI("#{QBT_ADDR}/api/v2/app/setPreferences?json=%7B%22listen_port%22:%20#{pia_port}%7D")
  http = Net::HTTP.new(uri.host, uri.port)
  req =  Net::HTTP::Get.new(uri)
  req.add_field "Cookie", sid
  http.request(req)
rescue StandardError => e
  @logger.error("HTTP Request failed (#{e.message})")
  puts "HTTP Request failed (#{e.message})"
end
# ----------

# get sid from qbt
sid = qbt_auth_login["set-cookie"].split(";")[0]

# get existing port from qbt
qbt_port = JSON.parse(qbt_app_preferences(sid).body)["listen_port"]
@logger.info("current qbt port: #{qbt_port}")
puts "current qbt port: #{qbt_port}"

# get port from pia
pia_port = JSON.parse(port_forward_assignment.body)["port"]
@logger.info("pia port: #{pia_port}")
puts "pia port: #{pia_port}"

# set new port in qbt
if pia_port != qbt_port
  response = qbt_app_setPreferences(sid, pia_port)
  @logger.info("qbt port changed to #{pia_port} (response status: #{response.code}: #{response.message})")
  puts "qbt port changed to #{pia_port} (response status: #{response.code}: #{response.message})"
end

@logger.close
