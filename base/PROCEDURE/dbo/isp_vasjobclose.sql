SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_VASJobClose                                    */  
/* Creation Date: 26-JAN-2016                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#361399 - Project Merlion - Add RCM for Partial WO       */ 
/*          complete                                                    */
/*                                                                      */  
/* Called By: ue_jobclose                                               */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */ 
/************************************************************************/  
CREATE PROC [dbo].[isp_VASJobClose]    
     @c_JobKey     NVARCHAR(10)
   , @b_Success    INT           OUTPUT    
   , @n_Err        INT           OUTPUT    
   , @c_ErrMsg     NVARCHAR(250) OUTPUT    
AS    
BEGIN    
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF  
    
   DECLARE  @n_Continue             INT     
         ,  @n_StartTCnt            INT  -- Holds the current transaction count     
  
         ,  @c_Facility             NVARCHAR(5)
         ,  @c_Storerkey            NVARCHAR(15)

         ,  @c_SQL                  NVARCHAR(MAX)
         ,  @c_SQLParm              NVARCHAR(MAX)
         ,  @c_JobValidationRules   NVARCHAR(30)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue   =  1
   SET @b_Success    =  1 
   SET @n_Err        =  0  
   SET @c_ErrMsg     =  '' 

   
   SELECT @c_Storerkey = Storerkey
   FROM WORKORDERJOBDETAIL WITH (NOLOCK)
   WHERE JobKey = @c_JobKey 

   BEGIN TRAN

   IF EXISTS ( SELECT 1
               FROM WORKORDERJOBDETAIL WITH (NOLOCK)
               WHERE JobKey = @c_JobKey
               AND   JobStatus = '9'
              )
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63705  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'Job is closed. (isp_VASJobClose)' 
      GOTO QUIT_SP
   END

   IF EXISTS ( SELECT 1
               FROM WORKORDERJOBDETAIL WITH (NOLOCK)
               WHERE JobKey = @c_JobKey
               AND   JobStatus = '8'
              )
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63710  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'Job had cancelled and not allow to close. (isp_VASJobClose)' 
      GOTO QUIT_SP
   END

   SELECT @c_JobValidationRules = SC.sValue
   FROM STORERCONFIG SC WITH (NOLOCK)
   JOIN CODELKUP CL WITH (NOLOCK) ON SC.sValue = CL.Listname
   WHERE SC.StorerKey = @c_StorerKey
   AND SC.Configkey = 'JOBExtendedValidation'

   IF ISNULL(@c_JobValidationRules,'') <> ''
   BEGIN
      EXEC isp_JOB_ExtendedValidation @c_JobKey = @c_JobKey 
                                    , @c_JobValidationRules = @c_JobValidationRules 
                                    , @b_Success= @b_Success OUTPUT
                                    , @c_ErrMsg = @c_ErrMsg  OUTPUT


      IF @b_Success <> 1
      BEGIN
         SET @n_Continue = 3
         SET @n_err=63715
         GOTO QUIT_SP
      END
   END
   ELSE   
   BEGIN  
      SELECT @c_JobValidationRules = SC.sValue    
      FROM STORERCONFIG SC WITH (NOLOCK) 
      WHERE SC.StorerKey = @c_StorerKey 
      AND SC.Configkey = 'JOBExtendedValidation'    
      
      IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_JobValidationRules) AND type = 'P')          
      BEGIN          
         SET @c_SQL = 'EXEC ' + @c_JobValidationRules + ' @c_JobKey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '          

         EXEC sp_executesql @c_SQL          
             , N'@c_JobKey NVARCHAR(10), @b_Success Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'
             , @c_JobKey          
             , @b_Success OUTPUT          
             , @n_Err     OUTPUT          
             , @c_ErrMsg  OUTPUT 


         IF @b_Success <> 1     
         BEGIN    
            SET @n_Continue = 3    
            SET @n_err=63720     
            GOTO QUIT_SP
         END         
      END  
   END            

   UPDATE WORKORDER_PALLETIZE WITH (ROWLOCK)
   SET Status   = '9'
      ,EditDate = GETDATE()
      ,EditWho  = SUSER_NAME()  
   WHERE JobKey = @c_JobKey
   AND Status < '9'

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63725  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDER_PALLETIZE. (isp_VASJobClose)' 
      GOTO QUIT_SP
   END

   UPDATE WORKORDER_UNCASING WITH (ROWLOCK)
   SET Status   = '9'
      ,EditDate = GETDATE()
      ,EditWho  = SUSER_NAME()  
   WHERE JobKey = @c_JobKey
   AND Status < '9'

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63730  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDER_UNCASING. (isp_VASJobClose)' 
      GOTO QUIT_SP
   END

   UPDATE WORKORDERJOBMOVE WITH (ROWLOCK)
   SET Status   = '9'
      ,EditDate = GETDATE()
      ,EditWho  = SUSER_NAME()  
   WHERE JobKey = @c_JobKey
   AND Status  < '9'

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63735  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBMOVE. (isp_VASJobClose)' 
      GOTO QUIT_SP
   END

   UPDATE WORKORDERJOBOPERATION WITH (ROWLOCK)
   SET JobStatus   = '9'
      ,EditDate = GETDATE()
      ,EditWho  = SUSER_NAME()  
   WHERE JobKey = @c_JobKey
   AND JobStatus  < '9'

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63740  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBOPERATION. (isp_VASJobClose)' 
      GOTO QUIT_SP
   END

   UPDATE WORKORDERREQUEST WITH (ROWLOCK)
   SET WOStatus   = '9'
      ,EditDate = GETDATE()
      ,EditWho  = SUSER_NAME()  
   FROM WORKORDERJOB WOJ     WITH (NOLOCK)
   JOIN WORKORDERREQUEST WOR ON (WOJ.WorkOrderkey = WOR.WorkOrderkey)
   WHERE WOJ.JobKey = @c_JobKey
   AND   WOR.QtyRemaining = 0
   AND   EXISTS ( SELECT 1 
                  FROM WORKORDERJOB WITH (NOLOCK)
                  WHERE WORKORDERJOB.Workorderkey = WOR.WorkOrderkey
                  AND   WORKORDERJOB.JobStatus < '8'
                  GROUP BY WORKORDERJOB.Workorderkey
                  HAVING COUNT( DISTINCT JobKey ) <= 1
                )

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63745  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOB. (isp_VASJobClose)' 
      GOTO QUIT_SP
   END

   UPDATE WORKORDERJOB WITH (ROWLOCK)
   SET JobStatus   = '9'
      ,EditDate = GETDATE()
      ,EditWho  = SUSER_NAME()  
   WHERE JobKey = @c_JobKey
   AND JobStatus  < '9'

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63745  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOB. (isp_VASJobClose)' 
      GOTO QUIT_SP
   END

   UPDATE WORKORDERJOBDETAIL WITH (ROWLOCK)
   SET    JobStatus = '9'
   WHERE  JobKey = @c_JobKey
   AND    JobStatus < '9'

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63550  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBDETAIL. (isp_VASJobClose)' 
      GOTO QUIT_SP
   END
QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SET @b_Success = 0    
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

      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_VASJobClose'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN 
      SET @b_Success = 1    
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   
      RETURN    
   END    
    
END -- Procedure  

GO