path = require 'path'
shell = require 'shell'

_ = require 'underscore-plus'
{$, BufferedProcess, ScrollView} = require 'atom'
fs = require 'fs-plus'

AddDialog = null  # Defer requiring until actually needed
MoveDialog = null # Defer requiring until actually needed
CopyDialog = null # Defer requiring until actually needed

Directory = require './directory'
DirectoryView = require './directory-view'
File = require './file'
FileView = require './file-view'
LocalStorage = window.localStorage

module.exports =
class TreeView extends ScrollView
  @content: ->
    @div class: 'tree-view-resizer tool-panel', 'data-show-on-right-side': atom.config.get('tree-view.showOnRightSide'), =>
      @div class: 'tree-view-scroller', outlet: 'scroller', =>
        @ol class: 'tree-view full-menu list-tree has-collapsable-children focusable-panel', tabindex: -1, outlet: 'list'
      @div class: 'tree-view-resize-handle', outlet: 'resizeHandle'

  initialize: (state) ->
    super

    focusAfterAttach = false
    root = null
    scrollLeftAfterAttach = -1
    scrollTopAfterAttach = -1
    selectedPath = null

    @on 'dblclick', '.tree-view-resize-handle', => @resizeToFitContent()
    @on 'click', '.entry', (e) =>
      return if e.shiftKey || e.metaKey
      @entryClicked(e)
    @on 'mousedown', '.entry', (e) =>
      e.stopPropagation()
      currentTarget = $(e.currentTarget)
      # return early if we're opening a contextual menu (right click) during multi-select mode
      return if @multiSelectEnabled() && currentTarget.hasClass('selected') &&
                # mouse right click or ctrl click as right click on darwin platforms
                (e.button is 2 || e.ctrlKey && process.platform is 'darwin')

      entryToSelect = currentTarget.view()

      if e.shiftKey
        @selectContinuousEntries(entryToSelect)
        @showMultiSelectMenu()
      # only allow ctrl click for multi selection on non darwin systems
      else if e.metaKey || (e.ctrlKey && process.platform isnt 'darwin')
        @selectMultipleEntries(entryToSelect)

        # only show the multi select menu if more then one file/directory is selected
        @showMultiSelectMenu() if @selectedPaths().length > 1
      else
        @selectEntry(entryToSelect)
        @showFullMenu()

    @on 'mousedown', '.tree-view-resize-handle', (e) => @resizeStarted(e)
    @command 'core:move-up', => @moveUp()
    @command 'core:move-down', => @moveDown()
    @command 'tree-view:expand-directory', => @expandDirectory()
    @command 'tree-view:collapse-directory', => @collapseDirectory()
    @command 'tree-view:open-selected-entry', => @openSelectedEntry(true)
    @command 'tree-view:move', => @moveSelectedEntry()
    @command 'tree-view:copy', => @copySelectedEntries()
    @command 'tree-view:cut', => @cutSelectedEntries()
    @command 'tree-view:paste', => @pasteEntries()
    @command 'tree-view:copy-full-path', => @copySelectedEntryPath(false)
    @command 'tree-view:show-in-file-manager', => @showSelectedEntryInFileManager()
    @command 'tree-view:copy-project-path', => @copySelectedEntryPath(true)
    @command 'tool-panel:unfocus', => @unfocus()

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
      @removeClass('panel-left')
      @addClass('panel-right')
      atom.workspaceView.appendToRight(this)
    else
      @removeClass('panel-right')
      @addClass('panel-left')
      atom.workspaceView.appendToLeft(this)

  detach: ->
    @scrollLeftAfterAttach = @scroller.scrollLeft()
    @scrollTopAfterAttach = @scrollTop()

    # Clean up copy and cut localStorage Variables
    LocalStorage['tree-view:cutPath'] = null
    LocalStorage['tree-view:copyPath'] = null

    super
    atom.workspaceView.focus()

  focus: ->
    @list.focus()

  unfocus: ->
    atom.workspaceView.focus()

  hasFocus: ->
    @list.is(':focus') or document.activeElement is @list[0]

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
    if atom.config.get('tree-view.showOnRightSide')
      width = $(document.body).width() - pageX
    else
      width = pageX
    @width(width)

  resizeToFitContent: ->
    @width(1) # Shrink to measure the minimum width of list
    @width(@list.outerWidth())

  updateRoot: (expandedEntries={}) ->
    @root?.remove()

    if rootDirectory = atom.project.getRootDirectory()
      directory = new Directory({directory: rootDirectory, isExpanded: true, expandedEntries, isRoot: true})
      @root = new DirectoryView(directory)
      @list.append(@root)
    else
      @root = null

  getActivePath: -> atom.workspace.getActivePaneItem()?.getPath?()

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

  # Get the outline of a system call to the current platform's file manager.
  #
  # pathToOpen  - Path to a file or directory.
  # isFile      - True if the path is a file, false otherwise.
  #
  # Returns an object containing a command, a human-readable label, and the
  # arguments.
  fileManagerCommandForPath: (pathToOpen, isFile) ->
    switch process.platform
      when 'darwin'
        command: 'open'
        label: 'Finder'
        args: ['-R', pathToOpen]
      when 'win32'
        command: 'cmd.exe'
        label: 'Explorer'
        args: ['/c', 'start', 'explorer.exe', pathToOpen]
      else
        # Strip the filename from the path to make sure we pass a directory
        # path. If we pass xdg-open a file path, it will open that file in the
        # most suitable application instead, which is not what we want.
        pathToOpen =  path.dirname(pathToOpen) if isFile

        command: 'xdg-open'
        label: 'File Manager'
        args: [pathToOpen]

  showSelectedEntryInFileManager: ->
    entry = @selectedEntry()
    return unless entry

    {command, args, label} = @fileManagerCommandForPath(entry.getPath(), entry instanceof FileView)

    errorLines = []
    stderr = (lines) -> errorLines.push(lines)
    exit = (code) ->
      if code isnt 0
        atom.confirm
          message: "Opening #{entryType} in #{label} failed"
          detailedMessage: errorLines.join('\n')
          buttons: ['OK']

    new BufferedProcess({command, args, stderr, exit})

  copySelectedEntry: ->
    if @hasFocus()
      entry = @selectedEntry()
      return unless entry isnt root
      oldPath = entry.getPath()
    else
      oldPath = @getActivePath()
    return unless oldPath

    CopyDialog ?= require './copy-dialog'
    dialog = new CopyDialog(oldPath)
    dialog.attach()

  removeSelectedEntries: ->
    if @hasFocus()
      selectedPaths = @selectedPaths()
    else if activePath = @getActivePath()
      selectedPaths = [activePath]

    return unless selectedPaths

    atom.confirm
      message: "Are you sure you want to delete the selected #{if selectedPaths.length > 1 then 'items' else 'item'}?"
      detailedMessage: "You are deleting:\n#{selectedPaths.join('\n')}"
      buttons:
        "Move to Trash": ->
          for selectedPath in selectedPaths
            shell.moveItemToTrash(selectedPath)
        "Cancel": null
        "Delete": =>
          for selectedPath in selectedPaths
            @removeSync(selectedPath)

  removeSync: (pathToRemove) ->
    try
      fs.removeSync(pathToRemove)
    catch error
      if error.code is 'EACCES' and process.platform is 'darwin'
        runas = require 'runas'
        removed = runas('/bin/rm', ['-r', '-f', pathToRemove], admin: true) is 0
        throw error unless removed
      else
        throw error

  # Public: Copy the path of the selected entry element.
  #         Save the path in localStorage, so that copying from 2 different
  #         instances of atom works as intended
  #
  #
  # Returns `copyPath`.
  copySelectedEntries: ->
    selectedPaths = @selectedPaths()
    return unless selectedPaths && selectedPaths.length > 0
    # save to localStorage so we can paste across multiple open apps
    LocalStorage.removeItem('tree-view:cutPath')
    LocalStorage['tree-view:copyPath'] = JSON.stringify(selectedPaths)

  # Public: Copy the path of the selected entry element.
  #         Save the path in localStorage, so that cutting from 2 different
  #         instances of atom works as intended
  #
  #
  # Returns `cutPath`
  cutSelectedEntries: ->
    selectedPaths = @selectedPaths()
    return unless selectedPaths && selectedPaths.length > 0
    # save to localStorage so we can paste across multiple open apps
    LocalStorage.removeItem('tree-view:copyPath')
    LocalStorage['tree-view:cutPath'] = JSON.stringify(selectedPaths)

  # Public: Paste a copied or cut item.
  #         If a file is selected, the file's parent directory is used as the
  #         paste destination.
  #
  #
  # Returns `destination newPath`.
  pasteEntries: ->
    entry = @selectedEntry()
    cutPaths = if LocalStorage['tree-view:cutPath'] then JSON.parse(LocalStorage['tree-view:cutPath']) else null
    copiedPaths = if LocalStorage['tree-view:copyPath'] then JSON.parse(LocalStorage['tree-view:copyPath']) else null
    initialPaths = copiedPaths || cutPaths

    for initialPath in initialPaths ? []
      initialPathIsDirectory = fs.isDirectorySync(initialPath)
      if entry && initialPath

        basePath = atom.project.resolve(entry.getPath())
        entryType = if entry instanceof DirectoryView then "directory" else "file"

        if entryType is 'file'
          basePath = path.dirname(basePath)

        newPath = path.join(basePath, path.basename(initialPath))

        if copiedPaths
          # append a number to the file if an item with the same name exists
          fileCounter = 0
          originalNewPath = newPath
          while fs.existsSync(newPath)
            if initialPathIsDirectory
              newPath = "#{originalNewPath}#{fileCounter.toString()}"
            else
              fileArr = originalNewPath.split('.')
              newPath = "#{fileArr[0]}#{fileCounter.toString()}.#{fileArr[1]}"
            fileCounter += 1

          if fs.isDirectorySync(initialPath)
            # use fs.copy to copy directories since read/write will fail for directories
            fs.copySync(initialPath, newPath)
          else
            # read the old file and write a new one at target location
            fs.writeFileSync(newPath, fs.readFileSync(initialPath))
        else if cutPaths
          # Only move the target if the cut target doesn't exists and if the newPath
          # is not within the initial path
          unless fs.existsSync(newPath) || !!newPath.match(new RegExp("^#{initialPath}"))
            fs.moveSync(initialPath, newPath)

  add: (isCreatingFile) ->
    selectedEntry = @selectedEntry() or @root
    selectedPath = selectedEntry.getPath()

    AddDialog ?= require './add-dialog'
    dialog = new AddDialog(selectedPath, isCreatingFile)
    dialog.on 'directory-created', (event, createdPath) =>
      @entryForPath(createdPath).reload()
      @selectEntryForPath(createdPath)
      false
    dialog.on 'file-created', (event, createdPath) ->
      atom.workspace.open(createdPath)
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
    if lastEntry = @root?.find('.entry:last').view()
      @selectEntry(lastEntry)
      @scrollToEntry(lastEntry)

  scrollToTop: ->
    @selectEntry(@root) if @root?
    @scrollTop(0)

  toggleSide: ->
    atom.config.toggle('tree-view.showOnRightSide')

  onSideToggled: (newValue) ->
    @detach()
    @attach()
    @attr('data-show-on-right-side', newValue)

  # Public: Return an array of paths from all selected items
  #
  # Example: @selectedPaths()
  # => ['selected/path/one', 'selected/path/two', 'selected/path/three']
  # Returns Array of selected item paths
  selectedPaths: ->
    $(item).view().getPath() for item in @list.find('.selected')

  # Public: Selects items within a range defined by a currently selected entry and
  #         a new given entry. This is shift+click functionality
  #
  # Returns array of selected elements
  selectContinuousEntries: (entry)->
    currentSelectedEntry = @selectedEntry()
    parentContainer = entry.parent()
    if $.contains(parentContainer[0], currentSelectedEntry[0])
      entryIndex = parentContainer.indexOf(entry)
      selectedIndex = parentContainer.indexOf(currentSelectedEntry)
      elements = (parentContainer.children()[i] for i in [entryIndex..selectedIndex])

      @deselect()
      for element in elements
        $(element).addClass('selected')

    elements

  # Public: Selects consecutive given entries without clearing previously selected
  #         items. This is cmd+click functionality
  #
  # Returns given entry
  selectMultipleEntries: (entry)->
    entry = entry?.view()
    return false unless entry?
    entry.addClass('selected')
    entry

  # Public: Toggle full-menu class on the main list element to display the full context
  #         menu.
  #
  # Returns noop
  showFullMenu: ->
    @list.removeClass('multi-select').addClass('full-menu')

  # Public: Toggle multi-select class on the main list element to display the the
  #         menu with only items that make sense for multi select functionality
  #
  # Returns noop
  showMultiSelectMenu: ->
    @list.removeClass('full-menu').addClass('multi-select')

  # Public: Check for multi-select class on the main list
  #
  # Returns boolean
  multiSelectEnabled: ->
    @list.hasClass('multi-select')
