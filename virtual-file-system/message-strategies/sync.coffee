_ = require 'underscore-plus'
fs = require 'fs-plus'
shell = require 'shell'

module.exports = sync = (virtualFileSystem, {path, pathAttributes}) ->
  console.log 'SYNC:', path
  node = virtualFileSystem.getNode(path)
  localPath = node.localPath()

  node.traverse (entry) ->
    entry.setDigest(pathAttributes[entry.path])

  if fs.existsSync(localPath)
    existingRemotePaths = node.map (e) -> e.localPath()
    existingLocalPaths = fs.listTreeSync(localPath)
    localPathsToRemove = _.difference(existingLocalPaths, existingRemotePaths)
    localPathsToRemove.forEach (path) -> shell.moveItemToTrash(path)

  node.findPathsToSync().then (paths) ->
    virtualFileSystem.fetch(paths)

