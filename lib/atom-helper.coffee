# fs = require 'graceful-fs'
# CSON = require 'cson'
# _path = require 'path'
# crypto = require 'crypto'
LocalStorage = window.localStorage
# {CompositeDisposable} = require 'atom'
# remote = require 'remote'
# dialog = remote.require 'dialog'
nsync = require 'nsync-fs'

# humanize = (seconds) ->
#   minutes = Math.floor(seconds / 60)
#   time = if minutes then minutes else seconds
#   unit = if minutes then 'minute' else 'second'
#   "#{time} #{unit}#{if time is 1 then '' else 's'}"

# convertEOL = (text) ->
#   text.replace(/\r\n|\n|\r/g, '\n')

# digest = (str) ->
#   crypto.createHash('md5').update(str, 'utf8').digest('hex')

module.exports = helper =
  addOpener: (callback) ->
    atom.workspace.addOpener(callback)

  success: (msg, opts) ->
    atom.notifications.addSuccess(msg, opts)

  info: (msg, opts) ->
    atom.notifications.addInfo(msg, opts)

  warn: (msg, opts) ->
    atom.notifications.addWarning(msg, opts)

  error: (msg, opts) ->
    atom.notifications.addError(msg, opts)

  loading: ->
    @loadingNotification =
      @info 'Learn IDE: loading your remote code...',
        detail: """This may take a moment, but will only happen
                very occasionally (maybe just once)"""
        dismissable: true

  updateProject: (path, directoryExpansionStates) ->
    @loadingNotification?.dismiss()
    initialPaths = atom.project.getPaths()
    initialPaths.forEach (path) -> atom.project.removePath(path)

    atom.project.addPath(path)
    helper.treeView()?.updateRoots(directoryExpansionStates)
    helper.updateTitle()

  replaceTitleUpdater: ->
    if not LocalStorage.getItem('workspace:updateTitle')
      LocalStorage.setItem('workspace:updateTitle', atom.workspace.updateWindowTitle)
      atom.workspace.updateWindowTitle = helper.updateTitle

  updateTitle: ->
    helper.replaceTitleUpdater()
    itemPath = atom.workspace.getActivePaneItem()?.getPath?()

    node =
      if itemPath?
        nsync.getNode(itemPath)
      else
        nsync.primaryNode

    title = 'Learn IDE'

    if node? and node.path?
      title += " — #{node.path.replace(/^\//, '')}"
      atom.applicationDelegate.setRepresentedFilename(node.localPath())

    document.title = title

  treeView: ->
    pkg = atom.packages.getActivePackage('learn-ide-tree')
    pkg?.mainModule.treeView

  # reloadTreeView: (path, pathToSelect) ->
  #   @treeView()?.entryForPath(path).reload()
  #   @treeView()?.selectEntryForPath(pathToSelect or path)

  # findBuffer: (path) ->
  #   atom.project.findBufferForPath(path)

  # findOrCreateBuffer: (path) ->
  #   atom.project.bufferForPath(path)

  # unimplemented: ({type}) =>
  #   command = type.replace(/^learn-ide:/, '').replace(/-/g, ' ')
  #   @warn 'Learn IDE: coming soon!', {detail: "Sorry, '#{command}' isn't available yet."}

  # disconnected: ->
  #   @error 'Learn IDE: connection lost 😮',
  #     detail: 'The connection with the remote server has been lost.'
  #     dismissable: false

  # connecting: (seconds) ->
  #   @warn 'Learn IDE: attempting to connect...', {dismissable: true}

  # onLearnSave: ({target}) =>
  #   textEditor = atom.workspace.getTextEditors().find (editor) ->
  #     editor.element is target

  #   if not textEditor.getPath()?
  #     # TODO: this happens if an untitled editor is saved. need to build a 'Save As' or sorts
  #     return console.log 'Cannot save file without path'

  #   text = convertEOL(textEditor.getText())
  #   content = new Buffer(text).toString('base64')
  #   @virtualFileSystem.save(textEditor.getPath(), content)

  # onEditorSave: ({path}) =>
  #   node = @virtualFileSystem.getNode(path)

  #   node.determineSync().then (shouldSync) =>
  #     if shouldSync
  #       @findOrCreateBuffer(path).then (textBuffer) =>
  #         text = convertEOL(textBuffer.getText())
  #         content = new Buffer(text).toString('base64')
  #         @virtualFileSystem.save(path, content)

  # saveEditorForPath: (path) ->
  #   textEditor = atom.workspace.getTextEditors().find (editor) ->
  #     editor.getPath() is path

  #   return false unless textEditor?

  #   if not textEditor.isModified()
  #     false
  #   else
  #     node = @virtualFileSystem.getNode(path)
  #     if node.digest is digest(textEditor.getText())
  #       textEditor.save()
  #       true
  #     false

  # saveAfterProjectReplace: (path) =>
  #   fs.readFile path, 'utf8', (err, data) =>
  #     if err
  #       return console.error "Project Replace Error", err

  #     text = convertEOL(data)
  #     content = new Buffer(text).toString('base64')
  #     @virtualFileSystem.save(path, content)

  # addMenu: ->
  #   path = _path.join(__dirname, '..', 'menus', 'menu.cson')

  #   fs.readFile path, (err, data) ->
  #     if err?
  #       return console.error "Unable to add menu:", err

  #     atom.menu.add CSON.parse(data)

  # addKeymaps: ->
  #   path = _path.join(__dirname, '..', 'keymaps', 'keymaps.cson')

  #   fs.readFile path, (err, data) ->
  #     if err?
  #       return console.error "Unable to add keymaps:", err

  #     atom.keymaps.add path, CSON.parse(data)

  # addContextMenus: ->
  #   path = _path.join(__dirname, '..', 'menus', 'context-menus.cson')

  #   fs.readFile path, (err, data) ->
  #     if err?
  #       return console.error "Unable to add context-menus:", err

  #     atom.contextMenu.add CSON.parse(data)

  # onImport: =>
  #   dialog.showOpenDialog
  #     title: 'Import Files',
  #     properties: ['openFile', 'multiSelections']
  #   , (paths) => @importLocalPaths(paths)


  # importLocalPaths: (localPaths) ->
  #   localPaths = [localPaths] if typeof localPaths is 'string'
  #   targetPath = @treeView().selectedPath
  #   targetNode = @virtualFileSystem.getNode(targetPath)

  #   localPaths.forEach (path) =>
  #     fs.readFile path, 'base64', (err, data) =>
  #       if err?
  #         return console.error 'Unable to import file:', path, err

  #       base = _path.basename(path)
  #       newPath = _path.posix.join(targetNode.path, base)

  #       if @virtualFileSystem.hasPath(newPath)
  #         @warn 'Learn IDE: cannot save file',
  #           detail: """There is already an existing remote file with path:
  #                   #{newPath}"""
  #         return

  #       @virtualFileSystem.save(newPath, data)

