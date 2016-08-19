nsync = require './nsync'
FileStat = require './file-stat'
RemoteFileOpener = require './remote-file-opener'

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
      open: @onOpen

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

  onChange: ({@entries, path, parent}) =>
    console.log "CHANGE: #{path}"
    nsync.refreshTree(path, parent)

  onConnection: ({@root, @entries}) =>
    nsync.setProject(@root)

  onRescue: ({message}) ->
    console.log "RESCUE: #{message}"

  onOpen: ({path, attributes, contents}) ->
    console.log "OPEN: #{path}"
    stat = new FileStat(attributes)
    stat.setContents(contents)
    (new RemoteFileOpener(stat)).open()

  onClose: ->
    nsync.resetProjects()

  send: (data) ->
    payload = JSON.stringify(data)
    console.log "SEND: #{payload}"
    @websocket.send(payload)

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

  open: (path) ->
    @send {command: 'open', path}

  realpath: (path) ->
    # TODO: make this actually find the realpath
    path

  getStat: (path) =>
    entry = @entries[path]
    new FileStat(entry)

  hasPath: (path) =>
    @entries[path]?

