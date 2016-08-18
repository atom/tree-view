fs = require 'fs-plus'

isPathValid = (path) -> path? and typeof path is 'string' and path.length > 0

module.exports = fsOverride =
  # TODO: make synchronous where necessary

  copy: (source, destination) ->
    learnIDE.remoteFS.cp(source, destination)

  copySync: (source, destination) ->
    learnIDE.remoteFS.cp(source, destination)

  existsSync: (path) ->
    isPathValid(path) and learnIDE.remoteFS.hasPath(path)

  isBinaryExtension: (ext) ->
    fs.isBinaryExtension(ext)

  isCaseInsensitive: ->
    false

  isCompressedExtension: (ext) ->
    fs.isCompressedExtension(ext)

  isDirectorySync: (path) ->
    stat = learnIDE.remoteFS.getStat(path)
    stat.isDirectory()

  isFileSync: (path) ->
    stat = learnIDE.remoteFS.getStat(path)
    stat.isFile()

  isImageExtension: (ext) ->
    fs.isImageExtension(ext)

  isPdfExtension: (ext) ->
    fs.isPdfExtension(ext)

  isReadmePath: (path) ->
    fs.isReadmePath(path)

  isSymbolicLinkSync: (path) ->
    stat = learnIDE.remoteFS.getStat(path)
    stat.isSymbolicLink()

  lstatSyncNoException: (path) ->
    learnIDE.remoteFS.getStat(path)

  listSync: (path, extensions) ->
    stat = learnIDE.remoteFS.getStat(path)
    stat.list(extensions)

  makeTreeSync: (path) ->
    learnIDE.remoteFS.mkdirp(path)

  moveSync: (source, destination) ->
    learnIDE.remoteFS.mv(source, destination)

  readFileSync: (path) ->
    stat = learnIDE.remoteFS.getStat(path)

  readdirSync: (path) ->
    stat = learnIDE.remoteFS.getStat(path)
    stat.entries

  realpathSync: (path) ->
    learnIDE.remoteFS.realpath(path)

  realpath: (path) ->
    learnIDE.remoteFS.realpath(path)

  statSync: ->
    atom.notifications.addWarning('Unimplemented fs-override', detail: 'statSync')

  statSyncNoException: ->
    atom.notifications.addWarning('Unimplemented fs-override', detail: 'statSyncNoException')

  writeFileSync: (path) ->
    learnIDE.remoteFS.touch(path)

  absolute: -> # currently used only in spec
    atom.notifications.addWarning('Unimplemented fs-override', detail: 'absolute')

  mkdirSync: -> # currently used only in spec
    atom.notifications.addWarning('Unimplemented fs-override', detail: 'mkdirSync')

  removeSync: -> # currently used only in spec
    atom.notifications.addWarning('Unimplemented fs-override', detail: 'removeSync')

  symlinkSync: -> # currently used only in spec
    atom.notifications.addWarning('Unimplemented fs-override', detail: 'symlinkSync')

