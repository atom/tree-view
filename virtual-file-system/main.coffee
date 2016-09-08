fs = require 'fs-plus'
_ = require 'underscore-plus'
shell = require 'shell'
_path = require 'path'
FileSystemNode = require './file-system-node'
ShellAdapter = require './adapters/shell-adapter'
FSAdapter = require './adapters/fs-adapter'

serverURI = 'ws://vm02.students.learn.co:3304/tree'
token     = atom.config.get('integrated-learn-environment.oauthToken')

class VirtualFileSystem
  constructor: ->
    @projectPaths = atom.project.getPaths()
    @projectPaths.forEach (path) -> atom.project.removePath(path)

    @physicalRoot = _path.join(atom.configDirPath, '.learn-ide')
    @convert = require './util/path-converter'
    @rootNode = new FileSystemNode({})

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
      init: @onRecievedInit
      sync: @onRecievedSync
      open: @onRecievedOpen
      fetch: @onRecievedFetch
      change: @onRecievedChange
      rescue: @onRecievedRescue

    @websocket.onopen = (event) =>
      @send {command: 'init'}

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

  onRecievedInit: ({project}) =>
    @rootNode = new FileSystemNode(project)
    @convert.setProject(@rootNode.localPath())
    @treeView()?.updateRoots()
    @sync(@rootNode.path)

  onRecievedSync: ({root, digests}) =>
    node = @rootNode.get(root)
    localPath = node.localPath()

    node.traverse (entry) ->
      entry.setDigest(digests[entry.path])

    if fs.existsSync(localPath)
      virtualPaths = node.map (e) -> e.localPath()
      physicalPaths = fs.listTreeSync(localPath)
      pathsToRemove = _.difference(physicalPaths, virtualPaths)
      pathsToRemove.forEach (path) -> shell.moveItemToTrash(path)

    node.findPathsToSync().then (paths) => @fetch(paths)

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

  fetch: (paths) ->
    pathsToFetch = paths.map (path) => @convert.localToRemote(path)
    @send {command: 'fetch', paths: pathsToFetch}

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

  save: (path) ->
    atom.project.bufferForPath(path).then (textBuffer) =>
      content = new Buffer(textBuffer.getText()).toString('base64')
      @send {command: 'save', path, content}

module.exports = new VirtualFileSystem

