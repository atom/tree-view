fetch = require './fetch'

module.exports = open = (virtualFileSystem, data) ->
  fetch(virtualFileSystem, data)

