# Factories for the suites that work on an in-memory workbook.
module ModelsHelper
  LOCALE = "en".freeze
  TIMEZONE = "UTC".freeze
  LANGUAGE = "en".freeze

  def model
    @model ||= IronCalc.create("m", LOCALE, TIMEZONE, LANGUAGE)
  end

  def user_model
    @user_model ||= IronCalc.create_user_model("m", LOCALE, TIMEZONE, LANGUAGE)
  end

  # A complete style with whatever the block changes. Style setters reject a
  # partial Hash, so every style test starts here.
  def style_with(target = model)
    style = target.get_cell_style(0, 1, 1)
    yield style
    style
  end
end
