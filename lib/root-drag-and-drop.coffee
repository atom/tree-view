url = require 'url'

{ipcRenderer, remote} = require 'electron'

{$, View} = require 'atom-space-pen-views'
_ = require 'underscore-plus'

module.exports =
class RootDragAndDropHandler
  constructor: (@treeView) ->
    ipcRenderer.on('tree-view:project-folder-dropped', @onDropOnOtherWindow)
    @handleEvents()

  dispose: ->
    ipcRenderer.removeListener('tree-view:project-folder-dropped', @onDropOnOtherWindow)

  handleEvents: ->
    # onDragStart is called directly by TreeView's onDragStart
    # will be cleaned up by tree view, since they are tree-view's handlers
    @treeView.on 'dragenter', '.tree-view', @onDragEnter
    @treeView.on 'dragend', '.project-root-header', @onDragEnd
    @treeView.on 'dragleave', '.tree-view', @onDragLeave
    @treeView.on 'dragover', '.tree-view', @onDragOver
    @treeView.on 'drop', '.tree-view', @onDrop

  onDragStart: (e) =>
    @prevDropTargetIndex = null
    e.originalEvent.dataTransfer.setData 'atom-tree-view-event', 'true'
    projectRoot = $(e.target).closest('.project-root')
    directory = projectRoot[0].directory

    e.originalEvent.dataTransfer.setData 'project-root-index', projectRoot.index()

    rootIndex = -1
    (rootIndex = index; break) for root, index in @treeView.roots when root.directory is directory

    e.originalEvent.dataTransfer.setData 'from-root-index', rootIndex
    e.originalEvent.dataTransfer.setData 'from-root-path', directory.path
    e.originalEvent.dataTransfer.setData 'from-window-id', @getWindowId()

    e.originalEvent.dataTransfer.setData 'text/plain', directory.path

    if process.platform in ['darwin', 'linux']
      pathUri = "file://#{directory.path}" unless @uriHasProtocol(directory.path)
      e.originalEvent.dataTransfer.setData 'text/uri-list', pathUri

  uriHasProtocol: (uri) ->
    try
      url.parse(uri).protocol?
    catch error
      false

  onDragEnter: (e) ->
    e.stopPropagation()

  onDragLeave: (e) =>
    e.stopPropagation()
    @removePlaceholder() if e.target is e.currentTarget

  onDragEnd: (e) =>
    e.stopPropagation()
    @clearDropTarget()

  onDragOver: (e) =>
    unless e.originalEvent.dataTransfer.getData('atom-tree-view-event') is 'true'
      return

    e.preventDefault()
    e.stopPropagation()

    entry = e.currentTarget

    if @treeView.roots.length is 0
      @getPlaceholder().appendTo(@treeView.list)
      return

    newDropTargetIndex = @getDropTargetIndex(e)
    return unless newDropTargetIndex?
    return if @prevDropTargetIndex is newDropTargetIndex
    @prevDropTargetIndex = newDropTargetIndex

    projectRoots = $(@treeView.roots)

    if newDropTargetIndex < projectRoots.length
      element = projectRoots.eq(newDropTargetIndex)
      element.addClass 'is-drop-target'
      @getPlaceholder().insertBefore(element)
    else
      element = projectRoots.eq(newDropTargetIndex - 1)
      element.addClass 'drop-target-is-after'
      @getPlaceholder().insertAfter(element)

  onDropOnOtherWindow: (e, fromItemIndex) =>
    paths = atom.project.getPaths()
    paths.splice(fromItemIndex, 1)
    atom.project.setPaths(paths)

    @clearDropTarget()

  clearDropTarget: ->
    element = @treeView.find(".is-dragging")
    element.removeClass 'is-dragging'
    element[0]?.updateTooltip()
    @removePlaceholder()

  onDrop: (e) =>
    e.preventDefault()
    e.stopPropagation()

    {dataTransfer} = e.originalEvent

    # TODO: support dragging folders from the filesystem -- electron needs to add support first
    return unless dataTransfer.getData('atom-tree-view-event') is 'true'

    fromWindowId = parseInt(dataTransfer.getData('from-window-id'))
    fromRootPath  = dataTransfer.getData('from-root-path')
    fromIndex     = parseInt(dataTransfer.getData('project-root-index'))
    fromRootIndex = parseInt(dataTransfer.getData('from-root-index'))

    toIndex = @getDropTargetIndex(e)

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

  getDropTargetIndex: (e) ->
    target = $(e.target)

    return if @isPlaceholder(target)

    projectRoots = $(@treeView.roots)
    projectRoot = target.closest('.project-root')
    projectRoot = projectRoots.last() if projectRoot.length is 0

    return 0 unless projectRoot.length

    center = projectRoot.offset().top + projectRoot.height() / 2

    if e.originalEvent.pageY < center
      projectRoots.index(projectRoot)
    else if projectRoot.next('.project-root').length > 0
      projectRoots.index(projectRoot.next('.project-root'))
    else
      projectRoots.index(projectRoot) + 1

  canDragStart: (e) ->
    $(e.target).closest('.project-root-header').size() > 0

  isDragging: (e) ->
    Boolean e.originalEvent.dataTransfer.getData 'from-root-path'

  getPlaceholder: ->
    @placeholderEl ?= $('<li/>', class: 'placeholder')

  removePlaceholder: ->
    @placeholderEl?.remove()
    @placeholderEl = null

  isPlaceholder: (element) ->
    element.is('.placeholder')

  getWindowId: ->
    @processId ?= atom.getCurrentWindow().id
