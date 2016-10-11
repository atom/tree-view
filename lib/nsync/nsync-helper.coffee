fs = require 'fs-plus'
_ = require 'underscore-plus'
_path = require 'path'
nsync = require 'nsync-fs'
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

module.exports = helper = (activationState) ->
  disposables = new CompositeDisposable

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

