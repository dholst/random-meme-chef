actions :run

attribute :message, :kind_of => String
attribute :color
attribute :notify

def initialize(message, run_context=nil)
  super
  @action = :run
  @message = message
  @color = :purple
  @notify = false
end
