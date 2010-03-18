require 'sinatra.validate'

Sinatra::Application.disable :run

use Rack::Static, :urls => ["/public/javascripts/MathJax", "tests"], :root => File.dirname(__FILE__) 

run Sinatra::Application

