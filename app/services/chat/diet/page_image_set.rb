# frozen_string_literal: true

require 'base64'
require 'fileutils'
require 'open3'
require 'tmpdir'

class Chat::Diet::PageImageSet
  def initialize(file_path)
    @file_path = file_path
  end

  def image_parts_for(page_numbers)
    return [] unless command_available?('pdftoppm')

    render_pages if @rendered_images.nil?

    Array(page_numbers).uniq.sort.filter_map do |page_number|
      image_path = @rendered_images[page_number.to_i]
      next unless image_path && File.exist?(image_path)

      {
        type: 'image_url',
        image_url: {
          url: "data:image/png;base64,#{Base64.strict_encode64(File.binread(image_path))}",
          detail: 'high',
        },
      }
    end
  end

  def cleanup
    return unless @tmpdir

    FileUtils.remove_entry(@tmpdir) if Dir.exist?(@tmpdir)
  ensure
    @tmpdir = nil
    @rendered_images = nil
  end

  private

  def render_pages
    @tmpdir = Dir.mktmpdir('diet-parser-images')
    prefix = File.join(@tmpdir, 'page')
    run_command('pdftoppm', '-png', '-r', '200', @file_path, prefix)

    @rendered_images = Dir.glob("#{prefix}-*.png").sort.each_with_object({}) do |image_path, images|
      page_number = image_path[/page-(\d+)\.png$/, 1].to_i
      images[page_number] = image_path
    end
  rescue StandardError
    @rendered_images = {}
  end

  def run_command(*command)
    stdout, stderr, status = Open3.capture3(*command)
    raise "#{command.first} failed: #{stderr}" unless status.success?

    stdout
  end

  def command_available?(name)
    system('which', name, out: File::NULL, err: File::NULL)
  end
end
