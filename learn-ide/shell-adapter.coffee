module.exports =
class ShellAdapter
  constructor: (@virtualFileSystem) ->
    # noop

  moveItemToTrash: (path) ->
    @virtualFileSystem.trash(path)
    true

