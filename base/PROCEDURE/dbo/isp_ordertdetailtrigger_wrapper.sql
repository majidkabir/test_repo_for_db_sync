SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_OrdertDetailTrigger_Wrapper                    */  
/* Creation Date: 07-May-2024                                           */  
/* Copyright: MAERSK                                                    */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:  UWP-18748 Call Orderdetail custom stored proc              */
/*                                                                      */  
/* Called By: Orderdetail insert/update/delete trigger                  */    
/*            Stored proc naming: ispORDDxx                             */
/*                                                                      */  
/* GITHUB Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/  

CREATE   PROCEDURE [dbo].[isp_OrdertDetailTrigger_Wrapper]  
      @c_Action         NVARCHAR(10) 
   ,  @b_Success        INT           OUTPUT 
   ,  @n_Err            INT           OUTPUT 
   ,  @c_ErrMsg         NVARCHAR(250) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF   
   
   --------Call from insert/update/delete trigger example --------
   /*IF @n_continue=1 or @n_continue=2          
   BEGIN   	  
      IF EXISTS (SELECT 1 FROM DELETED d   ----->Put INSERTED if INSERT action
                 JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey    
                 JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
                 WHERE  s.configkey = 'OrderDetailTrigger_SP')   -----> Current table trigger storerconfig
      BEGIN        	  
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED

      	 SELECT * 
      	 INTO #INSERTED
      	 FROM INSERTED
          
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED

      	 SELECT * 
      	 INTO #DELETED
      	 FROM DELETED

         EXECUTE dbo.isp_OrdertDetailTrigger_Wrapper ----->wrapper for current table trigger
                 , 'UPDATE'  -----> @c_Action can be INSERTE, UPDATE, DELETE
                 , @b_Success  OUTPUT  
                 , @n_Err      OUTPUT   
                 , @c_ErrMsg   OUTPUT  

         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3  
                  ,@c_errmsg = 'ntrOrderDetailUpdate ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))  -----> Put current trigger name
         END  
         
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED

         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
      END
   END      
   */
   
   DECLARE @n_Continue       INT
         , @n_StartTCnt      INT
         , @c_SPCode         NVARCHAR(10)
         , @c_Storerkey      NVARCHAR(15)
         , @c_SQL            NVARCHAR(MAX)
         , @c_configkey      NVARCHAR(30)
         , @c_option5_splist NVARCHAR(2000) 

   SET @n_err        = 0
   SET @b_success    = 1
   SET @c_errmsg     = ''

   SET @n_Continue   = 1
   SET @n_StartTCnt  = @@TRANCOUNT
   SET @c_SPCode     = ''
   SET @c_SQL        = ''
   SET @c_Storerkey  = ''
   SET @c_configkey = 'OrderDetailTrigger_SP'
   
   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      
   
   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END
   
   IF @c_Action IN('DELETE','UPDATE')
   BEGIN   
      DECLARE Cur_SPCode CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT DISTINCT D.Storerkey, S.Svalue, S.Option5
          FROM #DELETED D
          JOIN STORERCONFIG S WITH (NOLOCK) ON  D.Storerkey = S.Storerkey    
          JOIN sys.objects sys ON sys.type = 'P' AND sys.name = S.Svalue
          WHERE S.Configkey = @c_Configkey 
   END
   ELSE
   BEGIN
      DECLARE Cur_SPCode CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT DISTINCT I.Storerkey, S.Svalue, S.Option5
          FROM #INSERTED I
          JOIN STORERCONFIG S WITH (NOLOCK) ON  I.Storerkey = S.Storerkey    
          JOIN sys.objects sys ON sys.type = 'P' AND sys.name = S.Svalue
          WHERE S.Configkey = @c_Configkey 
   END
      
   OPEN Cur_SPCode
	
	 FETCH NEXT FROM Cur_SPCode INTO @c_StorerKey, @c_SPCode, @c_option5_splist

   BEGIN TRAN

	 WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
	 BEGIN
	 	  
      SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_Action, @c_Storerkey '  
                 + ',@b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '
      
      EXEC sp_executesql @c_SQL 
         , N'@c_Action NVARCHAR(10), @c_Storerkey NVARCHAR(15)
         , @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT' 
         , @c_Action
         , @c_StorerKey
         , @b_Success         OUTPUT                       
         , @n_Err             OUTPUT  
         , @c_ErrMsg          OUTPUT
           
      IF @b_Success <> 1
      BEGIN
          SELECT @n_Continue = 3  
          --GOTO QUIT_SP
      END
      
      IF ISNULL(@c_option5_splist,'') <> '' AND (@n_continue = 1 or @n_continue = 2)
      BEGIN
	       DECLARE Cur_SPCodeList CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	          SELECT colvalue FROM dbo.fnc_DelimSplit(',', @c_option5_splist) ORDER BY SeqNo

         OPEN Cur_SPCodeList

	       FETCH NEXT FROM Cur_SPCodeList INTO @c_SPCode

	       WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
	       BEGIN
         	  IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
         	  BEGIN
               SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_Action, @c_Storerkey '
                          + ',@b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '

               EXEC sp_executesql @c_SQL
                  , N'@c_Action NVARCHAR(10), @c_Storerkey NVARCHAR(15)
                  , @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'
                  , @c_Action
                  , @c_StorerKey
                  , @b_Success         OUTPUT
                  , @n_Err             OUTPUT
                  , @c_ErrMsg          OUTPUT

               IF @b_Success <> 1
               BEGIN
                   SELECT @n_Continue = 3
                   --GOTO QUIT_SP
               END
         	  END

	          FETCH NEXT FROM Cur_SPCodeList INTO @c_SPCode
	       END
         CLOSE Cur_SPCodeList
         DEALLOCATE Cur_SPCodeList
      END      

   	 FETCH NEXT FROM Cur_SPCode INTO @c_StorerKey, @c_SPCode, @c_option5_splist
	 END
 	 CLOSE Cur_SPCode
	 DEALLOCATE Cur_SPCode

   QUIT_SP:
   
   IF CURSOR_STATUS('LOCAL' , 'Cur_SPCode') in (0 , 1)          
   BEGIN          
      CLOSE Cur_SPCode          
      DEALLOCATE Cur_SPCode          
   END     
   
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_OrdertDetailTrigger_Wrapper'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END 
END  

GO