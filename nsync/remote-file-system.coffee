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
      connection: @onConnection

    @websocket.onmessage = (event) ->
      {type, payload} = JSON.parse(event.data)
      messageCallbacks[type]?(payload)

    @websocket.onerror = (event) ->
      console.log event

    @websocket.onclose = (event) ->
      console.log event

    @websocket.onopen = (event) ->
      console.log event

  send: (data) ->
    payload = JSON.stringify(data)
    console.log "send: #{payload}"

    @websocket.send(payload)

  onConnection: ({@root, @entries}) =>
    atom.project.addPath(@root)

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

