use std::cell::RefCell;

use magnus::{RArray, RString, Ruby};

use xlsx::base::types::Style;
use xlsx::base::Model as CoreModel;
use xlsx::export::{save_to_icalc, save_to_xlsx};

use crate::error::workbook_error;

/// Maps an engine `CellType` to a snake_case string, mirroring the names of the
/// Python binding's `CellType` enum variants.
fn cell_type_to_str(cell_type: xlsx::base::types::CellType) -> &'static str {
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

/// The raw IronCalc API. Wraps [`CoreModel`]; you must call `evaluate` yourself
/// after setting inputs.
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
            .cell_clear_contents(sheet, row, column)
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
        &self,
        sheet: u32,
        row: i32,
        column: i32,
    ) -> Result<String, magnus::Error> {
        self.model
            .borrow()
            .get_cell_type(sheet, row, column)
            .map(|t| cell_type_to_str(t).to_string())
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
            let _ = hash.aset(ruby.sym_new("color"), sheet.color);
            let _ = array.push(hash);
        }
        array
    }

    pub fn set_sheet_color(&self, sheet: u32, color: String) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .set_sheet_color(sheet, &color)
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

    /// Returns `[min_row, max_row, min_column, max_column]` for all non-empty
    /// cells. An empty sheet returns `[1, 1, 1, 1]`.
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

    #[allow(clippy::panic)]
    pub fn test_panic(&self) {
        panic!("This function panics for testing panic handling");
    }
}
