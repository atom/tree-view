DefaultFileIcons = require './default-file-icons'

class FileIcons
  constructor: ->
    @service = new DefaultFileIcons

  getService: ->
    @service

module.exports = new FileIcons
