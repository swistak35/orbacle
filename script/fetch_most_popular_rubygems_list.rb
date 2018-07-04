require 'net/http'
require 'uri'
require 'openssl'
require 'nokogiri'
require 'json'

stats = []

(0...100).each do |page|
  uri = URI.parse("https://rubygems.org/stats?page=#{page}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  puts "Requesting page #{page}..."
  request = Net::HTTP::Get.new(uri.request_uri)
  response = http.request(request)
  raw_body = response.body
  body = Nokogiri::HTML(raw_body)
  gem_nodes = body.css(".stats__graph__gem")
  gem_nodes.each do |gem_node|
    gem_name = gem_node.css(".stats__graph__gem__name a")[0].text
    gem_downloads = gem_node.css(".stats__graph__gem__count")[0].text.delete(",").to_i
    stats << { name: gem_name, downloads: gem_downloads }
  end
  sleep 1
end

File.open("script/stats.json", "w") do |f|
  f.write(JSON.pretty_generate(stats))
end
