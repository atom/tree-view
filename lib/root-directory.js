const {watchPath} = require('atom')

const _ = require('underscore-plus')
const fs = require('fs-plus')
const path = require('path')

const File = require('./file')
const Directory = require('./directory')

module.exports =
class RootDirectory extends Directory {
  constructor ({name, fullPath, symlink, expansionState, isRoot, ignoredNames, useSyncFS, stats}) {
    super({name, fullPath, symlink, expansionState, isRoot, ignoredNames, useSyncFS, stats})

    this.loadEntries()
    this.watch()
  }

  destroy () {
    super.destroy()
    this.unwatch()
  }

  onDidAddEntry (callback) {
    return this.emitter.on('did-add-entry', callback)
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
            this.emitter.emit('did-add-entry', directory)
          } else if (stats.isFile()) {
            const file = new File({name, fullPath, symlink, ignoredNames: this.ignoredNames, useSyncFS: this.useSyncFS, stats: statsFlat})
            this.emitter.emit('did-add-entry', file)
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
        let reload = false
        for (const event of events) {
          console.log(event)
          if (event.action === 'deleted' && event.path === this.path) {
            this.destroy()
            break
          } else {
            reload = true
          }
        }

        if (reload) this.reload()
      })
    } catch (error) {}

    this.reload()
  }

  // Public: Stop watching this project for changes.
  unwatch () {
    if (this.watchSubscription != null) {
      this.watchSubscription.dispose()
      this.watchSubscription = null
    }

    for (let [key, entry] of this.entries) {
      entry.destroy()
      this.entries.delete(key)
    }
  }
}
