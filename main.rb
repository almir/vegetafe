# main.rb
set :protection, :except => [:http_origin]
set :haml, :format => :html5

module Sinatra
  module GetOrPost
    def get_or_post(path, options = {}, &block)
      get(path, options, &block)
      post(path, options, &block)
    end
  end
  register GetOrPost
end

def getlines(io, out)
  while line = io.gets
    out << line << '<br />'
  end
end

get '/' do
  haml :index
end

post '/' do
  outfilename = SecureRandom.hex
  mode = params[:modes].to_s
  rate = params[:rates]
  rate.gsub!(/\s/,'')
  rate.include?(',') ? rate_stripped = rate.gsub(/,/, '') : rate_stripped = rate
  rate_int = rate_stripped.to_i unless rate_stripped.match(/[^[:digit:]]+/)
  duration = params[:duration].to_s
  ordering = params[:ordering].to_s

  if params[:file]
    filename = params[:file][:filename]
    filepath = "#{UPLOADS_PATH}/#{filename}"

    File.open(filepath, 'w') do |f|
      f.write(params[:file][:tempfile].read)
    end
  end

  if mode == 'attack' and rate.include?(',')
    haml :error, :locals => {rate: rate, filename: filename, mode: mode}
  elsif rate.nil? or rate.empty? or rate == 0
    haml :error, :locals => {rate: rate, filename: filename, mode: mode}
  elsif !rate_int.is_a?(Integer)
    haml :error, :locals => {rate: rate, filename: filename, mode: mode}
  elsif filename.nil? or filename.empty? or filename == 0
    haml :error, :locals => {rate: rate, filename: filename, mode: mode}
  else
    if duration.nil? or duration.empty? or duration == 0
      duration = '10s'
    end

    if ordering.nil? or ordering.empty? or ordering == 0
      ordering = 'random'
    end

    if mode == 'attack'
      cmd = "#{BIN_PATH}/vegeta #{mode} -duration=#{duration} -ordering=#{ordering} -targets=#{filepath} -output=#{BIN_PATH}/#{outfilename}.bin -rate=#{rate} 2>&1"
    else
      cmd = "#{BIN_PATH}/vegeta #{mode} -duration=#{duration} -ordering=#{ordering} -targets=#{filepath} -output=#{BIN_PATH}/#{outfilename}.bin -rates=#{rate} 2>&1"
    end
    stream do |out|
      IO.popen(cmd, 'r') do |io|
        # This is a dirty way of displaying a css formatted output within the html tags.
        out << '<!DOCTYPE html><html><head><title>Vegeta Load Test</title><link href="css/styles.css" rel="stylesheet"></head><body><h1>Executing Vegeta</h1><p><div id="content">'
        getlines(io, out)
        out << "</div><div class=\"button-container\"><form action=\"/results?outfilename=#{outfilename}&rates=#{rate}\" method=\"post\"><input type=\"submit\" value=\"Show results\"></form>
<form action=\"/resultsraw?outfilename=#{outfilename}\" method=\"post\"><input type=\"submit\" value=\"Show raw results\"></form></div></p></body></html>"
      end
    end
  end
end

get_or_post '/results' do
  outfilename = params[:outfilename]
  rates = params[:rates]

  %x{ #{BIN_PATH}/vegeta report -input=#{BIN_PATH}/#{outfilename}.bin -reporter=csv > #{BIN_PATH}/#{outfilename}.csv }

  results = CSV.read("#{BIN_PATH}/#{outfilename}.csv", {:headers => true, :return_headers => true, :header_converters => :symbol, :converters => :all})
  headers = results[0]
  values = results.drop(1)

  haml :results, :locals => {results: results, headers: headers, values: values, rates: rates}
end

get_or_post '/resultsraw' do
  outfilename = params[:outfilename]

  cmd = "#{BIN_PATH}/vegeta report -input=#{BIN_PATH}/#{outfilename}.bin -reporter=text 2>&1"

  stream do |out|
    IO.popen(cmd, 'r') do |io|
      # This is a dirty way of displaying a css formatted output within the html tags.
      out << '<!DOCTYPE html><html><head><title>Vegeta Load Test</title><link href="css/styles.css" rel="stylesheet"></head><body><h1>Vegeta Load Test - Raw Test Results</h1><p><div id="content">'
      getlines(io, out)
      out << '</div></p></body></html>'
    end
  end
end
