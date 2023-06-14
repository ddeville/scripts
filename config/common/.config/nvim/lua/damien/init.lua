require('damien.mappings')

-- Install plugins after mappings to make sure that plugins don't end up using old wrong ones...
require('damien.lazy')

require('damien.settings')
require('damien.base16')
require('damien.formatters')
