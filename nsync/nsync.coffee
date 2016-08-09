RemoteFileSystem = require('./remote-file-system')

module.exports = nsync =
  activate: ->
    nsync.setProject()

    remoteFS = new RemoteFileSystem(atom.project.getPaths()[0])
    atom.learnIDE = {remoteFS}

  deactive: ->
    nsync.resetProjects()

  setProject: ->
    @projectPaths = atom.project.getPaths()
    @projectPaths.forEach (path) -> atom.project.removePath(path)

    atom.project.addPath('/home/drewprice/code')

  resetProjects: ->
    atom.project.getPaths().forEach (path) -> atom.project.removePath(path)
    @projectPaths.forEach (path) -> atom.project.addPath(path)
