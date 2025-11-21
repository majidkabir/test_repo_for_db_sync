SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_RPT_ASN_TALLYSHT_039                                */
/* Creation Date: 28-Nov-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-24283 - [CHL] - MWMS PUMA Tally Sheet CR                */
/*          Duplicate from isp_RPT_ASN_TALLYSHT_023                     */
/*                                                                      */
/* Called By: RPT_ASN_TALLYSHT_039                                      */
/*                                                                      */
/* GitHub Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 14-Dec-2022 WLChooi  1.0   DevOps Combine Script                     */
/************************************************************************/

CREATE   PROC [dbo].[isp_RPT_ASN_TALLYSHT_039]
(
   @c_Receiptkey NVARCHAR(10)
 , @c_Username   NVARCHAR(250) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue INT = 1

   SELECT RECEIPT.ReceiptKey
        , RECEIPTDETAIL.POKey
        , SKU.SKU
        , SKU.DESCR
        , RECEIPTDETAIL.UOM
        , ISNULL(RECEIPTDETAIL.Lottable01, '') AS Lottable01
        , CONVERT(
             NVARCHAR(10)
           , ISNULL([dbo].[fnc_ConvSFTimeZone](RECEIPT.StorerKey, RECEIPT.Facility, RECEIPTDETAIL.Lottable04), '1900-01-01')
           , 103) AS LOTT04
        , [dbo].[fnc_ConvSFTimeZone](RECEIPT.StorerKey, RECEIPT.Facility, RECEIPTDETAIL.Lottable05) AS Lottable05
        , STORER.Company
        , [dbo].[fnc_ConvSFTimeZone](RECEIPT.StorerKey, RECEIPT.Facility, RECEIPT.ReceiptDate) AS ReceiptDate
        , RECEIPTDETAIL.PackKey
        , RECEIPTDETAIL.QtyExpected
        , RECEIPTDETAIL.BeforeReceivedQty
        , (SUSER_SNAME()) AS username
        , PACK.PackUOM1
        , PACK.CaseCnt
        , PACK.PackUOM4
        , PACK.Pallet
        , PACK.PackUOM2
        , PACK.InnerPack
        , RECEIPT.Signatory
        , SKU.IVAS
        , RECEIPTDETAIL.ToLoc AS ToLoc
        , RECEIPT.WarehouseReference
        , RECEIPTDETAIL.ToId
        , [dbo].[fnc_ConvSFTimeZone](RECEIPT.StorerKey, RECEIPT.Facility, GETDATE()) AS CurrentDateTime
        , ISNULL(RIF.ReceiptAmount, 0.00) AS ReceiptAmount
   FROM RECEIPT WITH (NOLOCK)
   JOIN RECEIPTDETAIL WITH (NOLOCK) ON (RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey)
   JOIN STORER WITH (NOLOCK) ON (RECEIPT.StorerKey = STORER.StorerKey)
   JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku)
   JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.PackKey)
   LEFT JOIN ReceiptInfo RIF WITH (NOLOCK) ON (RIF.ReceiptKey = RECEIPT.ReceiptKey)
   WHERE (RECEIPT.ReceiptKey = @c_Receiptkey)

END

GO