SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispPreRefreshWrapper                                        */
/* Creation Date: 25-JUN-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: MBOL Recalculate;                                           */
/*        : SOS#346256 - Project Merlion - Mbol Case Count Add On       */
/* Called By: ue_PreRefresh                                             */
/*          : exe_n_cst_visual_exceed                                   */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 22-Sep-2017  TLTING    1.1 Misisng NOLOCK                            */
/************************************************************************/
CREATE PROC [dbo].[ispPreRefreshWrapper] 
            @c_BusObj      NVARCHAR(50) 
         ,  @c_Key1        NVARCHAR(50) 
         ,  @c_Key2        NVARCHAR(50)  
         ,  @c_Key3        NVARCHAR(50) 
         ,  @b_Success     INT = 0  OUTPUT 
         ,  @n_err         INT = 0  OUTPUT 
         ,  @c_errmsg      NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON   -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt INT
         , @n_Continue  INT 
        
         , @c_Storerkey NVARCHAR(15)
         , @c_SubSP     NVARCHAR(10)

         , @c_SQL       NVARCHAR(MAX)      
         , @c_SQLParm   NVARCHAR(MAX)  

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
  
   BEGIN TRAN
   IF @c_BusObj = 'n_cst_mbol'
   BEGIN    
      SET @c_Storerkey = ''
      SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey
      FROM MBOLDETAIL WITH (NOLOCK)
      JOIN ORDERS     WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)
      WHERE MBOLDETAIL.MBOLKey = @c_Key1

      SET @c_SubSP = ''
      SELECT @c_SubSP = SC.SValue
      FROM STORERCONFIG SC WITH (NOLOCK)
      WHERE Storerkey = @c_Storerkey
      AND Configkey = 'MBOLPREREFESH_SP'

      IF @c_SubSP = ''
      BEGIN
         SET @c_SubSP = 'ispMBPRF01'
      END
      -- tlting
      IF NOT EXISTS (SELECT 1 FROM sys.objects o WITH (NOLOCK) WHERE NAME = @c_SubSP AND TYPE = 'P')
      BEGIN
         SET @n_Continue = 3    
         SET @n_Err = 63500   
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Stored Procedure Name ' + @c_SubSP + ' Not Found (ispPreRefreshWrapper)'
         GOTO QUIT          
      END

      SET @c_SQL = N'EXECUTE ' + @c_SubSP +  
         '  @c_MBOLKey  = @c_Key1 '  +  
         ', @b_Success  = @b_Success     OUTPUT ' +  
         ', @n_Err      = @n_Err         OUTPUT ' +  
         ', @c_ErrMsg   = @c_ErrMsg      OUTPUT '  

      SET @c_SQLParm =  N'@c_Key1  NVARCHAR(10), '  
                     +   '@b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Key1, 
                         @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT 

      IF @@ERROR <> 0 OR @b_Success <> 1  
      BEGIN  
         SET @n_Continue= 3    
         SET @n_Err     = 63505    
         SET @c_ErrMsg  =  'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_SubSP +   
                           CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (ispPreRefreshWrapper)'
         GOTO QUIT                          
      END 
   END
   
QUIT:
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPreRefreshWrapper'
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