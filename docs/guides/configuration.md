# OpenCode Harness - Configuration Guide

This comprehensive guide covers all configuration options for OpenCode Harness across different deployment methods and use cases.

## Configuration Files

### Primary Configuration: opencode.json

The main configuration file defines which plugins to load and global OpenCode settings:

**Location:** Root of repository
**Format:** JSON (strict syntax required)

```json
{
    "$schema": "https://opencode.ai/config.json",
    "plugin": [
        "@tarquinen/opencode-dcp@latest",
        "cc-safety-net",
        "ecc-universal",
        "oh-my-opencode"
    ],
    "settings": {
        "maxTokens": 4096,
        "temperature": 0.7,
        "model": "claude-3-opus"
    }
}
```

### Container Configuration: etc/opencode/opencode.jsonc

Container-specific configuration with extended features:

**Location:** `etc/opencode/opencode.jsonc`
**Format:** JSONC (supports comments and trailing commas)

```jsonc
{
    "$schema": "https://opencode.ai/config.json",
    // Inherit from main configuration
    "extends": "/app/opencode.json",

    // Container-specific overrides
    "plugin": [
        "@tarquinen/opencode-dcp@latest",
        "cc-safety-net",
        "ecc-universal",
        "oh-my-opencode"
    ],

    // Container optimizations
    "settings": {
        "containerMode": true,
        "workspacePath": "/workspace",
        "cachePath": "/tmp/opencode-cache",
        "logLevel": "info", // debug, info, warn, error
        "maxConcurrentTasks": 4,
    },

    // Plugin-specific configurations
    "pluginConfig": {
        "oh-my-opencode": {
            "agentSettings": {
                "sisyphus": {
                    "model": "claude-3-opus",
                    "temperature": 0.3,
                    "maxTokens": 8192
                },
                "hephaestus": {
                    "model": "gpt-4-turbo",
                    "temperature": 0.1,
                    "maxTokens": 4096
                }
            }
        }
    }
}
```

### User Configuration

**Location:** `~/.config/opencode/opencode.json` or `~/.config/opencode/opencode.jsonc`
**Purpose:** User-specific settings that apply across all projects

```jsonc
{
    // User preferences
    "settings": {
        "defaultModel": "claude-3-opus",
        "preferredTheme": "dark",
        "autoSave": true,
        "backupInterval": 300 // seconds
    },

    // User-specific plugin configurations
    "pluginConfig": {
        "oh-my-opencode": {
            "userPreferences": {
                "verboseLogging": false,
                "autoUpdate": true,
                "telemetry": false
            }
        }
    },

    // API keys and credentials (use environment variables instead)
    // DO NOT store secrets here - use environment variables
    "apiKeys": {
        "anthropic": "${ANTHROPIC_API_KEY}",
        "openai": "${OPENAI_API_KEY}"
    }
}
```

### Project-Specific Configuration

**Location:** `.opencode/opencode.json` or `.opencode/opencode.jsonc`
**Purpose:** Project-specific overrides and settings

```jsonc
{
    // Project-specific plugin selection
    "plugin": [
        "@tarquinen/opencode-dcp@latest",
        "cc-safety-net",
        "ecc-universal",
        "oh-my-opencode",
        "project-specific-plugin" // Local plugin
    ],

    // Project settings
    "settings": {
        "projectName": "MyProject",
        "projectType": "web-application",
        "targetFramework": "react-typescript",
        "codeStyle": "prettier-eslint"
    },

    // Project-specific agent configurations
    "pluginConfig": {
        "oh-my-opencode": {
            "projectContext": {
                "domain": "e-commerce",
                "complexity": "high",
                "teamSize": "large",
                "codebase": "mature"
            },
            "skillOverrides": {
                "frontend-ui-ux": {
                    "designSystem": "material-ui",
                    "stateManagement": "redux-toolkit"
                }
            }
        }
    }
}
```

## Plugin Configuration

### Core Plugins

#### everything-claude-code Configuration

```jsonc
{
    "pluginConfig": {
        "everything-claude-code": {
            "agents": {
                "enabled": ["code-reviewer", "test-writer", "documentation-generator"],
                "disabled": ["legacy-converter"]
            },
            "skills": {
                "tdd": {
                    "framework": "jest", // or "vitest", "mocha"
                    "coverageThreshold": 80
                },
                "git-workflows": {
                    "defaultBranch": "main",
                    "conventionalCommits": true,
                    "autoRebase": true
                }
            }
        }
    }
}
```

#### oh-my-openagent Configuration

```jsonc
{
    "pluginConfig": {
        "oh-my-opencode": {
            // Agent models and settings
            "agents": {
                "sisyphus": {
                    "model": "claude-3-opus",
                    "temperature": 0.3,
                    "maxTokens": 8192,
                    "systemPrompt": "Custom orchestrator instructions..."
                },
                "hephaestus": {
                    "model": "gpt-4-turbo",
                    "temperature": 0.1,
                    "maxTokens": 4096,
                    "specialization": "backend-development"
                },
                "prometheus": {
                    "model": "claude-3-opus",
                    "temperature": 0.2,
                    "planningDepth": "detailed"
                }
            },

            // Background task limits
            "backgroundTasks": {
                "maxConcurrent": 5,
                "timeoutMs": 300000, // 5 minutes
                "retryAttempts": 3
            },

            // Skill-embedded MCPs
            "skillMCPs": {
                "autoCleanup": true,
                "resourceLimits": {
                    "memory": "256MB",
                    "timeout": 60000
                }
            }
        }
    }
}
```

#### superpowers Configuration

```jsonc
{
    "pluginConfig": {
        "superpowers": {
            "workflows": {
                "tdd": {
                    "testRunner": "jest",
                    "coverageRequired": true,
                    "redGreenRefactor": true
                },
                "debugging": {
                    "systematic": true,
                    "rootCauseAnalysis": true,
                    "reproducibility": "always"
                },
                "git": {
                    "atomicCommits": true,
                    "conventionalCommits": true,
                    "signoffRequired": false
                }
            }
        }
    }
}
```

### Custom Plugin Configuration

```jsonc
{
    "plugin": [
        // ... core plugins ...
        "custom-plugin"
    ],
    "pluginConfig": {
        "custom-plugin": {
            "enabled": true,
            "settings": {
                "customSetting": "value"
            },
            "permissions": {
                "filesystem": "read-write",
                "network": "restricted",
                "execution": "sandboxed"
            }
        }
    }
}
```

## Environment-Specific Configuration

### Development Environment

```jsonc
{
    "settings": {
        "environment": "development",
        "logLevel": "debug",
        "hotReload": true,
        "sourceMap": true,
        "debugMode": true
    },

    "pluginConfig": {
        "oh-my-opencode": {
            "development": {
                "verboseLogging": true,
                "experimentalFeatures": true,
                "autoReload": true
            }
        }
    }
}
```

### Production Environment

```jsonc
{
    "settings": {
        "environment": "production",
        "logLevel": "warn",
        "optimized": true,
        "telemetry": true
    },

    "pluginConfig": {
        "oh-my-opencode": {
            "production": {
                "performanceMode": true,
                "resourceLimits": {
                    "maxMemory": "2GB",
                    "maxConcurrency": 3
                },
                "errorReporting": true
            }
        }
    }
}
```

### Container Environment Variables

Configure the harness through environment variables:

```bash
# Core OpenCode settings
export OPENCODE_CONFIG_PATH=/custom/config/path
export OPENCODE_LOG_LEVEL=debug
export OPENCODE_WORKSPACE=/workspace
export OPENCODE_CACHE_DIR=/tmp/opencode

# Plugin-specific environment variables
export OMO_AGENT_MODEL=claude-3-opus
export OMO_MAX_CONCURRENCY=5
export OMO_TIMEOUT_MS=300000

# API keys (never hardcode these)
export ANTHROPIC_API_KEY=your_key_here
export OPENAI_API_KEY=your_key_here

# Container runtime
podman run -it --rm \
  -e OPENCODE_LOG_LEVEL=debug \
  -e OMO_AGENT_MODEL=claude-3-opus \
  -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  -v $(pwd):/workspace \
  opencode-harness
```

## Configuration Validation

### JSON Schema Validation

```bash
# Validate main configuration
jq empty opencode.json && echo "Valid JSON" || echo "Invalid JSON"

# Validate with schema (if available)
jsonschema -i opencode.json schema/opencode-schema.json
```

### Configuration Testing

```bash
# Test configuration loading
opencode --config-check

# Test plugin loading
opencode --list-plugins

# Verbose configuration debugging
OPENCODE_LOG_LEVEL=debug opencode --config-check
```

### Validation Scripts

```bash
# Use built-in validation
./scripts/validate.sh

# Manual validation
jq . opencode.json > /dev/null && echo "✓ opencode.json valid"
jq . .opencode/opencode.jsonc > /dev/null && echo "✓ project config valid"
jq . ~/.config/opencode/opencode.json > /dev/null && echo "✓ user config valid"
```

## Advanced Configuration

### Model Selection Strategy

```jsonc
{
    "pluginConfig": {
        "oh-my-opencode": {
            "modelStrategy": {
                "orchestration": "claude-3-opus", // Main coordination
                "coding": "gpt-4-turbo",          // Implementation
                "review": "claude-3-opus",        // Code review
                "planning": "gpt-4-turbo",        // Strategic planning
                "documentation": "claude-3-haiku" // Fast documentation
            },

            "fallback": {
                "primary": "claude-3-opus",
                "secondary": "gpt-4-turbo",
                "emergency": "gpt-3.5-turbo"
            }
        }
    }
}
```

### Performance Tuning

```jsonc
{
    "settings": {
        "performance": {
            "caching": {
                "enabled": true,
                "strategy": "aggressive",
                "ttl": 3600 // seconds
            },
            "concurrency": {
                "maxParallelTasks": 4,
                "queueStrategy": "priority",
                "resourceLimits": {
                    "memory": "4GB",
                    "cpu": "2 cores"
                }
            },
            "optimization": {
                "lazyLoading": true,
                "precompilation": true,
                "bundling": "production"
            }
        }
    }
}
```

### Security Configuration

```jsonc
{
    "security": {
        "permissions": {
            "filesystem": {
                "allowedPaths": ["/workspace", "/tmp"],
                "deniedPaths": ["/etc", "/usr", "/root"],
                "readOnly": false
            },
            "network": {
                "allowedDomains": ["api.anthropic.com", "api.openai.com"],
                "proxyRequired": false,
                "tlsOnly": true
            },
            "execution": {
                "sandboxed": true,
                "timeoutMs": 60000,
                "memoryLimit": "1GB"
            }
        },

        "secrets": {
            "storageMethod": "environment", // never "file"
            "encryption": "AES-256",
            "rotationPolicy": "90days"
        }
    }
}
```

## Configuration Troubleshooting

### Common Issues

**Configuration not found:**

```bash
# Check configuration file locations
ls -la opencode.json
ls -la .opencode/opencode.json*
ls -la ~/.config/opencode/opencode.json*
ls -la etc/opencode/opencode.jsonc
```

**Plugin loading failures:**

```bash
# Verify plugin paths
git submodule status
ls -la modules/

# Check plugin configuration
jq '.plugin[]' opencode.json
```

**Permission errors:**

```bash
# Fix configuration file permissions
chmod 644 opencode.json
chmod 644 ~/.config/opencode/opencode.json

# Fix directory permissions
chmod 755 .opencode/
chmod 755 ~/.config/opencode/
```

### Debug Configuration Loading

```bash
# Enable verbose configuration debugging
export OPENCODE_CONFIG_DEBUG=true
export OPENCODE_LOG_LEVEL=debug

# Run with configuration tracing
opencode --trace-config

# Container debugging
podman run -it --rm \
  -e OPENCODE_CONFIG_DEBUG=true \
  -e OPENCODE_LOG_LEVEL=debug \
  opencode-harness opencode --config-check
```

### Configuration Backup and Recovery

```bash
# Backup current configuration
cp opencode.json opencode.json.backup
cp -r .opencode/ .opencode.backup/
cp -r ~/.config/opencode/ ~/.config/opencode.backup/

# Restore from backup
cp opencode.json.backup opencode.json
rm -rf .opencode/
mv .opencode.backup/ .opencode/
```

## Best Practices

### Configuration Management

1. **Version control**: Always commit `opencode.json` to version control
2. **Environment separation**: Use different configurations for dev/staging/production
3. **Secret management**: Never commit API keys or secrets
4. **Documentation**: Document custom configuration choices
5. **Validation**: Always validate configuration files before deployment

### Security Best Practices

1. **Use environment variables** for all secrets and API keys
2. **Limit plugin permissions** to minimum required access
3. **Regular updates** of plugins and dependencies
4. **Audit configurations** regularly for security issues
5. **Sandbox execution** in production environments

### Performance Best Practices

1. **Resource limits**: Set appropriate memory and CPU limits
2. **Caching strategy**: Configure caching based on usage patterns
3. **Concurrency limits**: Balance parallelism with resource usage
4. **Model selection**: Choose appropriate models for different tasks
5. **Monitoring**: Monitor performance metrics and adjust accordingly
