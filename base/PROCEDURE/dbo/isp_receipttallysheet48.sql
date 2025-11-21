SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ReceiptTallySheet48                                 */
/* Creation Date: 10-NOV-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
/* Called By: r_receipt_tallysheet48                                    */
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
CREATE PROC [dbo].[isp_ReceiptTallySheet48] 
            @c_ReceiptKeyStart   NVARCHAR(10)
         ,  @c_ReceiptKeyEnd     NVARCHAR(10)
         ,  @c_StorerKeyStart    NVARCHAR(15)
         ,  @c_StorerKeyEnd      NVARCHAR(15)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   
   SELECT RH.Storerkey
         ,RH.ReceiptKey
         ,RH.ContainerKey
         ,RH.ReceiptDate
         ,RH.BilledContainerQty
         ,RD.ReceiptLineNumber
         ,RD.Sku
         ,Style = ISNULL(RTRIM(SKU.Style),'')
         ,Color       = ISNULL(RTRIM(CL.Short),'')
         ,ColorDescr  = ISNULL(RTRIM(CL.Description),'')
         ,Size = ISNULL(RTRIM(SKU.Size),'')
         ,QtyExpected = SUM(RD.QtyExpected)
         ,UserDefine01= ISNULL(RTRIM(RD.UserDefine01),'')
         ,PrintTime   = GETDATE()
   FROM RECEIPT       RH  WITH (NOLOCK)
   JOIN RECEIPTDETAIL RD  WITH (NOLOCK) ON (RH.ReceiptKey = RD.ReceiptKey)
   JOIN SKU           SKU WITH (NOLOCK) ON (RD.Storerkey  = SKU.Storerkey)
                                        AND(RD.Sku =  SKU.Sku)
   LEFT JOIN CODELKUP CL  WITH (NOLOCK) ON (CL.ListName = 'COLORS')
                                        AND(CL.Code = SKU.Color)
                                        AND(CL.Storerkey = SKU.Storerkey)                                     
   WHERE RH.ReceiptKey BETWEEN @c_ReceiptKeyStart AND @c_ReceiptKeyEnd
   AND RH.Storerkey BETWEEN @c_StorerkeyStart AND @c_StorerkeyEnd
   GROUP BY RH.Storerkey
         ,  RH.ReceiptKey
         ,  RH.ContainerKey
         ,  RH.ReceiptDate
         ,  RH.BilledContainerQty
         ,  RD.ReceiptLineNumber
         ,  RD.Sku
         ,  ISNULL(RTRIM(SKU.Style),'')
         ,  ISNULL(RTRIM(CL.Short),'')
         ,  ISNULL(RTRIM(CL.Description),'')
         ,  ISNULL(RTRIM(SKU.Size),'')
         ,  ISNULL(RTRIM(RD.UserDefine01),'')
QUIT_SP:

END -- procedure

GO