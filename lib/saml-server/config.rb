module SamlServer
  Config = Struct.new(:service_providers, :users, :auth, :attributes)
  User = Struct.new(:username, :password)
  SampleSp = Struct.new(:name, :url)

  class << self
    attr_reader :config
  end
  @config = Config.new([], [])

  # Return a user object if user/pass is valid
  self.config.auth = proc do |username, password, request|
    users = SamlServer.config.users
    if users.nil? or users.empty? then
      nil
    else
      users.detect { |user| username && user.username == username && user.password == password }
    end
  end

  # Returns a Hash of attributes about the user, to be passed along in the SAML response (or nil)
  self.config.attributes = proc do |username|
    nil
  end

  # Add a user and password for SAML authentication
  def self.add_user(username, password)
    if username.kind_of? User then
      self.config.users << username
      return
    end
    self.config.users << User.new(username, password)
  end

  # Add a service provider to the portal
  def self.add_sp(name, url)
    self.config.service_providers << SampleSp.new(name, url)
  end
end
