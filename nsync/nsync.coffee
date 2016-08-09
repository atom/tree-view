RemoteFileSystem = require('./remote-file-system')

module.exports = nsync =
  activate: ->
    @removeProjects()

    remoteFS = new RemoteFileSystem()
    atom.learnIDE = {remoteFS}

  deactive: ->
    @resetProjects()

  removeProjects: ->
    @projectPaths = atom.project.getPaths()
    @projectPaths.forEach (path) -> atom.project.removePath(path)

  resetProjects: ->
    atom.project.getPaths().forEach (path) -> atom.project.removePath(path)
    @projectPaths.forEach (path) -> atom.project.addPath(path)
