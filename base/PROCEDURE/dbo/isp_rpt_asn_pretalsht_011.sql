SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_ASN_PRETALSHT_011                             */
/* Creation Date: 03-May-2023                                              */
/* Copyright: Maersk                                                       */
/* Written by: WZPang                                                      */
/*                                                                         */
/* Purpose: WMS-22393                                                      */
/*                                                                         */
/* Called By: RPT_ASN_PRETALSHT_011                                        */
/*                                                                         */
/* GitLab Version: 1.3                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 03-May-2023  WZPang  1.0   DevOps Combine Script                        */
/* 26-Sep-2023  WLChooi 1.1   UWP-8576 - Show ExternPOKey (WL01)           */
/* 15-Oct-2023  WLChooi 1.2   UWP-9559 - Show Notes (WL02)                 */
/* 31-Oct-2023  WLChooi 1.3   UWP-10213 - Global Timezone (GTZ01)          */
/***************************************************************************/

CREATE   PROC [dbo].[isp_RPT_ASN_PRETALSHT_011]
      @c_Receiptkey  NVARCHAR(10)

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue INT = 1, @n_err INT = 0, @c_errmsg NVARCHAR(255) = '', @b_Success INT = 1
         , @n_StartTCnt INT = @@TRANCOUNT, @c_GetReceiptKey NVARCHAR(10), @c_GetUserDefine03 NVARCHAR(30)
         , @c_GetUserDefine07 DATETIME

   CREATE TABLE #ITEMCLASS(
   RECEIPTKEY         NVARCHAR(10),
   PalletPosition     INT  )

   INSERT INTO #ITEMCLASS
   SELECT RECEIPT.RECEIPTKEY,
          COUNT(DISTINCT SKU.ITEMCLASS) + 4
   FROM RECEIPT (NOLOCK)
   JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey
   JOIN SKU (NOLOCK) ON RECEIPTDETAIL.SKU = SKU.SKU AND RECEIPT.STORERKEY = SKU.STORERKEY
   WHERE RECEIPT.ReceiptKey = @c_Receiptkey  
   GROUP BY RECEIPT.RECEIPTKEY

   SELECT RECEIPT.ReceiptKey,
          [dbo].[fnc_ConvSFTimeZone](RECEIPT.StorerKey, RECEIPT.Facility, RECEIPT.ReceiptDate) AS ReceiptDate,   --GTZ01
          RECEIPT.WarehouseReference,
          RECEIPT.ExternReceiptkey,
          RECEIPT.Facility,           
          RECEIPT.StorerKey,          
          [dbo].[fnc_ConvSFTimeZone](RECEIPT.StorerKey, RECEIPT.Facility, RECEIPT.AddDate) AS AddDate,   --GTZ01            
          RECEIPT.AddWho,             
          RECEIPT.SellerName,         
          RECEIPTDETAIL.ExternPOKey,
          RECEIPTDETAIL.Sku,
          RECEIPTDETAIL.UOM,
          RECEIPTDETAIL.PackKey,
          RECEIPTDETAIL.QtyExpected,
          RECEIPTDETAIL.FreeGoodQtyExpected,
          RECEIPTDETAIL.Lottable01,
          RECEIPTDETAIL.Lottable02,
          Lottable03 = IIF(ISNULL(CL.Short, 'N') = 'Y', RECEIPTDETAIL.ExternPOKey, RECEIPTDETAIL.Lottable03),   --WL01
          [dbo].[fnc_ConvSFTimeZone](RECEIPT.StorerKey, RECEIPT.Facility, RECEIPTDETAIL.Lottable04) AS Lottable04,   --GTZ01
          RECEIPTDETAIL.QtyReceived,   
          PRINCIPAL = SKU.SUSR3,
          PRINDESC = CODELKUP.DESCRIPTION,
          SKU.DESCR,
          SKU.SUSR3,
          STORER.Company,
          PACK.CaseCnt,
          PACK.Pallet,
          PACK.PackUOM3,
          PACK.PackUOM1,
          PACK.PackUOM2,
          PACK.PackUOM4,
          Pack.Innerpack,
          SUSER_NAME() AS SUSERNAME,
          t.PalletPosition,
          RECEIPT.Weight,
          RECEIPT.Cube,
          RECEIPT.UserDefine01,
          RECEIPT.UserDefine03,
          Lottable03Title = IIF(ISNULL(CL.Short, 'N') = 'Y', 'ExternPOKey', 'Lottable03'),   --WL01
          SCNotes = IIF(LEN(SC.Notes) >= 22, IIF(SUBSTRING(SC.Notes, 22, 1) = 'Y', SUBSTRING(TRIM(SC.Notes), 22, 300), ''), ''),   --WL02
          [dbo].[fnc_ConvSFTimeZone](RECEIPT.StorerKey, RECEIPT.Facility, GETDATE()) AS CurrentDateTime   --GTZ01
   FROM RECEIPT (NOLOCK)
   JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey
   JOIN SKU (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku
   JOIN STORER (NOLOCK) ON RECEIPT.Storerkey = STORER.Storerkey
   JOIN PACK (NOLOCK) ON PACK.PackKey = SKU.PackKey
   LEFT OUTER JOIN CODELKUP (NOLOCK) ON SKU.SUSR3 = CODELKUP.CODE AND CODELKUP.LISTNAME = 'PRINCIPAL'
   JOIN #ITEMCLASS t ON t.ReceiptKey = RECEIPT.Receiptkey
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'REPORTCFG' AND CL.Long = 'RPT_ASN_PRETALSHT_011'   --WL01 
                                 AND CL.Storerkey = RECEIPT.Storerkey AND CL.Code = 'ShowExtPOKey'   --WL01
   LEFT JOIN SKUCONFIG SC (NOLOCK) ON SC.Storerkey = SKU.Storerkey AND SC.SKU = SKU.SKU   --WL02
                                  AND SC.ConfigType = 'PRUE-E'   --WL02

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RPT_ASN_PRETALSHT_011'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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