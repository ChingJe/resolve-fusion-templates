-- Copy this file to local.lua (which git ignores) and fill it in. The build scripts only run when the
-- project that is open in Resolve has this name, so they can never touch another project by accident.
return {
  project = "My Lab Project",   -- name of the Resolve project to build in
  timeline = "FX Lab",          -- lab.lua creates this timeline in that project
  media = "some clip.mp4",      -- a clip in the project's media pool, used for the lab timeline
}
