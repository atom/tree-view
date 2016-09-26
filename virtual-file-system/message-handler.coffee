fs = require 'fs-plus'
_ = require 'underscore-plus'
shell = require 'shell'
FileSystemNode = require './file-system-node'

module.exports =
class MessageHandler
  constructor: (event, @virtualFileSystem) ->
    message = event.data

    try
      {type, data} = JSON.parse(message)
      console.log 'RECEIVED:', type
    catch err
      console.error 'ERROR PARSING MESSAGE:', err

    if not @[type]
      console.error "Unhandled message type: #{type}"
    else
      @[type](data)

  init: ({virtualFile}) ->
    vfs = @virtualFileSystem
    vfs.projectNode = new FileSystemNode(virtualFile)
    vfs.atomHelper.updateProject(vfs.projectNode.localPath(), vfs.expansionState())
    vfs.activationState = undefined
    vfs.sync(vfs.projectNode.path)

  sync: ({path, pathAttributes}) ->
    console.log 'SYNC:', path
    node = @virtualFileSystem.getNode(path)
    localPath = node.localPath()

    node.traverse (entry) ->
      entry.setDigest(pathAttributes[entry.path])

    if fs.existsSync(localPath)
      existingRemotePaths = node.map (e) -> e.localPath()
      existingLocalPaths = fs.listTreeSync(localPath)
      localPathsToRemove = _.difference(existingLocalPaths, existingRemotePaths)
      localPathsToRemove.forEach (path) -> shell.moveItemToTrash(path)

    node.findPathsToSync().then (paths) => @virtualFileSystem.fetch(paths)

  change: ({event, path, virtualFile}) ->
    console.log "#{event.toUpperCase()}:", path
    projectNode = @virtualFileSystem.projectNode

    node =
      switch event
        when 'moved_from', 'delete'
          projectNode.remove(path)
        when 'moved_to', 'create'
          projectNode.add(virtualFile)
        when 'close_write'
          projectNode.update(virtualFile)
        else
          console.log 'UNKNOWN CHANGE:', event, path

    return unless node?

    parent = node.parent
    atomHelper = @virtualFileSystem.atomHelper
    atomHelper.reloadTreeView(parent.localPath(), node.localPath())
    atomHelper.updateTitle()

    if event is 'close_write'
      unless atomHelper.saveEditorForPath(node.localPath())
        node.determineSync().then (shouldSync) =>
          if shouldSync
            @virtualFileSystem.fetch(node.path)

  open: (data) ->
    @fetch(data)

  fetch: ({path, content}) ->
    node = @virtualFileSystem.getNode(path)
    parent = node.parent
    stats = node.stats
    contentBuffer = new Buffer(content or '', 'base64')

    if stats.isDirectory()
      return fs.makeTree(node.localPath())

    fs.makeTree parent.localPath(), ->
      fs.writeFile node.localPath(), contentBuffer, {mode: stats.mode}, (err) ->
        if err?
          return console.error "WRITE ERR", err

  error: ({event, error}) ->
    console.log 'Error:', event, error

