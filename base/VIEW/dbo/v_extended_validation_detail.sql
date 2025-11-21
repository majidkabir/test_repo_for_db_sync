SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_Extended_Validation_Detail] AS
SELECT sc.ConfigKey,
   sc.Storerkey, c.LISTNAME [RoleCode], c.Code [SubRole], c.Short AS [Action],
   CASE [Short]
      WHEN 'CONDITION' THEN CASE WHEN ISNULL(RTRIM(Long), '') = '' THEN 'EXISTS' ELSE RTRIM(Long) END + ' - ' + Notes
      WHEN 'CONTAINS' THEN ISNULL(RTRIM(Long), '') + ' IN (' + ISNULL(RTRIM(Notes),'') + ')'
      ELSE Long
   END AS [Statement],
   CASE [Short]
      WHEN 'REQUIRED' THEN ''
      ELSE ISNULL(RTRIM(Notes2),'')
   END as 'WhereCondition'
FROM StorerConfig sc WITH (NOLOCK)
JOIN CODELKUP c WITH (NOLOCK) ON c.LISTNAME = sc.SValue
WHERE sc.ConfigKey LIKE '%ExtendedValidation'


GO