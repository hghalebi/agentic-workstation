use std::{collections::BTreeMap, fs, path::Path};

use serde::Deserialize;
use thiserror::Error;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ToolLockfile {
    remote_installers: Vec<RemoteInstallerUrl>,
}

impl ToolLockfile {
    pub fn from_path(path: impl AsRef<Path>) -> Result<Self, LockfileError> {
        let path = path.as_ref();
        let contents = fs::read_to_string(path).map_err(|source| LockfileError::Read {
            path: path.to_path_buf(),
            source,
        })?;
        Self::parse(&contents)
    }

    pub fn parse(contents: &str) -> Result<Self, LockfileError> {
        let raw: RawToolLockfile =
            serde_yaml::from_str(contents).map_err(|source| LockfileError::Parse { source })?;

        if raw.schema != 1 {
            return Err(LockfileError::UnsupportedSchema { schema: raw.schema });
        }

        validate_tool_section("npm", &raw.npm)?;
        validate_tool_section("uv", &raw.uv)?;
        validate_tool_section("pip", &raw.pip)?;
        validate_tool_section("go", &raw.go)?;
        validate_tool_section("cargo", &raw.cargo)?;
        validate_tool_section("github_releases", &raw.github_releases)?;

        let mut remote_installers = Vec::new();
        for (name, installer) in raw.remote_installers {
            let url = RemoteInstallerUrl::new(installer.url)
                .map_err(|source| LockfileError::InvalidRemoteInstaller { name, source })?;
            remote_installers.push(url);
        }

        Ok(Self { remote_installers })
    }

    pub fn remote_installers(&self) -> &[RemoteInstallerUrl] {
        &self.remote_installers
    }
}

#[derive(Debug, Deserialize)]
struct RawToolLockfile {
    schema: u32,
    #[serde(default)]
    npm: BTreeMap<String, String>,
    #[serde(default)]
    uv: BTreeMap<String, String>,
    #[serde(default)]
    pip: BTreeMap<String, String>,
    #[serde(default)]
    go: BTreeMap<String, String>,
    #[serde(default)]
    cargo: BTreeMap<String, String>,
    #[serde(default)]
    github_releases: BTreeMap<String, String>,
    #[serde(default)]
    remote_installers: BTreeMap<String, RawRemoteInstaller>,
}

#[derive(Debug, Deserialize)]
struct RawRemoteInstaller {
    url: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RemoteInstallerUrl(String);

impl RemoteInstallerUrl {
    fn new(value: impl Into<String>) -> Result<Self, RemoteInstallerUrlError> {
        let value = value.into();
        let trimmed = value.trim();

        if !(trimmed.starts_with("https://") || trimmed.starts_with("http://")) {
            return Err(RemoteInstallerUrlError::UnsupportedScheme {
                value: trimmed.to_owned(),
            });
        }

        Ok(Self(trimmed.to_owned()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[derive(Debug, Error)]
pub enum RemoteInstallerUrlError {
    #[error("remote installer URL must be http(s), got {value}")]
    UnsupportedScheme { value: String },
}

fn validate_tool_section(
    section: &'static str,
    tools: &BTreeMap<String, String>,
) -> Result<(), LockfileError> {
    for (name, version) in tools {
        ToolName::new(name).map_err(|source| LockfileError::InvalidToolName {
            section,
            name: name.clone(),
            source,
        })?;
        PinnedVersion::new(version).map_err(|source| LockfileError::InvalidPinnedVersion {
            section,
            name: name.clone(),
            source,
        })?;
    }

    Ok(())
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct ToolName(String);

impl ToolName {
    fn new(value: impl Into<String>) -> Result<Self, ToolNameError> {
        let value = value.into();
        let trimmed = value.trim();

        if trimmed.is_empty() {
            return Err(ToolNameError::Empty);
        }

        Ok(Self(trimmed.to_owned()))
    }
}

#[derive(Debug, Error)]
pub enum ToolNameError {
    #[error("tool name cannot be empty")]
    Empty,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct PinnedVersion(String);

impl PinnedVersion {
    fn new(value: impl Into<String>) -> Result<Self, PinnedVersionError> {
        let value = value.into();
        let trimmed = value.trim();

        if trimmed.is_empty() {
            return Err(PinnedVersionError::Empty);
        }

        if trimmed.contains("<pinned-version>")
            || trimmed.contains("TODO")
            || trimmed.contains("FIXME")
        {
            return Err(PinnedVersionError::Placeholder {
                value: trimmed.to_owned(),
            });
        }

        if trimmed == "latest" || trimmed.ends_with("@latest") {
            return Err(PinnedVersionError::MovingTarget {
                value: trimmed.to_owned(),
            });
        }

        Ok(Self(trimmed.to_owned()))
    }
}

#[derive(Debug, Error)]
pub enum PinnedVersionError {
    #[error("pinned version cannot be empty")]
    Empty,

    #[error("pinned version contains a placeholder: {value}")]
    Placeholder { value: String },

    #[error("pinned version cannot be a moving latest target: {value}")]
    MovingTarget { value: String },
}

#[derive(Debug, Error)]
pub enum LockfileError {
    #[error("failed to read lockfile {path}: {source}")]
    Read {
        path: std::path::PathBuf,
        source: std::io::Error,
    },

    #[error("failed to parse lockfile YAML: {source}")]
    Parse { source: serde_yaml::Error },

    #[error("unsupported lockfile schema {schema}")]
    UnsupportedSchema { schema: u32 },

    #[error("invalid tool name in {section}.{name}: {source}")]
    InvalidToolName {
        section: &'static str,
        name: String,
        source: ToolNameError,
    },

    #[error("invalid pinned version in {section}.{name}: {source}")]
    InvalidPinnedVersion {
        section: &'static str,
        name: String,
        source: PinnedVersionError,
    },

    #[error("invalid remote installer {name}: {source}")]
    InvalidRemoteInstaller {
        name: String,
        source: RemoteInstallerUrlError,
    },
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_current_lockfile_shape() -> Result<(), LockfileError> {
        let lockfile = ToolLockfile::parse(
            r#"
schema: 1
npm:
  "@openai/codex": "0.18.0"
uv:
  aider-chat: "0.84.0"
go:
  github.com/mikefarah/yq/v4: "v4.45.4"
cargo:
  zellij: "0.42.2"
remote_installers:
  rustup:
    url: https://sh.rustup.rs
"#,
        )?;

        assert_eq!(
            lockfile.remote_installers()[0].as_str(),
            "https://sh.rustup.rs"
        );
        Ok(())
    }

    #[test]
    fn rejects_moving_targets() {
        let error = ToolLockfile::parse(
            r#"
schema: 1
npm:
  openclaw: latest
"#,
        );

        assert!(matches!(
            error,
            Err(LockfileError::InvalidPinnedVersion { .. })
        ));
    }
}
