module.exports = shellOverride =
  moveItemToTrash: (path) ->
    learnIDE.remoteFS.fakeDelete(path)
    true

