module ChunkyPNG
  class AnimationDatastream < Datastream
    attr_accessor :animation_control_chunk
    attr_accessor :frame_control_chunks
    attr_accessor :frame_data_chunks

    class << self
      def from_io(io)
        ads = super
        ads.other_chunks.each do |chunk|
          case chunk
          when ChunkyPNG::Chunk::AnimationControl; ads.animation_control_chunk = chunk
          when ChunkyPNG::Chunk::FrameData; ads.frame_data_chunks << chunk
          when ChunkyPNG::Chunk::FrameControl; ads.frame_control_chunks << chunk
          end
        end
        ads.other_chunks = ads.other_chunks - ([ads.animation_control_chunk] +
                                               ads.frame_control_chunks +
                                               ads.frame_data_chunks)
        return ads
      end
    end

    def initialize
      super
      @frame_control_chunks = []
      @frame_data_chunks = []
    end

    def each_chunk
      yield(header_chunk)
      other_chunks.each { |chunk| yield(chunk) }
      yield(palette_chunk)      if palette_chunk
      yield(transparency_chunk) if transparency_chunk
      yield(physical_chunk)     if physical_chunk
      sorted_data_chunks.each  { |chunk| yield(chunk) }
      yield(end_chunk)
    end

    def sorted_data_chunks
      res = [@animation_control_chunk]
      first_fctl = @frame_control_chunks.sort_by(&:sequence_number).first
      res << first_fctl if default_image_is_first_frame?
      res << @data_chunks
      res << sorted_animation_chunks - (res.include?(first_fctl) ? [first_fctl] : [])
      res.flatten.compact
    end

    def animation_chunks
      @frame_control_chunks + @frame_data_chunks
    end

    def sorted_animation_chunks
      animation_chunks.sort_by(&:sequence_number)
    end

    def default_image_is_first_frame?
      first_fctl, second_fctl = @frame_control_chunks.sort_by(&:sequence_number)[0..1]
      (second_fctl.sequence_number - first_fctl.sequence_number) == 1
    end

    def slice_frame_data_chunks(fctl_chunk)
      min_seq_num = fctl_chunk.sequence_number
      res = []
      sorted_animation_chunks.each do |c|
        if c.sequence_number > min_seq_num
          break if c.is_a?(Chunk::FrameControl)
          res << c
        end
      end
      res
    end
  end
end
