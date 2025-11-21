SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [RDT].[V_rdtDataCapture]
AS
SELECT *
FROM [RDT].[rdtDataCapture] WITH (nolock)


GO