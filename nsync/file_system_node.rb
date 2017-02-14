require 'json'
require 'digest'

class FileSystemNode
  attr_reader :path, :stat, :basename, :parent

  IGNORED_ENTRIES = ['.', '..', '.DS_Store']

  def initialize(path, parent = nil)
    @path     = path
    @stat     = File.lstat(path)
    @basename = File.basename(path)
    @parent   = parent
  end

  def attributes
    {
      name: basename,
      path: path,
      size: size,
      digest: digest,
      symlink: symlink?,
      directory: directory?,
      entries: entries
    }
  end

  def directory?
    stat.directory?
  end

  def size
    stat.size
  end

  def symlink?
    stat.symlink?
  end

  def entries
    return nil unless directory?

    Dir.entries(path) - IGNORED_ENTRIES
  end

  def digest
    return nil if directory?

    Digest::SHA2.file(path).hexdigest
  end

  def tree
    return nil unless directory?

    Dir.foreach(path).with_object([]) do |entry, entries|
      next if IGNORED_ENTRIES.include? entry

      entry_path = File.join(path, entry)
      entries << FileSystemNode.new(entry_path, self)
    end
  end

  def serialize
    attributes.merge(tree: serialize_entries)
  end

  def serialize_entries
    return nil unless directory?

    tree.map(&:serialize)
  end

  def list_tree
    Dir.glob("#{path}/**/*", File::FNM_DOTMATCH) << path
  end

  def list_tree_with_data
    list_tree.each_with_object({}) do |entry, list_tree_data|
      list_tree_data[entry] = FileSystemNode.new(entry).attributes
    end
  end

  def expansion_state(basename_only: false)
    return nil unless directory?

    entries   = {}
    reference = basename_only ? basename : path

    tree.each do |entry|
      next unless entry.directory?
      entries.merge! entry.expansion_state(basename_only: true)
    end

    { reference => { isExpanded: false, entries: entries } }
  end
end

yo = FileSystemNode.new(FileUtils.pwd)
