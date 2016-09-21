fs = require 'fs-plus'
_ = require 'underscore-plus'
shell = require 'shell'
_path = require 'path'
convert = require './util/path-converter'
FileSystemNode = require './file-system-node'
ShellAdapter = require './adapters/shell-adapter'
FSAdapter = require './adapters/fs-adapter'
SingleSocket = require 'single-socket'

require('dotenv').config
  path: _path.join(__dirname, '../.env'),
  silent: true

notifyOfLoad = ->
  atom.notifications.addInfo 'Learn IDE: loading your remote code...',
    detail: """
            This may take a moment, but you likely won't need
            to wait again on this computer.
            """

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

token = atom.config.get('learn-ide.oauthToken')

class VirtualFileSystem
  constructor: ->
    @setLocalPaths()
    @rootNode = new FileSystemNode({})

    @fs = new FSAdapter(this)
    @shell = new ShellAdapter(this)

    @initialProjectPaths = atom.project.getPaths()
    @initialProjectPaths.forEach (path) -> atom.project.removePath(path)

    @connect()
    @addOpener()
    @observeSave()

  setLocalPaths: ->
    @localRoot = _path.join(atom.configDirPath, '.learn-ide')
    @logDirectory = _path.join(@localRoot, 'var', 'log')
    @cacheDirectory = _path.join(@localRoot, 'var', 'cache')
    @cachedRootNode = _path.join(@cacheDirectory, 'root_node')
    @receivedLog = _path.join(@logDirectory, 'received')
    @sentLog = _path.join(@logDirectory, 'sent')
    convert.configure({@localRoot})

    fs.makeTreeSync(@logDirectory)
    fs.makeTreeSync(@cacheDirectory)

  connect: ->
    messageCallbacks =
      init: @onRecievedInit
      sync: @onRecievedSync
      open: @onRecievedFetchOrOpen
      fetch: @onRecievedFetchOrOpen
      change: @onRecievedChange
      rescue: @onRecievedRescue

    @websocket = new WebSocket "#{WS_SERVER_URL}?token=#{token}"

    @websocket.onopen = =>
      @send {command: 'init'}

    @websocket.onmessage = (event) =>
      message = event.data
      fs.appendFileSync(@receivedLog, "\n#{new Date}: #{message}")

      try
        {type, data} = JSON.parse(message)
        console.log 'RECEIVED:', type
      catch err
        console.log 'ERROR PARSING MESSAGE:', message, err

      messageCallbacks[type]?(data)

    @websocket.onerror = (err) ->
      console.error 'ERROR:', err

    @websocket.onclose = (event) ->
      console.log 'CLOSED:', event

  addOpener: ->
    atom.workspace.addOpener (uri) =>
      if @hasPath(uri) and not fs.existsSync(uri)
        @open(uri)

  observeSave: ->
    body = document.body
    body.classList.add('learn-ide')

    atom.commands.add body, 'learn-ide:save', (e) ->
      console.log 'SAVE!', e

    # atom.commands.onWillDispatch (e) =>
    #   {type, target} = e

    #   if type is 'core:save'
    #     textEditor = atom.workspace.getTextEditors().find (editor) ->
    #       editor.element is target

    #   if textEditor?
    #     e.preventDefault()
    #     e.stopPropagation()
    #     @save(textEditor.getPath())
    # atom.workspace.observeTextEditors (editor) =>
    #   editor.onDidSave ({path}) =>
    #     @save(path)

  deactivate: ->
    if @rootNode.path?
      data = JSON.stringify(@rootNode.serialize())
      fs.writeFileSync(@cachedRootNode, data)

  activate: (@activationState) ->
    fs.readFile @cachedRootNode, (err, data) =>
      if err?
        notifyOfLoad()

      try
        virtualFile = JSON.parse(data)
        @rootNode = new FileSystemNode(virtualFile)
        if @rootNode.path?
          atom.project.addPath(@rootNode.localPath())
          @treeView()?.updateRoots(@activationState?.directoryExpansionStates)
      catch err
        notifyOfLoad()

  package: ->
    # todo: update package name
    atom.packages.getActivePackage('tree-view')

  treeView: ->
    @package()?.mainModule.treeView

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

  # -------------------
  # onmessage callbacks
  # -------------------

  onRecievedInit: ({virtualFile}) =>
    @rootNode = new FileSystemNode(virtualFile)
    atom.project.addPath(@rootNode.localPath())
    @treeView()?.updateRoots(@activationState?.directoryExpansionStates)
    @sync(@rootNode.path)

  onRecievedSync: ({path, pathAttributes}) =>
    console.log 'SYNC:', path
    node = @getNode(path)
    localPath = node.localPath()

    node.traverse (entry) ->
      entry.setDigest(pathAttributes[entry.path])

    if fs.existsSync(localPath)
      remotePaths = node.map (e) -> e.localPath()
      localPaths = fs.listTreeSync(localPath)
      pathsToRemove = _.difference(localPaths, remotePaths)
      pathsToRemove.forEach (path) -> shell.moveItemToTrash(path)

    node.findPathsToSync().then (paths) => @fetch(paths)

  onRecievedChange: ({path, isDir}) =>
    console.log 'CHANGE:', path
    node = @rootNode.update(parent)

    @treeView()?.entryForPath(node.localPath()).reload()
    @treeView()?.selectEntryForPath(path)
    @sync(parent.path)

  onRecievedFetchOrOpen: ({path, content}) =>
    # TODO: preserve full stats
    node = @getNode(path)
    node.setContent(content)

    stats = node.stats
    if stats.isDirectory()
      return fs.makeTreeSync(node.localPath())

    mode = stats.mode
    textBuffer = atom.project.findBufferForPath(node.localPath())
    if textBuffer?
      fs.writeFileSync(node.localPath(), node.buffer(), {mode})
      textBuffer.updateCachedDiskContentsSync()
      textBuffer.reload()
    else
      fs.writeFile(node.localPath(), node.buffer(), {mode})

  onRecievedRescue: ({message, backtrace}) ->
    console.log 'RESCUE:', message, backtrace

  # ------------------
  # File introspection
  # ------------------

  getNode: (path) ->
    @rootNode.get(path)

  hasPath: (path) ->
    @rootNode.has(path)

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
    @getNode(path).entries

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
    @send {command: 'fetch', paths}

  save: (path) ->
    atom.project.bufferForPath(path).then (textBuffer) =>
      content = new Buffer(textBuffer.getText()).toString('base64')
      @send {command: 'save', path, content}

module.exports = new VirtualFileSystem

