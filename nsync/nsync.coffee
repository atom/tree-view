fs = require 'fs-plus'
RemoteFileSystem = require './remote-file-system.coffee'

remoteFS = new RemoteFileSystem(atom.project.getPaths()[0])

isPathValid = (path) ->
  path? and typeof path is 'string' and path.length > 0

module.exports = nsync =

#absolute
#copySync

  existsSync: (path) ->
    isPathValid(path) and remoteFS.hasPath(path)

  isBinaryExtension: (ext) ->
    fs.isBinaryExtension(ext)

  isCaseInsensitive: ->
    false

  isCompressedExtension: (ext) ->
    fs.isCompressedExtension(ext)

  isDirectorySync: (path) ->
    node = remoteFS.getNode(path)
    node.isDirectory()

  isFileSync: (path) ->
    node = remoteFS.getNode(path)
    node.isFile()

  isImageExtension: (ext) ->
    fs.isImageExtension(ext)

  isPdfExtension: (ext) ->
    fs.isPdfExtension(ext)

  isReadmePath: (path) ->
    fs.isReadmePath(path)

  isSymbolicLinkSync: (path) ->
    node = remoteFS.getNode(path)
    node.isSymbolicLink()

  lstatSyncNoException: (path) ->
    node = remoteFS.getNode(path)
    node.getStat()

  listSync: (path, extensions) ->
    node = remoteFS.getNode(path)
    node.list(extensions) # TODO: return array of entries by full path, not recursive. extensions optional

#makeTreeSync
#mkdirSync
#moveSync

  readFileSync: (path) ->
    node = remoteFS.getNode(path)

  readdirSync: (path) ->
    node = remoteFS.getNode(path)
    node.entries

  realpathSync: (path) ->
    remoteFS.realpath(path) # TODO: return resolved realpath, or something?

  realpath: (path) ->
    remoteFS.realpath(path) # TODO: return resolved realpath, or something?

#removeSync
#statSync
#statSyncNoException
#symlinkSync
#writeFileSync
