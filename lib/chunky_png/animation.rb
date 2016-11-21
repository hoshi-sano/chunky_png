require 'chunky_png/frame'
require 'chunky_png/animation_datastream'

module ChunkyPNG
  class Animation < Canvas

    attr_accessor :frames, :default_image_is_first_frame, :num_plays

    #################################################################
    # CONSTRUCTORS
    #################################################################

    def initialize(width, height, initial = ChunkyPNG::Color::TRANSPARENT)
      if initial.kind_of?(ChunkyPNG::Frame)
        super(width, height, initial.pixels)
        @default_image_is_first_frame = true
        @frames = [initial]
      else
        super(width, height, initial)
        @default_image_is_first_frame = false
        @frames = []
      end
    end

    def num_frames
      @frames.size
    end

    #################################################################
    # DECODING
    #################################################################

    class << self
      def from_blob(str)
        from_datastream(ChunkyPNG::AnimationDatastream.from_blob(str))
      end

      def from_file(filename)
        from_datastream(ChunkyPNG::AnimationDatastream.from_file(filename))
      end

      def from_io(io)
        from_datastream(ChunkyPNG::AnimationDatastream.from_io(io))
      end

      # @param [ChunkyPNG::AnimationDatastream] ads
      # @return [ChunkyPNG::Animation]
      def from_datastream(ads)
        animation = super(ads)

        animation.default_image_is_first_frame = ads.default_image_is_first_frame?
        animation.num_plays = ads.animation_control_chunk.num_plays

        ads.frame_control_chunks.each do |fctl_chunk|
          fdat_chunks = ads.slice_frame_data_chunks(fctl_chunk)
          frame = ChunkyPNG::Frame.from_chunks(fctl_chunk, fdat_chunks, ads)
          animation.frames << frame
        end

        unless ads.animation_control_chunk.num_frames == animation.num_frames
          raise ChunkyPNG::ExpectationFailed, 'num_frames missmatched!'
        end
        animation
      end
    end

    #################################################################
    # ENCODING
    #################################################################

    def to_datastream(constraints = {})
      encoding = determine_png_encoding(constraints)

      ds = AnimationDatastream.new
      ds.header_chunk = Chunk::Header.new(:width => width, :height => height,
                                          :color => encoding[:color_mode],
                                          :depth => encoding[:bit_depth],
                                          :interlace => encoding[:interlace])
      if encoding[:color_mode] == ChunkyPNG::COLOR_INDEXED
        ds.palette_chunk      = encoding_palette.to_plte_chunk
        ds.transparency_chunk = encoding_palette.to_trns_chunk unless encoding_palette.opaque?
      end

      ds.animation_control_chunk = Chunk::AnimationControl.new(:num_frames => num_frames,
                                                               :num_plays  => num_plays)

      data = encode_png_pixelstream(encoding[:color_mode], encoding[:bit_depth],
                                    encoding[:interlace], encoding[:filtering])
      ds.data_chunks = Chunk::ImageData.split_in_chunks(data, encoding[:compression])

      idx = 0
      frames.each do |frame|
        if idx == 0 && @default_image_is_first_frame
          ds.frame_control_chunks << frame.to_frame_control_chunk(0)
        else
          fctl_chunk, *fdat_chunks = *frame.to_chunks(idx, constraints)
          ds.frame_control_chunks << fctl_chunk
          ds.frame_data_chunks = ds.frame_data_chunks + fdat_chunks
        end
        idx = ds.animation_chunks.size
      end

      ds.end_chunk = Chunk::End.new
      return ds
    end
  end
end
