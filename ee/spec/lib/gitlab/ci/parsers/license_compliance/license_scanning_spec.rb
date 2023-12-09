# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Ci::Parsers::LicenseCompliance::LicenseScanning do
  describe '#parse!' do
    let(:report) { Gitlab::Ci::Reports::LicenseScanning::Report.new }

    context 'when parsing a valid v1 report' do
      let(:v1_json) { fixture_file('security_reports/master/gl-license-scanning-report.json', dir: 'ee') }

      before do
        subject.parse!(v1_json, report)
      end

      it { expect(report.version).to eql('1.0') }
      it { expect(report.licenses.count).to eq(4) }

      it { expect(report.licenses[0].name).to eql('Apache 2.0') }
      it { expect(report.licenses[0].url).to eql('http://www.apache.org/licenses/LICENSE-2.0.txt') }
      it { expect(report.licenses[0].count).to be(1) }
      it { expect(report.licenses[0].dependencies.count).to be(1) }
      it { expect(report.licenses[0].dependencies[0].name).to eql('thread_safe') }

      it { expect(report.licenses[1].name).to eql('MIT') }
      it { expect(report.licenses[1].url).to eql('http://opensource.org/licenses/mit-license') }
      it { expect(report.licenses[1].count).to be(52) }
      it { expect(report.licenses[1].dependencies.count).to be(52) }
      it { expect(report.licenses[1].dependencies[0].name).to eql('actioncable') }

      it { expect(report.licenses[2].name).to eql('New BSD') }
      it { expect(report.licenses[2].url).to eql('http://opensource.org/licenses/BSD-3-Clause') }
      it { expect(report.licenses[2].count).to be(3) }
      it { expect(report.licenses[2].dependencies.count).to be(3) }
      it { expect(report.licenses[2].dependencies.map(&:name)).to contain_exactly('ffi', 'puma', 'sqlite3') }

      it { expect(report.licenses[3].name).to eql('unknown') }
      it { expect(report.licenses[3].url).to be_nil }
      it { expect(report.licenses[3].count).to be(1) }
      it { expect(report.licenses[3].dependencies.count).to be(1) }
      it { expect(report.licenses[3].dependencies[0].name).to eql('ruby-bundler-rails') }
    end

    context 'when parsing a valid v1.1 report' do
      let(:v1_1_data) { fixture_file('security_reports/gl-license-management-report-v1.1.json', dir: 'ee') }

      before do
        subject.parse!(v1_1_data, report)
      end

      it { expect(report.version).to eql('1.1') }
      it { expect(report.licenses.count).to eq(3) }

      it { expect(report.licenses[0].id).to eql('BSD-4-Clause') }
      it { expect(report.licenses[0].name).to eql('BSD') }
      it { expect(report.licenses[0].url).to eql('http://spdx.org/licenses/BSD-4-Clause.json') }
      it { expect(report.licenses[0].count).to be(2) }
      it { expect(report.licenses[0].dependencies.count).to be(2) }
      it { expect(report.licenses[0].dependencies.map(&:name)).to contain_exactly('b', 'c') }

      it { expect(report.licenses[1].id).to eql('MIT') }
      it { expect(report.licenses[1].name).to eql('MIT') }
      it { expect(report.licenses[1].url).to eql('http://opensource.org/licenses/mit-license') }
      it { expect(report.licenses[1].count).to be(2) }
      it { expect(report.licenses[1].dependencies.count).to be(2) }
      it { expect(report.licenses[1].dependencies.map(&:name)).to contain_exactly('a', 'c') }

      it { expect(report.licenses[2].id).to be_nil }
      it { expect(report.licenses[2].name).to eql('unknown') }
      it { expect(report.licenses[2].url).to eql('') }
      it { expect(report.licenses[2].count).to be(1) }
      it { expect(report.licenses[2].dependencies.count).to be(1) }
      it { expect(report.licenses[2].dependencies.map(&:name)).to contain_exactly('d') }
    end

    context 'when parsing a valid v2 report' do
      let(:v2_data) { fixture_file('security_reports/gl-license-management-report-v2.json', dir: 'ee') }

      before do
        subject.parse!(v2_data, report)
      end

      it { expect(report.version).to eql('2.0') }
      it { expect(report.licenses.count).to eq(3) }

      it { expect(report.licenses[0].id).to eql('BSD-3-Clause') }
      it { expect(report.licenses[0].name).to eql('BSD 3-Clause "New" or "Revised" License') }
      it { expect(report.licenses[0].url).to eql('http://spdx.org/licenses/BSD-3-Clause.json') }
      it { expect(report.licenses[0].count).to be(2) }
      it { expect(report.licenses[0].dependencies.count).to be(2) }
      it { expect(report.licenses[0].dependencies.map(&:name)).to contain_exactly('b', 'c') }

      it { expect(report.licenses[1].id).to eql('MIT') }
      it { expect(report.licenses[1].name).to eql('MIT License') }
      it { expect(report.licenses[1].url).to eql('http://spdx.org/licenses/MIT.json') }
      it { expect(report.licenses[1].count).to be(2) }
      it { expect(report.licenses[1].dependencies.count).to be(2) }
      it { expect(report.licenses[1].dependencies.map(&:name)).to contain_exactly('a', 'c') }

      it { expect(report.licenses[2].id).to be_nil }
      it { expect(report.licenses[2].name).to eql('unknown') }
      it { expect(report.licenses[2].url).to eql('') }
      it { expect(report.licenses[2].count).to be(1) }
      it { expect(report.licenses[2].dependencies.count).to be(1) }
      it { expect(report.licenses[2].dependencies.map(&:name)).to contain_exactly('d') }
    end

    context 'when parsing a v2 report with a missing license definition' do
      let(:v2_data) do
        {
          version: '2.0',
          licenses: [],
          dependencies: [
            { name: 'saml-kit', licenses: ['MIT'] }
          ]
        }.to_json
      end

      before do
        subject.parse!(v2_data, report)
      end

      it { expect(report.licenses.count).to be(1) }
      it { expect(report.licenses[0].id).to eql('MIT') }
      it { expect(report.licenses[0].name).to eql('unknown') }
      it { expect(report.licenses[0].dependencies.count).to be(1) }
      it { expect(report.licenses[0].dependencies[0].name).to eql('saml-kit') }
    end

    context 'when the report version is not recognized' do
      it do
        expect do
          subject.parse!(JSON.pretty_generate({ version: 'x' }), report)
        end.to raise_error(KeyError)
      end
    end

    context 'when the report version is missing' do
      before do
        subject.parse!(JSON.pretty_generate({}), report)
      end

      it { expect(report.version).to eq('1.0') }
      it { expect(report).to be_empty }
    end

    context 'when the report version is nil' do
      before do
        subject.parse!(JSON.pretty_generate({ version: nil }), report)
      end

      it { expect(report.version).to eq('1.0') }
      it { expect(report).to be_empty }
    end

    context 'when the report version is blank' do
      before do
        subject.parse!(JSON.pretty_generate({ version: '' }), report)
      end

      it { expect(report.version).to eq('1.0') }
      it { expect(report).to be_empty }
    end

    context 'when the report is not a valid JSON document' do
      it do
        expect do
          subject.parse!('blah', report)
        end.to raise_error(Gitlab::Ci::Parsers::LicenseCompliance::LicenseScanning::LicenseScanningParserError)
      end
    end
  end
end
