DefaultFileIcons = require '../lib/default-file-icons'
FileIcons = require '../lib/file-icons'

describe 'FileIcons', ->
  afterEach ->
    FileIcons.setService(new DefaultFileIcons)

  it 'provides a default', ->
    expect(FileIcons.getService()).toBeDefined()
    expect(FileIcons.getService()).not.toBeNull()

  it 'allows the default to be overridden', ->
    service = new Object
    FileIcons.setService(service)

    expect(FileIcons.getService()).toBe(service)

  it 'allows the service to be reset to the default easily', ->
    service = new Object
    FileIcons.setService(service)
    FileIcons.resetService()

    expect(FileIcons.getService()).not.toBe(service)
