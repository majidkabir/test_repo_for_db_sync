SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************************/
--CN Jreport Add View to BI Schema https://jiralfl.atlassian.net/browse/WMS-20125
/* Date           Author      Ver.  Purposes									          */
/* 01-JUL-2022   TyrionYu     1.0   Raise Ticket									      */
/* 06-JUL-2022   JarekLim     1.1   Create BI view                                        */
/******************************************************************************************/
CREATE   VIEW [BI].[V_PACKDet] AS
SELECT *
  FROM dbo.PACKDet WITH (NOLOCK)

GO