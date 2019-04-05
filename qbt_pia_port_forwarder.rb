require 'json'
require 'net/http'
require 'net/https'
require 'securerandom'
require 'socket'

# CONFIG

# add your qbt credentials and ip address here
QBT_USERNAME = "".freeze
QBT_PASSWORD = "".freeze
QBT_ADDR = "".freeze

# add your pia credentials here
PIA_USERNAME = "".freeze
PIA_PASSWORD = "".freeze
PIA_LOCAL_IP = Socket.getifaddrs.detect {|intf| !intf.addr.nil? && intf.addr.ip? && !intf.addr.ipv6? && intf.name.include?("tun")}.addr.ip_address

if File.exist?("pia_client_id_file.txt")
  f = File.open("pia_client_id_file.txt", "r")
  f.each_line do |line|
    PIA_CLIENT_ID = line.strip
  end
  f.close
else
  PIA_CLIENT_ID = SecureRandom.hex(32)
  f = File.open("pia_client_id_file.txt", "w")
  f.puts PIA_CLIENT_ID
  f.close
end
# ----------

# PIA METHODS
def port_forward_assignment
  uri = URI("https://www.privateinternetaccess.com/vpninfo/port_forward_assignment?user=#{PIA_USERNAME}&pass=#{PIA_PASSWORD}&client_id=#{PIA_CLIENT_ID}&local_ip=#{PIA_LOCAL_IP}")

  # Create client
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER

  # Create Request
  req =  Net::HTTP::Post.new(uri)

  # Fetch Request
  http.request(req)
rescue StandardError => e
  puts "HTTP Request failed (#{e.message})"
end
# ----------

# QBITTORRENT METHODS
def qbt_auth_login
  uri = URI("#{QBT_ADDR}/api/v2/auth/login?username=#{QBT_USERNAME}&password=#{QBT_PASSWORD}")

  # Create client
  http = Net::HTTP.new(uri.host, uri.port)

  # Create Request
  req =  Net::HTTP::Get.new(uri)

  # Fetch Request
   http.request(req)
rescue StandardError => e
  puts "HTTP Request failed (#{e.message})"
end

def qbt_app_preferences(sid)
  uri = URI("#{QBT_ADDR}/api/v2/app/preferences")

  # Create client
  http = Net::HTTP.new(uri.host, uri.port)

  # Create Request
  req =  Net::HTTP::Get.new(uri)

  # Add headers
  req.add_field "Cookie", sid

  # Fetch Request
  http.request(req)
rescue StandardError => e
  puts "HTTP Request failed (#{e.message})"
end

def qbt_app_setPreferences(sid, pia_port)
  uri = URI("#{QBT_ADDR}/api/v2/app/setPreferences?json=%7B%22listen_port%22:%20#{pia_port}%7D")

  # Create client
  http = Net::HTTP.new(uri.host, uri.port)

  # Create Request
  req =  Net::HTTP::Get.new(uri)

  # Add headers
  req.add_field "Cookie", sid

  # Fetch Request
  http.request(req)
rescue StandardError => e
  puts "HTTP Request failed (#{e.message})"
end
# ----------

# get port from pia
pia_port = JSON.parse(port_forward_assignment.body)["port"]
puts "pia port: #{pia_port}"

# get sid from qbt
sid = qbt_auth_login["set-cookie"].split(";")[0]

# get existing port from qbt
qbt_port = JSON.parse(qbt_app_preferences(sid).body)["listen_port"]
puts "current qbt port: #{qbt_port}"

# set new port in qbt
if pia_port != qbt_port
  response = qbt_app_setPreferences(sid, pia_port)
  puts "qbt port changed! (response status: #{response.code}: #{response.message})"
end
