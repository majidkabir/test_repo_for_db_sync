SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispFinalizeLoadPlan                                         */
/* Creation Date: 21-OCT-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 355118 - Finalize Load Plan                                 */ 
/*                                                                      */
/* Called By: nep_n_cst_loadplan.Event ue_finalizeLoadPlan              */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-12-13  Wan01    1.1   LFWM-3249 - UAT RG  Dock door booking     */
/*                            backend + SP                              */
/*                            DevOps Combine Order                      */
/************************************************************************/
CREATE PROC [dbo].[ispFinalizeLoadPlan] 
      @c_Loadkey        NVARCHAR(10) 
   ,  @b_Success        INT = 0  OUTPUT 
   ,  @n_err            INT = 0  OUTPUT 
   ,  @c_errmsg         NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   DECLARE @n_StartTranCnt             INT
         , @n_Continue                 INT 
         , @c_Storerkey                NVARCHAR(15)
         , @c_Facility                 NVARCHAR(5)
         , @c_Status                   NVARCHAR(10)
         , @c_FinalizeFlag             NVARCHAR(1)
         , @c_LOADExtendedValidation   NVARCHAR(10)   
         , @c_PostFinalizeLoadPlan_SP  NVARCHAR(10)
         , @c_SQL                      NVARCHAR(2000)
         , @c_RaiseErr                 NCHAR(1)
         
         , @c_LoadToTransportOrder     NVARCHAR(30) = ''             --(Wan01)

   SET @n_StartTranCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @c_Storerkey = ''
   SET @c_Facility  = ''
   SET @c_Status       = ''
   SET @c_FinalizeFlag = 'N' 
   SET @c_RaiseErr = 'N'

   SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey
              , @c_Facility = LOADPLAN.Facility
              , @c_Status = LOADPLAN.Status 
              , @c_FinalizeFlag = LOADPLAN.FinalizeFlag  
   FROM LOADPLAN       WITH (NOLOCK)
   JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLAN.LoadKey = LOADPLANDETAIL.LoadKey)
   JOIN ORDERS     WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)
   WHERE LOADPLAN.LoadKey = @c_LoadKey
      
   IF @c_Status = '9'
   BEGIN
      SET @n_continue = 3
      SET @n_err = 72800
      SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Finalize rejected. LOADPLAN had been shipped. (ispFinalizeLoadPlan)'
      GOTO QUIT
   END

   IF @c_FinalizeFlag = 'Y'
   BEGIN
      SET @n_continue=3
      SET @n_err=72805
      SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Finalize rejected. LOADPLAN had been finalized. (ispFinalizeLoadPlan)'
      GOTO QUIT
   END

   SET @c_LOADExtendedValidation = ''
   SET @b_success = 0
   EXECUTE dbo.nspGetRight @c_facility    -- facility   
          ,  @c_Storerkey                 -- Storerkey
          ,  NULL                         -- Sku
          ,  'LOADExtendedValidation'     -- Configkey
          ,  @b_success                OUTPUT
          ,  @c_LOADExtendedValidation OUTPUT
          ,  @n_err                    OUTPUT
          ,  @c_errmsg                 OUTPUT

   IF @b_success = 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 72810
      SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Executing nspGetRight (ispFinalizeLoadPlan)' 
                    + @c_errmsg
      GOTO QUIT
   END
 
   IF ISNULL(@c_LOADExtendedValidation,'') <> ''
   BEGIN 
      IF EXISTS(SELECT 1 FROM CODELKUP c WITH(NOLOCK) WHERE c.LISTNAME = @c_LOADExtendedValidation)
      BEGIN
         EXEC isp_LOAD_ExtendedValidation @c_Loadkey = @c_Loadkey,
                                          @c_Storerkey = @c_Storerkey,
                                          @c_LOADValidationRules = @c_LOADExtendedValidation,
                                          @b_Success = @b_Success OUTPUT, 
                                          @c_ErrMsg = @c_ErrMsg OUTPUT         
                                              
         IF @b_Success <> 1  
         BEGIN  
            SET @n_Continue = 3
            SET @n_err = 72820   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': LOADPLAN Validation Failed. (ispFinalizeLoadPlan) ' 
                         + @c_errmsg
            GOTO QUIT
         END      
      END
      ELSE
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_LOADExtendedValidation) AND type = 'P')          
         BEGIN          
            SET @c_SQL = 'EXEC ' + @c_LOADExtendedValidation + ' @c_Loadkey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '          
            EXEC sp_executesql @c_SQL,          
                 N'@c_LoadKey NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT',                         
                 @c_Loadkey,          
                 @b_Success OUTPUT,          
                 @n_err OUTPUT,          
                 @c_ErrMsg OUTPUT
                     
            IF @b_Success <> 1     
            BEGIN    
               SET @n_Continue = 3
               SET @n_err = 72830   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': LOADPLAN Validation Failed. (ispFinalizeLoadPlan) ' 
                            + @c_errmsg
               GOTO QUIT
            END         
         END  
      END
   END
   
   --(Wan01) - START
   IF @n_Continue IN ( 1, 2 )
   BEGIN
      SELECT @c_LoadToTransportOrder = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'LoadToTransportOrder')
      IF @c_LoadToTransportOrder = '1'
      BEGIN
         EXEC isp_LoadToTransportOrder
               @c_Loadkey  = @c_Loadkey   
            ,  @b_Success  = @b_Success   OUTPUT 
            ,  @n_err      = @n_err       OUTPUT 
            ,  @c_errmsg   = @c_errmsg    OUTPUT
            
         IF @b_Success = 0 
         BEGIN
            SET @n_Continue = 3
            GOTO QUIT
         END  
      END
   END
   --(Wan01) - END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE LOADPLAN WITH (ROWLOCK)
      SET FinalizeFlag = 'Y'
         ,EditWho = SUSER_NAME()
         ,EditDate= GETDATE()
      WHERE Loadkey = @c_LoadKey
      
      IF @@ERROR <> 0
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(CHAR(250),@n_err)
         SET @n_err = 72840  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE LOADPLAN Failed. (ispFinalizeLoadPlan)'
         GOTO QUIT
      END  
   END
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @b_success = 0      
      SET @c_PostFinalizeLoadPlan_SP = ''
      
      EXECUTE dbo.nspGetRight @c_facility    -- facility   
             ,  @c_Storerkey                 -- Storerkey
             ,  NULL                         -- Sku
             ,  'PostFinalizeLoadPlan_SP'     -- Configkey
             ,  @b_success                  OUTPUT
             ,  @c_PostFinalizeLoadPlan_SP  OUTPUT
             ,  @n_err                      OUTPUT
             ,  @c_errmsg                   OUTPUT

      IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_PostFinalizeLoadPlan_SP) AND type = 'P')          
      BEGIN          
         SET @c_SQL = 'EXEC ' + @c_PostFinalizeLoadPlan_SP + ' @c_Loadkey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '          
         EXEC sp_executesql @c_SQL,          
              N'@c_LoadKey NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT',                         
              @c_Loadkey,          
              @b_Success OUTPUT,          
              @n_err OUTPUT,          
              @c_ErrMsg OUTPUT
                  
         IF @b_Success <> 1     
         BEGIN    
            SET @n_Continue = 3
            SET @n_err = 72850   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': LOADPLAN Post Finalize Failed. (ispFinalizeLoadPlan) ' 
                         + @c_errmsg
            SET @c_RaiseErr = 'Y'
            GOTO QUIT
         END         
      END  
   END

QUIT:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispFinalizeLoadPlan'
      
      IF @c_RaiseErr = 'Y'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012         
         
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END   
END -- procedure

GO