#!/usr/bin/ruby

require 'osx/cocoa'
require 'optparse'

# This is my version object. There are many like it, but this one is mine.
# This does NOT currently handle alphanumeric version designations (e.g.,
# 1.0b3).
class ProgramVersion
  # The major-feature version. Required. If set to nil, will default to
  # zero.
  attr_accessor :major
  undef :major=
  def major=(major)
    @major = major || 0
  end
  # The minor-feature version. Required. If set to nil, will default to
  # zero.
  attr_accessor :minor
  undef :minor=
  def minor=(minor)
    @minor = minor || 0
  end
  # The patch version. Optional unless #build is specified. If #build is set
  # and we try to clear #patch, an exception will be raised.
  attr_accessor :patch
  undef :patch=
  def patch=(patch)
    if patch.nil? and build
      raise "Invalid version configuration. No build without patch."
    end
    @patch = patch
  end
  # The build number. Optional. If #build is set and #patch is unset, #patch
  # will be initialized to a zero value.
  attr_accessor :build
  undef :build=
  def build=(build)
    @build = build
    self.patch = 0 if patch.nil?
  end

  # The revision reference for the build; usually some identifier for the
  # source control system. 
  attr_accessor :rev
  # The type of revision reference; a text field.
  attr_accessor :rev_type

  # Compares this version against another version.
  def <=>(other)
    r = major <=> other.major
    r = minor <=> other.minor if r.zero?
    r = patch <=> other.patch if r.zero?

    if r.zero?
      case "#{build}/#{other.build}"
      when %r{^/$}
        r = 0
      when %r{^\d+/$}
        r = 1
      when %r{^/\d+$}
        r = -1
      else
        r = build <=> other.build
      end
    end
    r
  end

  VERSION_RE = %r{
    ^
    (\d+)           # $1 Major
    \.(\d+)         # $2 Minor
    (?:
     (?:\.(\d+))    # $3 Patch
      (?:\.(\d+))?  # $4 Build, optional (but only if patch is present)
    )?              # Patch and build are optional
    (?:
     \s+            # One or more spaces
     \(             # Followed by a parenthesis and
     (?:
      ([^\s]+)      # $5 Text with no spaces
      \s+           # Followed by one or more spaces
      (.+)          # $6 and any other text
      |             # OR
      (.+)          # $7 any text
     )
     \)             # Closing parenthesis
    )?
    $
  }x

  class << self
    # Parses a version object out of a string.
    def parse_version(version_string)
      version = ProgramVersion.new

      match = VERSION_RE.match(version_string.chomp.strip)
      raise "Invalid version string format" unless match

      int = lambda { |x| x ? x.to_i : x }

      captures = match.captures
      version.major = int[captures[0]]  # $1
      version.minor = int[captures[1]]  # $2
      version.patch = int[captures[2]]  # $3
      version.build = int[captures[3]]  # $4

      if captures[4]
        version.rev_type = captures[4]  # $5
        version.rev = captures[5]       # $6
      elsif captures[6]
        version.rev = captures[6]       # $7
      end

      version
    end
  end

  def initialize
    @major = @minor = 0
    @patch = @build = @rev = @rev_type = nil
  end

  # Returns a copy of the program version with an incremented build number.
  def increment_build
    version = self.dup
    version.increment_build!
    version
  end

  # Increments this version's build number.
  def increment_build!
    if self.build
      self.build += 1
    else
      self.build = 1
      self.patch = 0 unless patch
    end
    nil
  end

  # Returns a string representation of the revision. If there is no revision,
  # an empty string is returned.
  #
  # +:with_rev+::       Ignored.
  # +:with_rev_type+::  Shows the revision type identifier, if provided.
  def revision(option = nil)
    valid_option?(:revision, option)

    option = nil if :with_rev == option

    if (rev.nil? and rev_type.nil?) or (rev.nil? and option.nil?)
      ""
    elsif rev.nil? 
      "#{rev_type}"
    elsif rev_type.nil? or option.nil?
      "#{rev}"
    else
      "#{rev_type} #{rev}"
    end
  end

  # Returns a string representation of the short version. If there is no
  # patch value or patch value is zero, it is not printed.
  #
  # There are only two options:
  #
  # +:with_rev+::       Shows the revision identifier, if provided.
  # +:with_rev_type+::  Shows the revision type identifier, if provided.
  #                     Implies :with_rev.
  #
  # = Examples
  # v1 = ProgramVersion.parse_version("1.0 (git-rev abcdef10)")
  # v1.short_version                  # => 1.0
  # v1.short_version(:with_rev)       # => 1.0 (abcdef10)
  # v1.short_version(:with_rev_type)  # => 1.0 (git-rev abcdef10)
  #
  # v2 = ProgramVersion.parse_version("1.0.1.1 (git-rev abcdef10)")
  # v2.short_version                  # => 1.0.1
  # v2.short_version(:with_rev)       # => 1.0.1 (abcdef10)
  # v2.short_version(:with_rev_type)  # => 1.0.1 (git-rev abcdef10)
  def short_version(option = nil)
    valid_option?(:short_version, option)

    version = if patch.nil? || patch.zero?
                "#{major}.#{minor}"
              else
                "#{major}.#{minor}.#{patch}"
              end

    if option
      revision = revision(option)
      version = "#{version} (#{revision})" unless revision.empty?
    end

    "#{version}"
  end

  # Returns a string representation of the long version. If there is no
  # build number, this will return the same value as #short_version.
  #
  # There are only two options:
  #
  # +:with_rev+::       Shows the revision identifier, if provided.
  # +:with_rev_type+::  Shows the revision type identifier, if provided.
  #                     Implies :with_rev.
  #
  # = Examples
  # v1 = ProgramVersion.parse_version("1.0 (git-rev abcdef10)")
  # v1.long_version                  # => 1.0
  # v1.long_version(:with_rev)       # => 1.0 (abcdef10)
  # v1.long_version(:with_rev_type)  # => 1.0 (git-rev abcdef10)
  #
  # v2 = ProgramVersion.parse_version("1.0.1.1 (git-rev abcdef10)")
  # v2.long_version                  # => 1.0.1.1
  # v2.long_version(:with_rev)       # => 1.0.1.1 (abcdef10)
  # v2.long_version(:with_rev_type)  # => 1.0.1.1 (git-rev abcdef10)
  def long_version(option = nil)
    valid_option?(:long_version, option)
    return short_version(option) if build.nil?

    # Always start from the short version with no rev.
    version = "#{short_version}.#{build}"

    if option
      revision = revision(option)
      version = "#{version} (#{revision})" unless revision.empty?
    end

    version
  end

  def to_s
    long_version
  end

  def inspect
    "#<#{self.class}: #{long_version(:with_rev_type)}>"
  end

  def valid_option?(method, option)
    case option
    when nil, :with_rev, :with_rev_type
      nil
    else
      raise "Unknown option '#{option}' for ##{method}."
    end
  end
  private :valid_option?
end

options = {
  :path => :xcode,
  :mode => :iphone,
}

OptionParser.new do |opt|
  opt.banner = "Usage: #{File.basename(__FILE__)} [options]"
  opt.on("--path PATH", "-P", "Path to plist containing version info.",
         "Default uses Xcode environment values.") { |path|
    options[:path] = path
  }
=begin
  # This is not yet implemented.
  opt.on("--mode MODE", "Version mode. Default 'iphone' only uses",
         "numeric versioning.") { |mode|
    options[:mode] = mode.to_sym
  }
=end

  begin
    opt.parse!(ARGV)
  rescue OptionParser::InvalidOption => ex
    $stderr.puts "ERROR: #{ex.message}"
    $stderr << opt
    exit 1
  end
end

products_path   = ENV['BUILT_PRODUCTS_DIR']
infoplist_path  = ENV['INFOPLIST_PATH']

if :xcode == options[:path]
  raise "Not running under Xcode" if products_path.nil? or infoplist_path.nil?
  options[:path] = File.join(products_path, infoplist_path)
end


unless File.exist?(options[:path])
  raise "Cannot find Info.plist in #{options[:path]}."
end

path = options[:path]
# Load the plist
info_plist = OSX::NSDictionary.dictionaryWithContentsOfFile(path).mutableCopy
# Get the current HEAD
current_head = %x(git describe --always).chomp
# Get the list of build tags and turn them into version numbers.
build_tags = `git tag -l build-\\* --contains #{current_head}`.chomp.split($/)
build_tags.map! { |tag| ProgramVersion.parse_version(tag.sub(/^build-/, '')) }

# Get the CFBundleVersion from the plist.
old_version = ProgramVersion.parse_version(info_plist['CFBundleVersion'])
# Add the old version to the list of build tags.
build_tags << old_version.dup
# Get the largest version we know about for this head.
new_version = build_tags.max
# Increment the build number
new_version.increment_build!

# If we were in a non-iPhone mode, we'd also grab the head.
# new_version.ref = `git rev-parse --short HEAD`.chomp
# new_version.ref_type = 'git-ref'

puts "Version modified: #{old_version} -> #{new_version}"

# Set the long version (M.m.p.b)
info_plist['CFBundleVersion'] = new_version.long_version
# Set the short version (M.m or M.m.p).
info_plist['CFBundleShortVersionString'] = new_version.short_version
# Write the file.
info_plist.writeToFile_atomically(path, 1)
# Tag the version
`git tag build-#{new_version}`
