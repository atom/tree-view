module.exports =
class FileSystemNode
  constructor: ({@name, @path, @size, @digest, @symlink, @directory, @entries}) ->
    # cool

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

  getStat: ->
    isDirectory: => @isDirectory()
    isFile: => @isFile()
    isSymbolicLink: => @isSymbolicLink()
