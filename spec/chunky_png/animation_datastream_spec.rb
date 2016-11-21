require 'spec_helper'

describe ChunkyPNG::AnimationDatastream do
  describe '.from_file' do
    it 'should read a stream without failing' do
      filename = resource_file('2x2_loop_animation.png')
      ads = ChunkyPNG::AnimationDatastream.from_file(filename)
      expect(ads).to be_instance_of(ChunkyPNG::AnimationDatastream)
    end
  end

  describe '#each_chunk' do
    let(:datastream) do
      filename = resource_file('2x2_loop_animation.png')
      ChunkyPNG::AnimationDatastream.from_file(filename)
    end
    let(:expected_types) do
      %w(IHDR tEXt PLTE tRNS acTL fcTL IDAT fcTL fdAT fcTL fdAT fcTL fdAT IEND)
    end

    it 'iterate chunks in frame order' do
      types, seq_nums = [], []
      datastream.each_chunk do |chunk|
        types << chunk.type
        seq_nums << chunk.sequence_number if chunk.respond_to?(:sequence_number)
      end
      expect(types).to eq(expected_types)
      expect(seq_nums).to eq((0..6).to_a)
    end
  end

  describe '#slice_frame_data_chunks' do
    subject { ds.slice_frame_data_chunks(fctl_chunk) }

    let(:ds) do
      filename = resource_file('2x2_loop_animation.png')
      ChunkyPNG::AnimationDatastream.from_file(filename)
    end

    context 'sequence number 0 (= default image)' do
      let(:fctl_chunk) { ds.frame_control_chunks[0] }
      it 'return empty array' do
        expect(fctl_chunk.sequence_number).to eq(0)
        is_expected.to eq([])
      end
    end

    context 'sequence number 1' do
      let(:fctl_chunk) { ds.frame_control_chunks[1] }
      it 'return fdat chunk whose sequence number 2' do
        expect(fctl_chunk.sequence_number).to eq(1)
        expected = ds.frame_data_chunks.select { |c| c.sequence_number == 2 }
        is_expected.to eq(expected)
      end
    end
  end
end
