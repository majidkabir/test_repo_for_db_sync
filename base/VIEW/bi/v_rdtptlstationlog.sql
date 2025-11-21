SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Purpose: [KR] Add Columns to BI.V_rdtptlstationlog					   */
/* https://jiralfl.atlassian.net/browse/WMS-21098                          */
/* Creation Date: 31-OCT-2022                                              */
/*                                                                         */
/* Updates:                                                                */
/* Date          Author		  Ver.  Purposes                               */
/* 31-OCT-2022   JarekLim     1.0   Created                                */
/***************************************************************************/

CREATE   VIEW [BI].[V_rdtPTLStationLog]
AS
SELECT *
FROM rdt.rdtPTLStationLog WITH (NOLOCK)

GO