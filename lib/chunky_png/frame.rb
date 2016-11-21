module ChunkyPNG
  class Frame < Canvas
    attr_accessor :sequence_number,
                  :width, :height, :x_offset, :y_offset,
                  :delay_num, :delay_den, :dispose_op, :blend_op

    def self.from_canvas(canvas, attrs = {})
      new(canvas.width, canvas.height, canvas.pixels.dup, attrs)
    end

    def self.from_file(file, attrs = {})
      from_canvas(ChunkyPNG::Canvas.from_file(file), attrs)
    end

    def self.from_datastream(ds, attrs = {})
      from_canvas(super(ds), attrs)
    end

    def self.from_chunks(fctl_chunk, fdat_chunks, ads)
      color_mode = ads.header_chunk.color
      depth      = ads.header_chunk.depth
      interlace  = ads.header_chunk.interlace
      decoding_palette, transparent_color = nil, nil

      if fdat_chunks.any?
        case color_mode
        when ChunkyPNG::COLOR_INDEXED
          decoding_palette = ChunkyPNG::Palette.from_chunks(ads.palette_chunk,
                                                            ads.transparency_chunk)
        when ChunkyPNG::COLOR_TRUECOLOR
          transparent_color = ads.transparency_chunk.truecolor_entry(depth) if ads.transparency_chunk
        when ChunkyPNG::COLOR_GRAYSCALE
          transparent_color = ads.transparency_chunk.grayscale_entry(depth) if ads.transparency_chunk
        end

        imagedata = Chunk::FrameData.combine_chunks(fdat_chunks)
        frame = decode_png_pixelstream(imagedata, fctl_chunk.width, fctl_chunk.height,
                                       color_mode, depth, interlace,
                                       decoding_palette, transparent_color)
      else
        frame = ChunkyPNG::Frame.new(fctl_chunk.width, fctl_chunk.height)
      end

      %i(x_offset y_offset delay_num delay_den dispose_op blend_op).each do |attr|
        frame.send("#{attr}=", fctl_chunk.send(attr))
      end
      frame
    end

    def initialize(width, height, initial = ChunkyPNG::Color::TRANSPARENT, attrs = {})
      super(width, height, initial)
      attrs.each { |k, v| send("#{k}=", v) }
    end

    def to_chunks(seq_num = nil, constraints = {})
      [to_frame_control_chunk(seq_num), *to_frame_data_chunk(constraints)]
    end

    def to_frame_control_chunk(seq_num = nil)
      @sequence_number = seq_num if seq_num
      ChunkyPNG::Chunk::FrameControl.new(
        sequence_number: @sequence_number,
        width:           @width,
        height:          @height,
        x_offset:        @x_offset,
        y_offset:        @y_offset,
        delay_num:       @delay_num,
        delay_den:       @delay_den,
        dispose_op:      @dispose_op,
        blend_op:        @blend_op
      )
    end

    def to_frame_data_chunk(constraints = {})
      encoding = determine_png_encoding(constraints)
      data = encode_png_pixelstream(encoding[:color_mode], encoding[:bit_depth],
                                    encoding[:interlace],  encoding[:filtering])
      data_chunks = Chunk::ImageData.split_in_chunks(data, encoding[:compression])
      data_chunks.map.with_index do |data_chunk, idx|
        attrs = { frame_data: data_chunk.content }
        attrs[:sequence_number] = @sequence_number + idx + 1 if @sequence_number
        ChunkyPNG::Chunk::FrameData.new(attrs)
      end
    end
  end
end
