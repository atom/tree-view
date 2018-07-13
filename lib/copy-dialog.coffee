path = require 'path'
fs = require 'fs-plus'
Dialog = require './dialog'
{repoForPath} = require "./helpers"

module.exports =
class CopyDialog extends Dialog
  constructor: (@initialPath, {@onCopy}) ->
    super
      prompt: 'Enter the new path for the duplicate.'
      initialPath: atom.project.relativize(@initialPath)
      select: true
      iconClass: 'icon-arrow-right'

  onConfirm: (newPath) ->
    newPath = newPath.replace(/\s+$/, '') # Remove trailing whitespace
    unless path.isAbsolute(newPath)
      [rootPath] = atom.project.relativizePath(@initialPath)
      newPath = path.join(rootPath, newPath)
      return unless newPath

    if @initialPath is newPath
      @close()
      return

    unless @isNewPathValid(newPath)
      @showError("'#{newPath}' already exists.")
      return

    activeEditor = atom.workspace.getActiveTextEditor()
    activeEditor = null unless activeEditor?.getPath() is @initialPath
    try
      if fs.isDirectorySync(@initialPath)
        fs.copySync(@initialPath, newPath)
        @onCopy?({initialPath: @initialPath, newPath: newPath})
      else
        fs.copy @initialPath, newPath, =>
          @onCopy?({initialPath: @initialPath, newPath: newPath})
          atom.workspace.open newPath,
            activatePane: true
            initialLine: activeEditor?.getLastCursor().getBufferRow()
            initialColumn: activeEditor?.getLastCursor().getBufferColumn()
      if repo = repoForPath(newPath)
        repo.getPathStatus(@initialPath)
        repo.getPathStatus(newPath)
      @close()
    catch error
      @showError("#{error.message}.")

  isNewPathValid: (newPath) ->
    try
      oldStat = fs.statSync(@initialPath)
      newStat = fs.statSync(newPath)

      # New path exists so check if it points to the same file as the initial
      # path to see if the case of the file name is being changed on a on a
      # case insensitive filesystem.
      @initialPath.toLowerCase() is newPath.toLowerCase() and
        oldStat.dev is newStat.dev and
        oldStat.ino is newStat.ino
    catch
      true # new path does not exist so it is valid
