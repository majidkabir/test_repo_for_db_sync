SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


CREATE VIEW [dbo].[V_STORERCFGxCODELKUP_COL]
( Storerkey,Configkey,Cols) AS
SELECT Storerkey
      ,Configkey
      ,Cols = ISNULL((REPLACE(REPLACE(CONVERT(VARCHAR(4000),
                              (SELECT RTRIM(Long) FROM CODELKUP WITH (NOLOCK) 
										 WHERE ListName = SC.SValue
                               AND Short = 'ENABLED'
                               FOR XML PATH('col'), TYPE)), '<col>', '<'), '</col>', '>')),'')
FROM STORERCONFIG SC WITH (NOLOCK)


GO