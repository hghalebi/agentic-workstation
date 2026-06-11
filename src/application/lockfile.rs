use std::path::Path;

use crate::domain::lockfile::{LockfileError, ToolLockfile};

pub fn verify_lockfile(path: impl AsRef<Path>) -> Result<ToolLockfile, LockfileError> {
    ToolLockfile::from_path(path)
}
