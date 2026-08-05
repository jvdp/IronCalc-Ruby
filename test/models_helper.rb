# Factories for the suites that work on an in-memory workbook.
module ModelsHelper
  LOCALE = "en"
  TIMEZONE = "UTC"
  LANGUAGE = "en"

  def model
    @model ||= IronCalc.create("m", LOCALE, TIMEZONE, LANGUAGE)
  end

  def user_model
    @user_model ||= IronCalc.create_user_model("m", LOCALE, TIMEZONE, LANGUAGE)
  end
end
