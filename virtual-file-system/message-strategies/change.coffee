fs = require 'fs-plus'

changeStrategies = {
  moved_from: ({virtualFileSystem, projectNode, path}) ->
    node = projectNode.remove(path)

    # ignore weird vim write events
    return node if node.siblings().find (sibling) ->
      sibling.name is "#{node.name}.swp"

    fs.remove node.localPath(), (err) ->
      if err?
        console.error 'Unable to remove local file:', err

    node

  delete: (data) ->
    changeStrategies.moved_from(data)

  moved_to: ({virtualFileSystem, projectNode, virtualFile}) ->
    node = projectNode.add(virtualFile)
    virtualFileSystem.sync(node.path)
    node

  create: (data) ->
    changeStrategies.moved_to(data)

  close_write: ({virtualFileSystem, projectNode, virtualFile, atomHelper}) ->
    node = projectNode.update(virtualFile)

    if not atomHelper.saveEditorForPath(node.localPath())
      node.determineSync().then (shouldSync) ->
        if shouldSync
          virtualFileSystem.fetch(node.path)

    node
}

module.exports = change = (virtualFileSystem, {event, path, virtualFile}) ->
  console.log "#{event.toUpperCase()}:", path
  strategy = changeStrategies[event]
  atomHelper = virtualFileSystem.atomHelper

  if not strategy?
    return console.warn 'No strategy for change event:', event, path

  projectNode = virtualFileSystem.projectNode
  node = strategy({event, path, virtualFile, virtualFileSystem, projectNode, atomHelper})

  if not node?
    return console.warn 'Change strategy did not return node:', event, strategy

  parent = node.parent
  atomHelper.reloadTreeView(parent.localPath(), node.localPath())
  atomHelper.updateTitle()

