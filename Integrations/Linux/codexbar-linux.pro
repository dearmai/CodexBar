QT += core gui widgets quick qml quickcontrols2 network dbus
CONFIG += c++17 console
CONFIG -= app_bundle
TARGET = codexbar-linux
SOURCES += main.cpp DesktopController.cpp
HEADERS += DesktopController.h
RESOURCES += desktop.qrc
# lrelease compiles the catalogs and embed_translations bundles them at :/i18n,
# so a packaged binary carries its translations with no extra install step.
CONFIG += lrelease embed_translations
TRANSLATIONS += i18n/codexbar_ko.ts
QMAKE_CXXFLAGS += -Wall -Wextra
target.path = $$PREFIX/bin
isEmpty(PREFIX): target.path = /usr/local/bin
INSTALLS += target

DESKTOP_VERSION = $$(CODEXBAR_DESKTOP_VERSION)
isEmpty(DESKTOP_VERSION): DESKTOP_VERSION = 0.1.0
DEFINES += CODEXBAR_DESKTOP_VERSION=\\\"$$DESKTOP_VERSION\\\"
