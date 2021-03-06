require 'fileutils'
require 'thread'

require 'nil/file'
require 'nil/console'

module Nil
  class Builder
    attr_writer :threads, :sourceDirectories

    CExtension = 'c'
    CPlusPlusExtension = 'cpp'
    CUDAExtension = 'cu'
    ObjectExtension = 'o'

    def initialize(output)
      @includeDirectories = ['.']
      @libraryDirectories = []
      @sourceFiles = []
      @libraries = []

      @pic = false

      @outputDirectory = 'output'
      @objectDirectory = 'object'

      @output = output

      @threads = 1

      @compiler = 'g++'

      @additionalArguments = []

      @sourceDirectories = ['source']

      @mutex = Mutex.new

      @shellScript = nil
    end

    def writeShellScript(path)
      @shellScript = File.open(path, 'wb+')
    end

    def argument(newArgument)
      @additionalArguments << newArgument
    end

    def include(*directories)
      @includeDirectories += directories
    end

    def processSourceDirectory(directory)
      contents = Nil.readDirectory(directory, true)
      if contents == nil
        raise "Unable to read #{directory}"
      end
      directories, files = contents
      paths = files.map { |x| Nil.joinPaths(directory, x.name) }
      paths.each do |path|
        if Nil.getExtension(path) == CUDAExtension
          puts 'This appears to be a CUDA project'
          @compiler = 'nvcc'
          break
        end
      end
      sourceFiles = paths.reject do |path|
        ![CExtension, CPlusPlusExtension, CUDAExtension].include?(Nil.getExtension(path))
      end
      @sourceFiles += sourceFiles
    end

    def setOutputDirectory(directory)
      @outputDirectory = directory
    end

    def setObjectDirectory(directory)
      @objectDirectory = directory
    end

    def setSourceDirectories(*directories)
      @sourceDirectories = directories
    end

    def loadSources
      @sourceDirectories.each do |sourceDirectory|
        processSourceDirectory(sourceDirectory)
      end
    end

    def library(library)
      @libraries << library
    end

    def libraryDirectory(directory)
      @libraryDirectories << directory
    end

    def makeDirectory(directory)
      if @shellScript == nil
        FileUtils.mkdir_p(directory)
      else
        @shellScript.write("mkdir -p #{directory}\n")
      end
    end

    def getObject(path)
      return Nil.joinPaths(@objectDirectory, File.basename(path + '.' + ObjectExtension))
    end

    def command(commandString)
      Nil.threadPrint("Executing: #{commandString}")
      if @shellScript == nil
        return system(commandString)
      else
        @shellScript.write("#{commandString}\n")
        return 1
      end
    end

    def setCompiler(newCompiler)
      @compiler = newCompiler
    end

    def addArgument(argument)
      @additionalArguments << argument
    end

    def getAdditionalArguments
      additionalArguments = @additionalArguments.join(' ')
      if !additionalArguments.empty?
        additionalArguments = ' ' + additionalArguments
      end
      return additionalArguments
    end

    def worker
      while true
        source = nil
        object = nil
        @mutex.synchronize do
          if @targets.size == 0 || @compilationFailed
            return
          end
          source, object = @targets[0]
          @targets = @targets[1..-1]
        end

        fpicString = ''
        if @pic
          fpicString = ' -fPIC'
        end

        if @shellScript != nil
          @shellScript.puts("echo \"Compiling #{source}\"")
        end
        if !command("#{@compiler} -c #{source}#{fpicString} -o #{object}#{@includeDirectoryString}#{getAdditionalArguments}")
          @mutex.synchronize do
            if !@compilationFailed
              Nil.threadPrint('Compilation failed')
              @compilationFailed = true
            end
          end
          return
        end
      end
    end

    def compile
      makeDirectory(@objectDirectory)

      @includeDirectoryString = ''
      @includeDirectories.each do |directory|
        @includeDirectoryString += " -I#{directory}"
      end

      @libraryDirectoryString = ''
      @libraryDirectories.each do |directory|
        @libraryDirectoryString += " -L#{directory}"
      end

      @objectString = ''
      @targets.each do |source, object|
        @objectString += " #{object}"
      end

      threadString = 'thread'
      if @threads > 1
        threadString += 's'
      end

      puts "Compiling project with #{@threads} #{threadString}"

      start = Time.new

      threads = []
      @compilationFailed = false
      counter = 1
      @threads.times do |i|
        thread = Thread.new { worker }
        threads << thread
        counter += 1
      end

      threads.each do |thread|
        thread.join
      end

      success = !@compilationFailed

      difference = Time.new - start
      if success
        printf("Compilation finished after %.2f s\n", difference)
      end

      return success
    end

    def makeTargets
      loadSources
      makeDirectory(@outputDirectory)
      @targets = @sourceFiles.map { |path| [path, getObject(path)] }
    end

    def getLibraryString
      libraryString = ''
      @libraries.each do |library|
        libraryString += " -l#{library}"
      end
      return libraryString
    end

    def linkProgram
      libraryString = getLibraryString

      if @shellScript != nil
          @shellScript.puts("echo \"Compiling #{@output}\"")
        end

      outputPath = Nil.joinPaths(@outputDirectory, @output)
      if !command("#{@compiler} -o " + outputPath + @objectString + @libraryDirectoryString + libraryString + getAdditionalArguments)
        puts 'Failed to link'
        return false
      end

      return true
    end

    def linkStaticLibrary
      @library = "lib#{@output}.a"
      if @shellScript != nil
        @shellScript.puts("echo \"Building #{@library}\"")
      end
      output = Nil.joinPaths(@outputDirectory, @library)
      FileUtils.rm_f(output)
      return command('ar -cq ' + output + @objectString)
    end

    def linkDynamicLibrary
      libraryString = getLibraryString

      @library = "#{@output}.so"
      output = Nil.joinPaths(@outputDirectory, @library)
      return command("#{@compiler} -shared -o " + output + @objectString + libraryString + getAdditionalArguments)
    end

    def program
      makeTargets
      return compile && linkProgram
    end

    def staticLibrary(pic = false)
      @pic = pic
      makeTargets
      return compile && linkStaticLibrary
    end

    def dynamicLibrary
      makeTargets
      @pic = true
      return compile && linkDynamicLibrary
    end

    def optimise
      addArgument('-O3')
    end

    #for CUDA
    def shaderModel(model)
      @additionalArguments += [
        '-arch',
        "sm_#{(model * 10).to_i}"
        ]
    end

    def cpp11
      addArgument('-std=c++11')
    end

    def debug
      addArgument('-g')
    end
  end
end
