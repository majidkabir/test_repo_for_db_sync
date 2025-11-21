SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

--https://jiralfl.atlassian.net/browse/WMS-11749
CREATE   VIEW [dbo].[V_rdtSortLaneLocLog]
AS
SELECT *
FROM RDT.rdtSortLaneLocLog WITH (NOLOCK)

GO