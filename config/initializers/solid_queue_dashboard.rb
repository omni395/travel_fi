ActiveSupport.on_load(:solid_queue_record) do
  self.connects_to database: { writing: :queue, reading: :queue }
end