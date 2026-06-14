use std::cell::RefCell;

use magnus::{RString, Ruby};

use xlsx::base::UserModel as CoreUserModel;
use xlsx::export::{save_to_icalc, save_to_xlsx};

use crate::error::workbook_error;

/// The higher-level IronCalc API. Wraps [`CoreUserModel`], which auto-evaluates
/// and records diffs for collaboration (`flush_send_queue` /
/// `apply_external_diffs`).
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

    pub fn save_to_xlsx(&self, file: String) -> Result<(), magnus::Error> {
        let model = self.model.borrow();
        save_to_xlsx(model.get_model(), &file).map_err(workbook_error)
    }

    pub fn save_to_icalc(&self, file: String) -> Result<(), magnus::Error> {
        let model = self.model.borrow();
        save_to_icalc(model.get_model(), &file).map_err(workbook_error)
    }

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

    pub fn to_bytes(ruby: &Ruby, rb_self: &Self) -> RString {
        ruby.str_from_slice(&rb_self.model.borrow().to_bytes())
    }
}
