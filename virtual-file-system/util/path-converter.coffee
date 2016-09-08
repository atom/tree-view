_path = require 'path'

class PathManager
  constructor: (@remotePlatform = 'posix') ->
    @initialProjectPaths = atom.project.getPaths()
    @initialProjectPaths.forEach (path) -> atom.project.removePath(path)

    @localRoot = _path.join(atom.configDirPath, '.learn-ide')

  setProject: (@projectPath) ->
    atom.project.addPath(@projectPath)

  localToRemote: (localPath) ->
    remotePath = localPath.replace(@localRoot, '')

    if _path.sep isnt _path[@remotePlatform].sep
      remotePath = remotePath.split(_path.sep).join(_path[@remotePlatform].sep)

    remotePath

  remoteToLocal: (remotePath) ->
    if _path.sep isnt _path[@remotePlatform].sep
      remotePath = remotePath.split(_path[@remotePlatform].sep).join(_path.sep)

    _path.join(@localRoot, remotePath)

module.exports = new PathManager

