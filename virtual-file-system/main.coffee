fs = require 'fs-plus'
_ = require 'underscore-plus'
shell = require 'shell'
_path = require 'path'
convert = require './util/path-converter'
FileSystemNode = require './file-system-node'
ShellAdapter = require './adapters/shell-adapter'
FSAdapter = require './adapters/fs-adapter'
SingleSocket = require 'single-socket'

require('dotenv').config({
  path: _path.join(__dirname, '../.env'),
  silent: true
});

WS_SERVER_URL = (->
  config = _.defaults
    host: process.env['IDE_WS_HOST'],
    port: process.env['IDE_WS_PORT']
  ,
    host: 'ile.learn.co',
    port: 443,
    protocol: 'wss'

  if config.port != 443
    config.protocol = 'ws'

  "#{config.protocol}://#{config.host}:#{config.port}"
)()

token = atom.config.get('learn-ide.oauthToken')

class VirtualFileSystem
  constructor: ->
    @initialProjectPaths = atom.project.getPaths()
    @initialProjectPaths.forEach (path) -> atom.project.removePath(path)

    @localRoot = _path.join(atom.configDirPath, '.learn-ide')
    convert.configure({@localRoot})

    @rootNode = new FileSystemNode({})

    @fs = new FSAdapter(this)
    @shell = new ShellAdapter(this)

    @connect()
    @addOpener()
    @observeSave()

  connect: ->
    messageCallbacks =
      init: @onRecievedInit
      sync: @onRecievedSync
      open: @onRecievedFetchOrOpen
      fetch: @onRecievedFetchOrOpen
      change: @onRecievedChange
      rescue: @onRecievedRescue

    @websocket = new SingleSocket "#{WS_SERVER_URL}/tree?token=#{token}",
      onopen: () =>
        @send {command: 'init'}
      onmessage: (data) ->
        {type, payload} = JSON.parse(data)
        console.log 'RECEIVED:', type
        messageCallbacks[type]?(payload)
      onerror: (err) ->
        console.error 'ERROR:', err
      onclose: (event) ->
        console.log 'CLOSED:', event

  addOpener: ->
    atom.workspace.addOpener (uri) =>
      if @hasPath(uri) and not fs.existsSync(uri)
        @open(uri)

  observeSave: ->
    atom.workspace.observeTextEditors (editor) =>
      editor.onDidSave ({path}) =>
        @save(path)

  package: ->
    # todo: update package name
    atom.packages.getActivePackage('tree-view')

  treeView: ->
    @package()?.mainModule.treeView

  send: (msg) ->
    payload = {}

    for own key, value of msg
      if typeof value is 'string' and value.startsWith(@localRoot)
        payload[key] = convert.localToRemote(value)
      else
        payload[key] = value

    console.log 'SEND:', payload
    @websocket.send JSON.stringify(payload)

  # -------------------
  # onmessage callbacks
  # -------------------

  onRecievedInit: ({project}) =>
    @rootNode = new FileSystemNode(project)
    atom.project.addPath(@rootNode.localPath())
    @treeView()?.updateRoots(@activationState?.directoryExpansionStates)
    @sync(@rootNode.path)

  onRecievedSync: ({root, digests}) =>
    console.log 'SYNC:', root
    node = @getNode(root)
    localPath = node.localPath()

    node.traverse (entry) ->
      entry.setDigest(digests[entry.path])

    if fs.existsSync(localPath)
      remotePaths = node.map (e) -> e.localPath()
      localPaths = fs.listTreeSync(localPath)
      pathsToRemove = _.difference(localPaths, remotePaths)
      pathsToRemove.forEach (path) -> shell.moveItemToTrash(path)

    node.findPathsToSync().then (paths) => @fetch(paths)

  onRecievedChange: ({path, parent}) =>
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

