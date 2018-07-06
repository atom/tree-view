const {watchPath} = require('atom')

const _ = require('underscore-plus')
const fs = require('fs-plus')
const path = require('path')

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

  loadEntries () {
    fs.readdir(this.path, {}, (err, names) => {
      if (err) {
        names = []
        atom.notifications.addWarning(`Could not read files in ${this.path}`, err.message)
      }

      names.sort(new Intl.Collator(undefined, {numeric: true, sensitivity: 'base'}).compare)

      const files = []
      const directories = []

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
            if (this.entries.has(name)) {
              // push a placeholder since this entry already exists but this helps
              // track the insertion index for the created views
              directories.push(name)
            } else {
              const expansionState = this.expansionState.entries.get(name)
              directories.push(new Directory({
                name,
                fullPath,
                symlink,
                expansionState,
                ignoredNames: this.ignoredNames,
                useSyncFS: this.useSyncFS,
                stats: statsFlat
              }))
            }
          } else if (stats.isFile()) {
            if (this.entries.has(name)) {
              // push a placeholder since this entry already exists but this helps
              // track the insertion index for the created views
              files.push(name)
            } else {
              files.push(new File({name, fullPath, symlink, realpathCache, ignoredNames: this.ignoredNames, useSyncFS: this.useSyncFS, stats: statFlat}))
            }
          }
        })
      }

      return this.sortEntries(directories.concat(files))
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
