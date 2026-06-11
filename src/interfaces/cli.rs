use std::{
    env,
    io::{self, Write},
    path::PathBuf,
};

use clap::{Args, Parser, Subcommand};
use serde::Serialize;

use crate::{
    AppError,
    application::{
        lockfile::verify_lockfile,
        planner::{DryRunMode, PlanRequest, ResumeMode, StateDirectory, build_install_plan},
    },
    domain::{
        lockfile::ToolLockfile,
        module::{Module, ModuleSelection, parse_module_filter, parse_module_skip_set},
        profile::{
            AutoConfig, ProfileDirectory, ProfileName, ProfileOverrides, WorkspaceHydration,
        },
    },
};

#[derive(Debug, Parser)]
#[command(name = "agentic-workstation")]
#[command(about = "Typed Agentic Workstation planning and validation CLI")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Validate agentic-tools.lock.yaml.
    VerifyLockfile(VerifyLockfileArgs),

    /// Render the read-only install plan for a profile.
    Plan(PlanArgs),
}

#[derive(Debug, Args)]
struct VerifyLockfileArgs {
    #[arg(default_value = "agentic-tools.lock.yaml")]
    lockfile: PathBuf,
}

#[derive(Debug, Args)]
struct PlanArgs {
    #[arg(long, default_value = "coding-agent")]
    profile: String,

    #[arg(long, default_value = "profiles")]
    profiles_dir: PathBuf,

    #[arg(long, default_value = "/var/lib/agentic-workstation")]
    state_dir: PathBuf,

    #[arg(long)]
    only: Option<String>,

    #[arg(long)]
    skip: Option<String>,

    #[arg(long)]
    resume: bool,

    #[arg(long)]
    dry_run: bool,

    #[arg(long)]
    json: bool,

    #[arg(long, default_value = "agentic-tools.lock.yaml")]
    lockfile: PathBuf,
}

pub fn run() -> Result<(), AppError> {
    let cli = Cli::parse();

    match cli.command {
        Command::VerifyLockfile(args) => run_verify_lockfile(args),
        Command::Plan(args) => run_plan(args),
    }
}

fn run_verify_lockfile(args: VerifyLockfileArgs) -> Result<(), AppError> {
    verify_lockfile(&args.lockfile)?;
    println!("lockfile verified: {}", args.lockfile.display());
    Ok(())
}

fn run_plan(args: PlanArgs) -> Result<(), AppError> {
    let lockfile = verify_lockfile(&args.lockfile)?;
    let profile = ProfileName::new(args.profile)?;
    let only = match args.only {
        Some(value) => parse_module_filter(&value)?,
        None => parse_module_filter("")?,
    };
    let skip = match args.skip {
        Some(value) => parse_module_skip_set(&value)?,
        None => parse_module_skip_set("")?,
    };
    let selection = ModuleSelection::new(only, skip);
    let overrides = ProfileOverrides::from_environment(
        env::var("INCLUDE_FACTORY_TOOLS").ok().as_deref(),
        env::var("INCLUDE_LOCAL_MODEL_RUNTIME").ok().as_deref(),
        env::var("SKIP_BROWSER_TOOLS").ok().as_deref(),
        env::var("SKIP_AUTO_CONFIG").ok().as_deref(),
    )?;
    let workspace = WorkspaceHydration::from_environment(
        env::var("WORKSPACE_SOURCE").ok().as_deref(),
        env::var("WORKSPACE_REPO").ok().as_deref(),
    );

    let plan = build_install_plan(PlanRequest {
        profile,
        profiles_dir: ProfileDirectory::new(args.profiles_dir),
        state_dir: StateDirectory::new(args.state_dir),
        selection,
        dry_run: if args.dry_run {
            DryRunMode::DryRun
        } else {
            DryRunMode::Plan
        },
        resume: if args.resume {
            ResumeMode::Resume
        } else {
            ResumeMode::Fresh
        },
        overrides,
        workspace,
    })?;

    if args.json {
        let output = PlanOutput::from_plan(&plan, &lockfile);
        let stdout = io::stdout();
        let mut handle = stdout.lock();
        serde_json::to_writer_pretty(&mut handle, &output)?;
        writeln!(handle)?;
    } else {
        write_human_plan(&plan)?;
    }

    Ok(())
}

fn write_human_plan(plan: &crate::application::planner::InstallPlan) -> Result<(), AppError> {
    println!("Agentic Workstation install plan");
    println!("profile: {}", plan.profile);
    println!("dry_run: {}", plan.dry_run.is_dry_run());
    println!(
        "mutates_dotfiles: {}",
        if plan.auto_config.mutates_dotfiles() {
            "yes"
        } else {
            "no"
        }
    );
    println!(
        "requires_sudo: {}",
        if plan.requires_sudo() { "yes" } else { "no" }
    );
    println!();
    println!("Modules:");

    for module in &plan.modules {
        println!(
            "  {:<17} enabled={:<3} reason={:<16} {}",
            module.module,
            if module.enabled { "yes" } else { "no" },
            module.reason,
            module.module.description()
        );
    }

    println!();
    println!("Remote installers are listed in --json and docs/remote-installers.md.");
    Ok(())
}

#[derive(Debug, Serialize)]
struct PlanOutput {
    profile: String,
    dry_run: bool,
    mutates_dotfiles: bool,
    requires_sudo: bool,
    modules: Vec<ModuleOutput>,
    remote_installers: Vec<String>,
}

impl PlanOutput {
    fn from_plan(plan: &crate::application::planner::InstallPlan, lockfile: &ToolLockfile) -> Self {
        Self {
            profile: plan.profile.as_str().to_owned(),
            dry_run: plan.dry_run.is_dry_run(),
            mutates_dotfiles: plan.auto_config.mutates_dotfiles(),
            requires_sudo: plan.requires_sudo(),
            modules: plan
                .modules
                .iter()
                .map(ModuleOutput::from_module_plan)
                .collect(),
            remote_installers: lockfile
                .remote_installers()
                .iter()
                .map(|installer| installer.as_str().to_owned())
                .collect(),
        }
    }
}

#[derive(Debug, Serialize)]
struct ModuleOutput {
    name: Module,
    description: &'static str,
    enabled: bool,
    reason: String,
    requires_sudo: bool,
}

impl ModuleOutput {
    fn from_module_plan(plan: &crate::application::planner::ModulePlan) -> Self {
        Self {
            name: plan.module,
            description: plan.module.description(),
            enabled: plan.enabled,
            reason: plan.reason.as_str().to_owned(),
            requires_sudo: plan.module.requires_sudo().requires_sudo(),
        }
    }
}

#[allow(dead_code)]
fn _assert_auto_config_is_used(_: AutoConfig) {}
