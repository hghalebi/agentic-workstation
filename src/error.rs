use std::{io, path::PathBuf};

use thiserror::Error;

use crate::{
    application::planner::PlanError,
    domain::{
        lockfile::LockfileError,
        module::ModuleError,
        profile::{ProfileError, ProfileNameError},
    },
};

#[derive(Debug, Error)]
pub enum AppError {
    #[error("failed to read {path}: {source}")]
    ReadFile { path: PathBuf, source: io::Error },

    #[error("failed to write output: {0}")]
    WriteOutput(#[from] io::Error),

    #[error(transparent)]
    Lockfile(#[from] LockfileError),

    #[error(transparent)]
    Module(#[from] ModuleError),

    #[error(transparent)]
    Profile(#[from] ProfileError),

    #[error(transparent)]
    ProfileName(#[from] ProfileNameError),

    #[error(transparent)]
    Plan(#[from] PlanError),

    #[error("failed to serialize plan as JSON: {0}")]
    Json(#[from] serde_json::Error),
}
