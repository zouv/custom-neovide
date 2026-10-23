pub const BUILD_VERSION: &str = env!("NEOVIDE_BUILD_VERSION");

// [CUSTOM-BEGIN] CUSTOM-20261024-002 - release_channel reused on Windows for --reuse-instance
#[cfg(any(target_os = "macos", target_os = "windows"))]
// [CUSTOM-END] CUSTOM-20261024-002
pub fn release_channel() -> &'static str {
    release_channel_for_build_version(BUILD_VERSION)
}

// [CUSTOM-BEGIN] CUSTOM-20261024-002 - release_channel helper reused on Windows
#[cfg(any(target_os = "macos", target_os = "windows", test))]
// [CUSTOM-END] CUSTOM-20261024-002
fn release_channel_for_build_version(build_version: &str) -> &'static str {
    if build_version.starts_with("nightly-") { "nightly" } else { "stable" }
}

#[cfg(test)]
mod tests {
    use super::release_channel_for_build_version;

    #[test]
    fn release_channel_detects_nightly_builds() {
        assert_eq!(release_channel_for_build_version("nightly-104+g438415298449"), "nightly");
        assert_eq!(release_channel_for_build_version("nightly-104+g438415298449-dirty"), "nightly");
    }

    #[test]
    fn release_channel_defaults_to_stable() {
        assert_eq!(release_channel_for_build_version("0.15.2"), "stable");
        assert_eq!(release_channel_for_build_version("0.15.2-dirty"), "stable");
    }
}
