# CI workflow inventory and required settings

## CI tiers

`CI` runs on every pull request, every push to `master`, merge queue (`merge_group`),
and manual dispatch. There is no path filter: a required check must always be
created. Pull requests run lint, a Node 24 Ubuntu build and test, the Docker
image smoke test, changeset validation, and CodeQL. Pushes and merge queue runs
also run the Node 24/26 build and test matrix on Ubuntu, Windows, and macOS,
plus the package-manager CLI and UI end-to-end suites. The `CI Gate` job requires
every scheduled job to succeed. Its only accepted skips are the two full-suite
jobs on a pull request; the changeset check itself succeeds on exempt PRs and
non-PR events.

The old PR-triggered `Docker build test` workflow is now manual. Its useful
image check is in `scripts/test-docker-image.sh` and runs as part of `CI` on
every event, so a Docker-only PR also gets a required gate. The manual workflow
remains available for diagnosis until required-check settings can be reviewed.

Other active workflows have separate purposes: `Changesets` and
`Changesets Publish Test` cover release and snapshot publishing; `Docker publish
to docker.io` publishes the multi-arch image; `pnpm audit`, `Smoke Test`, and
the Apache and Nginx proxy workflows test their respective concerns.

## Callable workflow audit

The six `x-` workflows (`x-e2e-angular-cli-workflow.yml`,
`x-e2e-audit-workflow.yml`, `x-e2e-gatsbyjs-cli-workflow.yml`,
`x-e2e-jest-workflow.yml`, `x-smok-test-docker.yml`, and
`x-smok-test-module.yml`) declare only `workflow_call`. A repository-wide
search for each filename found no in-repository `uses:` caller in this
checkout. `yarn-ci.yml` is also callable-only and has no in-repository caller.
All seven are still marked active by the GitHub Actions API. Run-history and
branch-protection API requests returned 404 with the available credentials.
This checkout does not contain usable Git history, and callers can reference a reusable
workflow from another repository or branch. Therefore the audit does not prove
they are unused; they remain in place. Before removing one, search callers
across branches and external repositories, inspect its Actions run history,
and confirm no required check relies on it.

## Settings and live validation

- In repository branch protection or rulesets, require **CI Gate** for pull
  requests and enable it for merge queue. Remove any requirement for the old
  `Docker build test` check before relying on the manual-only workflow.
- Confirm a live PR gets the fast tier, a merge queue run gets the full tier,
  and a failed or skipped prerequisite makes `CI Gate` fail.
- For each public npm package published from this workspace (33 public
  `packages/**/package.json` manifests in this checkout), configure npm
  Trusted Publishing with repository `verdaccio/verdaccio`, workflow filename
  `changesets.yml`, and GitHub environment `npm`. The protected `publish` job
  has `id-token: write`; the version PR job does not. No npm token is used.
  The publish action keeps Changesets' package selection and pnpm publish
  behavior, sets provenance for every publish, then checks npm's published
  `dist.attestations` metadata for each package the action reports. A live
  release is required to verify the OIDC exchange and the package-level npm
  configuration. See [npm Trusted Publishing](https://docs.npmjs.com/trusted-publishers)
  and [pnpm publish provenance](https://pnpm.io/cli/publish#--provenance).

The npm attestation is a signed provenance statement for each package. Docker's
OCI SBOM remains on its separate image publication path; npm does not attach
that OCI SBOM to packages through `changeset publish`.
