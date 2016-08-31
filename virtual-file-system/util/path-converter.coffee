_path = require 'path'

module.exports =
class PathConverter
  constructor: (@localRoot, @remotePlatform = 'posix') ->
    # noop

  localToRemote: (localPath) ->
    remotePath = localPath.replace(@localRoot, '')

    if _path.sep isnt _path[@remotePlatform].sep
      remotePath = remotePath.split(_path.sep).join(_path[@remotePlatform].sep)

    remotePath

  remoteToLocal: (remotePath) ->
    if _path.sep isnt _path[@remotePlatform].sep
      remotePath = remotePath.split(_path[@remotePlatform].sep).join(_path.sep)

    _path.join(@localRoot, remotePath)

