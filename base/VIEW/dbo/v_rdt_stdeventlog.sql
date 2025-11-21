SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_RDT_StdEventLog]  
AS  
SELECT     RDT.rdtSTDEventLog.*  
FROM         RDT.rdtSTDEventLog with (NOLOCK)
  

GO