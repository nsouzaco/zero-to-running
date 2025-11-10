#!/bin/bash
# Check for required dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Minimum versions
MIN_DOCKER_VERSION="20.10.0"
MIN_MINIKUBE_VERSION="1.31.0"
MIN_HELM_VERSION="3.12.0"
MIN_KUBECTL_VERSION="1.27.0"

# Check Docker
check_docker() {
    print_step "Checking Docker"
    if ! command_exists docker; then
        print_error "Docker is not installed"
        echo ""
        echo "Please install Docker:"
        case "$(get_os)" in
            macos)
                echo "  Download from: https://www.docker.com/products/docker-desktop"
                ;;
            linux)
                echo "  Ubuntu/Debian: sudo apt-get install docker.io"
                echo "  Fedora: sudo dnf install docker"
                ;;
            windows)
                echo "  Install Docker Desktop for Windows"
                ;;
        esac
        exit_with_error 2 "Docker is required"
    fi
    
    # Check Docker is running
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running"
        echo "Please start Docker Desktop or your Docker daemon"
        exit_with_error 2 "Docker daemon is not running"
    fi
    
    local version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    print_success "Docker installed (version $version)"
}

# Check Minikube
check_minikube() {
    print_step "Checking Minikube"
    if ! command_exists minikube; then
        print_warning "Minikube is not installed"
        echo ""
        read -p "Would you like to install Minikube automatically? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_minikube
        else
            echo "Please install Minikube manually:"
            case "$(get_os)" in
                macos)
                    echo "  brew install minikube"
                    echo "  Or download from: https://minikube.sigs.k8s.io/docs/start/"
                    ;;
                linux)
                    echo "  Download from: https://minikube.sigs.k8s.io/docs/start/"
                    ;;
                windows)
                    echo "  Download from: https://minikube.sigs.k8s.io/docs/start/"
                    ;;
            esac
            exit_with_error 2 "Minikube is required"
        fi
    else
        local version=$(minikube version --short 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        print_success "Minikube installed (version $version)"
    fi
}

# Install Minikube
install_minikube() {
    print_step "Installing Minikube"
    case "$(get_os)" in
        macos)
            if command_exists brew; then
                brew install minikube
            else
                print_error "Homebrew not found. Please install Minikube manually."
                exit_with_error 2 "Minikube installation failed"
            fi
            ;;
        linux)
            # Download and install Minikube
            curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
            sudo install minikube-linux-amd64 /usr/local/bin/minikube
            rm minikube-linux-amd64
            ;;
        *)
            print_error "Automatic Minikube installation not supported on this OS"
            exit_with_error 2 "Please install Minikube manually"
            ;;
    esac
    print_success "Minikube installed"
}

# Check Helm
check_helm() {
    print_step "Checking Helm"
    if ! command_exists helm; then
        print_error "Helm is not installed"
        echo ""
        echo "Please install Helm:"
        case "$(get_os)" in
            macos)
                echo "  brew install helm"
                ;;
            linux)
                echo "  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
                ;;
            windows)
                echo "  Download from: https://helm.sh/docs/intro/install/"
                ;;
        esac
        exit_with_error 2 "Helm is required"
    fi
    
    local version=$(helm version --short 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    print_success "Helm installed (version $version)"
}

# Check kubectl
check_kubectl() {
    print_step "Checking kubectl"
    if ! command_exists kubectl; then
        print_error "kubectl is not installed"
        echo ""
        echo "Please install kubectl:"
        case "$(get_os)" in
            macos)
                echo "  brew install kubectl"
                ;;
            linux)
                echo "  curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                echo "  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl"
                ;;
            windows)
                echo "  Download from: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/"
                ;;
        esac
        exit_with_error 2 "kubectl is required"
    fi
    
    local version=$(kubectl version --client --short 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    print_success "kubectl installed (version $version)"
}

# Main execution
main() {
    echo "Checking dependencies..."
    echo ""
    
    check_docker
    check_minikube
    check_helm
    check_kubectl
    
    echo ""
    print_success "All dependencies are installed and ready!"
}

main "$@"

