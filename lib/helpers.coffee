path = require "path"

module.exports =
  repoForPath: (goalPath) ->
    for projectPath, i in atom.project.getPaths()
      if goalPath is projectPath or goalPath.indexOf(projectPath + path.sep) is 0
        return atom.project.getRepositories()[i]
    null
