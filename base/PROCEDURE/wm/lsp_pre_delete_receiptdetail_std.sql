SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: lsp_Pre_Delete_Receiptdetail_STD                   */  
/* Creation Date: 03-Apr-2018                                           */  
/* Copyright: LFLogistics                                               */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Receiptdetail Pre-delete process / validation               */  
/*                                                                      */  
/* Called By: Receiptdetail delete                                      */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 8.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 2021-02-08   mingle01 1.1  Add Big Outer Begin try/Catch             */ 
/************************************************************************/   
CREATE PROCEDURE [WM].[lsp_Pre_Delete_Receiptdetail_STD]
       @c_StorerKey         NVARCHAR(15)
   ,  @c_RefKey1           NVARCHAR(50)  = '' 
   ,  @c_RefKey2           NVARCHAR(50)  = '' 
   ,  @c_RefKey3           NVARCHAR(50)  = '' 
   ,  @c_RefreshHeader     CHAR(1) = 'N' OUTPUT
   ,  @c_RefreshDetail     CHAR(1) = 'N' OUTPUT 
   ,  @b_Success           INT = 1 OUTPUT   
   ,  @n_Err               INT = 0 OUTPUT
   ,  @c_Errmsg            NVARCHAR(255) = ''  OUTPUT
   ,  @c_UserName          NVARCHAR(128) = '' 
   ,  @c_IsSupervisor      CHAR(1) = 'N' 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue            INT 
          ,@n_starttcnt           INT
          ,@c_Receiptkey          NVARCHAR(10) = ''
          ,@c_ReceiptLineNumber   NVARCHAR(5) = ''   
          ,@c_UCCTracking         NVARCHAR(1) = '0'
          ,@c_UCCNo               NVARCHAR(20)
   
   SELECT @n_starttcnt=@@TRANCOUNT, @n_err=0, @b_success=1, @c_errmsg='', @n_continue=1

   SET @c_Receiptkey = @c_RefKey1
   SET @c_ReceiptLineNumber = @c_Refkey2
   SET @c_RefreshDetail = 'Y'
       
   --(mingle01) - START
   BEGIN TRY  
      IF @n_Continue IN (1,2)
      BEGIN      
         IF EXISTS(SELECT 1 
                     FROM RECEIPTDETAIL (NOLOCK)
                     WHERE Receiptkey = @c_Receiptkey
                     AND ReceiptLineNumber = @c_ReceiptLineNumber
                     AND QtyReceived > 0)
           BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 551051
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Cannot delete Receiptdetail where item have been received. (lsp_Pre_Delete_Receiptdetail_STD)'                
           END                                 
      END    

      IF @n_Continue IN (1,2)
      BEGIN      
           BEGIN TRAN
            
         EXEC nspGetRight
               @c_Facility = '',
               @c_StorerKey = @c_StorerKey,
               @c_sku = '',
               @c_ConfigKey = 'UCCTracking',
               @b_Success   = @b_Success OUTPUT,
               @c_authority = @c_UCCTracking OUTPUT,
               @n_err = @n_Err,
               @c_errmsg = @c_ErrMsg      

         IF @c_UCCTracking = '1'
         BEGIN       
            DECLARE CUR_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT UCCNo
            FROM UCC WITH (NOLOCK)
            WHERE Receiptkey = @c_ReceiptKey
            AND ReceiptLineNumber = @c_ReceiptLineNumber
            
            OPEN CUR_UCC
            
            FETCH FROM CUR_UCC INTO @c_UCCNo
            
            WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
            BEGIN
               UPDATE UCC WITH (ROWLOCK)
                  SET Receiptkey = '', 
                      ReceiptLineNumber = '' 
               WHERE UCCNo = @c_UCCNo 
               
               SET @n_err = @@ERROR
               
               IF @n_err <> 0
               BEGIN
                 SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 551052
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Update UCC Table Failed. (lsp_Pre_Delete_Receiptdetail_STD)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
             END  
            
               FETCH FROM CUR_UCC INTO @c_UCCNo
            END         
            CLOSE CUR_UCC
            DEALLOCATE CUR_UCC                                              
         END -- @c_UCCTracking = '1'      
      END 
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END      
   EXIT_SP:
   --REVERT     
   
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
      execute nsp_logerror @n_err, @c_errmsg, 'lsp_Pre_Delete_Receiptdetail_STD'  
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
END -- End Procedure

GO