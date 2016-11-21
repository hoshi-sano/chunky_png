require 'spec_helper'

describe ChunkyPNG::Animation do
  describe '.from_file' do
    it 'should read a stream without failing' do
      filename = resource_file('2x2_loop_animation.png')
      animation = ChunkyPNG::Animation.from_file(filename)
      expect(animation).to be_instance_of(ChunkyPNG::Animation)
      expect(animation.num_frames).to eq(4)
      expect(animation.num_plays).to eq(0)
      expect(animation.default_image_is_first_frame).to be_truthy
    end
  end

  describe '.to_datastream' do
    subject { animation.to_datastream }
    let(:animation) do
      frame = ChunkyPNG::Frame.new(1, 1, ChunkyPNG::Color::WHITE)
      ChunkyPNG::Animation.new(1, 1, frame).tap do |a|
        4.times { a.frames << ChunkyPNG::Frame.new(1, 1, ChunkyPNG::Color::WHITE) }
      end
    end
    it 'should return animation datastream' do
      expect(subject).to be_instance_of(ChunkyPNG::AnimationDatastream)
      expect(subject.animation_control_chunk)
        .to be_instance_of(ChunkyPNG::Chunk::AnimationControl)
      expect(subject.frame_control_chunks.size).to eq(5)
      expect(subject.frame_data_chunks.size).to eq(4)
      expect(subject.frame_control_chunks.first)
        .to be_instance_of(ChunkyPNG::Chunk::FrameControl)
      expect(subject.frame_data_chunks.first)
        .to be_instance_of(ChunkyPNG::Chunk::FrameData)
    end
  end
end
