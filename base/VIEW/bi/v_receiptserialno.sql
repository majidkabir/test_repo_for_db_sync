SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
--https://jiralfl.atlassian.net/browse/WMS-15595
/* Date         Author      Ver.  Purposes                                 */
/* 28-Sep-2020  KSheng      1.0   Created                                  */
/* 08-MAY-2023  JarekLIM    1.1   Created   https://jiralfl.atlassian.net/browse/WMS-22476  */
/***************************************************************************/
CREATE   VIEW [BI].[V_ReceiptSerialno]
AS
SELECT *
FROM dbo.ReceiptSerialno (NOLOCK)

GO