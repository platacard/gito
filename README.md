# Gito
<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
[![All Contributors](https://img.shields.io/badge/all_contributors-1-orange.svg?style=flat-square)](#contributors-)
<!-- ALL-CONTRIBUTORS-BADGE:END -->

Gito is a Swift wrapper for various git commands, designed to work with CI/CD environments. It supports both GitLab and GitHub predefined variables for CI/CD pipelines. A small part of the larger iOS deploy infrastructure at Plata.

## Features

- Git status management and validation
- Branch name detection for shallow clones
- Branch stability checking
- Tag management (create, remove, push)
- Commit SHA retrieval
- Remote branch analysis (merged/unmerged)
- Stale branch detection
- CI/CD integration with GitLab and GitHub variables

## Usage

### Basic Git Operations

```swift
let gito = Gito()

// Ensure working tree is clean
try gito.ensureGitStatusClean()

...
```
## CI/CD Integration

Gito automatically detects and uses CI/CD environment variables:

### GitLab Variables
- `CI_MERGE_REQUEST_SOURCE_BRANCH_NAME` - MR source branch
- `CI_COMMIT_BRANCH` - Push branch name
- `CI_COMMIT_SHORT_SHA` - Commit SHA

### GitHub Variables  
- `GITHUB_HEAD_REF` - Pull request branch
- `GITHUB_REF` + `GITHUB_REF_TYPE` - Push branch reference
- `GITHUB_SHA` - Commit SHA

## Dependencies

- [Corredor](https://github.com/platacard/corredor) - Shell command execution
- [Cronista](https://github.com/platacard/cronista) - Logging functionality

## Requirements

- macOS 14.0+
- Swift 6.0+

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/platacard/gito.git", from: "1.0.0")
]
```

## Contributors ✨

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/NoFearJoe"><img src="https://avatars.githubusercontent.com/u/4526841?v=4?s=100" width="100px;" alt="Ilya Kharabet"/><br /><sub><b>Ilya Kharabet</b></sub></a><br /><a href="https://github.com/platacard/gito/commits?author=NoFearJoe" title="Code">💻</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!