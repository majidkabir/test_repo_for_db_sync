SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_RobotLoadITF_Wrapper                                */
/* Creation Date: 20-JUN-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-5240 - CN_Robot_Exceed_BulidLoad_Order_Trigger          */
/*                                                                      */                                             
/*        :                                                             */
/* Called By: isp_GenEOrder_Replenishment_Wrapper                       */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_RobotLoadITF_Wrapper]
           @c_Loadkey   NVARCHAR(10) 
         , @b_Success   INT            OUTPUT
         , @n_Err       INT            OUTPUT
         , @c_ErrMsg    NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt             INT
         , @n_Continue              INT 

         , @c_SQL                   NVARCHAR(MAX)
         , @c_SQLParms              NVARCHAR(MAX)

         , @c_Facility              NVARCHAR(5)
         , @c_StorerKey             NVARCHAR(15)

         , @c_ConfigKey             NVARCHAR(30)
         , @c_RobotLoadITF_SP       NVARCHAR(30)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   SET @c_StorerKey = ''
   SET @c_Facility  = ''

   SELECT TOP 1 
            @c_Facility  = LP.Facility
         ,  @c_StorerKey = OH.Storerkey
   FROM LOADPLAN LP WITH (NOLOCK)
   JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (LP.Loadkey = LPD.Loadkey)
   JOIN ORDERS         OH  WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey)
   WHERE LP.Loadkey = @c_Loadkey

   SET @c_ConfigKey = 'RobotLoadITF_SP'

   SET @b_Success = 1
   EXEC nspGetRight  
         @c_Facility            
      ,  @c_StorerKey             
      ,  ''       
      ,  @c_ConfigKey             
      ,  @b_Success           OUTPUT    
      ,  @c_RobotLoadITF_SP   OUTPUT  
      ,  @n_err               OUTPUT  
      ,  @c_errmsg            OUTPUT

   IF @b_Success <> 1 
   BEGIN 
      SET @n_Continue= 3    
      SET @n_Err     = 60010    
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing nspGetRight '  
                     + '.(isp_RobotLoadITF_Wrapper)'
      GOTO QUIT_SP  
   END

   IF NOT EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_RobotLoadITF_SP AND TYPE = 'P')
   BEGIN
      SET @n_Continue= 3    
      SET @n_Err     = 60020    
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Storer''s facility is not setup for Robot Interface'  
                     + '.(isp_RobotLoadITF_Wrapper)'
      GOTO QUIT_SP  
   END

   SET @c_SQL = N'EXECUTE ' + @c_RobotLoadITF_SP  
               + '  @c_Loadkey = @c_Loadkey' 
               + ', @b_Success = @b_Success     OUTPUT' 
               + ', @n_Err     = @n_Err         OUTPUT'  
               + ', @c_ErrMsg  = @c_ErrMsg      OUTPUT'  

   SET @c_SQLParms= N' @c_Loadkey   NVARCHAR(10)'  
                  +  ',@b_Success   INT OUTPUT'
                  +  ',@n_Err       INT OUTPUT'
                  +  ',@c_ErrMsg    NVARCHAR(250) OUTPUT'
                                 
   EXEC sp_ExecuteSQL @c_SQL
                  ,   @c_SQLParms
                  ,   @c_Loadkey
                  ,   @b_Success    OUTPUT
                  ,   @n_Err        OUTPUT
                  ,   @c_ErrMsg     OUTPUT 
  
   IF @@ERROR <> 0 OR @b_Success <> 1  
   BEGIN  
      SET @n_Continue= 3    
      SET @n_Err     = 60030    
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_RobotLoadITF_SP 
                     + '.(isp_RobotLoadITF_Wrapper)'
                     + ' ( SQLSvr MESSAGE=' + @c_ErrMsg + ' )'  
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RobotLoadITF_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO