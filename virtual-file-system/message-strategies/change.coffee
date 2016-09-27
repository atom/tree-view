module.exports = change = (virtualFileSystem, {event, path, virtualFile}) ->
  console.log "#{event.toUpperCase()}:", path
  projectNode = virtualFileSystem.projectNode

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
  atomHelper = virtualFileSystem.atomHelper
  atomHelper.reloadTreeView(parent.localPath(), node.localPath())
  atomHelper.updateTitle()

  if event is 'close_write'
    unless atomHelper.saveEditorForPath(node.localPath())
      node.determineSync().then (shouldSync) ->
        if shouldSync
          virtualFileSystem.fetch(node.path)

