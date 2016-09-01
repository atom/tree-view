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
    @tree = new Tree({}, @physicalRoot, @convert)

    @fs = new FSAdapter(this)
    @shell = new ShellAdapter(this)

    @websocket = new WebSocket("#{serverURI}?token=#{token}")
    @observeSave()
    @handleEvents()

  observeSave: ->
    atom.workspace.observeTextEditors (editor) =>
      editor.getBuffer()?.onWillSave ({path}) =>
        @save(path)

  handleEvents: ->
    messageCallbacks =
      sync: @onSync
      build: @onBuild
      fetch: @onFetch
      change: @onChange
      rescue: @onRescue

    @websocket.onopen = (event) =>
      @send {command: 'build'}

    @websocket.onmessage = (event) ->
      {type, payload} = JSON.parse(event.data)
      console.log 'RECEIVED:', type
      messageCallbacks[type]?(payload)

    @websocket.onerror = (err) ->
      console.error('error with the websocket')
      console.log(err)

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

  onBuild: ({entries, root}) =>
    @root = @convert.remoteToLocal(root)
    @tree.update(entries)
    atom.project.addPath(@root)
    # TODO: persist title change, maybe use custom-title package
    document.title = "Learn IDE - #{@convert.localToRemote(@root).substr(1)}"
    @send {command: 'sync'}
    @treeView()?.updateRoots()

  onSync: ({entries}) =>
    @tree.addDigests(entries)
    @sync()

  onChange: ({entries, path, parent}) =>
    console.log 'CHANGE:', path
    @tree.update(entries)

    parent = @convert.remoteToLocal(parent)
    @treeView()?.entryForPath(parent).reload()

    path = @convert.remoteToLocal(path)
    @treeView()?.selectEntryForPath(path)

  onFetch: ({path, attributes, contents}) =>
    # TODO: preserve full stats
    localPath = @convert.remoteToLocal(path)
    dirname = _path.dirname(localPath)
    return unless localPath? and dirname?
    fs.makeTreeSync(dirname) unless fs.existsSync(dirname)
    decoded = new Buffer(contents, 'base64').toString('utf8')
    fs.writeFile(localPath, decoded)

  onRescue: ({message, backtrace}) ->
    console.log 'RESCUE:', message, backtrace

  # ------------------
  # Background syncing
  # ------------------

  sync: ->
    fs.makeTreeSync(@physicalRoot) unless fs.existsSync(@physicalRoot)
    @tree.getPathsToRemove().forEach (path) -> shell.moveItemToTrash(path)
    @tree.getPathsToSync().then (paths) => @fetch(paths)

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

  save: (path) ->
    atom.project.bufferForPath(path).then (textBuffer) =>
      content = new Buffer(textBuffer.getText()).toString('base64')
      @send {command: 'save', path, content}

module.exports = new VirtualFileSystem

