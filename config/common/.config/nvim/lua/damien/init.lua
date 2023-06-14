require('damien.base16')
require('damien.settings')
require('damien.mappings')

-- Install plugins last to make sure that things like mapping are set before they get a chance to
-- get the incorrect ones...
require('damien.packer')
