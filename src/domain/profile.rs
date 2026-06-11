use std::{fmt, path::PathBuf};

use thiserror::Error;

use crate::domain::module::Module;

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct ProfileName(String);

impl ProfileName {
    pub fn new(value: impl Into<String>) -> Result<Self, ProfileNameError> {
        let value = value.into();
        let trimmed = value.trim();

        if trimmed.is_empty() {
            return Err(ProfileNameError::Empty);
        }

        if trimmed.starts_with('.') || trimmed.contains('/') || trimmed.contains('\\') {
            return Err(ProfileNameError::UnsafePath {
                value: trimmed.to_owned(),
            });
        }

        if !trimmed
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_'))
        {
            return Err(ProfileNameError::InvalidCharacter {
                value: trimmed.to_owned(),
            });
        }

        Ok(Self(trimmed.to_owned()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }

    pub fn to_profile_path(&self, profiles_dir: &ProfileDirectory) -> PathBuf {
        profiles_dir.join(format!("{}.env", self.as_str()))
    }
}

impl fmt::Display for ProfileName {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(self.as_str())
    }
}

#[derive(Debug, Error)]
pub enum ProfileNameError {
    #[error("profile name cannot be empty")]
    Empty,

    #[error("profile name contains path traversal characters: {value}")]
    UnsafePath { value: String },

    #[error("profile name contains unsupported characters: {value}")]
    InvalidCharacter { value: String },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProfileDirectory(PathBuf);

impl ProfileDirectory {
    pub fn new(path: impl Into<PathBuf>) -> Self {
        Self(path.into())
    }

    pub fn join(&self, path: impl AsRef<std::path::Path>) -> PathBuf {
        self.0.join(path)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Flag {
    Enabled,
    Disabled,
}

impl Flag {
    pub fn from_profile_value(value: &str) -> Result<Self, ProfileError> {
        match value.trim() {
            "1" | "true" | "yes" => Ok(Self::Enabled),
            "0" | "false" | "no" => Ok(Self::Disabled),
            other => Err(ProfileError::InvalidFlagValue {
                value: other.to_owned(),
            }),
        }
    }

    pub fn is_enabled(self) -> bool {
        matches!(self, Self::Enabled)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AutoConfig {
    Enabled,
    Disabled,
}

impl AutoConfig {
    pub fn from_flag(flag: Flag) -> Self {
        match flag {
            Flag::Enabled => Self::Enabled,
            Flag::Disabled => Self::Disabled,
        }
    }

    pub fn mutates_dotfiles(self) -> bool {
        matches!(self, Self::Enabled)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WorkspaceHydration {
    Enabled,
    Disabled,
}

impl WorkspaceHydration {
    pub fn from_environment(source: Option<&str>, repo: Option<&str>) -> Self {
        if source.is_some_and(|value| !value.trim().is_empty())
            || repo.is_some_and(|value| !value.trim().is_empty())
        {
            Self::Enabled
        } else {
            Self::Disabled
        }
    }

    pub fn is_enabled(self) -> bool {
        matches!(self, Self::Enabled)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DotfilesConfig {
    Disabled,
    Enabled {
        repo: DotfilesRepo,
        target: DotfilesTarget,
        run_install: Flag,
    },
}

impl DotfilesConfig {
    pub fn is_enabled(&self) -> bool {
        matches!(self, Self::Enabled { .. })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DotfilesRepo(String);

impl DotfilesRepo {
    pub fn new(value: impl Into<String>) -> Result<Self, ProfileError> {
        let value = value.into();
        let trimmed = value.trim();
        if trimmed.is_empty() {
            return Err(ProfileError::InvalidDotfilesRepo);
        }
        Ok(Self(trimmed.to_owned()))
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DotfilesTarget(String);

impl DotfilesTarget {
    pub fn new(value: impl Into<String>) -> Result<Self, ProfileError> {
        let value = value.into();
        let trimmed = value.trim();
        if trimmed.is_empty() {
            return Err(ProfileError::InvalidDotfilesTarget);
        }
        Ok(Self(trimmed.to_owned()))
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProfileConfig {
    install_base: Flag,
    install_server_base: Flag,
    install_docker: Flag,
    install_runtimes: Flag,
    install_rust_server_tools: Flag,
    install_version_managers: Flag,
    install_git_helpers: Flag,
    install_agent_clis: Flag,
    install_browser_tools: Flag,
    install_cloud_clis: Flag,
    install_terminal_tools: Flag,
    install_factory_tools: Flag,
    install_security_tools: Flag,
    install_local_model_runtime: Flag,
    install_onepassword: Flag,
    install_harness: Flag,
    install_openclaw_layout: Flag,
    install_opentelemetry: Flag,
    install_neon_support: Flag,
    install_hetzner_s3: Flag,
    install_onepassword_ssh: Flag,
    auto_config: AutoConfig,
    dotfiles: DotfilesConfig,
}

impl ProfileConfig {
    pub fn parse(contents: &str) -> Result<Self, ProfileError> {
        let mut builder = ProfileConfigBuilder::default();

        for (index, raw_line) in contents.lines().enumerate() {
            let line = raw_line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }

            let Some((key, value)) = line.split_once('=') else {
                return Err(ProfileError::InvalidAssignment {
                    line: index + 1,
                    value: raw_line.to_owned(),
                });
            };

            builder.apply_assignment(key.trim(), strip_profile_quotes(value.trim()))?;
        }

        builder.build()
    }

    pub fn apply_overrides(&mut self, overrides: &ProfileOverrides) {
        if overrides.include_factory_tools.is_enabled() {
            self.install_factory_tools = Flag::Enabled;
            self.install_security_tools = Flag::Enabled;
        }

        if overrides.include_local_model_runtime.is_enabled() {
            self.install_factory_tools = Flag::Enabled;
            self.install_local_model_runtime = Flag::Enabled;
        }

        if overrides.skip_browser_tools.is_enabled() {
            self.install_browser_tools = Flag::Disabled;
        }

        if overrides.skip_auto_config.is_enabled() {
            self.auto_config = AutoConfig::Disabled;
        }
    }

    pub fn auto_config(&self) -> AutoConfig {
        self.auto_config
    }

    pub fn module_enabled(&self, module: Module, workspace: WorkspaceHydration) -> bool {
        match module {
            Module::Base => self.install_base.is_enabled(),
            Module::ServerBase => self.install_server_base.is_enabled(),
            Module::Docker => self.install_docker.is_enabled(),
            Module::Runtimes => self.install_runtimes.is_enabled(),
            Module::RustServerTools => self.install_rust_server_tools.is_enabled(),
            Module::VersionManagers => self.install_version_managers.is_enabled(),
            Module::GitHelpers => self.install_git_helpers.is_enabled(),
            Module::Agents => self.install_agent_clis.is_enabled(),
            Module::Browser => self.install_browser_tools.is_enabled(),
            Module::Cloud => self.install_cloud_clis.is_enabled(),
            Module::Terminal => self.install_terminal_tools.is_enabled(),
            Module::Factory => {
                self.install_factory_tools.is_enabled()
                    || self.install_security_tools.is_enabled()
                    || self.install_local_model_runtime.is_enabled()
            }
            Module::OnePassword => self.install_onepassword.is_enabled(),
            Module::Harness => self.install_harness.is_enabled(),
            Module::OpenClawLayout => self.install_openclaw_layout.is_enabled(),
            Module::OpenTelemetry => self.install_opentelemetry.is_enabled(),
            Module::Neon => self.install_neon_support.is_enabled(),
            Module::HetznerS3 => self.install_hetzner_s3.is_enabled(),
            Module::OnePasswordSsh => self.install_onepassword_ssh.is_enabled(),
            Module::Dotfiles => self.dotfiles.is_enabled(),
            Module::Workspace => workspace.is_enabled(),
            Module::Config => self.auto_config.mutates_dotfiles(),
            Module::Manifest => true,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProfileOverrides {
    include_factory_tools: Flag,
    include_local_model_runtime: Flag,
    skip_browser_tools: Flag,
    skip_auto_config: Flag,
}

impl ProfileOverrides {
    pub fn from_environment(
        include_factory_tools: Option<&str>,
        include_local_model_runtime: Option<&str>,
        skip_browser_tools: Option<&str>,
        skip_auto_config: Option<&str>,
    ) -> Result<Self, ProfileError> {
        Ok(Self {
            include_factory_tools: parse_optional_flag(include_factory_tools)?,
            include_local_model_runtime: parse_optional_flag(include_local_model_runtime)?,
            skip_browser_tools: parse_optional_flag(skip_browser_tools)?,
            skip_auto_config: parse_optional_flag(skip_auto_config)?,
        })
    }
}

impl Default for ProfileOverrides {
    fn default() -> Self {
        Self {
            include_factory_tools: Flag::Disabled,
            include_local_model_runtime: Flag::Disabled,
            skip_browser_tools: Flag::Disabled,
            skip_auto_config: Flag::Disabled,
        }
    }
}

#[derive(Debug)]
struct ProfileConfigBuilder {
    install_base: Flag,
    install_server_base: Flag,
    install_docker: Flag,
    install_runtimes: Flag,
    install_rust_server_tools: Flag,
    install_version_managers: Flag,
    install_git_helpers: Flag,
    install_agent_clis: Flag,
    install_browser_tools: Flag,
    install_cloud_clis: Flag,
    install_terminal_tools: Flag,
    install_factory_tools: Flag,
    install_security_tools: Flag,
    install_local_model_runtime: Flag,
    install_onepassword: Flag,
    install_harness: Flag,
    install_openclaw_layout: Flag,
    install_opentelemetry: Flag,
    install_neon_support: Flag,
    install_hetzner_s3: Flag,
    install_onepassword_ssh: Flag,
    auto_config: AutoConfig,
    dotfiles_repo: Option<DotfilesRepo>,
    dotfiles_target: Option<DotfilesTarget>,
    dotfiles_run_install: Flag,
}

impl Default for ProfileConfigBuilder {
    fn default() -> Self {
        Self {
            install_base: Flag::Disabled,
            install_server_base: Flag::Disabled,
            install_docker: Flag::Disabled,
            install_runtimes: Flag::Disabled,
            install_rust_server_tools: Flag::Disabled,
            install_version_managers: Flag::Disabled,
            install_git_helpers: Flag::Disabled,
            install_agent_clis: Flag::Disabled,
            install_browser_tools: Flag::Disabled,
            install_cloud_clis: Flag::Disabled,
            install_terminal_tools: Flag::Disabled,
            install_factory_tools: Flag::Disabled,
            install_security_tools: Flag::Disabled,
            install_local_model_runtime: Flag::Disabled,
            install_onepassword: Flag::Disabled,
            install_harness: Flag::Disabled,
            install_openclaw_layout: Flag::Disabled,
            install_opentelemetry: Flag::Disabled,
            install_neon_support: Flag::Disabled,
            install_hetzner_s3: Flag::Disabled,
            install_onepassword_ssh: Flag::Disabled,
            auto_config: AutoConfig::Enabled,
            dotfiles_repo: None,
            dotfiles_target: None,
            dotfiles_run_install: Flag::Disabled,
        }
    }
}

impl ProfileConfigBuilder {
    fn apply_assignment(&mut self, key: &str, value: &str) -> Result<(), ProfileError> {
        match key {
            "INSTALL_BASE" => self.install_base = Flag::from_profile_value(value)?,
            "INSTALL_SERVER_BASE" => self.install_server_base = Flag::from_profile_value(value)?,
            "INSTALL_DOCKER" => self.install_docker = Flag::from_profile_value(value)?,
            "INSTALL_RUNTIMES" => self.install_runtimes = Flag::from_profile_value(value)?,
            "INSTALL_RUST_SERVER_TOOLS" => {
                self.install_rust_server_tools = Flag::from_profile_value(value)?;
            }
            "INSTALL_VERSION_MANAGERS" => {
                self.install_version_managers = Flag::from_profile_value(value)?;
            }
            "INSTALL_GIT_HELPERS" => self.install_git_helpers = Flag::from_profile_value(value)?,
            "INSTALL_AGENT_CLIS" => self.install_agent_clis = Flag::from_profile_value(value)?,
            "INSTALL_BROWSER_TOOLS" => {
                self.install_browser_tools = Flag::from_profile_value(value)?
            }
            "INSTALL_CLOUD_CLIS" => self.install_cloud_clis = Flag::from_profile_value(value)?,
            "INSTALL_TERMINAL_TOOLS" => {
                self.install_terminal_tools = Flag::from_profile_value(value)?
            }
            "INSTALL_FACTORY_TOOLS" => {
                self.install_factory_tools = Flag::from_profile_value(value)?
            }
            "INSTALL_SECURITY_TOOLS" => {
                self.install_security_tools = Flag::from_profile_value(value)?
            }
            "INSTALL_LOCAL_MODEL_RUNTIME" => {
                self.install_local_model_runtime = Flag::from_profile_value(value)?;
            }
            "INSTALL_ONEPASSWORD" => self.install_onepassword = Flag::from_profile_value(value)?,
            "INSTALL_HARNESS" => self.install_harness = Flag::from_profile_value(value)?,
            "INSTALL_OPENCLAW_LAYOUT" => {
                self.install_openclaw_layout = Flag::from_profile_value(value)?;
            }
            "INSTALL_OPENTELEMETRY" => {
                self.install_opentelemetry = Flag::from_profile_value(value)?
            }
            "INSTALL_NEON_SUPPORT" => self.install_neon_support = Flag::from_profile_value(value)?,
            "INSTALL_HETZNER_S3" => self.install_hetzner_s3 = Flag::from_profile_value(value)?,
            "INSTALL_ONEPASSWORD_SSH" => {
                self.install_onepassword_ssh = Flag::from_profile_value(value)?
            }
            "AUTO_CONFIG" => {
                self.auto_config = AutoConfig::from_flag(Flag::from_profile_value(value)?)
            }
            "DOTFILES_REPO" => self.dotfiles_repo = Some(DotfilesRepo::new(value)?),
            "DOTFILES_TARGET" => self.dotfiles_target = Some(DotfilesTarget::new(value)?),
            "DOTFILES_RUN_INSTALL" => self.dotfiles_run_install = Flag::from_profile_value(value)?,
            _ => {}
        }

        Ok(())
    }

    fn build(self) -> Result<ProfileConfig, ProfileError> {
        let dotfiles = match self.dotfiles_repo {
            Some(repo) => DotfilesConfig::Enabled {
                repo,
                target: self
                    .dotfiles_target
                    .unwrap_or_else(|| DotfilesTarget("${HOME}/.dotfiles".to_owned())),
                run_install: self.dotfiles_run_install,
            },
            None => DotfilesConfig::Disabled,
        };

        Ok(ProfileConfig {
            install_base: self.install_base,
            install_server_base: self.install_server_base,
            install_docker: self.install_docker,
            install_runtimes: self.install_runtimes,
            install_rust_server_tools: self.install_rust_server_tools,
            install_version_managers: self.install_version_managers,
            install_git_helpers: self.install_git_helpers,
            install_agent_clis: self.install_agent_clis,
            install_browser_tools: self.install_browser_tools,
            install_cloud_clis: self.install_cloud_clis,
            install_terminal_tools: self.install_terminal_tools,
            install_factory_tools: self.install_factory_tools,
            install_security_tools: self.install_security_tools,
            install_local_model_runtime: self.install_local_model_runtime,
            install_onepassword: self.install_onepassword,
            install_harness: self.install_harness,
            install_openclaw_layout: self.install_openclaw_layout,
            install_opentelemetry: self.install_opentelemetry,
            install_neon_support: self.install_neon_support,
            install_hetzner_s3: self.install_hetzner_s3,
            install_onepassword_ssh: self.install_onepassword_ssh,
            auto_config: self.auto_config,
            dotfiles,
        })
    }
}

fn parse_optional_flag(value: Option<&str>) -> Result<Flag, ProfileError> {
    match value {
        Some(value) if value.trim().is_empty() => Ok(Flag::Disabled),
        Some(value) => Flag::from_profile_value(value),
        None => Ok(Flag::Disabled),
    }
}

fn strip_profile_quotes(value: &str) -> &str {
    value
        .strip_prefix('"')
        .and_then(|without_prefix| without_prefix.strip_suffix('"'))
        .or_else(|| {
            value
                .strip_prefix('\'')
                .and_then(|without_prefix| without_prefix.strip_suffix('\''))
        })
        .unwrap_or(value)
}

#[derive(Debug, Error)]
pub enum ProfileError {
    #[error("invalid profile assignment at line {line}: {value}")]
    InvalidAssignment { line: usize, value: String },

    #[error("profile flag value must be 0/1/true/false/yes/no, got {value}")]
    InvalidFlagValue { value: String },

    #[error("DOTFILES_REPO cannot be empty when present")]
    InvalidDotfilesRepo,

    #[error("DOTFILES_TARGET cannot be empty when present")]
    InvalidDotfilesTarget,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_openclaw_dotfiles_as_enabled() -> Result<(), ProfileError> {
        let profile = ProfileConfig::parse(
            r#"
INSTALL_BASE=1
INSTALL_OPENCLAW_LAYOUT=1
AUTO_CONFIG=1
DOTFILES_REPO=https://github.com/hghalebi/dotfiles
DOTFILES_TARGET=/root/.dotfiles
DOTFILES_RUN_INSTALL=0
"#,
        )?;

        assert!(profile.module_enabled(Module::Base, WorkspaceHydration::Disabled));
        assert!(profile.module_enabled(Module::OpenClawLayout, WorkspaceHydration::Disabled));
        assert!(profile.module_enabled(Module::Dotfiles, WorkspaceHydration::Disabled));
        assert!(profile.module_enabled(Module::Config, WorkspaceHydration::Disabled));
        Ok(())
    }

    #[test]
    fn rejects_path_like_profile_names() {
        assert!(ProfileName::new("../prod").is_err());
        assert!(ProfileName::new(".hidden").is_err());
    }
}
