SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_ASN_TALLYSHT_032                              */
/* Creation Date:  10-AUG-2023                                             */
/* Copyright: MAERSK                                                       */
/* Written by: Aftab                                                       */
/*                                                                         */
/* Purpose: WMS-23341 & WMS-23243 - Migrate WMS report to Logi Report      */
/*                                                                         */
/* Called By:RPT_ASN_TALLYSHT_032                                          */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver Purposes                                     */
/* 09-Aug-2023  WLChooi   1.0 DevOps Combine Script                        */
/***************************************************************************/
CREATE   PROC [dbo].[isp_RPT_ASN_TALLYSHT_032]
(@c_Receiptkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue INT           = 1
         , @n_err      INT           = 0
         , @c_errmsg   NVARCHAR(255) = N''
         , @b_Success  INT           = 1
   DECLARE @n_StartTCnt INT = @@TRANCOUNT

   SELECT STORER.Company
        , RECEIPT.ReceiptKey
        , RECEIPT.CarrierReference
        , RECEIPT.StorerKey
        , RECEIPT.CarrierName
        , PO.SellerName
        , RECEIPT.ReceiptDate
        , RECEIPTDETAIL.Sku
        , RECEIPTDETAIL.Lottable02 AS receiptdetail_lottable02
        , SKU.DESCR
        , IIF(ISNULL(SKU.Lottable04Label,'') = '', 'N', 'Y') AS Lottable04Label
        , RECEIPTDETAIL.UOM
        , SUM(RECEIPTDETAIL.QtyExpected) AS QtyExp
        , SUM(RECEIPTDETAIL.QtyExpected / NULLIF(CASE RECEIPTDETAIL.UOM
                                                      WHEN PACK.PackUOM1 THEN PACK.CaseCnt
                                                      WHEN PACK.PackUOM2 THEN PACK.InnerPack
                                                      WHEN PACK.PackUOM3 THEN 1
                                                      WHEN PACK.PackUOM4 THEN PACK.Pallet
                                                      WHEN PACK.PackUOM5 THEN PACK.Cube
                                                      WHEN PACK.PackUOM6 THEN PACK.GrossWgt
                                                      WHEN PACK.PackUOM7 THEN PACK.NetWgt
                                                      WHEN PACK.PackUOM8 THEN PACK.OtherUnit1
                                                      WHEN PACK.PackUOM9 THEN PACK.OtherUnit2 END, 0)) AS RECQtyExp
        , RECEIPT.CarrierAddress1
        , RECEIPT.POKey
        , PACK.CaseCnt
        , RECEIPTDETAIL.Lottable03
        , RECEIPT.Signatory
        , RECEIPT.UserDefine01
        , RECEIPT.Facility
        , RECEIPTDETAIL.Lottable01
        , RECEIPT.ContainerKey
        , RECEIPT.ContainerType
        , RECEIPTDETAIL.ReceiptLineNumber
        , SKU.RETAILSKU
        , SKU.ALTSKU
        , SKU.MANUFACTURERSKU
        , CONVERT(CHAR(20), SUSER_SNAME()) AS userid
        , RECEIPT.ExternReceiptKey
        , SKU.SUSR3
        , SKU.SUSR4
        , SKU.ShelfLife
        , CONVERT(NVARCHAR(10), DATEADD(DAY, SKU.ShelfLife, RECEIPT.ReceiptDate), 101) AS ExpDate
        , ISNULL(SKU.BUSR10, '') AS BUSR10
        , RECEIPTDETAIL.Lottable09
        , RECEIPT.Notes
        , SKU.LOTTABLE02LABEL
        , RECEIPTDETAIL.Lottable12
        , IIF(ISNULL(SKU.Lottable08Label,'') = '', 'N', 'Y') AS Lottable08Label
        , IIF(ISNULL(SKU.Lottable10Label,'') = '', 'N', 'Y') AS Lottable10Label
        , RECEIPTDETAIL.Lottable11
        , RECEIPTDETAIL.ExternPoKey
        , RECEIPTDETAIL.UserDefine02
        , SKUGroup = CASE WHEN RECEIPTDETAIL.StorerKey = 'IDSMED' THEN SKU.SKUGROUP
                          ELSE '' END
        , RECEIPTDETAIL.ToLoc
        , ISNULL(CL.Short, '') AS ShowToLoc
        , ISNULL(RECEIPTDETAIL.Lottable06, '') AS Lottable06
   FROM RECEIPT (NOLOCK)
   JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey
   JOIN STORER (NOLOCK) ON RECEIPTDETAIL.StorerKey = STORER.StorerKey
   JOIN SKU (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku
   JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
   LEFT OUTER JOIN PO (NOLOCK) ON (PO.POKey = RECEIPTDETAIL.POKey)
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (   CL.LISTNAME = 'REPORTCFG'
                                          AND CL.Code = 'ShowToLoc'
                                          AND CL.Long = 'RPT_ASN_TALLYSHT_032'
                                          AND CL.Storerkey = RECEIPTDETAIL.StorerKey)
   WHERE (RECEIPT.ReceiptKey = @c_Receiptkey)
   GROUP BY STORER.Company
          , RECEIPT.ReceiptKey
          , RECEIPT.CarrierReference
          , RECEIPT.StorerKey
          , RECEIPT.CarrierName
          , PO.SellerName
          , RECEIPT.ReceiptDate
          , RECEIPTDETAIL.Sku
          , RECEIPTDETAIL.Lottable02
          , SKU.DESCR
          , RECEIPTDETAIL.UOM
          , RECEIPT.CarrierAddress1
          , RECEIPT.POKey
          , PACK.CaseCnt
          , RECEIPTDETAIL.Lottable03
          , RECEIPT.Signatory
          , RECEIPT.UserDefine01
          , RECEIPT.Facility
          , RECEIPTDETAIL.Lottable01
          , RECEIPT.ContainerKey
          , RECEIPT.ContainerType
          , RECEIPTDETAIL.ReceiptLineNumber
          , SKU.RETAILSKU
          , SKU.ALTSKU
          , SKU.MANUFACTURERSKU
          , RECEIPT.ExternReceiptKey
          , SKU.SUSR3
          , SKU.SUSR4
          , SKU.ShelfLife
          , SKU.BUSR10
          , RECEIPT.Notes
          , SKU.LOTTABLE02LABEL
          , RECEIPTDETAIL.Lottable12
          , RECEIPTDETAIL.ExternPoKey
          , RECEIPTDETAIL.UserDefine02
          , CASE WHEN RECEIPTDETAIL.StorerKey = 'IDSMED' THEN SKU.SKUGROUP
                 ELSE '' END
          , RECEIPTDETAIL.ToLoc
          , ISNULL(CL.Short, '')
          , ISNULL(RECEIPTDETAIL.Lottable06, '')
          , IIF(ISNULL(SKU.Lottable08Label,'') = '', 'N', 'Y')
          , IIF(ISNULL(SKU.Lottable10Label,'') = '', 'N', 'Y')
          , RECEIPTDETAIL.Lottable09
          , RECEIPTDETAIL.Lottable11
          , IIF(ISNULL(SKU.Lottable04Label,'') = '', 'N', 'Y')
   ORDER BY RECEIPT.ReceiptKey
          , RECEIPTDETAIL.ReceiptLineNumber

   QUIT_SP:
   IF @n_continue = 3
   BEGIN
      SET @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RPT_ASN_TALLYSHT_032'
      RAISERROR(@c_errmsg, 16, 1) WITH SETERROR
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN TRAN;

END

GO