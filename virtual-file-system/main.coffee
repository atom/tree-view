fs = require 'fs-plus'
shell = require 'shell'
_path = require 'path'
Entry = require './entry'
Tree = require './tree'
ShellAdapter = require './adapters/shell-adapter'
FSAdapter = require './adapters/fs-adapter'
PathConverter = require './util/path-converter'

serverURI = 'ws://vm02.students.learn.co:3304/background_sync'
token     = atom.config.get('integrated-learn-environment.oauthToken')

class VirtualFileSystem
  constructor: ->
    @projectPaths = atom.project.getPaths()
    @projectPaths.forEach (path) -> atom.project.removePath(path)

    @physicalRoot = _path.join(atom.configDirPath, '.learn-ide')
    @convert = new PathConverter(@physicalRoot)
    @tree = new Tree({}, @convert)

    @fs = new FSAdapter(this)
    @shell = new ShellAdapter(this)

    @websocket = new WebSocket("#{serverURI}?token=#{token}")
    @addOpener()
    @observeSave()
    @handleEvents()

  addOpener: ->
    atom.workspace.addOpener (uri) =>
      if @hasPath(uri) and not fs.existsSync(uri)
        @open(uri)

  observeSave: ->
    atom.workspace.observeTextEditors (editor) =>
      editor.onDidSave ({path}) =>
        @save(path)

  handleEvents: ->
    messageCallbacks =
      sync: @onRecievedSync
      open: @onRecievedOpen
      build: @onRecievedBuild
      fetch: @onRecievedFetch
      change: @onRecievedChange
      rescue: @onRecievedRescue

    @websocket.onopen = (event) =>
      @send {command: 'build'}

    @websocket.onmessage = (event) ->
      {type, payload} = JSON.parse(event.data)
      console.log 'RECEIVED:', type
      messageCallbacks[type]?(payload)

    @websocket.onerror = (err) ->
      console.log 'ERROR:', err

    @websocket.onclose = (event) ->
      console.log 'CLOSED:', event

  package: ->
    # todo: update package name
    atom.packages.getActivePackage('tree-view')

  treeView: ->
    @package()?.mainModule.treeView

  send: (msg) ->
    convertedMsg = {}

    for own key, value of msg
      if typeof value is 'string' and value.startsWith(@physicalRoot)
        convertedMsg[key] = @convert.localToRemote(value)
      else
        convertedMsg[key] = value

    console.log 'SEND:', convertedMsg
    payload = JSON.stringify(convertedMsg)
    @websocket.send(payload)

  # -------------------
  # onmessage callbacks
  # -------------------

  onRecievedBuild: ({entries, root}) =>
    @root = @convert.remoteToLocal(root)
    @tree.update(entries, root)
    atom.project.addPath(@root)
    # TODO: persist title change, maybe use custom-title package
    document.title = "Learn IDE - #{@convert.localToRemote(@root).substr(1)}"
    @sync()
    @treeView()?.updateRoots()

  onRecievedSync: ({entries}) =>
    @tree.addDigests(entries)
    fs.makeTreeSync(@physicalRoot) unless fs.existsSync(@physicalRoot)
    @tree.getLocalPathsToRemove().forEach (path) -> shell.moveItemToTrash(path)
    @tree.getLocalPathsToSync().then (paths) => @fetch(paths)

  onRecievedChange: ({entries, path, parent}) =>
    console.log 'CHANGE:', path
    @tree.update(entries)
    @sync()

    parent = @convert.remoteToLocal(parent)
    @treeView()?.entryForPath(parent).reload()

    path = @convert.remoteToLocal(path)
    @treeView()?.selectEntryForPath(path)

  onRecievedFetch: ({path, attributes, content, directory}) =>
    # TODO: preserve full stats
    localPath = @convert.remoteToLocal(path)
    dirname = _path.dirname(localPath)
    return unless localPath? and dirname?

    fs.makeTreeSync(dirname) unless fs.existsSync(dirname)

    if directory?
      fs.makeTreeSync(localPath)
    else
      decoded = new Buffer(content, 'base64').toString('utf8')
      fs.writeFile(localPath, decoded)

  onRecievedOpen: ({path, attributes, content}) =>
    localPath = @convert.remoteToLocal(path)
    dirname = _path.dirname(localPath)
    return unless localPath? and dirname?
    return if fs.existsSync(localPath)

    fs.makeTreeSync(dirname) unless fs.existsSync(dirname)
    decoded = new Buffer(content, 'base64').toString('utf8')
    fs.writeFileSync(localPath, decoded)

    buffer = atom.project.findBufferForPath(localPath)
    buffer.updateCachedDiskContentsSync()
    buffer.reload()

  onRecievedRescue: ({message, backtrace}) ->
    console.log 'RESCUE:', message, backtrace

  # ------------------
  # Background syncing
  # ------------------

  sync: ->
    @send {command: 'sync'}

  fetch: (paths) ->
    pathsToFetch = paths.map (path) => @convert.localToRemote(path)
    @send {command: 'fetch', paths: pathsToFetch}

  # ------------------
  # File introspection
  # ------------------

  getEntry: (path) ->
    @tree.get(path)

  hasPath: (path) ->
    @tree.has(path)

  isDirectory: (path) ->
    @stat(path).isDirectory()

  isFile: (path) ->
    @stat(path).isFile()

  isSymbolicLink: (path) ->
    @stat(path).isSymbolicLink()

  list: (path, extension) ->
    @getEntry(path).list(extension)

  lstat: (path) ->
    # TODO: lstat
    @stat(path)

  read: (path) ->
    @getEntry(path)

  readdir: (path) ->
    @getEntry(path).entries

  realpath: (path) ->
    # TODO: realpath
    path

  stat: (path) ->
    @getEntry(path).stats

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

  open: (path) ->
    @send {command: 'open', path}

  save: (path) ->
    atom.project.bufferForPath(path).then (textBuffer) =>
      content = new Buffer(textBuffer.getText()).toString('base64')
      @send {command: 'save', path, content}

module.exports = new VirtualFileSystem

