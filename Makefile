# Maliit Keyboard Build Makefile
# Focus: English and Japanese language support.

# Configuration
BUILD_DIR := build
PREFIX := /usr
JOBS := $(shell nproc)

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m

.PHONY: all build install clean deps uninstall rebuild help purge delete install-maliit-framework

# Default target
all: build

# Show help
help:
	@echo "Maliit Keyboard Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  deps      - Install build dependencies (requires sudo)"
	@echo "  build     - Build the project"
	@echo "  install   - Install to system (requires sudo)"
	@echo "  uninstall - Remove from system (requires sudo)"
	@echo "  delete    - Completely remove all files (alias: purge)"
	@echo "  purge     - Completely remove all files + clean build"
	@echo "  clean     - Clean build directory"
	@echo "  rebuild   - Clean and build"
	@echo "  restart   - Restart maliit-server"
	@echo "  test      - Run tests"
	@echo "  all       - Build only (default)"
	@echo ""
	@echo "Quick start:"
	@echo "  make deps    # First time only"
	@echo "  make build"
	@echo "  sudo make install"
	@echo "  make restart"

# Install dependencies (Ubuntu/Debian)
deps:
	@echo "$(GREEN)Installing build dependencies...$(NC)"
	sudo apt update
	sudo apt install -y \
		cmake \
		build-essential \
		pkg-config \
		qtbase5-dev \
		qtdeclarative5-dev \
		qtquickcontrols2-5-dev \
		libqt5multimedia5-plugins \
		qtmultimedia5-dev \
		libglib2.0-dev \
		libhunspell-dev \
		libanthy-dev \
		gettext
	@echo "$(YELLOW)Checking for maliit-framework...$(NC)"
	@if ! pkg-config --exists maliit-plugins 2>/dev/null; then \
		echo "$(YELLOW)maliit-framework not found. Installing from source...$(NC)"; \
		$(MAKE) install-maliit-framework; \
	else \
		echo "$(GREEN)maliit-framework already installed.$(NC)"; \
	fi
	@echo "$(GREEN)Dependencies installed successfully!$(NC)"

# Install maliit-framework from source
install-maliit-framework:
	@echo "$(GREEN)Building maliit-framework from source...$(NC)"
	sudo apt install -y \
		libwayland-dev \
		wayland-protocols \
		libxkbcommon-dev \
		doxygen \
		libqt5waylandclient5-dev \
		qtwayland5-dev-tools \
		qtwayland5
	@mkdir -p /tmp/maliit-build
	cd /tmp/maliit-build && \
		rm -rf maliit-framework && \
		git clone https://github.com/maliit/framework.git maliit-framework && \
		cd maliit-framework && \
		mkdir -p build && cd build && \
		cmake .. -DCMAKE_INSTALL_PREFIX=/usr && \
		make -j$(JOBS) && \
		sudo make install
	@echo "$(GREEN)maliit-framework installed successfully!$(NC)"

# Configure and build
build: $(BUILD_DIR)/Makefile
	@echo "$(GREEN)Building maliit-keyboard...$(NC)"
	$(MAKE) -C $(BUILD_DIR) -j$(JOBS)
	@echo "$(GREEN)Build completed!$(NC)"

$(BUILD_DIR)/Makefile:
	@echo "$(GREEN)Configuring build...$(NC)"
	@mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && cmake .. \
		-DCMAKE_INSTALL_PREFIX=$(PREFIX) \
		-DCMAKE_PREFIX_PATH="/usr;/usr/local" \
		-DCMAKE_BUILD_TYPE=Release \
		-Denable-hunspell=ON \
		-Denable-tests=OFF
	@echo "$(GREEN)Configuration completed!$(NC)"

# Install to system
install:
	@echo "$(GREEN)Installing maliit-keyboard...$(NC)"
	$(MAKE) -C $(BUILD_DIR) install
	@echo "$(YELLOW)Compiling GSettings schemas...$(NC)"
	glib-compile-schemas $(PREFIX)/share/glib-2.0/schemas/ || true
	@echo "$(GREEN)Installation completed!$(NC)"
	@echo ""
	@echo "$(YELLOW)Run 'make restart' to restart maliit-server$(NC)"

# Uninstall from system
uninstall:
	@echo "$(YELLOW)Uninstalling maliit-keyboard...$(NC)"
	@if [ -f $(BUILD_DIR)/install_manifest.txt ]; then \
		xargs rm -f < $(BUILD_DIR)/install_manifest.txt; \
		echo "$(GREEN)Uninstall completed!$(NC)"; \
	else \
		echo "$(YELLOW)No install manifest found. Manual removal may be needed.$(NC)"; \
	fi

# Delete/Purge - completely remove all maliit-keyboard files
delete: purge

purge:
	@echo "$(YELLOW)Stopping maliit-server...$(NC)"
	-killall maliit-server 2>/dev/null || true
	@echo "$(YELLOW)Removing maliit-keyboard files...$(NC)"
	rm -rf $(PREFIX)/lib/maliit/keyboard2
	rm -rf $(PREFIX)/lib/maliit/plugins/libmaliit-keyboard-plugin.so
	rm -rf $(PREFIX)/bin/maliit-keyboard
	rm -rf $(PREFIX)/share/maliit/keyboard2
	rm -rf $(PREFIX)/share/doc/maliit-keyboard
	rm -f $(PREFIX)/share/glib-2.0/schemas/org.maliit.keyboard.maliit.gschema.xml
	rm -f $(PREFIX)/share/applications/com.github.maliit.keyboard.desktop
	rm -f $(PREFIX)/share/metainfo/com.github.maliit.keyboard.metainfo.xml
	@echo "$(YELLOW)Recompiling GSettings schemas...$(NC)"
	-glib-compile-schemas $(PREFIX)/share/glib-2.0/schemas/ 2>/dev/null || true
	@echo "$(YELLOW)Cleaning build directory...$(NC)"
	rm -rf $(BUILD_DIR)
	@echo "$(GREEN)Purge completed! All maliit-keyboard files removed.$(NC)"

# Clean build directory
clean:
	@echo "$(YELLOW)Cleaning build directory...$(NC)"
	rm -rf $(BUILD_DIR)
	@echo "$(GREEN)Clean completed!$(NC)"

# Rebuild from scratch
rebuild: clean build

# Restart maliit-server
restart:
	@echo "$(YELLOW)Restarting maliit-server...$(NC)"
	-killall maliit-server 2>/dev/null || true
	@sleep 1
	maliit-server &
	@echo "$(GREEN)maliit-server restarted!$(NC)"

# Run tests
test: build
	@echo "$(GREEN)Running tests...$(NC)"
	cd $(BUILD_DIR) && cmake .. -Denable-tests=ON
	$(MAKE) -C $(BUILD_DIR) -j$(JOBS)
	cd $(BUILD_DIR) && ctest --output-on-failure

# Debug build
debug:
	@mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && cmake .. \
		-DCMAKE_INSTALL_PREFIX=$(PREFIX) \
		-DCMAKE_BUILD_TYPE=Debug \
		-Denable-hunspell=ON \
		-Denable-tests=ON
	$(MAKE) -C $(BUILD_DIR) -j$(JOBS)

# Show build info
info:
	@echo "Build Configuration:"
	@echo "  Build directory: $(BUILD_DIR)"
	@echo "  Install prefix:  $(PREFIX)"
	@echo "  Parallel jobs:   $(JOBS)"
	@echo ""
	@echo "Languages enabled:"
	@echo "  - English (en)"
	@echo "  - Japanese (ja) - requires libanthy-dev"
