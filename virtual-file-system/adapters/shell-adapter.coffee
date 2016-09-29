module.exports =
class ShellAdapter
  constructor: (@virtualFileSystem) ->
    # noop

  moveItemToTrash: (path) ->
    @virtualFileSystem.rm(path)
    true

