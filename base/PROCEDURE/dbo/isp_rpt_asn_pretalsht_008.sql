SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Proc: isp_RPT_ASN_PRETALSHT_008                               */
/* Creation Date: 08-FEB-2023                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WZPang                                                   */
/*                                                                      */
/* Purpose: WMS-21236 - BBW PH Pre-Tally Sheet                          */
/*                                                                      */
/* Called By: RPT_ASN_PRETALSHT_008                                     */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver   Purposes                                */
/* 08-Feb-2023  WZPang    1.0   Devops Scripts Combine                  */
/************************************************************************/

CREATE   PROC [dbo].[isp_RPT_ASN_PRETALSHT_008]
            @c_Receiptkey     NVARCHAR(10)
         --,  @c_Storerkey      NVARCHAR(10)
         --   @c_ReceiptStart   NVARCHAR(10)
         --,  @c_ReceiptEnd     NVARCHAR(10)
         --,  @c_StorerStart    NVARCHAR(15)
         --,  @c_StorerEnd      NVARCHAR(15)
         --,  @c_userid         NVARCHAR(20) = ''

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT   STORER.Company
        ,   F.Descr
        ,   RECEIPT.ReceiptDate
        ,   RECEIPT.ReceiptKey
        ,   UPPER(RECEIPT.WarehouseReference) AS WarehouseReference
        ,   UPPER(RECEIPT.ExternReceiptkey) AS ExternReceiptkey
        ,   RECEIPTDETAIL.Sku
        ,   SKU.DESCR AS SKU_DESCR
        ,   PACK.CaseCnt
        --,   CASE WHEN RECEIPTDETAIL.UOM = 'EA' THEN (RECEIPTDETAIL.QtyExpected / PACK.CaseCnt) ELSE RECEIPTDETAIL.QtyExpected END AS EquivCSQty
        ,   CASE WHEN RECEIPTDETAIL.UOM = 'EA' THEN ISNULL((RECEIPTDETAIL.QtyExpected / NULLIF(PACK.CaseCnt,0)),0) ELSE RECEIPTDETAIL.QtyExpected END AS EquivCSQty
        ,   RECEIPTDETAIL.QtyExpected
        ,   RECEIPTDETAIL.UOM
        ,   UPPER(RECEIPTDETAIL.Lottable02) AS Lottable02
        ,   RECEIPTDETAIL.Lottable04
        ,   SKU.IVAS       
    FROM RECEIPT (NOLOCK)
    JOIN STORER (NOLOCK) ON RECEIPT.Storerkey = STORER.Storerkey
    JOIN FACILITY F (NOLOCK) ON F.Facility = RECEIPT.Facility
    JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey
    JOIN SKU (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey and SKU.Sku = RECEIPTDETAIL.Sku
    JOIN PACK (NOLOCK) ON PACK.PackKey = RECEIPTDETAIL.PackKey
    WHERE RECEIPT.ReceiptKey = @c_Receiptkey --AND STORER.StorerKey = @c_Storerkey
    GROUP BY STORER.Company
        ,   F.Descr
        ,   RECEIPT.ReceiptDate
        ,   RECEIPT.ReceiptKey
        ,   UPPER(RECEIPT.WarehouseReference) 
        ,   UPPER(RECEIPT.ExternReceiptkey)  
        ,   RECEIPTDETAIL.Sku
        ,   SKU.DESCR 
        ,   PACK.CaseCnt
        --,   CASE WHEN RECEIPTDETAIL.UOM = 'EA' THEN (RECEIPTDETAIL.QtyExpected / PACK.CaseCnt) ELSE RECEIPTDETAIL.QtyExpected END 
        ,   RECEIPTDETAIL.QtyExpected
        ,   RECEIPTDETAIL.UOM
        ,   UPPER(RECEIPTDETAIL.Lottable02) 
        ,   RECEIPTDETAIL.Lottable04
        ,   SKU.IVAS       

END 

GO