const {CompositeDisposable, watchPath} = require('atom')

const _ = require('underscore-plus')
const fs = require('fs-plus')
const path = require('path')

const File = require('./file')
const Directory = require('./directory')

module.exports =
class RootDirectory extends Directory {
  constructor ({name, fullPath, symlink, expansionState, isRoot, ignoredNames, useSyncFS, stats}) {
    super({name, fullPath, symlink, expansionState, isRoot, ignoredNames, useSyncFS, stats})

    this.directories = new Map()
    this.files = new Map()

    this.disposables = new CompositeDisposable()
    this.disposables.add(this.onDidDeletePath(deletedPath => {
      // todo
    }))
    this.disposables.add(this.onDidCreatePath(addedPath => {
      // todo
    }))
    this.disposables.add(this.onDidRenamePath((newPath, oldPath) => {
      // todo
    }))

    this.loadEntries()
    this.watch()
  }

  async destroy () {
    super.destroy()
    await this.unwatch()
    this.disposables.dispose()
  }

  onDidDeletePath (callback) {
    return this.emitter.on('did-delete-path', callback)
  }

  onDidRenamePath (callback) {
    return this.emitter.on('did-rename-path', callback)
  }

  onDidCreatePath (callback) {
    return this.emitter.on('did-create-path', callback)
  }

  onDidModifyPath (callback) {
    return this.emitter.on('did-modify-path', callback)
  }

  loadEntries () {
    fs.readdir(this.path, (err, names) => {
      if (err) {
        names = []
        atom.notifications.addWarning(`Could not read files in ${this.path}`, err.message)
      }

      names.sort(new Intl.Collator(undefined, {numeric: true, sensitivity: 'base'}).compare)

      for (let name of names) {
        const fullPath = path.join(this.path, name)
        if (this.isPathIgnored(fullPath)) continue

        fs.lstat(fullPath, (err, stats) => {
          if (err) return

          const symlink = stats.isSymbolicLink()
          if (symlink) {
            // TODO
            // stats = fs.statSyncNoException(fullPath)
          }

          const statsFlat = _.pick(stats, _.keys(stats))
          for (let key of ['atime', 'birthtime', 'ctime', 'mtime']) {
            statsFlat[key] = statsFlat[key] && statsFlat[key].getTime()
          }

          if (stats.isDirectory()) {
            const expansionState = this.expansionState.entries.get(name)
            const directory = new Directory({
              name,
              fullPath,
              symlink,
              expansionState,
              ignoredNames: this.ignoredNames,
              useSyncFS: this.useSyncFS,
              stats: statsFlat
            })
            this.directories.set(fullPath, directory)
          } else if (stats.isFile()) {
            const file = new File({name, fullPath, symlink, ignoredNames: this.ignoredNames, useSyncFS: this.useSyncFS, stats: statsFlat})
            this.files.set(fullPath, file)
          }
        })
      }

      // return this.sortEntries(directories.concat(files))
    })
  }

  // Public: Watch this project for changes.
  async watch () {
    if (this.watchSubscription != null) return
    try {
      this.watchSubscription = await watchPath(this.path, {}, events => {
        // let reload = false
        for (const event of events) {
          console.log(event)
          if (this.isPathIgnored(event.path)) continue
          const relativePath = path.relative(this.path, event.path)
          if (event.action === 'deleted') {
            if (event.kind === 'file') {
              this.files.get(relativePath).destroy()
            } else if (event.kind === 'directory') {
              this.directories.get(relativePath).destroy()
            }
            this.emitter.emit('did-delete-path', event.path)
          } else if (event.action === 'renamed') {
            // TODO: Will this be emitted if we move the file out of the root?
            if (event.kind === 'file') {
              this.files.set(relativePath, this.files.get(path.relative(this.path, event.oldPath)))
            } else if (event.kind === 'directory') {
              this.directories.set(relativePath, this.files.get(path.relative(this.path, event.oldPath)))
            }
            this.emitter.emit('did-rename-path', event.path, event.oldPath)
          } else if (event.action === 'created') {
            if (event.kind === 'file') {
              fs.lstat(event.path, (err, stats) => {
                if (err) return

                const symlink = stats.isSymbolicLink()
                if (symlink) {
                  // TODO
                  // stats = fs.statSyncNoException(fullPath)
                }

                const statsFlat = _.pick(stats, _.keys(stats))
                for (let key of ['atime', 'birthtime', 'ctime', 'mtime']) {
                  statsFlat[key] = statsFlat[key] && statsFlat[key].getTime()
                }

                const file = new File({name, fullPath: event.path, symlink, ignoredNames: this.ignoredNames, useSyncFS: this.useSyncFS, stats: statsFlat})
                this.files.set(relativePath, file)
              })
            } else if (event.kind === 'directory') {
              fs.lstat(event.path, (err, stats) => {
                if (err) return

                const symlink = stats.isSymbolicLink()
                if (symlink) {
                  // TODO
                  // stats = fs.statSyncNoException(event.path)
                }

                const statsFlat = _.pick(stats, _.keys(stats))
                for (let key of ['atime', 'birthtime', 'ctime', 'mtime']) {
                  statsFlat[key] = statsFlat[key] && statsFlat[key].getTime()
                }

                const expansionState = this.expansionState.entries.get(name)
                const directory = new Directory({
                  name,
                  fullPath: event.path,
                  symlink,
                  expansionState,
                  ignoredNames: this.ignoredNames,
                  useSyncFS: this.useSyncFS,
                  stats: statsFlat
                })
                this.directories.set(relativePath, directory)
              })
            }
            this.emitter.emit('did-create-path', event.path)
          } else if (event.action === 'modified') {
            this.emitter.emit('did-modify-path', event.path)
          }
        }
      })
    } catch (error) {} // TODO

    this.reload()
  }

  // Public: Stop watching this project for changes.
  async unwatch () {
    if (this.watchSubscription != null) {
      await this.watchSubscription
      console.log(this.watchSubscription)
      this.watchSubscription.dispose()
      this.watchSubscription = null
    }

    for (let [key, entry] of this.entries) {
      entry.destroy()
      this.entries.delete(key)
    }
  }
}
