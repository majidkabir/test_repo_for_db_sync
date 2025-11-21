SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [RDT].[V_LookUp_TestScript]
AS
SELECT Description AS [Text] ,
       Code AS [Value] FROM dbo.Codelkup WITH (NOLOCK)
WHERE Listname = 'ASNSTATUS'



GO