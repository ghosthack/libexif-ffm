# Publishing to Maven Central

Publishing is gated by a non-prerelease GitHub Release. Pushes and pull
requests only build and test; they never publish.

## Release procedure

1. Replace the SNAPSHOT version in the parent and both module poms, and update
   versioned documentation.
2. Merge the release commit to `main` and wait for CI to pass.
3. Publish a GitHub Release tagged `v<version>` at that exact commit.
4. The release workflow validates the tag, rebuilds and tests all three native
   classifiers from source, and deploys those exact artifacts to Maven Central.

Configure `MAVEN_CENTRAL_USERNAME`, `MAVEN_CENTRAL_PASSWORD`,
`GPG_PRIVATE_KEY`, and `GPG_PASSPHRASE` as repository Actions secrets.

`mvn -Prelease -Dgpg.skip=true clean verify` checks sources, javadocs, and
packaging locally without publishing. Published releases are immutable; use a
new version for changed content.
