FileSystemNode = require './file-system-node.coffee'

serverURI = 'ws://vm02.students.learn.co:3304/no_strings_attached'
token     = atom.config.get('integrated-learn-environment.oauthToken')

module.exports =
class RemoteFileSystem
  constructor: (@projectPath) ->
    @websocket = new WebSocket("#{serverURI}?token=#{token}")
    @handleEvents()

  handleEvents: ->
    messageCallbacks =
      change: @onChange
      rescue: @onRescue
      connection: @onConnection

    @websocket.onmessage = (event) ->
      {type, payload} = JSON.parse(event.data)
      messageCallbacks[type]?(payload)

    @websocket.onerror = (event) =>
      console.log event
      @onClose()

    @websocket.onclose = (event) =>
      console.log event
      @onClose()

    @websocket.onopen = (event) ->
      console.log event

  send: (data) ->
    payload = JSON.stringify(data)
    console.log "send: #{payload}"
    @websocket.send(payload)

  onChange: ({@entries, path, parent}) =>
    console.log "Change: #{path}"
    learnIDE.treeView.entryForPath(parent)?.reload?()
    learnIDE.treeView.selectEntryForPath(path)

  onConnection: ({@root, @entries}) =>
    @projectPaths = atom.project.getPaths()
    @projectPaths.forEach (path) -> atom.project.removePath(path)
    atom.project.addPath(@root)

  onRescue: ({message}) ->
    console.log "RESCUE: #{message}"

  onClose: ->
    atom.project.removePath(@root)
    @projectPaths.forEach (path) -> atom.project.addPath(path)

  getNode: (path) =>
    entry = @entries[path]
    new FileSystemNode(entry)

  hasPath: (path) =>
    @entries[path]?

  fakeDelete: (path) =>
    @send {command: 'fake_delete', path}

  touch: (path) ->
    @send {command: 'touch', path}

  mkdirp: (path) ->
    @send {command: 'mkdir_p', path}

  mv: (source, destination) ->
    @send {command: 'mv', source, destination}

  cp: (source, destination) ->
    @send {command: 'cp', source, destination}

  realpath: (path) ->
    # TODO: make this actually find the realpath
    path

