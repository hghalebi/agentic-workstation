use std::{collections::BTreeSet, fmt, str::FromStr};

use serde::{Serialize, Serializer};
use thiserror::Error;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum Module {
    Base,
    ServerBase,
    Docker,
    Runtimes,
    RustServerTools,
    VersionManagers,
    GitHelpers,
    Agents,
    Browser,
    Cloud,
    Terminal,
    Factory,
    OnePassword,
    Harness,
    OpenClawLayout,
    OpenTelemetry,
    Neon,
    HetznerS3,
    OnePasswordSsh,
    Dotfiles,
    Workspace,
    Config,
    Manifest,
}

impl Module {
    pub fn install_order() -> &'static [Self] {
        &[
            Self::Base,
            Self::ServerBase,
            Self::Docker,
            Self::Runtimes,
            Self::RustServerTools,
            Self::VersionManagers,
            Self::GitHelpers,
            Self::Agents,
            Self::Browser,
            Self::Cloud,
            Self::Terminal,
            Self::Factory,
            Self::OnePassword,
            Self::Harness,
            Self::OpenClawLayout,
            Self::OpenTelemetry,
            Self::Neon,
            Self::HetznerS3,
            Self::OnePasswordSsh,
            Self::Dotfiles,
            Self::Workspace,
            Self::Config,
            Self::Manifest,
        ]
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Self::Base => "base",
            Self::ServerBase => "server-base",
            Self::Docker => "docker",
            Self::Runtimes => "runtimes",
            Self::RustServerTools => "rust-server-tools",
            Self::VersionManagers => "version-managers",
            Self::GitHelpers => "git-helpers",
            Self::Agents => "agents",
            Self::Browser => "browser",
            Self::Cloud => "cloud",
            Self::Terminal => "terminal",
            Self::Factory => "factory",
            Self::OnePassword => "onepassword",
            Self::Harness => "harness",
            Self::OpenClawLayout => "openclaw-layout",
            Self::OpenTelemetry => "opentelemetry",
            Self::Neon => "neon",
            Self::HetznerS3 => "hetzner-s3",
            Self::OnePasswordSsh => "onepassword-ssh",
            Self::Dotfiles => "dotfiles",
            Self::Workspace => "workspace",
            Self::Config => "config",
            Self::Manifest => "manifest",
        }
    }

    pub fn description(self) -> &'static str {
        match self {
            Self::Base => "Core Ubuntu CLI and debugging tools",
            Self::ServerBase => {
                "Server firewall, web, updates, intrusion prevention, and journal limits"
            }
            Self::Docker => "Docker Engine from the official Docker apt repository",
            Self::Runtimes => "Rust and uv runtime tooling",
            Self::RustServerTools => "Rust server development tools",
            Self::VersionManagers => "mise and aqua tool version managers",
            Self::GitHelpers => "YAML and Git diff helpers",
            Self::Agents => "Agent and model CLIs",
            Self::Browser => "Playwright browser binaries",
            Self::Cloud => "Cloud and database CLIs",
            Self::Terminal => "Terminal workspace tools",
            Self::Factory => "Factory, security, artifact, tracing, and model helper tools",
            Self::OnePassword => "1Password CLI",
            Self::Harness => "Harness CLI",
            Self::OpenClawLayout => "OpenClaw server directory layout",
            Self::OpenTelemetry => "OpenTelemetry Collector Docker Compose stack",
            Self::Neon => "Neon Postgres client support and env validation template",
            Self::HetznerS3 => "Hetzner S3 awscli support and bucket validation helper",
            Self::OnePasswordSsh => "1Password SSH public-key export and SSH client helper",
            Self::Dotfiles => "Optional dotfiles clone and install hook",
            Self::Workspace => "Workspace copy and Git hydration",
            Self::Config => "Shell, Git, and hook auto-configuration",
            Self::Manifest => "Install manifest generation",
        }
    }

    pub fn requires_sudo(self) -> ModulePrivilege {
        match self {
            Self::Runtimes | Self::RustServerTools => ModulePrivilege::User,
            Self::Base
            | Self::ServerBase
            | Self::Docker
            | Self::VersionManagers
            | Self::GitHelpers
            | Self::Agents
            | Self::Browser
            | Self::Cloud
            | Self::Terminal
            | Self::Factory
            | Self::OnePassword
            | Self::Harness
            | Self::OpenClawLayout
            | Self::OpenTelemetry
            | Self::Neon
            | Self::HetznerS3
            | Self::OnePasswordSsh
            | Self::Dotfiles
            | Self::Workspace
            | Self::Config
            | Self::Manifest => ModulePrivilege::Sudo,
        }
    }
}

impl fmt::Display for Module {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(self.as_str())
    }
}

impl Serialize for Module {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(self.as_str())
    }
}

impl FromStr for Module {
    type Err = ModuleError;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value {
            "base" => Ok(Self::Base),
            "server-base" => Ok(Self::ServerBase),
            "docker" => Ok(Self::Docker),
            "runtimes" => Ok(Self::Runtimes),
            "rust-server-tools" => Ok(Self::RustServerTools),
            "version-managers" => Ok(Self::VersionManagers),
            "git-helpers" => Ok(Self::GitHelpers),
            "agents" => Ok(Self::Agents),
            "browser" => Ok(Self::Browser),
            "cloud" => Ok(Self::Cloud),
            "terminal" => Ok(Self::Terminal),
            "factory" => Ok(Self::Factory),
            "onepassword" => Ok(Self::OnePassword),
            "harness" => Ok(Self::Harness),
            "openclaw-layout" => Ok(Self::OpenClawLayout),
            "opentelemetry" => Ok(Self::OpenTelemetry),
            "neon" => Ok(Self::Neon),
            "hetzner-s3" => Ok(Self::HetznerS3),
            "onepassword-ssh" => Ok(Self::OnePasswordSsh),
            "dotfiles" => Ok(Self::Dotfiles),
            "workspace" => Ok(Self::Workspace),
            "config" => Ok(Self::Config),
            "manifest" => Ok(Self::Manifest),
            _ => Err(ModuleError::UnknownModule {
                name: value.to_owned(),
            }),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ModulePrivilege {
    Sudo,
    User,
}

impl ModulePrivilege {
    pub fn requires_sudo(self) -> bool {
        matches!(self, Self::Sudo)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ModuleFilter {
    All,
    Only(BTreeSet<Module>),
}

impl ModuleFilter {
    pub fn allows(&self, module: Module) -> bool {
        match self {
            Self::All => true,
            Self::Only(modules) => modules.contains(&module),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ModuleSkipSet(BTreeSet<Module>);

impl ModuleSkipSet {
    pub fn empty() -> Self {
        Self(BTreeSet::new())
    }

    pub fn contains(&self, module: Module) -> bool {
        self.0.contains(&module)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ModuleSelection {
    only: ModuleFilter,
    skip: ModuleSkipSet,
}

impl ModuleSelection {
    pub fn new(only: ModuleFilter, skip: ModuleSkipSet) -> Self {
        Self { only, skip }
    }

    pub fn unfiltered() -> Self {
        Self {
            only: ModuleFilter::All,
            skip: ModuleSkipSet::empty(),
        }
    }

    pub fn allows(&self, module: Module) -> bool {
        self.only.allows(module) && !self.skip.contains(module)
    }

    pub fn reason_for_disabled_filter(&self, module: Module) -> Option<PlanReason> {
        if !self.only.allows(module) {
            Some(PlanReason::OnlyFilter)
        } else if self.skip.contains(module) {
            Some(PlanReason::SkipFilter)
        } else {
            None
        }
    }
}

pub fn parse_module_filter(value: &str) -> Result<ModuleFilter, ModuleError> {
    let modules = parse_module_set(value)?;
    if modules.is_empty() {
        Ok(ModuleFilter::All)
    } else {
        Ok(ModuleFilter::Only(modules))
    }
}

pub fn parse_module_skip_set(value: &str) -> Result<ModuleSkipSet, ModuleError> {
    Ok(ModuleSkipSet(parse_module_set(value)?))
}

fn parse_module_set(value: &str) -> Result<BTreeSet<Module>, ModuleError> {
    let mut modules = BTreeSet::new();
    for raw in value.split(',') {
        let trimmed = raw.trim();
        if trimmed.is_empty() {
            continue;
        }
        modules.insert(trimmed.parse()?);
    }
    Ok(modules)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "kebab-case")]
pub enum PlanReason {
    Profile,
    ProfileDisabled,
    OnlyFilter,
    SkipFilter,
    ResumeMarker,
}

impl PlanReason {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Profile => "profile",
            Self::ProfileDisabled => "profile-disabled",
            Self::OnlyFilter => "only-filter",
            Self::SkipFilter => "skip-filter",
            Self::ResumeMarker => "resume-marker",
        }
    }
}

impl fmt::Display for PlanReason {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(self.as_str())
    }
}

#[derive(Debug, Error)]
pub enum ModuleError {
    #[error("unknown module: {name}")]
    UnknownModule { name: String },
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_comma_separated_filters() -> Result<(), ModuleError> {
        let filter = parse_module_filter("base, agents")?;

        assert!(filter.allows(Module::Base));
        assert!(filter.allows(Module::Agents));
        assert!(!filter.allows(Module::Cloud));
        Ok(())
    }
}
