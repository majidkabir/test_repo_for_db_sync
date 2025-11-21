SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: WM.lsp_GetBookingByDay_Wrapper                      */                                                                                  
/* Creation Date: 2022-02-17                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-3336 - Door Booking SPsDB queries clarification        */
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.0                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */ 
/* 2022-02-17  Wan01    1.0   Created.                                  */
/* 2022-02-17  Wan01    1.0   DevOps Combine Script.                    */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_GetBookingByDay_Wrapper]                                                                                                                     
      @d_Date                 DATETIME
   ,  @n_Interval             INT = 30
   ,  @c_Facility             NVARCHAR(5)  = ''
   ,  @c_Door1                NVARCHAR(10) = ''
   ,  @c_Door2                NVARCHAR(10) = ''
   ,  @c_Door3                NVARCHAR(10) = ''
   ,  @c_Door4                NVARCHAR(10) = ''
   ,  @c_Door5                NVARCHAR(10) = ''
   ,  @c_Door6                NVARCHAR(10) = ''
   ,  @c_Door7                NVARCHAR(10) = ''
   ,  @c_Door8                NVARCHAR(10) = ''
   ,  @c_Door9                NVARCHAR(10) = ''
   ,  @c_Door10               NVARCHAR(10) = ''
   ,  @c_InOut                CHAR(1)      = 'I'                -- I: Booking for Inbound, O:Booking for Outbound
   ,  @b_Success              INT = 1           OUTPUT  
   ,  @n_err                  INT = 0           OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)= '' OUTPUT 
   ,  @c_UserName             NVARCHAR(128)= ''                                                                                                                         
AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt            INT = @@TRANCOUNT  
         ,  @n_Continue             INT = 1
         
   SET @b_Success = 1
   SET @n_Err     = 0
   
   SET @n_Err = 0 
 
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
       
      EXEC  [dbo].[isp_GetBookingByDay]  
            @d_Date        = @d_Date
         ,  @n_Interval    = @n_Interval
         ,  @c_Door1       = @c_Door1 
         ,  @c_Door2       = @c_Door2 
         ,  @c_Door3       = @c_Door3 
         ,  @c_Door4       = @c_Door4 
         ,  @c_Door5       = @c_Door5 
         ,  @c_Door6       = @c_Door6 
         ,  @c_Door7       = @c_Door7 
         ,  @c_Door8       = @c_Door8 
         ,  @c_Door9       = @c_Door9 
         ,  @c_Door10      = @c_Door10
         ,  @c_Facility    = @c_Facility
         ,  @c_InOut       = @c_InOut
         ,  @c_CallSource  = 'WM'           

   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH

EXIT_SP:
   IF (XACT_STATE()) = -1                                     
   BEGIN
      SET @n_Continue = 3
      ROLLBACK TRAN
   END 

   IF @n_Continue=3  -- Error Occured - Process And Return
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_GetBookingByDay_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   
   IF @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN 
   END
         
   REVERT
END

GO