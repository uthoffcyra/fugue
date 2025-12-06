-- computer startup

local completion = require('cc.shell.completion')

shell.setCompletionFunction('fugue/fugue_interp.lua',
    completion.build( completion.file ))
shell.setAlias('fe', 'fugue/fugue_interp.lua')