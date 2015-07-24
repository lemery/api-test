require 'uri'
require 'net/http'
require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'json'

Bundler.require

get '/' do
  erb :default
end

get '/request/:name' do  
  erb :request
end

# Post requests sent here generate the actual request to be made from a JSON file in the 
# main directory of the app. JSON files must contain: 
#   - A "headers" array containing hashes of its headers, and containing 
#     "Content-Type" : "application/json"
#   - A "target_url" string containing the url the request is to be sent to
#   - A "body" hash containing whatever body content is needed (can be left
#     empty for GETs, but should exist)
post '/request/:name' do  
  # Parses the provided JSON file to produce the request
  request_file = File.read(params[:filename])
  request_data = JSON.parse(request_file)
  
  # Snags the url of the url triggering the post request. By default this will be
  # http://localhost:4567/request/:name, but this method will work when transplanted
  uri = URI.parse(URI.encode("#{request.base_url}#{request.fullpath}"))
  
  # Warning! When using this on an app that requires actual security, you must
  # make the https route actually secure. See the explanation how to at
  # http://www.rubyinside.com/how-to-cure-nethttps-risky-default-https-behavior-4010.html
  if uri.scheme == "https"
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
  http = Net::HTTP.new(uri.host, uri.port)
  # Extend this case statement when needed to allow for more request types
  case params[:name]
  when "post"
    request = Net::HTTP::Post.new(request_data["target_url"])
  when "get"
    request = Net::HTTP::Get.new(request_data["target_url"])
  when "put"
    request = Net::HTTP::Put.new(request_data["target_url"])
  end
  # Sets any headers needed
  if request_data["headers"]
    request_data["headers"].each do |header, value|
      request[header] = value
    end
  end
  request.body = request_data["body"].to_json
  response = http.request(request)
  STDERR.puts("Response Code: #{response.code}")
  
  redirect to("/success")
end

get '/success' do
  erb :success
end

# Write a JSON file and send a post to here if you want to test that this works
# This method appears to throw an error after processing the request, uncertain why,
# as it doesn't interrupt anything.
post '/testurl' do
  STDERR.puts("Hey it worked!")
  request.body.rewind
  body_contents = JSON.parse(request.body.read)
  STDERR.puts("Your params were: ")
  body_contents.each do |key, val|
    STDERR.puts("#{key.to_s} => #{val.to_s}")
  end
end

# Pull the request type from the url string
def get_request_type
  if request.path_info.include? "get"
    return "GET"
  elsif request.path_info.include? "post"
    return "POST"
  elsif request.path_info.include? "put"
    return "PUT"
  end
  # Return nil if something broke
  return nil
end
