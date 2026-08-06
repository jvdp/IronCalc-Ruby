use magnus::value::Lazy;
use magnus::{function, method, prelude::*, Error, RHash, RString, Ruby};

use xlsx::base::expressions::types::ParsedReference;
use xlsx::base::expressions::utils;
use xlsx::base::{get_all_timezones, get_supported_locales};
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

fn load_from_icalc(file_name: String, language_id: String) -> Result<Model, Error> {
    let model =
        import::load_from_icalc(&file_name, leak_str(&language_id)).map_err(workbook_error)?;
    Ok(Model::new(model))
}

fn load_from_bytes(bytes: RString, language_id: String) -> Result<Model, Error> {
    let raw = unsafe { bytes.as_slice() }.to_vec();
    let workbook: Workbook = bitcode::decode(&raw).map_err(workbook_error)?;
    let model = CoreModel::from_workbook(workbook, leak_str(&language_id)).map_err(workbook_error)?;
    Ok(Model::new(model))
}

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

fn create_user_model_from_icalc(
    file_name: String,
    language_id: String,
) -> Result<UserModel, Error> {
    let model =
        import::load_from_icalc(&file_name, leak_str(&language_id)).map_err(workbook_error)?;
    Ok(UserModel::new(CoreUserModel::from_model(model)))
}

fn create_user_model_from_bytes(bytes: RString, language_id: String) -> Result<UserModel, Error> {
    let raw = unsafe { bytes.as_slice() }.to_vec();
    let workbook: Workbook = bitcode::decode(&raw).map_err(workbook_error)?;
    let model = CoreModel::from_workbook(workbook, leak_str(&language_id)).map_err(workbook_error)?;
    Ok(UserModel::new(CoreUserModel::from_model(model)))
}

// Engine helpers ----------------------------------------------------------

fn column_to_number(column: String) -> Result<i32, Error> {
    utils::column_to_number(&column).map_err(workbook_error)
}

fn number_to_column(column: i32) -> Option<String> {
    utils::number_to_column(column)
}

fn is_valid_column(column: String) -> bool {
    utils::is_valid_column(&column)
}

fn is_valid_column_number(column: i32) -> bool {
    utils::is_valid_column_number(column)
}

fn is_valid_row(row: i32) -> bool {
    utils::is_valid_row(row)
}

fn is_valid_identifier(name: String) -> bool {
    utils::is_valid_identifier(&name)
}

fn is_valid_a1_identifier(name: String) -> bool {
    utils::is_valid_a1_identifier(&name)
}

fn quote_name(name: String) -> String {
    utils::quote_name(&name)
}

fn parsed_reference_to_ruby(ruby: &Ruby, parsed: ParsedReference) -> RHash {
    let hash = ruby.hash_new();
    let _ = hash.aset(ruby.sym_new("row"), parsed.row);
    let _ = hash.aset(ruby.sym_new("column"), parsed.column);
    let _ = hash.aset(ruby.sym_new("absolute_row"), parsed.absolute_row);
    let _ = hash.aset(ruby.sym_new("absolute_column"), parsed.absolute_column);
    hash
}

fn parse_reference_a1(ruby: &Ruby, reference: String) -> Option<RHash> {
    utils::parse_reference_a1(&reference).map(|p| parsed_reference_to_ruby(ruby, p))
}

fn parse_reference_r1c1(ruby: &Ruby, reference: String) -> Option<RHash> {
    utils::parse_reference_r1c1(&reference).map(|p| parsed_reference_to_ruby(ruby, p))
}

fn supported_locales() -> Vec<String> {
    get_supported_locales()
}

fn all_timezones() -> Vec<String> {
    get_all_timezones()
}

#[allow(clippy::panic)]
fn test_panic() {
    panic!("This function panics for testing panic handling");
}

/// Registers native methods. The Ruby name is the Rust method name; the number
/// after the slash is the magnus arity.
macro_rules! define_methods {
    // `tt`, not `literal`: `method!` needs the bare integer token.
    ($class:expr, $ty:ident, [ $( $name:ident / $arity:tt ),* $(,)? ]) => {
        $( $class.define_method(stringify!($name), method!($ty::$name, $arity))?; )*
    };
}

// The grouping below is meaningful; rustfmt would split it one entry per line.
#[rustfmt::skip]
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
    module.define_module_function("column_to_number", function!(column_to_number, 1))?;
    module.define_module_function("number_to_column", function!(number_to_column, 1))?;
    module.define_module_function("is_valid_column", function!(is_valid_column, 1))?;
    module.define_module_function("is_valid_column_number", function!(is_valid_column_number, 1))?;
    module.define_module_function("is_valid_row", function!(is_valid_row, 1))?;
    module.define_module_function("is_valid_identifier", function!(is_valid_identifier, 1))?;
    module.define_module_function("is_valid_a1_identifier", function!(is_valid_a1_identifier, 1))?;
    module.define_module_function("quote_name", function!(quote_name, 1))?;
    module.define_module_function("parse_reference_a1", function!(parse_reference_a1, 1))?;
    module.define_module_function("parse_reference_r1c1", function!(parse_reference_r1c1, 1))?;
    module.define_module_function("get_supported_locales", function!(supported_locales, 0))?;
    module.define_module_function("get_all_timezones", function!(all_timezones, 0))?;
    module.define_module_function("test_panic", function!(test_panic, 0))?;

    // Raw API: IronCalc::Model
    let model_class = module.define_class("Model", ruby.class_object())?;
    // Persistence and evaluation
    define_methods!(model_class, Model, [
        save_to_xlsx/1, save_to_icalc/1, to_bytes/0, evaluate/0,
    ]);
    // Set / clear values
    define_methods!(model_class, Model, [
        set_user_input/4, clear_cell_contents/3, clear_cell_all/3,
        update_cell_with_text/4, update_cell_with_number/4,
        update_cell_with_bool/4, update_cell_with_formula/4,
    ]);
    // Get values
    define_methods!(model_class, Model, [
        get_cell_content/3, get_cell_type/3, get_formatted_cell_value/3,
        get_cell_value_by_index/3, get_cell_value_by_ref/1, get_cell_formula/3,
        is_empty_cell/3, get_all_cells/0,
    ]);
    // Styles (JSON across the boundary; the Ruby layer exposes Hashes)
    define_methods!(model_class, Model, [
        set_cell_style_json/4, get_cell_style_json/3, copy_cell_style/6,
        get_column_style_json/2, set_column_style_json/3, delete_column_style/2,
        get_row_style_json/2, set_row_style_json/3, delete_row_style/2,
    ]);
    // Rows / columns
    define_methods!(model_class, Model, [
        insert_rows/3, insert_columns/3, delete_rows/3, delete_columns/3,
        get_column_width/2, set_column_width/3, get_row_height/2, set_row_height/3,
    ]);
    // Frozen rows / columns
    define_methods!(model_class, Model, [
        get_frozen_columns_count/1, set_frozen_columns_count/2,
        get_frozen_rows_count/1, set_frozen_rows_count/2,
    ]);
    // Sheets
    define_methods!(model_class, Model, [
        get_worksheets_properties/0, get_sheet_dimensions/1, set_sheet_color/2,
        add_sheet/1, new_sheet/0, insert_sheet/3, set_sheet_state/2,
        delete_sheet/1, rename_sheet/2,
    ]);
    // Defined names
    define_methods!(model_class, Model, [
        get_defined_name_list/0, new_defined_name/3, update_defined_name/5,
        delete_defined_name/2, is_valid_defined_name/3,
    ]);
    define_methods!(model_class, Model, [test_panic/0]);

    // User API: IronCalc::UserModel
    let user_model_class = module.define_class("UserModel", ruby.class_object())?;
    // Persistence and collaboration (diff queue)
    define_methods!(user_model_class, UserModel, [
        save_to_xlsx/1, save_to_icalc/1, to_bytes/0,
        apply_external_diffs/1, flush_send_queue/0,
    ]);
    // Evaluation / history
    define_methods!(user_model_class, UserModel, [
        evaluate/0, pause_evaluation/0, resume_evaluation/0,
        undo/0, redo/0, can_undo/0, can_redo/0,
    ]);
    // Set / clear / get values
    define_methods!(user_model_class, UserModel, [
        set_user_input/4, clear_cell_contents/3, clear_cell_all/3,
        clear_cell_formatting/3,
        get_cell_content/3, get_cell_type/3, get_formatted_cell_value/3,
    ]);
    // Styles (per-property; the engine user model has no whole-Style setter)
    define_methods!(user_model_class, UserModel, [
        get_cell_style_json/3, update_range_style/5,
    ]);
    // Rows / columns
    define_methods!(user_model_class, UserModel, [
        insert_rows/3, insert_columns/3, delete_rows/3, delete_columns/3,
        get_column_width/2, set_column_width/3, get_row_height/2, set_row_height/3,
    ]);
    // Frozen rows / columns
    define_methods!(user_model_class, UserModel, [
        get_frozen_columns_count/1, set_frozen_columns_count/2,
        get_frozen_rows_count/1, set_frozen_rows_count/2,
    ]);
    // Sheets
    define_methods!(user_model_class, UserModel, [
        get_worksheets_properties/0, get_sheet_dimensions/1, set_sheet_color/2,
        new_sheet/0, delete_sheet/1, rename_sheet/2,
    ]);
    // Defined names
    define_methods!(user_model_class, UserModel, [
        get_defined_name_list/0, new_defined_name/3, update_defined_name/5,
        delete_defined_name/2, is_valid_defined_name/3,
    ]);

    Ok(())
}
