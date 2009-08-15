

-- add a flag to users whose votes we want to ignore
ALTER TABLE users ADD COLUMN ign_votes boolean NOT NULL DEFAULT FALSE;

CREATE OR REPLACE FUNCTION update_vnpopularity() RETURNS void AS $$
BEGIN
  CREATE OR REPLACE TEMP VIEW tmp_pop1 (uid, vid, rank) AS
      SELECT v.uid, v.vid, sqrt(count(*))::real
        FROM votes v
--        JOIN users u ON u.id = v.uid AND NOT u.ign_votes  -- slow
        JOIN votes v2 ON v.uid = v2.uid AND v2.vote < v.vote
        WHERE v.uid NOT IN(SELECT id FROM users WHERE ign_votes) -- faster
    GROUP BY v.vid, v.uid;
  CREATE OR REPLACE TEMP VIEW tmp_pop2 (vid, win) AS
    SELECT vid, sum(rank) FROM tmp_pop1 GROUP BY vid;
  UPDATE vn SET c_popularity = COALESCE((SELECT win/(SELECT MAX(win) FROM tmp_pop2) FROM tmp_pop2 WHERE vid = id), 0);
  RETURN;
END;
$$ LANGUAGE plpgsql;



-- VN relations cleanup

UPDATE vn_relations SET relation = relation + 50 WHERE relation IN(8, 9, 10);
UPDATE vn_relations SET relation = relation - 1  WHERE relation > 3 AND relation < 50;
UPDATE vn_relations SET relation = 7 WHERE relation = 60;
DELETE FROM vn_relations WHERE relation > 50;

-- Be sure to execute the following query after restarting Multi, to regenerate the relation graphs:
--   UPDATE vn SET rgraph = NULL;

