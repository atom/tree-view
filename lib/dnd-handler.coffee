path = require 'path'
fs = require 'fs'
{$} = require 'atom'

DirectoryView = require './directory-view'
FileView = require './file-view'

module.exports =
class DragAndDropHandler
  startPosition: null
  draggedView: null
  highlightedDirectory: null
  expandTimer: null
  dragging: false
  constructor: (@treeView) ->
    @treeView.on 'mousedown', '.entry', @onEntryMousedown

  # Private: Starts dragging an entry
  #
  # Returns noop
  onEntryMousedown: (e) =>
    return unless e.which is 1

    @startPosition = { x: e.pageX, y: e.pageY }
    $(document.body).on('mousemove', @drag)
    $(document.body).on('mouseup', @dragStopped)

    entry = $(e.currentTarget)
    @draggedView = entry.data('view')
    @draggedView.removeClass('selected')

  # Private: Stops dragging an entry
  #
  # Returns noop
  dragStopped: (e) =>
    if @dragging
      @dragging = false

      @draggingView.remove()
      @draggingView = null

      @treeView.off 'mouseover', '.directory', @highlightDirectory

      if @highlightedDirectory?
        @performDragAndDrop()

      if @expandTimer?
        clearTimeout @expandTimer
        @expandTimer = null

    $(document.body).off 'mousemove', @drag
    $(document.body).off 'mouseup', @dragStopped

  # Private: Moves the current entry, highlights hovered entry
  #
  # Returns noop
  drag: (e) =>
    currentPosition = { x: e.pageX, y: e.pageY }
    distX = Math.abs(currentPosition.x - @startPosition.x)
    distY = Math.abs(currentPosition.y - @startPosition.y)

    # Calculate distance between current point and starting point, start
    # the actual dragging when distance is large enough
    if Math.sqrt(distY ** 2 + distX ** 2) > 5 and
      not @dragging
        @startDragging(e)
    else if @dragging
      @updateDraggingViewPosition(e)

  # Private: Actually starts the dragging process. Duplicates the view, listens
  # for mouseover events on directory entries and updates the dragged
  # view position
  #
  # Returns noop
  startDragging: (e) ->
    @dragging = true

    @draggingView = @draggedView.clone()
    @draggingView.addClass('dragging')
    @treeView.list.append(@draggingView)

    @treeView.on 'mouseover', '.directory', @highlightDirectory

    @updateDraggingViewPosition(e)

  # Private: Updates the position of the currently dragged element
  #
  # Returns noop
  updateDraggingViewPosition: (e) =>
    {scroller} = @treeView
    @draggingView.css
      left: e.pageX + scroller.scrollLeft()
      top: e.pageY + scroller.scrollTop()

  # Private: Highlights the currently hovered directory
  #
  # Returns noop
  highlightDirectory: (e) =>
    directory = $(e.currentTarget)
    view = directory.view()

    # Ignore hovering the original view
    return if view is @draggedView
    # This happens when we hover the original dragging view
    return unless view?

    e.stopPropagation()

    @treeView.find('.directory').removeClass('selected')
    view.addClass('selected')

    @highlightedDirectory = view.directory

    if @expandTimer?
      clearTimeout @expandTimer
      @expandTimer = null
    @expandTimer = setTimeout =>
      @expandDirectory()
    , 1000

  # Private: Moves the currently dragged file / directory to the highlighted
  # directory
  #
  # Returns noop
  performDragAndDrop: (callback) ->
    destinationPath = @highlightedDirectory.path
    if @draggedView instanceof DirectoryView
      sourcePath = @draggedView.directory.path
      entryType = "directory"
    else if @draggedView instanceof FileView
      sourcePath = @draggedView.file.path
      entryType = "file"

    # Build full destination path
    baseName = path.basename(sourcePath)
    destinationPath = path.resolve(destinationPath, baseName)

    return if destinationPath is sourcePath

    # Make sure that path does not exist already
    fs.stat destinationPath, (err, stat) =>
      throw err if err? and err.code isnt "ENOENT"

      if stat?
        return alert "Failed to move #{entryType}: File already exists."

      # Move the file
      fs.rename sourcePath, destinationPath, (err) =>
        throw err if err?
