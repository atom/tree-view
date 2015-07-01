path = require "path"

module.exports =
  repoForPath: (goalPath) ->
    if atom.project
      for projectPath, i in atom.project.getPaths()
        if goalPath is projectPath or goalPath.indexOf(projectPath + path.sep) is 0
          return atom.project.getRepositories()[i]
    null

  relativizePath: (goalPath) ->
    if atom.project
      for projectPath in atom.project.getPaths()
        if goalPath is projectPath or goalPath.indexOf(projectPath + path.sep) is 0
          return [projectPath, path.relative(projectPath, goalPath)]
    [null, goalPath]
