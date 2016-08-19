RemoteFileOpener = require './remote-file-opener'

module.exports = nsync =
  activate: (remoteFS) ->
    @removeProjects()
    global.learnIDE ?= {}
    learnIDE.remoteFS ?= remoteFS

    atom.workspace.addOpener (uri) =>
      @open(uri) if learnIDE.remoteFS.hasPath(uri)

  deactivate: ->
    learnIDE.remoteFS = undefined

  removeProjects: ->
    @projectPaths ?= atom.project.getPaths()
    @projectPaths.forEach (path) -> atom.project.removePath(path)

  setProject: (rootPath) ->
    @removeProjects()
    atom.project.addPath(rootPath)

  resetProjects: ->
    atom.project.getPaths().forEach (path) -> atom.project.removePath(path)
    @projectPaths?.forEach (path) -> atom.project.addPath(path)

  refreshTree: (path, parent) ->
    learnIDE.treeView.entryForPath(parent)?.reload?()
    learnIDE.treeView.selectEntryForPath(path)

  open: (path) ->
    stat = learnIDE.remoteFS.getStat(path)
    (new RemoteFileOpener(stat)).open()

