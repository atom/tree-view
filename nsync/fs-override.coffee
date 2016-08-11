fs = require 'fs-plus'

remoteFS = -> atom.learnIDE.remoteFS

isPathValid = (path) -> path? and typeof path is 'string' and path.length > 0

module.exports = fsOverride =
  # TODO: make synchronous where necessary

  copySync: (source, destination) ->
    remoteFS().cp(source, destination)

  existsSync: (path) ->
    isPathValid(path) and remoteFS().hasPath(path)

  isBinaryExtension: (ext) ->
    fs.isBinaryExtension(ext)

  isCaseInsensitive: ->
    false

  isCompressedExtension: (ext) ->
    fs.isCompressedExtension(ext)

  isDirectorySync: (path) ->
    node = remoteFS().getNode(path)
    node.isDirectory()

  isFileSync: (path) ->
    node = remoteFS().getNode(path)
    node.isFile()

  isImageExtension: (ext) ->
    fs.isImageExtension(ext)

  isPdfExtension: (ext) ->
    fs.isPdfExtension(ext)

  isReadmePath: (path) ->
    fs.isReadmePath(path)

  isSymbolicLinkSync: (path) ->
    node = remoteFS().getNode(path)
    node.isSymbolicLink()

  lstatSyncNoException: (path) ->
    node = remoteFS().getNode(path)
    node.getStat()

  listSync: (path, extensions) ->
    node = remoteFS().getNode(path)
    node.list(extensions)

  makeTreeSync: (path) ->
    remoteFS().mkdirp(path)

  moveSync: (source, destination) ->
    remoteFS().mv(source, destination)

  readFileSync: (path) ->
    node = remoteFS().getNode(path)

  readdirSync: (path) ->
    node = remoteFS().getNode(path)
    node.entries

  realpathSync: (path) ->
    remoteFS().realpath(path)

  realpath: (path) ->
    remoteFS().realpath(path)

#statSync
#statSyncNoException

  writeFileSync: (path) ->
    remoteFS().touch(path)

# These methods are used only in the spec:
#absolute
#mkdirSync
#removeSync
#symlinkSync
