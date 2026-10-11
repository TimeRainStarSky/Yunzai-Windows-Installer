fn main() -> Result<(), Box<dyn std::error::Error>> {
  let mut res = winresource::WindowsResource::new();
  res.set_manifest_file("res/manifest.xml");
  res.compile()?;
  Ok(())
}
