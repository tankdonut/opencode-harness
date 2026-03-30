# Contributing to OpenCode Harness

Thank you for considering contributing to OpenCode Harness! This project aims to make OpenCode environment bootstrapping simple and reliable for teams.

## How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test in container (`./scripts/build.sh --no-cache`)
5. Commit your changes (`git commit -m "feat: add amazing feature"`)
6. Push to branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Development Setup

See [DEVELOPMENT.md](DEVELOPMENT.md) for detailed development workflows, testing procedures, and troubleshooting guides.

## Commit Message Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New features
- `fix:` - Bug fixes
- `chore:` - Maintenance tasks
- `docs:` - Documentation updates
- `refactor:` - Code refactoring

## Testing Requirements

Before submitting a PR:

1. Run validation: `./scripts/validate.sh`
2. Build and test: `./scripts/build.sh --tag test && ./scripts/container-test.sh test`
3. Ensure no new vulnerabilities: `podman image scan test`

## Code Style

- Follow existing patterns in the codebase
- Use `set -euo pipefail` in all bash scripts
- Pin all versions (no `latest` tags)
- Keep containers minimal and secure

## What We're Looking For

- **Plugin integrations**: New OpenCode plugins as submodules
- **Container improvements**: Better security, smaller images, faster builds
- **Documentation**: Clear guides and examples
- **Testing**: Better validation and test coverage
- **Bug fixes**: Issues with setup, configuration, or container behavior

## What We're Not Looking For

- **Major architectural changes**: Discuss in an issue first
- **Breaking changes**: Without backward compatibility or migration path
- **Secrets**: Never commit API keys, tokens, or credentials
- **Bloat**: Dependencies or features that aren't essential

## Pull Request Process

1. **Check existing issues**: See if your change addresses an open issue
2. **Write clear descriptions**: Explain what changes and why
3. **Test thoroughly**: Both host and container scenarios
4. **Update docs**: README, DEVELOPMENT.md, or AGENTS.md as needed
5. **Follow conventions**: Commit messages, file structure, coding style

## Questions?

- Open an issue for bugs or feature requests
- Check [DEVELOPMENT.md](DEVELOPMENT.md) for technical details
- Review existing PRs for examples

## License

By contributing, you agree that your contributions will be licensed under the same terms as the project.

---

**Remember**: This harness is about reproducibility and ease of setup. Every change should make it easier for teams to get a working OpenCode environment.
