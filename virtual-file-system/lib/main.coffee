_ = require 'underscore-plus'
_path = require 'path'
convert = require './util/path-converter'
fs = require 'fs-plus'
shell = require 'shell'
AtomHelper = require './atom-helper'
ConnectionManager = require './connection-manager'
FSAdapter = require './adapters/fs-adapter'
FileSystemNode = require './file-system-node'
ShellAdapter = require './adapters/shell-adapter'

class VirtualFileSystem
  constructor: ->
    @atomHelper = new AtomHelper(this)
    @fs = new FSAdapter(this)
    @shell = new ShellAdapter(this)
    @projectNode = new FileSystemNode({})
    @connectionManager = new ConnectionManager(this)
    @reconnectCount = 0

    @setLocalPaths()

    @connectionManager.connect()
    @addOpener()

  setLocalPaths: ->
    @localRoot = _path.join(@atomHelper.configPath(), '.learn-ide')
    convert.configure({@localRoot})

    @logDirectory = _path.join(@localRoot, 'var', 'log')
    @receivedLog = _path.join(@logDirectory, 'received')
    @sentLog = _path.join(@logDirectory, 'sent')

    @cacheDirectory = _path.join(@localRoot, 'var', 'cache')
    @cachedProjectNode = _path.join(@cacheDirectory, 'project-node')

    fs.makeTreeSync(@logDirectory)
    fs.makeTreeSync(@cacheDirectory)

  addOpener: ->
    @atomHelper.addOpener (uri) =>
      fs.stat uri, (err, stats) =>
        if err? and @hasPath(uri)
          @open(uri)

  serialize: ->
    @projectNode.serialize()

  cache: ->
    serializedNode = @serialize()

    if serializedNode.path?
      data = JSON.stringify(serializedNode)
      fs.writeFile(@cachedProjectNode, data)

  loading: ->
    secondsTillNotifying = 3

    setTimeout =>
      if not @projectNode.path?
        @loadingNotification = @atomHelper.loading()
    , secondsTillNotifying * 1000

  setActivationState: (activationState) ->
    @activationState = activationState

  setProjectNodeFromCache: (serializedNode) ->
    return if @projectNode.path?

    @projectNode = new FileSystemNode(serializedNode)
    expansion = @activationState?.directoryExpansionStates

    @atomHelper.updateProject(@projectNode.localPath(), expansion)

  setProjectNode: (serializedNode) ->
    @projectNode = new FileSystemNode(serializedNode)
    expansion = @activationState?.directoryExpansionStates
    @activationState = undefined

    @loadingNotification?.dismiss()
    @loadingNotification = null

    @atomHelper.updateProject(@projectNode.localPath(), expansion)
    @sync(@projectNode.path)

  activate: ->
    fs.readFile @cachedProjectNode, (err, data) =>
      if err?
        console.error 'Unable to load cached project node:', err
        @loading()
        return

      try
        serializedNode = JSON.parse(data)
      catch error
        console.error 'Unable to parse cached project node:', error
        @loading()
        return

      @setProjectNodeFromCache(serializedNode)

  expansionState: ->
    @activationState?.directoryExpansionStates

  send: (msg) ->
    convertedMsg = {}

    for own key, value of msg
      if typeof value is 'string' and value.startsWith(@localRoot)
        convertedMsg[key] = convert.localToRemote(value)
      else
        convertedMsg[key] = value

    @connectionManager.send(convertedMsg)

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

  init: ->
    @send {command: 'init'}

  cp: (source, destination) ->
    @send {command: 'cp', source, destination}

  mv: (source, destination) ->
    @send {command: 'mv', source, destination}

  mkdirp: (path) ->
    @send {command: 'mkdirp', path}

  touch: (path) ->
    @send {command: 'touch', path}

  rm: (path) ->
    @send {command: 'rm', path}

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

