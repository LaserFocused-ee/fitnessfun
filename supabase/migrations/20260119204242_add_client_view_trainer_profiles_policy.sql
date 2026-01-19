-- Allow clients to view their trainer's profile
-- (Symmetric policy to "Trainers can view client profiles")
CREATE POLICY "Clients can view trainer profiles" ON profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM trainer_clients tc
      WHERE tc.client_id = auth.uid()
        AND tc.trainer_id = profiles.id
        AND tc.status = 'active'
    )
  );
