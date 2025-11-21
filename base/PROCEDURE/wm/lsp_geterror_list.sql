SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure:  lsp_                                      */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose:  Retrieve Error List for WMS Web                            */    
/*                                                                      */    
/* 27-May-2013  TLTING     1.1  Use table Identity to generate running  */  
/* 05-Feb-2021  mingle01   1.2  Add Big Outer Begin try/Catch           */ 
/************************************************************************/   
    
CREATE PROC [WM].[lsp_GetError_List]
     @ErrGroupKey   INT,
     @Refkey1       NVARCHAR(20),
     @Refkey2       NVARCHAR(20),
     @Refkey3       NVARCHAR(20),
     @b_Success     int            OUTPUT,
     @n_err         int            OUTPUT,
     @c_errmsg      NVARCHAR(250)  OUTPUT    
AS
BEGIN

   SET NOCOUNT ON     
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
    

   DECLARE @n_starttcnt int /* Holds the current transaction count */    
   DECLARE @n_continue int /* Continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip furthur processing */    
   DECLARE @n_cnt int /* Variable to record if @@ROWCOUNT=0 after UPDATE */    

   --(mingle01) - START
   BEGIN TRY
      SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''    

      SELECT RowRefNo, ErrCode ,ErrMsg -- TableName, SourceType
      FROM [WM].[WMS_Error_List]
      WHERE ErrGroupKey = @ErrGroupKey AND RefKey1 = @Refkey1 AND RefKey2 = @Refkey2 AND RefKey3 = @Refkey3

   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
EXIT_SP:
END

GO