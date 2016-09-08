Stat = require './stat'
fs = require 'fs-plus'
_ = require 'underscore-plus'
crypto = require 'crypto'
convert = require './util/path-converter'

module.exports =
class FileSystemNode
  constructor: ({@name, @path, @entries, @digest, @content, @tree, stat}, @parent) ->
    @stats = new Stat(stat)

  get: (path) ->
    if path is @path or path is @localPath()
      this
    else
      node = _.find @children(), (node) -> path.startsWith(node.path) or path.startsWith(node.localPath())
      node.get(path) if node?

  has: (path) ->
    @get(path)?

  children: ->
    return [] unless @tree?
    @tree.map (leaf) => new FileSystemNode(leaf, this)

  localPath: ->
    return unless @path?
    convert.remoteToLocal(@path)

  forEach: (callback) ->
    callback(this)
    @children().forEach (node) -> node.forEach(callback)

  map: (callback) ->
    initialValue = [callback(this)]

    @children().reduce (mapped, node) ->
      mapped.concat(node.map(callback))
    , initialValue

  updateTree: (@tree) ->

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

  findPathsToSync: ->
    pathsToSync = []

    syncPromises = @map (node) ->
      node.needsSync().then (shouldSync) ->
        pathsToSync.push(path) if shouldSync

    Promise.all(syncPromises).then ->
      pathsToSync

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

