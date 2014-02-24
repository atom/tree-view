path = require 'path'
fs = require 'fs-plus'
Dialog = require './dialog'

module.exports =
class MoveDialog extends Dialog
  constructor: (@initialPath) ->
    if fs.isDirectorySync(@initialPath)
      prompt = 'Enter the new path for the directory.'
    else
      prompt = 'Enter the new path for the file.'

    super
      prompt: prompt
      initialPath: atom.project.relativize(@initialPath)
      select: true
      iconClass: 'icon-arrow-right'

  onConfirm: (newPath) ->
    newPath = atom.project.resolve(newPath)
    return unless newPath

    if @initialPath is newPath
      @close()
      return

    unless @isNewPathValid(newPath)
      @showError("'#{newPath}' already exists.")
      return

    directoryPath = path.dirname(newPath)
    try
      fs.makeTreeSync(directoryPath) unless fs.existsSync(directoryPath)
      fs.moveSync(@initialPath, newPath)
      if repo = atom.project.getRepo()
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
