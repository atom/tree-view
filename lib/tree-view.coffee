path = require 'path'
{shell} = require 'electron'

_ = require 'underscore-plus'
{BufferedProcess, CompositeDisposable, Emitter} = require 'atom'
{repoForPath, getStyleObject, getFullExtension, updateEditorsForPath} = require "./helpers"
fs = require 'fs-plus'

AddDialog = require './add-dialog'
MoveDialog = require './move-dialog'
CopyDialog = require './copy-dialog'
Minimatch = null  # Defer requiring until actually needed

Directory = require './directory'
DirectoryView = require './directory-view'
RootDragAndDrop = require './root-drag-and-drop'

toggleConfig = (keyPath) ->
  atom.config.set(keyPath, not atom.config.get(keyPath))

module.exports =
class TreeView
  panel: null

  constructor: (state) ->
    @element = document.createElement('div')
    @element.classList.add('tree-view-resizer', 'tool-panel')
    @element.dataset.showOnRightSide = atom.config.get('tree-view.showOnRightSide')

    @scroller = document.createElement('div')
    @scroller.classList.add('tree-view-scroller', 'order--center')
    @element.appendChild(@scroller)

    @list = document.createElement('ol')
    @list.classList.add('tree-view', 'full-menu', 'list-tree', 'has-collapsable-children', 'focusable-panel')
    @list.tabIndex = -1
    @scroller.appendChild(@list)

    @resizeHandle = document.createElement('div')
    @resizeHandle.classList.add('tree-view-resize-handle')
    @element.appendChild(@resizeHandle)

    @disposables = new CompositeDisposable
    @emitter = new Emitter
    @focusAfterAttach = false
    @roots = []
    @scrollLeftAfterAttach = -1
    @scrollTopAfterAttach = -1
    @selectedPath = null
    @ignoredPatterns = []
    @useSyncFS = false
    @currentlyOpening = new Map

    @dragEventCounts = new WeakMap
    @rootDragAndDrop = new RootDragAndDrop(this)

    @handleEvents()

    process.nextTick =>
      @onStylesheetsChanged()
      onStylesheetsChanged = _.debounce(@onStylesheetsChanged, 100)
      @disposables.add atom.styles.onDidAddStyleElement(onStylesheetsChanged)
      @disposables.add atom.styles.onDidRemoveStyleElement(onStylesheetsChanged)
      @disposables.add atom.styles.onDidUpdateStyleElement(onStylesheetsChanged)

    @updateRoots(state.directoryExpansionStates)
    @selectEntry(@roots[0])

    @selectEntryForPath(state.selectedPath) if state.selectedPath
    @focusAfterAttach = state.hasFocus
    @scrollTopAfterAttach = state.scrollTop if state.scrollTop
    @scrollLeftAfterAttach = state.scrollLeft if state.scrollLeft
    @attachAfterProjectPathSet = state.attached and _.isEmpty(atom.project.getPaths())
    @element.style.width = "#{state.width}px" if state.width > 0
    @attach() if state.attached

    @disposables.add @onEntryMoved ({initialPath, newPath}) ->
      updateEditorsForPath(initialPath, newPath)

    @disposables.add @onEntryDeleted ({path}) ->
      for editor in atom.workspace.getTextEditors()
        if editor?.getPath()?.startsWith(path)
          editor.destroy()

  serialize: ->
    directoryExpansionStates: new ((roots) ->
      @[root.directory.path] = root.directory.serializeExpansionState() for root in roots
      this)(@roots)
    selectedPath: @selectedEntry()?.getPath()
    hasFocus: @hasFocus()
    attached: @panel?
    scrollLeft: @scroller.scrollLeft
    scrollTop: @scroller.scrollTop
    width: parseInt(@element.style.width or 0)

  deactivate: ->
    root.directory.destroy() for root in @roots
    @disposables.dispose()
    @rootDragAndDrop.dispose()
    @detach() if @panel?

  onDirectoryCreated: (callback) ->
    @emitter.on('directory-created', callback)

  onEntryCopied: (callback) ->
    @emitter.on('entry-copied', callback)

  onEntryDeleted: (callback) ->
    @emitter.on('entry-deleted', callback)

  onEntryMoved: (callback) ->
    @emitter.on('entry-moved', callback)

  onFileCreated: (callback) ->
    @emitter.on('file-created', callback)

  handleEvents: ->
    @resizeHandle.addEventListener 'dblclick', => @resizeToFitContent()
    @resizeHandle.addEventListener 'mousedown', (e) => @resizeStarted(e)
    @element.addEventListener 'click', (e) =>
      # This prevents accidental collapsing when a .entries element is the event target
      return if e.target.classList.contains('entries')

      @entryClicked(e) unless e.shiftKey or e.metaKey or e.ctrlKey
    @element.addEventListener 'mousedown', (e) => @onMouseDown(e)
    @element.addEventListener 'dragstart', (e) => @onDragStart(e)
    @element.addEventListener 'dragenter', (e) => @onDragEnter(e)
    @element.addEventListener 'dragleave', (e) => @onDragLeave(e)
    @element.addEventListener 'dragover', (e) => @onDragOver(e)
    @element.addEventListener 'drop', (e) => @onDrop(e)

    atom.commands.add @element,
     'core:move-up': @moveUp.bind(this)
     'core:move-down': @moveDown.bind(this)
     'core:page-up': => @pageUp()
     'core:page-down': => @pageDown()
     'core:move-to-top': => @scrollToTop()
     'core:move-to-bottom': => @scrollToBottom()
     'tree-view:expand-item': => @openSelectedEntry(pending: true, true)
     'tree-view:recursive-expand-directory': => @expandDirectory(true)
     'tree-view:collapse-directory': => @collapseDirectory()
     'tree-view:recursive-collapse-directory': => @collapseDirectory(true)
     'tree-view:open-selected-entry': => @openSelectedEntry()
     'tree-view:open-selected-entry-right': => @openSelectedEntryRight()
     'tree-view:open-selected-entry-left': => @openSelectedEntryLeft()
     'tree-view:open-selected-entry-up': => @openSelectedEntryUp()
     'tree-view:open-selected-entry-down': => @openSelectedEntryDown()
     'tree-view:move': => @moveSelectedEntry()
     'tree-view:copy': => @copySelectedEntries()
     'tree-view:cut': => @cutSelectedEntries()
     'tree-view:paste': => @pasteEntries()
     'tree-view:copy-full-path': => @copySelectedEntryPath(false)
     'tree-view:show-in-file-manager': => @showSelectedEntryInFileManager()
     'tree-view:open-in-new-window': => @openSelectedEntryInNewWindow()
     'tree-view:copy-project-path': => @copySelectedEntryPath(true)
     'tool-panel:unfocus': => @unfocus()
     'tree-view:toggle-vcs-ignored-files': -> toggleConfig 'tree-view.hideVcsIgnoredFiles'
     'tree-view:toggle-ignored-names': -> toggleConfig 'tree-view.hideIgnoredNames'
     'tree-view:remove-project-folder': (e) => @removeProjectFolder(e)

    [0..8].forEach (index) =>
      atom.commands.add @element, "tree-view:open-selected-entry-in-pane-#{index + 1}", =>
        @openSelectedEntryInPane index

    @disposables.add atom.workspace.onDidChangeActivePaneItem =>
      @selectActiveFile()
      @revealActiveFile() if atom.config.get('tree-view.autoReveal')
    @disposables.add atom.project.onDidChangePaths =>
      @updateRoots()
    @disposables.add atom.config.onDidChange 'tree-view.hideVcsIgnoredFiles', =>
      @updateRoots()
    @disposables.add atom.config.onDidChange 'tree-view.hideIgnoredNames', =>
      @updateRoots()
    @disposables.add atom.config.onDidChange 'core.ignoredNames', =>
      @updateRoots() if atom.config.get('tree-view.hideIgnoredNames')
    @disposables.add atom.config.onDidChange 'tree-view.showOnRightSide', ({newValue}) =>
      @onSideToggled(newValue)
    @disposables.add atom.config.onDidChange 'tree-view.sortFoldersBeforeFiles', =>
      @updateRoots()
    @disposables.add atom.config.onDidChange 'tree-view.squashDirectoryNames', =>
      @updateRoots()

  toggle: ->
    if @isVisible()
      @detach()
    else
      @show()

  show: ->
    @attach()
    @focus()

  isVisible: ->
    not @isHidden()

  isHidden: ->
    if @element.style.display is 'none' or not document.body.contains(@element)
      true
    else if @element.style.display
      false
    else
      getComputedStyle(@element).display is 'none'

  attach: ->
    return if _.isEmpty(atom.project.getPaths())

    @panel ?=
      if atom.config.get('tree-view.showOnRightSide')
        atom.workspace.addRightPanel(item: this)
      else
        atom.workspace.addLeftPanel(item: this)

    @focus() if @focusAfterAttach
    @scroller.scrollLeft = @scrollLeftAfterAttach if @scrollLeftAfterAttach > 0
    @scroller.scrollTop = @scrollTopAfterAttach if @scrollTopAfterAttach > 0

  detach: ->
    @scrollLeftAfterAttach = @scroller.scrollLeft
    @scrollTopAfterAttach = @scroller.scrollTop

    # Clean up copy and cut localStorage Variables
    window.localStorage['tree-view:cutPath'] = null
    window.localStorage['tree-view:copyPath'] = null

    @panel.destroy()
    @panel = null
    @unfocus()
    @resizeStopped()

  focus: ->
    @list.focus()

  unfocus: ->
    atom.workspace.getActivePane().activate()

  hasFocus: ->
    @element.contains(document.activeElement)

  toggleFocus: ->
    if @hasFocus()
      @unfocus()
    else
      @show()

  entryClicked: (e) ->
    if entry = e.target.closest('.entry')
      isRecursive = e.altKey or false
      @selectEntry(entry)
      if entry.classList.contains('directory')
        entry.toggleExpansion(isRecursive)
      else if entry.classList.contains('file')
        @fileViewEntryClicked(e)

  fileViewEntryClicked: (e) ->
    filePath = e.target.closest('.entry').getPath()
    detail = e.detail ? 1
    alwaysOpenExisting = atom.config.get('tree-view.alwaysOpenExisting')
    if detail is 1
      if atom.config.get('core.allowPendingPaneItems')
        openPromise = atom.workspace.open(filePath, pending: true, activatePane: false, searchAllPanes: alwaysOpenExisting)
        @currentlyOpening.set(filePath, openPromise)
        openPromise.then => @currentlyOpening.delete(filePath)
    else if detail is 2
      @openAfterPromise(filePath, searchAllPanes: alwaysOpenExisting)

  openAfterPromise: (uri, options) ->
    if promise = @currentlyOpening.get(uri)
      promise.then -> atom.workspace.open(uri, options)
    else
      atom.workspace.open(uri, options)

  resizeStarted: =>
    document.addEventListener('mousemove', @resizeTreeView)
    document.addEventListener('mouseup', @resizeStopped)

  resizeStopped: =>
    document.removeEventListener('mousemove', @resizeTreeView)
    document.removeEventListener('mouseup', @resizeStopped)

  resizeTreeView: ({pageX, which}) =>
    return @resizeStopped() unless which is 1

    if atom.config.get('tree-view.showOnRightSide')
      width = @element.offsetWidth + @element.getBoundingClientRect().left - pageX
    else
      width = pageX - @element.getBoundingClientRect().left

    @element.style.width = "#{width}px"

  resizeToFitContent: ->
    @element.style.width = '1px' # Shrink to measure the minimum width of list
    @element.style.width = "#{@list.offsetWidth}px"

  loadIgnoredPatterns: ->
    @ignoredPatterns.length = 0
    return unless atom.config.get('tree-view.hideIgnoredNames')

    Minimatch ?= require('minimatch').Minimatch

    ignoredNames = atom.config.get('core.ignoredNames') ? []
    ignoredNames = [ignoredNames] if typeof ignoredNames is 'string'
    for ignoredName in ignoredNames when ignoredName
      try
        @ignoredPatterns.push(new Minimatch(ignoredName, matchBase: true, dot: true))
      catch error
        atom.notifications.addWarning("Error parsing ignore pattern (#{ignoredName})", detail: error.message)

  updateRoots: (expansionStates={}) ->
    oldExpansionStates = {}
    for root in @roots
      oldExpansionStates[root.directory.path] = root.directory.serializeExpansionState()
      root.directory.destroy()
      root.remove()

    @loadIgnoredPatterns()

    @roots = for projectPath in atom.project.getPaths()
      continue unless stats = fs.lstatSyncNoException(projectPath)
      stats = _.pick stats, _.keys(stats)...
      for key in ["atime", "birthtime", "ctime", "mtime"]
        stats[key] = stats[key].getTime()

      directory = new Directory({
        name: path.basename(projectPath)
        fullPath: projectPath
        symlink: false
        isRoot: true
        expansionState: expansionStates[projectPath] ?
                        oldExpansionStates[projectPath] ?
                        {isExpanded: true}
        @ignoredPatterns
        @useSyncFS
        stats
      })
      root = new DirectoryView(directory).element
      @list.appendChild(root)
      root

    if @attachAfterProjectPathSet
      @attach()
      @attachAfterProjectPathSet = false

  getActivePath: -> atom.workspace.getActivePaneItem()?.getPath?()

  selectActiveFile: ->
    if activeFilePath = @getActivePath()
      @selectEntryForPath(activeFilePath)
    else
      @deselect()

  revealActiveFile: ->
    return if _.isEmpty(atom.project.getPaths())

    @attach()
    @focus() if atom.config.get('tree-view.focusOnReveal')

    return unless activeFilePath = @getActivePath()

    [rootPath, relativePath] = atom.project.relativizePath(activeFilePath)
    return unless rootPath?

    activePathComponents = relativePath.split(path.sep)
    currentPath = rootPath
    for pathComponent in activePathComponents
      currentPath += path.sep + pathComponent
      entry = @entryForPath(currentPath)
      if entry.classList.contains('directory')
        entry.expand()
      else
        @selectEntry(entry)
        @scrollToEntry(entry)

  copySelectedEntryPath: (relativePath = false) ->
    if pathToCopy = @selectedPath
      pathToCopy = atom.project.relativize(pathToCopy) if relativePath
      atom.clipboard.write(pathToCopy)

  entryForPath: (entryPath) ->
    bestMatchEntry = null
    bestMatchLength = 0

    for entry in @list.querySelectorAll('.entry')
      if entry.isPathEqual(entryPath)
        return entry

      entryLength = entry.getPath().length
      if entry.directory?.contains(entryPath) and entryLength > bestMatchLength
        bestMatchEntry = entry
        bestMatchLength = entryLength

    bestMatchEntry

  selectEntryForPath: (entryPath) ->
    @selectEntry(@entryForPath(entryPath))

  moveDown: (event) ->
    event?.stopImmediatePropagation()
    selectedEntry = @selectedEntry()
    if selectedEntry?
      if selectedEntry.classList.contains('directory')
        if @selectEntry(selectedEntry.entries.children[0])
          @scrollToEntry(@selectedEntry())
          return

      if nextEntry = @nextEntry(selectedEntry)
        @selectEntry(nextEntry)
    else
      @selectEntry(@roots[0])

    @scrollToEntry(@selectedEntry())

  moveUp: (event) ->
    event.stopImmediatePropagation()
    selectedEntry = @selectedEntry()
    if selectedEntry?
      if previousEntry = @previousEntry(selectedEntry)
        @selectEntry(previousEntry)
        if previousEntry.classList.contains('directory')
          @selectEntry(_.last(previousEntry.entries.children))
      else
        @selectEntry(selectedEntry.parentElement.closest('.directory'))
    else
      entries = @list.querySelectorAll('.entry')
      @selectEntry(entries[entries.length - 1])

    @scrollToEntry(@selectedEntry())

  nextEntry: (entry) ->
    currentEntry = entry
    while currentEntry?
      if currentEntry.nextSibling?
        currentEntry = currentEntry.nextSibling
        if currentEntry.matches('.entry')
          return currentEntry
      else
        currentEntry = currentEntry.parentElement.closest('.directory')

    return null

  previousEntry: (entry) ->
    currentEntry = entry
    while currentEntry?
      currentEntry = currentEntry.previousSibling
      if currentEntry?.matches('.entry')
        return currentEntry
    return null

  expandDirectory: (isRecursive=false) ->
    selectedEntry = @selectedEntry()
    return unless selectedEntry?

    if isRecursive is false and selectedEntry.isExpanded
      @moveDown() if selectedEntry.directory.getEntries().length > 0
    else
      selectedEntry.expand(isRecursive)

  collapseDirectory: (isRecursive=false) ->
    selectedEntry = @selectedEntry()
    return unless selectedEntry?

    if directory = selectedEntry.closest('.expanded.directory')
      directory.collapse(isRecursive)
      @selectEntry(directory)

  openSelectedEntry: (options={}, expandDirectory=false) ->
    selectedEntry = @selectedEntry()
    return unless selectedEntry?

    if selectedEntry.classList.contains('directory')
      if expandDirectory
        @expandDirectory(false)
      else
        selectedEntry.toggleExpansion()
    else if selectedEntry.classList.contains('file')
      if atom.config.get('tree-view.alwaysOpenExisting')
        options = Object.assign searchAllPanes: true, options
      @openAfterPromise(selectedEntry.getPath(), options)

  openSelectedEntrySplit: (orientation, side) ->
    selectedEntry = @selectedEntry()
    return unless selectedEntry?

    pane = atom.workspace.getActivePane()
    if pane and selectedEntry.classList.contains('file')
      if atom.workspace.getActivePaneItem()
        split = pane.split orientation, side
        atom.workspace.openURIInPane selectedEntry.getPath(), split
      else
        @openSelectedEntry yes

  openSelectedEntryRight: ->
    @openSelectedEntrySplit 'horizontal', 'after'

  openSelectedEntryLeft: ->
    @openSelectedEntrySplit 'horizontal', 'before'

  openSelectedEntryUp: ->
    @openSelectedEntrySplit 'vertical', 'before'

  openSelectedEntryDown: ->
    @openSelectedEntrySplit 'vertical', 'after'

  openSelectedEntryInPane: (index) ->
    selectedEntry = @selectedEntry()
    return unless selectedEntry?

    pane = atom.workspace.getPanes()[index]
    if pane and selectedEntry.classList.contains('file')
      atom.workspace.openURIInPane selectedEntry.getPath(), pane

  moveSelectedEntry: ->
    if @hasFocus()
      entry = @selectedEntry()
      return if not entry? or entry in @roots
      oldPath = entry.getPath()
    else
      oldPath = @getActivePath()

    if oldPath
      dialog = new MoveDialog oldPath,
        onMove: ({initialPath, newPath}) =>
          @emitter.emit 'entry-moved', {initialPath, newPath}
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
        args = ["/select,\"#{pathToOpen}\""]

        if process.env.SystemRoot
          command = path.join(process.env.SystemRoot, 'explorer.exe')
        else
          command = 'explorer.exe'

        command: command
        label: 'Explorer'
        args: args
      else
        # Strip the filename from the path to make sure we pass a directory
        # path. If we pass xdg-open a file path, it will open that file in the
        # most suitable application instead, which is not what we want.
        pathToOpen =  path.dirname(pathToOpen) if isFile

        command: 'xdg-open'
        label: 'File Manager'
        args: [pathToOpen]

  openInFileManager: (command, args, label, isFile) ->
    handleError = (errorMessage) ->
      atom.notifications.addError "Opening #{if isFile then 'file' else 'folder'} in #{label} failed",
        detail: errorMessage
        dismissable: true

    errorLines = []
    stderr = (lines) -> errorLines.push(lines)
    exit = (code) ->
      failed = code isnt 0
      errorMessage = errorLines.join('\n')

      # Windows 8 seems to return a 1 with no error output even on success
      if process.platform is 'win32' and code is 1 and not errorMessage
        failed = false

      handleError(errorMessage) if failed

    showProcess = new BufferedProcess({command, args, stderr, exit})
    showProcess.onWillThrowError ({error, handle}) ->
      handle()
      handleError(error?.message)
    showProcess

  showSelectedEntryInFileManager: ->
    return unless entry = @selectedEntry()

    isFile = entry.classList.contains('file')
    {command, args, label} = @fileManagerCommandForPath(entry.getPath(), isFile)
    @openInFileManager(command, args, label, isFile)

  showCurrentFileInFileManager: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    return unless editor.getPath()
    {command, args, label} = @fileManagerCommandForPath(editor.getPath(), true)
    @openInFileManager(command, args, label, true)

  openSelectedEntryInNewWindow: ->
    if pathToOpen = @selectedEntry()?.getPath()
      atom.open({pathsToOpen: [pathToOpen], newWindow: true})

  copySelectedEntry: ->
    if @hasFocus()
      entry = @selectedEntry()
      return if entry in @roots
      oldPath = entry?.getPath()
    else
      oldPath = @getActivePath()
    return unless oldPath

    dialog = new CopyDialog oldPath,
      onCopy: ({initialPath, newPath}) =>
        @emitter.emit 'entry-copied', {initialPath, newPath}
    dialog.attach()

  removeSelectedEntries: ->
    if @hasFocus()
      selectedPaths = @selectedPaths()
    else if activePath = @getActivePath()
      selectedPaths = [activePath]

    return unless selectedPaths and selectedPaths.length > 0

    for root in @roots
      if root.getPath() in selectedPaths
        atom.confirm
          message: "The root directory '#{root.directory.name}' can't be removed."
          buttons: ['OK']
        return

    atom.confirm
      message: "Are you sure you want to delete the selected #{if selectedPaths.length > 1 then 'items' else 'item'}?"
      detailedMessage: "You are deleting:\n#{selectedPaths.join('\n')}"
      buttons:
        "Move to Trash": =>
          failedDeletions = []
          for selectedPath in selectedPaths
            if shell.moveItemToTrash(selectedPath)
              @emitter.emit 'entry-deleted', {path: selectedPath}
            else
              failedDeletions.push "#{selectedPath}"
            if repo = repoForPath(selectedPath)
              repo.getPathStatus(selectedPath)
          if failedDeletions.length > 0
            atom.notifications.addError @formatTrashFailureMessage(failedDeletions),
              description: @formatTrashEnabledMessage()
              detail: "#{failedDeletions.join('\n')}"
              dismissable: true
          @updateRoots() if atom.config.get('tree-view.squashDirectoryNames')
        "Cancel": null

  formatTrashFailureMessage: (failedDeletions) ->
    fileText = if failedDeletions.length > 1 then 'files' else 'file'

    "The following #{fileText} couldn't be moved to the trash."

  formatTrashEnabledMessage: ->
    switch process.platform
      when 'linux' then 'Is `gvfs-trash` installed?'
      when 'darwin' then 'Is Trash enabled on the volume where the files are stored?'
      when 'win32' then 'Is there a Recycle Bin on the drive where the files are stored?'

  # Public: Copy the path of the selected entry element.
  #         Save the path in localStorage, so that copying from 2 different
  #         instances of atom works as intended
  #
  #
  # Returns `copyPath`.
  copySelectedEntries: ->
    selectedPaths = @selectedPaths()
    return unless selectedPaths and selectedPaths.length > 0
    # save to localStorage so we can paste across multiple open apps
    window.localStorage.removeItem('tree-view:cutPath')
    window.localStorage['tree-view:copyPath'] = JSON.stringify(selectedPaths)

  # Public: Copy the path of the selected entry element.
  #         Save the path in localStorage, so that cutting from 2 different
  #         instances of atom works as intended
  #
  #
  # Returns `cutPath`
  cutSelectedEntries: ->
    selectedPaths = @selectedPaths()
    return unless selectedPaths and selectedPaths.length > 0
    # save to localStorage so we can paste across multiple open apps
    window.localStorage.removeItem('tree-view:copyPath')
    window.localStorage['tree-view:cutPath'] = JSON.stringify(selectedPaths)

  # Public: Paste a copied or cut item.
  #         If a file is selected, the file's parent directory is used as the
  #         paste destination.
  #
  #
  # Returns `destination newPath`.
  pasteEntries: ->
    selectedEntry = @selectedEntry()
    cutPaths = if window.localStorage['tree-view:cutPath'] then JSON.parse(window.localStorage['tree-view:cutPath']) else null
    copiedPaths = if window.localStorage['tree-view:copyPath'] then JSON.parse(window.localStorage['tree-view:copyPath']) else null
    initialPaths = copiedPaths or cutPaths

    catchAndShowFileErrors = (operation) ->
      try
        operation()
      catch error
        atom.notifications.addWarning("Unable to paste paths: #{initialPaths}", detail: error.message)

    for initialPath in initialPaths ? []
      initialPathIsDirectory = fs.isDirectorySync(initialPath)
      if selectedEntry and initialPath and fs.existsSync(initialPath)
        basePath = selectedEntry.getPath()
        basePath = path.dirname(basePath) if selectedEntry.classList.contains('file')
        newPath = path.join(basePath, path.basename(initialPath))

        if copiedPaths
          # append a number to the file if an item with the same name exists
          fileCounter = 0
          originalNewPath = newPath
          while fs.existsSync(newPath)
            if initialPathIsDirectory
              newPath = "#{originalNewPath}#{fileCounter}"
            else
              extension = getFullExtension(originalNewPath)
              filePath = path.join(path.dirname(originalNewPath), path.basename(originalNewPath, extension))
              newPath = "#{filePath}#{fileCounter}#{extension}"
            fileCounter += 1

          if fs.isDirectorySync(initialPath)
            # use fs.copy to copy directories since read/write will fail for directories
            catchAndShowFileErrors =>
              fs.copySync(initialPath, newPath)
              @emitter.emit 'entry-copied', {initialPath, newPath}
          else
            # read the old file and write a new one at target location
            catchAndShowFileErrors =>
              fs.writeFileSync(newPath, fs.readFileSync(initialPath))
              @emitter.emit 'entry-copied', {initialPath, newPath}
        else if cutPaths
          # Only move the target if the cut target doesn't exist and if the newPath
          # is not within the initial path
          unless fs.existsSync(newPath) or newPath.startsWith(initialPath)
            catchAndShowFileErrors =>
              fs.moveSync(initialPath, newPath)
              @emitter.emit 'entry-moved', {initialPath, newPath}

  add: (isCreatingFile) ->
    selectedEntry = @selectedEntry() ? @roots[0]
    selectedPath = selectedEntry?.getPath() ? ''

    dialog = new AddDialog(selectedPath, isCreatingFile)
    dialog.onDidCreateDirectory (createdPath) =>
      @entryForPath(createdPath)?.reload()
      @selectEntryForPath(createdPath)
      @updateRoots() if atom.config.get('tree-view.squashDirectoryNames')
      @emitter.emit 'directory-created', {path: createdPath}
    dialog.onDidCreateFile (createdPath) =>
      atom.workspace.open(createdPath)
      @updateRoots() if atom.config.get('tree-view.squashDirectoryNames')
      @emitter.emit 'file-created', {path: createdPath}
    dialog.attach()

  removeProjectFolder: (e) ->
    pathToRemove = e.target.closest(".project-root > .header")?.querySelector(".name")?.dataset.path

    # TODO: remove this conditional once the addition of Project::removePath
    # is released.
    if atom.project.removePath?
      atom.project.removePath(pathToRemove) if pathToRemove?

  selectedEntry: ->
    @list.querySelector('.selected')

  selectEntry: (entry) ->
    return unless entry?

    @selectedPath = entry.getPath()

    selectedEntries = @getSelectedEntries()
    if selectedEntries.length > 1 or selectedEntries[0] isnt entry
      @deselect(selectedEntries)
      entry.classList.add('selected')
    entry

  getSelectedEntries: ->
    @list.querySelectorAll('.selected')

  deselect: (elementsToDeselect=@getSelectedEntries()) ->
    selected.classList.remove('selected') for selected in elementsToDeselect
    undefined

  scrollTop: (top) ->
    if top?
      @scroller.scrollTop = top
    else
      @scroller.scrollTop

  scrollBottom: (bottom) ->
    if bottom?
      @scroller.scrollTop = bottom - @scroller.offsetHeight
    else
      @scroller.scrollTop + @scroller.offsetHeight

  scrollToEntry: (entry) ->
    element = if entry?.classList.contains('directory') then entry.header else entry
    element?.scrollIntoViewIfNeeded(true) # true = center around item if possible

  scrollToBottom: ->
    if lastEntry = _.last(@list.querySelectorAll('.entry'))
      @selectEntry(lastEntry)
      @scrollToEntry(lastEntry)

  scrollToTop: ->
    @selectEntry(@roots[0]) if @roots[0]?
    @scroller.scrollTop = 0

  pageUp: ->
    @scroller.scrollTop -= @element.offsetHeight

  pageDown: ->
    @scroller.scrollTop += @element.offsetHeight

  toggleSide: ->
    toggleConfig('tree-view.showOnRightSide')

  moveEntry: (initialPath, newDirectoryPath) ->
    if initialPath is newDirectoryPath
      return

    entryName = path.basename(initialPath)
    newPath = "#{newDirectoryPath}/#{entryName}".replace(/\s+$/, '')

    try
      fs.makeTreeSync(newDirectoryPath) unless fs.existsSync(newDirectoryPath)
      fs.moveSync(initialPath, newPath)
      @emitter.emit 'entry-moved', {initialPath, newPath}

      if repo = repoForPath(newPath)
        repo.getPathStatus(initialPath)
        repo.getPathStatus(newPath)

    catch error
      atom.notifications.addWarning("Failed to move entry #{initialPath} to #{newDirectoryPath}", detail: error.message)

  onStylesheetsChanged: =>
    return unless @isVisible()

    # Force a redraw so the scrollbars are styled correctly based on the theme
    @element.style.display = 'none'
    @element.offsetWidth
    @element.style.display = ''

  onMouseDown: (e) ->
    if entryToSelect = e.target.closest('.entry')
      e.stopPropagation()

      # return early if we're opening a contextual menu (right click) during multi-select mode
      if @multiSelectEnabled() and
         e.target.classList.contains('selected') and
         # mouse right click or ctrl click as right click on darwin platforms
         (e.button is 2 or e.ctrlKey and process.platform is 'darwin')
        return

      if e.shiftKey
        @selectContinuousEntries(entryToSelect)
        @showMultiSelectMenu()
      # only allow ctrl click for multi selection on non darwin systems
      else if e.metaKey or (e.ctrlKey and process.platform isnt 'darwin')
        @selectMultipleEntries(entryToSelect)

        # only show the multi select menu if more then one file/directory is selected
        @showMultiSelectMenu() if @selectedPaths().length > 1
      else
        @selectEntry(entryToSelect)
        @showFullMenu()

  onSideToggled: (newValue) ->
    @element.dataset.showOnRightSide = newValue
    if @isVisible()
      @detach()
      @attach()

  # Public: Return an array of paths from all selected items
  #
  # Example: @selectedPaths()
  # => ['selected/path/one', 'selected/path/two', 'selected/path/three']
  # Returns Array of selected item paths
  selectedPaths: ->
    entry.getPath() for entry in @getSelectedEntries()

  # Public: Selects items within a range defined by a currently selected entry and
  #         a new given entry. This is shift+click functionality
  #
  # Returns array of selected elements
  selectContinuousEntries: (entry) ->
    currentSelectedEntry = @selectedEntry()
    parentContainer = entry.parentElement
    if parentContainer.contains(currentSelectedEntry)
      entries = Array.from(parentContainer.querySelectorAll('.entry'))
      entryIndex = entries.indexOf(entry)
      selectedIndex = entries.indexOf(currentSelectedEntry)
      elements = (entries[i] for i in [entryIndex..selectedIndex])

      @deselect()
      element.classList.add('selected') for element in elements

    elements

  # Public: Selects consecutive given entries without clearing previously selected
  #         items. This is cmd+click functionality
  #
  # Returns given entry
  selectMultipleEntries: (entry) ->
    entry?.classList.toggle('selected')
    entry

  # Public: Toggle full-menu class on the main list element to display the full context
  #         menu.
  showFullMenu: ->
    @list.classList.remove('multi-select')
    @list.classList.add('full-menu')

  # Public: Toggle multi-select class on the main list element to display the the
  #         menu with only items that make sense for multi select functionality
  showMultiSelectMenu: ->
    @list.classList.remove('full-menu')
    @list.classList.add('multi-select')

  # Public: Check for multi-select class on the main list
  #
  # Returns boolean
  multiSelectEnabled: ->
    @list.classList.contains('multi-select')

  onDragEnter: (e) =>
    if header = e.target.closest('.entry.directory > .header')
      return if @rootDragAndDrop.isDragging(e)

      e.stopPropagation()

      entry = header.parentNode
      @dragEventCounts.set(entry, 0) unless @dragEventCounts.get(entry)
      entry.classList.add('selected') if @dragEventCounts.get(entry) is 0
      @dragEventCounts.set(entry, @dragEventCounts.get(entry) + 1)

  onDragLeave: (e) =>
    if header = e.target.closest('.entry.directory > .header')
      return if @rootDragAndDrop.isDragging(e)

      e.stopPropagation()

      entry = header.parentNode
      @dragEventCounts.set(entry, @dragEventCounts.get(entry) - 1)
      entry.classList.remove('selected') if @dragEventCounts.get(entry) is 0

  # Handle entry name object dragstart event
  onDragStart: (e) ->
    if entry = e.target.closest('.entry')
      e.stopPropagation()

      if @rootDragAndDrop.canDragStart(e)
        return @rootDragAndDrop.onDragStart(e)

      target = entry.querySelector(".name")
      initialPath = target.dataset.path

      fileNameElement = target.cloneNode(true)
      for key, value of getStyleObject(target)
        fileNameElement.style[key] = value
      fileNameElement.style.position = 'absolute'
      fileNameElement.style.top = 0
      fileNameElement.style.left = 0
      # Ensure the cloned file name element is rendered on a separate GPU layer
      # to prevent overlapping elements located at (0px, 0px) from being used as
      # the drag image.
      fileNameElement.style.willChange = 'transform'

      document.body.appendChild(fileNameElement)

      e.dataTransfer.effectAllowed = "move"
      e.dataTransfer.setDragImage(fileNameElement, 0, 0)
      e.dataTransfer.setData("initialPath", initialPath)

      window.requestAnimationFrame ->
        fileNameElement.remove()

  # Handle entry dragover event; reset default dragover actions
  onDragOver: (e) ->
    if entry = e.target.closest('.entry')
      return if @rootDragAndDrop.isDragging(e)

      e.preventDefault()
      e.stopPropagation()

      if @dragEventCounts.get(entry) > 0 and not entry.classList.contains('selected')
        entry.classList.add('selected')

  # Handle entry drop event
  onDrop: (e) ->
    if entry = e.target.closest('.entry')
      return if @rootDragAndDrop.isDragging(e)

      e.preventDefault()
      e.stopPropagation()

      entry.classList.remove('selected')

      return unless entry.classList.contains('directory')

      newDirectoryPath = entry.querySelector('.name')?.dataset.path
      return false unless newDirectoryPath

      initialPath = e.dataTransfer.getData("initialPath")

      if initialPath
        # Drop event from Atom
        @moveEntry(initialPath, newDirectoryPath)
      else
        # Drop event from OS
        for file in e.dataTransfer.files
          @moveEntry(file.path, newDirectoryPath)
