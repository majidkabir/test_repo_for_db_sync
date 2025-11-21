SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_UploadinvData]   
AS   
SELECT [Storerkey]  
, [ExternOrderkey]  
, [Invoice_Number]  
, [Invoice_Date]  
, [Invoice_Amount]  
, [Status]  
, [Remarks]  
FROM [UploadinvData] (NOLOCK)   
GO