# frozen_string_literal: true

require 'rails_helper'

#
# OsmPbfImportJob — unit-спек фонового импорта из .pbf.
# Проверяет: вызов сервиса, broadcast прогресса и КРИТИЧНОЕ удаление
# временного файла в ensure.
#
RSpec.describe OsmPbfImportJob, type: :job do
  let(:category) { create(:poi_category, :with_osm_tags) }
  let(:user) { create(:user, :admin) }

  describe '#perform' do
    it 'удаляет временный .pbf файл (в ensure) после импорта' do
      # Создаём реальный временный файл
      temp = Rails.root.join('tmp', 'pbf_test.osm.pbf')
      FileUtils.mkdir_p(Rails.root.join('tmp'))
      File.write(temp, 'pbf-bytes')

      allow(OsmPbfImportService).to receive(:call).and_return(
        { created: 1, skipped_duplicate: 0, skipped_modified: 0, errors: 0 }
      )
      allow(OsmImportBroadcaster).to receive(:started)
      allow(OsmImportBroadcaster).to receive(:call)

      described_class.perform_now(category.id, temp.to_s, user.id)

      expect(File.exist?(temp)).to be false
    end

    it 'удаляет файл даже при ошибке сервиса' do
      temp = Rails.root.join('tmp', 'pbf_fail.osm.pbf')
      File.write(temp, 'pbf-bytes')

      allow(OsmPbfImportService).to receive(:call).and_raise(OsmPbfImportService::ImportError, 'tool missing')
      allow(OsmImportBroadcaster).to receive(:started)
      allow(OsmImportBroadcaster).to receive(:failed)

      expect { described_class.perform_now(category.id, temp.to_s, user.id) }
        .not_to raise_error

      expect(File.exist?(temp)).to be false
      expect(OsmImportBroadcaster).to have_received(:failed)
    end

    it 'отправляет прогресс и финальный результат' do
      temp = Rails.root.join('tmp', 'pbf_prog.osm.pbf')
      File.write(temp, 'pbf-bytes')

      allow(OsmPbfImportService).to receive(:call) do |**kwargs, &block|
        block.call(100) if block
        { created: 5, skipped_duplicate: 0, skipped_modified: 0, errors: 0 }
      end
      allow(OsmImportBroadcaster).to receive(:started)
      allow(OsmImportBroadcaster).to receive(:pbf_progress)
      allow(OsmImportBroadcaster).to receive(:call)

      described_class.perform_now(category.id, temp.to_s, user.id)

      expect(OsmImportBroadcaster).to have_received(:pbf_progress).with(user: user, processed: 100)
      expect(OsmImportBroadcaster).to have_received(:call)
      FileUtils.rm_f(temp)
    end
  end
end
