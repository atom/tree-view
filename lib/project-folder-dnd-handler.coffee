BrowserWindow = null # Defer require until actually used
RendererIpc = require 'ipc'

{$, View} = require 'atom-space-pen-views'
_ = require 'underscore-plus'

module.exports =
class ProjectFolderDragAndDropHandler
  constructor: (@treeView) ->
    @treeView.on 'dragstart', '.project-root-header', @onDragStart
    @treeView.on 'dragend', '.project-root-header', @onDragEnd
    @treeView.on 'dragleave', @onDragLeave
    @treeView.on 'dragover', @onDragOver
    @treeView.on 'drop', @onDrop

    RendererIpc.on('tree-view:project-folder-dropped', @onDropOnOtherWindow)

  # unused
  unsubscribe: ->
    RendererIpc.removeListener('tree-view:project-folder-dropped', @onDropOnOtherWindow)

  onDragStart: (event) =>
    event.originalEvent.dataTransfer.setData 'atom-event', 'true'

    element = $(event.target).closest('.project-root-header')
    projectRoot = $(event.target).closest('.project-root')
    event.originalEvent.dataTransfer.setDragImage(projectRoot[0], 0, 0)
    directory = projectRoot[0].directory

    event.originalEvent.dataTransfer.setData 'project-root-index', projectRoot.index()

    rootIndex = -1
    _.find(@treeView.roots, (root, index) -> root.directory is directory and ((rootIndex = index) or true))
    event.originalEvent.dataTransfer.setData 'from-root-index', rootIndex
    event.originalEvent.dataTransfer.setData 'from-root-path', directory.path
    event.originalEvent.dataTransfer.setData 'from-process-id', @getProcessId()
    event.originalEvent.dataTransfer.setData 'from-routing-id', @getRoutingId()

    event.originalEvent.dataTransfer.setData 'text/plain', directory.path

    if process.platform is 'darwin'
      pathUri = "file://#{directory.path}" unless @uriHasProtocol(directory.path)
      event.originalEvent.dataTransfer.setData 'text/uri-list', pathUri

  uriHasProtocol: (uri) ->
    try
      require('url').parse(uri).protocol?
    catch error
      false

  onDragLeave: (event) =>
    @removePlaceholder()

  onDragEnd: (event) =>
    @clearDropTarget()

  onDragOver: (event) =>
    unless event.originalEvent.dataTransfer.getData('atom-event') is 'true'
      event.preventDefault()
      event.stopPropagation()
      return

    event.preventDefault()
    event.stopPropagation()
    newDropTargetIndex = @getDropTargetIndex(event)
    return unless newDropTargetIndex?

    @removeDropTargetClasses()

    projectRoots = $(@treeView.roots)

    if newDropTargetIndex < projectRoots.length
      element = projectRoots.eq(newDropTargetIndex).addClass 'is-drop-target'
      @getPlaceholder().insertBefore(element)
    else
      element = projectRoots.eq(newDropTargetIndex - 1).addClass 'drop-target-is-after'
      @getPlaceholder().insertAfter(element)

  onDropOnOtherWindow: (fromItemIndex) =>
    paths = atom.project.getPaths()
    paths.splice(fromItemIndex, 1)
    atom.project.setPaths(paths)

    @clearDropTarget()

  clearDropTarget: ->
    element = @treeView.find(".is-dragging")
    element.removeClass 'is-dragging'
    element[0]?.updateTooltip()
    @removeDropTargetClasses()
    @removePlaceholder()

  onDrop: (event) =>
    event.preventDefault()
    {dataTransfer} = event.originalEvent

    return unless dataTransfer.getData('atom-event') is 'true'

    fromProcessId = parseInt(dataTransfer.getData('from-process-id'))
    fromRoutingId = parseInt(dataTransfer.getData('from-routing-id'))
    fromRootPath  = dataTransfer.getData('from-root-path')
    fromIndex     = parseInt(dataTransfer.getData('project-root-index'))
    fromRootIndex = parseInt(dataTransfer.getData('from-root-index'))

    toIndex = @getDropTargetIndex(event)

    @clearDropTarget()

    if fromProcessId is @getProcessId()
      unless fromIndex is toIndex
        projectPaths = atom.project.getPaths()
        projectPaths.splice(fromIndex, 1)
        if toIndex > fromIndex then toIndex -= 1
        projectPaths.splice(toIndex, 0, fromRootPath)
        atom.project.setPaths(projectPaths)
    else
      projectPaths = atom.project.getPaths()
      projectPaths.splice(toIndex, 0, fromRootPath)
      atom.project.setPaths(projectPaths)

      if not isNaN(fromProcessId) and not isNaN(fromRoutingId)
        # Let the window where the drag started know that the tab was dropped
        browserWindow = @browserWindowForProcessIdAndRoutingId(fromProcessId, fromRoutingId)
        browserWindow?.webContents.send('tree-view:project-folder-dropped', fromIndex)

  removeDropTargetClasses: ->
    workspaceElement = $(atom.views.getView(atom.workspace))
    workspaceElement.find('.tree-view .is-drop-target').removeClass 'is-drop-target'
    workspaceElement.find('.tree-view .drop-target-is-after').removeClass 'drop-target-is-after'

  getDropTargetIndex: (event) ->
    target = $(event.target)

    return if @isPlaceholder(target)

    projectRoots = $(@treeView.roots)
    element = target.closest('.project-root')
    element = projectRoots.last() if element.length is 0

    return 0 unless element.length

    elementCenter = element.offset().top + element.height() / 2

    if event.originalEvent.pageY < elementCenter
      projectRoots.index(element)
    else if element.next('.project-root').length > 0
      projectRoots.index(element.next('.project-root'))
    else
      projectRoots.index(element) + 1


  getPlaceholder: ->
    @placeholderEl ?= $('<li/>', class: 'placeholder')

  removePlaceholder: ->
    @placeholderEl?.remove()
    @placeholderEl = null

  isPlaceholder: (element) ->
    element.is('.placeholder')

  getProcessId: ->
    @processId ?= atom.getCurrentWindow().getProcessId()

  getRoutingId: ->
    @routingId ?= atom.getCurrentWindow().getRoutingId()

  browserWindowForProcessIdAndRoutingId: (processId, routingId) ->
    BrowserWindow ?= require('remote').require('browser-window')
    for browserWindow in BrowserWindow.getAllWindows()
      if browserWindow.getProcessId() is processId and browserWindow.getRoutingId() is routingId
        return browserWindow

    return
