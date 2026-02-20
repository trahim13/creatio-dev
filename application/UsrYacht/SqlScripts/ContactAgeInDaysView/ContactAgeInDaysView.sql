CREATE OR REPLACE VIEW "UsrVwContactAgeDays" AS
SELECT
  "Id"        AS "UsrId",
  "Name"      AS "UsrName",
  "BirthDate" AS "UsrBirthDate",
  (CURRENT_DATE - "BirthDate"::date) AS "UsrAgeDays",
  "Id"        AS "UsrContactId"
FROM "Contact";