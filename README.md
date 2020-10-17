# Terratest - Automated Testing

[![Built with Mage](https://magefile.org/badge.svg)](https://magefile.org)

## Overview

This repo is borne from the work originally put together by @jlucktay, refactored into an easily consumable
accelerator to kickstart Terraform testing leveraged by Terratest.

## Description

This repository is a central store for [Mage](https://github.com/magefile/mage) targets/funcs to keep things
[DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself).

The [Dockerfile](https://docs.docker.com/engine/reference/builder/) for our `module-test` CI/automated test image is
also kept [here](./Dockerfile).

## Local Development

The [docker-build.sh](/scripts/docker-build.sh) and [docker-run.sh](/scripts/docker-run.sh) scripts in the `/scripts/`
directory of this repo can get you up and running with a local copy of the Docker image.

The aforementioned scripts will build and execute an image tagged with `local-dev`. In contrast, the pipeline on Azure
DevOps runs against the tag `latest` from the container registry.

## Branching / CI Model

This repository has CI in effect on the `master` branch, and will not allow commits to be pushed directly.

If you are starting to work on a new feature or piece of functionality, you should create a new branch. Once you are
happy with your new branch and wish to have it tested, create a pull request on GitHub into the `master` branch. All
such PRs will be validated with the Azure Pipelines build definition linked from the badge above.

The PR validation build will:

1. build the Docker image
1. execute some Terraform validation tests within a container based on said image
1. if successful on both counts, push the new image to the container registry on Azure

The PR validation builds for the various Terraform modules pull the `module-test` image tagged as `latest`.

The `module-test:latest` image/tag will reflect the contents of the `master` branch of this repository
