SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrWorkOrderHeaderUpdate                                    */
/* Creation Date: 13-Aug-2007                                           */
/* Copyright: IDS                                                       */
/* Written by: YokeBeen                                                 */
/*                                                                      */
/* Purpose: Handle trigger point of WorkOrder table updates.            */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  Any related Updates of table WorkOrder.                  */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Date         Author     Ver.  Purposes                               */
/* 25 May 2012  TLTING01   1.0   DM integrity - add update editdate B4  */
/*                               TrafficCop for status < '9'            */ 
/* 28-Oct-2013  TLTING     1.0   Review Editdate column update          */
/* 30-May-2017  YokeBeen   1.1   Revised and moved the trigger points   */
/*                               to a Sub-SP - isp_ITF_ntrWorkOrder.    */
/*                               - (YokeBeen01).                        */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrWorkOrderHeaderUpdate]
ON  [dbo].[WorkOrder]
FOR UPDATE
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

   DECLARE @b_debug int
   SET @b_debug = 0

   DECLARE   
     @b_Success            INT       
   , @n_err                INT       
   , @n_err2               INT       
   , @c_errmsg             NVARCHAR(250) 
   , @n_continue           INT
   , @n_starttcnt          INT
   , @c_preprocess         NVARCHAR(250) 
   , @c_pstprocess         NVARCHAR(250) 
   , @n_cnt                INT      

   DECLARE   
     @c_WorkOrderKey       NVARCHAR(10) 
   , @c_Status             NVARCHAR(10) 
   , @c_StorerKey          NVARCHAR(15) 

   --(YokeBeen01) - START
   DECLARE 
     @c_TriggerName        NVARCHAR(120) 
   , @c_SourceTable        NVARCHAR(60) 
   , @c_ExternStatus       NVARCHAR(10) 
   , @b_ColumnsUpdated     VARBINARY(1000) 

   SET @b_ColumnsUpdated   = COLUMNS_UPDATED() 
   SET @c_TriggerName      = 'ntrWorkOrderHeaderUpdate'
   SET @c_SourceTable      = 'WORKORDER'
   --(YokeBeen01) - END

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4
   END
   
   -- tlting01
   IF EXISTS ( SELECT 1 FROM INSERTED, DELETED 
                WHERE INSERTED.StorerKey =  DELETED.StorerKey
                  AND INSERTED.WorkOrderKey =  DELETED.WorkOrderKey
                  AND ( INSERTED.[Status] < '9' OR DELETED.[Status] < '9')  ) 
         AND ( @n_continue = 1 OR @n_continue = 2 )
         AND NOT UPDATE(EditDate)
	BEGIN 	
	 	UPDATE WORKORDER WITH (ROWLOCK) 
    	   SET EditDate = GETDATE(), 
             EditWho  = SUser_SName(),
             TrafficCop = NULL 
        FROM WORKORDER  
        JOIN INSERTED ON (WORKORDER.StorerKey    = INSERTED.StorerKey
                     AND WORKORDER.WorkOrderKey  = INSERTED.WorkOrderKey) 
        JOIN DELETED  ON (INSERTED.StorerKey     = DELETED.StorerKey
                     AND INSERTED.WorkOrderKey   = DELETED.WorkOrderKey )
       WHERE ( INSERTED.[Status] < '9' OR DELETED.[Status] < '9' )

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
	 	IF @n_err <> 0
    	BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=68003   
    	   SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + 
                            ': Update Failed On Table WORKORDER. (ntrWorkOrderHeaderUpdate) ( SQLSvr MESSAGE=' + 
                            dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
    	END
	END

   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_continue = 4
   END

   IF ( @n_continue = 1 OR @n_continue = 2 ) AND NOT UPDATE(EditDate)
	BEGIN 	
	 	UPDATE WORKORDER WITH (ROWLOCK) 
    	   SET EditDate = GETDATE(), 
             EditWho  = SUser_SName(),
             TrafficCop = NULL 
        FROM WORKORDER  
        JOIN INSERTED ON (WORKORDER.StorerKey = INSERTED.StorerKey
                      AND WORKORDER.WorkOrderKey = INSERTED.WorkOrderKey) 
       WHERE WORKORDER.[Status] = '9'

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

	 	IF @n_err <> 0
    	BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=68001   
    	   SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + 
                            ': Update Failed On Table WORKORDER. (ntrWorkOrderHeaderUpdate) ( SQLSvr MESSAGE=' + 
                            dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
    	END
	END


   IF @n_continue = 1 OR @n_continue = 2 -- (Trigger Point)
   BEGIN 
/********************************************************/
/* Interface Trigger Points Calling Process - (Start)   */
/********************************************************/
   -- (YokeBeen01) - Start
      DECLARE Cur_WorkOrder_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      -- Extract values for required variables
       SELECT DISTINCT INSERTED.WorkOrderKey
         FROM INSERTED 
         JOIN ITFTriggerConfig WITH (NOLOCK) ON ( ITFTriggerConfig.StorerKey = INSERTED.StorerKey )
        WHERE ITFTriggerConfig.SourceTable = @c_SourceTable
          AND ITFTriggerConfig.sValue      = '1'
       UNION 
       SELECT DISTINCT INSERTED.WorkOrderKey 
         FROM INSERTED   
         JOIN ITFTriggerConfig WITH (NOLOCK) ON ( ITFTriggerConfig.StorerKey = 'ALL' )
         JOIN StorerConfig WITH (NOLOCK) ON ( StorerConfig.StorerKey = INSERTED.StorerKey AND 
                                              StorerConfig.ConfigKey = ITFTriggerConfig.ConfigKey AND 
                                              StorerConfig.SValue = '1' )
        WHERE ITFTriggerConfig.SourceTable = @c_SourceTable 
          AND ITFTriggerConfig.sValue      = '1' 

      OPEN Cur_WorkOrder_TriggerPoints  
      FETCH NEXT FROM Cur_WorkOrder_TriggerPoints INTO @c_WorkOrderKey 

      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         -- Execute SP - isp_ITF_ntrWorkOrderHeader
         EXECUTE dbo.isp_ITF_ntrWorkOrderHeader
                  @c_TriggerName    = @c_TriggerName
                , @c_SourceTable    = @c_SourceTable
                , @c_WorkOrderKey   = @c_WorkOrderKey
                , @b_ColumnsUpdated = @b_ColumnsUpdated 
                , @b_Success        = @b_Success OUTPUT
                , @n_err            = @n_err     OUTPUT
                , @c_errmsg         = @c_errmsg  OUTPUT

         FETCH NEXT FROM Cur_WorkOrder_TriggerPoints INTO @c_WorkOrderKey
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE Cur_WorkOrder_TriggerPoints
      DEALLOCATE Cur_WorkOrder_TriggerPoints
   -- (YokeBeen01) - End
   END -- IF @n_continue = 1 OR @n_continue = 2 -- (Trigger Point)
/********************************************************/
/* Interface Trigger Points Calling Process - (End)     */
/********************************************************/

	/* #INCLUDE <TRRDA2.SQL> */    
   IF @n_continue=3  -- Error Occured - Process And Return    
   BEGIN    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt    
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

      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'ntrWorkOrderHeaderUpdate'    
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