fs = require 'fs-plus'
_path = require 'path'
Sync = require './sync'
FileStat = require './file-stat'

serverURI = 'ws://vm02.students.learn.co:3304/no_strings_attached'
token     = atom.config.get('integrated-learn-environment.oauthToken')

pathConverter =
  remoteToLocal: (remotePath, localTarget = '', remotePlatform = 'posix') ->
    if _path.sep isnt _path[remotePlatform].sep
      remotePath = remotePath.split(_path[remotePlatform].sep).join(_path.sep)

    _path.join(localTarget, remotePath)

  remoteEntries: (remoteEntries, remoteProjectRoot, localRoot, createVirtualFiles = false) ->
    new Promise (resolve, reject) =>
      virtualRoot = @remoteToLocal(remoteProjectRoot, localRoot)
      virtualEntries = {}

      for own remotePath, attributes of remoteEntries
        localPath = @remoteToLocal(remotePath, localRoot)
        value = if createVirtualFiles then new FileStat(attributes) else attributes
        virtualEntries[localPath] = value

      resolve {virtualEntries, virtualRoot}


module.exports =
class Interceptor
  constructor: ->
    @projectPaths = atom.project.getPaths()
    @projectPaths.forEach (path) -> atom.project.removePath(path)

    @websocket = new WebSocket("#{serverURI}?token=#{token}")
    @handleEvents()

  handleEvents: ->
    messageCallbacks =
      connection: @onBuildTree
      file_sync: @onFileSync

    @websocket.onopen = (event) =>
      @send {request: 'build_tree'}

    @websocket.onmessage = (event) ->
      {type, payload} = JSON.parse(event.data)
      console.log "RECIEVED: #{type}"
      messageCallbacks[type]?(payload)

  localRoot: ->
    # TODO: update package name
    _path.join(atom.packages.getActivePackage('tree-view')?.path, '.remote-root')

  localHome: ->
    _path.join(@localRoot(), 'home')

  send: (msg) ->
    payload = JSON.stringify(msg)
    console.log "SEND: #{payload}"
    @websocket.send(payload)

  onBuildTree: ({entries, root}) =>
    pathConverter.remoteEntries(entries, root, @localRoot(), true).then ({@virtualEntries, @virtualRoot}) =>
      atom.project.addPath(@virtualRoot)
      # TODO: persist title change, maybe use custom-title package
      document.title = 'Learn IDE - ' + @virtualRoot.replace("#{@localHome()}/", '')
      @send request: 'file_sync'

  onFileSync: ({entries, root}) ->
    {virtualEntries} = pathConverter.remoteEntries(entries, root, @localRoot())
    (new Sync(virtualEntries, @localHome())).execute()

  #----------------
  # shell functions
  #----------------

  moveItemToTrash: (path) ->
    @send {command: 'trash', path}
    true

  #------------------
  # fs functions
  #------------------

  # reflections

  existsSync: (path) ->
    @virtualEntries[path]?

  isBinaryExtension: (ext) ->
    fs.isBinaryExtension(ext)

  isCaseInsensitive: ->
    fs.isCaseInsensitive()

  isCompressedExtension: (ext) ->
    fs.isCompressedExtension(ext)

  isDirectorySync: (path) ->
    @virtualEntries[path].isDirectory()

  isFileSync: (path) ->
    @virtualEntries[path].isFile()

  isImageExtension: (ext) ->
    fs.isImageExtension(ext)

  isPdfExtension: (ext) ->
    fs.isPdfExtension(ext)

  isReadmePath: (path) ->
    fs.isReadmePath(path)

  isSymbolicLinkSync: (path) ->
    @virtualEntries[path].isSymbolicLink()

  lstatSyncNoException: (path) ->
    @virtualEntries[path]

  listSync: (path, extensions) ->
    @virtualEntries[path].list(extensions)

  readFileSync: (path) ->
    @virtualEntries[path]

  readdirSync: (path) ->
    @virtualEntries[path].entries

  realpathSync: (path) ->
    # TODO: make this real
    path

  realpath: (path) ->
    # TODO: make this real
    path

  statSync: ->
    atom.notifications.addWarning('Unimplemented fs-override', detail: 'statSync')

  statSyncNoException: ->
    atom.notifications.addWarning('Unimplemented fs-override', detail: 'statSyncNoException')

  absolute: -> # currently used only in spec
    atom.notifications.addWarning('Unimplemented fs-override', detail: 'absolute')

  # actions

  copy: (source, destination) ->
    @send {command: 'cp', source, destination}

  copySync: (source, destination) ->
    @send {command: 'cp', source, destination}

  makeTreeSync: (path) ->
    @send {command: 'mkdir_p', path}

  moveSync: (source, destination) ->
    @send {command: 'mv', source, destination}

  writeFileSync: (path) ->
    @send {command: 'touch', path}

  mkdirSync: -> # currently used only in spec
    atom.notifications.addWarning('Unimplemented fs-override', detail: 'mkdirSync')

  removeSync: -> # currently used only in spec
    atom.notifications.addWarning('Unimplemented fs-override', detail: 'removeSync')

  symlinkSync: -> # currently used only in spec
    atom.notifications.addWarning('Unimplemented fs-override', detail: 'symlinkSync')

