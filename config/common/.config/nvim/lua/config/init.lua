require('config.ft')
require('config.mappings')

-- Install plugins after mappings to make sure that plugins don't end up using old wrong ones...
require('config.lazy')

require('config.settings')
