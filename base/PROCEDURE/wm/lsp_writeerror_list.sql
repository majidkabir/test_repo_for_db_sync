SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure:  lsp_WriteError_List                               */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose:  Retrieve Error List for WMS Web                            */    
/*                                                                      */  
/* Date        Author   Ver   Purposes                                  */  
/* 27-May-2013 TLTING   1.1   Use table Identity to generate running    */  
/* 26-Oct-2018 Wan      1.1   Add WriteType                             */
/* 2020-11-23  Wan01    1.2   Add Big Outer Begin Try..End Try to enable*/
/*                            Revert when Sub SP Raise error            */
/************************************************************************/   
    
CREATE PROC [WM].[lsp_WriteError_List]
     @i_iErrGroupKey   INT= 0 OUTPUT,
     @c_TableName     NVARCHAR(50),
     @c_SourceType    NVARCHAR(50),
     @c_Refkey1       NVARCHAR(20),
     @c_Refkey2       NVARCHAR(20),
     @c_Refkey3       NVARCHAR(20),
     @n_LogWarningNo  INT          = 0,              --(Wan01) Mainly for Batch Processing to Log Warning # for API to get Process key's WarningNo to re-execute
     @c_WriteType     NVARCHAR(20) = 'ERROR',        --(Wan01) DEFAULT 'ERROR'. 1) 'ERROR' 2) 'QUESTION' 3) WARNING
     @n_err2          INT,
     @c_errmsg2       NVARCHAR(250),
     @b_Success       int            OUTPUT,
     @n_err           int            OUTPUT,
     @c_errmsg        NVARCHAR(250)  OUTPUT    
AS
BEGIN

   SET NOCOUNT ON     
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
    

   DECLARE @n_starttcnt int /* Holds the current transaction count */    
   DECLARE @n_continue int /* Continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip furthur processing */    
   DECLARE @n_cnt int /* Variable to record if @@ROWCOUNT=0 after UPDATE */    

   SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=1

   --(Wan01) - START
   BEGIN TRY
      --If First Error get new key
      IF @i_iErrGroupKey = 0
      BEGIN
         --Call get Key        
         EXECUTE   nspg_getkey    
                  'ErrGroupKey'    
                  , 10    
                  , @i_iErrGroupKey      OUTPUT    
                  , @b_success          OUTPUT    
                  , @n_err              OUTPUT    
                  , @c_errmsg           OUTPUT 

         IF NOT @b_success = 1    
         BEGIN    
            SET @n_continue = 3    
            SET @n_err = 553851
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Get ErrGroupkey Failed. (lsp_WrtieError_List)' 
            GOTO QUIT
         END
      END
      --(Wan01) - START
      IF @n_LogWarningNo IS NULL 
      BEGIN
         SET @n_LogWarningNo = 0 --Initialize
      END

      INSERT [WM].[WMS_Error_List]( ErrGroupKey, TableName, SourceType, RefKey1, RefKey2, RefKey3, LogWarningNo, WriteType, ErrCode, ErrMsg)
      SELECT @i_iErrGroupKey, @c_TableName, @c_SourceType, @c_Refkey1, @c_Refkey2, @c_Refkey3, @n_LogWarningNo, @c_WriteType, @n_err2, @c_errmsg2
      --(Wan01) - END

      IF @@Error <> 0 or @@Rowcount = 0
      BEGIN
         SET @b_success = 0    
         SET @n_continue = 3    
         SET @n_err = 553852
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Failed to insert. (lsp_WrtieError_List)' 
         GOTO QUIT
      END
   END TRY

   BEGIN CATCH
      SET @n_continue = 3
      SET @c_errmsg='Writing Record to WM.WMS_Error_List Failed. (lsp_WrtieError_List). ( SQLSvr MESSAGE=' + ERROR_MESSAGE() + ' ) '  
      GOTO QUIT  
   END CATCH
   --(Wan01) - END
   QUIT:

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN     
      
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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
      
      execute nsp_logerror @n_err, @c_errmsg, 'lsp_WrtieError_List'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
      
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END     
      RETURN
   END
END

GO