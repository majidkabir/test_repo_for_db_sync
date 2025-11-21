SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPODYS01                                         */
/* Creation Date: 17-Jan-2018                                           */
/* Copyright: LFL                                                       */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-3534 - Retrieve Archived ASNTrade ReturnXDock Infor     */
/*          in Respective Screen                                        */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispPODYS01]
    @c_Orderkey   NVARCHAR(10)
  , @c_Loadkey    NVARCHAR(10)
  , @b_Success    INT           OUTPUT  
  , @n_Err        INT           OUTPUT  
  , @c_ErrMsg     NVARCHAR(250) OUTPUT  
  , @b_Debug      INT = 0  
AS    
BEGIN    
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF    

   DECLARE @n_Continue        INT   
         , @n_StartTCnt       INT 

   DECLARE @c_PickDetailKey   NVARCHAR(10) 
         , @c_LocationFlag    NVARCHAR(10) 
        
         , @CUR_PD            CURSOR

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue=1
   SET @b_Success=1
   SET @n_Err=0
   SET @c_ErrMsg=''

   SET @CUR_PD = CURSOR FAST_FORWARD READ_ONLY FOR 
   SELECT 
       PD.PickDetailkey
     , LOC.LocationFlag
   FROM PICKDETAIL PD WITH (NOLOCK)
   JOIN LOC WITH (NOLOCK) ON (PD.Loc = LOC.LOC)    
   WHERE PD.Orderkey = @c_Orderkey
   ORDER BY PD.PickDetailkey

   OPEN @CUR_PD

   FETCH NEXT FROM @CUR_PD INTO @c_PickDetailkey
                              , @c_LocationFlag

          
   WHILE (@@FETCH_STATUS <> -1)          
   BEGIN 
      UPDATE PICKDETAIL WITH (ROWLOCK)
      SET ToLoc = @c_LocationFlag
         ,EditWho= SUSER_NAME()
         ,EditDate = GETDATE() 
         ,Trafficcop = NULL
      WHERE PickDetailKey = @c_PickDetailKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 61010
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) 
                        + ': Update PickDetail Failed. (ispPODYS01)'
         GOTO QUIT_SP
      END

      FETCH NEXT FROM @CUR_PD INTO @c_PickDetailkey
                                 , @c_LocationFlag
   END
   CLOSE @CUR_PD
   DEALLOCATE @CUR_PD

   QUIT_SP:
   IF CURSOR_STATUS( 'VARIABLE', '@CUR_PD') in (0 , 1)  
   BEGIN
      CLOSE @CUR_PD           
      DEALLOCATE @CUR_PD      
   END 

  
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_Success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPODYS01'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END      
END -- Procedure

GO