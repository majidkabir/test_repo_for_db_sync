SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: WM.lsp_IQC_RCM_CopyCCLogicalLoc2ToLoc               */  
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
CREATE PROCEDURE [WM].[lsp_IQC_RCM_CopyCCLogicalLoc2ToLoc] 
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

   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT
         
         , @c_ToFacility      NVARCHAR(5) = ''
         , @c_ToLoc           NVARCHAR(10)= ''

   DECLARE @t_IQCDetail       TABLE
         ( QC_Key             NVARCHAR(10) NOT NULL DEFAULT('')
         , QCLineNo           NVARCHAR(5)  NOT NULL DEFAULT('')  PRIMARY KEY
         , FromLoc            NVARCHAR(10) NOT NULL DEFAULT('')
         , CCLogicalLoc       NVARCHAR(10) NOT NULL DEFAULT('')         
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
          ,   FromLoc
          ,   CCLogicalLoc
          )
      SELECT 
            iq.QC_Key
         ,  iq.QCLineNo
         ,  iq.FromLoc
         ,  l.CCLogicalLoc
      FROM InventoryQCDetail AS iq WITH (NOLOCK)
      JOIN dbo.LOC AS l WITH (NOLOCK) ON l.Loc = iq.FromLoc
      WHERE iq.QC_Key = @c_QC_Key
      AND iq.FromLoc <> ''
      
      IF @@ROWCOUNT = 0
      BEGIN
         GOTO EXIT_SP
      END
      
      ;  WITH upd AS
      (
         SELECT TOP 1 WITH TIES 
               tid.QC_Key
            ,  tid.QCLineNo
            ,  l.Loc
         FROM @t_IQCDetail AS tid
         JOIN dbo.LOC AS l WITH (NOLOCK) ON l.CCLogicalLoc = tid.CCLogicalLoc
         WHERE l.Facility = @c_ToFacility
         ORDER BY ROW_NUMBER() OVER(PARTITION BY tid.QC_Key, tid.QCLineNo 
                                    ORDER BY CASE WHEN l.Loc <> tid.FromLoc THEN '0' + LOC ELSE '9' + tid.FromLoc END)
      )
      
      UPDATE iq WITH (ROWLOCK)
      SET   iq.ToLoc = upd.Loc
         ,  iq.TrafficCop = NULL
      FROM InventoryQCDetail iq 
      JOIN upd ON upd.QC_Key = iq.QC_Key AND upd.QCLineNo = iq.QCLineNo
      
      IF @@ERROR <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 559901
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error on Update InventoryQCDetail table. (lsp_IQC_RCM_CopyCCLogicalLoc2ToLoc)'
         GOTO EXIT_SP
      END
      
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH

   EXIT_SP:
   
   IF (XACT_STATE()) = -1  -- Happens when there is a mistchmatching of begin..commit statement
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
     
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_IQC_RCM_CopyCCLogicalLoc2ToLoc'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt -- Need a Batch Commit at Main Call if success
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