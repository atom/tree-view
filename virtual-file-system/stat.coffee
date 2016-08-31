module.exports =
class Stats
  constructor: (attributes) ->
    for own key, value of attributes
      if key.endsWith('time')
        @[key] = new Date(value)
      else
        @[key] = value

  isFile: ->
    @file

  isDirectory: ->
    @directory

  isBlockDevice: ->
    @blockdev

  isCharacterDevice: ->
    @chardev

  isSymbolicLink: ->
    @symlink

  isSocket: ->
    @socket

