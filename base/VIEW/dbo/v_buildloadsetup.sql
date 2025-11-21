SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE VIEW [dbo].[V_BuildLoadSetup]
AS
SELECT sc.StorerKey, sc.Facility, sc.sValue AS [ParmCode], CODELKUP.UDF01 AS [GroupLevel], 
       Long AS [ColName], CODELKUP.UDF03 AS [Operator], ISNULL(Notes,'') AS [Value], CODELKUP.UDF02 AS [Condition]
FROM   CODELKUP WITH (NOLOCK)  
JOIN CODELIST CL WITH (NOLOCK) ON CL.LISTNAME = CODELKUP.LISTNAME
JOIN StorerConfig AS sc WITH (NOLOCK) ON (sc.ConfigKey = 'BuildLoadParm' AND sc.SValue = CL.ListGroup) 
WHERE  CODELKUP.Short    = 'CONDITION'  
 


GO