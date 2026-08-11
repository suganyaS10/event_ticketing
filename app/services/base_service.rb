class BaseService
  def self.call(...) = new(...).call

  def call
    raise NotImplementedError, "#{self.class} must implement #call"
  end
end
