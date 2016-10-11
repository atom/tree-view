LocalStorage = window.localStorage
nsync = require 'nsync-fs'
crypto = require 'crypto'

digest = (str) ->
  crypto.createHash('md5').update(str, 'utf8').digest('hex')

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

  open: (path) ->
    atom.workspace.open(path)

  updateProject: (path, directoryExpansionStates) ->
    @loadingNotification?.dismiss()
    initialPaths = atom.project.getPaths()
    initialPaths.forEach (path) -> atom.project.removePath(path)

    atom.project.addPath(path)
    @treeView()?.updateRoots(directoryExpansionStates)
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
      atom.config.observe 'learn-ide.oauthToken', (token) ->
        if token? and token.length
          resolve(token)

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

  saveEditor: (path) ->
    textEditor = atom.workspace.getTextEditors().find (editor) ->
      editor.getPath() is path

    return unless textEditor? and textEditor.isModified()

    node = nsync.getNode(path)
    if node.digest is digest(textEditor.getText())
      textEditor.save()

