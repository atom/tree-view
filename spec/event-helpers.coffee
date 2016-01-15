{$} = require 'atom-space-pen-views'

module.exports.buildInternalDragEvents = (dragged, enterTarget, dropTarget) ->
  dataTransfer =
    data: {}
    setData: (key, value) -> @data[key] = "#{value}" # Drag events stringify data values
    getData: (key) -> @data[key]
    setDragImage: (@image) -> return

  dragStartEvent = $.Event()
  dragStartEvent.target = dragged
  dragStartEvent.currentTarget = dragged
  dragStartEvent.originalEvent = {dataTransfer}

  dropEvent = $.Event()
  dropEvent.target = dropTarget
  dropEvent.currentTarget = dropTarget
  dropEvent.originalEvent = {dataTransfer}

  dragEnterEvent = $.Event()
  dragEnterEvent.target = enterTarget
  dragEnterEvent.currentTarget = enterTarget
  dragEnterEvent.originalEvent = {dataTransfer}

  [dragStartEvent, dragEnterEvent, dropEvent]

module.exports.buildExternalDropEvent = (filePaths, dropTarget) ->
  dataTransfer =
    data: {}
    setData: (key, value) -> @data[key] = "#{value}" # Drag events stringify data values
    getData: (key) -> @data[key]
    files: []

  dropEvent = $.Event()
  dropEvent.target = dropTarget
  dropEvent.currentTarget = dropTarget
  dropEvent.originalEvent = {dataTransfer}

  for filePath in filePaths
    dropEvent.originalEvent.dataTransfer.files.push({path: filePath})

  dropEvent