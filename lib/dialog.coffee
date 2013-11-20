{$, Editor, View} = require 'atom'
path = require 'path'

module.exports =
class Dialog extends View
  @content: ({prompt} = {}) ->
    @div class: 'tree-view-dialog tool-panel panel-bottom', =>
      @div class: 'block', =>
        @label prompt, class: 'icon', outlet: 'promptText'
        @subview 'miniEditor', new Editor(mini: true)

  initialize: ({initialPath, @onConfirm, select, iconClass} = {}) ->
    @promptText.addClass(iconClass) if iconClass
    @on 'core:confirm', => @onConfirm(@miniEditor.getText())
    @on 'core:cancel', => @cancel()
    @miniEditor.hiddenInput.on 'focusout', => @remove()

    @miniEditor.setText(initialPath)

    if select
      extension = path.extname(initialPath)
      baseName = path.basename(initialPath)
      if baseName is extension
        selectionEnd = initialPath.length
      else
        selectionEnd = initialPath.length - extension.length
      range = [[0, initialPath.length - baseName.length], [0, selectionEnd]]
      @miniEditor.setSelectedBufferRange(range)

  attach: ->
    atom.rootView.append(this)
    @miniEditor.focus()

  close: ->
    @remove()
    atom.rootView.focus()

  cancel: ->
    @remove()
    $('.tree-view').focus()

  showError: (message) ->
    @promptText.text(message)
    @flashError()
