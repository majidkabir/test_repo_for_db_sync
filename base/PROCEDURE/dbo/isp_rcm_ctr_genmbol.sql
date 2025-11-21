SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/    
/* Stored Procedure: isp_RCM_CTR_GenMBOL                                 */    
/* Creation Date: 2022-02-25                                             */    
/* Copyright: LFL                                                        */    
/* Written by: Wan                                                       */    
/*                                                                       */    
/* Purpose: LFWM-3354 - [CN]UAT Carters - Create Mbol header in Container*/  
/*          Manifest                                                     */  
/*                                                                       */    
/* Called By:                                                            */    
/*                                                                       */    
/* Version: 1.0                                                          */    
/*                                                                       */    
/* Data Modifications:                                                   */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date        Author   Ver   Purposes                                   */    
/* 2022-02-25  Wan      1.0   Created.                                   */  
/* 2022-02-25  Wan      1.0   DevOps Conmbine Script                     */
/* 2023-06-23  LUKE     1.1   JSM-158391                                 */
/*                            UPDATE @_batch from 0 to 1 (Luke01)        */  
/*************************************************************************/   
CREATE   PROCEDURE [dbo].[isp_RCM_CTR_GenMBOL]    
   @c_ContainerKey   NVARCHAR(10)   
,  @b_Success        INT          = 1   OUTPUT     
,  @n_Err            INT          = 0   OUTPUT  
,  @c_ErrMsg         NVARCHAR(255)= ''  OUTPUT  
,  @c_Code           NVARCHAR(30) = ''           
AS    
BEGIN    
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_Continue        INT = 1  
         , @n_StartTCnt       INT = @@TRANCOUNT  
  
         , @c_Loc             NVARCHAR(10) = ''  
         , @c_MBOLKey         NVARCHAR(10) = ''  
         , @c_Facility        NVARCHAR(5)  = ''  
  
   SET @b_Success = 1  
   SET @c_ErrMsg = ''  
  
   SET @n_Err = 0   
  
   BEGIN TRAN  
  
   SELECT TOP 1 @c_Loc = p2.Loc  
   FROM dbo.CONTAINER AS c WITH (NOLOCK)  
   JOIN dbo.CONTAINERDETAIL AS c2 WITH (NOLOCK) ON  c2.ContainerKey = c.ContainerKey  
   JOIN dbo.PALLET AS p WITH (NOLOCK) ON p.PalletKey = c2.PalletKey  
   JOIN dbo.PALLETDETAIL AS p2 WITH (NOLOCK) ON p2.PalletKey = p.PalletKey  
   WHERE c.ContainerKey = @c_ContainerKey  
   ORDER BY p2.PalletLineNumber  
        
   SELECT @c_Facility = l.Facility  
   FROM dbo.LOC AS l WITH (NOLOCK)   
   WHERE l.Loc = @c_Loc  
  
   EXEC dbo.nspg_GetKey  
         @KeyName    = N'MBOL'  
      ,  @fieldlength= 10  
      ,  @keystring  = @c_MBOLKey   OUTPUT  
      ,  @b_Success  = @b_Success   OUTPUT  
      ,  @n_Err      = @n_Err       OUTPUT  
      ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT  
      ,  @b_resultset= 0            
      ,  @n_batch    = 1     -- LUKE01
           
   IF @b_Success = 0  
   BEGIN           
      SET @n_Continue = 3             
      GOTO QUIT_SP  
   END  
        
   INSERT INTO MBOL (Facility, MBOLkey)    
   VALUES (@c_Facility, @c_MBOLKey)    
    
   SET @n_Err = @@ERROR    
   IF @n_Err <> 0    
   BEGIN    
      SET @n_Continue = 3    
      SET @n_Err = 30102    
      SET @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert MBOL fail. (isp_RCM_CTR_GenMBOL)'    
      GOTO QUIT_SP   
   END     
        
   UPDATE dbo.CONTAINER WITH (ROWLOCK)  
   SET MBOLKey = @c_MBOLKey   
      ,EditWHo = SUSER_SNAME()  
      ,EditDate= GETDATE()  
   WHERE ContainerKey = @c_ContainerKey  
                        
   SET @n_Err = @@ERROR    
   IF @n_Err <> 0    
   BEGIN    
      SET @n_Continue = 3    
      SET @n_Err = 30102    
      SET @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Update Container fail. (isp_RCM_CTR_GenMBOL)'    
      GOTO QUIT_SP    
   END   
        
   EXEC dbo.isp_MBOLReleasePickTask_Wrapper  
         @c_MbolKey  = @c_MBOLKey  
      ,  @b_Success  = @b_Success OUTPUT  
      ,  @n_Err      = @n_Err OUTPUT  
      ,  @c_ErrMsg   = @c_ErrMsg OUTPUT  
        
   IF @b_Success = 0    
   BEGIN    
      SET @n_Continue = 3    
      GOTO QUIT_SP    
   END   
  
   QUIT_SP:  
     
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt         
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
  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_RCM_CTR_GenMBOL'  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
  
   REVERT        
END    

GO