load(":has_maven_deps.bzl", "MavenInfo", "calculate_artifact_jars", "has_maven_deps")
load(":maven_utils.bzl", "determine_additional_dependencies", "generate_pom")

def _pom_file_impl(ctx):
    # Ensure the target has coordinates
    if not ctx.attr.target[MavenInfo].coordinates:
        fail("pom_file target must have maven coordinates.")

    info = ctx.attr.target[MavenInfo]

    artifact_jars = calculate_artifact_jars(info)
    additional_deps = determine_additional_dependencies(artifact_jars, ctx.attr.additional_dependencies)

    all_maven_deps = info.maven_deps.to_list()
    for dep in additional_deps:
        for coords in dep[MavenInfo].as_maven_dep.to_list():
            all_maven_deps.append(coords)

    out = generate_pom(
        ctx,
        coordinates = info.coordinates,
        versioned_dep_coordinates = sorted(all_maven_deps),
        pom_template = ctx.file.pom_template,
        out_name = "%s.xml" % ctx.label.name,
    )

    return [
        DefaultInfo(
            files = depset([out]),
            data_runfiles = ctx.runfiles([out]),
        ),
        OutputGroupInfo(
            pom = depset([out]),
        ),
    ]

pom_file = rule(
    _pom_file_impl,
    doc = """Generate a pom.xml file that lists first-order maven dependencies.

The following substitutions are performed on the template file:

  {groupId}: Replaced with the maven coordinates group ID.
  {artifactId}: Replaced with the maven coordinates artifact ID.
  {version}: Replaced by the maven coordinates version.
  {type}: Replaced by the maven coordinates type, if present (defaults to "jar")
  {scope}: Replaced by the maven coordinates type, if present (defaults to "compile")
  {dependencies}: Replaced by a list of maven dependencies directly relied upon
    by java_library targets within the artifact.
""",
    attrs = {
        "pom_template": attr.label(
            doc = "Template file to use for the pom.xml",
            default = "//private/templates:pom.tpl",
            allow_single_file = True,
        ),
        "target": attr.label(
            doc = "The rule to base the pom file on. Must be a java_library and have a maven_coordinate tag.",
            mandatory = True,
            providers = [
                [JavaInfo],
            ],
            aspects = [
                has_maven_deps,
            ],
        ),
        "additional_dependencies": attr.label_keyed_string_dict(
            doc = "Mapping of `Label`s to the excluded workspace names",
            allow_empty = True,
            providers = [
                [JavaInfo],
            ],
            aspects = [
                has_maven_deps,
            ],
        ),
    },
)
