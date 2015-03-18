String.class_eval do

  def get_domain
    result = self.match(/^(http(s)?(:\/\/)?)?(www\.)?(.*\.)?(.*\.(\w{3}))/)
    result ? result[6] : nil
  end

end