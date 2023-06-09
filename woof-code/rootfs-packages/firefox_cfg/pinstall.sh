# can be firefox or firefox-esr
for FFDIR in usr/lib*/firefox*; do break; done

cat << EOF > ${FFDIR}/puppy.cfg
//

// use less vertical space
defaultPref("browser.compactmode.show", true);
defaultPref("browser.uidensity", 1);

// render website text while fetching images
defaultPref("nglayout.initialpaint.delay", 0);

// run smoother without GPU acceleration
defaultPref("general.smoothScroll", false);

// use less disk space and write less often
defaultPref("browser.cache.disk.enable", false);
defaultPref("browser.cache.memory.enable", true);
defaultPref("browser.sessionstore.resume_from_crash", false);

// limit the number of content processes to use less RAM
defaultPref("dom.ipc.processCount", 4);

// disable annoyances
defaultPref("browser.ctrlTab.recentlyUsedOrder", false);
defaultPref("browser.aboutwelcome.enabled", false);
defaultPref("startup.homepage_welcome_url", "");
defaultPref("browser.newtabpage.enabled", false);
defaultPref("trailhead.firstrun.didSeeAboutWelcome", true);
defaultPref("extensions.pocket.enabled", false);
defaultPref("extensions.screenshots.disabled", true);
defaultPref("browser.messaging-system.whatsNewPanel.enabled", false);
defaultPref("browser.uitour.enabled", false);
defaultPref("identity.fxaccounts.enabled", false);
defaultPref("identity.fxaccounts.toolbar.enabled", false);
defaultPref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);
defaultPref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false);
defaultPref("browser.tabs.firefox-view", false);

// disable autoplay
defaultPref("media.autoplay.default", 5);

// use an external PDF viewer
defaultPref("pdfjs.disabled", true);

// privacy
defaultPref("privacy.trackingprotection.enabled", true);
defaultPref("privacy.resistFingerprinting", true);
defaultPref("privacy.donottrackheader.enabled", true);
defaultPref("toolkit.telemetry.enabled", false);
defaultPref("toolkit.telemetry.unified", false);
defaultPref("toolkit.telemetry.reportingpolicy.firstRun", false);
defaultPref("app.normandy.enabled", false);
defaultPref("datareporting.policy.dataSubmissionEnabled", false);
EOF

cat << EOF > ${FFDIR}/defaults/pref/puppy-settings.js
pref("general.config.obscure_value", 0);
pref("general.config.filename", "puppy.cfg");
EOF
