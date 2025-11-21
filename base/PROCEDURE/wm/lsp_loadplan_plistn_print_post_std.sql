SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: lsp_LOADPLAN_PLISTN_Print_Post_Std                  */  
/* Creation Date: 14-Jul-2023                                            */  
/* Copyright: MAERSK                                                     */  
/* Written by: WLChooi                                                   */  
/*                                                                       */  
/* Purpose: WMS-22860 - Call ispExportAllocatedOrd by Load               */
/*                                                                       */  
/* Called By: WM.lsp_WM_Print_Report                                     */
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 14-Jul-2023 WLChooi  1.0   DevOps Script Combine                      */
/*************************************************************************/   
CREATE   PROCEDURE [WM].[lsp_LOADPLAN_PLISTN_Print_Post_Std]  
    @n_WMReportRowID BIGINT 
   ,@c_Parm1         NVARCHAR(60)      OUTPUT   
   ,@c_Parm2         NVARCHAR(60)      OUTPUT   
   ,@c_Parm3         NVARCHAR(60)      OUTPUT   
   ,@c_Parm4         NVARCHAR(60)      OUTPUT   
   ,@c_Parm5         NVARCHAR(60)      OUTPUT   
   ,@c_Parm6         NVARCHAR(60)      OUTPUT   
   ,@c_Parm7         NVARCHAR(60)      OUTPUT   
   ,@c_Parm8         NVARCHAR(60)      OUTPUT   
   ,@c_Parm9         NVARCHAR(60)      OUTPUT   
   ,@c_Parm10        NVARCHAR(60)      OUTPUT   
   ,@c_Parm11        NVARCHAR(60)      OUTPUT   
   ,@c_Parm12        NVARCHAR(60)      OUTPUT   
   ,@c_Parm13        NVARCHAR(60)      OUTPUT   
   ,@c_Parm14        NVARCHAR(60)      OUTPUT   
   ,@c_Parm15        NVARCHAR(60)      OUTPUT   
   ,@c_Parm16        NVARCHAR(60)      OUTPUT   
   ,@c_Parm17        NVARCHAR(60)      OUTPUT   
   ,@c_Parm18        NVARCHAR(60)      OUTPUT   
   ,@c_Parm19        NVARCHAR(60)      OUTPUT   
   ,@c_Parm20        NVARCHAR(60)      OUTPUT 
   ,@n_Noofparms     INT               OUTPUT   
   ,@b_ContinuePrint BIT               OUTPUT   
   ,@n_NoOfCopy      INT               OUTPUT   
   ,@c_PrinterID     NVARCHAR(30)      OUTPUT   
   ,@c_PrintData     NVARCHAR(4000)    OUTPUT 
   ,@b_Success       INT               OUTPUT 
   ,@n_Err           INT               OUTPUT 
   ,@c_ErrMsg        NVARCHAR(255)     OUTPUT 
   ,@c_UserName      NVARCHAR(30) = ''
   ,@c_PrintSource   NVARCHAR(10) = 'WMReport' 
   ,@b_SCEPreView    INT          = 0     
   ,@n_JobID         INT          = 0  OUTPUT 
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue           INT = 1
         , @n_StartTCnt          INT = @@TRANCOUNT 
         , @c_ReportLineDesc     NVARCHAR(50)
         , @c_Module             NVARCHAR(10) = 'LOADPLAN' 
                 
   SET @b_Success = 1
   SET @c_ErrMsg = ''

   SET @n_Err = 0 

   IF @c_UserName = '' SET @c_UserName = SUSER_SNAME()

   IF SUSER_SNAME() <> @c_UserName 
   BEGIN
      EXEC [WM].[lsp_SetUser] 
            @c_UserName = @c_UserName  OUTPUT
         ,  @n_Err      = @n_Err       OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
                
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
    
      EXECUTE AS LOGIN = @c_UserName
   END

   BEGIN TRAN

   BEGIN TRY 
      EXEC [dbo].[ispExportAllocatedOrd] @c_Key = @c_Parm1
                                       , @c_Type = @c_Module
                                       , @b_success = @b_success OUTPUT
                                       , @n_err = @n_err OUTPUT
                                       , @c_errmsg = @c_errmsg OUTPUT
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE() + '. (lsp_LOADPLAN_PLISTN_Print_Post_Std)'
      GOTO EXIT_SP
   END CATCH

   EXIT_SP:
   
   IF (XACT_STATE()) = -1  
   BEGIN
      ROLLBACK TRAN
   END 
       
   IF @n_Continue = 3   
   BEGIN
      SET @b_Success = 0
      IF @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_LOADPLAN_PLISTN_Print_Post_Std'
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
   BEGIN
      BEGIN TRAN
   END

   REVERT
END  

GO