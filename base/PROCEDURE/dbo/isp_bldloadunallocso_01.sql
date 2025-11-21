SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_BldLoadUnallocSO_01                            */  
/* Creation Date: 15-Apr-2019                                           */  
/* Copyright: LFL                                                       */  
/* Written by:Wan                                                       */  
/*                                                                      */  
/* Purpose: WMS-8633 - CN_Skecher_Robot_Exceed_BuildLoad_NewRCMMenu     */  
/*          (isp_BldLoadUnalloc_SO??)                                   */
/*                                                                      */  
/* Called By: Build Load Unallocate Order                               */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_BldLoadUnallocSO_01]  
      @c_LoadKey    NVARCHAR(10)  
   ,  @c_Storerkey  NVARCHAR(15) = ''     
   ,  @b_Success    INT             OUTPUT 
   ,  @n_Err        INT             OUTPUT 
   ,  @c_ErrMsg     NVARCHAR(250)   OUTPUT
   ,  @b_debug      INT = 0
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue        INT         = 1 
         , @n_StartTCnt       INT         = @@TRANCOUNT

         , @c_LoadLineNumber  NVARCHAR(5) = ''
         , @c_Orderkey        NVARCHAR(10)= '' 
         , @c_PickDetailKey   NVARCHAR(10)= ''

         , @CUR_LOADORD       CURSOR
         , @CUR_PD            CURSOR

   SET @n_err=0
   SET @b_success=1
   SET @c_errmsg=''
   
   IF EXISTS(  SELECT 1 FROM LOADPLAN LP WITH (NOLOCK)
               WHERE LP.LoadKey = @c_LoadKey
               AND LP.[Status] >= '3'
            )
   BEGIN
      SET @n_continue = 3  
      SET @n_Err = 31010 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                    + ': Load# ' + RTRIM(@c_Loadkey) + ' had been released/Picked/Shipped. (isp_BldLoadUnallocSO_01)'  
      
      GOTO QUIT_SP
   END

   SET @CUR_LOADORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT  LPD.LoadLineNumber 
         , LPD.Orderkey
   FROM LOADPLANDETAIL LPD WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey)
   WHERE LPD.LoadKey = @c_LoadKey
   AND   OH.[Status] IN ('0', '1')
   ORDER BY LPD.LoadLineNumber

   OPEN @CUR_LOADORD
   
   FETCH NEXT FROM @CUR_LOADORD INTO   @c_LoadLineNumber 
                                    ,  @c_Orderkey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      BEGIN TRAN
      SET @CUR_PD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT  PD.PickDetailKey 
      FROM PICKDETAIL PD WITH (NOLOCK)
      WHERE PD.Orderkey = @c_OrderKey

      OPEN @CUR_PD
   
      FETCH NEXT FROM @CUR_PD INTO  @c_PickDetailKey
                                    
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE PICKDETAIL  
         WHERE PickDetailKey = @c_PickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3  
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @n_Err = 31020 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Delete Pickdetail fail. (isp_BldLoadUnallocSO_01)'  
                          + '( ' + @c_ErrMsg + ')' 
      
            GOTO QUIT_SP
         END

         FETCH NEXT FROM @CUR_PD INTO  @c_PickDetailKey            
      END 
      CLOSE @CUR_PD
      DEALLOCATE @CUR_PD

      UPDATE ORDERS 
      SET M_Address4 = 'Y'
         ,Trafficcop  = NULL
      WHERE Orderkey = @c_Orderkey

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue = 3  
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @n_Err = 31030 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Update Order Table fail. (isp_BldLoadUnallocSO_01)'  
                       + '( ' + @c_ErrMsg + ')' 
      
         GOTO QUIT_SP
      END

      DELETE FROM LOADPLANDETAIL
      WHERE LoadKey = @c_LoadKey
      AND LoadLineNumber = @c_LoadLineNumber

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue = 3  
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @n_Err = 31040 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Update Loadplandetail Table fail. (isp_BldLoadUnallocSO_01)'  
                       + '( ' + @c_ErrMsg + ')' 
      
         GOTO QUIT_SP
      END

      IF @b_debug = 0
      BEGIN 
         WHILE @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END
      END

      FETCH NEXT FROM @CUR_LOADORD INTO   @c_LoadLineNumber 
                                       ,  @c_Orderkey
   END
   CLOSE @CUR_LOADORD 
   DEALLOCATE @CUR_LOADORD 

   QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_BldLoadUnallocSO_01'
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
END  
SET QUOTED_IDENTIFIER OFF

GO