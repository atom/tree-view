url = require 'url'

{ipcRenderer, remote} = require 'electron'

{$, View} = require 'atom-space-pen-views'
_ = require 'underscore-plus'

module.exports =
class RootDragAndDropHandler
  constructor: (@treeView) ->
    ipcRenderer.on('tree-view:project-folder-dropped', @onDropOnOtherWindow)

    # will be cleaned up by tree view
    @treeView.on 'dragend', '.project-root-header', @onDragEnd

  dispose: ->
    ipcRenderer.removeListener('tree-view:project-folder-dropped', @onDropOnOtherWindow)

  onDragStart: (event) =>
    event.originalEvent.dataTransfer.setData 'atom-event', 'true'
    projectRoot = $(event.target).closest('.project-root')
    directory = projectRoot[0].directory

    event.originalEvent.dataTransfer.setData 'project-root-index', projectRoot.index()

    rootIndex = -1
    (rootIndex = index; break) for root, index in @treeView.roots when root.directory is directory

    event.originalEvent.dataTransfer.setData 'from-root-index', rootIndex
    event.originalEvent.dataTransfer.setData 'from-root-path', directory.path
    event.originalEvent.dataTransfer.setData 'from-window-id', @getWindowId()

    event.originalEvent.dataTransfer.setData 'text/plain', directory.path

    if process.platform in ['darwin', 'linux']
      pathUri = "file://#{directory.path}" unless @uriHasProtocol(directory.path)
      event.originalEvent.dataTransfer.setData 'text/uri-list', pathUri

  uriHasProtocol: (uri) ->
    try
      url.parse(uri).protocol?
    catch error
      false

  onDragLeave: (event) =>
    @removePlaceholder()

  onDragEnd: (event) =>
    @clearDropTarget()

  onDragOver: (event) =>
    unless event.originalEvent.dataTransfer.getData('atom-event') is 'true'
      return

    entry = event.currentTarget
    if entry.classList.contains('selected')
      @clearDropTarget()
      return

    newDropTargetIndex = @getDropTargetIndex(event)
    return unless newDropTargetIndex?

    @removeDropTargetClasses()

    projectRoots = $(@treeView.roots)

    if newDropTargetIndex < projectRoots.length
      element = projectRoots.eq(newDropTargetIndex)
      element.addClass 'is-drop-target'
      @getPlaceholder().insertBefore(element)
    else
      element = projectRoots.eq(newDropTargetIndex - 1)
      element.addClass 'drop-target-is-after'
      @getPlaceholder().insertAfter(element)

  onDropOnOtherWindow: (event, fromItemIndex) =>
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

    # TODO: support dragging folders from the filesystem -- electron needs to add support first
    return unless dataTransfer.getData('atom-event') is 'true'

    fromWindowId = parseInt(dataTransfer.getData('from-window-id'))
    fromRootPath  = dataTransfer.getData('from-root-path')
    fromIndex     = parseInt(dataTransfer.getData('project-root-index'))
    fromRootIndex = parseInt(dataTransfer.getData('from-root-index'))

    toIndex = @getDropTargetIndex(event)

    @clearDropTarget()

    if fromWindowId is @getWindowId()
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

      if not isNaN(fromWindowId)
        # Let the window where the drag started know that the tab was dropped
        browserWindow = remote.BrowserWindow.fromId(fromWindowId)
        browserWindow?.webContents.send('tree-view:project-folder-dropped', fromIndex)

  removeDropTargetClasses: ->
    workspaceElement = $(atom.views.getView(atom.workspace))
    workspaceElement.find('.tree-view .is-drop-target').removeClass 'is-drop-target'
    workspaceElement.find('.tree-view .drop-target-is-after').removeClass 'drop-target-is-after'

  getDropTargetIndex: (event) ->
    target = $(event.target)

    return if @isPlaceholder(target)

    projectRoots = $(@treeView.roots)
    projectRoot = target.closest('.project-root')
    projectRoot = projectRoots.last() if projectRoot.length is 0

    return 0 unless projectRoot.length

    element = projectRoot.find('.project-root-header')

    elementCenter = element.offset().top + element.height() / 2

    if event.originalEvent.pageY < elementCenter
      projectRoots.index(projectRoot)
    else if projectRoot.next('.project-root').length > 0
      projectRoots.index(projectRoot.next('.project-root'))
    else
      projectRoots.index(projectRoot) + 1

  canDragStart: (event) ->
    $(event.target).closest('.project-root-header').size() > 0

  isDragging: (event) ->
    Boolean event.originalEvent.dataTransfer.getData 'from-root-path'

  getPlaceholder: ->
    @placeholderEl ?= $('<li/>', class: 'placeholder')

  removePlaceholder: ->
    @placeholderEl?.remove()
    @placeholderEl = null

  isPlaceholder: (element) ->
    element.is('.placeholder')

  getWindowId: ->
    @processId ?= atom.getCurrentWindow().id
