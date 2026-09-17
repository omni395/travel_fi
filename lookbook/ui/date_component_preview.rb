# frozen_string_literal: true

# @logical_path ui
# @component Ui::DateComponent
class Ui::DateComponentPreview < Lookbook::Preview
  # 1. Форматы написания (короткий, длинный, по умолчанию)
  def formats
    render_with_template(locals: { sample_time: Time.current })
  end

  # 2. Раздельное отображение (Только дата / Только время / Относительное время)
  def split_date_and_time
    render_with_template(locals: { sample_time: Time.current - 2.hours })
  end

  # 3. Пустое значение (Fallback / Никогда)
  def empty_fallback
    render_with_template
  end

  # 4. Отображение в виде бейджей (Badges)
  def badges
    render_with_template(locals: { sample_time: Time.current })
  end
end
