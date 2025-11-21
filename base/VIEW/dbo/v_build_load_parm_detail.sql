SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE VIEW V_Build_Load_Parm_Detail 
AS  
SELECT SC.StorerKey, 
       SC.Facility,
       CL.LISTNAME   AS [BL_ParameterCode],  
       ParmDet.Code  AS [Line], 
       ParmDet.Short AS [Type], 
       ParmDet.UDF01 AS [Group], 
       ParmDet.Long  AS [FieldName], 
       ParmDet.UDF03 AS [Condition], 
       ParmDet.Notes AS [Values]
FROM   StorerConfig  AS SC WITH (NOLOCK)
JOIN CODELIST AS CL WITH (NOLOCK) ON  CL.ListGroup = SC.SValue
JOIN CODELKUP AS ParmDet WITH (NOLOCK) ON  ParmDet.LISTNAME = CL.LISTNAME      
WHERE  SC.ConfigKey = 'BuildLoadParm' 

GO