use magnus::value::Lazy;
use magnus::{Error, ExceptionClass, Module, Ruby};

/// `IronCalc::Error` — the single exception class raised by this binding,
/// mirroring the Python binding's `WorkbookError`.
pub static IRONCALC_ERROR: Lazy<ExceptionClass> = Lazy::new(|ruby| {
    let module = ruby.define_module("IronCalc").unwrap();
    module
        .define_error("Error", ruby.exception_standard_error())
        .unwrap()
});

/// Converts any engine error into an `IronCalc::Error` Ruby exception.
pub fn workbook_error<E: ToString>(e: E) -> Error {
    let ruby = Ruby::get().expect("called outside of a Ruby thread");
    Error::new(ruby.get_inner(&IRONCALC_ERROR), e.to_string())
}
