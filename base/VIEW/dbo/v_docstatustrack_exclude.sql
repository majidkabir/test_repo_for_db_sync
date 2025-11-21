SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_DocStatusTrack_EXCLUDE]
 AS
WITH Tab1
AS (
SELECT DocumentNo FROM dbo.DocStatusTrack(NOLOCK)
	WHERE Storerkey = '18467'  AND Facility='NSH04'	AND Tablename='ASNEXCEPTION'
	AND key1 =  'Exceed'AND key2='00'
	AND Docstatus='1'
)
SELECT tab2.ROWREF,  tab1.DocumentNo
FROM DocStatusTrack(NOLOCK) tab2, tab1
WHERE tab1.DocumentNo=tab2.DocumentNo

GO