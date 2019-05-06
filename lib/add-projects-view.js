module.exports =
class AddProjectView {
  constructor () {
    this.element = document.createElement('div')
    this.element.id = 'add-projects-view'

    this.icon = document.createElement('div')
    this.icon.classList.add('icon', 'icon-large', 'icon-telescope')

    this.element.appendChild(this.icon)

    this.title = document.createElement('h1')
    this.title.innerText = 'Add projects'

    this.element.appendChild(this.title)

    this.description = document.createElement('div')
    this.description.classList.add('description')
    this.description.innerText = 'Add or reopen projects to view their contents'

    this.element.appendChild(this.description)

    this.addProjectsButton = document.createElement('button')
    this.addProjectsButton.classList.add('btn', 'btn-primary')
    this.addProjectsButton.innerText = 'Add projects'
    this.addProjectsButton.addEventListener('click', () => {
      atom.pickFolder(paths => {
        if (paths) {
          atom.project.setPaths(paths)
        }
      })
    })

    this.element.appendChild(this.addProjectsButton)

    this.reopenProjectButton = document.createElement('button')
    this.reopenProjectButton.classList.add('btn')
    this.reopenProjectButton.innerText = 'Reopen project'
    this.reopenProjectButton.addEventListener('click', () => {
      atom.commands.dispatch(this.element, 'application:reopen-project')
    })

    this.element.appendChild(this.reopenProjectButton)
  }
}
