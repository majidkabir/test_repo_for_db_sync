SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/* MY have exist CBOL physical table and view table early */
/* 2020-12-16 kocy  WMS-15883  create for CN Sephora      */
CREATE   VIEW [dbo].[V_CBOL]  AS
SELECT *
FROM [dbo].[CBOL] WITH (NOLOCK)

GO