_ = require 'underscore-plus'
_path = require 'path'
onmessage= require './onmessage'
SingleSocket = require 'single-socket'
PendingCommands = require './util/pending-commands'
{CompositeDisposable} = require 'event-kit'

require('dotenv').config
  path: _path.join(__dirname, '..', '.env'),
  silent: true

WS_SERVER_URL = (->
  config = _.defaults
    host: process.env['IDE_WS_HOST']
    port: process.env['IDE_WS_PORT']
    path: process.env['IDE_WS_PATH']
  ,
    host: 'ile.learn.co',
    port: 443,
    path: 'go_fs_server'
    protocol: 'wss'

  if config.port isnt 443
    config.protocol = 'ws'

  {protocol, host, port, path} = config

  "#{protocol}://#{host}:#{port}/#{path}"
)()

module.exports =
class ConnectionManager
  constructor: (@virtualFileSystem) ->
    @pending = new PendingCommands
    @handleEvents()

  handleEvents: ->
    @disposables = new CompositeDisposable

    @disposables.add @pending.onDidRemove ({command}) =>
      if command is 'sync'
        @startPingAfterTimeout()

  connect: ->
    @virtualFileSystem.atomHelper.getToken().then (token) =>
      @websocket = new WebSocket "#{WS_SERVER_URL}?token=#{token}"

      @websocket.onopen = (event) =>
        @onOpen(event)

      @websocket.onmessage = (event) =>
        onmessage(event, @virtualFileSystem, @pending)

      @websocket.onerror = (err) ->
        console.error 'WS ERROR:', err

      @websocket.onclose = (event) =>
        @onClose(event)

  onOpen: (event) ->
    @connected = true

    if @reconnectNotification?
      @successfulReconnect()

    @virtualFileSystem.activate()
    @virtualFileSystem.init()

  onClose: (event) ->
    console.warn 'WS CLOSED:', event

    if @connected and not @reconnectNotification?
      @connected = false
      @virtualFileSystem.atomHelper.disconnected()

    @reconnect()

  send: (msg) ->
    if not @connected
      return @virtualFileSystem.atomHelper.error 'Learn IDE: you are not connected!',
        detail: 'The operation cannot be performed while disconnected'

    @pending.add(msg.command)
    console.log 'SEND:', msg
    payload = JSON.stringify(msg)
    @websocket.send(payload)

  sendPing: (msg) ->
    console.log 'SEND:', 'ping'
    payload = JSON.stringify(msg)
    @websocket.send(payload)

  reconnect: ->
    if not @reconnectNotification?
      @reconnectNotification = @virtualFileSystem.atomHelper.connecting()

    secondsBetweenAttempts = 5
    setTimeout =>
      @connect()
    , secondsBetweenAttempts * 1000

  successfulReconnect: ->
    @reconnectNotification.dismiss()
    @reconnectNotification = null
    @virtualFileSystem.atomHelper.success 'Learn IDE: connected!'

  startPingAfterTimeout: (seconds = 15) ->
    setTimeout =>
      @startPing()
    , seconds * 1000

  startPing: ->
    return if @pinging

    if @pending.any('init') or @pending.greaterThan('fetch', 5)
      @startPingAfterTimeout()
    else
      @ping()

  ping: ->
    return if not @connected

    @pings ?= []
    timestamp = (new Date).toString()
    @pings.push(timestamp)

    @sendPing {command: 'ping', timestamp}
    @waitForPong(timestamp)

  waitForPong: (timestamp, secondsToWait = 3) ->
    isRepeat = timestamp is @currentPing
    @currentPing = timestamp

    setTimeout =>
      @resolvePing(timestamp, isRepeat)
    , secondsToWait * 1000

  resolvePing: (timestamp, isRepeat) ->
    if not @pings.includes(timestamp)
      return @ping()

    if isRepeat
      @pinging = false
      @websocket.close()
    else
      @waitForPong(timestamp, 5)

  pong: (timestamp) ->
    i = @pings.indexOf(timestamp)
    @pings.splice(i, 1)

