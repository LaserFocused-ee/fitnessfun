-- Migrate any existing notes to instructions (where instructions is empty)
UPDATE exercises
SET instructions = notes
WHERE (instructions IS NULL OR instructions = '')
  AND notes IS NOT NULL
  AND notes != '';

-- Drop the notes column
ALTER TABLE exercises DROP COLUMN notes;
