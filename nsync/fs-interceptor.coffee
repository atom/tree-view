fs = require 'fs-plus'
_path = require 'path'
Sync = require './sync'
FileStat = require './file-stat'

serverURI = 'ws://vm02.students.learn.co:3304/something'
token     = atom.config.get('integrated-learn-environment.oauthToken')

convert =
  localToRemote: (localPath, localRoot, remotePlatform = 'posix') ->
    remotePath = localPath.replace(localRoot, '')

    if _path.sep isnt _path[remotePlatform].sep
      remotePath = remotePath.split(_path.sep).join(_path[remotePlatform].sep)

    remotePath

  remoteToLocal: (remotePath, localTarget = '', remotePlatform = 'posix') ->
    if _path.sep isnt _path[remotePlatform].sep
      remotePath = remotePath.split(_path[remotePlatform].sep).join(_path.sep)

    _path.join(localTarget, remotePath)

  remoteMessage: (msg, localRoot) ->
    converted = {}

    for own key, value of msg
      if typeof value is 'string' and value.startsWith(localRoot)
        converted[key] = @localToRemote(value, localRoot)
      else
        converted[key] = value

    converted

  remoteEntries: (remoteEntries, localRoot, createVirtualFiles = false) ->
    virtualEntries = {}

    for own remotePath, attributes of remoteEntries
      localPath = @remoteToLocal(remotePath, localRoot)
      value = if createVirtualFiles then new FileStat(attributes) else attributes
      virtualEntries[localPath] = value

    virtualEntries

module.exports =
class Interceptor
  constructor: ->
    @projectPaths = atom.project.getPaths()
    @projectPaths.forEach (path) -> atom.project.removePath(path)

    @localRoot = _path.join(atom.configDirPath, '.learn-ide')

    @websocket = new WebSocket("#{serverURI}?token=#{token}")
    @handleEvents()

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
      console.log "RECEIVED: #{type}"
      messageCallbacks[type]?(payload)

  package: ->
    # todo: update package name
    atom.packages.getActivePackage('tree-view')

  treeView: ->
    @package()?.mainModule?.treeView

  send: (msg) ->
    convertedMsg = convert.remoteMessage(msg, @localRoot)
    payload = JSON.stringify(convertedMsg)
    console.log "SEND: #{payload}"
    @websocket.send(payload)

  #-------------
  # initial sync
  #-------------

  fetch: (paths) ->
    pathsToFetch = paths.map (path) -> convert.localToRemote(path, @localRoot)
    @send {command: 'fetch', paths: pathsToFetch}

  #--------------------
  # onmessage callbacks
  #--------------------

  onBuild: ({entries, root}) =>
    @virtualRoot = convert.remoteToLocal(root, @localRoot)
    @virtualEntries = convert.remoteEntries(entries, @localRoot, true)
    atom.project.addPath(@virtualRoot)
    # TODO: persist title change, maybe use custom-title package
    document.title = 'Learn IDE - ' + @virtualRoot.replace("#{@localRoot}/", '')
    @send {command: 'sync'}

  onSync: ({entries, root}) =>
    virtualEntries = convert.remoteEntries(entries, @localRoot)
    sync = new Sync(virtualEntries, "#{@localRoot}/#{root}")
    sync.execute()

  onChange: ({entries, path, parent}) =>
    console.log "CHANGE: #{path}"
    @virtualEntries = convert.remoteEntries(entries, @localRoot, true)
    path = convert.remoteToLocal(path, @localRoot)
    parent = convert.remoteToLocal(parent, @localRoot)
    @treeView()?.entryForPath(parent).reload()
    @treeView()?.selectEntryForPath(path)

  onFetch: ({path, attributes, contents}) =>
    # TODO: include mode and shiz?
    localPath = convert.remoteToLocal(path, @localRoot)
    dirname = _path.dirname(localPath)
    return unless localPath? and dirname?
    fs.makeTreeSync(dirname) unless fs.existsSync(dirname)
    fs.writeFile(localPath, contents)

  onRescue: ({message}) ->
    console.log "RESCUE: #{message}"

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
    @send {command: 'mkdirp', path}

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

