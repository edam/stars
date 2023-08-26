
-- prizes
CREATE TABLE prizes (
  id INTEGER PRIMARY KEY ASC NOT NULL,
  starval INT NOT NULL,
  goal INT NOT NULL,
  start STRING,
  end STRING
);

INSERT INTO prizes VALUES (1, 2, 300, '2023-08-18', NULL);

-- stars
CREATE TABLE stars (
  id INTEGER PRIMARY KEY ASC NOT NULL,
  at STRING NOT NULL,
  got BOOL,
  prize_id INTEGER NOT NULL
);

INSERT INTO stars VALUES (NULL, '2023-08-19', true, 1);
INSERT INTO stars VALUES (NULL, '2023-08-20', false, 1);
INSERT INTO stars VALUES (NULL, '2023-08-21', true, 1);

INSERT INTO stars VALUES (NULL, '2023-08-26', NULL, 1);
INSERT INTO stars VALUES (NULL, '2023-08-27', NULL, 1);
INSERT INTO stars VALUES (NULL, '2023-08-28', NULL, 1);
INSERT INTO stars VALUES (NULL, '2023-08-29', NULL, 1);
