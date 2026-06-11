//! Typed planning and validation support for Agentic Workstation.
//!
//! The Bash installer remains the mutation boundary. This crate owns read-only
//! planning and policy validation so those decisions are type-checked, tested,
//! and reusable from Nix and CI.

pub mod application;
pub mod domain;
pub mod error;
pub mod interfaces;

pub use error::AppError;
