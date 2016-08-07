{CompositeDisposable} = require 'event-kit'
FileIcons = require './file-icons'

module.exports =
class FileView extends HTMLElement
  initialize: (@file) ->
    @subscriptions = new CompositeDisposable()
    @subscriptions.add @file.onDidDestroy => @subscriptions.dispose()

    @draggable = true

    @classList.add('file', 'entry', 'list-item')

    @fileName = document.createElement('span')
    @fileName.classList.add('name', 'icon')
    @appendChild(@fileName)
    @fileName.textContent = @file.name
    @fileName.title = @file.name
    @fileName.dataset.name = @file.name
    @fileName.dataset.path = @file.path

    iconClass = FileIcons.getService().iconClassForPath(@file.path)
    if iconClass
      unless Array.isArray iconClass
        iconClass = iconClass.toString().split(/\s+/g)
      @fileName.classList.add(iconClass...)

    @subscriptions.add @file.onDidStatusChange => @updateStatus()
    @updateStatus()

  updateStatus: ->
    @classList.remove(
      'status-added', 'status-updated',
      'status-unmerged', 'status-changed','status-untracked',
      'status-conflicted', 'status-unmodified', 'status-ignored')
    @classList.add.apply(@classList, @file.statuses.map (s) -> "status-#{s}")

  getPath: ->
    @fileName.dataset.path

  isPathEqual: (pathToCompare) ->
    @file.isPathEqual(pathToCompare)

module.exports = document.registerElement('tree-view-file', prototype: FileView.prototype, extends: 'li')
