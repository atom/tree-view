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

    @subscribe @directory, 'entry-added', (entry) =>
      view = @createViewForEntry(entry)
      insertionIndex = entry.indexInParentDirectory
      if insertionIndex < @entries.children().length
        @entries.children().eq(insertionIndex).before(view)
      else
        @entries.append(view)

    if isExpanded then @expand() else @collapse()

    @subscribe @directory, 'entry-added entry-removed', =>
      @trigger 'tree-view:directory-modified' if @isExpanded

  beforeRemove: ->
    @directory.destroy()

  getPath: ->
    @directory.path

  createViewForEntry: (entry) ->
    if entry instanceof Directory
      view = new DirectoryView(directory: entry)
    else
      view = new FileView(entry)

    subscription = @subscribe @directory, 'entry-removed', (removedEntry) ->
      if entry is removedEntry
        view.remove()
        subscription.off()

    view

  reload: ->
    @directory.reload() if @isExpanded

  toggleExpansion: ->
    if @isExpanded then @collapse() else @expand()

  expand: ->
    return if @isExpanded
    @addClass('expanded').removeClass('collapsed')
    @directory.reload()
    @directory.watch()
    @deserializeEntryExpansionStates(@entryStates) if @entryStates?
    @isExpanded = true
    false

  collapse: ->
    @entryStates = @serializeEntryExpansionStates()
    @removeClass('expanded').addClass('collapsed')
    @directory.unwatch()
    @entries.empty()
    @isExpanded = false

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
