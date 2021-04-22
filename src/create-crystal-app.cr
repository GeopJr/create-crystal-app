require "term-prompt"
require "baked_file_system"
require "colorize"
require "crustache"
require "compiled_license"

CRYSTAL_VERSION = Crystal::VERSION

module Create::Crystal::App
  extend self

  # ## Functions

  # Runs a command in shell
  # Used for fetching the git aurhor and email from git
  def run_cmd(cmd, args)
    stdout = IO::Memory.new
    stderr = IO::Memory.new
    status = Process.run(cmd, args: args, output: stdout, error: stderr)

    # Let's require the cmd (git) instead of putting a default name and email
    if (stderr.to_s.size > 0)
      print_console("Command `#{cmd}` not found. Please install and configure `#{cmd}`", "error", true)
    end
    stdout.to_s
  end

  # Prints to console using colors and STDOUT/STDERR for better handling
  # It also exits if requested to
  def print_console(msg : String, type : String | Nil = "simple", stop : Bool | Nil = false)
    color = :default
    if type == "error"
      color = :red
    elsif type == "warn"
      color = :yellow
    elsif type == "success"
      color = :light_green
    end

    (type == "error" ? STDERR : STDOUT).puts msg.colorize(color)
    exit(1) if stop
  end

  # Makes string module-and-others-name-compatible
  def clean_project_name(unclean_name : String) : String
    unclean_name.downcase.gsub(/(-|_|\ )+/, "_")
  end

  # Creates the template
  def create_file(content : String, path : String, project_dir : Path, type : String | Nil = "")
    # New path is a combination of the template destination and the file destination
    # BUT with the first parent removed
    new_path = Path[project_dir, Path[path].to_s.split(/\/|\\/).compact!.reject! { |x| x == "" }[1..-1].join("/")]
    # Creates the new paths
    Dir.mkdir_p(new_path.parent) unless Dir.exists?(new_path.parent)
    # Handle file names
    basename = new_path.basename(".mst")
    filename = basename.gsub(/^_/, ".")
    if type == "license"
      filename = "#{basename == "UNLICENSE" ? "UN" : ""}LICENSE"
    elsif type == "coc"
      filename = "CODE_OF_CONDUCT.md"
    end
    # Write the files to the destination
    File.write(Path[new_path.parent, filename], content)
  end

  # ## baked_file_system
  # Bake the templates folder
  class FileStorage
    extend BakedFileSystem

    bake_folder "../templates"
  end

  # Get all the stored files and create hashes
  # based on their paths and categories
  files = FileStorage.files.map { |x| x.path }

  structured_files = Hash(String, Array(String)).new
  licenses = Hash(String, String).new
  cocs = Hash(String, String).new
  cis = Hash(String, String).new

  files.each do |file|
    path_parts = file.split("/")
    category = path_parts[1]
    filename = path_parts[-1].split(".")[0..-2].join(".")

    structured_files[category] = (structured_files[category]? || [] of String) << file
    licenses[filename] = file if category == "licenses"
    cocs[filename.gsub(/_|-/, " ").titleize] = file if category == "coc"
    cis[filename.split(/\.|^_/)[-2].gsub(/_|-/, " ").titleize] = file if category == "ci"
  end

  # ## Prompt
  STDOUT.puts ("create-crystal-app - " + {{ `shards version #{__DIR__}`.chomp.stringify }}).colorize(:light_magenta)

  prompt = Term::Prompt.new(interrupt: :exit)

  # Match the `crystal init` validation requirements
  ProjectNameValidator = Proc(Term::Prompt::Question, String?, Bool).new do |question, value|
    if value.nil? || value.blank?
      question.errors << "Project Name must not be empty."
      next false
    end
    question.errors << "Project Name must not be longer than 50 characters." if value.size > 50
    question.errors << "Project Name must start with a letter." if !value[0].ascii_letter?
    question.errors << "Project Name must only contain alphanumerical characters, spaces, _ or -" if !value.each_char.all? { |c| c.alphanumeric? || c == '-' || c == '_' || c == ' ' }

    next false if question.errors.size > 0
    true
  end

  name = prompt.ask("Project Name:", required: true, validators: [ProjectNameValidator])
  cleaned_name = clean_project_name(name.not_nil!)

  # If neither the current Dir nor the dir named after the cleaned name
  # are empty, error
  if !Dir.empty?(".") && (Dir.exists?(cleaned_name) && !Dir.empty?(cleaned_name))
    print_console("Directory not empty.", "error", true)
  end

  type = prompt.select("Choose a template:") do |menu|
    menu.choice name: "App", value: "app"
    menu.choice name: "Shard", value: "lib"
    menu.choice name: "Kemal (Web)", value: "kemal"
  end

  ci = prompt.select("Choose a CI:", cis.keys << "I would like to pick one later")

  license = prompt.select("Choose a license:", licenses.keys.sort { |x, y| x <=> y } << "I would like to pick one later")
  coc = prompt.select("Choose a Code of Conduct:", cocs.keys.sort { |x, y| x <=> y } << "I would like to pick one later")

  continue = prompt.yes?("Are you sure you want to continue?")
  print_console("OK! Init was aborted.", "success", true) if !continue

  # Detect the template destination
  project_dir = Path["."]
  if !Dir.empty?(".")
    Dir.mkdir(cleaned_name) if !Dir.exists?(cleaned_name)
    project_dir = Path["./" + cleaned_name]
  end

  author = run_cmd("git", ["config", "user.name"])
  email = run_cmd("git", ["config", "user.email"])
  run_cmd("git", ["init", project_dir.to_s, "--initial-branch=main"])

  config = {
    "author"                  => author.strip,
    "email"                   => email.strip,
    "project_name"            => name,
    "module_name"             => cleaned_name,
    "module_name_capitalized" => cleaned_name.gsub("_", " ").titleize.gsub(" ", "_"),
    "app"                     => type == "app",
    "lib"                     => type == "lib",
    "kemal"                   => type == "kemal",
    "ci"                      => ci,
    "license"                 => license,
    "coc"                     => coc,
    "crystal_version"         => CRYSTAL_VERSION,
    "version_command"         => "{{ `shards version \#{__DIR__}`.chomp.stringify }}",
    "year"                    => Time.local.year,
  }

  structured_files.keys.each do |k|
    if k == "base"
      structured_files[k].each do |v|
        content = Crustache.render(Crustache.parse(FileStorage.get(v).gets_to_end), config)
        create_file(content, v.gsub("example", cleaned_name), project_dir)
      end
      next
    end

    if k == "ci"
      baked_file_hash = cis
      user_input = config["ci"]
      type = ""
    elsif k == "coc"
      baked_file_hash = cocs
      user_input = config["coc"]
      type = "coc"
    elsif k == "licenses"
      baked_file_hash = licenses
      user_input = config["license"]
      type = "license"
    end

    # Stop if the input doesn't exist, aka, "I would like to pick one later"
    next unless baked_file_hash.not_nil!.has_key?(user_input)
    file_path = baked_file_hash.not_nil![user_input]
    content = Crustache.render(Crustache.parse(FileStorage.get(file_path).gets_to_end), config)
    # Handle hidden files
    create_file(content, file_path.split(/\/|\\/).map { |x| x.starts_with?("_") ? x.gsub(/^_/, ".") : x }.join("/"), project_dir, type)
  end

  print_console("Your project should now be available!", "success", true)
end
