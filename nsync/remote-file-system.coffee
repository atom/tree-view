FileSystemNode = require './file-system-node.coffee'

serverURI = 'ws://vm02.students.learn.co:3304/fs_server'
token     = atom.config.get('integrated-learn-environment.oauthToken')

module.exports =
class RemoteFileSystem
  constructor: (@projectPath) ->
    @websocket = new WebSocket("#{serverURI}?token=#{token}")
    @handleEvents()

  handleEvents: ->
    messageCallbacks =
      connection: @onConnection

    @websocket.onmessage = (event) =>
      {type, payload} = JSON.parse(event.data)
      messageCallbacks[type]?(payload)

    @websocket.onerror = (event) ->
      console.log event

    @websocket.onclose = (event) ->
      console.log event

    @websocket.onopen = (event) ->
      console.log event

  getNode: (path) =>
    entry = @entries[path]
    new FileSystemNode(entry)

  hasPath: (path) =>
    @entries[path]?

  onConnection: ({@root, @entries}) =>
    atom.project.addPath(@root)

  realpath: (path) ->
    # TODO: make this actually find the realpath
    path

