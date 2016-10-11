fs = require 'fs-plus'
_ = require 'underscore-plus'
_path = require 'path'
nsync = require 'nsync-fs'
remote = require 'remote'
dialog = remote.require 'dialog'
atomHelper = require './atom-helper'
executeCustomCommand = require './custom-commands'
SingleSocket = require 'single-socket'
{CompositeDisposable} = require 'event-kit'

require('dotenv').config
  path: _path.join(__dirname, '..', '..', '.env')
  silent: true

WS_SERVER_URL = (->
  config = _.defaults
    host: process.env['IDE_WS_HOST']
    port: process.env['IDE_WS_PORT']
    path: process.env['IDE_WS_PATH']
  ,
    host: 'ile.learn.co',
    port: 443,
    path: 'go_fs_server'
    protocol: 'wss'

  if config.port isnt 443
    config.protocol = 'ws'

  {protocol, host, port, path} = config

  "#{protocol}://#{host}:#{port}/#{path}"
)()

convertEOL = (text) ->
  text.replace(/\r\n|\n|\r/g, '\n')

unimplemented = ({type}) ->
  command = type.replace(/^learn-ide:/, '').replace(/-/g, ' ')
  atomHelper.warn 'Learn IDE: coming soon!', {detail: "Sorry, '#{command}' isn't available yet."}

onSave = ({target}) ->
  editor = atomHelper.findTextEditorByElement(target)
  path = editor.getPath()

  if not editor.getPath()?
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

module.exports = helper = (activationState) ->
  disposables = new CompositeDisposable

  disposables.add atomHelper.addCommands
    'learn-ide:save': onSave
    'learn-ide:save-as': unimplemented
    'learn-ide:save-all': unimplemented
    'learn-ide:import': onImport
    'learn-ide:file-open': unimplemented
    'learn-ide:add-project': unimplemented

  disposables.add nsync.onDidConfigure ->
    atomHelper.addOpener (uri) ->
      fs.stat uri, (err, stats) ->
        if err? and nsync.hasPath(uri)
          nsync.open(uri)

  disposables.add nsync.onDidSetPrimary ({localPath, expansionState}) ->
    atomHelper.updateProject(localPath, expansionState)

  disposables.add nsync.onWillLoad ->
    secondsTillNotifying = 2

    setTimeout ->
      unless nsync.hasPrimaryNode()
        atomHelper.loading()
    , secondsTillNotifying * 1000

  disposables.add nsync.onDidDisconnect (detail) ->
    if detail?
      atomHelper.error 'Learn IDE: you are not connected!', {detail}
    else
      atomHelper.disconnected()

  disposables.add nsync.onWillConnect ->
    atomHelper.connecting()

  disposables.add nsync.onDidConnect ->
    atomHelper.connected()

  disposables.add nsync.onDidReceiveCustomCommand (payload) ->
    executeCustomCommand(payload)

  disposables.add nsync.onDidChange (path) ->
    parent = _path.dirname(path)
    atomHelper.reloadTreeView(parent, path)
    atomHelper.updateTitle()

  disposables.add nsync.onDidUpdate (path) ->
    atomHelper.saveEditor(path)

  atomHelper.getToken().then (token) ->
    nsync.configure
      expansionState: activationState.directoryExpansionStates
      localRoot: _path.join(atom.configDirPath, '.learn-ide')
      connection:
        websocket: SingleSocket
        url: "#{WS_SERVER_URL}?token=#{token}"
        spawn: atomHelper.spawn

  return disposables

