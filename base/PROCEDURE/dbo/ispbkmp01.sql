SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store Procedure: ispBKMP01                                              */
/* Creation Date: 20-JUN-2013                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: Booking Column Mapping                                         */
/*        : SOS#281131- Booking Column Mapping                             */
/*                                                                         */
/* Called By: ue_receiptkey_rule                                           */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/* 19-JUN-2014  YTWAn     1.1   SOS#314027- Add PODeliverdate to Booking_In*/
/*                              (Wan01)                                    */
/* 26-AUG-2014  YTWan     1.1   SOS#318511 - Add carrier to booking data   */
/*                              (Wan02)                                    */
/***************************************************************************/
CREATE PROC [dbo].[ispBKMP01]
           @c_ReceiptKey      NVARCHAR(10) 
         , @c_POKey           NVARCHAR(10)   OUTPUT
         , @c_ReferenceNo     NVARCHAR(30)   OUTPUT
         , @c_Userdefine01    NVARCHAR(20)   OUTPUT
         , @c_Userdefine02    NVARCHAR(20)   OUTPUT
         , @c_Userdefine03    NVARCHAR(20)   OUTPUT
         , @c_Userdefine04    NVARCHAR(20)   OUTPUT   
         , @c_Userdefine05    NVARCHAR(20)   OUTPUT
         , @dt_Userdefine06   DATETIME       OUTPUT
         , @dt_Userdefine07   DATETIME       OUTPUT
         , @c_Userdefine08    NVARCHAR(10)   OUTPUT
         , @c_Userdefine09    NVARCHAR(10)   OUTPUT
         , @c_Userdefine10    NVARCHAR(10)   OUTPUT
         , @n_Qty             INT            OUTPUT
         , @n_UOMQty          INT            OUTPUT
         , @n_NumberOfSku     INT            OUTPUT
         , @b_Success         INT            OUTPUT            
         , @n_err             INT            OUTPUT          
         , @c_errmsg          NVARCHAR(255)  OUTPUT  
AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF 

   SET @b_Success = 2 

   SELECT @c_POKey         = ISNULL(RTRIM(PO.POKey),'')
         ,@c_ReferenceNo   = ISNULL(RTRIM(PO.ExternPOkey),'')
         ,@c_UserDefine01  = ISNULL(RTRIM(PO.UserDefine01),'')
         ,@c_UserDefine02  = ISNULL(RTRIM(PO.UserDefine02),'')
         ,@c_UserDefine03  = ISNULL(RTRIM(PO.UserDefine03),'')
         ,@c_UserDefine04  = ISNULL(RTRIM(PO.UserDefine08),'') --(Wan02)
         ,@dt_Userdefine06 = ISNULL(RTRIM(PO.UserDefine06),'') --(Wan01)
         ,@n_Qty           = ISNULL(PO.OpenQty,0)
         ,@b_Success       = 1 
   FROM RECEIPT WITH (NOLOCK)
   JOIN PO WITH (NOLOCK) ON (RECEIPT.Storerkey = PO.Storerkey) AND (RECEIPT.UserDefine02 = PO.ExternPOkey)
   WHERE RECEIPT.ReceiptKey = @c_Receiptkey
END

GO