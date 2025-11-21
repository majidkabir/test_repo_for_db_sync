SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_ReceiptTallySheet63                                 */  
/* Creation Date: 05-AUG-2019                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-10099 - [MY]-Levis-New Tallysheet RCMREPORT             */   
/*        :                                                             */  
/* Called By: r_receipt_tallysheet63                                    */
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

CREATE PROC [dbo].[isp_ReceiptTallySheet63]  
            @c_ReceiptKeyStart   NVARCHAR(10)  
         ,  @c_ReceiptKeyEnd     NVARCHAR(10)  
         ,  @c_StorerKeyStart    NVARCHAR(15)  
         ,  @c_StorerKeyEnd      NVARCHAR(15) 
         ,  @c_userid            NVARCHAR(20) = ''
  
AS  
BEGIN   
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @n_continue INT = 1, @n_err INT = 0, @c_errmsg NVARCHAR(255) = '', @b_Success INT = 1
           , @n_StartTCnt INT = @@TRANCOUNT, @c_GetReceiptKey NVARCHAR(10), @c_GetUserDefine03 NVARCHAR(30)
           , @c_GetUserDefine07 DATETIME
             
   SELECT RECEIPT.StorerKey,
          RECEIPT.Facility,
          RECEIPT.ReceiptKey,  
          RECEIPT.RECType,
          RECEIPT.ExternReceiptKey, 
          CONVERT(NVARCHAR(10), RECEIPT.AddDate, 101) AS AddDate,
          RECEIPTDETAIL.ExternLineNo,
          SKU.Style,
          SKU.Size,
          LTRIM(RTRIM(RECEIPTDETAIL.UserDefine01)) AS UserDefine01,
          SUM(RECEIPTDETAIL.QtyExpected) AS QtyExp,
          RECEIPTDETAIL.ReceiptLinenumber,
          RECEIPT.UserDefine03,
          ISNULL(RECEIPT.UserDefine07,'1900/01/01') AS UserDefine07
   INTO #TLYSHEET63
   FROM RECEIPT (nolock)
   JOIN RECEIPTDETAIL (nolock) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey
   JOIN SKU (nolock) ON  SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku
   WHERE ( RECEIPT.ReceiptKey >= @c_ReceiptKeyStart ) AND
         ( REceipt.receiptkey <= @c_ReceiptKeyEnd ) AND
         ( RECEIPT.Storerkey >=  @c_StorerKeyStart ) AND
         ( RECEIPT.Storerkey <=  @c_StorerKeyEnd )
   GROUP BY RECEIPT.StorerKey,
            RECEIPT.Facility,
            RECEIPT.ReceiptKey,  
            RECEIPT.RECType,
            RECEIPT.ExternReceiptKey, 
            CONVERT(NVARCHAR(10), RECEIPT.AddDate, 101),
            RECEIPTDETAIL.ExternLineNo,
            SKU.Style,
            SKU.Size,
            LTRIM(RTRIM(RECEIPTDETAIL.UserDefine01)),
            RECEIPTDETAIL.ReceiptLinenumber,
            RECEIPT.UserDefine03,
            ISNULL(RECEIPT.UserDefine07,'1900/01/01')
   ORDER BY RECEIPT.ReceiptKey, RECEIPTDETAIL.ReceiptLinenumber

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT ReceiptKey, UserDefine03, UserDefine07
   FROM #TLYSHEET63

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_GetReceiptKey, @c_GetUserDefine03, @c_GetUserDefine07
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      
      IF LTRIM(RTRIM(ISNULL(@c_GetUserDefine03,''))) NOT IN ('Y','N')
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 90001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Please update the value in Receipt.Userdefine03. (isp_ReceiptTallySheet63)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
      END

      IF ISNULL(@c_GetUserDefine07,'1900/01/01') = '1900/01/01'
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 90002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Please update the value in Receipt.Userdefine07. (isp_ReceiptTallySheet63)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
      END

      FETCH NEXT FROM CUR_LOOP INTO @c_GetReceiptKey, @c_GetUserDefine03, @c_GetUserDefine07
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      SELECT DISTINCT StorerKey,
                      Facility,
                      ReceiptKey,  
                      RECType,
                      ExternReceiptKey,
                      AddDate,
                      ExternLineNo,
                      Style,
                      Size,
                      UserDefine01,
                      QtyExp,
                      ReceiptLinenumber
      FROM #TLYSHEET63
      ORDER BY ReceiptKey, ReceiptLinenumber
   END

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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ReceiptTallySheet63'  
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