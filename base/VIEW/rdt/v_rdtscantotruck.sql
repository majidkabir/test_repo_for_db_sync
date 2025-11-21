SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [RDT].[V_rdtScanToTruck]
AS Select *
FROM [RDT].[rdtScanToTruck] with (NOLOCK)

GO