SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrTaskDetailDelete                                         */
/* Creation Date:                                                       */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
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
/* Date         Author  Ver  Purposes                                   */
/* 20-Sep-2016  TLTING  1.1  Change SetROWCOUNT 1 to Top 1              */
/* 05-JUN-2017  NJOW01  1.2  WMS-1986 Update QtyReplen and              */
/*                           PendingMoveIn to LotXLocXId                */ 
/* 12-Feb-2018  NJOW02  1.3  Fix id for pendingmovein removal           */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrTaskDetailDelete]
 ON  [dbo].[TaskDetail]
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

 DECLARE
   @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?
 , @n_err                int       -- Error number returned by stored procedure or this trigger
 , @n_err2               int       -- For Additional Error Detection
 , @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
 , @n_continue           int                 
 , @n_starttcnt          int       -- Holds the current transaction count
 , @c_preprocess         NVARCHAR(250) -- preprocess
 , @c_pstprocess         NVARCHAR(250) -- post process
 , @n_cnt                int                  
 , @c_authority          NVARCHAR(1)  -- KHLim02
 , @c_PickDetailStatus   NVARCHAR(10) 
 , @n_PendingMoveIn      INT --NJOW01
 , @n_QtyReplen          INT --NJOW01
 , @c_ReservedID         NVARCHAR(18) --NJOW02

 DECLARE @c_LocationCategy NVARCHAR(10) -- (Vicky02)

 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
      /* #INCLUDE <TRTASKDD1.SQL> */     
 IF (SELECT COUNT(*) FROM DELETED) = (SELECT COUNT(*) FROM DELETED WHERE ArchiveCop = '9')
 BEGIN
 SELECT @n_continue = 4
 END
 IF @n_continue=1 or @n_continue=2
 BEGIN
     IF EXISTS (SELECT * FROM deleted WHERE STATUS='9' )
     BEGIN
         SELECT @n_continue = 3 , @n_err = 67997 --82001
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Item(s) Are Completed - Delete Failed. (ntrTaskDetailDelete)'
     END
 END

 --NJOW01
 IF @n_continue=1 or @n_continue=2          
 BEGIN
    IF EXISTS (SELECT 1 FROM DELETED d  
               JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey    
               JOIN sys.objects sys WITH (NOLOCK) ON sys.type = 'P' AND sys.name = s.Svalue
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
                 'DELETE'  --@c_Action
               , @b_Success  OUTPUT  
               , @n_Err      OUTPUT   
               , @c_ErrMsg   OUTPUT  

       IF @b_success <> 1  
       BEGIN  
          SELECT @n_continue = 3  
                ,@c_errmsg = 'ntrTaskDetailDelete ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))
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
     @c_toloc NVARCHAR(10), @c_toid NVARCHAR(18), @c_lot NVARCHAR(10), @n_qty int, @c_packkey NVARCHAR(10), @c_uom NVARCHAR(5),
     @c_caseid NVARCHAR(10), @c_sourcekey NVARCHAR(30), @c_status NVARCHAR(10), @c_reasonkey NVARCHAR(10)

      --(Wan01) - START
      DECLARE @c_Sourcetype      NVARCHAR(30)
            , @c_RefTaskKey      NVARCHAR(10)

      SET @c_RefTaskKey    = ''
      --(Wan01) - END
     SELECT @c_taskdetailkey = SPACE(10)
     WHILE (1=1)
     BEGIN         
         SELECT  TOP 1
                 @c_taskdetailkey = taskdetailkey,
                 @c_tasktype = tasktype ,
                 @c_storerkey = storerkey,
                 @c_sku = sku,
                 @c_fromloc = fromloc ,
                 @c_fromid = fromid ,
                 @c_toloc = toloc ,
                 @c_toid = toid,
                 @c_lot = lot ,
                 @n_qty = qty,
                 @c_caseid = caseid,
                 @c_sourcekey = sourcekey,
                 @c_status = status,
                 @c_reasonkey = reasonkey,
                 @c_Sourcetype = SourceType,                                                        --(Wan01)
                 @c_RefTaskKey = RefTaskKey,                                                        --(Wan01)
                 @n_QtyReplen = QtyReplen,           --NJOW01
                 @n_PendingMoveIn = PendingMoveIn    --NJOW01
         FROM DELETED
         WHERE taskdetailkey > @c_Taskdetailkey
         ORDER BY taskdetailkey

         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END

         -- (Vicky02) - Start
         SELECT @c_LocationCategy = LocationCategory 
         FROM   LOC l WITH (NOLOCK)
         WHERE  l.Loc = @c_toloc
         -- (Vicky02) - End

         --(Wan01) - START
         IF @c_sourcetype = 'VAS'  
         BEGIN
            EXEC ispVASTaskProcessing
                  'DEL'
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
         --(Wan01) - END
     IF @n_continue = 1 or @n_continue = 2
     -- added by mmlee , 07/08/2001 for fbr28c - Pallet move for different floor
     -- start
     IF (@c_tasktype = 'MV') 
     BEGIN
 	    IF EXISTS (SELECT 1 from putawaytask With (nolock) where taskdetailkey = @c_taskdetailkey)
 		    DELETE from putawaytask where taskdetailkey = @c_taskdetailkey
     END	
     -- end

     IF (@c_tasktype = 'PA') OR 
     (@c_tasktype='PK' AND @c_LocationCategy IN ('PnD_Ctr','PnD_Out')) -- (Vicky02)
     BEGIN
       IF @n_continue = 1 or @n_continue = 2
       BEGIN
         IF ISNULL(RTRIM(@c_toid), '') <> '' AND ISNULL(RTRIM(@c_toloc), '') <> ''
         BEGIN
             IF @n_continue = 1 or @n_continue = 2
             BEGIN
                 INSERT LOTxLOCxID (Lot,Loc,ID,Storerkey,Sku)
                 SELECT L1.Lot,@c_toloc,@c_toid,L1.Storerkey,L1.Sku
                 FROM LOTxLOCxID L1 WITH (NOLOCK)
                 WHERE L1.Id  = @c_fromid
                 AND   L1.Loc = @c_fromloc
                 AND   NOT EXISTS
                 (SELECT 1 FROM LOTxLOCxID L3 with (NOLOCK)
                 WHERE L3.Lot = L1.Lot
                 AND   L3.Loc = @c_toloc
                 AND   L3.ID  = @c_toid
                 )
                 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                 IF @n_err <> 0
                 BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 67998--82002   
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed To LOTxLOCxID. (ntrTaskDetailDelete)' + ' ( ' 
                           + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
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
                     ,              @c_action       = 'R'
                     ,              @b_Success      = @b_success
                     ,              @n_err          = @n_err
                     ,              @c_errmsg       = @c_errmsg
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
         IF ISNULL(RTRIM(@c_toid), '') = '' AND ISNULL(RTRIM(@c_toloc), '') <> ''
         BEGIN
            -- (ChewKP01) (Start) --
            IF @n_continue = 1 or @n_continue = 2
             BEGIN
                 INSERT LOTxLOCxID (Lot,Loc,ID,Storerkey,Sku)
                 SELECT L1.Lot,@c_toloc,@c_toid,L1.Storerkey,L1.Sku
                 FROM LOTxLOCxID L1 WITH (NOLOCK)
                 WHERE L1.Lot  = @c_lot
                 AND   L1.Loc = @c_fromloc
                 AND   NOT EXISTS
                 (SELECT 1 FROM LOTxLOCxID L3 with (NOLOCK)
                 WHERE L3.Lot = L1.Lot
                 AND   L3.Loc = @c_toloc
                 AND   L3.ID  = @c_toid
                 )
                 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                 IF @n_err <> 0
                 BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 67998--82002   
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed To LOTxLOCxID. (ntrTaskDetailDelete)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                 END
             END
             -- (ChewKP01) (End) --
             
             IF @n_continue = 1 or @n_continue = 2
             BEGIN
                 SELECT @b_success = 1
                 execute nspPendingMoveInUpdate
                                @c_storerkey    = @c_storerkey
                 ,              @c_sku          = @c_sku
                 ,              @c_lot          = @c_lot
                 ,              @c_Loc          = @c_toloc
                 ,              @c_ID           = ''
                 ,              @c_fromloc      = @c_fromloc
                 ,              @c_fromid       = @c_fromid
                 ,              @n_qty          = @n_qty
                 ,              @c_action       = 'R'
                 ,              @b_Success      = @b_success
                 ,              @n_err          = @n_err
                 ,              @c_errmsg       = @c_errmsg
                 ,              @c_tasktype     = @c_tasktype -- (Vicky02)

                 IF @b_success = 0
                 BEGIN
                   SELECT @n_continue = 3
                 END
             END
          END
    END
     END
     
     IF @n_Continue = 1 OR @n_Continue = 2  
     BEGIN  
         IF (@c_TaskType IN ('PK','VNPK') )  -- (ChewKP02)
         BEGIN  
             SET @c_PickDetailStatus = ''  
               
             SELECT TOP 1  
                    @c_PickDetailStatus = ISNULL(STATUS,'')  
             FROM PICKDETAIL WITH (NOLOCK)  
             WHERE  TaskDetailKey = @c_TaskDetailKey   
             ORDER BY [Status] DESC   
               
             IF @c_PickDetailStatus IN ('5','6','7','8','9')  
             BEGIN  
                SELECT @n_Continue = 3  
                SELECT @c_errmsg = CONVERT(CHAR(250), @n_Err),  
                       @n_Err = 67999   
                SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +   
                       ': Cannot Delete Confirmed Pick Task  (ntrTaskDetailDelete)'    
             END  
             IF @c_PickDetailStatus  IN ('0','1','2','3','4')  
             BEGIN  
                UPDATE PICKDETAIL WITH (ROWLOCK)   
                SET TaskDetailKey = '', TrafficCop = NULL  
                WHERE TaskDetailKey = @c_TaskDetailKey  
                AND   STATUS IN ('0','1','2','3','4')  
             END                      
         END   
     END
     
     IF @n_Continue IN(1,2) --NJOW01
     BEGIN
        IF @n_QtyReplen > 0 AND ISNULL(@c_Lot,'') <> '' AND ISNULL(@c_FromLoc,'') <> '' AND @c_Status NOT IN('9','X')
        BEGIN
           IF EXISTS(SELECT 1 FROM LOTXLOCXID (NOLOCK)                                                         
                     WHERE Lot = @c_Lot                                                                        
                     AND Loc = @c_FromLoc                                                                      
                     AND ID = @c_FromID)                                                                       
           BEGIN                                                                                               
           	 UPDATE LOTXLOCXID WITH (ROWLOCK)                                                                 
              SET QtyReplen = CASE WHEN (QtyReplen - @n_QtyReplen) < 0 THEN 0 ELSE QtyReplen - @n_QtyReplen END                                                   
              WHERE Lot = @c_Lot                                                                               
              AND Loc = @c_FromLoc                                                                             
              AND ID = @c_FromID                                                                               
                                                                                                               
              SET @n_err = @@ERROR                                                                             
                                                                                                               
              IF @n_err <> 0                                                                                   
              BEGIN                                                                                            
                 SELECT @n_continue = 3
                       ,@n_err = 68000 
                 SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                        ':  Update LOTXLOCXID Failed! (ntrTaskDetailDelete)'
              END                                                                                              
           END                                                                                                 
        END
        
        IF @n_PendingMoveIn > 0 AND ISNULL(@c_Lot,'') <> '' AND ISNULL(@c_FromLoc,'') <> '' AND ISNULL(@c_ToLoc,'') <> '' AND @c_Status NOT IN('9','X')
        BEGIN
        	 --NJOW02 Start
	 	       SET @c_ReservedID = ''
         	 	  
           SELECT @c_ReservedID = ID
         	 FROM dbo.RFPutaway (NOLOCK)
         	 WHERE Taskdetailkey = @c_TaskdetailKey
         	 	  
         	 SET @n_cnt = @@ROWCOUNT
         	 	  
         	 IF @n_cnt = 0
         	    SET @c_ReservedID = @c_ToID        	
         	 --NJOW02 End
         	    
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
                       ,@n_err = 68001 
                 SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                        ':  Execute rdt.rdt_Putaway_PendingMoveIn Failed! (ntrTaskDetailDelete)'
              END                                                                                              
           END                                                                                                 
        END            	 
     END
 END -- WHILE 1=1
 
 END
 
      -- Start (KHLim01) 
   IF @n_continue = 1 or @n_continue = 2
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
               ,@c_errmsg = 'ntrTaskDetailDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
         INSERT INTO dbo.TaskDetail_DELLOG ( TaskDetailKey )
         SELECT TaskDetailKey FROM DELETED

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table ORDERS Failed. (ntrTaskDetailDelete)' 
                  + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END
   -- End (KHLim01) 

      /* #INCLUDE <TRTASKDD2.SQL> */
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
        execute nsp_logerror @n_err, @c_errmsg, 'ntrTaskDetailDelete'
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