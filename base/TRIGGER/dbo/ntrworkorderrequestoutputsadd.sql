SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Trigger: ntrWorkOrderRequestOutputsAdd                                  */
/* Creation Date: 03-Aug-2015                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: Calc QtyRemaining when Add new Output Line                     */
/*        : SOS#318089 - Project Merlion - VAP Add or Delete               */
/*                       Work Order Component (Wan01)                      */
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
CREATE TRIGGER ntrWorkOrderRequestOutputsAdd ON WORKORDERREQUESTOUTPUTS
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

   
         , @c_WorkOrderkey    NVARCHAR(10)
         , @c_WorkOrderType   NVARCHAR(10)
         , @n_PackQty         FLOAT

   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT   

   SET @c_WorkOrderType = 'O'

   IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   BEGIN
      SET @n_continue = 4
      GOTO QUIT
   END

   UPDATE WORKORDERREQUESTOUTPUTS WITH (ROWLOCK)
   SET Qty          = CASE WHEN WOR.UOMQty = 0 THEN 0 ELSE ((WORQO.Qty/WOR.UOMQty) * WOR.UOMQty) END
      ,QtyRemaining = CASE WHEN WOR.UOMQty = 0 THEN 0 ELSE ((WORQO.Qty/WOR.UOMQty) * WOR.UOMQty) END                        
      ,EditWho      = SUSER_NAME()
      ,EditDate     = GETDATE()
      ,Trafficcop   = NULL
   FROM INSERTED
   JOIN WORKORDERREQUEST WOR WITH (NOLOCK) ON (INSERTED.WorkOrderKey = WOR.Workorderkey)
   JOIN WORKORDERREQUESTOUTPUTS WORQO ON  (WOR.WorkOrderkey = WORQO.WorkOrderkey)
                                      AND (INSERTED.WkOrdReqOutputsKey = WORQO.WkOrdReqOutputsKey)
   --LEFT JOIN WORKORDEROUTPUTS   WOO   WITH (NOLOCK) ON (WORQO.WkOrdOutputsKey = WOO.WkOrdOutputsKey)  -- (Wan01)

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63705   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERREQUESTOUTPUTS. (ntrWorkOrderRequestUpdate)' 
      GOTO QUIT
   END 
   DECLARE CUR_WO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT INSERTED.WorkOrderkey
   FROM INSERTED 

   OPEN CUR_WO
   
   FETCH NEXT FROM CUR_WO INTO @c_WorkOrderkey

   WHILE @@FETCH_STATUS <> -1  
   BEGIN
      SET @n_PackQty = 0
      IF @c_WorkOrderType = 'O'
      BEGIN
         SELECT TOP 1 @n_PackQty = CASE WORO.UOM
                                   WHEN PACK.PACKUOM1 THEN PACK.CaseCnt
                                   WHEN PACK.PACKUOM2 THEN PACK.InnerPack
                                   WHEN PACK.PACKUOM3 THEN 1
                                   WHEN PACK.PACKUOM4 THEN PACK.Pallet
                                   WHEN PACK.PACKUOM5 THEN PACK.Cube
                                   WHEN PACK.PACKUOM6 THEN PACK.GrossWgt
                                   WHEN PACK.PACKUOM7 THEN PACK.NetWgt
                                   WHEN PACK.PACKUOM8 THEN PACK.OtherUnit1
                                   WHEN PACK.PACKUOM9 THEN PACK.OtherUnit2
                                   ELSE 1
                                   END
         FROM WORKORDERREQUESTOUTPUTS WORO WITH (NOLOCK) 
         JOIN PACK                    PACK WITH (NOLOCK) ON (WORO.Packkey = PACK.Packkey)
         WHERE WORO.WorkOrderkey = @c_Workorderkey
      END
    
      UPDATE WORKORDERREQUEST WITH (ROWLOCK)
      SET Qty          = UOMQty * @n_PackQty
         ,QtyRemaining = UOMQtyRemaining * @n_PackQty
         ,PackQty      = CASE WHEN @n_PackQty > 0 THEN @n_PackQty ELSE PackQty END
         ,EditWho      = SUSER_NAME() 
         ,EditDate     = GETDATE()
         ,Trafficcop   = NULL
      WHERE WorkOrderkey = @c_WorkOrderkey
      
      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63710   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Insert Failed Into Table WORKORDERREQUEST. (ntrWorkOrderRequestOutputAdd)' 
         GOTO QUIT
      END 

      FETCH NEXT FROM CUR_WO INTO @c_WorkOrderkey
   END
   CLOSE CUR_WO
   DEALLOCATE CUR_WO
QUIT:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_WO') in (0 , 1)  
   BEGIN
      CLOSE CUR_WO
      DEALLOCATE CUR_WO
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrWorkOrderRequestOutputsAdd'    
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