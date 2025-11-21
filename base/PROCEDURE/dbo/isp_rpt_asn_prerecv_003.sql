SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_ASN_PRERECV_003                               */
/* Creation Date: 04-FEB-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: Harshitha                                                   */
/*                                                                         */
/* Purpose: WMS-18873 - r_dw_receivinglabel22                              */
/*                                                                         */
/* Called By: RPT_ASN_PRERECV_003                                          */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author      Ver. Purposes                                  */
/* 07-Feb-2022  WLChooi     1.0  DevOps Combine Script                     */
/***************************************************************************/
CREATE PROC [dbo].[isp_RPT_ASN_PRERECV_003]
   @c_Receiptkey       NVARCHAR(10)
 , @c_ReceiptLineStart NVARCHAR(5)
 , @c_ReceiptLineEnd   NVARCHAR(5)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Storerkey     NVARCHAR(15)
         , @c_CarrierName   NVARCHAR(30)
         , @c_CustLot2Label NVARCHAR(60)
         , @c_CustLot3Label NVARCHAR(60)


   SET @c_Storerkey = N''
   SET @c_CarrierName = N''
   SET @c_CustLot2Label = N''
   SET @c_CustLot3Label = N''

   CREATE TABLE #TMP_CL
   (
      Storerkey           NVARCHAR(15)
    , CarrierName         NVARCHAR(30)
    , CustLot2Label       NVARCHAR(60)
    , CustLot3Label       NVARCHAR(60)
    , ShowCarrierName     INT
    , ShowLot4BlankIfNull INT
    , PrintPreRecv        INT
    , showLot06           INT
   )

   IF ISNULL(@c_ReceiptLineStart,'') = '' SET @c_ReceiptLineStart = '00001'
   IF ISNULL(@c_ReceiptLineEnd,'') = ''   SET @c_ReceiptLineEnd = 'ZZZZZ'

   INSERT INTO #TMP_CL (Storerkey, CarrierName, CustLot2Label, CustLot3Label, ShowCarrierName, ShowLot4BlankIfNull
                      , PrintPreRecv, showLot06)
   SELECT Storerkey = RH.StorerKey
        , CarrierName = MAX(CASE WHEN CL.Code = 'ShowCarrierName' THEN ISNULL(RTRIM(RH.CarrierName), '')
                                 ELSE '' END)
        , CustLot2Label = MAX(CASE WHEN CL.Code = 'ShowCustLot2Label' THEN 'Batch Number (L2):'
                                   ELSE '' END)
        , CustLot3Label = MAX(CASE WHEN CL.Code = 'ShowCustLot3Label' THEN 'Customer Order Number (L3):'
                                   ELSE '' END)
        , ShowCarrierName = MAX(CASE WHEN CL.Code = 'ShowCarrierName' THEN 1
                                     ELSE 0 END)
        , ShowLot4BlankIfNULL = MAX(CASE WHEN CL.Code = 'ShowLot4BlankIfNULL' THEN 1
                                         ELSE 0 END)
        , PrintPreRecv = MAX(CASE WHEN CL.Code = 'PrintPreRecv' THEN 1
                                  ELSE 0 END)
        , showlot06 = MAX(CASE WHEN CL.Code = 'showLot06' THEN 1
                               ELSE 0 END)
   FROM RECEIPT RH WITH (NOLOCK)
   JOIN CODELKUP CL WITH (NOLOCK) ON  (CL.LISTNAME = 'REPORTCFG')
                                  AND (CL.Storerkey = RH.StorerKey)
                                  AND (CL.Long = 'RPT_ASN_PRERECV_003')
                                  AND (  CL.Short IS NULL
                                    OR   CL.Short <> 'N')
   WHERE ReceiptKey = @c_Receiptkey
   GROUP BY RH.StorerKey

   SELECT RECEIPTDETAIL.ReceiptKey
        , RECEIPTDETAIL.ReceiptLineNumber
        , RECEIPTDETAIL.StorerKey
        , RECEIPTDETAIL.Sku
        , RECEIPTDETAIL.ToLoc
        , RECEIPTDETAIL.PutawayLoc
        , RECEIPTDETAIL.Lottable01
        , RECEIPTDETAIL.Lottable02
        , RECEIPTDETAIL.Lottable03
        , Lottable04 = CASE WHEN CL.ShowLot4BlankIfNull = 1
                            AND  RECEIPTDETAIL.Lottable04 = '1900-01-01' THEN NULL
                            ELSE CONVERT(NVARCHAR(10), RECEIPTDETAIL.Lottable04, 111) --RECEIPTDETAIL.Lottable04
                       END
        , RECEIPTDETAIL.Lottable05
        , RECEIPTDETAIL.QtyExpected
        , RECEIPTDETAIL.QtyReceived
        , RECEIPTDETAIL.BeforeReceivedQty
        , RECEIPTDETAIL.ToId
        , RECEIPTDETAIL.POKey
        , SKU.DESCR
        , SKU.LOTTABLE01LABEL
        , SKU.LOTTABLE02LABEL
        , SKU.LOTTABLE03LABEL
        , SKU.LOTTABLE04LABEL
        , SKU.LOTTABLE05LABEL
        , PACK.CaseCnt
        , PACK.Qty
        , PACK.PalletTI
        , PACK.PalletHI
        , PACK.PackDescr
        , LOC.PutawayZone
        , SKU.PutawayZone
        , LOC.Facility
        , LOC_b.PutawayZone
        , CL.ShowCarrierName
        , CL.CarrierName
        , CL.CustLot2Label
        , CL.CustLot3Label
        , ISNULL(CL.showLot06, 0) AS showLot06
        , SKU.LOTTABLE06LABEL
        , RECEIPTDETAIL.Lottable06
   FROM RECEIPTDETAIL WITH (NOLOCK)
   JOIN SKU WITH (NOLOCK) ON  (RECEIPTDETAIL.StorerKey = SKU.StorerKey)
                          AND (RECEIPTDETAIL.Sku = SKU.Sku)
   JOIN PACK WITH (NOLOCK) ON (PACK.PackKey = SKU.PACKKey)
   JOIN LOC WITH (NOLOCK) ON (LOC.Loc = RECEIPTDETAIL.ToLoc)
   LEFT JOIN LOC LOC_b WITH (NOLOCK) ON (LOC_b.Loc = RECEIPTDETAIL.PutawayLoc)
   LEFT JOIN #TMP_CL CL ON (RECEIPTDETAIL.StorerKey = CL.Storerkey)
   WHERE (  (RECEIPTDETAIL.ReceiptKey = @c_Receiptkey)
      AND   (RECEIPTDETAIL.ReceiptLineNumber >= @c_ReceiptLineStart)
      AND   (RECEIPTDETAIL.ReceiptLineNumber <= @c_ReceiptLineEnd))
   AND   (RECEIPTDETAIL.ToId <> '')
   AND   (RECEIPTDETAIL.QtyReceived >= CASE WHEN ISNULL(PrintPreRecv,0) = 1 THEN 0
                                            ELSE 1 END)
   ORDER BY RECEIPTDETAIL.ReceiptKey, RECEIPTDETAIL.ReceiptLineNumber

END

GO