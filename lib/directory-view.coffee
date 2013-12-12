{$, $$, View} = require 'atom'

Directory = require './directory'
FileView = require './file-view'
File = require './file'

module.exports =
class DirectoryView extends View
  @content: ->
    @li class: 'directory entry list-nested-item', =>
      @div outlet: 'header', class: 'header list-item', =>
        @span class: 'name icon', outlet: 'directoryName'
      @ol class: 'entries list-tree', outlet: 'entries'

  initialize: ({@directory, isExpanded, isRoot} = {}) ->
    if isExpanded then @expand() else @collapse()

    if @directory.symlink
      iconClass = 'icon-file-symlink-directory'
    else
      iconClass = 'icon-file-directory'
      if isRoot?
        iconClass = 'icon-repo' if atom.project.getRepo()?.isProjectAtRoot()
      else
        iconClass = 'icon-file-submodule' if @directory.submodule
    @directoryName.addClass(iconClass)
    @directoryName.text(@directory.name)

    unless isRoot?
      @subscribe @directory.$status.onValue (status) =>
        @removeClass('status-ignored status-modified status-added')
        @addClass("status-#{status}") if status?

    @subscribe @directory, 'entry-removed', ({name}) =>
      @entries.find("> .entry:contains('#{name}')").remove()
      @trigger 'tree-view:directory-modified'

    @subscribe @directory, 'entry-added', (entry, index) =>
      view = @createViewForEntry(entry)
      if index is 0
        @entries.prepend(view)
      else
        @entries.children().eq(index).before(view)

      @trigger 'tree-view:directory-modified'

  beforeRemove: -> @directory.destroy()

  getPath: ->
    @directory.path

  createViewForEntry: (entry) ->
    if entry instanceof Directory
      new DirectoryView(directory: entry)
    else
      new FileView(entry)

  reload: ->
    @directory.reload()

  buildEntries: ->
    @entries.empty()
    for entry in @directory.getEntries()
      @entries.append(@createViewForEntry(entry))

  toggleExpansion: ->
    if @isExpanded then @collapse() else @expand()

  expand: ->
    return if @isExpanded
    @addClass('expanded').removeClass('collapsed')
    @buildEntries()
    @watchEntries()
    @deserializeEntryExpansionStates(@entryStates) if @entryStates?
    @isExpanded = true
    false

  collapse: ->
    @entryStates = @serializeEntryExpansionStates()
    @removeClass('expanded').addClass('collapsed')
    @unwatchEntries()
    @entries.empty()
    @isExpanded = false

  watchEntries: ->
    @directory.watch()

  unwatchEntries: ->
    @directory.unwatch()

  serializeEntryExpansionStates: ->
    entryStates = {}
    @entries?.find('> .directory.expanded').each ->
      view = $(this).view()
      entryStates[view.directory.name] = view.serializeEntryExpansionStates()
    entryStates

  deserializeEntryExpansionStates: (entryStates) ->
    for directoryName, childEntryStates of entryStates
      @entries.find("> .directory:contains('#{directoryName}')").each ->
        view = $(this).view()
        view.entryStates = childEntryStates
        view.expand()
