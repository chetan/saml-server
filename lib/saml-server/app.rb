require 'zlib'
require 'saml_idp'
require 'sinatra/base'

module SamlServer
  class App < Sinatra::Base
    use Rack::Session::Cookie, key: 'idp.session'
    enable :inline_templates
    disable :absolute_redirects
    enable :prefixed_redirects

    helpers do
      include SamlIdp::Controller

      def current_user
        username = session[:username]
        SamlServer.config.users.detect { |user| username && user.username == username }
      end
    end

    get '/' do
      erb :index
    end

    def validate_saml_request()
      raw_saml_request = params[:SAMLRequest] || session[:SAMLRequest]
      decode_request(raw_saml_request)
      halt(401, "invalid SAML request") unless valid_saml_request?
    end

    before '/saml/auth' do
      validate_saml_request
    end

    # show login form
    get '/saml/auth' do
      session[:SAMLRequest] = params[:SAMLRequest]
      if current_user then
        # already logged in, redir back
        @saml_response = encode_response(current_user)
        erb :saml_response
      else
        erb :login
      end
    end

    post '/saml/auth' do
      user = SamlServer.config.auth.(params[:username], params[:password], request)
      if user then
        session[:username] = params[:username]
        @saml_response = encode_response(current_user)
        erb :saml_response
      else
        @errors = ["Incorrect email or password."]
        erb :login
      end
    end

    get '/saml/logout' do
      session.clear
      erb :logout
    end

    get '/saml/metadata' do
      content_type 'text/xml'
      SamlIdp.metadata.signed
    end

  end
end

__END__

@@ index
<h3>Portal</h3>
<p>Welcome, <%= current_user %></p>
<ul>
  <% SamlServer.config.service_providers.each do |sp| %>
    <li><a href="<%= sp.url %>"><%= sp.name %></a></li>
  <% end %>
</ul>
<hr />
<a href="<%= url('/saml/logout') %>">Logout</a>

@@ login
<h3>Login</h3>
<% @errors.each do |error| %>
  <p><%= error %></p>
<% end if @errors %>
<form action="<%= url('/saml/auth') %>" method="post">
  <p>
    <label for="username">Email</label>
    <input type="text" id="username" name="username" value="<%= params[:username] %>" autofocus="autofocus" />
  </p>
  <p>
    <label for="password">Password</label>
    <input type="password" id="password" name="password" />
  </p>
  <p><input type="submit" value="Login" /></p>
</form>

@@ logout
<h2>logged out</h2>

@@ saml_response
<form action="<%= saml_acs_url %>" method="post">
  <input type="hidden" name="SAMLResponse" value="<%= @saml_response %>" />
  <p>You are being signed in. If you are not redirected soon, please click <input type="submit" value="Continue" /></p>
</form>
<script>
  window.onload = function() { document.forms[0].submit() };
</script>

@@ layout
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>IdP Sandbox</title>
  </head>
  <body>
    <%= yield %>
  </body>
</html>
