//! Generates the gRPC/protobuf bindings from `proto/kumo/v1/kumo.proto`.
//! Uses a vendored `protoc` so builds never depend on the system one.

use std::path::PathBuf;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let proto_root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../proto");
    let proto_file = proto_root.join("kumo/v1/kumo.proto");

    let mut config = tonic_prost_build::Config::new();
    config.protoc_executable(protoc_bin_vendored::protoc_bin_path()?);

    tonic_prost_build::configure()
        // `bytes` fields become `bytes::Bytes`: zero-copy on the terminal hot path.
        .bytes(".")
        .compile_with_config(config, &[proto_file], &[proto_root])?;
    Ok(())
}
