SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: WM.lsp_IQC_RCM_CopyFromID2ToLoc                     */  
/* Creation Date: 2020-07-01                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-3078 - CN_PUMA_Inventory QC Enhancemen                  */
/*                                                                       */  
/* Called By: WM.lsp_RCMConfigSP_IQC_Wrapper                             */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 2021-10-04  Wan      1.0   Created.                                   */
/* 2021-10-04  Wan      1.0   Devops Combine Script                      */
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_IQC_RCM_CopyFromID2ToLoc] 
   @c_QC_Key         NVARCHAR(10)  
,  @b_Success        INT          = 1   OUTPUT   
,  @n_Err            INT          = 0   OUTPUT
,  @c_Errmsg         NVARCHAR(255)= ''  OUTPUT
,  @c_Code           NVARCHAR(30) = ''             
,  @c_UserName       NVARCHAR(128)= ''
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue           INT = 1
         , @n_StartTCnt          INT = @@TRANCOUNT
         
         , @c_ToFacility         NVARCHAR(5) = ''
         , @c_QCLineNo_UnMatch   NVARCHAR(5) = ''
         , @c_FromID_UnMatch     NVARCHAR(18)= ''

   DECLARE @t_IQCDetail       TABLE
         ( QC_Key             NVARCHAR(10) NOT NULL DEFAULT('')
         , QCLineNo           NVARCHAR(5)  NOT NULL DEFAULT('')  PRIMARY KEY
         , FromID             NVARCHAR(18) NOT NULL DEFAULT('')
         )
         

   SET @b_Success = 1
   SET @c_ErrMsg = ''

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

   BEGIN TRY
      BEGIN TRAN
      
      SELECT @c_ToFacility = iq.to_facility
      FROM InventoryQC AS iq WITH (NOLOCK) 
      WHERE iq.QC_Key = @c_QC_Key
      
      INSERT INTO @t_IQCDetail
          (
              QC_Key
          ,   QCLineNo
          ,   FromID
          )
      SELECT iq.QC_Key
         ,  iq.QCLineNo
         ,  iq.FromID
      FROM InventoryQCDetail AS iq WITH (NOLOCK)
      WHERE iq.QC_Key = @c_QC_Key
      AND iq.FromID <> ''
      AND Toloc = ''
      
      IF @@ROWCOUNT = 0
      BEGIN
         GOTO EXIT_SP
      END

      SELECT TOP 1 
             @c_QCLineNo_UnMatch = CASE WHEN l.Facility = @c_ToFacility THEN '' ELSE RTRIM(tid.QCLineNo) END
            ,@c_FromID_UnMatch   = CASE WHEN l.Facility = @c_ToFacility THEN '' ELSE RTRIM(tid.FromID) END
      FROM @t_IQCDetail AS tid
      LEFT OUTER JOIN dbo.LOC AS l WITH (NOLOCK) ON l.Loc = tid.FromID 
      ORDER BY 2 DESC, 1
      
      IF @c_QCLineNo_UnMatch <> ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 560051
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': FromID: ' + @c_FromID_UnMatch + ' is invalid location for To Facility: ' + @c_ToFacility
                       + ', QC Line #: ' + @c_QCLineNo_UnMatch
                       + '. (lsp_IQC_RCM_CopyFromID2ToLoc) |' + @c_FromID_UnMatch + '|' + @c_ToFacility + '|' + @c_QCLineNo_UnMatch
         GOTO EXIT_SP         
      END

      UPDATE iq WITH (ROWLOCK)
      SET   iq.ToLoc = ti.FromID
         ,  iq.TrafficCop = NULL
      FROM InventoryQCDetail iq 
      JOIN @t_IQCDetail ti ON ti.QC_Key = iq.QC_Key AND ti.QCLineNo = iq.QCLineNo
      
      IF @@ERROR <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 560052
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error on Update InventoryQCDetail table. (lsp_IQC_RCM_CopyFromID2ToLoc)'
         GOTO EXIT_SP
      END
      
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
      IF @@TRANCOUNT > 0
      BEGIN
         ROLLBACK TRAN
      END
     
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_IQC_RCM_CopyFromID2ToLoc'
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