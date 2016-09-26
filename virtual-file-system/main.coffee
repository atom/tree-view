fs = require 'fs-plus'
_ = require 'underscore-plus'
shell = require 'shell'
_path = require 'path'
convert = require './util/path-converter'
AtomHelper = require './atom-helper'
FileSystemNode = require './file-system-node'
ShellAdapter = require './adapters/shell-adapter'
FSAdapter = require './adapters/fs-adapter'
MessageHandler = require './message-handler'
SingleSocket = require 'single-socket'

require('dotenv').config
  path: _path.join(__dirname, '..', '.env'),
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

class VirtualFileSystem
  constructor: ->
    @atomHelper = new AtomHelper(this)
    @fs = new FSAdapter(this)
    @shell = new ShellAdapter(this)
    @projectNode = new FileSystemNode({})

    @setLocalPaths()

    @connect()
    @addOpener()

  setLocalPaths: ->
    @localRoot = _path.join(@atomHelper.configPath(), '.learn-ide')
    @logDirectory = _path.join(@localRoot, 'var', 'log')
    @receivedLog = _path.join(@logDirectory, 'received')
    @sentLog = _path.join(@logDirectory, 'sent')
    convert.configure({@localRoot})

    fs.makeTreeSync(@logDirectory)

  connect: ->
    @websocket = new WebSocket "#{WS_SERVER_URL}?token=#{@atomHelper.token()}"

    @websocket.onopen = =>
      @activate()
      @send {command: 'init'}

    @websocket.onmessage = (event) =>
      new MessageHandler(event, this)

    @websocket.onerror = (err) =>
      console.error 'ERROR:', err
      @atomHelper.cannotConnect()

    @websocket.onclose = (event) =>
      console.log 'CLOSED:', event
      @atomHelper.disconnected()

  addOpener: ->
    @atomHelper.addOpener (uri) =>
      if @hasPath(uri) and not fs.existsSync(uri)
        @open(uri)

  serialize: ->
    @projectNode.serialize()

  setActivationState: (activationState) ->
    @activationState = activationState

  activate: ->
    return @atomHelper.loading() unless @activationState.virtualProject?

    @projectNode = new FileSystemNode(@activationState.virtualProject)

    if not @projectNode.path?
      return @atomHelper.loading()

    @atomHelper.updateProject(@projectNode.localPath(), @expansionState())

  expansionState: ->
    @activationState?.directoryExpansionStates

  send: (msg) ->
    convertedMsg = {}

    for own key, value of msg
      if typeof value is 'string' and value.startsWith(@localRoot)
        convertedMsg[key] = convert.localToRemote(value)
      else
        convertedMsg[key] = value

    console.log 'SEND:', convertedMsg
    payload = JSON.stringify(convertedMsg)
    fs.appendFileSync(@sentLog, "\n#{new Date}: #{payload}")
    @websocket.send payload

  # ------------------
  # File introspection
  # ------------------

  getNode: (path) ->
    @projectNode.get(path)

  hasPath: (path) ->
    @projectNode.has(path)

  isDirectory: (path) ->
    @stat(path).isDirectory()

  isFile: (path) ->
    @stat(path).isFile()

  isSymbolicLink: (path) ->
    @stat(path).isSymbolicLink()

  list: (path, extension) ->
    @getNode(path).list(extension)

  lstat: (path) ->
    # TODO: lstat
    @stat(path)

  read: (path) ->
    @getNode(path)

  readdir: (path) ->
    @getNode(path).entries()

  realpath: (path) ->
    # TODO: realpath
    path

  stat: (path) ->
    @getNode(path)?.stats

  # ---------------
  # File operations
  # ---------------

  cp: (source, destination) ->
    @send {command: 'cp', source, destination}

  mv: (source, destination) ->
    @send {command: 'mv', source, destination}

  mkdirp: (path) ->
    @send {command: 'mkdirp', path}

  touch: (path) ->
    @send {command: 'touch', path}

  trash: (path) ->
    @send {command: 'trash', path}

  sync: (path) ->
    @send {command: 'sync', path}

  open: (path) ->
    @send {command: 'open', path}

  fetch: (paths) ->
    paths = [paths] if typeof paths is 'string'

    if paths.length
      @send {command: 'fetch', paths}

  save: (path, content) ->
    @send {command: 'save', path, content}

module.exports = new VirtualFileSystem

