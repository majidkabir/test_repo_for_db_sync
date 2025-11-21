SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ReceiptSummary10                                    */
/* Creation Date: 06-JAN-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: WMS-826 - FBR New Receipt Report Format                     */
/*        :                                                             */
/* Called By:  r_dw_receipt_summary10                                   */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_ReceiptSummary10]  
      @c_Receiptkey   NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_Storerkey       NVARCHAR(15)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   SELECT RECEIPT.Facility
        , RECEIPT.Storerkey
	     , RECEIPT.FinalizeDate
	     , RECEIPT.ReceiptKey
	     , ExternReceiptKey   = ISNULL(RTRIM(RECEIPT.ExternReceiptKey),'')
	     , WarehouseReference = ISNULL(RTRIM(RECEIPT.WarehouseReference),'')
	     , CarrierKey         = ISNULL(RTRIM(RECEIPT.CarrierKey),'')
	     , CarrierName        = ISNULL(RTRIM(RECEIPT.CarrierName),'')
	     , CarrierAddress1  = ISNULL(RTRIM(RECEIPT.CarrierAddress1),'')
	     , CarrierAddress2  = ISNULL(RTRIM(RECEIPT.CarrierAddress2),'')
	     , CarrierReference = ISNULL(RTRIM(RECEIPT.CarrierReference),'')
	     , ContainerKey     = ISNULL(RTRIM(RECEIPT.ContainerKey),'')
        , ExternLineNo     = N' ' + RIGHT('000000' + LTRIM(RTRIM(RECEIPTDETAIL.ExternLineNo)),6)
	     , SKU   = N' ' + RECEIPTDETAIL.Sku
	     , Descr = N' ' + SKU.Descr
	     , QtyExpected  = SUM(RECEIPTDETAIL.QtyExpected) 
	     , UOM   = N' ' + RECEIPTDETAIL.UOM
	     , QtyAvailable =  SUM(CASE WHEN LOC.HOSTWHCODE <> 'DAMAGE' 
	                                THEN RECEIPTDETAIL.QtyReceived     
	                                ELSE 0 END)  
	     , QtyDamage = SUM(CASE WHEN LOC.HOSTWHCODE = 'DAMAGE' 
	                            THEN RECEIPTDETAIL.QtyReceived     
	                            ELSE 0 END) 
	     --, UOMPACKQty =  CASE RECEIPTDETAIL.UOM
      --                  WHEN PACK.PACKUOM1 THEN PACK.CaseCnt
      --                  WHEN PACK.PACKUOM2 THEN PACK.InnerPack
      --                  WHEN PACK.PACKUOM3 THEN 1
      --                  WHEN PACK.PACKUOM4 THEN PACK.Pallet
      --                  WHEN PACK.PACKUOM5 THEN PACK.Cube
      --                  WHEN PACK.PACKUOM6 THEN PACK.GrossWgt
      --                  WHEN PACK.PACKUOM7 THEN PACK.NetWgt
      --                  WHEN PACK.PACKUOM8 THEN PACK.OtherUnit1
      --                  WHEN PACK.PACKUOM9 THEN PACK.OtherUnit2
		    --              ELSE 1
      --                  END  
        , UserID = SUSER_NAME()
   FROM RECEIPT WITH (NOLOCK)
   JOIN RECEIPTDETAIL(NOLOCK) ON RECEIPT.Receiptkey = RECEIPTDETAIL.ReceiptKey
   JOIN SKU  WITH (NOLOCK) ON (RECEIPTDETAIL.Storerkey = SKU.Storerkey)
                           AND(RECEIPTDETAIL.Sku = SKU.Sku)
   --JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   JOIN LOC  WITH (NOLOCK) ON (RECEIPTDETAIL.Toloc = LOC.Loc)
   WHERE RECEIPT.Receiptkey = @c_Receiptkey
   GROUP BY RECEIPT.Facility
         , RECEIPT.Storerkey
	      , RECEIPT.FinalizeDate
	      , RECEIPT.ReceiptKey
	      , ISNULL(RTRIM(RECEIPT.ExternReceiptKey),'')
	      , ISNULL(RTRIM(RECEIPT.WarehouseReference),'')
	      , ISNULL(RTRIM(RECEIPT.CarrierKey),'')
	      , ISNULL(RTRIM(RECEIPT.CarrierName),'')
	      , ISNULL(RTRIM(RECEIPT.CarrierAddress1),'')
	      , ISNULL(RTRIM(RECEIPT.CarrierAddress2),'')
	      , ISNULL(RTRIM(RECEIPT.CarrierReference),'')
	      , ISNULL(RTRIM(RECEIPT.ContainerKey),'')
	      , RIGHT('000000' + LTRIM(RTRIM(RECEIPTDETAIL.ExternLineNo)),6)
	      , RECEIPTDETAIL.Sku
	      , SKU.Descr
	      , RECEIPTDETAIL.UOM
	      --, CASE RECEIPTDETAIL.UOM
       --    WHEN PACK.PACKUOM1 THEN PACK.CaseCnt
       --    WHEN PACK.PACKUOM2 THEN PACK.InnerPack
       --    WHEN PACK.PACKUOM3 THEN 1
       --    WHEN PACK.PACKUOM4 THEN PACK.Pallet
       --    WHEN PACK.PACKUOM5 THEN PACK.[Cube]
       --    WHEN PACK.PACKUOM6 THEN PACK.GrossWgt
       --    WHEN PACK.PACKUOM7 THEN PACK.NetWgt
       --    WHEN PACK.PACKUOM8 THEN PACK.OtherUnit1
       --    WHEN PACK.PACKUOM9 THEN PACK.OtherUnit2
       --    ELSE 1
       --    END
END -- procedure

GO