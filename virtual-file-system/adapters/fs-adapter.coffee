fs = require 'fs-plus'

module.exports =
class FSAdapter
  constructor: (@virtualFileSystem) ->
    # noop

  existsSync: (path) ->
    @virtualFileSystem.hasPath(path)

  isBinaryExtension: (ext) ->
    fs.isBinaryExtension(ext)

  isCaseInsensitive: ->
    fs.isCaseInsensitive()

  isCompressedExtension: (ext) ->
    fs.isCompressedExtension(ext)

  isDirectorySync: (path) ->
    @virtualFileSystem.isDirectory(path)

  isFileSync: (path) ->
    @virtualFileSystem.isFile(path)

  isImageExtension: (ext) ->
    fs.isImageExtension(ext)

  isPdfExtension: (ext) ->
    fs.isPdfExtension(ext)

  isReadmePath: (path) ->
    fs.isReadmePath(path)

  isSymbolicLinkSync: (path) ->
    @virtualFileSystem.isSymbolicLink(path)

  lstatSyncNoException: (path) ->
    @virtualFileSystem.lstat(path)

  listSync: (path, extensions) ->
    @virtualFileSystem.list(path, extensions)

  readFileSync: (path) ->
    @virtualFileSystem.read(path)

  readdirSync: (path) ->
    @virtualFileSystem.readdir(path)

  realpathSync: (path) ->
    @virtualFileSystem.realpath(path)

  realpath: (path) ->
    @virtualFileSystem.realpath(path)

  statSync: (path) ->
    @virtualFileSystem.stat(path) or
      throw new Error("No virtual entry (file or directory) could be found by the given path '#{path}'")

  statSyncNoException: (path) ->
    @virtualFileSystem.stat(path)

  absolute: -> # currently used only in spec
    atom.notifications.addWarning('Unadapted fs function', detail: 'absolute')

  copy: (source, destination) ->
    @virtualFileSystem.cp(source, destination)

  copySync: (source, destination) ->
    @virtualFileSystem.cp(source, destination)

  makeTreeSync: (path) ->
    @virtualFileSystem.mkdirp(path)

  moveSync: (source, destination) ->
    @virtualFileSystem.mv(source, destination)

  writeFileSync: (path) ->
    @virtualFileSystem.touch(path)

  mkdirSync: -> # currently used only in spec
    atom.notifications.addWarning('Unadapted fs function', detail: 'mkdirSync')

  removeSync: -> # currently used only in spec
    atom.notifications.addWarning('Unadapted fs function', detail: 'removeSync')

  symlinkSync: -> # currently used only in spec
    atom.notifications.addWarning('Unadapted fs function', detail: 'symlinkSync')

