path = require 'path'

{fs} = require 'atom'

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
    if @initialPath is newPath
      @close()
      return

    if fs.existsSync(newPath)
      @showError("'#{newPath}' already exists. Try a different path.")
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
      @showError("#{error.message} Try a different path.")
