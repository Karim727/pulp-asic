#!/usr/bin/env python3
"""
Design Space Exploration (DSE) Script for LibreLane.

Loads a base configuration (config.yaml) and file list (flist.yaml),
generates unique parameter combinations across defined sweep variables,
and executes LibreLane for each combination.
"""

import argparse
import csv
import itertools
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# ---------------------------------------------------------------------------
# 0. Automatic Environment Bootstrap
# ---------------------------------------------------------------------------
# If running in system Python without librelane, re-exec inside devshell AppImage
if "LIBRELANE_IN_APPIMAGE" not in os.environ:
    try:
        import librelane  # noqa: F401
    except ModuleNotFoundError:
        appimage = Path.home() / "librelane-devshell-x86_64.AppImage"
        if appimage.is_file() and os.access(appimage, os.X_OK):
            env = os.environ.copy()
            env["LIBRELANE_IN_APPIMAGE"] = "1"
            print(f"[INFO] LibreLane not found in host Python. Delegating to {appimage}...")
            os.execve(
                str(appimage),
                [str(appimage), "python3", os.path.abspath(__file__)] + sys.argv[1:],
                env,
            )

try:
    from librelane.flows import Flow
except ModuleNotFoundError:
    Flow = None

# ---------------------------------------------------------------------------
# 1. Parameter Sweep Definition
# ---------------------------------------------------------------------------
# Define the parameters and the list of values to explore:
DEFAULT_SWEEP_PARAMS: Dict[str, List[Any]] = {
    "FP_CORE_UTIL": [30, 35],
    "PL_TARGET_DENSITY_PCT": [40, 45],
    # Additional sweep parameters can be added here, for example:
    # "DRT_OPT_ITERS": [1, 2],
    # "GRT_ADJUSTMENT": [0.20, 0.25],
}


def resolve_pdk(pdk: str = "sky130A", pdk_root: Optional[str] = None) -> Tuple[str, Optional[str]]:
    """Resolves PDK and PDK_ROOT dynamically using env, ciel, or filesystem."""
    if pdk_root:
        return pdk, str(Path(pdk_root).resolve())
    if env_root := os.getenv("PDK_ROOT"):
        return pdk, str(Path(env_root).resolve())

    # Try ciel if available
    try:
        import ciel
        from librelane.common import get_pdk_hash
        from ciel.source import StaticWebDataSource

        family = (
            ciel.Family.by_name.get(pdk)
            or [f for f in ciel.Family.by_name.values() if pdk in f.variants][0]
        )
        ciel_home = ciel.get_ciel_home()
        opdks_rev = get_pdk_hash(pdk)
        version = ciel.fetch(
            ciel_home,
            family.name,
            opdks_rev,
            data_source=StaticWebDataSource("https://fossi-foundation.github.io/ciel-releases"),
            include_libraries=["default"],
        )
        return pdk, str(version.get_dir(ciel_home))
    except Exception:
        pass

    # Fallback to local ~/.ciel directory
    ciel_sky130 = Path.home() / ".ciel" / "ciel" / "sky130" / "versions"
    if ciel_sky130.is_dir():
        versions = [p for p in ciel_sky130.iterdir() if p.is_dir()]
        if versions:
            return pdk, str(versions[0])

    return pdk, None


def make_run_tag(combo: Dict[str, Any], prefix: str = "dse") -> str:
    """Builds a filesystem-safe tag representing the combination."""
    tag_parts = [f"{k}_{v}" for k, v in combo.items()]
    joined = "_".join(tag_parts)
    tag = f"{prefix}_{joined}" if prefix else joined
    return tag.replace(" ", "").replace("/", "_")


def extract_metrics(run_dir: Path) -> Dict[str, Any]:
    """Extracts key PPA metrics from the run directory's metrics.json."""
    metrics_file = run_dir / "final" / "metrics.json"
    if not metrics_file.is_file():
        alt = list(run_dir.glob("**/metrics.json"))
        if alt:
            metrics_file = alt[0]
        else:
            return {}
    try:
        with open(metrics_file, "r") as f:
            data = json.load(f)
        return {
            "die_area": data.get("design__die__area"),
            "core_area": data.get("design__core__area"),
            "setup_ws": data.get("timing__setup__ws"),
            "setup_tns": data.get("timing__setup__tns"),
            "drc_errors": data.get("route__drc_errors"),
        }
    except Exception:
        return {}


def run_exploration(
    config_file: Path,
    flist_file: Path,
    sweep_params: Dict[str, List[Any]],
    flow_name: str = "Classic",
    design_dir: Optional[Path] = None,
    pdk: str = "sky130A",
    pdk_root: Optional[str] = None,
    dry_run: bool = False,
    to_step: Optional[str] = None,
    from_step: Optional[str] = None,
    only_step: Optional[str] = None,
    tag_prefix: str = "dse",
    output_csv: Optional[Path] = None,
) -> List[Dict[str, Any]]:
    """Runs the design space exploration over all unique combinations."""
    config_file = config_file.resolve()
    flist_file = flist_file.resolve()
    if design_dir is None:
        design_dir = config_file.parent
    design_dir = design_dir.resolve()

    if not config_file.is_file():
        raise FileNotFoundError(f"Configuration file not found: {config_file}")
    if not flist_file.is_file():
        raise FileNotFoundError(f"File list not found: {flist_file}")

    pdk, resolved_pdk_root = resolve_pdk(pdk, pdk_root)

    print("==================================================")
    print(" LibreLane Design Space Exploration (DSE)")
    print("==================================================")
    print(f"Base Config : {config_file}")
    print(f"File List   : {flist_file}")
    print(f"Design Dir  : {design_dir}")
    print(f"Flow        : {flow_name}")
    print(f"PDK         : {pdk}")
    print(f"PDK Root    : {resolved_pdk_root}")
    if only_step:
        print(f"Only Step   : {only_step}")
    elif to_step or from_step:
        print(f"Step Range  : {from_step or 'start'} -> {to_step or 'end'}")
    print("==================================================")

    # Generate all unique combinations
    keys = list(sweep_params.keys())
    value_lists = list(sweep_params.values())
    combinations = [dict(zip(keys, prod)) for prod in itertools.product(*value_lists)]

    print(f"\nDiscovered {len(combinations)} unique parameter combinations to evaluate:")
    for idx, combo in enumerate(combinations, 1):
        tag = make_run_tag(combo, prefix=tag_prefix)
        print(f"  [{idx:2d}/{len(combinations)}] Tag: {tag} | Overrides: {combo}")

    if dry_run:
        print("\n[DRY-RUN] Validating configurations for each run...")
        if Flow is not None:
            FlowClass = Flow.factory.get(flow_name)
            for combo in combinations:
                tag = make_run_tag(combo, prefix=tag_prefix)
                flow = FlowClass(
                    [str(config_file), str(flist_file), combo],
                    design_dir=str(design_dir),
                    pdk=pdk,
                    pdk_root=resolved_pdk_root,
                )
                print(f"  [OK] Validated run: {tag} (DESIGN_NAME={flow.config['DESIGN_NAME']})")
        print("\n[DRY-RUN] Dry run complete. No flows were executed.")
        return []

    if Flow is None:
        raise RuntimeError("LibreLane Python package is not available in current environment.")

    FlowClass = Flow.factory.get(flow_name)
    run_records: List[Dict[str, Any]] = []

    for idx, combo in enumerate(combinations, 1):
        run_tag = make_run_tag(combo, prefix=tag_prefix)
        run_dir = design_dir / "runs" / run_tag

        print(f"\n{'=' * 60}")
        print(f" Starting Exploration [{idx}/{len(combinations)}]: {run_tag}")
        print(f" Parameters: {combo}")
        print(f"{'=' * 60}")

        status = "UNKNOWN"
        error_msg = ""
        metrics = {}

        try:
            # Instantiate LibreLane Flow passing config.yaml, flist.yaml, and combo overrides
            flow = FlowClass(
                [str(config_file), str(flist_file), combo],
                design_dir=str(design_dir),
                pdk=pdk,
                pdk_root=resolved_pdk_root,
            )

            # Execution with step controls if specified
            kwargs: Dict[str, Any] = {"tag": run_tag}
            if only_step:
                kwargs["frm"] = only_step
                kwargs["to"] = only_step
            else:
                if from_step:
                    kwargs["frm"] = from_step
                if to_step:
                    kwargs["to"] = to_step

            flow.start(**kwargs)
            status = "COMPLETED"
            print(f"\n[SUCCESS] Run {run_tag} completed successfully.")
            metrics = extract_metrics(run_dir)

        except Exception as err:
            status = "FAILED"
            error_msg = str(err)
            print(f"\n[ERROR] Run {run_tag} failed: {err}")

        record: Dict[str, Any] = {
            "index": idx,
            "tag": run_tag,
            "status": status,
            "error": error_msg,
            **combo,
            **metrics,
        }
        run_records.append(record)

    # -----------------------------------------------------------------------
    # Summary Report
    # -----------------------------------------------------------------------
    print("\n" + "=" * 70)
    print(" EXPLORATION RUN SUMMARY")
    print("=" * 70)
    header = f"{'Tag':<40} {'Status':<12} {'Setup WS':<10} {'Die Area':<12} {'DRC'}"
    print(header)
    print("-" * 70)
    for r in run_records:
        ws_str = f"{r.get('setup_ws', '-'):.2f}" if isinstance(r.get("setup_ws"), (int, float)) else "-"
        area_str = f"{r.get('die_area', '-'):.0f}" if isinstance(r.get("die_area"), (int, float)) else "-"
        drc_str = str(r.get("drc_errors", "-"))
        print(f"{r['tag']:<40} {r['status']:<12} {ws_str:<10} {area_str:<12} {drc_str}")

    # Save summary CSV
    if output_csv is None:
        output_csv = design_dir / "dse_summary.csv"

    try:
        all_fieldnames = list(run_records[0].keys())
        with open(output_csv, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=all_fieldnames)
            writer.writeheader()
            writer.writerows(run_records)
        print(f"\nDetailed DSE results saved to: {output_csv}")
    except Exception as e:
        print(f"Warning: Could not save summary CSV: {e}")

    return run_records


def main():
    default_dir = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(
        description="Run Design Space Exploration (DSE) using LibreLane with config.yaml and flist.yaml."
    )
    parser.add_argument(
        "--config",
        "-c",
        type=Path,
        default=default_dir / "config.yaml",
        help="Path to base config.yaml (default: %(default)s)",
    )
    parser.add_argument(
        "--flist",
        "-f",
        type=Path,
        default=default_dir / "flist.yaml",
        help="Path to flist.yaml (default: %(default)s)",
    )
    parser.add_argument(
        "--design-dir",
        "-d",
        type=Path,
        default=default_dir,
        help="Design directory (default: %(default)s)",
    )
    parser.add_argument(
        "--flow",
        type=str,
        default="Classic",
        help="LibreLane flow class to run (default: %(default)s)",
    )
    parser.add_argument(
        "--pdk",
        type=str,
        default="sky130A",
        help="PDK name (default: %(default)s)",
    )
    parser.add_argument(
        "--pdk-root",
        type=str,
        default=None,
        help="PDK root directory (default: auto-detect)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Generate combinations and validate configurations without executing the flow.",
    )
    parser.add_argument(
        "--only",
        type=str,
        default=None,
        help="Run only a single flow step (e.g. Verilator.Lint, OpenROAD.Floorplan)",
    )
    parser.add_argument(
        "--to",
        type=str,
        default=None,
        help="Stop flow execution at this step ID (e.g. OpenROAD.STAPrePNR)",
    )
    parser.add_argument(
        "--from",
        dest="from_step",
        type=str,
        default=None,
        help="Start flow execution from this step ID",
    )
    parser.add_argument(
        "--tag-prefix",
        type=str,
        default="dse",
        help="Prefix to prepend to run tags (default: %(default)s)",
    )
    parser.add_argument(
        "--output-csv",
        type=Path,
        default=None,
        help="Path to save summary CSV (default: <design_dir>/dse_summary.csv)",
    )

    args = parser.parse_args()

    run_exploration(
        config_file=args.config,
        flist_file=args.flist,
        sweep_params=DEFAULT_SWEEP_PARAMS,
        flow_name=args.flow,
        design_dir=args.design_dir,
        pdk=args.pdk,
        pdk_root=args.pdk_root,
        dry_run=args.dry_run,
        to_step=args.to,
        from_step=args.from_step,
        only_step=args.only,
        tag_prefix=args.tag_prefix,
        output_csv=args.output_csv,
    )


if __name__ == "__main__":
    main()
