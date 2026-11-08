//! Your agents' files, the programs they run headless and the pages
//! their runs are given.

mod files;
mod headless;
mod page;

pub use files::LocalAgentDefFiles;
pub use headless::ProcessHeadlessRunner;
pub use page::HttpPageReader;
