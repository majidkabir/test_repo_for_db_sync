SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_receipt_report_24                          */
/* Creation Date: 22-May-2019                                            */
/* Copyright: LFL                                                        */
/* Written by: Stephen Tsang SL (HK LIT)                                 */
/*                                                                       */
/* Purpose: Receipt Summary for K-Swiss & ASICS                          */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_receipt_report_24c          */
/*                                      r_hk_receipt_report_24d          */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 23/05/2019   ML       1.1  Performance tuning                         */
/* 30/05/2019   ST       1.2  Added as_showsku                           */
/*                            , TotalVar, TotalExp, TotalRec             */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_receipt_report_24] (
       @as_storerkey          NVARCHAR(40)
     , @as_asnstatus          NVARCHAR(40)
     , @as_receiptkey         NVARCHAR(4000)
     , @as_externreceiptkey   NVARCHAR(4000)
     , @as_wh_ref             NVARCHAR(4000)
     , @as_datawindows        NVARCHAR(40) = ''
     , @as_showsku            NVARCHAR(1)  = 'N'
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_DataWindow      NVARCHAR(40)

   SET @c_DataWindow = 'r_hk_receipt_report_24'

   IF OBJECT_ID('tempdb..#TEMP_RECEIPTKEY') IS NOT NULL
      DROP TABLE #TEMP_RECEIPTKEY
   IF OBJECT_ID('tempdb..#TEMP_RECEIPTDETAIL') IS NOT NULL
      DROP TABLE #TEMP_RECEIPTDETAIL
   IF OBJECT_ID('tempdb..#TEMP_RECEIPTDETAIL_WHREF') IS NOT NULL
      DROP TABLE #TEMP_RECEIPTDETAIL_WHREF
   IF OBJECT_ID('tempdb..#TEMP_RECEIPT') IS NOT NULL
      DROP TABLE #TEMP_RECEIPT
   IF OBJECT_ID('tempdb..#TEMP_RECEIPT_DUP') IS NOT NULL
      DROP TABLE #TEMP_RECEIPT_DUP
   IF OBJECT_ID('tempdb..#TEMP_RESULT') IS NOT NULL
      DROP TABLE #TEMP_RESULT

   -- Get #TEMP_RECEIPTKEY
   SELECT ReceiptKey
        , WarehouseReference
   INTO #TEMP_RECEIPTKEY
   FROM dbo.Receipt(NOLOCK)
   WHERE StorerKey = @as_storerkey
       AND ASNStatus IN (SELECT LTRIM(ColValue) FROM dbo.fnc_DelimSplit(',', replace(@as_asnstatus, CHAR(13) + CHAR(10), ',')) WHERE ColValue <> '')
       AND (ISNULL(@as_receiptkey, '') <> '' OR ISNULL(@as_externreceiptkey, '') <> '' OR ISNULL(@as_wh_ref, '') <> '')
       AND (ISNULL(@as_receiptkey, '') = '' OR ReceiptKey IN (SELECT LTRIM(ColValue) FROM dbo.fnc_DelimSplit(',', replace(@as_receiptkey, CHAR(13) + CHAR(10), ',')) WHERE ColValue <> ''))
       AND (ISNULL(@as_externreceiptkey, '') = '' OR ExternReceiptKey IN (SELECT LTRIM(ColValue) FROM dbo.fnc_DelimSplit(',', replace(@as_externreceiptkey, CHAR(13) + CHAR(10), ',')) WHERE ColValue <> ''))
       AND (ISNULL(@as_wh_ref, '') = '' OR Warehousereference IN (SELECT LTRIM(ColValue) FROM dbo.fnc_DelimSplit(',', replace(@as_wh_ref, CHAR(13) + CHAR(10), ',')) WHERE ColValue <> ''))


   -- Get #TEMP_RECEIPTDETAIL
   SELECT Storerkey          = RTRIM( RH.Storerkey )
        , ReceiptKey         = RTRIM( RH.ReceiptKey )
        , WarehouseReference = RTRIM( RH.WarehouseReference )
        , ToLoc              = RTRIM( RD.ToLoc )
        , Sku                = RTRIM( RD.Sku )
        , ToId               = RTRIM( RD.ToId )
        , ScanQty            = SUM(RD.BeforeReceivedQty)
     INTO #TEMP_RECEIPTDETAIL
     FROM #TEMP_RECEIPTKEY RK
     JOIN dbo.Receipt RH(NOLOCK) ON RK.Receiptkey = RH.Receiptkey
     JOIN dbo.receiptdetail RD(NOLOCK) ON RH.Receiptkey = RD.Receiptkey
    GROUP BY RH.Storerkey
           , RH.ReceiptKey
           , RH.WarehouseReference
           , RD.ToLoc
           , RD.Sku
           , RD.ToId

   -- Get #TEMP_RECEIPTDETAIL_WHREF
   SELECT Storerkey          = RTRIM( RH.Storerkey )
        , WarehouseReference = RTRIM( RH.WarehouseReference )
        , Sku                = RTRIM( RD.Sku )
        , ToId               = RTRIM( RD.ToId )
        , QtyExpected        = SUM(RD.QtyExpected)
        , Beforereceivedqty  = SUM(RD.Beforereceivedqty)
        , TotalVar           = SUM(RD.Beforereceivedqty) - SUM(RD.QtyExpected)
     INTO #TEMP_RECEIPTDETAIL_WHREF
     FROM dbo.Receipt RH(NOLOCK)
     JOIN dbo.receiptdetail RD(NOLOCK) ON RH.Receiptkey = RD.Receiptkey
    WHERE RH.Storerkey = @as_storerkey
      AND RH.WarehouseReference IN (SELECT DISTINCT WarehouseReference FROM #TEMP_RECEIPTKEY WHERE ISNULL(WarehouseReference,'')<>'')
     GROUP BY RH.Storerkey
            , RH.WarehouseReference
            , RD.Sku
            , RD.ToId


   -- Get #TEMP_RECEIPT
   SELECT Y.StorerKey
        , Y.WarehouseReference
        --, Y.ToLoc
        , Y.Sku
        , Y.SkuBefQtyOfToidW
        , WHRef_Sku_Qty_Key = LTRIM(RTRIM(Y.Sku)) + '@' + Y.SkuBefQtyOfToidW
        , Duplicate_Cnt = COUNT(DISTINCT Y.ToId)
   INTO #TEMP_RECEIPT
   FROM (
      SELECT X.Storerkey
           , X.WarehouseReference
           , X.Toloc
           , X.Sku
           , X.ToId
           , SkuBefQtyOfToidW = STUFF((
                SELECT DISTINCT ', '+ IIF(a.Beforereceivedqty<>0, RTRIM(ISNULL(a.warehousereference,''))
                       +'@'+ RTRIM(ISNULL(a.sku,'')) +'@'+ ISNULL(CAST(a.Beforereceivedqty AS NVARCHAR(10)),''), '')
                FROM #TEMP_RECEIPTDETAIL_WHREF a
                WHERE a.Storerkey=X.Storerkey AND a.WarehouseReference = X.WarehouseReference AND a.ToId = X.ToId
                ORDER BY 1
                FOR XML PATH('')
             ), 1, 2, '')
      FROM #TEMP_RECEIPTDETAIL X
   ) Y
   GROUP BY Y.StorerKey
          , Y.WarehouseReference
          --, Y.Toloc
          , Y.Sku
          , Y.SkuBefQtyOfToidW
   HAVING COUNT(DISTINCT Y.ToId) > 1


   -- Get #TEMP_RECEIPT_DUP
   SELECT DISTINCT
          Y.Storerkey
        , Y.ToId
        , Y.SkuBefQtyOfToidW
   INTO #TEMP_RECEIPT_DUP
   FROM (
      SELECT X.Storerkey
           , X.WarehouseReference
           , X.ToId
           , X.Sku
           , SkuBefQtyOfToidW = LTRIM( RTRIM( X.Sku ) ) +'@'+ STUFF((
                SELECT DISTINCT ', '+ IIF(a.Beforereceivedqty<>0, RTRIM(ISNULL(a.warehousereference,''))
                       +'@'+ RTRIM(ISNULL(a.sku,'')) +'@'+ ISNULL(CAST(a.Beforereceivedqty AS NVARCHAR(10)),''), '')
                FROM #TEMP_RECEIPTDETAIL_WHREF a
                WHERE a.Storerkey=X.Storerkey AND a.WarehouseReference = X.WarehouseReference AND a.ToId = X.ToId
                ORDER BY 1
                FOR XML PATH('')
             ), 1, 2, '')
      FROM (
         SELECT DISTINCT
                Storerkey
              , WarehouseReference
              , ToId
              , Sku
         FROM #TEMP_RECEIPTDETAIL
         WHERE ISNULL(ToId,'')<>''
   ) X
   ) Y
   JOIN (
      SELECT WHRef_Sku_Qty_Key
        , Duplicate_Cnt = MAX(Duplicate_Cnt)
  FROM #TEMP_RECEIPT
       GROUP BY WHRef_Sku_Qty_Key
   ) Z ON Y.SkuBefQtyOfToidW = Z.WHRef_Sku_Qty_Key


   -- Get Result Set
   SELECT Storerkey          = X.Storerkey
        , CustomerGroupCode  = LTRIM( RTRIM( X.CustomerGroupCode ) )
        , Receiptkey         = X.Receiptkey
        , WarehouseReference = X.WarehouseReference
        , ContainerQty       = IIF(SeqNoReceiptKey=1, X.ContainerQty, 0)
        , ToLoc              = X.ToLoc
        , ToId               = X.ToId
        , IssueID            = IIF( (X.RecQtyW - X.ExpQtyW) <> 0, 'Y', 'N')
        , ProblemID          = X.ProblemID
        , Style              = X.Style
        , Color              = X.Color
        , SIZE               = X.SIZE
        , Sku                = X.Sku
        , SkuVar             = X.SkuVar
        , Scanned            = X.Scanned
        , Brand              = X.Brand
        , SimilartoidW       = ISNULL( STUFF ( ( SELECT DISTINCT ', ' + a.ToId FROM #TEMP_RECEIPT_DUP a
                                      WHERE a.Storerkey = X.Storerkey AND a.SkuBefQtyOfToidW = X.SkuBefQtyOfToidW AND ISNULL(a.ToId,'')<>''
                                      ORDER BY 1 FOR XML PATH ('') ), 1, 2, ''), '')
        , QtyExpected        = X.QtyExpected
        , ExpQtyW            = X.ExpQtyW
        , RecQtyW            = X.RecQtyW
        , SkuVarW            = X.RecQtyW - X.ExpQtyW
        , WH_RSku_Show       = IIF( X.ExpQtyW > 0 AND X.Scanned = 0, 'N', 'Y' )
        , Duplicate_Cnt      = IIF( ISNULL(Y.Duplicate_Cnt,0)=0, 0, Y.Duplicate_Cnt )
        , TotalVar           = Z.TotalVar
        , TotalRec           = Z.TotalRec
        , TotalExp           = Z.TotalExp
   INTO #TEMP_RESULT
   FROM (
      SELECT StorerKey          = RTRIM( RH.StorerKey )
           , ReceiptKey         = RTRIM( RH.ReceiptKey )
           , WarehouseReference = RTRIM( RH.WarehouseReference )
           , Sku                = RTRIM( RD.Sku )
           , ToLoc              = RTRIM( RD.ToLoc )
           , ToId               = RTRIM( RD.ToId )
           , ContainerQty       = MAX( RH.ContainerQty )
           , CustomerGroupCode  = MAX( RTRIM( ST.CustomerGroupCode ) )
           , Style              = MAX( RTRIM( SKU.Style ) )
           , Color              = MAX( RTRIM( SKU.Color ) )
           , Size               = MAX( RTRIM( SKU.Size ) )
           , Scanned            = SUM( RD.BeforeReceivedQty )
           , Brand              = RTRIM(ISNULL(CASE (select top 1 b.ColValue
                                             from dbo.fnc_DelimSplit(MAX( RptCfg2.Delim),MAX( RptCfg2.Notes)) a, dbo.fnc_DelimSplit(MAX( RptCfg2.Delim),MAX( RptCfg2.Notes2)) b
                                             where a.SeqNo=b.SeqNo and a.ColValue='Brand')
                                     WHEN 'SKUGROUP'  THEN MAX( SKU.SKUGROUP  )
                                     WHEN 'CLASS'     THEN MAX( SKU.CLASS     )
                                     WHEN 'ITEMCLASS' THEN MAX( SKU.ITEMCLASS )
                                     WHEN 'SUSR1'     THEN MAX( SKU.SUSR1     )
                                     WHEN 'SUSR2'     THEN MAX( SKU.SUSR2     )
                                     WHEN 'SUSR3'     THEN MAX( SKU.SUSR3     )
                                     WHEN 'SUSR4'     THEN MAX( SKU.SUSR4     )
                                     WHEN 'SUSR5'     THEN MAX( SKU.SUSR5     )
                                     WHEN 'BUSR1'     THEN MAX( SKU.BUSR1     )
                                     WHEN 'BUSR2'     THEN MAX( SKU.BUSR2     )
                                     WHEN 'BUSR3'     THEN MAX( SKU.BUSR3     )
                                     WHEN 'BUSR4'     THEN MAX( SKU.BUSR4     )
                                     WHEN 'BUSR5'     THEN MAX( SKU.BUSR5     )
                                     WHEN 'BUSR6'     THEN MAX( SKU.BUSR6     )
                                     WHEN 'BUSR7'     THEN MAX( SKU.BUSR7     )
                                     WHEN 'BUSR8'     THEN MAX( SKU.BUSR8     )
                                     WHEN 'BUSR9'     THEN MAX( SKU.BUSR9     )
                                     WHEN 'BUSR10'    THEN MAX( SKU.BUSR10    )
                                  END, '') )
           , ProblemID          = CASE WHEN SUM( RD.BeforeReceivedQty ) = 0 OR SUBSTRING(RD.ToId, 2,7) = SUBSTRING(RD.ToLoc,4,7) THEN 'N' ELSE 'Y' END
           , SkuVar             = SUM( RD.BeforeReceivedQty ) - SUM( RD.QtyExpected )
           , QtyExpected        = SUM( RD.QtyExpected )
           , ExpQtyW            = MAX( WR.QtyExpected )
           , RecQtyW            = MAX( WR.Beforereceivedqty )
           , SkuBefQtyOfToidW   = LTRIM( RTRIM( RD.Sku ) ) +'@'+ STUFF((
                                     SELECT DISTINCT ', '+ IIF(a.Beforereceivedqty<>0, RTRIM(ISNULL(a.warehousereference,''))
                                            +'@'+ RTRIM(ISNULL(a.sku,'')) +'@'+ ISNULL(CAST(a.Beforereceivedqty AS NVARCHAR(10)),''), '')
                                     FROM #TEMP_RECEIPTDETAIL_WHREF a
                                     WHERE a.Storerkey=RH.Storerkey AND a.WarehouseReference = RH.WarehouseReference AND a.ToId = RD.ToId
                                     ORDER BY 1
                                     FOR XML PATH('')
                                  ), 1, 2, '')
           , SeqNoReceiptKey    = ROW_NUMBER() OVER(PARTITION BY RH.ReceiptKey ORDER BY RD.Sku)
      FROM #TEMP_RECEIPTKEY RK
      JOIN dbo.RECEIPT         RH (NOLOCK) ON RK.ReceiptKey = RH.ReceiptKey
      JOIN dbo.STORER          ST (NOLOCK) ON ST.Storerkey = RH.Storerkey
      JOIN dbo.RECEIPTDETAIL   RD (NOLOCK) ON RH.ReceiptKey = RD.ReceiptKey
      JOIN dbo.SKU            SKU (NOLOCK) ON RD.StorerKey = SKU.StorerKey AND RD.Sku = SKU.Sku

      LEFT JOIN (
         SELECT StorerKey
              , WarehouseReference
              , Sku
              , QtyExpected       = SUM(QtyExpected)
              , BeforeReceivedQty = SUM(BeforeReceivedQty)
          FROM #TEMP_RECEIPTDETAIL_WHREF
         GROUP BY StorerKey, WarehouseReference, Sku
      ) WR ON WR.StorerKey = RH.StorerKey AND WR.WarehouseReference = RH.WarehouseReference AND WR.Sku = RD.Sku

      LEFT JOIN (
         SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))
              , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
           FROM CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
      ) RptCfg2
      ON RptCfg2.Storerkey=RH.Storerkey AND RptCfg2.SeqNo=1

      GROUP BY RH.StorerKey
             , RH.ReceiptKey
             , RH.WarehouseReference
             , RD.Sku
             , RD.ToLoc
             , RD.ToId
   ) X
   LEFT JOIN (
      SELECT WHRef_Sku_Qty_Key
        , Duplicate_Cnt = MAX(Duplicate_Cnt)
   FROM #TEMP_RECEIPT
       GROUP BY WHRef_Sku_Qty_Key
   ) Y ON X.SkuBefQtyOfToidW = Y.WHRef_Sku_Qty_Key

   JOIN (
      SELECT WarehouseReference
           , TotalVar = SUM( TotalVar )
           , TotalExp = SUM( QtyExpected )
           , TotalRec = SUM( Beforereceivedqty )
      FROM #TEMP_RECEIPTDETAIL_WHREF
      GROUP BY WarehouseReference
   ) Z ON X.WarehouseReference = Z.WarehouseReference
   WHERE NOT ( X.ExpQtyW > 0 AND X.Scanned = 0 ) OR @as_showsku = 'Y'


   -- Final Result Set
   SELECT Storerkey
        , CustomerGroupCode
        , Receiptkey
        , WarehouseReference
        , ContainerQty
        , ToLoc
        , ToId
        , ScannedLoc    = CASE WHEN ISNULL(RecQtyW,0)<>0 THEN ToLoc END
        , ScannedId     = CASE WHEN ISNULL(RecQtyW,0)<>0 THEN ToId END
        , IssueID
        , ProblemID
        , Style
        , Color
        , SIZE
        , SKU
        , SkuVar
        , Scanned
        , Brand
        , SimilartoidW
        , Similartoid   = CASE WHEN LEN(SimilartoidW) - LEN(REPLACE(SimilartoidW,',','')) > 0
                               THEN CONVERT(NVARCHAR(10), LEN(SimilartoidW)-LEN(REPLACE(SimilartoidW,',',''))) + ') '
                                  + STUFF(REPLACE(', '+SimilartoidW,', '+ToId,''),1,2,'')
                               ELSE '' END
        , QtyExpected
        , ExpQtyW
        , RecQtyW
        , SkuVarW
        , WH_RSku_Show
        , Duplicate_Cnt
        , SkuWithVar    = IIF(ISNULL(SkuVarW,0)=0, '2', '1')
        , ASN_List      = STUFF((SELECT DISTINCT ', '+ RTRIM(ISNULL(ReceiptKey,'')) FROM #TEMP_RECEIPTKEY WHERE ReceiptKey<>''
                         ORDER BY 1 FOR XML PATH('')), 1, 2, '')
        , Brand_List    = STUFF((SELECT DISTINCT ', '+ RTRIM(ISNULL(Brand,'')) FROM #TEMP_RESULT WHERE Brand<>''
                          ORDER BY 1 FOR XML PATH('')), 1, 2, '')
        , datawindow    = @as_datawindows
        , TotalVar
        , TotalExp
        , TotalRec
     FROM #TEMP_RESULT
     ORDER BY Storerkey
            , WarehouseReference
            , Style
            , Color
            , Size
END

GO