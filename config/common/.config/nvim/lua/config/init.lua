require('config.mappings')

-- Install plugins after mappings to make sure that plugins don't end up using old wrong ones...
require('config.lazy')

-- base16 has to come before settings since they might change highlights that would be wrong without it...
require('config.base16')

require('config.settings')
