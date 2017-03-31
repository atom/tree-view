const {Disposable, CompositeDisposable} = require('event-kit')
const path = require('path')

const FileIcons = require('./file-icons')
const TreeView = require('./tree-view')

module.exports =
class TreeViewPackage {
  constructor () {
    this.treeView = null
  }

  activate (state) {
    this.state = state
    this.disposables = new CompositeDisposable()
    if (this.shouldAttach()) {
      if (this.state.attached == null) {
        this.state.attached = true
      }
    }

    if (this.state.attached) {
      this.createView()
    }

    return this.disposables.add(atom.commands.add('atom-workspace', {
      'tree-view:show': () => this.createView().show(),
      'tree-view:toggle': () => this.createView().toggle(),
      'tree-view:toggle-focus': () => this.createView().toggleFocus(),
      'tree-view:reveal-active-file': () => this.createView().revealActiveFile(),
      'tree-view:toggle-side': () => this.createView().toggleSide(),
      'tree-view:add-file': () => this.createView().add(true),
      'tree-view:add-folder': () => this.createView().add(false),
      'tree-view:duplicate': () => this.createView().copySelectedEntry(),
      'tree-view:remove': () => this.createView().removeSelectedEntries(),
      'tree-view:rename': () => this.createView().moveSelectedEntry(),
      'tree-view:show-current-file-in-file-manager': () => this.createView().showCurrentFileInFileManager()
    })
    )
  }

  deactivate () {
    this.disposables.dispose()
    if (this.fileIconsDisposable) this.fileIconsDisposable.dispose()
    if (this.treeView) this.treeView.deactivate()
    this.treeView = null
  }

  consumeFileIcons (service) {
    FileIcons.setService(service)
    if (this.treeView) this.treeView.updateRoots()
    return new Disposable(() => {
      FileIcons.resetService()
      if (this.treeView) this.treeView.updateRoots()
    }
    )
  }

  serialize () {
    if (this.treeView != null) {
      return this.treeView.serialize()
    } else {
      return this.state
    }
  }

  createView () {
    if (this.treeView == null) {
      this.treeView = new TreeView(this.state)
    }
    return this.treeView
  }

  shouldAttach () {
    const projectPath = atom.project.getPaths()[0] || ''

    if (atom.workspace.getActivePaneItem()) {
      return false
    } else if (path.basename(projectPath) === '.git') {
      // Only attach when the project path matches the path to open signifying
      // the .git folder was opened explicitly and not by using Atom as the Git
      // editor.
      return projectPath === atom.getLoadSettings().pathToOpen
    } else {
      return true
    }
  }
}
