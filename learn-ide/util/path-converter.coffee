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

  remoteMessage: (msg) ->
    converted = {}

    for own key, value of msg
      if typeof value is 'string' and value.startsWith(@localRoot)
        converted[key] = @localToRemote(value)
      else
        converted[key] = value

    converted

  remoteEntries: (remoteEntries, virtualFileObject) ->
    virtualEntries = {}

    for own remotePath, attributes of remoteEntries
      localPath = @remoteToLocal(remotePath)
      virtualEntries[localPath] = new virtualFileObject(attributes)

    virtualEntries

  addDigestToEntries: (remoteEntries, virtualEntries) ->
    for own remotePath, digest of remoteEntries
      virtualFile = virtualEntries[@remoteToLocal(remotePath)]
      virtualFile.addDigest(digest)

  addContentToEntries: (remoteEntries, virtualEntries) ->
    for own remotePath, contents of remoteEntries
      virtualFile = virtualEntries[@remoteToLocal(remotePath)]
      virtualFile.addContent(digest)

