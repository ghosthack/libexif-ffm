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

Builds use the Maven Wrapper (`./mvnw`), which pins Maven 3.9.16. Do not
switch the release to the runner's `mvn`: under Maven 3.10 the
central-publishing plugin (0.11.0) stages resolver files such as
`_remote.repositories` and `maven-metadata-local.xml` into the bundle, and
Central rejects it with "Bundle has content that does NOT have a .pom file".

`./mvnw -Prelease -Dgpg.skip=true clean verify` checks sources, javadocs, and
packaging locally without publishing. Published releases are immutable; use a
new version for changed content.

To inspect the signed bundle CI would upload, run the Release workflow
manually (optionally with a throwaway `version`). It rebuilds all three
natives, builds against an unreachable Central URL with placeholder
credentials, and attaches `central-bundle.zip` as a workflow artifact; nothing
is published.
