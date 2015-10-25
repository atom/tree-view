DefaultFileIcons = require './default-file-icons'

class FileIcons
  constructor: ->
    @service = new DefaultFileIcons

  getService: ->
    @service

  resetService: ->
    @service = new DefaultFileIcons

  setService: (@service) ->

module.exports = new FileIcons
