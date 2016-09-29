module.exports =
class Stat
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

  serialize: ->
    serialized = {}

    for own key, value of this
      if key.endsWith('time')
        serialized[key] = value.toString()
      else
        serialized[key] = value

    serialized


