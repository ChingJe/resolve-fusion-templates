-- Copy this file to local.lua (which git ignores) and fill it in. The build scripts only run when the
-- project that is open in Resolve has this name, so they can never touch another project by accident.
return {
  project = "My Lab Project",   -- name of the Resolve project to build in
  timeline = "FX Lab",          -- lab.lua creates this timeline in that project
  -- Optional: a clip in the project's media pool. lab.lua makes the lab clip from it; without it the lab clip is an
  -- empty Fusion composition. Only needed to try a template on real footage (FX_SRC=media).
  media = "some clip.mp4",
}
