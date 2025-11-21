SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Trigger:  ntrReplenishmentDelete                                     */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:  Trigger Inventory Move when Confirm Replenishment          */  
/*                                                                      */  
/*                                                                      */  
/*                                                                      */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Called By: Replenishment Record Delete                               */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Purposes                                      */  
/* 14-Jul-2011  KHLim02    1.2   GetRight for Delete log                */
/* 19-May-2017  SHONG     Include MoveRefNo when Calling Itrn Move      */
/* 07-JUL-2017  SHONG     Update QtyReplen and Double 11                */
/*                        PendingMoveIn to LotXLocXId (SWT01)           */ 
/* 13-Sep-2019  SHONG     LoseID Location should set ToID to ''         */  
/* 18-Aug-2022  WLChooi   WMS-20526 - ReplenUpdateUCC (WL01)            */
/* 18-Aug-2022  WLChooi   DevOps Combine Script                         */
/************************************************************************/  
CREATE   TRIGGER [dbo].[ntrREPLENISHMENTDelete]
ON [dbo].[REPLENISHMENT]
FOR DELETE
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

   DECLARE  @b_Success     int,       -- Populated by calls to stored procedures - was the proc successful?
        @n_err         int,       -- Error number returned by stored procedure or this trigger
        @c_errmsg      NVARCHAR(250), -- Error message returned by stored procedure or this trigger
        @n_continue    int,       -- continuation flag: 
                                  -- 1=Continue, 
                                  -- 2=failed but continue processsing, 
                                  -- 3=failed do not continue processing, 
                                  -- 4=successful but skip further processing
        @n_starttcnt   int,       -- Holds the current transaction count
        @n_cnt         int        -- Holds the number of rows affected by the DELETE statement that fired this trigger.
      , @c_authority   NVARCHAR(1)  -- KHLim02

   --WL01 S
   DECLARE @c_ReplenUpdateUCC   NVARCHAR(20)  
          ,@c_Option1           NVARCHAR(50)  
          ,@c_Option2           NVARCHAR(50)  
          ,@c_Option3           NVARCHAR(50)  
          ,@c_Option4           NVARCHAR(50)  
          ,@c_Option5           NVARCHAR(4000)
          ,@c_UCCNoField        NVARCHAR(30) 
          ,@c_DropID            NVARCHAR(20)  
          ,@c_RefNo             NVARCHAR(20)   
   --WL01 E
   
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
   
   IF (SELECT COUNT(*) FROM DELETED) =
      (SELECT COUNT(*) FROM DELETED WHERE DELETED.ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS(  
         SELECT 1  
         FROM NSQLCONFIG WITH (NOLOCK)  
         WHERE ConfigKey = 'RepleDelLog' AND  
               NSQLValue = '1'  
       )  
      BEGIN  
         INSERT INTO DEL_Replenishment 
               (ReplenishmentKey, ReplenishmentGroup, Storerkey, Sku, FromLoc, ToLoc, Lot, Id, Qty, QtyMoved, 
               QtyInPickLoc, Priority, UOM, PackKey, ArchiveCop, Confirmed, ReplenNo, Remark, AddDate, AddWho, 
               EditDate, EditWho, RefNo, DropID, LoadKey, Wavekey, OriginalFromLoc, OriginalQty, [ToID], 
               DeleteDate, DeleteWho, SourceType, [MoveRefKey], PendingMoveIn,
               QtyReplen )  
         SELECT ReplenishmentKey, ReplenishmentGroup, Storerkey, Sku, FromLoc, ToLoc, Lot, Id, Qty, QtyMoved, 
               QtyInPickLoc, Priority, UOM, PackKey, ArchiveCop, Confirmed, ReplenNo, Remark, AddDate, AddWho,
               EditDate, EditWho, RefNo, DropID, LoadKey, Wavekey, OriginalFromLoc, OriginalQty, [ToID], 
               getdate(), suser_sname(), 'delete', MoveRefKey, PendingMoveIn,
               QtyReplen
         FROM DELETED  
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table REPLENISHMENT Failed. (ntrReplenishmentDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END 
   
   DECLARE @c_ReplenishmentKey     NVARCHAR(10),
           @c_Storerkey            NVARCHAR(15),
           @c_Sku                  NVARCHAR(20),
           @c_FromLoc              NVARCHAR(10),
           @c_Lot                  NVARCHAR(10),
           @c_Id                   NVARCHAR(18),
           @n_Qty                  INT,
           @c_MoveRefKey           NVARCHAR(10),
           @c_PickDetailKey        NVARCHAR(18),
           @c_TaskDetailKey        NVARCHAR(10),
           @n_PickDetQty           INT          
         , @n_PendingMoveIn        INT --SWT01
         , @n_QtyReplen            INT --SWT01
         , @c_Confirmed            NVARCHAR(1) --SWT01 
         , @c_ToLoc                NVARCHAR(10)
         , @c_ToId                 NVARCHAR(18)
         , @c_LoseID               NVARCHAR(10)
           
   IF @n_continue = 1 or @n_continue = 2
   BEGIN   	   
      DECLARE cur_Del_Replenishment CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ReplenishmentKey, Storerkey, Sku, FromLoc, Lot, Id, Qty, 
             ISNULL(MoveRefKey,''), ISNULL(PendingMoveIn,0), ISNULL(QtyReplen, 0), 
             Confirmed, ToLoc, ISNULL(ToID, ISNULL(ID,'')), RefNo, DropID   --WL01
      FROM DELETED
   
      OPEN cur_Del_Replenishment
   
      FETCH FROM cur_Del_Replenishment INTO 
         @c_ReplenishmentKey, @c_Storerkey, @c_Sku,
         @c_FromLoc, @c_Lot, @c_Id, @n_Qty, @c_MoveRefKey, @n_PendingMoveIn, 
         @n_QtyReplen, @c_Confirmed, @c_ToLoc, @c_ToID, @c_RefNo, @c_DropID   --WL01
   
      WHILE @@FETCH_STATUS = 0
      BEGIN
   	   IF @c_MoveRefKey <> ''
   	   BEGIN
   		   DECLARE cur_PickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   		   SELECT PickDetailKey, MoveRefKey 
   		   FROM PICKDETAIL WITH (NOLOCK) 
   		   WHERE Storerkey = @c_Storerkey
   		   AND   Sku = @c_Sku 
   		   AND   Lot = @c_Lot 
   		   AND   Loc = @c_FromLoc 
   		   AND   [Status] < '5'  
   		   AND  (MoveRefKey IS NOT NULL AND MoveRefKey <> '') 
   		
   		   OPEN cur_PickDetail
   		
   		   FETCH FROM cur_PickDetail INTO @c_PickDetailKey, @c_MoveRefKey
   		
   		   WHILE @@FETCH_STATUS = 0
   		   BEGIN
   			   UPDATE PICKDETAIL WITH (ROWLOCK)
   			   SET MoveRefKey = '', 
   			       TrafficCop = NULL,
   			       EditDate   = GETDATE(), 
   			       EditWho    = SUSER_SNAME()
   			   WHERE PickDetailKey = @c_PickDetailKey  
   		
   			   FETCH FROM cur_PickDetail INTO @c_PickDetailKey, @c_MoveRefKey
   		   END
   		   CLOSE cur_PickDetail
   		   DEALLOCATE cur_PickDetail
   	   END

         IF @n_QtyReplen > 0 AND ISNULL(@c_Lot,'') <> '' AND ISNULL(@c_FromLoc,'') <> '' AND @c_Confirmed  <> 'Y'
         BEGIN
            IF EXISTS(SELECT 1 FROM LOTXLOCXID (NOLOCK)                                                         
                      WHERE Lot = @c_Lot                                                                        
                      AND Loc = @c_FromLoc                                                                      
                      AND ID = @c_Id)                                                                       
            BEGIN                                                                                               
         	   UPDATE LOTXLOCXID WITH (ROWLOCK)                                                                 
               SET QtyReplen = CASE WHEN (QtyReplen - @n_QtyReplen) < 0 THEN 0 ELSE QtyReplen - @n_QtyReplen END,                                                   
                   EditWho = SUSER_SNAME(),
                   EditDate = GETDATE()
               WHERE Lot = @c_Lot                                                                               
               AND Loc = @c_FromLoc                                                                             
               AND ID = @c_Id                                                                               
                                                                                                             
               SET @n_err = @@ERROR                                                                             
                                                                                                             
               IF @n_err <> 0                                                                                   
               BEGIN                                                                                            
                  SELECT @n_continue = 3
                        ,@n_err = 68000 
                  SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                         ':  Update LOTXLOCXID Failed! (ntrReplenishmentDelete)'
               END                                                                                              
            END                                                                                                 
         END -- IF @n_QtyReplen > 0
        IF @n_PendingMoveIn > 0 AND ISNULL(@c_Lot,'') <> '' AND ISNULL(@c_ToLoc,'') <> '' AND @c_Confirmed  <> 'Y'
        BEGIN
            SET @c_LoseID = '0'  
                 
            SELECT @c_LoseID = LoseId  
            FROM LOC WITH (NOLOCK)  
            WHERE Loc = @c_ToLoc  
              
            IF @c_LoseID = '1'  
             SET @c_ToID = ''

           IF EXISTS(SELECT 1 FROM LOTXLOCXID (NOLOCK)                                                         
                     WHERE Lot = @c_Lot                                                                        
                     AND Loc = @c_ToLoc                                                                      
                     AND ID = @c_ToID)                                                                       
           BEGIN                                                                                               
       	 	  UPDATE LOTxLOCxID 
       	 	         SET PendingMoveIn = CASE WHEN (PendingMoveIn - @n_PendingMoveIn) < 0 THEN 0 
       	 	                                 ELSE PendingMoveIn - @n_PendingMoveIn 
       	 	                           END,
                        EditDate = GETDATE(),   
                        EditWho = SUSER_SNAME()       	 	         
       	 	  WHERE Lot = @c_LOT 
                AND LOC = @c_ToLoc      
                AND ID  = @c_ToID     
                                                                                                               
              SET @n_err = @@ERROR                                                                             
                                                                                                               
              IF @n_err <> 0                                                                                   
              BEGIN                                                                                            
                 SELECT @n_continue = 3
                       ,@n_err = 68001 
                 SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                        ':  Execute rdt.rdt_Putaway_PendingMoveIn Failed! (ntrTaskDetailDelete)'
              END                                                                                              
           END                                                                                                 
        END 
        
         --WL01 S
         IF (@n_Continue = 1 OR @n_Continue = 2) AND @c_Confirmed <> 'Y'
         BEGIN
            SET @c_ReplenUpdateUCC = '0'

            SELECT @b_success = 0

            EXECUTE nspGetRight                                
               @c_Facility        = '',                     
               @c_StorerKey       = @c_StorerKey,                    
               @c_sku             = '',
               @c_ConfigKey       = 'ReplenUpdateUCC',
               @b_Success         = @b_success           OUTPUT,             
               @c_Authority       = @c_ReplenUpdateUCC   OUTPUT,             
               @n_err             = @n_err               OUTPUT,             
               @c_errmsg          = @c_errmsg            OUTPUT,             
               @c_Option1         = @c_Option1           OUTPUT,               
               @c_Option2         = @c_Option2           OUTPUT,               
               @c_Option3         = @c_Option3           OUTPUT,               
               @c_Option4         = @c_Option4           OUTPUT,               
               @c_Option5         = @c_Option5           OUTPUT 

            IF ISNULL(@c_UCCNoField,'') = ''
               SELECT @c_UCCNoField = dbo.fnc_GetParamValueFromString('@c_UCCNoField', @c_Option5, @c_UCCNoField)  

            IF ISNULL(@c_UCCNoField,'') = ''
               SET @c_UCCNoField = 'DropID'
               
            IF @c_ReplenUpdateUCC = '1' AND @c_UCCNoField IN ('DropID', 'RefNo')
            BEGIN
               UPDATE UCC WITH (ROWLOCK)
               SET [Status] = CASE WHEN @c_Confirmed = 'N' THEN '1' ELSE [Status] END
               WHERE UCCNo = CASE WHEN @c_UCCNoField = 'DropID' THEN @c_DropID ELSE @c_RefNo END
               AND [Status] <= '6'
            END
         END
         --WL01 E
                        
         FETCH FROM cur_Del_Replenishment INTO 
                  @c_ReplenishmentKey, @c_Storerkey, @c_Sku,
                  @c_FromLoc, @c_Lot, @c_Id, @n_Qty, @c_MoveRefKey, @n_PendingMoveIn, 
                  @n_QtyReplen, @c_Confirmed, @c_ToLoc, @c_ToID, @c_RefNo, @c_DropID   --WL01 
      END
   
      CLOSE cur_Del_Replenishment
      DEALLOCATE cur_Del_Replenishment
   END -- IF @n_continue = 1 or @n_continue = 2   
   

   /* #INCLUDE <TRCONHD1.SQL> */     
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @b_success = 0         --    Start (KHLim02)
      EXECUTE nspGetRight  NULL,             -- facility  
                           NULL,             -- Storerkey  
                           NULL,             -- Sku  
                           'DataMartDELLOG', -- Configkey  
                           @b_success     OUTPUT, 
                           @c_authority   OUTPUT, 
                           @n_err         OUTPUT, 
                           @c_errmsg      OUTPUT  
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
               ,@c_errmsg = 'ntrReplenishmentDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
         INSERT INTO dbo.REPLENISHMENT_DELLOG ( ReplenishmentKey )
         SELECT ReplenishmentKey FROM DELETED

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Delete Trigger On Table REPLENISHMENT Failed. (ntrReplenishmentDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
         END
      END
   END

      /* #INCLUDE <TRCOND2.SQL> */
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrReplenishmentDelete'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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