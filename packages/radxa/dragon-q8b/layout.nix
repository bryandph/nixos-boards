# Fixed GPT identifiers of layout v1 images. They keep builds reproducible and
# are replaced on first boot (randomize-disk-ids.sh); nothing mounts by them.
{
  diskId = "81ad85de-22d0-4e73-8ebb-0512b0000001";
  espId = "81ad85de-22d0-4e73-8ebb-0512b0000002";
  rootId = "81ad85de-22d0-4e73-8ebb-0512b0000003";
  # Discoverable Partitions Specification: root partition (64-bit ARM).
  rootType = "b921b045-1df0-41c3-af44-4c6f280d3fae";
}
