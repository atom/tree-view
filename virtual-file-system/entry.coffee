Stat = require './stat'
fs = require 'fs-plus'
crypto = require 'crypto'

module.exports =
class Entry
  constructor: ({@name, @path, @entries, @digest, @content, stat}, @localPath) ->
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

  needsSync: ->
    new Promise (resolve) =>
      fs.stat @localPath, (err, stats) =>
        if err? or not @digest?
          return resolve(true)

        if stats.isDirectory()
          str = fs.readdirSync(@localPath).sort().join('')
          localDigest = crypto.createHash('md5').update(str, 'utf8').digest('hex')
          return resolve(@digest isnt localDigest)
        else
          hash = crypto.createHash('md5')
          stream = fs.createReadStream(@localPath)

          stream.on 'data', (data) ->
            hash.update(data, 'utf8')

          stream.on 'end', =>
            localDigest = hash.digest('hex')
            return resolve(@digest isnt localDigest)

