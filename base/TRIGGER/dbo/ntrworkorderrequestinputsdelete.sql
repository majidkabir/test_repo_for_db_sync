SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Trigger: ntrWorkOrderRequestInputsDelete                                */
/* Creation Date: 24-Jul-2015                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Delete Job's transaction if delete input component            */
/*                                                                         */
/* Return Status:                                                          */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Called By: When records Inserted                                        */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Modifications:                                                          */
/* Date         Author   Ver  Purposes                                     */
/***************************************************************************/
CREATE TRIGGER ntrWorkOrderRequestInputsDelete ON WORKORDERREQUESTINPUTS
FOR DELETE
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT                     
         , @n_StartTCnt       INT            -- Holds the current transaction count    
         , @b_Success         INT            -- Populated by calls to stored procedures - was the proc successful?    
         , @n_err             INT            -- Error number returned by stored procedure or this trigger    
         , @c_errmsg          NVARCHAR(255)  -- Error message returned by stored procedure or this trigger    

         , @c_Jobkey             NVARCHAR(10)
         , @c_WorkOrderkey       NVARCHAR(10)
         , @c_WkOrdReqInputsKey  NVARCHAR(10)
   
   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT 

   IF (SELECT COUNT(1) FROM DELETED) = (SELECT COUNT(1) FROM DELETED WHERE DELETED.ArchiveCop = '9')  
   BEGIN
      SET @n_Continue = 4
      GOTO QUIT
   END  

   IF EXISTS ( SELECT 1
               FROM DELETED
               JOIN WORKORDERJOB WOJ  WITH (NOLOCK) ON (DELETED.WorkOrderkey = WOJ.WorkOrderkey)
               WHERE WOJ.QtyJob > 0 
               AND NOT EXISTS (SELECT 1 
                               FROM WORKORDERREQUESTINPUTS WORI WITH (NOLOCK) 
                               WHERE WORI.WorkOrderkey = DELETED.WorkOrderkey)
             )
   BEGIN
      SET @n_Continue= 3 
      SET @n_err  = 60070
      SET @c_errmsg = 'Workorder has assigned to Job. Not Allow to delete all workorder inputs.'
                    + '(ntrWorkOrderRequestInputsDelete)'
      GOTO QUIT
   END


   DECLARE CUR_DELINPUT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DELETED.WorkOrderkey
         ,DELETED.WkOrdReqInputsKey
   FROM DELETED 

   OPEN CUR_DELINPUT
   
   FETCH NEXT FROM CUR_DELINPUT INTO @c_WorkOrderkey
                                    ,@c_WkOrdReqInputsKey

   WHILE @@FETCH_STATUS <> -1  
   BEGIN
      DECLARE CUR_JOB CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT WORKORDERJOB.JobKey
      FROM WORKORDERJOB WITH (NOLOCK)
      WHERE WORKORDERJOB.WorkOrderkey = @c_WorkOrderkey

      OPEN CUR_JOB
      
      FETCH NEXT FROM CUR_JOB INTO @c_Jobkey

      WHILE @@FETCH_STATUS <> -1  
      BEGIN
         SET @b_Success = 0  
         EXEC dbo.ispCancJobOperationInput 
                 @c_Jobkey  = @c_Jobkey
               , @c_WorkOrderkey = @c_WorkOrderkey
               , @c_WkOrdReqInputsKey = @c_WkOrdReqInputsKey
               , @b_Success = @b_Success     OUTPUT  
               , @n_Err     = @n_err         OUTPUT   
               , @c_ErrMsg  = @c_errmsg      OUTPUT  

         IF @n_err <> 0  
         BEGIN 
            SET @n_Continue= 3 
            SET @n_err  = 60075
            SET @c_errmsg = 'Execute ispCancJobOperationInput Failed.'
                          + '(' + @c_errmsg + '). (ntrWorkOrderRequestInputsDelete)'
            GOTO QUIT
         END 
         FETCH NEXT FROM CUR_JOB INTO @c_Jobkey
      END
      CLOSE CUR_JOB
      DEALLOCATE CUR_JOB

      FETCH NEXT FROM CUR_DELINPUT INTO @c_WorkOrderkey
                                       ,@c_WkOrdReqInputsKey
   END
   CLOSE CUR_DELINPUT
   DEALLOCATE CUR_DELINPUT
QUIT:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_DELINPUT') in (0 , 1)  
   BEGIN
      CLOSE CUR_DELINPUT
      DEALLOCATE CUR_DELINPUT
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_JOB') in (0 , 1)  
   BEGIN
      CLOSE CUR_JOB
      DEALLOCATE CUR_JOB
   END

   /* #INCLUDE <TRRDA2.SQL> */    
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SET @b_Success = 0

      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
      ELSE    
      BEGIN    
         WHILE @@TRANCOUNT > @n_starttcnt    
         BEGIN    
            COMMIT TRAN    
         END     
      END    

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrWorkOrderRequestInputsDelete'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR   

      RETURN    
   END    
   ELSE    
   BEGIN  
      SET @b_Success = 1
  
      WHILE @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         COMMIT TRAN    
      END    

      RETURN    
   END      
END

GO