SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: ispQtyExpectedAlert                                 */
/* Creation Date:                                                       */
/* Copyright: LFL                                                       */
/* Ticket Id: IN00417189                                                */
/*                                                                      */
/* Purpose: Pre-alert LOTxLOCxID.Qtyexpected > 0                        */
/*                                                                      */
/* Called By:  Scheduler job                                            */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Modifications:                                                       */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispQtyExpectedAlert]
     @c_Country   NVARCHAR(5)
   , @c_StorerKey NVARCHAR(15)
   , @c_itfDBName NVARCHAR(15)
   , @b_debug     INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ExecStatements NVARCHAR(MAX)
         , @c_ExecArguments  NVARCHAR(MAX)
         , @c_Recipients     NVARCHAR(255)
         , @c_EmailSubject   NVARCHAR(255)
         , @tableHTML        NVARCHAR(MAX)
         , @c_ListName       NVARCHAR(30)
         , @c_ConfigKey      NVARCHAR(30)

   IF ISNULL(RTRIM(@c_StorerKey),'') <> '%'
   BEGIN
      SET @c_EmailSubject = ISNULL(RTRIM(@c_Country),'') + ' | ' + ISNULL(RTRIM(@c_StorerKey),'') + ' | Over Allocate with QtyExpected > 0 | ' + + @@servername
   END
   ELSE
   BEGIN
      SET @c_EmailSubject = ISNULL(RTRIM(@c_Country),'') + ' | Over Allocate with QtyExpected > 0 | ' + + @@servername
   END

   SET @c_ListName     = 'VALIDATE'
   SET @c_ConfigKey    = 'ALLOWOVERALLOCATIONS'

   SET @c_ExecStatements = ''
   SET @c_ExecArguments  = ''
   SET @c_Recipients     = ''

   IF ISNULL(RTRIM(@c_StorerKey),'') <> '%'
   BEGIN
      SET @c_ExecStatements = N'SELECT @c_Recipients = ISNULL(RTRIM(Long),'''') ' -- Retrieve Email
                              + 'FROM ' + ISNULL(RTRIM(@c_itfDBName),'') + '.dbo.CodeLkUp WITH (NOLOCK) '
                              + 'WHERE ListName = ''' + ISNULL(RTRIM(@c_ListName),'') + ''' '
                              + 'AND Code = ''' + ISNULL(RTRIM(@c_ConfigKey),'') + ''' '
                              + 'AND StorerKey = ''' + ISNULL(RTRIM(@c_StorerKey),'') + ''' '
   END
   ELSE
   BEGIN
      SET @c_ExecStatements = N'SELECT @c_Recipients = ISNULL(RTRIM(Long),'''') ' -- Retrieve Email
                              + 'FROM ' + ISNULL(RTRIM(@c_itfDBName),'') + '.dbo.CodeLkUp WITH (NOLOCK) '
                              + 'WHERE ListName = ''' + ISNULL(RTRIM(@c_ListName),'') + ''' '
                              + 'AND Code = ''' + ISNULL(RTRIM(@c_ConfigKey),'') + ''' '
   END

   SET @c_ExecArguments = N'@c_Recipients NVARCHAR(255) OUTPUT'

   EXEC sp_ExecuteSql @c_ExecStatements
                    , @c_ExecArguments
                    , @c_Recipients OUTPUT

   IF ISNULL(OBJECT_ID('tempdb..#P'),'') <> ''
   BEGIN
      DROP TABLE #P
   END
   IF ISNULL(OBJECT_ID('tempdb..#RESULT'),'') <> ''
   BEGIN
      DROP TABLE #RESULT
   END

   CREATE TABLE #P (
        ShipFlag        NVARCHAR(1)  NULL
      , StorerKey       NVARCHAR(15) NULL
      , Sku             NVARCHAR(20) NULL
      , SkuStatus       NVARCHAR(10) NULL
      , Lot             NVARCHAR(10) NULL
      , Loc             NVARCHAR(10) NULL
      , Id              NVARCHAR(20) NULL
      , PickQty         INT          NULL
   )
   CREATE TABLE #RESULT (
        ShipFlag        NVARCHAR(1)  NULL
      , StorerKey       NVARCHAR(15) NULL
      , Sku             NVARCHAR(20) NULL
      , SkuStatus       NVARCHAR(10) NULL
      , Lot             NVARCHAR(10) NULL
      , Loc             NVARCHAR(10) NULL
      , Id              NVARCHAR(20) NULL
      , PickQty         INT          NULL
      , LLIQty          INT          NULL
      , LLIQtyAllocated INT          NULL
      , LLIQtyPicked    INT          NULL
      , LLIQtyExpected  INT          NULL
   )

   IF ISNULL(RTRIM(@c_StorerKey),'') <> '%'
   BEGIN
      INSERT INTO #P ( ShipFlag, StorerKey, Sku, SkuStatus, Lot, Loc, Id, PickQty )
      SELECT P.ShipFlag, P.StorerKey, P.Sku, UPPER(ISNULL(RTRIM(S.SkuStatus),'')) AS SkuStatus, P.Lot, P.Loc, P.Id, SUM(P.Qty) AS PickQty
      FROM PickDetail P WITH (NOLOCK)
      JOIN SKU S WITH (NOLOCK)
      ON (P.StorerKey = S.StorerKey AND P.Sku = S.Sku)
      WHERE P.StorerKey = @c_StorerKey
        AND P.[Status] <= '5' --AND P.ShipFlag = 'Y'
      GROUP BY P.ShipFlag, P.StorerKey, P.Sku, UPPER(ISNULL(RTRIM(S.SkuStatus),'')), P.Lot, P.Loc, P.Id
      ORDER BY P.StorerKey, P.Sku, P.Lot, P.Loc, P.Id
   END
   ELSE
   BEGIN -- All StorerKey
      INSERT INTO #P ( ShipFlag, StorerKey, Sku, SkuStatus, Lot, Loc, Id, PickQty )
      SELECT P.ShipFlag, P.StorerKey, P.Sku, UPPER(ISNULL(RTRIM(S.SkuStatus),'')) AS SkuStatus, P.Lot, P.Loc, P.Id, SUM(P.Qty) AS PickQty
      FROM PickDetail P WITH (NOLOCK)
      JOIN SKU S WITH (NOLOCK)
      ON (P.StorerKey = S.StorerKey AND P.Sku = S.Sku)
      WHERE P.[Status] <= '5'
      GROUP BY P.ShipFlag, P.StorerKey, P.Sku, UPPER(ISNULL(RTRIM(S.SkuStatus),'')), P.Lot, P.Loc, P.Id
      ORDER BY P.StorerKey, P.Sku, P.Lot, P.Loc, P.Id
   END

   INSERT INTO #RESULT ( ShipFlag, StorerKey, Sku, SkuStatus, Lot, Loc, Id, PickQty
                       , LLIQty, LLIQtyAllocated, LLIQtyPicked, LLIQtyExpected )
   SELECT P.ShipFlag, P.StorerKey, P.Sku, P.SkuStatus, P.Lot, P.Loc, P.Id, P.PickQty
        , ISNULL(L.Qty, 0), ISNULL(L.QtyAllocated, 0), ISNULL(L.QtyPicked, 0), ISNULL(L.QtyExpected, 0)
   FROM #P P
   LEFT JOIN LOTxLOCxID L WITH (NOLOCK)
   ON (P.StorerKey = L.StorerKey AND P.Sku = L.Sku AND P.Lot = L.Lot AND P.Loc = L.Loc AND P.Id = L.Id)
   LEFT JOIN StorerConfig S WITH (NOLOCK)
   ON (L.StorerKey = S.StorerKey AND S.ConfigKey = 'ALLOWOVERALLOCATIONS')
   WHERE ISNULL(L.QtyExpected, 0) > 0 AND ISNULL(RTRIM(S.SValue),'') <> '1'
   ORDER BY P.StorerKey, P.Sku, P.Lot, P.Loc, P.Id

   IF @b_debug = 1
   BEGIN
      SELECT @c_Recipients '@c_Recipients'
      SELECT * FROM #RESULT
   END

   IF EXISTS (SELECT 1 FROM #RESULT) AND ISNULL(RTRIM(@c_Recipients),'') <> ''
   BEGIN
      SET @tableHTML =
          N'<STYLE TYPE="text/css"> ' + CHAR(13) +
          N'<!--' + CHAR(13) +
          N'TR{font-family: Arial; font-size: 10pt;}' + CHAR(13) +
          N'TD{font-family: Arial; font-size: 9pt;}' + CHAR(13) +
          N'H3{font-family: Arial; font-size: 12pt;}' + CHAR(13) +
          N'BODY{font-family: Arial; font-size: 9pt;}' + CHAR(13) +
          N'--->' + CHAR(13) +
          N'</STYLE>' + CHAR(13) +
          N'<H3>' + @c_EmailSubject + '</H3>' +
          N'<BODY><P ALIGN="LEFT">Please check the following QtyExpected Inventory:</P></BODY>' +
          N'<TABLE BORDER="1" CELLSPACING="0" CELLPADDING="3">' +
          N'<TR BGCOLOR=#3BB9FF><TH>ShipFlag</TH><TH>StorerKey</TH><TH>Sku</TH>' +
          N'<TH>SkuStatus</TH><TH>Lot</TH><TH>Loc</TH><TH>Id</TH><TH>PickQty</TH>' +
          N'<TH>LLIQty</TH><TH>LLIQtyAlloc</TH><TH>LLIQtyPick</TH><TH>LLIQtyExp</TH>' +
          N'</TR>' +
          CAST ( ( SELECT
                     TD = A.ShipFlag, '',
                     TD = A.StorerKey, '',
                     TD = A.Sku, '',
                     TD = A.SkuStatus, '',
                     TD = A.Lot, '',
                     TD = A.Loc, '',
                     TD = A.Id, '',
                     TD = A.PickQty, '',
                     TD = A.LLIQty, '',
                     TD = A.LLIQtyAllocated, '',
                     TD = A.LLIQtyPicked, '',
                     TD = A.LLIQtyExpected, ''
                 FROM #RESULT A WITH (NOLOCK)
                   ORDER BY A.StorerKey, A.Sku, A.Lot, A.Loc, A.Id
            FOR XML PATH('TR'), TYPE
          ) AS NVARCHAR(MAX) ) +
          N'</TABLE>' ;

      EXEC msdb.dbo.sp_send_dbmail
           @recipients  = @c_Recipients,
           @subject     = @c_EmailSubject,
           @body        = @tableHTML,
           @body_format = 'HTML';
   END
END -- Procedure

GO