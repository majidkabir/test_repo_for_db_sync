SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Trigger: ntrWorkOrderStepsDelete                                        */
/* Creation Date: 22-Oct-2012                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Trigger when Delete Work Order Routing                        */
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

CREATE TRIGGER ntrWorkOrderStepsDelete ON WorkOrderSteps
AFTER DELETE 
AS
BEGIN
   IF @@ROWCOUNT = 0  
   BEGIN
	   RETURN
   END

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue  INT                     
         , @n_StartTCnt INT            -- Holds the current transaction count    
         , @b_Success   INT            -- Populated by calls to stored procedures - was the proc successful?    
         , @n_err       INT            -- Error number returned by stored procedure or this trigger    
         , @c_errmsg    NVARCHAR(255)  -- Error message returned by stored procedure or this trigger    

   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT     


   IF (SELECT COUNT(1) FROM DELETED) = (SELECT COUNT(1) FROM DELETED WHERE DELETED.ArchiveCop = '9')  
   BEGIN
	   SET @n_Continue = 4
      GOTO QUIT
   END

   IF EXISTS ( SELECT 1 
               FROM DELETED
               JOIN WORKORDERJOB WITH (NOLOCK) ON (DELETED.WorkOrderName = WORKORDERJOB.WorkOrderName)
             )  
   BEGIN
      SET @n_continue = 3
      SET @n_err=63701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Not Allow to delete Work Order Routing exists in WORKORDERJOB. (ntrWorkOrderRoutingDelete)'
      GOTO QUIT
   END

-- =============================================
-- Author:		SHONG
-- Create date: 22/10/2012
-- Description: Delete WorkOrder Inputs & Outputs 
-- =============================================
--CREATE TRIGGER ntrWorkOrderStepsDelete 
--   ON  dbo.WorkOrderSteps 
--   AFTER DELETE 
--AS 
--BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	SET NOCOUNT ON;

   DECLARE @c_WkOrdInputsKey NVARCHAR(10)
   
   DECLARE CUR_WorkOrderInputs CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT woi.WkOrdInputsKey 
   FROM WorkOrderInputs woi WITH (NOLOCK) 
   JOIN DELETED DEL ON DEL.MasterWorkOrder = woi.MasterWorkOrder 
                   AND DEL.WorkOrderName   = woi.WorkOrderName 
                   AND DEL.StepNumber      = woi.StepNumber 
                    
   OPEN CUR_WorkOrderInputs
   
   FETCH NEXT FROM CUR_WorkOrderInputs INTO @c_WkOrdInputsKey     
   WHILE @@FETCH_STATUS <> -1
   BEGIN
   	DELETE FROM WorkOrderInputs WHERE WkOrdInputsKey = @c_WkOrdInputsKey 
   	
   	FETCH NEXT FROM CUR_WorkOrderInputs INTO @c_WkOrdInputsKey
   END
   CLOSE CUR_WorkOrderInputs 
   DEALLOCATE CUR_WorkOrderInputs


   DECLARE @c_WkOrdOutputsKey NVARCHAR(10)
   
   DECLARE CUR_WorkOrderOutputs CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT woi.WkOrdOutputsKey 
   FROM WorkOrderOutputs woi WITH (NOLOCK) 
   JOIN DELETED DEL ON DEL.MasterWorkOrder = woi.MasterWorkOrder 
                   AND DEL.WorkOrderName   = woi.WorkOrderName 
                   AND DEL.StepNumber      = woi.StepNumber 
                    
   OPEN CUR_WorkOrderOutputs
   
   FETCH NEXT FROM CUR_WorkOrderOutputs INTO @c_WkOrdOutputsKey     
   WHILE @@FETCH_STATUS <> -1
   BEGIN
   	DELETE FROM WorkOrderOutputs WHERE WkOrdOutputsKey = @c_WkOrdOutputsKey 
   	
   	FETCH NEXT FROM CUR_WorkOrderOutputs INTO @c_WkOrdOutputsKey
   END
   CLOSE CUR_WorkOrderOutputs 
   DEALLOCATE CUR_WorkOrderOutputs
--END




QUIT:
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrWorkOrderRoutingDelete'    
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