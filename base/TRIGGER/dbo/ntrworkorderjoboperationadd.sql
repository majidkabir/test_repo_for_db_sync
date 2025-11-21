SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Trigger: ntrWorkOrderJobOperationAdd                                    */
/* Creation Date: 21-Sep-2015                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Update other transactions while WorkOrderJobOperation line    */
/*           is added                                                      */
/*                                                                         */
/* Return Status:                                                          */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Called By: When records Updated                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Modifications:                                                          */
/* Date         Author   Ver  Purposes                                     */
/***************************************************************************/
CREATE TRIGGER ntrWorkOrderJobOperationAdd ON WORKORDERJOBOPERATION 
FOR INSERT
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

   DECLARE @n_QtyItemsOrd     INT
         , @n_QtyItemsRes     INT
         , @n_QtyNonInvOrd    INT
         , @n_QtyReleased     INT

         , @c_JobKey          NVARCHAR(10)   
         , @c_JobLineNo       NVARCHAR(5)

   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT   
   
   SET @c_JobKey        = ''
   SET @c_JobLineNo     = ''

   IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   BEGIN
      SET @n_continue = 4
      GOTO QUIT
   END

   DECLARE CUR_JOB CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT INSERTED.Jobkey
   FROM INSERTED 
   ORDER BY INSERTED.Jobkey

   OPEN CUR_JOB

   FETCH NEXT FROM CUR_JOB INTO  @c_Jobkey

   WHILE @@FETCH_STATUS <> -1  
   BEGIN
      SET @n_QtyItemsOrd = 0
      SET @n_QtyNonInvOrd= 0
      SELECT  @n_QtyItemsOrd = ISNULL(SUM(CASE WHEN RTRIM(SKU) <> '' THEN StepQty ELSE 0 END),0)
            , @n_QtyNonInvOrd= ISNULL(SUM(CASE WHEN RTRIM(NonInvSku) <> '' THEN StepQty ELSE 0 END),0)
      FROM WORKORDERJOBOPERATION WITH (NOLOCK)
      WHERE JobKey = @c_JobKey

      UPDATE WORKORDERJOBDETAIL WITH (ROWLOCK)
      SET EditWho   = SUSER_NAME()
         ,EditDate  = GETDATE()
         ,QtyItemsOrd  = @n_QtyItemsOrd
         ,QtyItemsNeed = @n_QtyItemsOrd - QtyItemsRes
         ,QtyNonInvOrd = @n_QtyNonInvOrd
         ,QtyNonInvNeed= @n_QtyNonInvOrd - QtyNonInvRes
      WHERE JobKey = @c_JobKey

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63705  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBDETAIL. (ntrWorkOrderJobOperationAdd)' 
         GOTO QUIT
      END
      FETCH NEXT FROM CUR_JOB INTO  @c_Jobkey
   END
   CLOSE CUR_JOB 
   DEALLOCATE CUR_JOB
QUIT:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_JOB') in (0 , 1)  
   BEGIN
      CLOSE CUR_JOB
      DEALLOCATE CUR_JOB
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_JOBOP') in (0 , 1)  
   BEGIN
      CLOSE CUR_JOBOP
      DEALLOCATE CUR_JOBOP
   END

   /* #INCLUDE <TRRDA2.SQL> */    
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrWorkOrderJobOperationAdd'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR  

      RETURN    
   END    
   ELSE    
   BEGIN    
      WHILE @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         COMMIT TRAN    
      END    

      RETURN    
   END      
END

GO