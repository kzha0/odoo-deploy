#!/usr/bin/env python3

import argparse
import subprocess
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

IMG_CONFIGS = [
    {
        "label": "soolit-tech/odoo-base",
        "context": "./base",
        "dockerfile": "18.Dockerfile",
    },
    {
        "label": "soolit-tech/odoo-community",
        "context": "./community",
        "dockerfile": "18.Dockerfile",
    },
    {
        "label": "soolit-tech/odoo-builder",
        "context": "./builder",
        "dockerfile": "18.Dockerfile",
    },
    {
        "label": "soolit-tech/odoo-community-builder",
        "context": "./builder",
        "dockerfile": "18.Dockerfile",
        "build_args": {"ODOO_IMAGE": "soolit-tech/odoo-community"},
    },
]


@dataclass
class BuildConfig:
    label: str
    context: Path | None = None
    dockerfile: Path | None = None
    build_args: dict = field(default_factory=dict)
    _image_tags: list[str] = field(default_factory=list)

    def build(self, version_tag: str, multi: bool):
        build_date = date.today().isoformat()
        major_version = version_tag.split(".")[0]

        tags = [
            f"{self.label}:latest",
            f"{self.label}:{version_tag}",
            f"{self.label}:{major_version}",
            f"{self.label}:{version_tag}_{build_date}",
            f"{self.label}:{major_version}_{build_date}",
        ]
        args = ["docker", "build"]
        for tag in tags:
            args += ["-t", tag]

        for key, value in self.build_args.items():
            args += ["--build-arg", f"{key}={value}"]

        if multi:
            args += ["--platform", "linux/amd64,linux/arm64"]

        if self.dockerfile:
            args += ["-f", self.dockerfile]

        args += ["."]

        subprocess.run(args, cwd=(Path.cwd() / self.context), check=True)

        self._image_tags = tags

    def push(self, registry: str):
        for tag in self._image_tags:
            subprocess.run(["docker", "tag", tag, f"{registry}/{tag}"])
        subprocess.run(["docker", "push", "--all-tags", f"{registry}/{self.label}"])


def build_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-r",
        "--registry",
        type=str,
        help="Target registry. When specified, automatically tags images and pushes images to this registry after build",
    )
    parser.add_argument(
        "-v",
        "--version",
        type=str,
        default="18.0",
        help="Odoo version for tagging images",
    )
    parser.add_argument(
        "-m",
        "--multi",
        action="store_true",
        help="Perform a multi-platform build"
    )
    return parser


if __name__ == "__main__":
    parser = build_parser()
    args = parser.parse_args()
    build_items = [
        BuildConfig(
            item.get("label"),
            item.get("context"),
            item.get("dockerfile"),
            item.get("build_args", {}),
        )
        for item in IMG_CONFIGS
    ]
    for item in build_items:
        item.build(args.version, args.multi)

    if args.registry:
        for item in build_items:
            item.push(args.registry)
