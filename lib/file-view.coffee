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
    @fileName.dataset.name = @file.name
    @fileName.dataset.path = @file.path
    @setupTooltip();

    @fileName.classList.add(FileIcons.getService().iconClassForPath(@file.path))

    @subscriptions.add @file.onDidStatusChange => @updateStatus()
    @updateStatus()

  updateStatus: ->
    @classList.remove('status-ignored', 'status-modified',  'status-added')
    @classList.add("status-#{@file.status}") if @file.status?

  getPath: ->
    @fileName.dataset.path

  isPathEqual: (pathToCompare) ->
    @file.isPathEqual(pathToCompare)

  setupTooltip: ->
    onMouseEnter = =>
      @mouseEnterSubscription.dispose()
      @tooltip = atom.tooltips.add this,
        title: @file.name
        html: false
        delay:
          show: 1000
          hide: 100
        placement: 'bottom'
      @dispatchEvent(new CustomEvent('mouseenter', bubbles: true))

    @mouseEnterSubscription = dispose: =>
      @removeEventListener('mouseenter', onMouseEnter)
      @mouseEnterSubscription = null

    @addEventListener('mouseenter', onMouseEnter)

module.exports = document.registerElement('tree-view-file', prototype: FileView.prototype, extends: 'li')
