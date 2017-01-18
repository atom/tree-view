fs = require 'fs-plus'
_ = require 'underscore-plus'
_path = require 'path'
nsync = require 'nsync-fs'
remote = require 'remote'
{dialog} = require('electron').remote
atomHelper = require './atom-helper'
executeCustomCommand = require './custom-commands'
{CompositeDisposable} = require 'event-kit'

require('dotenv').config
  path: _path.join(__dirname, '..', '..', '.env')
  silent: true

require('dotenv').config
  path: _path.join(atom.getConfigDirPath(), '.env')
  silent: true

WS_SERVER_URL = (->
  config = _.defaults
    host: process.env['IDE_WS_HOST']
    port: process.env['IDE_WS_PORT']
    path: process.env['IDE_WS_FS_PATH']
  ,
    host: 'ile.learn.co',
    port: 443,
    path: 'fs_server'

  {host, port, path} = config
  protocol = if port is 443 then 'wss' else 'ws'

  "#{protocol}://#{host}:#{port}/#{path}"
)()

convertEOL = (text) ->
  text.replace(/\r\n|\n|\r/g, '\n')

unimplemented = ({type}) ->
  command = type.replace(/^learn-ide:/, '').replace(/-/g, ' ')
  atomHelper.warn 'Learn IDE: coming soon!', {detail: "Sorry, '#{command}' isn't available yet."}

onRefresh = ->
  atomHelper.resetPackage()

onSave = ({target}) ->
  editor = atomHelper.findTextEditorByElement(target)
  path = editor.getPath()

  if not path
    # TODO: untitled editor is saved
    return console.warn 'Cannot save file without path'

  text = convertEOL(editor.getText())
  content = new Buffer(text).toString('base64')
  nsync.save(path, content)

onImport = ->
  dialog.showOpenDialog
    title: 'Import Files',
    properties: ['openFile', 'multiSelections']
  , (paths) ->
    importLocalPaths(paths)

importLocalPaths = (localPaths) ->
  localPaths = [localPaths] if typeof localPaths is 'string'
  targetPath = atomHelper.selectedPath()
  targetNode = nsync.getNode(targetPath)

  localPaths.forEach (path) ->
    fs.readFile path, 'base64', (err, data) ->
      if err?
        return console.error 'Unable to import file:', path, err

      base = _path.basename(path)
      newPath = _path.posix.join(targetNode.path, base)

      if nsync.hasPath(newPath)
        atomHelper.warn 'Learn IDE: cannot save file',
          detail: "There is already an existing remote file with path: #{newPath}"
        return

      nsync.save(newPath, data)

onEditorSave = ({path}) ->
  node = nsync.getNode(path)

  node.determineSync().then (shouldSync) ->
    if shouldSync
      atomHelper.findOrCreateBuffer(path).then (textBuffer) ->
        text = convertEOL(textBuffer.getText())
        content = new Buffer(text).toString('base64')
        nsync.save(node.path, content)

onFindAndReplace = (path) ->
  fs.readFile path, 'utf8', (err, data) ->
    if err
      return console.error 'Project Replace Error', err

    text = convertEOL(data)
    content = new Buffer(text).toString('base64')
    nsync.save(path, content)

waitForFile = (localPath, seconds) ->
  setTimeout ->
    fs.stat localPath, (err, stats) ->
      if err? and nsync.hasPath(localPath)
        waitForFile(localPath, seconds * 2)
      else
        atomHelper.resolveOpen(localPath)
  , seconds * 1000

module.exports = helper = (activationState) ->
  composite = new CompositeDisposable

  disposables = [
    atomHelper.addCommands
      'learn-ide:save': onSave
      'learn-ide:reset-connection': -> nsync.resetConnection()
      'learn-ide:save-as': unimplemented
      'learn-ide:save-all': unimplemented
      'learn-ide:import': onImport
      'learn-ide:file-open': unimplemented
      'learn-ide:add-project': unimplemented
      'learn-ide-tree:refresh': onRefresh

    nsync.onDidConfigure ->
      atomHelper.addOpener (uri) ->
        fs.stat uri, (err, stats) ->
          if err? and nsync.hasPath(uri)
            atomHelper.loadingFile(uri)
            nsync.open(uri)
            waitForFile(uri, 1)

    nsync.onDidOpen ({localPath}) ->
      atomHelper.resolveOpen(localPath)

    nsync.onDidSetPrimary ({localPath, expansionState}) ->
      atomHelper.updateProject(localPath, expansionState)

    nsync.onWillLoad ->
      secondsTillNotifying = 2

      setTimeout ->
        unless nsync.hasPrimaryNode()
          atomHelper.loading()
      , secondsTillNotifying * 1000

    nsync.onDidDisconnect ->
      atomHelper.disconnected()

    nsync.onDidSendWhileDisconnected (msg) ->
        atomHelper.error 'Learn IDE: you are not connected!',
          detail: "The operation cannot be performed while disconnected {command: #{msg.command}}"

    nsync.onDidConnect ->
      atomHelper.connected()

    nsync.onDidReceiveCustomCommand (payload) ->
      executeCustomCommand(payload)

    nsync.onDidChange (path) ->
      parent = _path.dirname(path)
      atomHelper.reloadTreeView(parent, path)
      atomHelper.updateTitle()

    nsync.onDidUpdate (path) ->
      atomHelper.saveEditor(path)

    atomHelper.observeTextEditors (editor) ->
      composite.add editor.onDidSave (e) ->
        onEditorSave(e)

    atomHelper.on 'learn-ide:logout', ->
      pkg = atom.packages.loadPackage('learn-ide-tree')
      pkg.mainModule.preventCache = true
      nsync.flushCache()

    atomHelper.onDidActivatePackage (pkg) ->
      if pkg.name is 'find-and-replace'
        projectFindView = pkg.mainModule.projectFindView
        resultModel = projectFindView.model

        composite.add resultModel.onDidReplacePath ({filePath}) ->
          onFindAndReplace(filePath)
  ]

  disposables.forEach (disposable) -> composite.add(disposable)

  atomHelper.getToken().then (token) ->
    nsync.configure
      expansionState: activationState.directoryExpansionStates
      localRoot: _path.join(atom.configDirPath, '.learn-ide')
      connection:
        url: "#{WS_SERVER_URL}?token=#{token}&version=#{atomHelper.learnIdeVersion()}"

  return composite

