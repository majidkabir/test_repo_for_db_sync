SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
--PH_Unilever - LogiReport - Pre-allocation Pick Detail Report SP https://jiralfl.atlassian.net/browse/WMS-21813
/* Date         Author      Ver.  Purposes                                 */
/* 24-FEB-2020  JarekLim     1.0   Created                                  */
/***************************************************************************/
CREATE   VIEW [BI].[V_PREALLOCATEPICKDETAIL]  AS
SELECT *
FROM [dbo].[PreAllocatePickDetail] WITH (NOLOCK)

GO