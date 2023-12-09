# frozen_string_literal: true

require 'fast_spec_helper'
require 'diff_match_patch'

describe Gitlab::Diff::CharDiff do
  let(:old_string) { "Helo \n Worlld" }
  let(:new_string) { "Hello \n World" }

  subject { described_class.new(old_string, new_string) }

  describe '#generate_diff' do
    context 'when old string is nil' do
      let(:old_string) { nil }

      it 'does not raise an error' do
        expect { subject.generate_diff }.not_to raise_error
      end

      it 'treats nil values as blank strings' do
        changes = subject.generate_diff

        expect(changes).to eq([
          [:insert, "Hello \n World"]
        ])
      end
    end

    it 'generates an array of changes' do
      changes = subject.generate_diff

      expect(changes).to eq([
        [:equal, "Hel"],
        [:insert, "l"],
        [:equal, "o \n Worl"],
        [:delete, "l"],
        [:equal, "d"]
      ])
    end
  end

  describe '#to_html' do
    it 'returns an HTML representation of the diff' do
      subject.generate_diff

      expect(subject.to_html).to eq(
        '<span class="idiff">Hel</span>' \
        '<span class="idiff addition">l</span>' \
        "<span class=\"idiff\">o \n Worl</span>" \
        '<span class="idiff deletion">l</span>' \
        '<span class="idiff">d</span>'
      )
    end
  end
end
