SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

--https://jiralfl.atlassian.net/browse/WMS-14815
CREATE   VIEW  [BI].[V_rdtSortAndPackLOC]
AS
SELECT *
FROM RDT.rdtSortAndPackLOC WITH (NOLOCK)

GO