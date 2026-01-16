#!/usr/bin/env python3

import argparse
import base64
import json
import subprocess
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path
import tomllib


@dataclass(frozen=True)
class Repo:
    name: str
    url: str
    deploy_key_b64: str | None = None


@dataclass(frozen=True)
class Addon:
    repo: str
    branch: str | None = None


@dataclass(frozen=True)
class Instance:
    name: str
    image_label: str
    json_b64: str
    addons: frozenset[Addon] = field(default_factory=frozenset)


@dataclass
class ProjectConfig:
    project_name: str
    odoo_version: str
    builder_image: str | None
    repos: set[Repo] = field(default_factory=set)
    instances: set[Instance] = field(default_factory=set)


def build(config: ProjectConfig):
    build_date = date.today().isoformat()
    for instance in config.instances:
        major_version = (
            config.odoo_version.split(".")[0]
            if config.odoo_version and "." in config.odoo_version
            else config.odoo_version
        )

        tags = [
            f"{instance.image_label}:{instance.name}",
            f"{instance.image_label}:{config.odoo_version}_{instance.name}",
            f"{instance.image_label}:{major_version}_{instance.name}",
            f"{instance.image_label}:{config.odoo_version}_{instance.name}_{build_date}",
            f"{instance.image_label}:{major_version}_{instance.name}_{build_date}",
        ]

        args = ["docker", "build"]
        for tag in tags:
            args.extend(["-t", tag])

        if config.builder_image:
            args.extend(["--build-arg", f"ODOO_IMAGE={config.builder_image}"])

        args.extend(
            [
                "--build-arg",
                f"ODOO_VERSION={config.odoo_version}",
                "--build-arg",
                f"BUILDER_ADDONS_JSON_B64={instance.json_b64}",
                ".",
            ]
        )

        subprocess.run(args, check=True)


def parse_config(file: Path):
    config: dict = tomllib.loads(file.read_text("utf-8"))

    repos: set[Repo] = set()
    for item in config.get("repos", []):
        repos.add(Repo(item.get("name"), item.get("url"), item.get("deploy_key_b64")))
    repos_by_name = {repo.name: repo for repo in repos}

    instances: set[Instance] = set()
    for name, vals in config.get("instance", {}).items():
        addons_set = set()
        for addon in vals.get("addons", []):
            addons_set.add(Addon(addon.get("repo"), addon.get("branch")))

        repos = []
        for addon in addons_set:
            if addon.repo in repos_by_name:
                repo_obj = repos_by_name[addon.repo]
                repo_dict = {"url": repo_obj.url, "branch": addon.branch}
                if repo_obj.deploy_key_b64 is not None:
                    repo_dict["deploy_key"] = repo_obj.deploy_key_b64
                repos.append(repo_dict)

        json_b64 = base64.b64encode(json.dumps(repos).encode("utf-8")).decode("ascii")

        instances.add(
            Instance(
                name,
                vals.get("image_label"),
                json_b64,
                frozenset(addons_set),
            )
        )

    return ProjectConfig(
        config.get("project_name"),
        config.get("odoo_version"),
        config.get("builder_image"),
        repos,
        instances,
    )


def build_parser():
    parser = argparse.ArgumentParser(
        description="Build customized Odoo deployments from simple config files"
    )
    parser.add_argument(
        "-f",
        "--file",
        type=Path,
        default=Path("config.toml"),
        help="Path to toml configuration file; defaults to 'config.toml'",
    )
    parser.add_argument(
        "-p",
        "--print",
        action="store_true",
        help="Print only the generated JSON addons string instead of invoking build",
    )

    return parser


if __name__ == "__main__":
    parser = build_parser()

    args = parser.parse_args()
    config = parse_config(args.file)
    if args.print:
        for instance in config.instances:
            print(f"\n[{instance.name}]\n{instance.json_b64}")
    else:
        build(config)
