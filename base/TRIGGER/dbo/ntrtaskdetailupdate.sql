SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/        
/* Trigger: ntrTaskDetailUpdate                                         */        
/* Creation Date:                                                       */        
/* Copyright: IDS                                                       */        
/* Written by:                                                          */        
/*                                                                      */        
/* Purpose:                                                             */        
/*                                                                      */        
/* Called By:                                                           */        
/*                                                                      */        
/* PVCS Version: 1.3                                                    */        
/*                                                                      */        
/* Version: 5.4                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Ver     Author   Purposes                               */        
/* 18-Sep-2009  1.1     Vicky    Fix UOM retrieval, original script     */        
/*                               parse in UOM = NULL causing MV not     */        
/*                               workable                               */        
/*                               RDT Compatible Error Message (Vicky01) */        
/* 13-Jan-2010  1.2     Vicky    Added the Non-Inventory Move Pending   */        
/*                               Move In Qty (Vicky02)                  */        
/* 14-Jan-2010  1.3     James    If PrepackByBOM config turned on, need */        
/*                               to loop for all component SKU (james01)*/        
/* 24-Feb-2010  1.4     ChewKP   Prompt Error when different user       */        
/*                               getting same task (ChewKP01)           */             
/* 25-Feb-2010  1.5     ChewKP   Update Parameter for ITRNAddMOVE       */        
/*                               (ChewKP02)                             */        
/* 03-Mar-2010  1.6     Vicky    Add in EditWho & EditDate (Vicky03)    */        
/* 11-Mar-2010  1.7     Vicky    Should pass in Lottables value into    */        
/*                               ItrnAddMove (Vicky04)                  */        
/* 21-Jun-2010  1.5     ChewKP   Create Record in LotxLocxID when       */        
/*                               ID = '' and ToLoc <> '' SOS#178103     */        
/*                               (ChewKP03)                             */        
/* 05-Jul-2010  1.6  ChewKP      Only Move by Qty in TaskDetail NoLoop  */        
/*                               required (ChewKP04)                    */        
/* 15-Jul-2010  1.7     KHLim    Replace sUSER_Name to sUSER_sName      */         
/* 15-Jul-2010  1.8     ChewKP   Offset LotxLocxID.QtyReplen (ChewKP05) */        
/* 10-Jul-2010  1.9     Vicky    Comment the Insertion of LotxLocxID    */        
/*                               (Vicky05)                              */        
/* 21-Sep-2010  2.0     James    Update editdate & editwho (james02)    */        
/* 02-Oct-2010  2.1     Shong    If Lottable03 = blank, get packkey from*/    
/*                               SKU (Shong01)                          */    
/* 26-Oct_2010  2.2     TLTING   Performance Tune                       */  
/* 08-Nov-2010  2.3     James    Update userkey & reasonkey blank when  */        
/*                               reset taskdetail status (james03)      */  
/* 23 May 2012  2.4     TLTING01 DM integrity - add update editdate B4  */  
/*                               TrafficCop                             */    
/* 07-Nov-2012  2.5     NJOW01   257259-When close task auto close alert*/  
/*                               if the task generated from alert       */  
/* 28-Oct-2013  2.6     TLTING   Review Editdate column update          */  
/* 18-Dec-2012  2.7     YTWan    SOS#260275: VAS-CreateJobs (Wan01)     */ 
/* 31-Mar-2014  2.8     ChewKP   AnF Project Enhancement (ChewKP06)     */
/* 30-Jul-2014  2.9     CSCHONG  Add Lottable06-15 (CS01)               */
/* 29-Sep-2014  3.0     KHLim    Move up ArchiveCop sequence (KH01)     */ 
/* 25-Feb-2015  3.1     CSCHONG  SOS#333694 - Prevent update sku if     */
/*                              taskdetailkey exist in pickdetail (CS01)*/
/* 05-MAY-2015  3.2     NJOW02   338845-call custom stored proc         */
/* 20-JAN-2016  3.3     Wan02    VAS - To Recalculate Operation task    */
/*                               Info when update qty                   */
/* 29-Sep-2016  3.4     Ung      Prevent recompile with SET ROWCOUNT    */
/* 05-JUN-2017  3.5     NJOW03   WMS-1986 Update QtyReplen and          */
/*                               PendingMoveIn to LotXLocXId            */ 
/* 30-Aug-2017  3.6     NJOW04   WMS-1965 support change Pendingmovein  */
/*                               and QtyReplen                          */
/************************************************************************/        
CREATE TRIGGER [dbo].[ntrTaskDetailUpdate]        
ON  [dbo].[TaskDetail]        
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
        
   DECLARE        
   @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?        
   ,         @n_err                int       -- Error number returned by stored procedure or this trigger        
   ,         @n_err2 int              -- For Additional Error Detection        
   ,         @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger        
   ,         @n_continue     int        
   ,         @n_starttcnt    int              -- Holds the current transaction count        
   ,         @c_preprocess   NVARCHAR(250)         -- preprocess        
   ,         @c_pstprocess   NVARCHAR(250)         -- post process        
   ,         @n_cnt          int        
   ,         @c_logicaltoloc NVARCHAR(10)  -- fbr028c        
   ,         @n_QtyToMove    INT    
   ,         @n_LotQty       INT    
   ,         @c_ReservedID   NVARCHAR(18) --NJOW04
       
   DECLARE @c_LocationCategy NVARCHAR(10) -- (Vicky02)        
        
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT        

   IF UPDATE(ArchiveCop)         --KH01  
   BEGIN        
      SELECT @n_continue = 4        
   END      
     
 -- tlting01  
   IF ( @n_continue = 1 or @n_continue = 2 ) AND NOT UPDATE(EditDate)  
   BEGIN  
      UPDATE Taskdetail SET TrafficCop = NULL, EditDate = GETDATE(), EditWho=SUSER_SNAME()   
      FROM Taskdetail,Inserted  
      WHERE Taskdetail.TaskdetailKey=Inserted.TaskdetailKey  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @n_err = 67838 --66700   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed On Table Taskdetail. (ntrTaskdetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
      END  
   END  
              
   IF UPDATE(TrafficCop)        
   BEGIN        
      SELECT @n_continue = 4        
   END        
           
   IF UPDATE(ArchiveCop)        
   BEGIN        
      SELECT @n_continue = 4        
   END        
   /* #INCLUDE <TRTASKDU1.SQL> */   
   
   --To Trace when is the FinalLoc updated to ToLoc
   IF UPDATE(FinalLoc)    
   BEGIN
	BEGIN TRY
		 DECLARE 
			@cNewToLoc NVARCHAR(30),
			@cNewFinalLoc NVARCHAR(30),
			@cNewStatus NVARCHAR(3),
			@cOldToLoc NVARCHAR(30),
			@cOldFinalLoc NVARCHAR(30),
			@cOldStatus NVARCHAR(3),
			@cTaskDetailKey NVARCHAR(10)

			SELECT @cNewToLoc = ToLoc,
				@cNewFinalLoc = FinalLoc,
				@cNewStatus = Status,
				@cTaskDetailKey = TaskDetailKey
			FROM INSERTED

			SELECT @cOldToLoc = ToLoc,
				@cOldFinalLoc = FinalLoc,
				@cOldStatus = Status
			FROM INSERTED

			IF @cNewToLoc = @cNewFinalLoc
			BEGIN
				INSERT INTO TraceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4, Col1, Col2, Col3, Col4)
				VALUES('TaskDetailUPDTrace', GETDATE(), CAST(@cNewToLoc AS NVARCHAR(20)), CAST(@cNewFinalLoc AS NVARCHAR(20)), @cNewStatus, CAST(SUSER_SNAME() AS NVARCHAR(20)), @cTaskDetailKey, @cOldToLoc, @cOldFinalLoc, @cOldStatus)
			END
		END TRY
		BEGIN CATCH
			INSERT INTO TraceInfo (TraceName, TimeIn, Col1)
			VALUES('TaskDetailUPDTrace', GETDATE(), 'Exception Happens')
		END CATCH
   END
           
   IF @n_continue=1 or @n_continue=2        
   BEGIN        
      IF EXISTS (SELECT * FROM deleted WHERE Status='9' )        
      BEGIN        
         SELECT @n_continue = 3        
         SELECT @n_err = 67818 --81301        
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Item(s) Are Completed - Update Failed. (ntrTaskDetailUpdate)'        
      END        
   END        

   --NJOW02
   IF @n_continue=1 or @n_continue=2          
   BEGIN
      IF EXISTS (SELECT 1 FROM DELETED d  
                 JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey    
                 JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
                 WHERE  s.configkey = 'TaskDetailTrigger_SP')  
      BEGIN        	  
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED

      	 SELECT * 
      	 INTO #INSERTED
      	 FROM INSERTED
            
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED

      	 SELECT * 
      	 INTO #DELETED
      	 FROM DELETED

         EXECUTE dbo.isp_TaskDetailTrigger_Wrapper
                   'UPDATE'  --@c_Action
                 , @b_Success  OUTPUT  
                 , @n_Err      OUTPUT   
                 , @c_ErrMsg   OUTPUT  

         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3  
                  ,@c_errmsg = 'ntrTaskDetailUpdate ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))
         END  
         
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED

         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
      END
   END   
           
   IF @n_continue = 1 or @n_continue = 2        
   BEGIN        
      DECLARE @c_taskdetailkey NVARCHAR(10), @c_tasktype NVARCHAR(10), @c_newtaskdetailkey NVARCHAR(10)        
      DECLARE @c_pickdetailkey NVARCHAR(10)        
      DECLARE @c_storerkey NVARCHAR(15), @c_sku NVARCHAR(20), @c_fromloc NVARCHAR(10), @c_fromid NVARCHAR(18),        
              @c_toloc NVARCHAR(10), @c_toid NVARCHAR(18), @c_lot NVARCHAR(10), @n_qty int, @c_packkey NVARCHAR(10), @c_uom NVARCHAR(10),        
              @c_caseid NVARCHAR(10), @c_sourcekey NVARCHAR(30), @c_sourcetype NVARCHAR(30), @c_Status NVARCHAR(10), @c_reasonkey NVARCHAR(10),        
              @c_wavekey NVARCHAR(10), @c_userposition NVARCHAR(10), @c_userkey NVARCHAR(18), @c_childid NVARCHAR(18)        
      DECLARE @c_deletedtasktype NVARCHAR(10), @c_deletedstorerkey NVARCHAR(15), @c_deletedsku NVARCHAR(20), @c_deletedfromloc NVARCHAR(10), @c_deletedfromid NVARCHAR(18),        
              @c_deletedtoloc NVARCHAR(10), @c_deletedtoid NVARCHAR(18), @c_deletedlot NVARCHAR(10), @n_deletedqty int, @c_deletedpackkey NVARCHAR(10), @c_deleteduom NVARCHAR(10),        
              @c_deletedcaseid NVARCHAR(10), @c_deletedsourcekey NVARCHAR(30), @c_deletedStatus NVARCHAR(10), @c_deletedreasonkey NVARCHAR(10),        
              @c_deleteduserposition NVARCHAR(10), @c_deleteduserkey NVARCHAR(18)        
      DECLARE @c_rc_toloc NVARCHAR(10), @c_rc_validinfromloc NVARCHAR(10), @c_rc_validintoloc NVARCHAR(10),        
              @c_rc_locholdkey NVARCHAR(10), @c_rc_idholdkey NVARCHAR(10), @c_rc_removetaskfromuserqueue NVARCHAR(10),        
              @c_rc_docyclecount NVARCHAR(10), @c_rc_taskStatus NVARCHAR(10), @c_rc_continueprocessing NVARCHAR(10)        
      DECLARE @c_work_loc NVARCHAR(10), @c_work_id NVARCHAR(18),        
              @n_qtynotmoved int, @n_scratch_qtytobemoved int, @n_checkcount int        
              
      DECLARE @b_isDiffFloor int, @c_fromoutloc NVARCHAR(10)        
      declare @c_unit NVARCHAR(10)        
        
      DECLARE @c_taskuom NVARCHAR(10) -- (Vicky01)        
        
      DECLARE @c_listkey             NVARCHAR(10), --NJOW01        
              @n_PendingMoveIn       INT, --NJOW03
              @n_deletedPendingMoveIn INT, --NJOW03
              @n_QtyReplen2          INT, --NJOW03
              @n_deletedQtyReplen     INT --NJOW03
        
      -- (Vicky04) - Start        
      DECLARE  @c_lottable01        NVARCHAR(18),        
               @c_lottable02        NVARCHAR(18),        
               @c_lottable03        NVARCHAR(18),        
               @d_lottable04        datetime,        
               @d_lottable05        datetime        
      -- (Vicky04) - End   
		
		 -- (CS01) - Start        
      DECLARE  @c_lottable06        NVARCHAR(30),        
               @c_lottable07        NVARCHAR(30),        
               @c_lottable08        NVARCHAR(30), 
					@c_lottable09        NVARCHAR(30),        
               @c_lottable10        NVARCHAR(30),        
               @c_lottable11        NVARCHAR(30), 
					@c_lottable12        NVARCHAR(30),
					@d_lottable13        datetime,       
               @d_lottable14        datetime,        
               @d_lottable15        datetime        
      -- (CS01) - End         
              
      -- (ChewKP05) - Start        
      DECLARE         
             @c_ReplenLot NVARCHAR(10)        
           , @n_QtyReplen INT        
           , @n_ddQty  INT        
           , @n_nQtyReplen INT        
      -- (ChewKP05) - End        
  
      --(Wan01) - START  
      DECLARE @c_RefTaskKey      NVARCHAR(10)  
  
      SET @c_RefTaskKey    = ''  
      --(Wan01) - END  
            
      SELECT @c_taskdetailkey = SPACE(10)        
              
      WHILE (1=1) and (@n_continue = 1 or @n_continue = 2)        
      BEGIN        
         SELECT TOP 1 
         @c_taskdetailkey = taskdetailkey,        
         @c_tasktype = tasktype ,        
         @c_storerkey = storerkey,        
         @c_sku = sku,        
         @c_fromloc = fromloc ,        
         @c_fromid = fromid ,        
         @c_toloc =  toloc ,        
         @c_toid = toid,        
         @c_lot = lot ,        
         @n_qty = qty,        
         @c_caseid = caseid,        
         @c_sourcekey = sourcekey,        
         @c_sourcetype = sourcetype,        
         @c_Status = Status,        
         @c_reasonkey = reasonkey,        
         @c_wavekey = wavekey,        
         @c_userposition = userposition,        
         @c_userkey = userkey,        
         @c_taskuom = UOM, -- (Vicky01)      
         @c_listkey = Listkey, --NJOW01   
         @c_RefTaskKey = RefTaskKey,                                                               --(Wan01)              
         @n_QtyReplen2 = QtyReplen, --NJOW03
         @n_PendingMoveIn = PendingMoveIn  --NJOW03
         FROM INSERTED        
         WHERE taskdetailkey > @c_Taskdetailkey        
         ORDER BY taskdetailkey        
                 
         IF @@ROWCOUNT = 0        
         BEGIN        
            BREAK        
         END        

         /*CS01 Start*/

         IF UPDATE(Sku)
           BEGIN
         
                IF EXISTS (SELECT 1 FROM Pickdetail WITH (NOLOCK)
                            WHERE taskdetailkey = @c_Taskdetailkey)
                 BEGIN
                    SELECT @n_continue = 3          
                    SELECT @n_err = 67843 --81301          
                    SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TaskDetail Failed.Cannot update sku while pickdetail exists.(ntrTaskDetailUpdate)' 
             
                 END 
                
           END
         /*CS01 End*/           
        
         -- (Vicky02) - Start        
         SELECT @c_LocationCategy = LocationCategory         
         FROM   LOC l WITH (NOLOCK)        
         WHERE  l.Loc = @c_toloc        
         -- (Vicky02) - End        
        
        
         SELECT @c_deletedtasktype = tasktype ,        
         @c_deletedstorerkey = storerkey,        
         @c_deletedsku = sku,        
         @c_deletedfromloc = fromloc ,        
         @c_deletedfromid = fromid ,        
         @c_deletedtoloc = toloc ,        
         @c_deletedtoid = toid,        
         @c_deletedlot = lot ,        
         @n_deletedqty = qty,        
         @c_deletedcaseid = caseid,        
         @c_deletedsourcekey = sourcekey,        
         @c_deletedStatus = Status,        
         @c_deletedreasonkey = reasonkey,        
         @c_deleteduserposition = userposition,        
         @c_deleteduserkey = userkey,        
         @n_deletedQtyReplen = QtyReplen, --NJOW03
         @n_deletedPendingMoveIn = PendingMoveIn  --NJOW03
         FROM DELETED        
         WHERE taskdetailkey = @c_Taskdetailkey        
                 
         -- Prompt Error when same user getting same task (start)-- (ChewKP01)        
         IF @n_continue=1 or @n_continue=2        
         BEGIN        
            IF (@c_deletedStatus = '3' AND @c_Status = '3')         
            BEGIN        
               IF ( @c_deleteduserkey <> @c_userkey )         
               BEGIN        
                  SELECT @n_continue = 3        
                  SELECT @n_err = 67838 --81301        
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Task Taken - Update Failed. (ntrTaskDetailUpdate)'        
               END        
           END            
         END        
         -- Prompt Error when same user getting same task (end) -- (ChewKP01)        
  
         -- Update userkey & reasonkey = '' if reset status back to 0 (james03)       
         IF @n_continue=1 or @n_continue=2        
         BEGIN        
            IF (@c_deletedStatus <> '9' AND @c_Status = '0')         
            BEGIN        
               UPDATE TASKDETAIL WITH (ROWLOCK) SET        
                  UserKey = '',        
                  ReasonKey = '',   
                  TRAFFICCOP = NULL        
               WHERE TASKDETAIL.taskdetailkey = @c_taskdetailkey        
  
               IF @@ERROR <> 0  
               BEGIN        
                  SELECT @n_continue = 3         
                  SELECT @n_err = 67842         
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TaskDetail Failed. (ntrTaskDetailUpdate)'        
               END        
           END            
         END        
             
         -- Offset LotxLocxID.QtyReplen (start)-- (ChewKP05)         
         IF @n_continue = 1 or @n_continue = 2        
         BEGIN        
            IF @c_Status = 'X' AND @c_deletedStatus NOT IN ('9','X')  AND @c_tasktype IN ('DPK', 'DRP')        
            BEGIN        
               IF ISNULL(@c_Lot,'')  = ''        
               BEGIN        
                   SET @n_ddQty = 0          
                   SET @n_ddQty = @n_qty        
                   SET @n_nQtyReplen = 0        
                           
                   DECLARE curQtyReplen CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
                   SELECT  Lot , QtyReplen FROM LotxLocxID (NOLOCK)        
                   WHERE  Loc = @c_fromloc        
                           AND ID = @c_fromid        
                           AND SKU = @c_sku        
                           AND Storerkey = @c_storerkey        
                           AND QtyReplen>0        
                  ORDER By Lot        
                        
                  OPEN curQtyReplen        
                  FETCH NEXT FROM curQtyReplen INTO @c_ReplenLot , @n_QtyReplen        
                  WHILE @@FETCH_Status <> -1        
                  BEGIN          
                     IF  @n_QtyReplen - @n_ddQty  > 0         
                     BEGIN        
                        SET @n_nQtyReplen = @n_QtyReplen - @n_ddQty        
                     END        
                     ELSE        
                     BEGIN        
                        SET @n_nQtyReplen = 0        
                     END        
                
                     UPDATE LotxLocxID  with (RowLOCK)      
                     SET    QtyReplen = @n_nQtyReplen,  
                            EditDate = GETDATE(),   --tlting  
                            EditWho = SUSER_SNAME()        
                     WHERE  Loc = @c_fromloc        
                            AND ID = @c_fromid        
                            AND SKU = @c_sku    
                            AND Storerkey = @c_storerkey        
                            AND Lot = @c_ReplenLot        
                          
                     SELECT @n_err = @@ERROR --, @n_cnt = @@ROWCOUNT        
                     IF @n_err<>0        
                     BEGIN        
                         SELECT @n_continue = 3        
                         SELECT @n_err = 67839--81305   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+        
                                ': Update Failed On Table LotxLocxID. (ntrTaskDetailUpdate)'         
                               +' ( '+' SQLSvr MESSAGE='+ISNULL(RTRIM(@c_errmsg) ,'')         
                               +' ) '        
                     END        
                             
                     SET @n_ddQty = @n_qty - @n_QtyReplen        
                     IF @n_ddQty <= 0 BREAK        
         
                     FETCH NEXT FROM curQtyReplen INTO @c_ReplenLot , @n_QtyReplen        
                             
                  END        
                  CLOSE curQtyReplen        
                  DEALLOCATE curQtyReplen          
               END        
               ELSE        
               BEGIN        
                  UPDATE LotxLocxID with (ROWLOCK)         
                     SET QtyReplen = QtyReplen - @n_qty,  
                         EditDate = GETDATE(),   --tlting  
                         EditWho = SUSER_SNAME()        
                  WHERE Loc      = @c_fromloc         
                  AND ID         = @c_fromid        
                  AND SKU        = @c_sku        
                  AND Storerkey  = @c_storerkey        
                  AND Lot        = @c_lot        
                  AND QtyReplen > 0        
                          
                  SELECT @n_err = @@ERROR --, @n_cnt = @@ROWCOUNT        
                     IF @n_err <> 0        
                     BEGIN        
                        SELECT @n_continue = 3        
                        SELECT @n_err= 67840--81305   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed On Table LotxLocxID. (ntrTaskDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '        
                     END              
               END        
            END        
         END        
         -- Offset LotxLocxID.QtyReplen (end)-- (ChewKP05)         
                 
         --(Wan01) - START  
         IF @n_continue = 1 or @n_continue = 2        
         BEGIN  
            IF @c_sourcetype = 'VAS'  AND 
              (@c_Status <> @c_deletedStatus OR @n_qty <> @n_deletedqty)      --(Wan02) 
            BEGIN  
               EXEC ispVASTaskProcessing  
                     'UPD'  
                  ,  @c_TaskdetailKey  
                  ,  @c_Tasktype   
                  ,  @c_Sourcekey   
                  ,  @c_SourceType   
                  ,  @c_PickDetailKey   
                  ,  @c_RefTaskKey    
                  ,  @c_Storerkey   
                  ,  @c_Sku   
                  ,  @c_Fromloc   
                  ,  @c_Fromid   
                  ,  @c_Toloc   
                  ,  @c_Toid    
                  ,  @c_Lot   
                  ,  @n_Qty   
                  ,  0    
                  ,  @c_UOM   
                  ,  @c_Caseid    
                  ,  @c_Status   
                  ,  @c_Reasonkey    
                  ,  @b_Success        OUTPUT  
                  ,  @n_err            OUTPUT  
                  ,  @c_errmsg         OUTPUT  
        
               IF @b_Success <> 1  
               BEGIN  
                  SET @n_Continue = 3  
               END  
            END  
         END  
         --(Wan01) - END  
  
         IF @n_continue = 1 or @n_continue = 2        
         BEGIN        
            IF @c_tasktype = 'MV'        
            BEGIN        
               SELECT @c_unit = uom from taskdetail with (nolock) where taskdetailkey = @c_taskdetailkey        
               IF UPDATE(ToLoc) or UPDATE(FromLoc)  -- if toloc and fromloc have been updated        
               BEGIN        
                  IF @c_unit = '1'        
                  -- if this is a pallet move, need to update the path in the putawaytask table and the logicalfromloc and logicaltoloc        
                  BEGIN        
                     EXEC nspInsertIntoPutawayTask @c_taskdetailkey, @c_fromloc, @c_toloc, @c_fromid, @c_sku, @c_fromoutloc output, @b_isDiffFloor output        
                     UPDATE TASKDETAIL with (ROWLOCK)        
                     SET  LOGICALFROMLOC = FROMLOC,        
                          EDITDATE = GETDATE(), -- (Vicky03)        
                          EDITWHO = sUSER_sName(), -- (Vicky03)        
                     TRAFFICCOP = NULL        
                     WHERE TASKDETAIL.taskdetailkey = @c_taskdetailkey        
                             
                     UPDATE TASKDETAIL  with (ROWLOCK)       
                     SET  LOGICALTOLOC = ( CASE WHEN @b_isDiffFloor = 1 THEN @c_FromOutLoc        
                     ELSE TOLOC        
                     END ),        
                          EDITDATE = GETDATE(), -- (Vicky03)        
                          EDITWHO = sUSER_sName(), -- (Vicky03)        
                     TRAFFICCOP = NULL        
                     WHERE TASKDETAIL.taskdetailkey = @c_taskdetailkey        
                  END        
                  ELSE        
                  BEGIN        
                     UPDATE TASKDETAIL  with (ROWLOCK)       
                     SET  LOGICALFROMLOC = FROMLOC,        
                          EDITDATE = GETDATE(), -- (Vicky03)        
                          EDITWHO = sUSER_sName(), -- (Vicky03)        
                     TRAFFICCOP = NULL        
                     WHERE TASKDETAIL.taskdetailkey = @c_taskdetailkey        
                             
                     UPDATE TASKDETAIL with (ROWLOCK)        
                     SET  LOGICALTOLOC = TOLOC,        
                          EDITDATE = GETDATE(), -- (Vicky03)        
                          EDITWHO = sUSER_sName(), -- (Vicky03)        
                     TRAFFICCOP = NULL        
                     WHERE TASKDETAIL.taskdetailkey = @c_taskdetailkey        
                  END        
               END -- if toloc and fromloc have been updated        
            END -- if tasktype = 'MV'        
         END -- if @n_continue = '1' or '2'        
                 
                 
         IF @n_continue = 1 or @n_continue = 2        
         BEGIN        
            IF ISNULL(RTRIM(@c_reasonkey), '') <> '' -- (Vicky01)        
            BEGIN        
               SELECT  @c_rc_toloc = TOLOC,        
               @c_rc_validinfromloc = VALIDINFROMLOC,        
               @c_rc_validintoloc = VALIDINTOLOC,        
               @c_rc_locholdkey = LOCHOLDKEY,        
               @c_rc_idholdkey = IDHOLDKEY,        
               @c_rc_removetaskfromuserqueue = REMOVETASKFROMUSERQUEUE,        
               @c_rc_docyclecount = DOCYCLECOUNT,        
               @c_rc_taskStatus = TASKStatus,        
               @c_rc_continueprocessing = CONTINUEPROCESSING        
               FROM TASKMANAGERREASON WITH (NOLOCK)        
               WHERE TASKMANAGERREASONKEY = @c_reasonkey        
                       
               IF @c_userposition = '1'        
               BEGIN        
                  SELECT @c_work_loc = @c_fromloc,        
                         @c_work_id = @c_fromid        
               END        
                       
               IF @c_userposition = '2'        
               BEGIN        
                  SELECT  @c_work_loc = @c_toloc,        
                          @c_work_id = @c_toid        
               END        
                       
               IF @n_continue = 1 or @n_continue = 2        
               BEGIN        
                  IF @c_userposition = '1' and @c_rc_validinfromloc = '0'        
                  BEGIN        
                     SELECT @n_continue = 3         
                     SELECT @n_err = 67819--81303        
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Reason Code is Not Valid In The FROMLOC (ntrTaskDetailUpdate)'        
                  END        
               END        
                       
               IF @n_continue = 1 or @n_continue = 2        
               BEGIN        
                  IF @c_userposition = '1' and @c_rc_validinfromloc = '0'        
                  BEGIN        
                     SELECT @n_continue = 3        
                     SELECT @n_err = 67820--81304        
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Reason Code is Not Valid In The TOLOC (ntrTaskDetailUpdate)'        
                  END        
               END        
                       
               IF @n_continue = 1 or @n_continue = 2        
               BEGIN        
                  IF @c_rc_removetaskfromuserqueue = '1'        
                  BEGIN        
                     SELECT @b_success = 0        
                     EXECUTE nspAddSkipTasks        
                     ''        
                     , @c_deleteduserkey        
                     , @c_taskdetailkey        
                     , @c_tasktype        
                     , @c_caseid        
                     , @c_lot        
                     , @c_fromloc        
                     , @c_fromid        
                     , @c_toloc        
                     , @c_toid        
                     , @b_Success OUTPUT        
                     , @n_err OUTPUT        
                     , @c_errmsg OUTPUT        
                             
                     IF @b_success <> 1        
                     BEGIN        
                        SELECT @n_continue=3        
                     END        
                  END        
               END        
                       
               IF @n_continue = 1 or @n_continue = 2        
               BEGIN        
                  IF ISNULL(RTRIM(@c_rc_locholdkey), '') <> '' -- (Vicky01)        
                  BEGIN        
                     IF ISNULL(RTRIM(@c_work_loc), '') <> '' -- (Vicky01)        
                     BEGIN        
                        SELECT @b_success = 0        
                        EXECUTE nspInventoryHold        
                        ''        
                        , @c_work_loc        
                        , ''        
                        , @c_rc_locholdkey        
                        , '1'        
                        , @b_Success OUTPUT        
                        , @n_err OUTPUT        
                        , @c_errmsg OUTPUT        
                                
                        IF @b_success <> 1        
                        BEGIN        
                           SELECT @n_continue=3        
                        END        
                     END --IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_work_loc)) IS NOT NULL        
                  END --IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_rc_locholdkey)) IS NOT NULL        
               END --IF @n_continue = 1 or @n_continue = 2        
                       
               IF @n_continue = 1 or @n_continue = 2        
               BEGIN        
                  IF ISNULL(RTRIM(@c_rc_idholdkey), '') <> '' -- (Vicky01)        
                  BEGIN        
                     IF ISNULL(RTRIM(@c_work_id), '') <> '' -- (Vicky01)        
                     BEGIN        
                        SELECT @b_success = 0        
                        EXECUTE nspInventoryHold        
                        ''        
                        , ''        
                        , @c_work_id        
                        , @c_rc_idholdkey        
                        , '1'        
                        , @b_Success OUTPUT        
                        , @n_err OUTPUT        
                        , @c_errmsg OUTPUT        
                                
                        IF @b_success <> 1        
                        BEGIN        
                           SELECT @n_continue=3        
                        END        
                     END -- IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_work_id)) IS NOT NULL        
                  END -- IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_rc_idholdkey)) IS NOT NULL        
               END -- IF @n_continue = 1 or @n_continue = 2        
                       
               IF @n_continue = 1 or @n_continue = 2        
               BEGIN        
                  IF (@c_rc_taskStatus <> @c_Status) AND ISNULL(RTRIM(@c_rc_taskStatus), '') <> '' And @c_Status <> 'X'  -- (Vicky01) -- (ChewKP05)        
                  BEGIN        
                     UPDATE TASKDETAIL with (ROWLOCK)  
                     SET Status = @c_rc_taskStatus,        
                          EDITDATE = GETDATE(), -- (Vicky03)        
                          EDITWHO = sUSER_sName() -- (Vicky03)        
                     WHERE TASKDETAILKEY = @c_taskdetailkey        
                             
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT        
                     IF @n_err <> 0        
                     BEGIN      
                        SELECT @n_continue = 3        
                        SELECT @n_err= 67821--81305   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed On Table Task Detail. (ntrTaskDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '        
                     END        
                  END        
               END        
                       
               IF @n_continue = 1 or @n_continue = 2        
               BEGIN        
                  IF @c_rc_docyclecount = '1'        
                  BEGIN        
                     IF ISNULL(RTRIM(@c_work_loc), '') <> '' -- (Vicky01)        
                     BEGIN        
--                        IF NOT EXISTS(SELECT TASKDETAILKEY         
--                                       FROM TASKDETAIL (NOLOCK)        
--                                       WHERE Tasktype = 'CC'        
--                                        AND FROMLOC = @c_work_loc        
--                                        AND Status = '0' )         
--                                        AND NOT EXISTS(SELECT TASKDETAILKEY         
--                                     FROM TASKDETAIL (NOLOCK) WHERE Tasktype = 'CC'        
--                                                               AND FROMLOC = @c_work_loc        
--                                                               AND Status = '3' )        
                        IF NOT EXISTS(SELECT 1 FROM TASKDETAIL WITH (NOLOCK)        
                                      WHERE Tasktype = 'CC' AND FROMLOC = @c_work_loc AND Status = '0' ) AND        
                           NOT EXISTS(SELECT 1 FROM TASKDETAIL WITH (NOLOCK) WHERE Tasktype = 'CC'        
                                       AND FROMLOC = @c_work_loc AND Status = '3' )        
                        BEGIN        
                           SELECT @b_success = 1        
                           EXECUTE nspg_getkey        
                           'TaskDetailKey'        
                           , 10        
                           , @c_newtaskdetailkey OUTPUT        
                           , @b_success OUTPUT        
                           , @n_err OUTPUT        
                           , @c_errmsg OUTPUT        
                                   
                           IF NOT @b_success = 1        
                           BEGIN        
                              SELECT @n_continue = 3        
                           END        
                            
                           IF @n_continue = 1 or @n_continue = 2        
                           BEGIN        
                              INSERT TASKDETAIL (        
                               TaskDetailKey        
                              ,TaskType        
                              ,FromLoc        
                              ,SourceType        
                              ,SourceKey        
                              ,WaveKey )        
                              VALUES(        
                              @c_newtaskdetailkey        
                              ,'CC'        
                              ,@c_work_loc   -- Changed by JN.Was previously @c_fromloc        
                              ,'TASKDETAIL'        
                              ,@c_taskdetailkey        
                              ,@c_wavekey)        
                                      
                              SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT        
                              IF @n_err <> 0        
                              BEGIN        
                                 SELECT @n_continue = 3        
                                 SELECT @n_err= 67822--81306   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                                 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Failed Into Table Task Detail. (ntrTaskDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
                              END        
                           END        
                        END -- IF NOT EXISTS(SELECT * FROM TASKDETAIL WHERE        
                     END -- IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_work_loc)) IS NOT NULL        
                  END -- IF @c_rc_docyclecount = '1'        
               END -- IF @n_continue = 1 or @n_continue = 2        
                       
                       
               IF @n_continue = 1 or @n_continue = 2        
               BEGIN        
                  IF @c_rc_removetaskfromuserqueue = '1'        
                  BEGIN        
                     SELECT @n_continue = @n_continue        
                  END        
               END        
                       
               IF @n_continue = 1 or @n_continue = 2        
               BEGIN        
                  IF @c_rc_continueprocessing = '0'        
                  BEGIN        
                     CONTINUE        
                  END        
               END        
            END -- IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_reasonkey)) IS NOT NULL        
         END -- IF @n_continue = 1 or @n_continue = 2        
                 
         IF @n_continue = 1 or @n_continue = 2        
         BEGIN        
            IF (@c_tasktype = 'PK') OR         
               (@c_tasktype='PK' AND @c_LocationCategy IN ('PnD_Ctr','PnD_Out')) -- (Vicky02)        
            BEGIN        
               IF @n_continue = 1 or @n_continue = 2        
               BEGIN        
               IF @c_Status <> @c_deletedStatus AND @c_Status = '3'        
                BEGIN        
                     -- Commented by Ricky on 29th October.  This is to be validated against @c_sourcetype        
                     --   IF @c_sourcekey <> 'BATCHPICK'        
                     IF @c_sourcetype = 'PICKDETAIL'        
                     BEGIN        
                        SELECT @c_pickdetailkey = SUBSTRING(@c_sourcekey,1,10)        
                        UPDATE  PICKDETAIL with (ROWLOCK)        
                        SET  Status = '3',  
                              EditDate = GETDATE(),   --tlting  
                              EditWho = SUSER_SNAME()        
                        WHERE  PICKDETAILKEY = @c_pickdetailkey        
                        AND Status IN ('0', '1', '2')        
                                
                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT        
                        IF @n_err <> 0                                BEGIN        
                           SELECT @n_continue = 3        
                           SELECT @n_err= 67823 --81307   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed To Table PickDetail. (ntrTaskDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
                        END        
                        CONTINUE -- Done so loop around!        
                     END -- sourcekey        
                          
                     IF @c_sourcetype = 'BATCHPICK'        
                     BEGIN        
                        UPDATE PICKDETAIL with (ROWLOCK)        
                        SET Status = '3',  
                           EditDate = GETDATE(),   --tlting  
                           EditWho = SUSER_SNAME()        
                        WHERE PICKSLIPNO = @c_taskdetailkey        
                        AND Status IN ('0', '1', '2')        
                                
                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT        
                        IF @n_err <> 0        
                        BEGIN        
                           SELECT @n_continue = 3        
                           SELECT @n_err= 67824--81307   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed To Table PickDetail. (ntrTaskDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
                        END        
                        CONTINUE -- Done so loop around!        
                     END -- sourcetype = 'batchpick'        
                  END        
               END        
                       
               IF @n_continue = 1 or @n_continue = 2        
                BEGIN        
                  IF @c_Status <> @c_DeletedStatus AND @c_Status = '9'        
                  BEGIN        
                     -- If task exists in putawaytask, change the Status to in progress (Status=3).        
                     -- Commented by Ricky on 29th October.  This is to be validated against @c_sourcetype        
                     -- IF @c_sourcekey <> 'BATCHPICK'        
                     DECLARE @c_PickDetailStatus NVARCHAR(1)        
                     IF EXISTS ( SELECT 1 FROM PUTAWAYTASK WITH (NOLOCK)        
                                 WHERE PUTAWAYTASK.Taskdetailkey = @c_taskdetailkey        
                                 AND   PUTAWAYTASK.Status = '0' )        
                     BEGIN        
                        SELECT @c_PickDetailStatus = '3' --In Progress...        
                     END        
                     ELSE        
                     BEGIN        
                        SELECT @c_PickDetailStatus = '5' --Picked...        
                     END        
                             
                     IF @c_sourceType = 'PICKDETAIL'        
                     BEGIN        
                        SELECT @c_pickdetailkey = SUBSTRING(@c_sourcekey,1,10)        
                                
                        UPDATE  PICKDETAIL with (ROWLOCK)        
                        SET Status = @c_PickDetailStatus ,        
                            LOC    = @c_fromloc,        
                            ID     = @c_fromid,        
                            TOLOC  = @c_toloc,        
                            DROPID = @c_toid,        
                            QTY    = @n_qty,  
                            EditDate = GETDATE(),   --tlting  
                            EditWho = SUSER_SNAME()        
                        WHERE PICKDETAILKEY = @c_pickdetailkey        
                        -- Added By SHONG SOS# 9136        
                        -- Error when Pickdetail was shipped        
                        AND   Status <> '9'        
                    
                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT        
                        IF @n_err <> 0        
                        BEGIN        
                           SELECT @n_continue = 3        
                           SELECT @n_err= 67825--81308   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed To Table PickDetail. (ntrTaskDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
                        END        
                                
                        IF @n_continue = 1 or @n_continue = 2        
                        BEGIN        
                           IF ISNULL(RTRIM(@c_toid), '') <> '' -- (Vicky01)        
                           BEGIN        
                              IF SUBSTRING(@c_toid,1,10) <> @c_caseid -- A DropID Cannot be a caseid!        
                              BEGIN        
                                 --SELECT 'BEFORE nspCheckDropID'        
                                 EXECUTE nspCheckDropID        
                                 @c_dropid       = @c_toid        
                                 ,@c_childid      = @c_caseid        
                                 ,@c_droploc      = @c_toloc        
                                 ,@b_Success      = @b_success OUTPUT        
                                 ,@n_err          = @n_err OUTPUT        
                                 ,@c_errmsg       = @c_errmsg OUTPUT        
                                 --SELECT 'AFTER nspCheckDropID: @b_success = ' + str(@b_success)        
                                 IF @b_success = 0        
                                 BEGIN        
                                    SELECT @n_continue = 3        
                                 END        
                              END        
                           END        
                        END        
                        CONTINUE -- Done so loop around!        
                     END -- sourcetype =Pickdetail       
                             
                     IF @c_sourcetype = 'BATCHPICK'        
                     BEGIN        
                        UPDATE  PICKDETAIL with (ROWLOCK)        
                        SET  Status = @c_PickDetailStatus ,        
                             LOC    = @c_fromloc,        
                             ID     = @c_fromid,        
                             TOLOC  = @c_toloc,        
                             DROPID = @c_toid,        
                             QTY    = @n_qty,  
                             EditDate = GETDATE(),   --tlting  
                             EditWho = SUSER_SNAME()        
                        WHERE PICKDETAILKEY = @c_pickdetailkey        
                        -- Added By SHONG SOS# 9136        
                        -- Error when Pickdetail was shipped        
                        AND   Status <> '9'        
        
                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT        
                        IF @n_err <> 0        
                        BEGIN        
                           SELECT @n_continue = 3        
                           SELECT @n_err= 67826--81308   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed To Table PickDetail. (ntrTaskDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
                        END        
                                
                        IF @n_continue = 1 or @n_continue = 2        
                                
                        BEGIN        
                           IF ISNULL(RTRIM(@c_toid), '') <> '' -- (Vicky01)        
                           BEGIN        
                              IF SUBSTRING(@c_toid,1,10) <> @c_caseid -- A DropID Cannot be a caseid!        
                              BEGIN        
                                 --SELECT 'BEFORE nspCheckDropID'        
                                 EXECUTE nspCheckDropID        
                                  @c_dropid       = @c_toid        
                                 ,@c_childid      = @c_caseid        
                                 ,@c_droploc      = @c_toloc        
                                 ,@b_Success      = @b_success OUTPUT        
                                 ,@n_err         = @n_err OUTPUT        
                                 ,@c_errmsg   = @c_errmsg OUTPUT        
                                 --SELECT 'AFTER nspCheckDropID: @b_success = ' + str(@b_success)        
                                 IF @b_success = 0        
                                 BEGIN        
                                    SELECT @n_continue = 3        
                                 END        
                              END        
                           END        
                        END        
                        CONTINUE -- Done so loop around!        
                                
                     END        
                  END -- IF @c_Status <> @c_deletedStatus AND @c_Status = '9'        
               END -- IF @n_continue = 1 or @n_continue = 2        
                       
            END -- IF (@c_tasktype = 'PK')        
         END -- IF @n_continue = 1 or @n_continue = 2        
                 
         IF @n_continue = 1 or @n_continue = 2        
         BEGIN        
            IF @c_tasktype = 'PA'        
            BEGIN        
               IF @n_continue = 1 or @n_continue = 2        
               BEGIN        
                  IF ISNULL(RTRIM(@c_fromid), '') = '' -- (Vicky01)        
                  BEGIN        
                     IF ISNULL(RTRIM(@c_sku), '') = '' or ISNULL(RTRIM(@c_storerkey), '') = '' -- (Vicky01)        
                     OR ISNULL(RTRIM(@c_lot), '') = '' OR ISNULL(RTRIM(@c_fromloc), '') = '' -- (Vicky01)        
                     or @n_qty = 0        
                     BEGIN        
                        SELECT @n_continue = 3         
                        SELECT @n_err = 67827 --81309        
                        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': FromID is blank therefore LOT/FROMLOC/ID/QTY/STORERKEY/SKU must be filled in. (ntrTaskDetailUpdate)'        
                     END        
                 END        
               END        
               IF @n_continue = 1 or @n_continue = 2        
               BEGIN        
                  IF ISNULL(RTRIM(@c_fromid), '') <> '' -- (Vicky01)        
                  BEGIN        
                     IF ISNULL(RTRIM(@c_lot), '') <> '' -- (Vicky01)        
                     BEGIN        
                        SELECT @n_continue = 3         
                        SELECT @n_err = 67828--81310        
                        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': FromID has been filled in therefore LOT should be blank. (ntrTaskDetailUpdate)'        
                     END        
                  END        
               END        
               IF @n_continue = 1 or @n_continue = 2        
               BEGIN        
                  IF ISNULL(RTRIM(@c_fromloc), '') = '' -- (Vicky01)        
                  BEGIN        
                     SELECT @n_continue = 3         
                     SELECT @n_err = 67829 --81311        
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': FromLOC should be filled in. (ntrTaskDetailUpdate)'        
                  END        
               END        
            END        
         END        
                 
         IF @n_continue = 1 or @n_continue = 2        
         BEGIN        
            IF @c_tasktype = 'PA'        
            BEGIN        
               IF @n_continue = 1 or @n_continue = 2        
               BEGIN        
                  IF ISNULL(RTRIM(@c_deletedtoid), '') <> '' and ISNULL(RTRIM(@c_deletedtoloc), '') <> '' -- (Vicky01)        
                  BEGIN        
                     IF @n_continue = 1 or @n_continue = 2        
                     BEGIN        
                        INSERT LOTxLOCxID (Lot,Loc,ID,Storerkey,Sku)        
                        SELECT L1.Lot,@c_deletedtoloc,@c_deletedtoid,L1.Storerkey,L1.Sku        
                        FROM LOTxLOCxID L1 WITH (NOLOCK)        
                        WHERE L1.Id  = @c_deletedfromid        
                        AND   L1.Loc = @c_deletedfromloc        
                        AND   NOT EXISTS        
                        (SELECT 1 FROM LOTxLOCxID L3 WITH (NOLOCK)     -- tlting01    
                        WHERE L3.Lot = L1.Lot        
                        AND   L3.Loc = @c_deletedtoloc        
                        AND   L3.ID  = @c_deletedtoid        
                        )        
                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT        
                        IF @n_err <> 0        
                        BEGIN        
                           SELECT @n_continue = 3        
                           SELECT @n_err= 67830--81312   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed To LOTxLOCxID. (ntrTaskDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '        
                        END        
                     END        
                     IF @n_continue = 1 or @n_continue = 2        
                     BEGIN        
                        SELECT @b_success = 1        
                        execute nspPendingMoveInUpdate        
                                       @c_storerkey    = ''        
                        ,              @c_sku          = ''        
                        ,              @c_lot          = ''        
                        ,              @c_Loc          = @c_deletedtoloc        
                        ,              @c_ID           = @c_deletedtoid        
                        ,              @c_fromloc      = @c_deletedfromloc        
                        ,              @c_fromid       = @c_deletedfromid        
                        ,              @n_qty          = @n_deletedqty        
                        ,              @c_action       = 'R'        
                        ,              @b_Success      = @b_success OUTPUT        
                        ,              @n_err          = @n_err OUTPUT        
                        ,              @c_errmsg       = @c_errmsg OUTPUT        
                        ,              @c_tasktype     = @c_tasktype -- (Vicky02)        
                        IF @b_success = 0        
                        BEGIN        
                           SELECT @n_continue = 3        
                        END        
                     END        
                  END        
               END        
               IF @n_continue = 1 or @n_continue = 2        
               BEGIN        
                  IF ISNULL(RTRIM(@c_deletedtoid), '') = '' and ISNULL(RTRIM(@c_deletedtoloc), '') <> '' -- (Vicky01)        
                  BEGIN        
                       -- Commended by (Vicky05) - Start        
--                     IF @n_continue = 1 or @n_continue = 2        
--                     BEGIN        
                           -- (ChewKP03) (Start) --        
--                           INSERT LOTxLOCxID        
--                              (        
--                                Lot        
--                               ,Loc        
--                               ,ID        
--                               ,Storerkey        
--                               ,Sku        
--                              )        
--                            SELECT L1.Lot        
--                                  ,@c_toloc        
--                           ,@c_toid        
--                                  ,L1.Storerkey        
--                                  ,L1.Sku        
--                            FROM   LOTxLOCxID L1 WITH (NOLOCK)        
--                            WHERE  L1.Lot = @c_lot AND        
--                                   L1.Loc = @c_fromloc AND        
--                                   NOT EXISTS         
--                                   (        
--                                       SELECT 1        
--                                       FROM   LOTxLOCxID L3        
--                                       WHERE  L3.Lot = L1.Lot AND        
--                                              L3.Loc = @c_toloc AND        
--              L3.ID = @c_toid        
--                                   )        
--                                    
--                            SELECT @n_err = @@ERROR        
--                                  ,@n_cnt = @@ROWCOUNT        
--                                    
--                            IF @n_err<>0        
--                            BEGIN        
--                                SELECT @n_continue = 3          
--                                SELECT @n_err = 67996 --81904   -- Should Be Set To The SQL Errmessage but I don't know how to do so.          
--                                SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)        
--                                      +        
--                                       ': Update Failed To LOTxLOCxID. (ntrTaskDetailAdd)'         
--                                      +' ( '+' SQLSvr MESSAGE='+dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))         
--                                      +' ) '        
--                            END        
                           -- (ChewKP03) (End) --        
--                     END        
                       -- Commended by (Vicky05) - End        
                     IF @n_continue = 1 or @n_continue = 2        
                     BEGIN        
                        SELECT @b_success = 1        
                        execute nspPendingMoveInUpdate        
                        @c_storerkey    = @c_deletedstorerkey        
                        ,              @c_sku          = @c_deletedsku        
                        ,              @c_lot          = @c_deletedlot        
                        ,              @c_Loc          = @c_deletedtoloc        
                        ,              @c_ID           = ''        
                        ,              @c_fromloc      = @c_deletedfromloc        
                        ,              @c_fromid       = @c_deletedfromid        
                        ,              @n_qty          = @n_deletedqty        
                        ,              @c_action       = 'R'        
                        ,              @b_Success      = @b_success OUTPUT        
                        ,              @n_err          = @n_err OUTPUT        
                        ,              @c_errmsg       = @c_errmsg OUTPUT        
                        ,              @c_tasktype     = @c_tasktype -- (Vicky02)        
                        IF @b_success = 0        
                        BEGIN        
                           SELECT @n_continue = 3        
                        END        
                     END        
                  END        
               END        
               IF @n_continue = 1 or @n_continue = 2        
               BEGIN        
                  IF ISNULL(RTRIM(@c_toid), '') <> '' and ISNULL(RTRIM(@c_toloc), '') <> '' -- (Vicky01)        
                  BEGIN        
                     IF @n_continue = 1 or @n_continue = 2        
                     BEGIN        
                        INSERT LOTxLOCxID (Lot,Loc,ID,Storerkey,Sku)        
                        SELECT L1.Lot,@c_toloc,@c_toid,L1.Storerkey,L1.Sku        
                        FROM LOTxLOCxID L1 WITH (NOLOCK)        
                        WHERE L1.Id  = @c_fromid        
                        AND   L1.Loc = @c_fromloc        
                        AND   NOT EXISTS        
                        (SELECT 1 FROM LOTxLOCxID L3 WITH (NOLOCK)  -- tlting01      
                        WHERE L3.Lot = L1.Lot        
                        AND   L3.Loc = @c_toloc        
                        AND   L3.ID  = @c_toid        
                        )        
                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT        
                        IF @n_err <> 0        
                        BEGIN        
                           SELECT @n_continue = 3        
                           SELECT @n_err= 67831 --81313   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed To LOTxLOCxID. (ntrTaskDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '        
                        END        
                    END        
                     IF @n_continue = 1 or @n_continue = 2        
                     BEGIN        
                        SELECT @b_success = 1        
                        execute nspPendingMoveInUpdate        
                        @c_storerkey    = ''        
                        ,              @c_sku          = ''        
                        ,              @c_lot          = ''        
                        ,              @c_Loc          = @c_toloc        
                        ,              @c_ID           = @c_toid        
                        ,              @c_fromloc      = @c_fromloc        
                        ,              @c_fromid       = @c_fromid        
                        ,              @n_qty          = @n_qty        
                        ,              @c_action       = 'I'        
                        ,              @b_Success      = @b_success OUTPUT        
                        ,              @n_err          = @n_err OUTPUT        
                        ,              @c_errmsg       = @c_errmsg OUTPUT        
                        ,              @c_tasktype     = @c_tasktype -- (Vicky02)        
                        IF @b_success = 0        
                        BEGIN        
                           SELECT @n_continue = 3        
                        END        
                     END        
                  END        
               END        
               IF @n_continue = 1 or @n_continue = 2        
               BEGIN        
                  IF ISNULL(RTRIM(@c_toid), '') = '' and ISNULL(RTRIM(@c_toloc), '') <> '' -- (Vicky01)        
                  BEGIN        
                     IF @n_continue = 1 or @n_continue = 2        
                     BEGIN        
                        SELECT @b_success = 1        
                        execute nspPendingMoveInUpdate        
                        @c_storerkey    = @c_storerkey        
                        ,              @c_sku          = @c_sku        
                        ,              @c_lot          = @c_lot        
                        ,              @c_Loc          = @c_toloc        
                        ,              @c_ID           = ''        
                        ,              @c_fromloc     = @c_fromloc        
                        ,              @c_fromid       = @c_fromid        
                        ,              @n_qty          = @n_qty        
                        ,              @c_action       = 'I'        
                        ,              @b_Success      = @b_success OUTPUT        
                        ,              @n_err          = @n_err OUTPUT        
                        ,              @c_errmsg       = @c_errmsg OUTPUT        
                        ,              @c_tasktype     = @c_tasktype -- (Vicky02)        
                        IF @b_success = 0        
                        BEGIN        
                           SELECT @n_continue = 3        
                        END        
                     END        
                  END        
               END        
            END        
         END        
                 
         IF @n_continue = 1 or @n_continue = 2        
         BEGIN        
            IF @c_tasktype = 'MV' or @c_tasktype = 'PA'        
            BEGIN        
               IF @n_continue = 1 or @n_continue = 2        
               BEGIN        
                  IF @c_Status = '9'        
                  BEGIN        
                     IF @n_continue = 1 or @n_continue = 2        
                     BEGIN        
                        IF ISNULL(RTRIM(@c_toloc), '') = '' -- (Vicky01)        
                        BEGIN        
                           SELECT @n_continue = 3         
                           SELECT @n_err = 67832--81314        
                           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': TOLOC should be filled in. (ntrTaskDetailUpdate)'        
                        END        
                     END        
                     IF @n_continue = 1 or @n_continue = 2        
                     BEGIN        
                        IF ISNULL(RTRIM(@c_fromid), '') <> '' -- (Vicky01)        
                        BEGIN        
                           IF @n_deletedqty = 0 -- The whole pallet was scheduled to be moved        
                           BEGIN        
                              IF @n_qty > 0 -- A partial pallet was moved        
                              BEGIN        
                                 SELECT @n_checkcount = COUNT(*) FROM LOTxLOCxID WITH (NOLOCK)        
                                 WHERE ID = @c_fromid and LOC = @c_fromloc and QTY > 0        
                                 IF @n_checkcount > 1        
                                 BEGIN        
                                    SELECT @n_continue = 3         
                                    SELECT @n_err = 67833--81315        
                                    SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': You cannot Specify A QTY To Move When Moving A Multi-Lot Pallet (ntrTaskDetailUpdate)'        
                                 END        
                                 IF @n_continue = 1 or @n_continue = 2        
                                 BEGIN        
                                    SELECT @n_scratch_qtytobemoved = QTY        
                                    FROM LOTxLOCxID WITH (NOLOCK)        
                                    WHERE ID = @c_fromid and LOC = @c_fromloc and QTY > 0        
                                    IF @n_qty > @n_scratch_qtytobemoved        
                                    BEGIN        
                                       SELECT @n_continue = 3        
                                       SELECT @n_err = 67834 --81319        
                                       SELECT @c_errmsg = 'NSQL' + Convert(NVARCHAR(5),@n_err) + ': Qty Specified Exceeds Qty On Pallet (ntrTaskDetailUpdate)'        
                                    END        
                                    ELSE IF @n_qty < @n_scratch_qtytobemoved        
                                    BEGIN        
                                       SELECT @n_qtynotmoved = @n_scratch_qtytobemoved - @n_qty        
                                    END        
                                 END        
                              END        
                              ELSE        
                              BEGIN        
                                 SELECT @n_qtynotmoved = 0        
                              END        
                           END        
                           ELSE        
                           BEGIN        
                           IF ISNULL(RTRIM(@c_lot), '') = '' -- (Vicky01)        
                              OR ISNULL(RTRIM(@c_fromloc), '') = '' -- (Vicky01)        
                              BEGIN        
                                 SELECT @n_continue = 3         
                                 SELECT @n_err = 67835--81316        
                             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': A specific QTY on and ID was specified to be moved but LOT or LOC was not Specified. (ntrTaskDetailUpdate)'        
                              END        
                              IF @n_continue = 1 or @n_continue = 2        
                              BEGIN        
                                 SELECT @n_qtynotmoved = @n_deletedqty - @n_qty        
                              END        
                           END        
                        END        
                        ELSE        
                        BEGIN        
                           IF ISNULL(RTRIM(@c_lot), '') = '' -- (Vicky01)        
                           OR ISNULL(RTRIM(@c_fromloc), '') = ''  -- (Vicky01)        
                           OR @n_qty <= 0        
                           OR @n_deletedqty <=0        
                           BEGIN        
                              SELECT @n_continue = 3         
                              SELECT @n_err = 67836--81317        
                              SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': A specific QTY on and ID was specified to be moved but LOT or LOC was not Specified. (ntrTaskDetailUpdate)'        
                           END        
                           IF @n_continue = 1 or @n_continue = 2        
                           BEGIN        
                              SELECT @n_qtynotmoved = @n_deletedqty - @n_qty        
                           END        
                        END        
                     END        
                             
                     -- fbr028c : for pallet move, toloc = logicaltoloc        
                             
                     SELECT @c_logicaltoloc = logicaltoloc        
                     FROM INSERTED        
                     WHERE taskdetailkey = @c_Taskdetailkey        
        
                     -- (james01) start        
                     IF EXISTS (SELECT 1 FROM STORERCONFIG WITH (NOLOCK)     
                                WHERE Configkey = 'PrepackByBOM'     
                                AND Storerkey = @c_storerkey AND sValue = '1')        
                     BEGIN        
                        IF @c_fromid <> ''        
                        BEGIN        
                           DECLARE CUR_LOT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR         
                           SELECT LOT, SKU        
                           FROM LOTxLOCxID WITH (NOLOCK)        
                           WHERE LOC = @c_fromloc        
                           AND   Storerkey = @c_storerkey        
                           AND   ID = @c_fromid        
                           AND   QTY > 0        
           
                           OPEN CUR_LOT        
                           FETCH NEXT FROM CUR_LOT INTO @c_lot, @c_sku        
                           WHILE @@FETCH_Status <> -1        
                           BEGIN        
                               EXEC nspGetPack @c_storerkey,        
                               @c_sku,        
                               @c_lot,        
                               @c_fromloc,        
                               @c_fromid,        
                               @c_PackKey OUTPUT,        
                               @b_success OUTPUT,        
                               @n_err OUTPUT,        
                               @c_errmsg OUTPUT        
           
                               IF @b_success = 0        
                               BEGIN        
                                  SELECT @n_continue = 3        
                               END        
           
                              SELECT @c_uom = CASE @c_taskuom        
                                         WHEN '2' THEN PackUOM1 -- Case        
                                         WHEN '3' THEN PackUOM2 -- Inner pack        
                                         WHEN '6' THEN PackUOM3 -- Master unit        
                                         WHEN '1' THEN PackUOM4 -- Pallet        
                                         WHEN '4' THEN PackUOM8 -- Other unit 1        
                                         WHEN '5' THEN PackUOM9 -- Other unit 2        
                              END        
                              FROM PACK WITH (NOLOCK)        
                              WHERE Packkey = @c_PackKey        
           
                              -- (Vicky04) - Start        
                              SELECT @c_lottable01 = Lottable01,        
                                     @c_lottable02 = Lottable02,        
                                     @c_lottable03 = Lottable03,        
                                     @d_lottable04 = Lottable04,        
                                     @d_lottable05 = Lottable05,
												 @c_lottable06 = Lottable06,		--CS01        
                                     @c_lottable07 = Lottable07,     --CS01   
                                     @c_lottable08 = Lottable08,     --CS01
												 @c_lottable09 = Lottable09,     --CS01   
                                     @c_lottable10 = Lottable10,     --CS01   
                                     @c_lottable11 = Lottable11,		--CS01
												 @c_lottable12 = Lottable12,		--CS01
												 @d_lottable13 = Lottable13,     --CS01
                                     @d_lottable14 = Lottable14,     --CS01   
                                     @d_lottable15 = Lottable15      --CS01   
                              FROM LotAttribute WITH (NOLOCK)        
                              WHERE Lot = @c_lot        
                              AND   StorerKey = @c_storerkey        
                              AND   SKU = @c_sku        
                              -- (Vicky04) - End        
           
                              IF @n_continue = 1 or @n_continue = 2        
                              BEGIN        
                                 SELECT @b_success = 0        
                                 EXECUTE nspItrnAddMove        
                                 @n_ItrnSysId    = NULL,        
                                 @c_itrnkey      = NULL,        
                                 @c_StorerKey    = @c_storerkey,        
                                 @c_Sku          = @c_sku,        
                                 @c_Lot          = @c_lot,        
                                 @c_FromLoc      = @c_fromloc,        
                                 @c_FromID    = @c_fromid,        
                                 @c_ToLoc        = @c_toloc, -- (ChewKP02)        
                                 @c_ToID         = @c_toid,        
                                 @c_Status       = '',        
                                 @c_lottable01   = @c_lottable01, -- (Vicky04)        
                                 @c_lottable02   = @c_lottable02, -- (Vicky04)        
                                 @c_lottable03   = @c_lottable03, -- (Vicky04)        
                                 @d_lottable04   = @d_lottable04, -- (Vicky04)        
                                 @d_lottable05   = @d_lottable05, -- (Vicky04)  
											@c_lottable06   = @c_lottable06, -- (CS01)        
                                 @c_lottable07   = @c_lottable07, -- (CS01)        
                                 @c_lottable08   = @c_lottable08, -- (CS01)
											@c_lottable09   = @c_lottable09, -- (CS01)        
                                 @c_lottable10   = @c_lottable10, -- (CS01)        
                                 @c_lottable11   = @c_lottable11, -- (CS01)
											@c_lottable12   = @c_lottable12, -- (CS01)
											@d_lottable13   = @d_lottable13, -- (CS01)        
                                 @d_lottable14   = @d_lottable14, -- (CS01)        
                                 @d_lottable15   = @d_lottable15, -- (CS01)      
                                 @n_casecnt      = 0,        
                                 @n_innerpack    = 0,        
                                 @n_qty          = @n_qty,        
                                 @n_pallet       = 0,        
                                 @f_cube         = 0,        
                                 @f_grosswgt     = 0,        
                                 @f_netwgt       = 0,        
                                 @f_otherunit1   = 0,        
                                 @f_otherunit2   = 0,        
                                 @c_SourceKey    = @c_taskdetailkey,        
                                 @c_SourceType   = 'ntrTaskDetailUpdate',        
                                 @c_PackKey      = @c_packkey,        
                                 @c_UOM          = @c_uom,        
                                 @b_UOMCalc      = 1,        
                                 @d_EffectiveDate = NULL,        
                                 @b_Success      = @b_Success  OUTPUT,        
                                 @n_err          = @n_err      OUTPUT,        
                                 @c_errmsg       = @c_errmsg   OUTPUT        
                                 IF NOT @b_success=1        
                                 BEGIN        
                                    SELECT @n_continue = 3        
                                 END        
                            END        
                              FETCH NEXT FROM CUR_LOT INTO @c_lot, @c_sku        
                           END        
                           CLOSE CUR_LOT        
                           DEALLOCATE CUR_LOT        
                                
                                
                        END -- @c_fromid <> ''        
                        ELSE IF @c_sourcetype IN ('DPK','DRP')    
                        BEGIN        
                           SET @n_QtyToMove = @n_Qty    
                               
                           DECLARE CUR_LOT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR         
                           SELECT LOT, Qty - QtyPicked - QtyAllocated    
                           FROM LOTxLOCxID WITH (NOLOCK)        
                           WHERE LOC = @c_fromloc        
                           AND   Storerkey = @c_storerkey        
                           AND   SKU = @c_SKU         
                           AND   Qty - QtyPicked - QtyAllocated > 0        
           
                           OPEN CUR_LOT        
                           FETCH NEXT FROM CUR_LOT INTO @c_lot, @n_LOTQty        
                           WHILE @@FETCH_Status <> -1        
                           BEGIN        
                              -- (Shong01)    
                              IF ISNULL(RTRIM(@c_lottable03),'') <> ''    
                              BEGIN    
                                 SELECT @c_PackKey = Packkey     
                                 FROM SKU (NOLOCK)        
                                 WHERE SKU = @c_lottable03        
                                 AND Storerkey = @c_storerkey                                      
                              END    
                              ELSE    
                              BEGIN    
                                 SELECT @c_PackKey = Packkey     
                                 FROM SKU (NOLOCK)        
                                 WHERE SKU = @c_sku        
                                 AND Storerkey = @c_storerkey                                                                    
                              END    
                                         
                              SELECT @c_uom = CASE @c_taskuom        
                                         WHEN '2' THEN PackUOM1 -- Case        
                                         WHEN '3' THEN PackUOM2 -- Inner pack        
                                         WHEN '6' THEN PackUOM3 -- Master unit        
                                         WHEN '1' THEN PackUOM4 -- Pallet        
                                         WHEN '4' THEN PackUOM8 -- Other unit 1        
                                         WHEN '5' THEN PackUOM9 -- Other unit 2        
                              END        
                              FROM PACK WITH (NOLOCK)        
                              WHERE Packkey = @c_PackKey        
           
                              -- (Vicky04) - Start        
                              SELECT @c_lottable01 = Lottable01,        
                                     @c_lottable02 = Lottable02,        
                                     @c_lottable03 = Lottable03,        
                                     @d_lottable04 = Lottable04,        
                                     @d_lottable05 = Lottable05,
												 @c_lottable06 = Lottable06,		--CS01        
                                     @c_lottable07 = Lottable07,     --CS01   
                                     @c_lottable08 = Lottable08,     --CS01
												 @c_lottable09 = Lottable09,     --CS01   
                                     @c_lottable10 = Lottable10,     --CS01   
                                     @c_lottable11 = Lottable11,		--CS01
												 @c_lottable12 = Lottable12,		--CS01
												 @d_lottable13 = Lottable13,     --CS01
                                     @d_lottable14 = Lottable14,     --CS01   
                                     @d_lottable15 = Lottable15      --CS01         
                              FROM LotAttribute WITH (NOLOCK)        
                              WHERE Lot = @c_lot        
                              AND   StorerKey = @c_storerkey        
                              AND   SKU = @c_sku        
                              -- (Vicky04) - End        
           
                              IF @n_LOTQty > @n_QtyToMove    
                                 SET @n_LOTQty = @n_QtyToMove     
                                     
                              IF @n_continue = 1 or @n_continue = 2        
                              BEGIN        
                                 SELECT @b_success = 0        
                                 EXECUTE nspItrnAddMove        
                                 @n_ItrnSysId    = NULL,        
                                 @c_itrnkey      = NULL,        
                                 @c_StorerKey    = @c_storerkey,        
                                 @c_Sku          = @c_sku,        
                                 @c_Lot          = @c_lot,        
                                 @c_FromLoc      = @c_fromloc,        
                                 @c_FromID       = @c_fromid,        
                                 @c_ToLoc        = @c_toloc, -- (ChewKP02)        
                                 @c_ToID         = @c_toid,        
                                 @c_Status       = '',        
                                 @c_lottable01   = @c_lottable01, -- (Vicky04)        
                                 @c_lottable02   = @c_lottable02, -- (Vicky04)        
                                 @c_lottable03   = @c_lottable03, -- (Vicky04)        
                                 @d_lottable04   = @d_lottable04, -- (Vicky04)        
                                 @d_lottable05   = @d_lottable05, -- (Vicky04) 
											@c_lottable06   = @c_lottable06, -- (CS01)        
                                 @c_lottable07   = @c_lottable07, -- (CS01)        
                                 @c_lottable08   = @c_lottable08, -- (CS01)
											@c_lottable09   = @c_lottable09, -- (CS01)        
                                 @c_lottable10   = @c_lottable10, -- (CS01)        
                                 @c_lottable11   = @c_lottable11, -- (CS01)
											@c_lottable12   = @c_lottable12, -- (CS01)
											@d_lottable13   = @d_lottable13, -- (CS01)        
                                 @d_lottable14   = @d_lottable14, -- (CS01)        
                                 @d_lottable15   = @d_lottable15, -- (CS01)          
                                 @n_casecnt      = 0,        
                                 @n_innerpack    = 0,        
                                 @n_qty          = @n_LOTQty,        
                                 @n_pallet       = 0,        
                                 @f_cube         = 0,        
                                 @f_grosswgt     = 0,        
                                 @f_netwgt       = 0,        
                                 @f_otherunit1   = 0,        
                                 @f_otherunit2   = 0,        
                                 @c_SourceKey    = @c_taskdetailkey,        
                                 @c_SourceType   = 'ntrTaskDetailUpdate',        
                                 @c_PackKey      = @c_packkey,        
                                 @c_UOM          = @c_uom,        
                                 @b_UOMCalc      = 1,        
                                 @d_EffectiveDate = NULL,        
                                 @b_Success      = @b_Success  OUTPUT,        
                                 @n_err          = @n_err      OUTPUT,        
                                 @c_errmsg       = @c_errmsg   OUTPUT        
                                 IF NOT @b_success=1        
                                 BEGIN        
                                    SELECT @n_continue = 3        
                                 END        
                              END        
                                  
                              SET @n_QtyToMove = @n_QtyToMove - @n_LotQty     
                                  
                              FETCH NEXT FROM CUR_LOT INTO @c_lot, @n_LOTQty         
                           END        
                           CLOSE CUR_LOT        
                           DEALLOCATE CUR_LOT        
                        END -- SourceType in DPK,DRP                                   
                        ELSE                                
                        BEGIN        
                                      
                           -- For Proj Diana -  Only Move Qty in TaskDetail (Start) (ChewKP04) --        
                           SELECT @c_lottable01 = Lottable01,        
                                  @c_lottable02 = Lottable02,        
                                  @c_lottable03 = Lottable03,        
                                  @d_lottable04 = Lottable04,        
                                  @d_lottable05 = Lottable05,
											 @c_lottable06 = Lottable06,		--CS01        
                                  @c_lottable07 = Lottable07,     --CS01   
                                  @c_lottable08 = Lottable08,     --CS01
											 @c_lottable09 = Lottable09,     --CS01   
                                  @c_lottable10 = Lottable10,     --CS01   
                                  @c_lottable11 = Lottable11,		--CS01
										 	 @c_lottable12 = Lottable12,		--CS01
										 	 @d_lottable13 = Lottable13,     --CS01
                                  @d_lottable14 = Lottable14,     --CS01   
                                  @d_lottable15 = Lottable15      --CS01        
                           FROM LotAttribute WITH (NOLOCK)        
                           WHERE Lot = @c_lot        
                           AND   StorerKey = @c_storerkey        
                           AND   SKU = @c_sku        
        
                           -- (Shong01)    
                           IF ISNULL(RTRIM(@c_lottable03),'') <> ''    
                           BEGIN    
                              SELECT @c_PackKey = Packkey     
                              FROM SKU (NOLOCK)        
                              WHERE SKU = @c_lottable03        
                              AND Storerkey = @c_storerkey                                      
                           END    
                           ELSE    
                           BEGIN    
                              SELECT @c_PackKey = Packkey     
                              FROM SKU (NOLOCK)        
                              WHERE SKU = @c_sku        
                              AND Storerkey = @c_storerkey                                                                    
                           END    
                                 
                           SELECT @c_uom = PackUOM3 FROM PACK (NOLOCK)        
                           WHERE PACKKEY = @c_PackKey        
                                 
                   
                           SELECT @b_success = 0        
                           EXECUTE nspItrnAddMove        
                           @n_ItrnSysId    = NULL,        
                           @c_itrnkey      = NULL,        
                           @c_StorerKey    = @c_storerkey,        
                           @c_Sku          = @c_sku,        
                           @c_Lot          = @c_lot,        
                           @c_FromLoc      = @c_fromloc,        
                           @c_FromID       = @c_fromid,        
                           @c_ToLoc     = @c_toloc, -- (ChewKP02)        
                           @c_ToID         = @c_toid,        
                           @c_Status       = '',        
                           @c_lottable01   = @c_lottable01, -- (Vicky04)        
                           @c_lottable02   = @c_lottable02, -- (Vicky04)        
                           @c_lottable03   = @c_lottable03, -- (Vicky04)        
                           @d_lottable04   = @d_lottable04, -- (Vicky04)        
                           @d_lottable05   = @d_lottable05, -- (Vicky04)  
									@c_lottable06   = @c_lottable06, -- (CS01)        
                           @c_lottable07   = @c_lottable07, -- (CS01)        
                           @c_lottable08   = @c_lottable08, -- (CS01)
									@c_lottable09   = @c_lottable09, -- (CS01)        
                           @c_lottable10   = @c_lottable10, -- (CS01)        
                           @c_lottable11   = @c_lottable11, -- (CS01)
									@c_lottable12   = @c_lottable12, -- (CS01)
									@d_lottable13   = @d_lottable13, -- (CS01)        
                           @d_lottable14   = @d_lottable14, -- (CS01)        
                           @d_lottable15   = @d_lottable15, -- (CS01)         
                           @n_casecnt      = 0,        
                           @n_innerpack    = 0,        
                           @n_qty          = @n_qty,        
                           @n_pallet       = 0,        
                           @f_cube         = 0,        
                           @f_grosswgt     = 0,        
                           @f_netwgt       = 0,        
                           @f_otherunit1   = 0,        
                           @f_otherunit2   = 0,        
                           @c_SourceKey    = @c_taskdetailkey,        
                           @c_SourceType   = 'ntrTaskDetailUpdate',        
                           @c_PackKey      = @c_PackKey,--@c_packkey,        
                           @c_UOM          = @c_uom,--@c_uom,        
                           @b_UOMCalc      = 1,        
                           @d_EffectiveDate = NULL,        
                           @b_Success      = @b_Success  OUTPUT,        
                           @n_err          = @n_err      OUTPUT,        
                           @c_errmsg       = @c_errmsg   OUTPUT        
                           IF NOT @b_success=1        
                           BEGIN        
                              SELECT @n_continue = 3        
                           END        
                   
                           -- For Proj Diana -  Only Move Qty in TaskDetail (End) (ChewKP04) --        
                        END -- @c_fromid = ''        
                     END   -- (james01) end        
                     ELSE        
                     BEGIN        
                        -- (Vicky01) - Start - Get UOM        
                        EXEC nspGetPack @c_storerkey,        
                         @c_sku,        
                         @c_lot,        
                         @c_fromloc,        
                         @c_fromid,        
                         @c_PackKey OUTPUT,        
                         @b_success OUTPUT,        
                         @n_err OUTPUT,        
                         @c_errmsg OUTPUT        
        
                         IF @b_success = 0        
                         BEGIN        
                            SELECT @n_continue = 3        
                         END        
        
                         SELECT @c_uom = CASE @c_taskuom        
                                  WHEN '2' THEN PackUOM1 -- Case        
                                  WHEN '3' THEN PackUOM2 -- Inner pack        
                                  WHEN '6' THEN PackUOM3 -- Master unit        
                                  WHEN '1' THEN PackUOM4 -- Pallet        
                                  WHEN '4' THEN PackUOM8 -- Other unit 1        
                                  WHEN '5' THEN PackUOM9 -- Other unit 2        
                               END        
                         FROM PACK WITH (NOLOCK)        
                         WHERE Packkey = @c_PackKey        
                         -- (Vicky01) - End - Get UOM        
        
                         -- (ChewKP06)
                         IF @c_Lot = '' 
                         BEGIN  
                            -- (Vicky04) - Start        
                            SELECT @c_lot = LOT,        
                                   @c_sku = SKU        
                            FROM LOTxLOCxID WITH (NOLOCK)        
                            WHERE LOC = @c_fromloc        
                            AND   Storerkey = @c_storerkey        
                            AND   ID = @c_fromid        
                            AND   QTY > 0        
                         END
                         
                          SELECT @c_lottable01 = Lottable01,        
                                 @c_lottable02 = Lottable02,        
                                 @c_lottable03 = Lottable03,        
                                 @d_lottable04 = Lottable04,        
                                 @d_lottable05 = Lottable05,
										   @c_lottable06 = Lottable06,		--CS01        
                                 @c_lottable07 = Lottable07,     --CS01   
                                 @c_lottable08 = Lottable08,     --CS01
											@c_lottable09 = Lottable09,     --CS01   
                                 @c_lottable10 = Lottable10,     --CS01   
                                 @c_lottable11 = Lottable11,		--CS01
											@c_lottable12 = Lottable12,		--CS01
											@d_lottable13 = Lottable13,     --CS01
                                 @d_lottable14 = Lottable14,     --CS01   
                                 @d_lottable15 = Lottable15      --CS01  	        
                          FROM LotAttribute WITH (NOLOCK)        
                          WHERE Lot = @c_lot        
                          AND   StorerKey = @c_storerkey        
                          AND   SKU = @c_sku        
                          -- (Vicky04) - End        
        
                        IF @n_continue = 1 or @n_continue = 2        
                        BEGIN        
                           SELECT @b_success = 0        
                           EXECUTE nspItrnAddMove        
                           @n_ItrnSysId    = NULL,        
                           @c_itrnkey      = NULL,        
                           @c_StorerKey    = @c_storerkey,        
                           @c_Sku          = @c_sku,        
                           @c_Lot          = @c_lot,        
                           @c_FromLoc      = @c_fromloc,        
                           @c_FromID       = @c_fromid,        
                           @c_ToLoc        = @c_toloc,-- (ChewKP02)        
                           @c_ToID         = @c_toid,         
                           @c_Status       = '',        
                           @c_lottable01   = @c_lottable01, -- (Vicky04)        
                           @c_lottable02   = @c_lottable02, -- (Vicky04)        
                           @c_lottable03   = @c_lottable03, -- (Vicky04)        
                           @d_lottable04   = @d_lottable04, -- (Vicky04)       
                           @d_lottable05   = @d_lottable05, -- (Vicky04)    
									@c_lottable06   = @c_lottable06, -- (CS01)        
                           @c_lottable07   = @c_lottable07, -- (CS01)        
                           @c_lottable08   = @c_lottable08, -- (CS01)
									@c_lottable09   = @c_lottable09, -- (CS01)        
                           @c_lottable10   = @c_lottable10, -- (CS01)        
                           @c_lottable11   = @c_lottable11, -- (CS01)
									@c_lottable12   = @c_lottable12, -- (CS01)
									@d_lottable13   = @d_lottable13, -- (CS01)        
                           @d_lottable14   = @d_lottable14, -- (CS01)        
                           @d_lottable15   = @d_lottable15, -- (CS01)    
                           @n_casecnt      = 0,        
                           @n_innerpack    = 0,        
                           @n_qty          = @n_qty,        
                           @n_pallet       = 0,        
                           @f_cube        = 0,        
                           @f_grosswgt     = 0,        
                           @f_netwgt       = 0,        
                           @f_otherunit1   = 0,        
                           @f_otherunit2   = 0,        
                           @c_SourceKey    = @c_taskdetailkey,        
                           @c_SourceType   = 'ntrTaskDetailUpdate',        
                           @c_PackKey      = @c_packkey,        
                           @c_UOM          = @c_uom,        
                           @b_UOMCalc      = 1,        
                           @d_EffectiveDate = NULL,        
                           @b_Success      = @b_Success  OUTPUT,        
                           @n_err          = @n_err      OUTPUT,        
                           @c_errmsg       = @c_errmsg   OUTPUT        
                           IF NOT @b_success=1        
                           BEGIN        
                              SELECT @n_continue = 3        
                           END        
                        END        
                     END -- not Prepack        
        
                     IF (@n_continue = 1 or @n_continue = 2) and @n_qtynotmoved > 0        
                     BEGIN        
                        SELECT @b_success = 1        
                        EXECUTE   nspg_getkey        
                        'TaskDetailKey'        
                        , 10        
                        , @c_newtaskdetailkey OUTPUT        
                        , @b_success OUTPUT        
                        , @n_err OUTPUT        
                        , @c_errmsg OUTPUT        
                        IF NOT @b_success = 1        
                        BEGIN        
                           SELECT @n_continue = 3        
                        END        
                        IF @n_continue = 1 or @n_continue = 2        
                        BEGIN        
                           INSERT TASKDETAIL        
                           (        
                           TaskDetailKey        
                           ,TaskType        
                           ,FromLoc        
                           ,FromID        
                           ,ToLoc        
                           ,Toid        
                           ,UOM        
                           ,Status        
                           ,StatusMsg        
                           ,UOMQTY        
                           ,QTY        
                           ,SourceType        
                           ,SourceKey        
                           ,Wavekey        
                           ,Priority        
                           ,UserKeyOverride        
                           )        
                           VALUES        
                           (        
                           @c_newtaskdetailkey        
                           ,@c_tasktype        
                           ,@c_fromloc -- Changed by JN cos remainder of goods still at original location in inventory        
               --          ,@c_toloc -- Yes, the FROMLOC is now the last location the worker was at, in otherwords the TOLOC of the current transaction.        
                           ,@c_deletedfromid        
                           ,''        
                           ,@c_deletedtoid        
                           ,'6'        
                           ,'0'        
                           ,'Split From TaskDetail Record '+ @c_taskdetailkey        
                           ,0        
                           ,0        
                           ,'TASKDETAIL'        
                           ,@c_taskdetailkey        
                           ,@c_wavekey        
                           ,'1'        
                           ,@c_userkey        
                           )        
                           SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT        
                           IF @n_err <> 0        
                           BEGIN        
                              SELECT @n_continue = 3        
                              SELECT @n_err= 67837--81318   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                              SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Failed On Task Detail. (ntrTaskDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '        
                           END        
                        END        
                     END        
                     CONTINUE -- Done so loop around!        
                  END        
               END        
            END        
         END  
           
         --NJOW01  
         IF (@n_continue = 1 or @n_continue = 2)   
         BEGIN  
            IF @c_Status <> @c_DeletedStatus AND @c_Status IN('9','X') AND @c_sourcetype = 'TMCCRLSE' AND @c_listkey = 'ALERT'   
            BEGIN        
              UPDATE ALERT WITH (ROWLOCK)  
              SET ALERT.Status = '9',  
                  ALERT.TrafficCop = 'T'  
              FROM ALERT   
              JOIN INSERTED ON ALERT.Taskdetailkey2 = INSERTED.Taskdetailkey  
              WHERE INSERTED.Listkey = 'ALERT'   
              AND INSERTED.Sourcetype = 'TMCCRLSE'                
              AND INSERTED.Taskdetailkey = @c_Taskdetailkey  
              AND ALERT.Status <> '9'  
            END  
         END  
         
         IF @n_continue IN(1,2)  --NJOW03 Update status to close or cancel
         BEGIN         	 
         	 IF @n_QtyReplen2 > 0 AND ISNULL(@c_Lot,'') <> '' AND ISNULL(@c_FromLoc,'') <> '' AND @c_Status IN ('X','9') AND @c_deletedStatus NOT IN('X','9')
         	 BEGIN
               IF EXISTS(SELECT 1 FROM LOTXLOCXID (NOLOCK)                                                         
                         WHERE Lot = @c_Lot                                                                        
                         AND Loc = @c_FromLoc                                                                      
                         AND ID = @c_FromID)                                                                       
               BEGIN                                                                                               
               	 UPDATE LOTXLOCXID WITH (ROWLOCK)                                                                 
                  SET QtyReplen = CASE WHEN (ISNULL(QtyReplen,0) - @n_QtyReplen2) < 0 THEN 0 ELSE ISNULL(QtyReplen,0) - @n_QtyReplen2 END                                                   
                  WHERE Lot = @c_Lot                                                                               
                  AND Loc = @c_FromLoc                                                                             
                  AND ID = @c_FromID                                                                               
                                                                                                                   
                  SET @n_err = @@ERROR                                                                             
                                                                                                                   
                  IF @n_err <> 0                                                                                   
                  BEGIN                                                                                            
                     SELECT @n_continue = 3
                           ,@n_err = 67838 
                     SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                            ':  Update LOTXLOCXID Failed! (ntrTaskDetailUpdate)'
                  END          
                  
                  UPDATE TASKDETAIL WITH (ROWLOCK)
                  SET QtyReplen = 0,
                      Trafficcop = NULL                   
                  WHERE Taskdetailkey = @c_Taskdetailkey                                                                  

                  SET @n_err = @@ERROR                                                                             
                                                                                                                   
                  IF @n_err <> 0                                                                                   
                  BEGIN                                                                                            
                     SELECT @n_continue = 3
                           ,@n_err = 67839 
                     SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                            ':  Update TASKDETAIL Failed! (ntrTaskDetailUpdate)'
                  END          
               END                                                                                                 
         	 END

         	 IF @n_PendingMoveIn > 0 AND ISNULL(@c_Lot,'') <> '' AND ISNULL(@c_FromLoc,'') <> '' AND ISNULL(@c_ToLoc,'') <> '' AND @c_Status IN ('X','9') AND @c_deletedStatus NOT IN('X','9') 
         	 BEGIN
         	 	  SET @c_ReservedID = ''
         	 	  
              SELECT @c_ReservedID = ID
         	 	  FROM dbo.RFPutaway (NOLOCK)
         	 	  WHERE Taskdetailkey = @c_TaskdetailKey
         	 	  
         	 	  SET @n_cnt = @@ROWCOUNT
         	 	  
         	 	  IF @n_cnt = 0
         	 	     SET @c_ReservedID = @c_ToID

               IF EXISTS(SELECT 1 FROM LOTXLOCXID (NOLOCK)                                                         
                         WHERE Lot = @c_Lot                                                                        
                         AND Loc = @c_ToLoc                                                                      
                         AND ID = @c_ReservedID)                                                                       
               BEGIN                                                                                               
                  EXEC rdt.rdt_Putaway_PendingMoveIn 
                       @cUserName = ''
                      ,@cType = 'UNLOCK'
                      ,@cFromLoc = ''
                      ,@cFromID = ''
                      ,@cSuggestedLOC = ''
                      ,@cStorerKey = @c_Storerkey
                      ,@nErrNo = @n_Err OUTPUT
                      ,@cErrMsg = @c_Errmsg OUTPUT
                      ,@cSKU = @c_Sku
                      ,@nPutawayQTY    = 0
                      ,@cFromLOT       = ''
                      ,@cTaskDetailKey = @c_TaskdetailKey
                      ,@nFunc = 0
                      ,@nPABookingKey = 0
                                                                                                                   
                  SET @n_err = @@ERROR                                                                             
                                                                                                                   
                  IF @n_err <> 0                                                                                   
                  BEGIN                                                                                            
                     SELECT @n_continue = 3
                           ,@n_err = 67840 
                     SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                            ':  Execute rdt.rdt_Putaway_PendingMoveIn Failed! (ntrTaskDetailUpdate)'
                  END                                                                                              

                  UPDATE TASKDETAIL WITH (ROWLOCK)
                  SET PendingMoveIn = 0,
                      Trafficcop = NULL                   
                  WHERE Taskdetailkey = @c_Taskdetailkey                                                                  

                  SET @n_err = @@ERROR                                                                             
                                                                                                                   
                  IF @n_err <> 0                                                                                   
                  BEGIN                                                                                            
                     SELECT @n_continue = 3
                           ,@n_err = 67841 
                     SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                            ':  Update TASKDETAIL Failed! (ntrTaskDetailUpdate)'
                  END          
               END                                                                                                 
         	 END            	 
         END           

         IF @n_continue IN(1,2)  --NJOW04 change qtyreplen or pendingmoveid but not cancel or close
         BEGIN
         	 --update qtyreplen
         	 IF @n_QtyReplen2 <> @n_deletedQtyReplen AND ISNULL(@c_Lot,'') <> '' AND ISNULL(@c_FromLoc,'') <> '' AND @c_Status NOT IN ('X','9')
         	 BEGIN
              IF EXISTS(SELECT 1 FROM LOTXLOCXID (NOLOCK)                                                         
                        WHERE Lot = @c_Lot                                                                        
                        AND Loc = @c_FromLoc                                                                      
                        AND ID = @c_FromID)                                                                       
              BEGIN                                      
              	 UPDATE LOTXLOCXID WITH (ROWLOCK)                                                                 
                 SET QtyReplen = CASE WHEN (ISNULL(QtyReplen,0) + (@n_QtyReplen2 - @n_deletedQtyReplen)) < 0 THEN 0 ELSE ISNULL(QtyReplen,0) + (@n_QtyReplen2 - @n_deletedQtyReplen) END                                                   
                 WHERE Lot = @c_Lot                                                                               
                 AND Loc = @c_FromLoc                                                                             
                 AND ID = @c_FromID                                                                               
                                                                                                                  
                 SET @n_err = @@ERROR                                                                             
                                                                                                                  
                 IF @n_err <> 0                                                                                   
                 BEGIN                                                                                            
                    SELECT @n_continue = 3
                          ,@n_err = 67839 
                    SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                           ':  Update LOTXLOCXID Failed! (ntrTaskDetailUpdate)'
                 END    
              END     
           END     
           
           --update pendingmovein   
         	 IF @n_PendingMoveIn <> @n_deletedPendingMoveIn AND ISNULL(@c_Lot,'') <> '' AND ISNULL(@c_FromLoc,'') <> '' AND ISNULL(@c_ToLoc,'') <> '' AND @c_Status NOT IN ('X','9')
         	 BEGIN         	 	  

         	 	  SET @c_ReservedID = ''
         	 	  
              SELECT @c_ReservedID = ID
         	 	  FROM dbo.RFPutaway (NOLOCK)
         	 	  WHERE Taskdetailkey = @c_TaskdetailKey
         	 	  
         	 	  SET @n_cnt = @@ROWCOUNT
         	 	  
         	 	  IF @n_cnt = 0
         	 	     SET @c_ReservedID = @c_ToID

         	 	  --amend qty
         	 	  IF @n_PendingMoveIn > 0 AND @n_deletedPendingMoveIn > 0
         	 	  BEGIN         	 	     
         	 	     IF @n_cnt > 0
         	 	     BEGIN
         	 	        UPDATE dbo.RFPutaway WITH (ROWLOCK)
         	 	        SET Qty = CASE WHEN (Qty + (@n_PendingMoveIn - @n_deletedPendingMoveIn)) < 0 THEN 0 ELSE Qty + (@n_PendingMoveIn - @n_deletedPendingMoveIn) END  
         	 	     	  WHERE Taskdetailkey = @c_Taskdetailkey         	    	  	  
                 
                    SET @n_err = @@ERROR                                                                             
                                                                                                                     
                    IF @n_err <> 0                                                                                   
                    BEGIN                                                                                            
                       SELECT @n_continue = 3
                             ,@n_err = 67840 
                       SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                              ':  Update RFPutaway Failed! (ntrTaskDetailUpdate)'
                    END    
         	 	     END
         	 	  
                 IF EXISTS(SELECT 1 FROM LOTXLOCXID (NOLOCK)                                                         
                           WHERE Lot = @c_Lot                                                                        
                           AND Loc = @c_ToLoc                                                                      
                           AND ID = @c_ReservedID)                                                                       
                 BEGIN
           	       UPDATE LOTXLOCXID WITH (ROWLOCK)                                                                 
                    SET PendingMoveIn = CASE WHEN (ISNULL(PendingMoveIn,0) + (@n_PendingMoveIn - @n_deletedPendingMoveIn)) < 0 THEN 0 ELSE ISNULL(PendingMoveIn,0) + (@n_PendingMoveIn - @n_deletedPendingMoveIn) END
                    WHERE Lot = @c_Lot                                                                               
                    AND Loc = @c_ToLoc                                                                             
                    AND ID = @c_ReservedID                                              
                                     
                    SET @n_err = @@ERROR                                                                             
                                                                                                                     
                    IF @n_err <> 0                                                                                   
                    BEGIN                                                                                            
                       SELECT @n_continue = 3
                             ,@n_err = 67841 
                       SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                              ':  Update LOTXLOCXID Failed! (ntrTaskDetailUpdate)'
                    END
                 END          
              END
              
              --remove pendingmovein
         	 	  IF @n_PendingMoveIn = 0 AND @n_deletedPendingMoveIn > 0
         	 	  BEGIN         
                 IF EXISTS(SELECT 1 FROM LOTXLOCXID (NOLOCK)                                                         
                           WHERE Lot = @c_Lot                                                                        
                           AND Loc = @c_ToLoc                                                                      
                           AND ID = @c_ReservedID)                                                                       
                 BEGIN                                                                                               
                    EXEC rdt.rdt_Putaway_PendingMoveIn 
                         @cUserName = ''
                        ,@cType = 'UNLOCK'
                        ,@cFromLoc = ''
                        ,@cFromID = ''
                        ,@cSuggestedLOC = ''
                        ,@cStorerKey = @c_Storerkey
                        ,@nErrNo = @n_Err OUTPUT
                        ,@cErrMsg = @c_Errmsg OUTPUT
                        ,@cSKU = @c_Sku
                        ,@nPutawayQTY    = 0
                        ,@cFromLOT       = ''
                        ,@cTaskDetailKey = @c_TaskdetailKey
                        ,@nFunc = 0
                        ,@nPABookingKey = 0
                                                                                                                     
                    SET @n_err = @@ERROR                                                                             
                                                                                                                     
                    IF @n_err <> 0                                                                                   
                    BEGIN                                                                                            
                       SELECT @n_continue = 3
                             ,@n_err = 67842 
                       SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                              ':  Execute rdt.rdt_Putaway_PendingMoveIn Failed! (ntrTaskDetailUpdate)'
                    END                                                                                                            
                 END                                                       
              END                                                                                              

              --create new pendingmovein
         	 	  IF @n_deletedPendingMoveIn = 0 AND @n_PendingMoveIn > 0
         	 	  BEGIN
                 EXEC rdt.rdt_Putaway_PendingMoveIn 
                      @cUserName = ''
                     ,@cType = 'LOCK'
                     ,@cFromLoc = @c_FromLoc
                     ,@cFromID = @c_FromID
                     ,@cSuggestedLOC = @c_ToLoc
                     ,@cStorerKey = @c_Storerkey
                     ,@nErrNo = @n_Err OUTPUT
                     ,@cErrMsg = @c_Errmsg OUTPUT
                     ,@cSKU = @c_Sku
                     ,@nPutawayQTY    = @n_PendingMoveIn
                     ,@cFromLOT       = @c_LOT
                     ,@cTaskDetailKey = @c_TaskdetailKey
                     ,@nFunc = 0
                     ,@nPABookingKey = 0
                     ,@cMoveQTYAlloc = '1'         	 	  	
                 
                 SET @n_err = @@ERROR                                                                             
                                                                                                                  
                 IF @n_err <> 0                                                                                   
                 BEGIN                                                                                            
                    SELECT @n_continue = 3
                          ,@n_err = 67843
                    SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                           ':  Execute rdt.rdt_Putaway_PendingMoveIn Failed! (ntrTaskDetailUpdate)'
                 END                                                                                                                                  
         	 	  END

         	 END            	                       	 	         	
         END                                     
      END -- WHILE 1=1        
   END        
   /* #INCLUDE <TRTASKDU2.SQL> */        
   IF @n_continue=3  -- Error Occured - Process And Return        
   BEGIN        
    -- To support RDT - start        
       DECLARE @n_IsRDT INT        
       EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT        
        
       IF @n_IsRDT = 1        
       BEGIN        
          -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here        
          -- Instead we commit and raise an error back to parent, let the parent decide        
        
          -- Commit until the level we begin with        
          WHILE @@TRANCOUNT > @n_starttcnt        
             COMMIT TRAN        
        
          -- Raise error with severity = 10, instead of the default severity 16.         
          -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger        
          RAISERROR (@n_err, 10, 1) WITH SETERROR         
        
          -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten        
      END        
      ELSE        
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
         execute nsp_logerror @n_err, @c_errmsg, 'ntrTaskDetailUpdate'      
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012     
         RETURN      
      END         
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