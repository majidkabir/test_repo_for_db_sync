SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_UnpickpackORD_Wrapper                          */  
/* Creation Date: 05-Oct-2012                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#249056:Unpickpack Orders                                */  
/*          Storerconfig UnpickpackORD_SP={SPName} to enable UNpickpack */
/*          Process                                                     */
/*                                                                      */  
/* Called By: RCM Unpickpack Orders At Unpickpack Orders screen         */    
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 2020-06-04  Wan01    1.1   WMS-13120 - [PH] NIKE - WMS UnPacking Module*/
/************************************************************************/  

CREATE PROCEDURE [dbo].[isp_UnpickpackORD_Wrapper]  
      @c_OrderKey       NVARCHAR(10)   
   ,  @c_ConsoOrderkey  NVARCHAR(30)  
   ,  @c_UPPLoc         NVARCHAR(10)
   ,  @c_UnpickMoveKey  NVARCHAR(10)  OUTPUT  
   ,  @b_Success        INT           OUTPUT 
   ,  @n_Err            INT           OUTPUT 
   ,  @c_ErrMsg         NVARCHAR(250) OUTPUT
   ,  @c_Loadkey        NVARCHAR(10) = ''    --(Wan01)
   ,  @c_MBOLKey        NVARCHAR(10) = ''    --(Wan01) Ready for future if request to unpickpack by MBOL
   ,  @c_WaveKey        NVARCHAR(10) = ''    --(Wan01)
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_Continue      INT
         , @n_StartTCnt     INT
         , @c_SPCode        NVARCHAR(10)
         , @c_StorerKey     NVARCHAR(15)  = ''  --(Wan01)
         --, @c_Loadkey       NVARCHAR(10)      --(Wan01)
         , @c_SQL           NVARCHAR(MAX)

   SET @n_err        = 0
   SET @b_success    = 1
   SET @c_errmsg     = ''

   SET @n_Continue   = 1
   SET @n_StartTCnt  = @@TRANCOUNT
   SET @c_SPCode     = ''
   SET @c_StorerKey  = ''
   --SET @c_Loadkey    = ''      --(Wan01)
   SET @c_SQL        = ''
   
   WHILE @@TRANCOUNT > 0
   BEGIN 
      COMMIT TRAN
   END

   IF @c_Orderkey <> ''
   BEGIN
      SET @c_Loadkey = ''
      SELECT @c_Storerkey = ISNULL(RTRIM(ORDERS.Storerkey),'')
            ,@c_Loadkey   = ISNULL(RTRIM(ORDERS.Loadkey),'') 
      FROM ORDERS WITH (NOLOCK)
      WHERE ORDERS.Orderkey = @c_OrderKey
   END
   ELSE IF @c_LoadKey <> ''
   BEGIN
      SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey
      FROM ORDERS WITH (NOLOCK)
      WHERE ORDERS.Loadkey = @c_Loadkey
   END
   ELSE IF @c_MBOLKey <> ''
   BEGIN
      SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey
      FROM ORDERS WITH (NOLOCK)
      WHERE ORDERS.MBOLKey = @c_MBOLKey
   END 
   ELSE IF @c_WaveKey <> ''
   BEGIN
      SELECT TOP 1 @c_Storerkey = OH.Storerkey
      FROM WAVEDETAIL WD WITH (NOLOCK) 
      JOIN ORDERS     OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
      WHERE WD.Wavekey = @c_WaveKey
   END

   SELECT @c_SPCode = sVALUE 
   FROM   StorerConfig WITH (NOLOCK) 
   WHERE  StorerKey = @c_StorerKey
   AND    ConfigKey = 'UnpickpackORD_SP'  

   IF ISNULL(RTRIM(@c_SPCode),'') = ''
   BEGIN       
       SET @n_Continue = 3  
       SET @n_Err = 31211 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                     + ': Please Setup Stored Procedure Name into Storer Configuration(UnpickpackORD_SP) for '
                     + RTRIM(@c_StorerKey)+ '. (isp_UnpickpackORD_Wrapper)'  
       GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SET @n_Continue = 3  
       SET @n_Err = 31212
       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                     + ': Storerconfig UnpickpackORD_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))
                     + '). (isp_UnpickpackORD_Wrapper)'  
       GOTO QUIT_SP
   END

   BEGIN TRAN
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_Orderkey = @c_Orderkey, @c_Loadkey = @c_Loadkey, @c_ConsoOrderkey = @c_ConsoOrderkey'
              + ', @c_UPPLoc = @c_UPPLoc, @c_UnpickMoveKey = @c_UnpickMoveKey OUTPUT'  
              + ', @b_Success= @b_Success OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT '
              + ', @c_MBOLKey= @c_MBOLKey, @c_WaveKey = @c_Wavekey'

   EXEC sp_executesql @c_SQL 
      , N'@c_Orderkey NVARCHAR(10), @c_Loadkey NVARCHAR(10), @c_ConsoOrderkey NVARCHAR(30), @c_UPPLoc NVARCHAR(10)
        , @c_UnpickMoveKey NVARCHAR(10) OUTPUT, @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT
        , @c_MBOLKey NVARCHAR(10), @c_Wavekey NVARCHAR(10)' 
      , @c_OrderKey
      , @c_Loadkey
      , @c_ConsoOrderkey
      , @c_UPPLoc
      , @c_UnpickMoveKey   OUTPUT
      , @b_Success         OUTPUT                       
      , @n_Err             OUTPUT  
      , @c_ErrMsg          OUTPUT
      , @c_MBOLKey                  --(Wan01)
      , @c_Wavekey                  --(Wan01)

        
   IF @b_Success <> 1
   BEGIN
       SELECT @n_Continue = 3  
       GOTO QUIT_SP
   END

   QUIT_SP:
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN

         --(Wan01) - START
         WHILE @@TRANCOUNT < @n_StartTCnt
         BEGIN
            BEGIN TRAN
         END
         --(Wan01) - END
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @n_err, @c_errmsg, 'isp_UnpickpackORD_Wrapper'
      --RAISERROR @n_err @c_errmsg
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