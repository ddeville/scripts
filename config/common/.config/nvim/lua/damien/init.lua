require('damien.settings')
require('damien.mappings')

-- Install plugins after settings and mappings to make sure that plugins don't end up using wrong ones...
require('damien.lazy')

require('damien.base16')
