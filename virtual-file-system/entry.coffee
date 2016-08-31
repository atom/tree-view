Stat = require './stat'

module.exports =
class Entry
  constructor: ({@name, @path, @entries, @digest, @content, stat}) ->
    @stats = new Stat(stat)

  addContent: (@content) ->
    # base64 vs utf8?

  addDigest: (@digest) ->

  read: ->
    # base64 vs utf8?
    @contents

  list: (extension) ->
    if extension?
      entries = @entries.filter (entry) -> entry.endsWith(".#{extension}")

    (entries or @entries).map (entry) => "#{@path}/#{entry}"

