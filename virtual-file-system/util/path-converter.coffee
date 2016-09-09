_path = require 'path'

class PathConverter
  constructor: (@localRoot, @remotePlatform = 'posix') ->

  configure: ({localRoot, remotePlatform}) ->
    @localRoot = localRoot if localRoot?
    @remotePlatform = remotePlatform if remotePlatform?

  localToRemote: (localPath) ->
    remotePath = localPath.replace(@localRoot, '')

    if _path.sep isnt _path[@remotePlatform].sep
      remotePath = remotePath.split(_path.sep).join(_path[@remotePlatform].sep)

    remotePath

  remoteToLocal: (remotePath) ->
    if _path.sep isnt _path[@remotePlatform].sep
      remotePath = remotePath.split(_path[@remotePlatform].sep).join(_path.sep)

    _path.join(@localRoot, remotePath)

module.exports = new PathConverter

