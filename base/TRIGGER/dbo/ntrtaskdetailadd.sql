SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ntrTaskDetailAdd                                            */
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
/* 05-Jan-2009  1.1     Vicky    RDT Compatible Error Message (Vicky01) */
/* 12-Jan-2010  1.2     Shong    Added the Non-Inventory Move Pending   */
/*                               Move In Qty                            */
/* 26-Jan-2010  1.3     Vicky    Add in new parameter to PendingMoveIn  */
/*                               Stored Proc (Vicky02)                  */
/* 18-Feb-2010  1.4     ChewKP   Do not update pendingmovein when       */
/*                               when task status = 'Q' (ChewKP01)      */
/* 21-Jun-2010  1.5     ChewKP   Create Record in LotxLocxID when       */
/*                               ID = '' and ToLoc <> '' SOS#178103     */
/*                               (ChewKP02)                             */
/* 08-Feb-2013  1.6     Ung      Add TrafficCop                         */
/* 18-Dec-2012  1.6     YTWan    SOS#260275: VAS-CreateJobs (Wan01)     */ 
/* 21-SEP-2016  1.7     SHONG01  Remove SetRowCount                     */
/* 05-JUN-2017  1.8     NJOW01   WMS-1986 Update QtyReplen and          */
/*                               PendingMoveIn to LotXLocXId            */ 
/* 06-JUL-2017  1.9     NJOW02   RDT request to skip the insert trigger */
/* 12-JAN-2018  2.0     Wan02    Fixed to use output err from           */
/*                               rdt_Putaway_PendingMoveIn instead @@ERROR */
/* 13-Jan-2020  2.1     NJOW03   WMS-11388 call custom stored proc      */ 
/* 27-Jul-2022  2.1     Wan03    Fix to set @n_err = 0 as Output blank  */ 
/*                               and caused Prompt error 67994          */
/************************************************************************/

CREATE   TRIGGER [dbo].[ntrTaskDetailAdd]
ON [dbo].[TaskDetail]
FOR  INSERT
AS
BEGIN
    SET NOCOUNT ON
    SET ANSI_NULLS OFF  
    SET QUOTED_IDENTIFIER OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @b_Success       INT -- Populated by calls to stored procedures - was the proc successful?
           ,@n_err           INT -- Error number returned by stored procedure or this trigger
           ,@n_err2          INT -- For Additional Error Detection
           ,@c_errmsg        NVARCHAR(250) -- Error message returned by stored procedure or this trigger
           ,@n_continue      INT
           ,@n_starttcnt     INT -- Holds the current transaction count
           ,@c_preprocess    NVARCHAR(250) -- preprocess
           ,@c_pstprocess    NVARCHAR(250) -- post process
           ,@n_cnt           INT
           ,@b_isDiffFloor   INT -- added by mmlee , 07/08/2001 for fbr28c - Pallet move for different floor
           ,@c_fromoutloc    NVARCHAR(10) -- added by mmlee , 07/08/2001 for fbr28c - Pallet move for different floor
           ,@n_PendingMoveIn INT --NJOW01
           ,@n_QtyReplen     INT --NJOW01

   --(Wan01) - START
   DECLARE @c_SourceType     NVARCHAR(10)

   DECLARE @n_IsRDT INT

   SET @c_SourceType    = ''

   --(Wan01) - END 

    SELECT @n_continue = 1
          ,@n_starttcnt = @@TRANCOUNT
    /* #INCLUDE <TRTASKDA1.SQL> */

   DECLARE @c_LocationCategy NVARCHAR(10)

   IF @n_continue = 1 OR @n_continue = 2      
      BEGIN      
      IF EXISTS (SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')      
      BEGIN      
         SELECT @n_continue = 4      
      END      
   END   

   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT --NJOW02

   IF EXISTS (SELECT 1 FROM INSERTED WHERE TrafficCop = '9') OR @n_IsRDT=1  --NJOW02
   BEGIN      
      SELECT @n_continue = 4      
   END      
   /* --remove use trafficcop='9' to skip for insert because update always true when insert
   IF UPDATE(TrafficCop) 
   BEGIN
      SELECT @n_continue = 4
   END*/

    IF @n_continue=1 OR
       @n_continue=2
    BEGIN
        IF EXISTS (
               SELECT *
               FROM   INSERTED
               WHERE  STATUS = '9'
           )
        BEGIN
            SELECT @n_continue = 3
                  ,@n_err = 67991--81905
            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                   ': Cannot Insert Completed Items! (ntrTaskDetailAdd)'
        END
    END
    
    IF @n_continue=1 OR
       @n_continue=2
    BEGIN
        IF EXISTS (
               SELECT *
               FROM   INSERTED
               WHERE  ISNULL(RTRIM(reasonkey) ,'')<>''
           )
        BEGIN
            SELECT @n_continue = 3
                  ,@n_err = 67992 --81906
            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                   ': Cannot Insert Items With A ReasonCode Filled In! (ntrTaskDetailAdd)'
        END
    END
    
    --NJOW03
    IF @n_continue=1 or @n_continue = 2
    BEGIN
       IF EXISTS (SELECT 1 FROM INSERTED i
                  JOIN storerconfig s WITH (NOLOCK) ON  i.storerkey = s.storerkey
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
                    'INSERT'  --@c_Action
                  , @b_Success  OUTPUT
                  , @n_Err      OUTPUT
                  , @c_ErrMsg   OUTPUT
    
          IF @b_success <> 1
          BEGIN
             SELECT @n_continue = 3
                   ,@c_errmsg = 'ntrTaskDetailAdd ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))
          END
    
          IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
             DROP TABLE #INSERTED
    
          IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
             DROP TABLE #DELETED
       END
    END    

    IF @n_continue=1 OR
       @n_continue=2
    BEGIN
        DECLARE @c_taskdetailkey     NVARCHAR(10)
               ,@c_tasktype          NVARCHAR(10)
               ,@c_newtaskdetailkey  NVARCHAR(10)

        DECLARE @c_pickdetailkey     NVARCHAR(10)
        DECLARE @c_storerkey         NVARCHAR(15)
               ,@c_sku               NVARCHAR(20)
               ,@c_fromloc           NVARCHAR(10)
               ,@c_fromid            NVARCHAR(18)
               ,@c_toloc             NVARCHAR(10)
               ,@c_toid              NVARCHAR(18)
               ,@c_lot               NVARCHAR(10)
               ,@n_qty               INT
               ,@c_packkey           NVARCHAR(10)
               ,@c_uom               NVARCHAR(5)
               ,@c_caseid            NVARCHAR(10)
               ,@c_sourcekey         NVARCHAR(30)
               ,@c_status            NVARCHAR(10)
               ,@c_reasonkey         NVARCHAR(10)
               ,@n_uomqty            INT /* add by mmlee - FBR028c , to grab the uomqty  */

        SELECT @c_taskdetailkey = SPACE(10)
        WHILE (1=1)
        BEGIN
            SELECT TOP 1
                   @c_taskdetailkey = taskdetailkey
                  ,@c_tasktype = tasktype
                  ,@c_storerkey = storerkey
                  ,@c_sku = sku
                  ,@c_fromloc = fromloc
                  ,@c_fromid = fromid
                  ,@c_toloc = toloc
                  ,@c_toid = toid
                  ,@c_lot = lot
                  ,@n_qty = qty
                  ,@c_caseid = caseid
                  ,@c_sourcekey = sourcekey
                  ,@c_status = STATUS
                  ,@c_reasonkey = reasonkey
                  ,@n_uomqty = uomqty  /* add by mmlee 07/07/2001 - FBR028c , to grab the uomqty  */
                  ,
                   @c_uom = uom /* add by mmlee 07/08/2001 - FBR028c , to grab the uom  */
                  ,@c_SourceType = SourceType                                                      --(Wan01)
                  ,@c_PickDetailKey = PickDetailKey                                                --(Wan01)
                  ,@n_QtyReplen = QtyReplen           --NJOW01
                  ,@n_PendingMoveIn = PendingMoveIn   --NJOW01
            FROM   INSERTED
            WHERE  taskdetailkey>@c_Taskdetailkey
            ORDER BY
                   taskdetailkey

            IF @@ROWCOUNT=0
            BEGIN
                BREAK
            END

            SELECT @c_LocationCategy = LocationCategory
            FROM   LOC l WITH (NOLOCK)
            WHERE  l.Loc = @c_toloc


            --(Wan01) - START
            IF @c_SourceType = 'VAS' 
            BEGIN
               EXEC ispVASTaskProcessing
                     'ADD'
                  ,  @c_TaskdetailKey
                  ,  @c_Tasktype  
                  ,  @c_Sourcekey 
                  ,  @c_SourceType 
                  ,  @c_PickDetailKey
                  ,  '' 
                  ,  @c_Storerkey 
                  ,  @c_Sku 
                  ,  @c_Fromloc 
                  ,  @c_Fromid 
                  ,  @c_Toloc 
                  ,  @c_Toid  
                  ,  @c_Lot 
                  ,  @n_Qty 
                  ,  @n_UOMQty  
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

            -- added by MMLEE - 07/08/2001 Customized for PICK N DROP - MOVE
            IF (@c_tasktype='MV')
            BEGIN
                -- add by mmlee - FBR028c - To do a pallet move, uom must = 'pallet'
                IF @c_uom='1'
                    EXEC nspInsertIntoPutawayTask @c_taskdetailkey
                        ,@c_fromloc
                        ,@c_toloc
                        ,@c_fromid
                        ,@c_sku
                        ,@c_fromoutloc OUTPUT
                        ,@b_isDiffFloor OUTPUT
            END
            -- end of PICK N DROP - MOVE
            IF (@c_tasktype='PA') OR
               (@c_tasktype='PK' AND @c_LocationCategy IN ('PnD_Ctr','PnD_Out') AND  @c_status  <> 'Q' ) -- (ChewKP01)

               --(@c_tasktype='NMV' AND @c_LocationCategy IN ('PnD_Ctr','PnD_Out'))
            BEGIN
                IF @n_continue=1 OR
                   @n_continue=2
                BEGIN
                    IF ISNULL(RTRIM(@c_fromid) ,'')=''
                    BEGIN
                        IF ISNULL(RTRIM(@c_sku) ,'')='' OR
                           ISNULL(RTRIM(@c_storerkey) ,'')='' OR
                           ISNULL(RTRIM(@c_lot) ,'')='' OR
                           ISNULL(RTRIM(@c_fromloc) ,'')='' OR
                           @n_qty=0
                        BEGIN
                            SELECT @n_continue = 3
                                  ,@n_err = 67993 --81901
                            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                                   ': FromID is blank therefore LOT/FROMLOC/ID/QTY/STORERKEY/SKU must be filled in. (ntrTaskDetailAdd)'
                        END
                    END
                END

                IF @n_continue=1 OR
                   @n_continue=2
                BEGIN
                    IF ISNULL(RTRIM(@c_fromid) ,'')<>''
                    BEGIN
                        IF ISNULL(RTRIM(@c_lot) ,'')<>''
                        BEGIN
                            SELECT @n_continue = 3
                                  ,@n_err = 67994 --81902
                            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                                   ': FromID has been filled in therefore LOT should be blank. (ntrTaskDetailAdd)'
                        END
                    END
                END

                IF @n_continue=1 OR
                   @n_continue=2
                BEGIN
                    IF ISNULL(RTRIM(@c_fromloc) ,'')=''
                    BEGIN
                        SELECT @n_continue = 3
                              ,@n_err = 67995 --81903
                        SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                               ': FromLOC should be filled in. (ntrTaskDetailAdd)'
                    END
                END

                IF @n_continue=1 OR
                   @n_continue=2
                BEGIN
                    IF ISNULL(RTRIM(@c_toid) ,'')<>'' AND
                       ISNULL(RTRIM(@c_toloc) ,'')<>''
                    BEGIN
                        IF @n_continue=1 OR
                           @n_continue=2
                        BEGIN
                            INSERT LOTxLOCxID
                              (
                                Lot
                               ,Loc
                               ,ID
                               ,Storerkey
                               ,Sku
                              )
                            SELECT L1.Lot
                                  ,@c_toloc
                                  ,@c_toid
                                  ,L1.Storerkey
                                  ,L1.Sku
                            FROM   LOTxLOCxID L1 WITH (NOLOCK)
                            WHERE  L1.Id = @c_fromid AND
                                   L1.Loc = @c_fromloc AND
                                   NOT EXISTS
                                   (
                                       SELECT 1
                                       FROM   LOTxLOCxID L3
                                       WHERE  L3.Lot = L1.Lot AND
                                              L3.Loc = @c_toloc AND
                                              L3.ID = @c_toid
                                   )

                            SELECT @n_err = @@ERROR
                                  ,@n_cnt = @@ROWCOUNT

                            IF @n_err<>0
                            BEGIN
                                SELECT @n_continue = 3
                                SELECT @n_err = 67996 --81904   
                                SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)
                                      +
                                       ': Update Failed To LOTxLOCxID. (ntrTaskDetailAdd)'
                                      +' ( '+' SQLSvr MESSAGE='+dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))
                                      +' ) '
                            END
                        END

                        IF @n_continue=1 OR
                           @n_continue=2
                        BEGIN
                            SELECT @b_success = 1
                            EXECUTE nspPendingMoveInUpdate
                            @c_storerkey=''
                            , @c_sku=''
                            , @c_lot=''
                            , @c_Loc=@c_toloc
                            , @c_ID=@c_toid
                            , @c_fromloc=@c_fromloc
                            , @c_fromid=@c_fromid
                            , @n_qty=@n_qty
                            , @c_action='I'
                            , @b_Success=@b_success
                            , @n_err=@n_err
                            , @c_errmsg=@c_errmsg
                            , @c_tasktype = @c_tasktype -- (Vicky02)
                            IF @b_success=0
                            BEGIN
                                SELECT @n_continue = 3
                            END
                        END
                    END
                END

                IF @n_continue=1 OR
                   @n_continue=2
                BEGIN
                    IF ISNULL(RTRIM(@c_toid) ,'')='' AND
                       ISNULL(RTRIM(@c_toloc) ,'')<>''
                    BEGIN
                        IF @n_continue=1 OR
                           @n_continue=2
                        BEGIN
                           -- (ChewKP02) (Start) --
                           INSERT LOTxLOCxID
                              (
                                Lot
                               ,Loc
                               ,ID
                               ,Storerkey
                               ,Sku
                              )
                            SELECT L1.Lot
                                  ,@c_toloc
                                  ,@c_toid
                                  ,L1.Storerkey
                                  ,L1.Sku
                            FROM   LOTxLOCxID L1 WITH (NOLOCK)
                            WHERE  L1.Lot = @c_lot AND
                                   L1.Loc = @c_fromloc AND
                                   NOT EXISTS
                                   (
                                       SELECT 1
                                       FROM   LOTxLOCxID L3
                                       WHERE  L3.Lot = L1.Lot AND
                                              L3.Loc = @c_toloc AND
                                              L3.ID = @c_toid
                                   )

                            SELECT @n_err = @@ERROR
                                  ,@n_cnt = @@ROWCOUNT

                            IF @n_err<>0
                            BEGIN
                                SELECT @n_continue = 3
                                SELECT @n_err = 67996 --81904   
                                SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)
                                      +
                                       ': Update Failed To LOTxLOCxID. (ntrTaskDetailAdd)'
                                      +' ( '+' SQLSvr MESSAGE='+dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))
                                      +' ) '
                            END

                           -- SKIP PENDING MOVEIN UPDATE

                           -- (ChewKP02) (End) --
                       END

                       IF @n_continue=1 OR
                           @n_continue=2
                        BEGIN
                            SELECT @b_success = 1
                            EXECUTE nspPendingMoveInUpdate
                            @c_storerkey=@c_storerkey
                            , @c_sku=@c_sku
                            , @c_lot=@c_lot
                            , @c_Loc=@c_toloc
                            , @c_ID=''
                            , @c_fromloc=@c_fromloc
                            , @c_fromid=@c_fromid
                            , @n_qty=@n_qty
                            , @c_action='I'
                            , @b_Success=@b_success
                            , @n_err=@n_err
                            , @c_errmsg=@c_errmsg
                            , @c_tasktype = @c_tasktype -- (Vicky02)
                            IF @b_success=0
                            BEGIN
                                SELECT @n_continue = 3
                            END
                        END
                    END
                END
            END
            --@c_toinloc


            IF @n_continue=1 OR
               @n_continue=2
            BEGIN
                UPDATE TASKDETAIL WITH (ROWLOCK)
                SET    LOGICALFROMLOC = LOC.LOGICALLOCATION
                      ,TRAFFICCOP = NULL
                FROM   TASKDETAIL
                       JOIN LOC WITH (NOLOCK)
                            ON  (TASKDETAIL.FROMLOC=LOC.LOC)
                WHERE  TASKDETAIL.taskdetailkey = @c_taskdetailkey AND
                       ISNULL(RTRIM(TASKDETAIL.FROMLOC) ,'')<>'' AND
                       ISNULL(RTRIM(TASKDETAIL.LOGICALFROMLOC) ,'') = ''

                UPDATE TASKDETAIL WITH (ROWLOCK)
                SET    LOGICALFROMLOC = FROMLOC
                      ,TRAFFICCOP = NULL
                FROM   TASKDETAIL
                WHERE  TASKDETAIL.taskdetailkey = @c_taskdetailkey AND
                       ISNULL(RTRIM(TASKDETAIL.FROMLOC) ,'')<>'' AND
                       ISNULL(RTRIM(TASKDETAIL.LOGICALFROMLOC) ,'') = ''

                UPDATE TASKDETAIL WITH (ROWLOCK)
                SET    LOGICALTOLOC = (
                           CASE
                                WHEN @b_isDiffFloor=1 THEN @c_FromOutLoc
                                ELSE LOC.LOGICALLOCATION
                           END
                       )
                      ,TRAFFICCOP = NULL
                FROM   TASKDETAIL
                       JOIN LOC WITH (NOLOCK)
                            ON  (TASKDETAIL.TOLOC=LOC.LOC)
                WHERE  TASKDETAIL.taskdetailkey = @c_taskdetailkey AND
                       ISNULL(RTRIM(TASKDETAIL.TOLOC) ,'')<>'' AND
                       ISNULL(RTRIM(TASKDETAIL.LOGICALTOLOC) ,'') = ''

                UPDATE TASKDETAIL WITH (ROWLOCK)
                SET    LOGICALTOLOC = (
                           CASE
                                WHEN @b_isDiffFloor=1 THEN @c_FromOutLoc
                                ELSE TOLOC
                           END
                       )
                      ,TRAFFICCOP = NULL
                FROM   TASKDETAIL
                WHERE  TASKDETAIL.taskdetailkey = @c_taskdetailkey AND
                       ISNULL(RTRIM(TASKDETAIL.TOLOC) ,'')<>'' AND
                       ISNULL(RTRIM(TASKDETAIL.LOGICALTOLOC) ,'') = ''
            END
            
            IF @n_continue IN(1,2)  --NJOW01
            BEGIN
                IF @n_PendingMoveIn > 0 AND ISNULL(@c_Lot,'') <> '' AND ISNULL(@c_FromLoc,'') <> '' AND ISNULL(@c_ToLoc,'') <> '' 
                BEGIN
                  SET @n_Err = 0             --Wan03
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
                                                                                                                   
                  --SET @n_err = @@ERROR  -- (Wan02)                                                                             
                                                                                                                   
                  IF @n_err <> 0                                                                                   
                  BEGIN                                                                                            
                     SELECT @n_continue = 3
                           ,@n_err = 67994 
                     SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                            ':  Execute rdt.rdt_Putaway_PendingMoveIn Failed! (ntrTaskDetailAdd)'
                  END                                                                                              
                END               

                IF @n_QtyReplen > 0 AND ISNULL(@c_Lot,'') <> '' AND ISNULL(@c_FromLoc,'') <> '' 
                BEGIN
                  IF EXISTS(SELECT 1 FROM LOTXLOCXID (NOLOCK)                                                         
                            WHERE Lot = @c_Lot                                                                        
                            AND Loc = @c_FromLoc                                                                      
                            AND ID = @c_FromID)                                                                       
                  BEGIN                                                                                               
                      UPDATE LOTXLOCXID WITH (ROWLOCK)                                                                 
                      SET QtyReplen = QtyReplen + @n_QtyReplen                                                  
                     WHERE Lot = @c_Lot                                                                               
                     AND Loc = @c_FromLoc                                                                             
                     AND ID = @c_FromID                                                                               
                                                                                                                      
                     SET @n_err = @@ERROR                                                                             
                                                                                                                      
                     IF @n_err <> 0                                                                                   
                     BEGIN                                                                                            
                        SELECT @n_continue = 3
                              ,@n_err = 67993 
                        SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                               ':  Update LOTXLOCXID Failed! (ntrTaskDetailAdd)'
                     END                                                                                              
                  END                                                                                                 
                END
            END
        END -- WHILE 1=1
    END
    /* #INCLUDE <TRTASKDA2.SQL> */
    IF @n_continue=3 -- Error Occured - Process And Return
    BEGIN
        -- To support RDT - start
        EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

        IF @n_IsRDT=1
        BEGIN
            -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
            -- Instead we commit and raise an error back to parent, let the parent decide

            -- Commit until the level we begin with
            WHILE @@TRANCOUNT>@n_starttcnt
                  COMMIT TRAN

            -- Raise error with severity = 10, instead of the default severity 16.
            -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
            RAISERROR (@n_err ,10 ,1) WITH SETERROR

            -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
        END
        ELSE
        BEGIN
            IF @@TRANCOUNT=1 AND
               @@TRANCOUNT>=@n_starttcnt
            BEGIN
                ROLLBACK TRAN
            END
            ELSE
            BEGIN
                WHILE @@TRANCOUNT>@n_starttcnt
                BEGIN
                    COMMIT TRAN
                END
            END
            EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrTaskDetailAdd'
            RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
            RETURN
        END
    END
    ELSE
    BEGIN
        WHILE @@TRANCOUNT>@n_starttcnt
        BEGIN
            COMMIT TRAN
        END
        RETURN
    END
END

GO