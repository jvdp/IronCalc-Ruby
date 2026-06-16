use std::cell::RefCell;

use magnus::value::StaticSymbol;
use magnus::{RArray, RString, Ruby};

use xlsx::base::expressions::types::Area;
use xlsx::base::UserModel as CoreUserModel;
use xlsx::export::{save_to_icalc, save_to_xlsx};

use crate::error::workbook_error;
use crate::model::cell_type_to_str;

/// The higher-level, recommended IronCalc API. Wraps [`CoreUserModel`], which
/// **auto-evaluates after every action** and records diffs for collaboration
/// (`flush_send_queue` / `apply_external_diffs`). Prefer this over the raw
/// `Model`, which requires manual `evaluate` and can be left inconsistent.
///
/// This mirrors the surface of IronCalc's WebAssembly binding (the engine's
/// canonical UserModel), so it is a superset of the Python binding's thinner
/// `UserModel`.
#[magnus::wrap(class = "IronCalc::UserModel", free_immediately, size)]
pub struct UserModel {
    pub model: RefCell<CoreUserModel<'static>>,
}

impl UserModel {
    pub fn new(model: CoreUserModel<'static>) -> Self {
        UserModel {
            model: RefCell::new(model),
        }
    }

    /// A single-cell `Area`, for the range-based engine operations below.
    fn cell_area(sheet: u32, row: i32, column: i32) -> Area {
        Area {
            sheet,
            row,
            column,
            width: 1,
            height: 1,
        }
    }

    // Persistence -----------------------------------------------------------

    pub fn save_to_xlsx(&self, file: String) -> Result<(), magnus::Error> {
        let model = self.model.borrow();
        save_to_xlsx(model.get_model(), &file).map_err(workbook_error)
    }

    pub fn save_to_icalc(&self, file: String) -> Result<(), magnus::Error> {
        let model = self.model.borrow();
        save_to_icalc(model.get_model(), &file).map_err(workbook_error)
    }

    pub fn to_bytes(ruby: &Ruby, rb_self: &Self) -> RString {
        ruby.str_from_slice(&rb_self.model.borrow().to_bytes())
    }

    // Collaboration (diff queue) --------------------------------------------

    pub fn apply_external_diffs(&self, external_diffs: RString) -> Result<(), magnus::Error> {
        let bytes = unsafe { external_diffs.as_slice() }.to_vec();
        self.model
            .borrow_mut()
            .apply_external_diffs(&bytes)
            .map_err(workbook_error)
    }

    pub fn flush_send_queue(ruby: &Ruby, rb_self: &Self) -> RString {
        let bytes = rb_self.model.borrow_mut().flush_send_queue();
        ruby.str_from_slice(&bytes)
    }

    // Evaluation / history --------------------------------------------------

    /// Usually unnecessary (the user model auto-evaluates); exposed for parity.
    pub fn evaluate(&self) {
        self.model.borrow_mut().evaluate();
    }

    pub fn undo(&self) -> Result<(), magnus::Error> {
        self.model.borrow_mut().undo().map_err(workbook_error)
    }

    pub fn redo(&self) -> Result<(), magnus::Error> {
        self.model.borrow_mut().redo().map_err(workbook_error)
    }

    pub fn can_undo(&self) -> bool {
        self.model.borrow().can_undo()
    }

    pub fn can_redo(&self) -> bool {
        self.model.borrow().can_redo()
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
            .set_user_input(sheet, row, column, &value)
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
            .range_clear_contents(&Self::cell_area(sheet, row, column))
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
            .get_cell_content(sheet, row, column)
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

    // Styles ----------------------------------------------------------------
    //
    // Reads return the full style as JSON (the Ruby layer exposes it as a Hash).
    // The user-model styling primitive is per-property (`update_range_style`,
    // mirroring the WASM binding) rather than the whole-Style setter the raw
    // `Model` exposes.

    pub fn get_cell_style_json(
        &self,
        sheet: u32,
        row: i32,
        column: i32,
    ) -> Result<String, magnus::Error> {
        let style = self
            .model
            .borrow()
            .get_cell_style(sheet, row, column)
            .map_err(workbook_error)?;
        serde_json::to_string(&style).map_err(workbook_error)
    }

    pub fn update_range_style(
        &self,
        sheet: u32,
        row: i32,
        column: i32,
        style_path: String,
        value: String,
    ) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .update_range_style(&Self::cell_area(sheet, row, column), &style_path, &value)
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
            .set_columns_width(sheet, column, column, width)
            .map_err(workbook_error)
    }

    pub fn set_row_height(&self, sheet: u32, row: i32, height: f64) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .set_rows_height(sheet, row, row, height)
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
            .set_frozen_columns_count(sheet, column_count)
            .map_err(workbook_error)
    }

    pub fn set_frozen_rows_count(&self, sheet: u32, row_count: i32) -> Result<(), magnus::Error> {
        self.model
            .borrow_mut()
            .set_frozen_rows_count(sheet, row_count)
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

    pub fn new_sheet(&self) -> Result<(), magnus::Error> {
        self.model.borrow_mut().new_sheet().map_err(workbook_error)
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
            .rename_sheet(sheet, &new_name)
            .map_err(workbook_error)
    }

    /// Returns `[min_row, max_row, min_column, max_column]` for all non-empty
    /// cells. An empty sheet returns `[1, 1, 1, 1]`.
    pub fn get_sheet_dimensions(&self, sheet: u32) -> Result<(i32, i32, i32, i32), magnus::Error> {
        let model = self.model.borrow();
        let worksheet = model
            .get_model()
            .workbook
            .worksheet(sheet)
            .map_err(workbook_error)?;
        let dimension = worksheet.dimension();
        Ok((
            dimension.min_row,
            dimension.max_row,
            dimension.min_column,
            dimension.max_column,
        ))
    }
}
