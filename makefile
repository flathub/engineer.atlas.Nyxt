# SPDX-FileCopyrightText: Atlas Engineer LLC
# SPDX-License-Identifier: BSD-3-Clause

FLATPAK_COMMAND = flatpak
FLATPAK_BUILDER = flatpak-builder
FLATPAK_APP_ID = engineer.atlas.Nyxt
FLATPAK_MANIFEST := $(FLATPAK_APP_ID).yaml

.PHONY: flatpak-build
flatpak-build:
	@$(FLATPAK_BUILDER) --force-clean --user --install --default-branch=local-flathub build $(FLATPAK_MANIFEST)

.PHONY: flatpak-run
flatpak-run:
	@$(FLATPAK_COMMAND) update -y $(FLATPAK_APP_ID)
	@$(FLATPAK_COMMAND) run --branch=local-flathub $(FLATPAK_APP_ID)
