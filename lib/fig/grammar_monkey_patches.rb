# The existence of this &!#%)(*!&% file makes me want to hurl, but it's the
# simplest way to modify the classes generated by Treetop: the Treetop grammar
# doesn't allow extensions at the grammar level, only the rule level.

require 'fig/grammar/v0'
require 'fig/grammar/v1'
require 'fig/grammar/v2'
require 'fig/grammar/v3'

module Fig; end
module Fig::Grammar; end

class Fig::Grammar::V0Parser
  def version()
    return 0
  end
end

class Fig::Grammar::V1Parser
  def version()
    return 1
  end
end

class Fig::Grammar::V2Parser
  def version()
    return 2
  end
end

class Fig::Grammar::V3Parser
  def version()
    return 3
  end
end
