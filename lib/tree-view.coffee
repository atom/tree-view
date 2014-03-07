path = require 'path'
shell = require 'shell'

_ = require 'underscore-plus'
{$, ScrollView} = require 'atom'
fs = require 'fs-plus'

AddDialog = null  # Defer requiring until actually needed
MoveDialog = null # Defer requiring until actually needed

Directory = require './directory'
DirectoryView = require './directory-view'
File = require './file'
FileView = require './file-view'

module.exports =
class TreeView extends ScrollView
  @content: ->
    @div class: 'tree-view-resizer tool-panel', 'data-showOnRightSide': atom.config.get('tree-view.showOnRightSide'), =>
      @div class: 'tree-view-scroller', outlet: 'scroller', =>
        @ol class: 'tree-view list-tree has-collapsable-children focusable-panel', tabindex: -1, outlet: 'list'
      @div class: 'tree-view-resize-handle', outlet: 'resizeHandle'

  initialize: (state) ->
    super

    focusAfterAttach = false
    root = null
    scrollLeftAfterAttach = -1
    scrollTopAfterAttach = -1
    selectedPath = null

    @on 'click', '.entry', (e) => @entryClicked(e)
    @on 'mousedown', '.entry', (e) =>
      e.stopPropagation()
      @selectEntry($(e.currentTarget).view())

    @on 'mousedown', '.tree-view-resize-handle', (e) => @resizeStarted(e)
    @command 'core:move-up', => @moveUp()
    @command 'core:move-down', => @moveDown()
    @command 'tree-view:expand-directory', => @expandDirectory()
    @command 'tree-view:collapse-directory', => @collapseDirectory()
    @command 'tree-view:open-selected-entry', => @openSelectedEntry(true)
    @command 'tree-view:move', => @moveSelectedEntry()
    @command 'tree-view:add', => @add()
    @command 'tree-view:remove', => @removeSelectedEntry()
    @command 'tree-view:copy-full-path', => @copySelectedEntryPath(false)
    @command 'tree-view:copy-project-path', => @copySelectedEntryPath(true)
    @command 'tool-panel:unfocus', => @unfocus()
    @command 'tree-view:toggle-side', => @toggleSide()

    @on 'tree-view:directory-modified', =>
      if @hasFocus()
        @selectEntryForPath(@selectedPath) if @selectedPath
      else
        @selectActiveFile()

    @subscribe atom.workspaceView, 'pane-container:active-pane-item-changed', =>
      @selectActiveFile()
    @subscribe atom.project, 'path-changed', => @updateRoot()
    @subscribe atom.config.observe 'tree-view.hideVcsIgnoredFiles', callNow: false, =>
      @updateRoot()
    @subscribe atom.config.observe 'tree-view.hideIgnoredNames', callNow: false, =>
      @updateRoot()
    @subscribe atom.config.observe 'core.ignoredNames', callNow: false, =>
      @updateRoot() if atom.config.get('tree-view.hideIgnoredNames')
    @subscribe atom.config.observe 'tree-view.showOnRightSide', callNow: false, (newValue) =>
      @onSideToggled(newValue)

    @updateRoot(state.directoryExpansionStates)
    @selectEntry(@root) if @root?

    @selectEntryForPath(state.selectedPath) if state.selectedPath
    @focusAfterAttach = state.hasFocus
    @scrollTopAfterAttach = state.scrollTop if state.scrollTop
    @scrollLeftAfterAttach = state.scrollLeft if state.scrollLeft
    @width(state.width) if state.width > 0
    @attach() if state.attached

  afterAttach: (onDom) ->
    @focus() if @focusAfterAttach
    @scroller.scrollLeft(@scrollLeftAfterAttach) if @scrollLeftAfterAttach > 0
    @scrollTop(@scrollTopAfterAttach) if @scrollTopAfterAttach > 0

  serialize: ->
    directoryExpansionStates: @root?.directory.serializeExpansionStates()
    selectedPath: @selectedEntry()?.getPath()
    hasFocus: @hasFocus()
    attached: @hasParent()
    scrollLeft: @scroller.scrollLeft()
    scrollTop: @scrollTop()
    width: @width()

  deactivate: ->
    @remove()

  toggle: ->
    if @isVisible()
      @detach()
    else
      @show()

  show: ->
    @attach() unless @hasParent()
    @focus()

  attach: ->
    return unless atom.project.getPath()
    if atom.config.get('tree-view.showOnRightSide')
      atom.workspaceView.appendToRight(this)
    else
      atom.workspaceView.appendToLeft(this)

  detach: ->
    @scrollLeftAfterAttach = @scroller.scrollLeft()
    @scrollTopAfterAttach = @scrollTop()
    super
    atom.workspaceView.focus()

  focus: ->
    @list.focus()

  unfocus: ->
    atom.workspaceView.focus()

  hasFocus: ->
    @list.is(':focus')

  toggleFocus: ->
    if @hasFocus()
      @unfocus()
    else
      @show()

  entryClicked: (e) ->
    entry = $(e.currentTarget).view()
    switch e.originalEvent?.detail ? 1
      when 1
        @selectEntry(entry)
        @openSelectedEntry(false) if entry instanceof FileView
        entry.toggleExpansion() if entry instanceof DirectoryView
      when 2
        if entry.is('.selected.file')
          atom.workspaceView.getActiveView()?.focus()
        else if entry.is('.selected.directory')
          entry.toggleExpansion()

    false

  resizeStarted: =>
    $(document.body).on('mousemove', @resizeTreeView)
    $(document.body).on('mouseup', @resizeStopped)

  resizeStopped: =>
    $(document.body).off('mousemove', @resizeTreeView)
    $(document.body).off('mouseup', @resizeStopped)

  resizeTreeView: ({pageX}) =>
    w = pageX
    w = $('body').width() - w if atom.config.get('tree-view.showOnRightSide')
    @width(w)

  updateRoot: (expandedEntries={}) ->
    @root?.remove()

    if rootDirectory = atom.project.getRootDirectory()
      directory = new Directory({directory: rootDirectory, isExpanded: true, expandedEntries, isRoot: true})
      @root = new DirectoryView(directory)
      @list.append(@root)
    else
      @root = null

  getActivePath: -> atom.workspaceView.getActivePaneItem()?.getPath?()

  selectActiveFile: ->
    if activeFilePath = @getActivePath()
      @selectEntryForPath(activeFilePath)
    else
      @deselect()

  revealActiveFile: ->
    return unless atom.project.getPath()

    @attach()
    @focus()

    return unless activeFilePath = @getActivePath()

    activePathComponents = atom.project.relativize(activeFilePath).split(path.sep)
    currentPath = atom.project.getPath().replace(new RegExp("#{_.escapeRegExp(path.sep)}$"), '')
    for pathComponent in activePathComponents
      currentPath += path.sep + pathComponent
      entry = @entryForPath(currentPath)
      if entry.hasClass('directory')
        entry.expand()
      else
        centeringOffset = (@scrollBottom() - @scrollTop()) / 2
        @selectEntry(entry)
        @scrollToEntry(entry, centeringOffset)

  copySelectedEntryPath: (relativePath = false) ->
    if pathToCopy = @selectedPath
      pathToCopy = atom.project.relativize(pathToCopy) if relativePath
      atom.clipboard.write(pathToCopy)

  entryForPath: (entryPath) ->
    fn = (bestMatchEntry, element) ->
      entry = $(element).view()
      if entry.getPath() is entryPath
        entry
      else if entry.getPath().length > bestMatchEntry.getPath().length and entry.directory?.contains(entryPath)
        entry
      else
        bestMatchEntry

    @list.find(".entry").toArray().reduce(fn, @root)

  selectEntryForPath: (entryPath) ->
    @selectEntry(@entryForPath(entryPath))

  moveDown: ->
    selectedEntry = @selectedEntry()
    if selectedEntry
      if selectedEntry.is('.expanded.directory')
        if @selectEntry(selectedEntry.find('.entry:first'))
          @scrollToEntry(@selectedEntry())
          return
      until @selectEntry(selectedEntry.next('.entry'))
        selectedEntry = selectedEntry.parents('.entry:first')
        break unless selectedEntry.length
    else
      @selectEntry(@root)

    @scrollToEntry(@selectedEntry())

  moveUp: ->
    selectedEntry = @selectedEntry()
    if selectedEntry
      if previousEntry = @selectEntry(selectedEntry.prev('.entry'))
        if previousEntry.is('.expanded.directory')
          @selectEntry(previousEntry.find('.entry:last'))
      else
        @selectEntry(selectedEntry.parents('.directory').first())
    else
      @selectEntry(@list.find('.entry').last())

    @scrollToEntry(@selectedEntry())

  expandDirectory: ->
    selectedEntry = @selectedEntry()
    selectedEntry.view().expand() if selectedEntry instanceof DirectoryView

  collapseDirectory: ->
    if directory = @selectedEntry()?.closest('.expanded.directory').view()
      directory.collapse()
      @selectEntry(directory)

  openSelectedEntry: (changeFocus) ->
    selectedEntry = @selectedEntry()
    if selectedEntry instanceof DirectoryView
      selectedEntry.view().toggleExpansion()
    else if selectedEntry instanceof FileView
      atom.workspaceView.open(selectedEntry.getPath(), { changeFocus })

  moveSelectedEntry: ->
    entry = @selectedEntry()
    return unless entry and entry isnt @root
    oldPath = entry.getPath()

    MoveDialog ?= require './move-dialog'
    dialog = new MoveDialog(oldPath)
    dialog.attach()

  removeSelectedEntry: ->
    entry = @selectedEntry()
    return unless entry

    entryType = if entry instanceof DirectoryView then "directory" else "file"
    atom.confirm
      message: "Are you sure you want to delete the selected #{entryType}?"
      detailedMessage: "You are deleting #{entry.getPath()}"
      buttons:
        "Move to Trash": -> shell.moveItemToTrash(entry.getPath())
        "Cancel": null
        "Delete": -> fs.removeSync(entry.getPath())

  add: ->
    selectedEntry = @selectedEntry() or @root
    selectedPath = selectedEntry.getPath()

    AddDialog ?= require './add-dialog'
    dialog = new AddDialog(selectedPath)
    dialog.on 'directory-created', (event, createdPath) =>
      @entryForPath(createdPath).reload()
      @selectEntryForPath(createdPath)
      false
    dialog.on 'file-created', (event, createdPath) ->
      atom.workspaceView.open(createdPath)
      false
    dialog.attach()

  selectedEntry: ->
    @list.find('.selected')?.view()

  selectEntry: (entry) ->
    entry = entry?.view()
    return false unless entry?

    @selectedPath = entry.getPath()
    @deselect()
    entry.addClass('selected')

  deselect: ->
    @list.find('.selected').removeClass('selected')

  scrollTop: (top) ->
    if top?
      @scroller.scrollTop(top)
    else
      @scroller.scrollTop()

  scrollBottom: (bottom) ->
    if bottom?
      @scroller.scrollBottom(bottom)
    else
      @scroller.scrollBottom()

  scrollToEntry: (entry, offset = 0) ->
    displayElement = if entry instanceof DirectoryView then entry.header else entry
    top = displayElement.position().top
    bottom = top + displayElement.outerHeight()
    if bottom > @scrollBottom()
      @scrollBottom(bottom + offset)
    if top < @scrollTop()
      @scrollTop(top + offset)

  scrollToBottom: ->
    @selectEntry(@root.find('.entry:last')) if @root
    @scrollToEntry(@root.find('.entry:last')) if @root

  scrollToTop: ->
    @selectEntry(@root) if @root
    @scrollTop(0)

  toggleSide: ->
    atom.config.toggle('tree-view.showOnRightSide')

  onSideToggled: (newValue) ->
    @detach()
    @attach()
    @attr('data-showOnRightSide', newValue)
