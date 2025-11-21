SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispREC05                                           */
/* Creation Date: 05-FEB-2021                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-16172-RG NIKE Receipt Header Trigger update ASNStatus   */   
/*                                                                      */
/* Called By: isp_ReceiptTrigger_Wrapper from Receipt Trigger           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 04-JUL-2022  CSCHONG  1.1  WMS-16175 disable trafficcop update (CS01)*/
/* 06-JUL-2022  CSCHONG  1.2  WMS-16175 add insert Trans2 table (CS02)  */
/* 03-AUG-2022  CSCHONG  1.3  WMS-20358 Revised update logic (CS03)     */
/************************************************************************/

CREATE PROC [dbo].[ispREC05]   
   @c_Action        NVARCHAR(10),
   @c_Storerkey     NVARCHAR(15),  
   @b_Success       INT      OUTPUT,
   @n_Err           INT      OUTPUT, 
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue        INT,
           @n_StartTCnt       INT,
           @c_Receiptkey      NVARCHAR(10),
           @c_doctype         NCHAR(1),
           @c_TransmitLogKey  NVARCHAR(10),
           @c_TableName       NVARCHAR(30)     


  DECLARE   @c_TriggerName          nvarchar(120)  
          , @c_SourceTable          nvarchar(60)  
        --  , @c_ReceiptKey           nvarchar(10)  
          , @c_ColumnsUpdated       VARCHAR(1000)     
          , @c_UpdateFields         NVARCHAR(1) = 'N'        --CS03       
                                             
    SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

     SET @c_TableName = 'WSRCU6EXELLOG'
     SET @c_SourceTable    = 'RECEIPT'  
     SET @c_ColumnsUpdated = 'ASNStatus'

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
         
    IF @c_Action IN('UPDATE') 
    BEGIN
      
      SET @c_Receiptkey = ''

      SELECT TOP 1 @c_Receiptkey = I.Receiptkey
      FROM #INSERTED I 

      --CS03 S
      IF EXISTS (SELECT 1 FROM Receipt R WITH (NOLOCK)
                     WHERE R.StorerKey = @c_Storerkey
                     AND R.ReceiptKey = @c_Receiptkey
                     AND R.DOCTYPE ='R'
                     AND R.ASNStatus='0' 
                     AND (R.RecType = 'RSO-F' OR R.RECType='RSO-N'))
      BEGIN
              SET @c_UpdateFields = 'Y'
      END 

     --CS03 E

      IF EXISTS (SELECT 1 FROM #INSERTED I 
                 JOIN #DELETED D ON I.Receiptkey = D.Receiptkey 
                 WHERE I.Userdefine06 <> ISNULL(D.Userdefine06,'1900-01-01 00:00:00.000') AND I.Storerkey = @c_Storerkey) AND @c_UpdateFields ='Y'    --CS03
       BEGIN   

             UPDATE RECEIPT WITH (ROWLOCK)
             SET ASNStatus = 'RCVD',
               --  Trafficcop = NULL,                       --CS01
                 EditWho = SUSER_SNAME(),
                 EditDate = GETDATE()
             WHERE Receiptkey = @c_Receiptkey


               SELECT @b_success = 1     --CS02 S
               
               EXEC dbo.ispGenTransmitLog2 @c_TableName, @c_Receiptkey, 'RCVD', @c_StorerKey, ''
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT

            IF @b_success = 0
            BEGIN    
               SELECT @n_continue = 3, @n_err = 60098, @c_errmsg = 'ispREC05: ' + rtrim(@c_errmsg)
            END

      END --CS02 E

   END
      
   QUIT_SP:
   
    IF @n_Continue=3  -- Error Occured - Process AND Return
    BEGIN
       SELECT @b_Success = 0
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
       EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispREC05'     
       --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
       RETURN
    END
    ELSE
    BEGIN
       SELECT @b_Success = 1
       WHILE @@TRANCOUNT > @n_StartTCnt
       BEGIN
         COMMIT TRAN
       END
       RETURN
    END  
END  

GO