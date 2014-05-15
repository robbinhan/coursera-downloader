require "mechanize"
require "mechanize/http/content_disposition_parser"
require "uri"
require 'net/http'
require 'cgi'
require 'nokogiri'
require 'awesome_print'


if ARGV.size < 3
  puts "coursera-downloader.rb <username> <password> <course>"
  exit 1
end

def course_uri(course_name)
  URI("https://class.coursera.org/#{course_name}")
end

def initial_response(uri)
  Net::HTTP.get_response(uri)
end

def do_login(initial_response, username, password)
  uri = URI('https://accounts.coursera.org/api/v1/login')
  cookies = ""
  Net::HTTP.start(uri.host, uri.port,:use_ssl => uri.scheme == 'https') do |http|
    request = Net::HTTP::Post.new(uri)
    request['Cookie'] = "csrftoken=#{initial_response["Set-Cookie"].split(";")[0].split("=")[1]}"
    request["X-CSRFToken"] = initial_response["Set-Cookie"].split(";")[0].split("=")[1]
    request["Referer"] = "https://accounts.coursera.org/signin"
    request.set_form_data('email' => username, 'password' => password)
    response = http.request(request)
    cookies = response["set-cookie"]
  end

  return cookies
end

def build_cookie_string(cookies)
  cookies = CGI::Cookie.parse(cookies)
  cauth = cookies["CAUTH"]
  return "maestro_login_flag=1;#{cauth}"
end

def course_content_uri(course_name)
 URI("https://class.coursera.org/#{course_name}/lecture")
end


def get_content_site(cookie_string, course_name)
  data = ""
  uri = course_content_uri(course_name)
  Net::HTTP.start(uri.host, uri.port,:use_ssl => uri.scheme == 'https') do |http|
    request = Net::HTTP::Get.new(uri)
    request["Cookie"] = cookie_string
    response = http.request(request)
    ap data = response.body
  end

  return data
end

def get_download_links(data)
  page = Nokogiri::HTML(data)
  result = []

  page.css('div.course-lecture-item-resource').each do |div|
     div.css('a').each do |link|
      result << link.attributes['href'].value
     end
  end

  return result
end

username = ARGV[0]
password = ARGV[1]
course_name = ARGV[2]
initial_resp = initial_response(course_uri(course_name))
cookies = do_login(initial_resp, username, password)
cookie_string = build_cookie_string(cookies)
data = get_content_site(cookie_string, course_name)
links = get_download_links(data)
