# frozen_string_literal: true

#
# Миграция: гарантирует наличие SRID 4326 (WGS 84) в spatial_ref_sys.
#
# `CREATE EXTENSION postgis` не всегда заполняет spatial_ref_sys данными — каст
# геометрии в geography (ST_SetSRID(ST_MakePoint(...), 4326)::geography) падает:
# `ERROR: Cannot find SRID (4326) in spatial_ref_sys`. Вставка идемпотентна.
#
class EnsurePostgisSrid4326 < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text)
      SELECT 4326, 'EPSG', 4326,
             'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563,AUTHORITY["EPSG","7030"]],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AUTHORITY["EPSG","4326"]]',
             '+proj=longlat +datum=WGS84 +no_defs'
      WHERE NOT EXISTS (SELECT 1 FROM spatial_ref_sys WHERE srid = 4326);
    SQL
  end

  def down
    execute "DELETE FROM spatial_ref_sys WHERE srid = 4326 AND auth_srid = 4326"
  end
end
