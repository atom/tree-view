remoteFS = -> atom.learnIDE.remoteFS

module.exports = shellOverride =
  moveItemToTrash: (path) ->
    remoteFS().fakeDelete(path)
    true

