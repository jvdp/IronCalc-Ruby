use std::cell::RefCell;

use magnus::value::StaticSymbol;
use magnus::value::ReprValue;
use magnus::{IntoValue, RArray, RString, Ruby, TryConvert, Value};

use xlsx::base::cell::CellValue;
use xlsx::base::expressions::types::Area;
use xlsx::base::types::{Color, SheetState, Style};
use xlsx::base::Model as CoreModel;
use xlsx::export::{save_to_icalc, save_to_xlsx};

use crate::error::workbook_error;

pub(crate) fn cell_area(sheet: u32, row: i32, column: i32) -> Area {
    Area {
        sheet,
        row,
        column,
        width: 1,
        height: 1,
    }
}

pub(crate) fn color_to_ruby(ruby: &Ruby, color: &Color) -> Value {
    match color {
        Color::Rgb(hex) => hex.clone().into_value_with(ruby),
        Color::Theme(theme, tint) => {
            let array = ruby.ary_new();
            let _ = array.push(*theme);
            let _ = array.push(*tint);
            array.into_value_with(ruby)
        }
        Color::None => ruby.qnil().into_value_with(ruby),
    }
}

/// Accepts the same shapes `color_to_ruby` produces, so a color read from one
/// sheet can be written to another.
pub(crate) fn parse_color(color: Value) -> Result<Color, magnus::Error> {
    if color.is_nil() {
        return Ok(Color::None);
    }
    if let Ok(hex) = String::try_convert(color) {
        return Ok(Color::Rgb(hex));
    }
    match <(i32, f64)>::try_convert(color) {
        Ok((theme, tint)) => Ok(Color::Theme(theme, tint)),
        Err(_) => Err(workbook_error(
            "Color must be a \"#RRGGBB\" String, a [theme, tint] pair, or nil",
        )),
    }
}

fn cell_value_to_ruby(ruby: &Ruby, value: CellValue) -> Value {
    match value {
        CellValue::None => ruby.qnil().into_value_with(ruby),
        CellValue::String(s) => s.into_value_with(ruby),
        CellValue::Number(n) => n.into_value_with(ruby),
        CellValue::Boolean(b) => b.into_value_with(ruby),
    }
}

/// Each class passes the result of its own engine call.
pub(crate) fn defined_names_to_ruby(
    ruby: &Ruby,
    names: impl IntoIterator<Item = (String, Option<u32>, String)>,
) -> RArray {
    let array = ruby.ary_new();
    let (name_key, scope_key, formula_key) = (
        ruby.sym_new("name"),
        ruby.sym_new("scope"),
        ruby.sym_new("formula"),
    );
    for (name, scope, formula) in names {
        let hash = ruby.hash_new();
        let _ = hash.aset(name_key, name);
        let _ = hash.aset(scope_key, scope);
        let _ = hash.aset(formula_key, formula);
        let _ = array.push(hash);
    }
    array
}

fn parse_sheet_state(state: &str) -> Result<SheetState, magnus::Error> {
    match state {
        "visible" => Ok(SheetState::Visible),
        "hidden" => Ok(SheetState::Hidden),
        "veryHidden" | "very_hidden" => Ok(SheetState::VeryHidden),
        other => Err(workbook_error(format!(
            "Invalid sheet state: '{other}' (expected visible, hidden or veryHidden)"
        ))),
    }
}

/// Names match the Python binding's `CellType` variants.
pub(crate) fn cell_type_to_str(cell_type: xlsx::base::types::CellType) -> &'static str {
    use xlsx::base::types::CellType::*;
    match cell_type {
        Number => "number",
        Text => "text",
        LogicalValue => "logical_value",
        ErrorValue => "error_value",
        Array => "array",
        CompoundData => "compound_data",
    }
}

#[magnus::wrap(class = "IronCalc::Model", free_immediately, size)]
pub struct Model {
    pub model: RefCell<CoreModel<'static>>,
}

impl Model {
    pub fn new(model: CoreModel<'static>) -> Self {
        Model {
            model: RefCell::new(model),
        }
    }

    // Persistence -----------------------------------------------------------

    pub fn save_to_xlsx(&self, file: String) -> Result<(), magnus::Error> {
        save_to_xlsx(&self.model.borrow(), &file).map_err(workbook_error)
    }

    pub fn save_to_icalc(&self, file: String) -> Result<(), magnus::Error> {
        save_to_icalc(&self.model.borrow(), &file).map_err(workbook_error)
    }

    pub fn to_bytes(ruby: &Ruby, rb_self: &Self) -> RString {
        ruby.str_from_slice(&rb_self.model.borrow().to_bytes())
    }

    // Evaluation ------------------------------------------------------------

    pub fn evaluate(&self) {
        self.model.borrow_mut().evaluate()
    }

    // Set / clear values ----------------------------------------------------

    pub fn set_user_input(
        &self,
        sheet: u32,
        row: i32,
        column: i32,
        value: String,
    ) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .set_user_input(sheet, row, column, value)
            .map_err(workbook_error)
    }

    pub fn clear_cell_contents(
        &self,
        sheet: u32,
        row: i32,
        column: i32,
    ) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .range_clear_contents(&cell_area(sheet, row, column))
            .map_err(workbook_error)
    }

    pub fn clear_cell_all(&self, sheet: u32, row: i32, column: i32) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .range_clear_all(&cell_area(sheet, row, column))
            .map_err(workbook_error)
    }

    pub fn update_cell_with_text(
        &self,
        sheet: u32,
        row: i32,
        column: i32,
        value: String,
    ) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .update_cell_with_text(sheet, row, column, &value)
            .map_err(workbook_error)
    }

    pub fn update_cell_with_number(
        &self,
        sheet: u32,
        row: i32,
        column: i32,
        value: f64,
    ) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .update_cell_with_number(sheet, row, column, value)
            .map_err(workbook_error)
    }

    pub fn update_cell_with_bool(
        &self,
        sheet: u32,
        row: i32,
        column: i32,
        value: bool,
    ) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .update_cell_with_bool(sheet, row, column, value)
            .map_err(workbook_error)
    }

    pub fn update_cell_with_formula(
        &self,
        sheet: u32,
        row: i32,
        column: i32,
        formula: String,
    ) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .update_cell_with_formula(sheet, row, column, formula)
            .map_err(workbook_error)
    }

    // Get values ------------------------------------------------------------

    pub fn get_cell_content(
        &self,
        sheet: u32,
        row: i32,
        column: i32,
    ) -> Result<String, magnus::Error> {
        self.model
            .borrow()
            .get_localized_cell_content(sheet, row, column)
            .map_err(workbook_error)
    }

    pub fn get_cell_type(
        ruby: &Ruby,
        rb_self: &Self,
        sheet: u32,
        row: i32,
        column: i32,
    ) -> Result<StaticSymbol, magnus::Error> {
        rb_self
            .model
            .borrow()
            .get_cell_type(sheet, row, column)
            .map(|t| ruby.sym_new(cell_type_to_str(t)))
            .map_err(workbook_error)
    }

    pub fn get_formatted_cell_value(
        &self,
        sheet: u32,
        row: i32,
        column: i32,
    ) -> Result<String, magnus::Error> {
        self.model
            .borrow()
            .get_formatted_cell_value(sheet, row, column)
            .map_err(workbook_error)
    }

    pub fn get_cell_value_by_index(
        ruby: &Ruby,
        rb_self: &Self,
        sheet: u32,
        row: i32,
        column: i32,
    ) -> Result<Value, magnus::Error> {
        rb_self
            .model
            .borrow()
            .get_cell_value_by_index(sheet, row, column)
            .map(|v| cell_value_to_ruby(ruby, v))
            .map_err(workbook_error)
    }

    pub fn get_cell_value_by_ref(
        ruby: &Ruby,
        rb_self: &Self,
        cell_ref: String,
    ) -> Result<Value, magnus::Error> {
        rb_self
            .model
            .borrow()
            .get_cell_value_by_ref(&cell_ref)
            .map(|v| cell_value_to_ruby(ruby, v))
            .map_err(workbook_error)
    }

    pub fn get_cell_formula(
        &self,
        sheet: u32,
        row: i32,
        column: i32,
    ) -> Result<Option<String>, magnus::Error> {
        self.model
            .borrow()
            .get_cell_formula(sheet, row, column)
            .map_err(workbook_error)
    }

    pub fn is_empty_cell(&self, sheet: u32, row: i32, column: i32) -> Result<bool, magnus::Error> {
        self.model
            .borrow()
            .is_empty_cell(sheet, row, column)
            .map_err(workbook_error)
    }

    pub fn get_all_cells(ruby: &Ruby, rb_self: &Self) -> RArray {
        let array = ruby.ary_new();
        // Interned once: this loop is O(cells).
        let (sheet_key, row_key, column_key) = (
            ruby.sym_new("sheet"),
            ruby.sym_new("row"),
            ruby.sym_new("column"),
        );
        for cell in rb_self.model.borrow().get_all_cells() {
            let hash = ruby.hash_new();
            let _ = hash.aset(sheet_key, cell.index);
            let _ = hash.aset(row_key, cell.row);
            let _ = hash.aset(column_key, cell.column);
            let _ = array.push(hash);
        }
        array
    }

    // Styles (serialized as JSON; the Ruby layer exposes them as hashes) -----

    pub fn set_cell_style_json(
        &self,
        sheet: u32,
        row: i32,
        column: i32,
        style_json: String,
    ) -> Result<(), magnus::Error> {
        let style: Style = serde_json::from_str(&style_json).map_err(workbook_error)?;
        self.model
            .borrow_mut()
            .set_cell_style(sheet, row, column, &style)
            .map_err(workbook_error)
    }

    pub fn get_cell_style_json(
        &self,
        sheet: u32,
        row: i32,
        column: i32,
    ) -> Result<String, magnus::Error> {
        let style = self
            .model
            .borrow()
            .get_style_for_cell(sheet, row, column)
            .map_err(workbook_error)?;
        serde_json::to_string(&style).map_err(workbook_error)
    }

    pub fn copy_cell_style(
        &self,
        source_sheet: u32,
        source_row: i32,
        source_column: i32,
        destination_sheet: u32,
        destination_row: i32,
        destination_column: i32,
    ) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .copy_cell_style(
                (source_sheet, source_row, source_column),
                (destination_sheet, destination_row, destination_column),
            )
            .map_err(workbook_error)
    }

    // Row / column styles (the default style for a whole row or column) ------

    pub fn get_column_style_json(
        &self,
        sheet: u32,
        column: i32,
    ) -> Result<Option<String>, magnus::Error> {
        let style = self
            .model
            .borrow()
            .get_column_style(sheet, column)
            .map_err(workbook_error)?;
        style
            .map(|s| serde_json::to_string(&s).map_err(workbook_error))
            .transpose()
    }

    pub fn get_row_style_json(
        &self,
        sheet: u32,
        row: i32,
    ) -> Result<Option<String>, magnus::Error> {
        let style = self
            .model
            .borrow()
            .get_row_style(sheet, row)
            .map_err(workbook_error)?;
        style
            .map(|s| serde_json::to_string(&s).map_err(workbook_error))
            .transpose()
    }

    pub fn set_column_style_json(
        &self,
        sheet: u32,
        column: i32,
        style_json: String,
    ) -> Result<(), magnus::Error> {
        let style: Style = serde_json::from_str(&style_json).map_err(workbook_error)?;
        self.model
            .borrow_mut()
            .set_column_style(sheet, column, &style)
            .map_err(workbook_error)
    }

    pub fn set_row_style_json(
        &self,
        sheet: u32,
        row: i32,
        style_json: String,
    ) -> Result<(), magnus::Error> {
        let style: Style = serde_json::from_str(&style_json).map_err(workbook_error)?;
        self.model
            .borrow_mut()
            .set_row_style(sheet, row, &style)
            .map_err(workbook_error)
    }

    pub fn delete_column_style(&self, sheet: u32, column: i32) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .delete_column_style(sheet, column)
            .map_err(workbook_error)
    }

    pub fn delete_row_style(&self, sheet: u32, row: i32) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .delete_row_style(sheet, row)
            .map_err(workbook_error)
    }

    // Rows / columns --------------------------------------------------------

    pub fn insert_rows(&self, sheet: u32, row: i32, row_count: i32) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .insert_rows(sheet, row, row_count)
            .map_err(workbook_error)
    }

    pub fn insert_columns(
        &self,
        sheet: u32,
        column: i32,
        column_count: i32,
    ) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .insert_columns(sheet, column, column_count)
            .map_err(workbook_error)
    }

    pub fn delete_rows(&self, sheet: u32, row: i32, row_count: i32) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .delete_rows(sheet, row, row_count)
            .map_err(workbook_error)
    }

    pub fn delete_columns(
        &self,
        sheet: u32,
        column: i32,
        column_count: i32,
    ) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .delete_columns(sheet, column, column_count)
            .map_err(workbook_error)
    }

    pub fn get_column_width(&self, sheet: u32, column: i32) -> Result<f64, magnus::Error> {
        self.model
            .borrow()
            .get_column_width(sheet, column)
            .map_err(workbook_error)
    }

    pub fn get_row_height(&self, sheet: u32, row: i32) -> Result<f64, magnus::Error> {
        self.model
            .borrow()
            .get_row_height(sheet, row)
            .map_err(workbook_error)
    }

    pub fn set_column_width(
        &self,
        sheet: u32,
        column: i32,
        width: f64,
    ) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .set_column_width(sheet, column, width)
            .map_err(workbook_error)
    }

    pub fn set_row_height(&self, sheet: u32, row: i32, height: f64) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .set_row_height(sheet, row, height)
            .map_err(workbook_error)
    }

    // Frozen rows / columns -------------------------------------------------

    pub fn get_frozen_columns_count(&self, sheet: u32) -> Result<i32, magnus::Error> {
        self.model
            .borrow()
            .get_frozen_columns_count(sheet)
            .map_err(workbook_error)
    }

    pub fn get_frozen_rows_count(&self, sheet: u32) -> Result<i32, magnus::Error> {
        self.model
            .borrow()
            .get_frozen_rows_count(sheet)
            .map_err(workbook_error)
    }

    pub fn set_frozen_columns_count(
        &self,
        sheet: u32,
        column_count: i32,
    ) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .set_frozen_columns(sheet, column_count)
            .map_err(workbook_error)
    }

    pub fn set_frozen_rows_count(&self, sheet: u32, row_count: i32) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .set_frozen_rows(sheet, row_count)
            .map_err(workbook_error)
    }

    // Sheets ----------------------------------------------------------------

    pub fn get_worksheets_properties(ruby: &Ruby, rb_self: &Self) -> RArray {
        let array = ruby.ary_new();
        for sheet in rb_self.model.borrow().get_worksheets_properties() {
            let hash = ruby.hash_new();
            let _ = hash.aset(ruby.sym_new("name"), sheet.name);
            let _ = hash.aset(ruby.sym_new("state"), sheet.state);
            let _ = hash.aset(ruby.sym_new("sheet_id"), sheet.sheet_id);
            let _ = hash.aset(ruby.sym_new("color"), color_to_ruby(ruby, &sheet.color));
            let _ = array.push(hash);
        }
        array
    }

    pub fn set_sheet_color(&self, sheet: u32, color: Value) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .set_sheet_color(sheet, &parse_color(color)?)
            .map_err(workbook_error)
    }

    pub fn add_sheet(&self, sheet_name: String) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .add_sheet(&sheet_name)
            .map_err(workbook_error)
    }

    pub fn new_sheet(&self) {
        self.model.borrow_mut().new_sheet();
    }

    pub fn insert_sheet(
        &self,
        sheet_name: String,
        sheet_index: u32,
        sheet_id: Option<u32>,
    ) -> Result<(), magnus::Error> {
        let mut model = self.model.borrow_mut();
        // A duplicate id silently mis-scopes defined names, which resolve a
        // sheet id to the first match.
        if let Some(id) = sheet_id {
            if model
                .get_worksheets_properties()
                .iter()
                .any(|sheet| sheet.sheet_id == id)
            {
                return Err(workbook_error(format!("Sheet id {id} is already in use")));
            }
        }
        model
            .insert_sheet(&sheet_name, sheet_index, sheet_id)
            .map_err(workbook_error)
    }

    pub fn set_sheet_state(&self, sheet: u32, state: String) -> Result<(), magnus::Error> {
        let state = parse_sheet_state(&state)?;
        self.model
            .borrow_mut()
            .set_sheet_state(sheet, state)
            .map_err(workbook_error)
    }

    pub fn delete_sheet(&self, sheet: u32) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .delete_sheet(sheet)
            .map_err(workbook_error)
    }

    pub fn rename_sheet(&self, sheet: u32, new_name: String) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .rename_sheet_by_index(sheet, &new_name)
            .map_err(workbook_error)
    }

    pub fn get_sheet_dimensions(&self, sheet: u32) -> Result<(i32, i32, i32, i32), magnus::Error> {
        let model = self.model.borrow();
        let worksheet = model.workbook.worksheet(sheet).map_err(workbook_error)?;
        let dimension = worksheet.dimension();
        Ok((
            dimension.min_row,
            dimension.max_row,
            dimension.min_column,
            dimension.max_column,
        ))
    }

    // Defined names ---------------------------------------------------------

    pub fn get_defined_name_list(ruby: &Ruby, rb_self: &Self) -> RArray {
        defined_names_to_ruby(ruby, rb_self.model.borrow().get_defined_name_list())
    }

    pub fn new_defined_name(
        &self,
        name: String,
        scope: Option<u32>,
        formula: String,
    ) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .new_defined_name(&name, scope, &formula)
            .map_err(workbook_error)
    }

    pub fn update_defined_name(
        &self,
        name: String,
        scope: Option<u32>,
        new_name: String,
        new_scope: Option<u32>,
        new_formula: String,
    ) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .update_defined_name(&name, scope, &new_name, new_scope, &new_formula)
            .map_err(workbook_error)
    }

    pub fn delete_defined_name(
        &self,
        name: String,
        scope: Option<u32>,
    ) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .delete_defined_name(&name, scope)
            .map_err(workbook_error)
    }

    /// Collapses the engine's error-with-reason to a boolean.
    pub fn is_valid_defined_name(&self, name: String, scope: Option<u32>, formula: String) -> bool {
        self.model
            .borrow_mut()
            .is_valid_defined_name(&name, scope, &formula)
            .is_ok()
    }

    #[allow(clippy::panic)]
    pub fn test_panic(&self) {
        panic!("This function panics for testing panic handling");
    }
}
