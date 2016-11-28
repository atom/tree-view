LocalStorage = window.localStorage
nsync = require 'nsync-fs'
crypto = require 'crypto'
fs = require 'fs-plus'
_path = require 'path'

digest = (str) ->
  crypto.createHash('md5').update(str, 'utf8').digest('hex')

module.exports = helper =
  addOpener: (callback) ->
    atom.workspace.addOpener(callback)

  addCommands: (commands, target = 'atom-workspace') ->
    atom.commands.add(target, commands)

  on: (key, callback) ->
    atom.emitter.on(key, callback)

  success: (msg, opts) ->
    atom.notifications.addSuccess(msg, opts)

  info: (msg, opts) ->
    atom.notifications.addInfo(msg, opts)

  warn: (msg, opts) ->
    atom.notifications.addWarning(msg, opts)

  error: (msg, opts) ->
    atom.notifications.addError(msg, opts)

  loadingFile: (path) ->
    @loadingFileNotifications ?= {}
    @loadingFileNotifications[path] =
      @info "Learn IDE: loading #{_path.basename(path)}...",
        detail: """Please leave this file blank and the contents
                will appear automatically (as you long as
                you have not altered the file)"""
        dismissable: true

  loading: ->
    @loadingNotification =
      @info 'Learn IDE: loading your remote code...',
        detail: """This may take a moment, but will only happen
                very occasionally (maybe just once)"""
        dismissable: true

  open: (path) ->
    atom.workspace.open(path).then =>
      @treeView()?.revealActiveFile()

  updateProject: (path, directoryExpansionStates) ->
    @loadingNotification?.dismiss()
    initialPaths = atom.project.getPaths()
    initialPaths.forEach (path) -> atom.project.removePath(path)

    fs.makeTreeSync(path)
    atom.project.addPath(path)
    @treeView().updateRoots(directoryExpansionStates)
    @updateTitle()

  resetTitleUpdate: ->
    # TODO: call this on deactivate
    atom.workspace.updateWindowTitle = LocalStorage.getItem('workspace:updateTitle')
    LocalStorage.removeItem('workspace:updateTitle')

  replaceTitleUpdater: ->
    if not LocalStorage.getItem('workspace:updateTitle')
      LocalStorage.setItem('workspace:updateTitle', atom.workspace.updateWindowTitle)
      atom.workspace.updateWindowTitle = @updateTitle

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

  getToken: ->
    new Promise (resolve) ->
      pkg = atom.packages.loadPackage('learn-ide')
      token = pkg.mainModule.token

      token.observe (value) ->
        if value?
          resolve(value)

  spawn: (modulePath) ->
    {BufferedNodeProcess} = require 'atom'
    new BufferedNodeProcess({command: modulePath})

  disconnected: ->
    @error 'Learn IDE: connection lost 😮',
      detail: 'The connection with the remote server has been lost.'

  connecting: ->
    @connectingNotification =
      @warn 'Learn IDE: attempting to connect...', {dismissable: true}

  connected: ->
    @connectingNotification?.dismiss()
    @connectingNotification = null
    @success 'Learn IDE: connected!'

  reloadTreeView: (path, pathToSelect) ->
    @treeView()?.entryForPath(path).reload()
    @treeView()?.selectEntryForPath(pathToSelect or path)

  selectedPath: ->
    @treeView()?.selectedPath

  onDidActivatePackage: (callback) ->
    atom.packages.onDidActivatePackage(callback)

  observeTextEditors: (callback) ->
    atom.workspace.observeTextEditors(callback)

  findTextEditorByElement: (element) ->
    atom.workspace.getTextEditors().find (editor) ->
      editor.element is element

  findTextEditorByPath: (path) ->
    atom.workspace.getTextEditors().find (editor) ->
      editor.getPath() is path

  findOrCreateBuffer: (path) ->
    atom.project.bufferForPath(path)

  saveEditor: (path) ->
    textEditor = @findTextEditorByPath(path)

    return unless textEditor? and textEditor.isModified()

    node = nsync.getNode(path)
    if node.digest is digest(textEditor.getText())
      textEditor.save()

  resolveOpen: (path) ->
    notification = @loadingFileNotifications[path]
    if notification?
      @refreshBuffer(path)
      notification.dismiss()
      delete @loadingFileNotifications[path]

  refreshBuffer: (path) ->
    textBuffer = atom.project.findBufferForPath(path)

    if textBuffer.isEmpty()
      textBuffer.updateCachedDiskContents false, ->
        textBuffer.subscribeToFile()
        textBuffer.reload()

  resetPackage: ->
    atom.packages.deactivatePackage('learn-ide-tree')
    atom.packages.activatePackage('learn-ide-tree')

  termFocus: ->
    view = atom.views.getView(atom.workspace)
    atom.commands.dispatch view, 'learn-ide:focus'

