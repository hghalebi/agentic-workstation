use std::{fs, path::PathBuf};

use thiserror::Error;

use crate::domain::{
    module::{Module, ModuleSelection, PlanReason},
    profile::{
        AutoConfig, ProfileConfig, ProfileDirectory, ProfileError, ProfileName, ProfileOverrides,
        WorkspaceHydration,
    },
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DryRunMode {
    Plan,
    DryRun,
}

impl DryRunMode {
    pub fn is_dry_run(self) -> bool {
        matches!(self, Self::DryRun)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ResumeMode {
    Fresh,
    Resume,
}

impl ResumeMode {
    fn is_resume(self) -> bool {
        matches!(self, Self::Resume)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StateDirectory(PathBuf);

impl StateDirectory {
    pub fn new(path: impl Into<PathBuf>) -> Self {
        Self(path.into())
    }

    fn installed_marker(&self, module: Module) -> PathBuf {
        self.0.join("installed").join(module.as_str())
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlanRequest {
    pub profile: ProfileName,
    pub profiles_dir: ProfileDirectory,
    pub state_dir: StateDirectory,
    pub selection: ModuleSelection,
    pub dry_run: DryRunMode,
    pub resume: ResumeMode,
    pub overrides: ProfileOverrides,
    pub workspace: WorkspaceHydration,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InstallPlan {
    pub profile: ProfileName,
    pub dry_run: DryRunMode,
    pub auto_config: AutoConfig,
    pub modules: Vec<ModulePlan>,
}

impl InstallPlan {
    pub fn requires_sudo(&self) -> bool {
        // Preserve the existing top-level JSON contract from the Bash planner.
        // Per-module `requires_sudo` remains precise for review tooling.
        true
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ModulePlan {
    pub module: Module,
    pub enabled: bool,
    pub reason: PlanReason,
}

pub fn build_install_plan(request: PlanRequest) -> Result<InstallPlan, PlanError> {
    let profile_path = request.profile.to_profile_path(&request.profiles_dir);
    let contents = fs::read_to_string(&profile_path).map_err(|source| PlanError::ReadProfile {
        path: profile_path,
        source,
    })?;

    let mut profile = ProfileConfig::parse(&contents)?;
    profile.apply_overrides(&request.overrides);

    let modules = Module::install_order()
        .iter()
        .copied()
        .map(|module| {
            let profile_enabled = profile.module_enabled(module, request.workspace);
            let reason = module_reason(
                module,
                profile_enabled,
                &request.selection,
                request.resume,
                &request.state_dir,
            );
            let enabled = matches!(reason, PlanReason::Profile);
            ModulePlan {
                module,
                enabled,
                reason,
            }
        })
        .collect();

    Ok(InstallPlan {
        profile: request.profile,
        dry_run: request.dry_run,
        auto_config: profile.auto_config(),
        modules,
    })
}

fn module_reason(
    module: Module,
    profile_enabled: bool,
    selection: &ModuleSelection,
    resume: ResumeMode,
    state_dir: &StateDirectory,
) -> PlanReason {
    if !profile_enabled {
        return PlanReason::ProfileDisabled;
    }

    if let Some(reason) = selection.reason_for_disabled_filter(module) {
        return reason;
    }

    if resume.is_resume() && state_dir.installed_marker(module).is_file() {
        return PlanReason::ResumeMarker;
    }

    PlanReason::Profile
}

#[derive(Debug, Error)]
pub enum PlanError {
    #[error("failed to read profile {path}: {source}")]
    ReadProfile {
        path: PathBuf,
        source: std::io::Error,
    },

    #[error(transparent)]
    Profile(#[from] ProfileError),
}

#[cfg(test)]
mod tests {
    use std::{fs, path::Path};

    use tempfile::tempdir;

    use crate::domain::{
        module::{ModuleFilter, ModuleSelection, parse_module_filter, parse_module_skip_set},
        profile::ProfileName,
    };

    use super::*;

    #[test]
    fn plans_profile_modules_in_installer_order() -> Result<(), Box<dyn std::error::Error>> {
        let root = tempdir()?;
        write_profile(
            root.path(),
            "coding-agent",
            r#"
INSTALL_BASE=1
INSTALL_RUNTIMES=1
INSTALL_AGENT_CLIS=1
INSTALL_BROWSER_TOOLS=1
INSTALL_ONEPASSWORD=1
AUTO_CONFIG=1
"#,
        )?;

        let plan = build_install_plan(PlanRequest {
            profile: ProfileName::new("coding-agent")?,
            profiles_dir: ProfileDirectory::new(root.path()),
            state_dir: StateDirectory::new(root.path().join("state")),
            selection: ModuleSelection::unfiltered(),
            dry_run: DryRunMode::Plan,
            resume: ResumeMode::Fresh,
            overrides: ProfileOverrides::default(),
            workspace: WorkspaceHydration::Disabled,
        })?;

        assert_eq!(plan.modules[0].module, Module::Base);
        assert!(module(&plan, Module::Base).enabled);
        assert!(module(&plan, Module::Browser).enabled);
        assert!(!module(&plan, Module::Cloud).enabled);
        assert_eq!(
            module(&plan, Module::Cloud).reason,
            PlanReason::ProfileDisabled
        );
        assert!(plan.requires_sudo());
        Ok(())
    }

    #[test]
    fn applies_only_skip_and_resume_reasons() -> Result<(), Box<dyn std::error::Error>> {
        let root = tempdir()?;
        write_profile(
            root.path(),
            "coding-agent",
            r#"
INSTALL_BASE=1
INSTALL_AGENT_CLIS=1
AUTO_CONFIG=1
"#,
        )?;
        fs::create_dir_all(root.path().join("state/installed"))?;
        fs::write(root.path().join("state/installed/base"), "")?;

        let plan = build_install_plan(PlanRequest {
            profile: ProfileName::new("coding-agent")?,
            profiles_dir: ProfileDirectory::new(root.path()),
            state_dir: StateDirectory::new(root.path().join("state")),
            selection: ModuleSelection::new(
                parse_module_filter("base,agents")?,
                parse_module_skip_set("agents")?,
            ),
            dry_run: DryRunMode::Plan,
            resume: ResumeMode::Resume,
            overrides: ProfileOverrides::default(),
            workspace: WorkspaceHydration::Disabled,
        })?;

        assert_eq!(module(&plan, Module::Base).reason, PlanReason::ResumeMarker);
        assert_eq!(module(&plan, Module::Agents).reason, PlanReason::SkipFilter);
        assert_eq!(module(&plan, Module::Config).reason, PlanReason::OnlyFilter);
        Ok(())
    }

    #[test]
    fn factory_override_enables_security_factory_module() -> Result<(), Box<dyn std::error::Error>>
    {
        let root = tempdir()?;
        write_profile(
            root.path(),
            "minimal",
            r#"
INSTALL_BASE=1
INSTALL_FACTORY_TOOLS=0
INSTALL_SECURITY_TOOLS=0
INSTALL_LOCAL_MODEL_RUNTIME=0
AUTO_CONFIG=1
"#,
        )?;

        let plan = build_install_plan(PlanRequest {
            profile: ProfileName::new("minimal")?,
            profiles_dir: ProfileDirectory::new(root.path()),
            state_dir: StateDirectory::new(root.path().join("state")),
            selection: ModuleSelection::new(ModuleFilter::All, parse_module_skip_set("")?),
            dry_run: DryRunMode::Plan,
            resume: ResumeMode::Fresh,
            overrides: ProfileOverrides::from_environment(Some("1"), None, None, None)?,
            workspace: WorkspaceHydration::Disabled,
        })?;

        assert!(module(&plan, Module::Factory).enabled);
        Ok(())
    }

    fn write_profile(
        root: &Path,
        name: &str,
        contents: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        fs::write(root.join(format!("{name}.env")), contents)?;
        Ok(())
    }

    fn module(plan: &InstallPlan, module: Module) -> &ModulePlan {
        for planned in &plan.modules {
            if planned.module == module {
                return planned;
            }
        }
        panic!("missing module {module}");
    }
}
