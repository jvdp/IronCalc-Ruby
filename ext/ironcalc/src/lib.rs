use magnus::value::Lazy;
use magnus::{function, method, prelude::*, Error, RString, Ruby};

use xlsx::base::types::Workbook;
use xlsx::base::{Model as CoreModel, UserModel as CoreUserModel};
use xlsx::import;

mod error;
mod model;
mod user_model;

use error::{workbook_error, IRONCALC_ERROR};
use model::Model;
use user_model::UserModel;

fn leak_str(s: &str) -> &'static str {
    Box::leak(s.to_owned().into_boxed_str())
}

// Top-level constructors --------------------------------------------------

/// Creates an empty model using the raw API.
fn create(name: String, locale: String, tz: String, language_id: String) -> Result<Model, Error> {
    let model = CoreModel::new_empty(
        leak_str(&name),
        leak_str(&locale),
        leak_str(&tz),
        leak_str(&language_id),
    )
    .map_err(workbook_error)?;
    Ok(Model::new(model))
}

/// Loads a model from an xlsx file.
fn load_from_xlsx(
    file_path: String,
    locale: String,
    tz: String,
    language_id: String,
) -> Result<Model, Error> {
    let model = import::load_from_xlsx(&file_path, &locale, &tz, leak_str(&language_id))
        .map_err(workbook_error)?;
    Ok(Model::new(model))
}

/// Loads a model from the internal binary icalc format.
fn load_from_icalc(file_name: String, language_id: String) -> Result<Model, Error> {
    let model =
        import::load_from_icalc(&file_name, leak_str(&language_id)).map_err(workbook_error)?;
    Ok(Model::new(model))
}

/// Loads a model from icalc bytes (same format as `save_to_icalc`).
fn load_from_bytes(bytes: RString, language_id: String) -> Result<Model, Error> {
    let raw = unsafe { bytes.as_slice() }.to_vec();
    let workbook: Workbook = bitcode::decode(&raw).map_err(workbook_error)?;
    let model = CoreModel::from_workbook(workbook, leak_str(&language_id)).map_err(workbook_error)?;
    Ok(Model::new(model))
}

/// Creates an empty model using the user-model API.
fn create_user_model(
    name: String,
    locale: String,
    tz: String,
    language_id: String,
) -> Result<UserModel, Error> {
    let model = CoreUserModel::new_empty(
        leak_str(&name),
        leak_str(&locale),
        leak_str(&tz),
        leak_str(&language_id),
    )
    .map_err(workbook_error)?;
    Ok(UserModel::new(model))
}

/// Creates a user model from an xlsx file.
fn create_user_model_from_xlsx(
    file_path: String,
    locale: String,
    tz: String,
    language_id: String,
) -> Result<UserModel, Error> {
    let model = import::load_from_xlsx(&file_path, &locale, &tz, leak_str(&language_id))
        .map_err(workbook_error)?;
    Ok(UserModel::new(CoreUserModel::from_model(model)))
}

/// Creates a user model from an icalc file.
fn create_user_model_from_icalc(
    file_name: String,
    language_id: String,
) -> Result<UserModel, Error> {
    let model =
        import::load_from_icalc(&file_name, leak_str(&language_id)).map_err(workbook_error)?;
    Ok(UserModel::new(CoreUserModel::from_model(model)))
}

/// Creates a user model from icalc bytes (same format as `save_to_icalc`).
fn create_user_model_from_bytes(bytes: RString, language_id: String) -> Result<UserModel, Error> {
    let raw = unsafe { bytes.as_slice() }.to_vec();
    let workbook: Workbook = bitcode::decode(&raw).map_err(workbook_error)?;
    let model = CoreModel::from_workbook(workbook, leak_str(&language_id)).map_err(workbook_error)?;
    Ok(UserModel::new(CoreUserModel::from_model(model)))
}

#[allow(clippy::panic)]
fn test_panic() {
    panic!("This function panics for testing panic handling");
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("IronCalc")?;

    // Ensure the IronCalc::Error exception class exists.
    Lazy::force(&IRONCALC_ERROR, ruby);

    // Top-level constructors.
    module.define_module_function("create", function!(create, 4))?;
    module.define_module_function("load_from_xlsx", function!(load_from_xlsx, 4))?;
    module.define_module_function("load_from_icalc", function!(load_from_icalc, 2))?;
    module.define_module_function("load_from_bytes", function!(load_from_bytes, 2))?;
    module.define_module_function("create_user_model", function!(create_user_model, 4))?;
    module.define_module_function(
        "create_user_model_from_xlsx",
        function!(create_user_model_from_xlsx, 4),
    )?;
    module.define_module_function(
        "create_user_model_from_icalc",
        function!(create_user_model_from_icalc, 2),
    )?;
    module.define_module_function(
        "create_user_model_from_bytes",
        function!(create_user_model_from_bytes, 2),
    )?;
    module.define_module_function("test_panic", function!(test_panic, 0))?;

    // Raw API: IronCalc::Model
    let model_class = module.define_class("Model", ruby.class_object())?;
    model_class.define_method("save_to_xlsx", method!(Model::save_to_xlsx, 1))?;
    model_class.define_method("save_to_icalc", method!(Model::save_to_icalc, 1))?;
    model_class.define_method("to_bytes", method!(Model::to_bytes, 0))?;
    model_class.define_method("evaluate", method!(Model::evaluate, 0))?;
    model_class.define_method("set_user_input", method!(Model::set_user_input, 4))?;
    model_class.define_method("clear_cell_contents", method!(Model::clear_cell_contents, 3))?;
    model_class.define_method("get_cell_content", method!(Model::get_cell_content, 3))?;
    model_class.define_method("get_cell_type", method!(Model::get_cell_type, 3))?;
    model_class.define_method(
        "get_formatted_cell_value",
        method!(Model::get_formatted_cell_value, 3),
    )?;
    model_class.define_method("set_cell_style_json", method!(Model::set_cell_style_json, 4))?;
    model_class.define_method("get_cell_style_json", method!(Model::get_cell_style_json, 3))?;
    model_class.define_method("insert_rows", method!(Model::insert_rows, 3))?;
    model_class.define_method("insert_columns", method!(Model::insert_columns, 3))?;
    model_class.define_method("delete_rows", method!(Model::delete_rows, 3))?;
    model_class.define_method("delete_columns", method!(Model::delete_columns, 3))?;
    model_class.define_method("get_column_width", method!(Model::get_column_width, 2))?;
    model_class.define_method("get_row_height", method!(Model::get_row_height, 2))?;
    model_class.define_method("set_column_width", method!(Model::set_column_width, 3))?;
    model_class.define_method("set_row_height", method!(Model::set_row_height, 3))?;
    model_class.define_method(
        "get_frozen_columns_count",
        method!(Model::get_frozen_columns_count, 1),
    )?;
    model_class.define_method(
        "get_frozen_rows_count",
        method!(Model::get_frozen_rows_count, 1),
    )?;
    model_class.define_method(
        "set_frozen_columns_count",
        method!(Model::set_frozen_columns_count, 2),
    )?;
    model_class.define_method(
        "set_frozen_rows_count",
        method!(Model::set_frozen_rows_count, 2),
    )?;
    model_class.define_method(
        "get_worksheets_properties",
        method!(Model::get_worksheets_properties, 0),
    )?;
    model_class.define_method("set_sheet_color", method!(Model::set_sheet_color, 2))?;
    model_class.define_method("add_sheet", method!(Model::add_sheet, 1))?;
    model_class.define_method("new_sheet", method!(Model::new_sheet, 0))?;
    model_class.define_method("delete_sheet", method!(Model::delete_sheet, 1))?;
    model_class.define_method("rename_sheet", method!(Model::rename_sheet, 2))?;
    model_class.define_method("get_sheet_dimensions", method!(Model::get_sheet_dimensions, 1))?;
    model_class.define_method("test_panic", method!(Model::test_panic, 0))?;

    // User API: IronCalc::UserModel
    let user_model_class = module.define_class("UserModel", ruby.class_object())?;
    user_model_class.define_method("save_to_xlsx", method!(UserModel::save_to_xlsx, 1))?;
    user_model_class.define_method("save_to_icalc", method!(UserModel::save_to_icalc, 1))?;
    user_model_class.define_method(
        "apply_external_diffs",
        method!(UserModel::apply_external_diffs, 1),
    )?;
    user_model_class.define_method("flush_send_queue", method!(UserModel::flush_send_queue, 0))?;
    // Evaluation / history
    user_model_class.define_method("evaluate", method!(UserModel::evaluate, 0))?;
    user_model_class.define_method("undo", method!(UserModel::undo, 0))?;
    user_model_class.define_method("redo", method!(UserModel::redo, 0))?;
    user_model_class.define_method("can_undo", method!(UserModel::can_undo, 0))?;
    user_model_class.define_method("can_redo", method!(UserModel::can_redo, 0))?;
    // Set / clear / get values
    user_model_class.define_method("set_user_input", method!(UserModel::set_user_input, 4))?;
    user_model_class.define_method(
        "clear_cell_contents",
        method!(UserModel::clear_cell_contents, 3),
    )?;
    user_model_class.define_method("get_cell_content", method!(UserModel::get_cell_content, 3))?;
    user_model_class.define_method("get_cell_type", method!(UserModel::get_cell_type, 3))?;
    user_model_class.define_method(
        "get_formatted_cell_value",
        method!(UserModel::get_formatted_cell_value, 3),
    )?;
    // Styles
    user_model_class.define_method(
        "get_cell_style_json",
        method!(UserModel::get_cell_style_json, 3),
    )?;
    user_model_class.define_method(
        "update_range_style",
        method!(UserModel::update_range_style, 5),
    )?;
    // Rows / columns
    user_model_class.define_method("insert_rows", method!(UserModel::insert_rows, 3))?;
    user_model_class.define_method("insert_columns", method!(UserModel::insert_columns, 3))?;
    user_model_class.define_method("delete_rows", method!(UserModel::delete_rows, 3))?;
    user_model_class.define_method("delete_columns", method!(UserModel::delete_columns, 3))?;
    user_model_class.define_method("get_column_width", method!(UserModel::get_column_width, 2))?;
    user_model_class.define_method("get_row_height", method!(UserModel::get_row_height, 2))?;
    user_model_class.define_method("set_column_width", method!(UserModel::set_column_width, 3))?;
    user_model_class.define_method("set_row_height", method!(UserModel::set_row_height, 3))?;
    // Frozen rows / columns
    user_model_class.define_method(
        "get_frozen_columns_count",
        method!(UserModel::get_frozen_columns_count, 1),
    )?;
    user_model_class.define_method(
        "get_frozen_rows_count",
        method!(UserModel::get_frozen_rows_count, 1),
    )?;
    user_model_class.define_method(
        "set_frozen_columns_count",
        method!(UserModel::set_frozen_columns_count, 2),
    )?;
    user_model_class.define_method(
        "set_frozen_rows_count",
        method!(UserModel::set_frozen_rows_count, 2),
    )?;
    // Sheets
    user_model_class.define_method(
        "get_worksheets_properties",
        method!(UserModel::get_worksheets_properties, 0),
    )?;
    user_model_class.define_method("set_sheet_color", method!(UserModel::set_sheet_color, 2))?;
    user_model_class.define_method("new_sheet", method!(UserModel::new_sheet, 0))?;
    user_model_class.define_method("delete_sheet", method!(UserModel::delete_sheet, 1))?;
    user_model_class.define_method("rename_sheet", method!(UserModel::rename_sheet, 2))?;
    user_model_class.define_method(
        "get_sheet_dimensions",
        method!(UserModel::get_sheet_dimensions, 1),
    )?;
    user_model_class.define_method("to_bytes", method!(UserModel::to_bytes, 0))?;

    Ok(())
}
