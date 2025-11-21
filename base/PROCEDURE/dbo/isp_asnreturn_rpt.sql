SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ASNReturn_Rpt                                       */
/* Creation Date: 03-MAR-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-1233 -Newlook B2B Return VAS Report                     */
/*        :                                                             */
/* Called By: r_dw_asn_return_rpt                                       */
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
CREATE PROC [dbo].[isp_ASNReturn_Rpt]
           @c_ReceiptKeyStart    NVARCHAR(10)
         , @c_ReceiptKeyEnd      NVARCHAR(10) 
         , @c_Storerkey          NVARCHAR(15)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
 
   SET @n_StartTCnt = @@TRANCOUNT
   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   SELECT PrintDate = GETDATE()
      ,RH.Storerkey  
      ,RH.ReceiptKey   
      ,SellerAddress4 = ISNULL(RTRIM(RH.SellerAddress4),'')
      ,UserDefine01   = ISNULL(RTRIM(RH.UserDefine01),'')
      ,UserDefine04   = ISNULL(RTRIM(RH.UserDefine04),'')
      ,TotalQtyExpected = SUM(RD.QtyExpected)
   FROM RECEIPT RH WITH (NOLOCK)
   JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON (RH.ReceiptKey = RD.Receiptkey)
   WHERE RH.Receiptkey >= @c_ReceiptKeyStart
   AND   RH.ReceiptKey <= @c_ReceiptKeyEnd
   AND   RH.Storerkey = @c_Storerkey
   AND   RH.DocType = 'R'
   AND   RH.RecType = 'NL-R'
   AND   RH.ASNStatus <> '9'
   GROUP BY RH.Storerkey  
         ,  RH.ReceiptKey   
         ,  ISNULL(RTRIM(RH.SellerAddress4),'')
         ,  ISNULL(RTRIM(RH.UserDefine01),'')
         ,  ISNULL(RTRIM(RH.UserDefine04),'')

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
 END -- procedure

GO