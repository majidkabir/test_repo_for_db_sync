SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_ASN_Extended_Validation] AS
SELECT sc.Storerkey, c.LISTNAME [RoleCode], c.Code [SubRole], c.Short AS [Action],
   CASE [Short]
      WHEN 'CONDITION' THEN CASE WHEN ISNULL(RTRIM(Long), '') = '' THEN 'EXISTS' ELSE RTRIM(Long) END + ' - ' + Notes
      ELSE Long
   END AS [Statement]
FROM StorerConfig sc WITH (NOLOCK)
JOIN CODELKUP c WITH (NOLOCK) ON c.LISTNAME = sc.SValue
WHERE sc.ConfigKey = 'ASNExtendedValidation'

GO