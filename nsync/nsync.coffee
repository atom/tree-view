module.exports = nsync =
  activate: (remoteFS) ->
    global.learnIDE ?= {}
    learnIDE.remoteFS ?= remoteFS

  deactivate: ->
    learnIDE.remoteFS = undefined

  setProject: (rootPath) ->
    @projectPaths = atom.project.getPaths()
    @projectPaths.forEach (path) -> atom.project.removePath(path)
    atom.project.addPath(rootPath)

  resetProjects: ->
    atom.project.getPaths().forEach (path) -> atom.project.removePath(path)
    @projectPaths?.forEach (path) -> atom.project.addPath(path)

  refreshTree: (path, parent) ->
    learnIDE.treeView.entryForPath(parent)?.reload?()
    learnIDE.treeView.selectEntryForPath(path)

