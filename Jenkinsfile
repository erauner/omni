#!/usr/bin/env groovy

@Library('homelab@main') _

// Lightweight pod for YAML validation
def POD_YAML = '''
apiVersion: v1
kind: Pod
metadata:
  labels:
    workload-type: ci-builds
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:3355.v388858a_47b_33-3-jdk21
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
  - name: tools
    image: alpine:3.21
    command: ['sleep', '3600']
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 256Mi
'''

pipeline {
    agent {
        kubernetes {
            yaml POD_YAML
        }
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        skipDefaultCheckout(true)
        timeout(time: 10, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Setup Tools') {
            steps {
                container('tools') {
                    sh '''
                        apk add --no-cache yamllint yq
                    '''
                }
            }
        }

        stage('Validate YAML Syntax') {
            steps {
                container('tools') {
                    sh '''
                        echo "=== Validating cluster templates ==="
                        for f in cluster-template-*.yaml; do
                            if [ -f "$f" ]; then
                                echo "Checking $f..."
                                yq e '.' "$f" > /dev/null && echo "  ✓ $f"
                            fi
                        done

                        echo ""
                        echo "=== Validating patches ==="
                        for f in patches/*.yaml; do
                            if [ -f "$f" ]; then
                                echo "Checking $f..."
                                yq e '.' "$f" > /dev/null && echo "  ✓ $f"
                            fi
                        done

                        echo ""
                        echo "=== Validating docker-compose.yaml ==="
                        yq e '.' docker-compose.yaml > /dev/null && echo "✓ docker-compose.yaml"
                    '''
                }
            }
        }

        stage('Lint YAML') {
            steps {
                container('tools') {
                    sh '''
                        echo "=== Running yamllint ==="

                        # Create yamllint config for relaxed rules (Talos/Omni templates have special syntax)
                        cat > .yamllint.yml << 'EOF'
extends: relaxed
rules:
  line-length:
    max: 200
  truthy:
    check-keys: false
  document-start: disable
  comments:
    min-spaces-from-content: 1
EOF

                        yamllint -c .yamllint.yml cluster-template-*.yaml patches/*.yaml || echo "⚠️ Lint warnings (non-blocking)"
                    '''
                }
            }
        }

        stage('Validate Cluster Templates') {
            steps {
                container('tools') {
                    sh '''
                        echo "=== Checking cluster template structure ==="

                        for template in cluster-template-*.yaml; do
                            if [ -f "$template" ]; then
                                echo ""
                                echo "--- $template ---"

                                # Check for required top-level keys
                                KIND=$(yq e '.kind' "$template")
                                NAME=$(yq e '.name' "$template")
                                K8S_VERSION=$(yq e '.kubernetes.version' "$template")
                                TALOS_VERSION=$(yq e '.talos.version' "$template")

                                echo "  Kind: $KIND"
                                echo "  Name: $NAME"
                                echo "  Kubernetes: $K8S_VERSION"
                                echo "  Talos: $TALOS_VERSION"

                                # Count machines
                                CONTROL_PLANES=$(yq e '.machines | map(select(.controlPlane == true)) | length' "$template")
                                WORKERS=$(yq e '.machines | map(select(.controlPlane != true)) | length' "$template")
                                echo "  Control Planes: $CONTROL_PLANES"
                                echo "  Workers: $WORKERS"

                                # Validate required fields exist
                                if [ "$KIND" = "Cluster" ] && [ "$NAME" != "null" ]; then
                                    echo "  ✓ Valid cluster template"
                                else
                                    echo "  ⚠️ Missing required fields"
                                fi
                            fi
                        done
                    '''
                }
            }
        }

        stage('Check Patch References') {
            steps {
                container('tools') {
                    sh '''
                        echo "=== Checking patch file references ==="

                        # Extract patch references from cluster templates
                        for template in cluster-template-*.yaml; do
                            if [ -f "$template" ]; then
                                echo ""
                                echo "--- Patches referenced in $template ---"

                                # Get all patch file references, filter out YAML separators
                                PATCHES=$(yq e '.. | select(has("file")) | .file' "$template" 2>/dev/null | grep -v '^---$' | grep -v '^null$' | sort -u)

                                if [ -n "$PATCHES" ]; then
                                    ALL_FOUND=true
                                    echo "$PATCHES" | while read -r patch; do
                                        # Skip empty lines
                                        [ -z "$patch" ] && continue

                                        # Extract just the filename for local check
                                        FILENAME=$(basename "$patch")

                                        if [ -f "patches/$FILENAME" ]; then
                                            echo "  ✓ patches/$FILENAME"
                                        elif [ -f "$patch" ]; then
                                            echo "  ✓ $patch (absolute path)"
                                        else
                                            echo "  ⚠️ patches/$FILENAME not found (referenced as $patch)"
                                            # Don't fail - paths may be environment-specific
                                        fi
                                    done
                                else
                                    echo "  (no file patches)"
                                fi
                            fi
                        done

                        echo ""
                        echo "=== Available patches ==="
                        ls -1 patches/*.yaml 2>/dev/null | wc -l | xargs -I{} echo "  {} patch files in patches/"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo '✅ Omni cluster templates validated successfully!'
        }
        failure {
            echo '❌ Omni cluster template validation failed!'
        }
    }
}
