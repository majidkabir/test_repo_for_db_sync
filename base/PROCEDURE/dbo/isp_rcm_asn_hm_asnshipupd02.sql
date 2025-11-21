SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_ASN_HM_ASNSHIPUPD02                        */
/* Creation Date: 18-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19679 - CN_HM_ASN_Receiving_CR                          */
/*          Copy and modify from isp_RCM_ASN_HM_ASNSHIPUPD01            */
/*                                                                      */
/* Called By: ASN Dynamic RCM configure at listname 'RCMConfig'         */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 18-May-2022  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_RCM_ASN_HM_ASNSHIPUPD02]
      @c_Receiptkey  NVARCHAR(10),   
      @b_success     INT OUTPUT,
      @n_err         INT OUTPUT,
      @c_errmsg      NVARCHAR(225) OUTPUT,
      @c_code        NVARCHAR(30) = ''
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue        INT,
           @n_cnt             INT,
           @n_starttcnt       INT,
           @c_Key2            NVARCHAR(30),
           @c_Code2           NVARCHAR(10),
           @c_TL2TableName    NVARCHAR(30) = 'WSRCHNM9L',
           @c_TL3TableName    NVARCHAR(30) = 'RCPTHNM9L'
           
   DECLARE @c_storerkey       NVARCHAR(15),
           @c_doctype         NVARCHAR(10)
              
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt = @@TRANCOUNT, @c_errmsg = '', @n_err = 0 
   
   SELECT TOP 1 @c_Storerkey  = Storerkey,
                @c_doctype    = Doctype
   FROM RECEIPT (NOLOCK)
   WHERE Receiptkey = @c_Receiptkey    

   DECLARE cur_RECEIPTUDF CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      WITH CTE AS (
      SELECT DISTINCT RD.Userdefine09, ISNULL(CL.Code2,'') AS Code2
      FROM RECEIPTDETAIL RD (NOLOCK)
      JOIN RECEIPT R (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
      JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'HMFAC' 
                               AND CL.Storerkey = R.StorerKey
                               AND CL.Short = R.Facility
      WHERE RD.Receiptkey = @c_Receiptkey
      AND ISNULL(RD.Userdefine09,'') <> ''
      UNION ALL
      SELECT DISTINCT RD.Userdefine10 AS Userdefine09, ISNULL(CL.Code2,'') AS Code2
      FROM RECEIPTDETAIL RD (NOLOCK)
      JOIN RECEIPT R (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
      JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'HMFAC' 
                               AND CL.Storerkey = R.StorerKey
                               AND CL.Short = R.Facility
      WHERE RD.Receiptkey = @c_Receiptkey
      AND ISNULL(RD.Userdefine10,'') <> '')
      SELECT DISTINCT CTE.Userdefine09, CTE.Code2
      FROM CTE
      ORDER BY CTE.UserDefine09

   OPEN cur_RECEIPTUDF  
          
   FETCH NEXT FROM cur_RECEIPTUDF INTO @c_Key2, @c_Code2
          
   WHILE @@FETCH_STATUS = 0 
   BEGIN   
      IF @c_Code2 = 'TL2'
      BEGIN
         IF EXISTS (SELECT 1 
                    FROM TransmitLog2 (NOLOCK) 
                    WHERE TableName = @c_TL2TableName
                    AND Key1 = @c_Receiptkey 
                    AND Key2 = @c_Key2 
                    AND Key3 = @c_Storerkey)
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err)+': TL2 - Interface was transmitted (isp_RCM_ASN_HM_ASNSHIPUPD02)' 
                             + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         END

         IF @n_continue IN (1,2)
         BEGIN
            EXEC [dbo].[ispGenTransmitLog2] @c_TL2TableName, @c_Receiptkey, @c_Key2, @c_StorerKey, ''  
                  , @b_success   OUTPUT  
                  , @n_err       OUTPUT  
                  , @c_errmsg    OUTPUT  
                 
            IF @b_success = 0
                SELECT @n_continue = 3, @n_err = 65210, @c_errmsg = 'isp_RCM_ASN_HM_ASNSHIPUPD02: ' + RTRIM(@c_errmsg)
         END
      END
      ELSE   --TL3
      BEGIN
         IF EXISTS (SELECT 1 
                    FROM TransmitLog3 (NOLOCK) 
                    WHERE TableName = @c_TL3TableName
                    AND Key1 = @c_Receiptkey 
                    AND Key2 = @c_Key2 
                    AND Key3 = @c_Storerkey)
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_err)+': TL3 - Interface was transmitted (isp_RCM_ASN_HM_ASNSHIPUPD02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         END
         
         IF @n_continue IN (1,2)
         BEGIN
            EXEC [dbo].[ispGenTransmitLog3] @c_TL3TableName, @c_Receiptkey, @c_Key2, @c_StorerKey, ''  
                  , @b_success   OUTPUT  
                  , @n_err       OUTPUT  
                  , @c_errmsg    OUTPUT  
                 
            IF @b_success = 0
                SELECT @n_continue = 3, @n_err = 65215, @c_errmsg = 'isp_RCM_ASN_HM_ASNSHIPUPD02: ' + RTRIM(@c_errmsg)
         END      
      END

      FETCH NEXT FROM cur_RECEIPTUDF INTO @c_Key2, @c_Code2
   END         
   CLOSE cur_RECEIPTUDF
   DEALLOCATE cur_RECEIPTUDF    
        
ENDPROC: 
 
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
   ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RCM_ASN_HM_ASNSHIPUPD02'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END     
END -- End PROC

GO