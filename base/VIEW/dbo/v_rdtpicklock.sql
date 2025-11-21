SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_RDTPickLock]
AS
SELECT     RDT.rdtPickLock.*
FROM         RDT.rdtPickLock   (NOLOCK)


GO