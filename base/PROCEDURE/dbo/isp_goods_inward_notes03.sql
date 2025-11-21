SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_goods_inward_notes03                           */
/* Creation Date: 06-Jan-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-21469 - SG - IDSMED - Adding WH Code in Tally Sheet,    */
/*          GIN document, and Inbound Pallet Receiving Label - CR       */
/*          Convert from SQL Query to SP                                */
/*                                                                      */
/* Called By: r_dw_goods_inward_notes03                                 */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 06-Jan-2023  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_goods_inward_notes03]
   @c_ReceiptKeyStart NVARCHAR(10)
 , @c_ReceiptKeyEnd   NVARCHAR(10)
 , @c_Storerkey       NVARCHAR(15)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt INT
         , @n_Continue  INT
         , @b_Success   INT
         , @n_Err       INT
         , @c_Errmsg    NVARCHAR(255)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success = 1
   SET @n_Err = 0
   SET @c_Errmsg = N''

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      SELECT STORER.Company
           , RECEIPT.ReceiptKey
           , RECEIPT.CarrierReference
           , RECEIPT.StorerKey
           , RECEIPT.CarrierName
           , PO.SellerName
           , RECEIPT.AddWho
           , RECEIPT.ReceiptDate
           , RECEIPTDETAIL.Sku
           , CASE WHEN ISNULL(CL4.Short, 'N') = 'Y' THEN RECEIPTDETAIL.Lottable07
                  ELSE RECEIPTDETAIL.Lottable02 END
           , SKU.DESCR
           , RECEIPTDETAIL.Lottable04
           , RECEIPTDETAIL.UOM
           , QtyExp = CASE WHEN CL.Short = 0 THEN SUM(RECEIPTDETAIL.QtyExpected)
                           ELSE
                              SUM(RECEIPTDETAIL.QtyExpected / NULLIF(CASE RECEIPTDETAIL.UOM
                                                                          WHEN PACK.PackUOM1 THEN PACK.CaseCnt
                                                                          WHEN PACK.PackUOM2 THEN PACK.InnerPack
                                                                          WHEN PACK.PackUOM3 THEN 1
                                                                          WHEN PACK.PackUOM4 THEN PACK.Pallet
                                                                          WHEN PACK.PackUOM5 THEN PACK.Cube
                                                                          WHEN PACK.PackUOM6 THEN PACK.GrossWgt
                                                                          WHEN PACK.PackUOM7 THEN PACK.NetWgt
                                                                          WHEN PACK.PackUOM8 THEN PACK.OtherUnit1
                                                                          WHEN PACK.PackUOM9 THEN PACK.OtherUnit2 END, 0))END
           , QtyRec = CASE WHEN CL.Short = 0 THEN SUM(RECEIPTDETAIL.QtyReceived)
                           ELSE
                              SUM(RECEIPTDETAIL.QtyReceived / NULLIF(CASE RECEIPTDETAIL.UOM
                                                                          WHEN PACK.PackUOM1 THEN PACK.CaseCnt
                                                                          WHEN PACK.PackUOM2 THEN PACK.InnerPack
                                                                          WHEN PACK.PackUOM3 THEN 1
                                                                          WHEN PACK.PackUOM4 THEN PACK.Pallet
                                                                          WHEN PACK.PackUOM5 THEN PACK.Cube
                                                                          WHEN PACK.PackUOM6 THEN PACK.GrossWgt
                                                                          WHEN PACK.PackUOM7 THEN PACK.NetWgt
                                                                          WHEN PACK.PackUOM8 THEN PACK.OtherUnit1
                                                                          WHEN PACK.PackUOM9 THEN PACK.OtherUnit2 END, 0))END
           , SKU.STDCUBE
           , CONVERT(NVARCHAR(60), RECEIPT.Notes) AS Notes
           , RECEIPT.CarrierAddress1
           , RECEIPT.POKey
           , RECEIPT.Signatory
           , RECEIPTDETAIL.ExternReceiptKey
           , RECEIPTDETAIL.Lottable03
           , CODELKUP.Description
           , CL.Short
           , SKU.SUSR3
           , SKU.SUSR4
           , CL1.Short AS ShowLot01
           , RECEIPTDETAIL.Lottable01
           , SKU.MANUFACTURERSKU
           , SKU.CLASS
           , ISNULL(f.UserDefine02, 'IDS Logistics') AS 'FCompany'
           , ISNULL(CL2.Short, 'N') AS ShowExtraField
           , RECEIPTDETAIL.Lottable15
           , CASE WHEN ISNULL(CL3.Code, '') <> '' THEN 'Y'
                  ELSE 'N' END AS ShowLot15
           , ISNULL(CL5.Short, 'N') AS ExtendSKUDescrColumn
           , RECEIPT.ExternReceiptKey
           , RECEIPTDETAIL.Lottable12
           , RECEIPTDETAIL.Lottable10
           , RECEIPTDETAIL.Lottable11
           , RECEIPTDETAIL.Lottable08
           , RECEIPTDETAIL.Lottable09
           , RECEIPTDETAIL.ExternPoKey
           , ISNULL(RECEIPTDETAIL.Lottable06,'') AS Lottable06
           , ISNULL(CL6.Short,'N') AS ShowWHCode
      FROM RECEIPT (NOLOCK)
      INNER JOIN RECEIPTDETAIL (NOLOCK) ON (RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey)
      INNER JOIN STORER (NOLOCK) ON (RECEIPTDETAIL.StorerKey = STORER.StorerKey)
      INNER JOIN SKU (NOLOCK) ON (   SKU.StorerKey = STORER.StorerKey
                                 AND SKU.StorerKey = RECEIPTDETAIL.StorerKey
                                 AND SKU.Sku = RECEIPTDETAIL.Sku)
      --INNER JOIN CODELKUP (nolock) ON ( RECEIPTDETAIL.ConditionCode = CODELKUP.Code AND CODELKUP.Listname = 'ASNREASON' )
      INNER JOIN (  SELECT Code
                         , Description
                    FROM CODELKUP WITH (NOLOCK)
                    WHERE (LISTNAME = 'ASNREASON' AND Storerkey = Storerkey)
                    UNION
                    SELECT Code
                         , Description
                    FROM CODELKUP WITH (NOLOCK)
                    WHERE (LISTNAME = 'ASNREASON' AND Storerkey = '')
                    AND   NOT EXISTS (  SELECT 1
                                        FROM CODELKUP WITH (NOLOCK)
                                        WHERE (LISTNAME = 'ASNREASON' AND Storerkey = Storerkey))) CODELKUP ON (RECEIPTDETAIL.ConditionCode = CODELKUP.Code)
      LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (   CL.LISTNAME = 'REPORTCFG'
                                             AND CL.Code = 'SHOWSIGNATURE'
                                             AND CL.Long = 'r_dw_goods_inward_notes03'
                                             AND CL.Storerkey = RECEIPT.StorerKey)
      LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (   CL1.LISTNAME = 'REPORTCFG'
                                              AND CL1.Code = 'SHOWLOT01'
                                              AND CL1.Long = 'r_dw_goods_inward_notes03'
                                              AND CL1.Storerkey = RECEIPT.StorerKey)
      LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON (   CL2.LISTNAME = 'REPORTCFG'
                                              AND CL2.Code = 'ShowExtraField'
                                              AND CL2.Long = 'r_dw_goods_inward_notes03'
                                              AND CL2.Storerkey = RECEIPT.StorerKey)
      LEFT JOIN PO (NOLOCK) ON (PO.POKey = RECEIPTDETAIL.POKey)
      INNER JOIN PACK (NOLOCK) ON (PACK.PackKey = RECEIPTDETAIL.PackKey)
      LEFT JOIN FACILITY AS f WITH (NOLOCK) ON f.Facility = RECEIPT.Facility
      LEFT OUTER JOIN CODELKUP CL3 (NOLOCK) ON (   RECEIPT.StorerKey = CL3.Storerkey
                                               AND CL3.Code = 'showlot15'
                                               AND CL3.LISTNAME = 'REPORTCFG'
                                               AND CL3.Long = 'r_dw_goods_inward_notes03'
                                               AND ISNULL(CL3.Short, '') <> 'N')
      LEFT JOIN CODELKUP CL4 WITH (NOLOCK) ON (   CL4.LISTNAME = 'REPORTCFG'
                                              AND CL4.Code = 'ShowLot07'
                                              AND CL4.Long = 'r_dw_goods_inward_notes03'
                                              AND CL4.Storerkey = RECEIPT.StorerKey)
      LEFT JOIN CODELKUP CL5 WITH (NOLOCK) ON (   CL5.LISTNAME = 'REPORTCFG'
                                              AND CL5.Code = 'ExtendSKUDescrColumn'
                                              AND CL5.Long = 'r_dw_goods_inward_notes03'
                                              AND CL5.Storerkey = RECEIPT.StorerKey)
      LEFT JOIN CODELKUP CL6 WITH (NOLOCK) ON (   CL6.LISTNAME = 'REPORTCFG'
                                              AND CL6.Code = 'ShowWHCode'
                                              AND CL6.Long = 'r_dw_goods_inward_notes03'
                                              AND CL6.Storerkey = RECEIPT.StorerKey)
      WHERE (RECEIPT.ReceiptKey >= @c_ReceiptKeyStart)
      AND   (RECEIPT.ReceiptKey <= @c_ReceiptKeyEnd)
      AND   (RECEIPT.StorerKey = @c_Storerkey)
      AND   ((RECEIPT.RECType = 'NORMAL') OR (RECEIPT.DOCTYPE = 'A'))
      GROUP BY STORER.Company
             , RECEIPT.ReceiptKey
             , RECEIPT.CarrierReference
             , RECEIPT.StorerKey
             , RECEIPT.CarrierName
             , PO.SellerName
             , RECEIPT.AddWho
             , RECEIPT.ReceiptDate
             , RECEIPTDETAIL.Sku
             , CASE WHEN ISNULL(CL4.Short, 'N') = 'Y' THEN RECEIPTDETAIL.Lottable07
                    ELSE RECEIPTDETAIL.Lottable02 END
             , SKU.DESCR
             , RECEIPTDETAIL.Lottable04
             , RECEIPTDETAIL.UOM
             , SKU.STDCUBE
             , CONVERT(NVARCHAR(60), RECEIPT.Notes)
             , RECEIPT.CarrierAddress1
             , RECEIPT.POKey
             , RECEIPT.Signatory
             , RECEIPTDETAIL.ExternReceiptKey
             , RECEIPTDETAIL.Lottable03
             , CODELKUP.Description
             , CL.Short
             , SKU.SUSR3
             , SKU.SUSR4
             , CL1.Short
             , RECEIPTDETAIL.Lottable01
             , SKU.MANUFACTURERSKU
             , SKU.CLASS
             , ISNULL(f.UserDefine02, 'IDS Logistics')
             , ISNULL(CL2.Short, 'N')
             , RECEIPTDETAIL.Lottable15
             , ISNULL(CL3.Code, '')
             , ISNULL(CL5.Short, 'N')
             , RECEIPT.ExternReceiptKey
             , RECEIPTDETAIL.Lottable12
             , RECEIPTDETAIL.Lottable10
             , RECEIPTDETAIL.Lottable11
             , RECEIPTDETAIL.Lottable08
             , RECEIPTDETAIL.Lottable09
             , RECEIPTDETAIL.ExternPoKey
             , ISNULL(RECEIPTDETAIL.Lottable06,'')
             , ISNULL(CL6.Short,'N')
   END
END -- procedure

GO