module.exports =
class FileSystemNode
  constructor: ({@name, @path, @size, @digest, @symlink, @directory, @entries, atime, ctime, mtime, birthtime}) ->
    @atime = new Date(atime)
    @ctime = new Date(ctime)
    @mtime = new Date(mtime)
    @birthtime = new Date(birthtime)

  list: (extension) ->
    if extension?
      entries = @entries.filter (entry) -> entry.endsWith(".#{extension}")

    (entries or @entries).map (entry) => "#{@path}/#{entry}"

  isDirectory: ->
    @directory

  isFile: ->
    not @directory

  isSymbolicLink: ->
    @symlink

