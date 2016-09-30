module.exports = init = (virtualFileSystem, {timestamp}) ->
  virtualFileSystem.connectionManager.pong(timestamp)

