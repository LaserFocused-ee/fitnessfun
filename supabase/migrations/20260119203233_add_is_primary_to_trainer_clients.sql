-- Add is_primary column to trainer_clients
-- Only one trainer can be primary per client (enforced in application)
ALTER TABLE trainer_clients
ADD COLUMN is_primary boolean NOT NULL DEFAULT false;

-- Create index for efficient lookup of primary trainer
CREATE INDEX idx_trainer_clients_primary ON trainer_clients (client_id, is_primary) WHERE is_primary = true;

-- Create a function to set primary trainer (unsets others first)
CREATE OR REPLACE FUNCTION set_primary_trainer(p_relationship_id uuid, p_client_id uuid)
RETURNS void AS $$
BEGIN
  -- Unset all other primary trainers for this client
  UPDATE trainer_clients
  SET is_primary = false
  WHERE client_id = p_client_id AND is_primary = true;

  -- Set the new primary trainer
  UPDATE trainer_clients
  SET is_primary = true
  WHERE id = p_relationship_id AND client_id = p_client_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION set_primary_trainer(uuid, uuid) TO authenticated;
