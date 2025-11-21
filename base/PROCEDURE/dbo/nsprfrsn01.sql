SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspRFRSN01                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Ver.  Author     Purposes                               */
/* 27-01-2010   1.0   Vicky      Created                                */
/* 11-03-2010   1.1   Vicky      If ContinueProcessing = 1 Main SP      */
/*                               should update Task Status = 9 and not  */
/*                               update from here (Vicky01)             */
/* 25-03-2010   1.1   Vicky      Insert to Alert (Vicky02)              */
/* 20-07-2010   1.1   Vicky      RequestedTOLOC should get from TOLOC   */
/*                               (Vicky03)                              */
/* 07-09-2010   1.1   ChewKP     Enhance Supervisor Alert (ChewKP01)    */
/* 18-09-2010   1.1   ChewKP     Fixes for PA Task (ChewKP02)           */
/* 24-10-2010   1.1   TLTING     Performance Tune                       */
/* 13-12-2011   1.2   ChewKP     Generate CC Task when in Reason screen */
/*                               (ChewKP03)                             */
/* 29-06-2012   1.3   ChewKP     Revise Alert Message and CC Task       */
/*                               Generation (ChewKP04)                  */
/* 25-07-2012   1.4   ChewKP     Module Name for CCSV Task (ChewKP05)   */
/* 25-03-2013   1.5   Ung        SOS256104 Add ContProcNotUpdTaskStatus */
/* 28-05-2024   1.6   NLT013     FCR-229 - Increase the max length of   */
/*                               qty text box to 7 digit, and handle    */
/*                               the exception                          */
/************************************************************************/

CREATE PROC    [dbo].[nspRFRSN01]
               @c_sendDelimiter    NVARCHAR(1)
,              @c_ptcid            NVARCHAR(5)
,              @c_userid           NVARCHAR(18)
,              @c_taskId           NVARCHAR(10)
,              @c_databasename     NVARCHAR(30)
,              @c_appflag          NVARCHAR(5)
,              @c_recordType       NVARCHAR(2)
,              @c_server           NVARCHAR(30)
,              @c_ttm              NVARCHAR(5)
,              @c_taskdetailkey    NVARCHAR(10)
,              @c_fromloc          NVARCHAR(18)
,              @c_fromid           NVARCHAR(18)
,              @c_toloc            NVARCHAR(18)
,              @c_toid             NVARCHAR(18)
,              @n_qty              int
,              @c_packkey          NVARCHAR(10)
,              @c_uom              NVARCHAR(10)
,              @c_reasoncode       NVARCHAR(10)
,              @c_outstring        NVARCHAR(255)  OUTPUT
,              @b_Success          int        OUTPUT
,              @n_err              int        OUTPUT
,              @c_errmsg           NVARCHAR(250)  OUTPUT
,              @c_userposition     NVARCHAR(10) = ''
AS
BEGIN
 SET NOCOUNT ON
 SET ANSI_NULLS OFF
 SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SELECT @b_debug = 0

   DECLARE @n_continue  int,
           @n_starttcnt int, -- Holds the current transaction count
           @n_cnt       int, -- Holds @@ROWCOUNT after certain operations
           @n_err2      int  -- For Additional Error Detection

   DECLARE @c_retrec NVARCHAR(2) -- Return Record '01' = Success, '09' = Failure

   DECLARE @n_cqty       int,
           @n_returnrecs int

   -- (Vicky02) - Start
   DECLARE @c_AlertMessage NVARCHAR( 255),
           @c_Loadkey  NVARCHAR(10),
           @c_TaskType     NVARCHAR(10),
           @c_ModuleName   NVARCHAR(30)
   -- (Vicky02) - End

   SELECT @n_starttcnt = @@TRANCOUNT,
          @n_continue = 1,
          @b_success = 0,
          @n_err = 0,
          @c_errmsg = '',
          @n_err2 = 0,
          @n_cnt=0,
          @c_AlertMessage = '' -- (Vicky02)

   SELECT @c_retrec = '01'
   SELECT @n_returnrecs=1

   DECLARE @c_requestedsku     NVARCHAR(20),
           @n_requestedqty     int,
           @c_requestedlot     NVARCHAR(10),
           @c_requestedfromid  NVARCHAR(18),
           @c_requestedfromloc NVARCHAR(10),
           @c_requestedtoid    NVARCHAR(18),
           @c_requestedtoloc   NVARCHAR(10),
           @c_requestedwavekey NVARCHAR(10),
           @c_currentstatus    NVARCHAR(10),
           @c_StorerKey        NVARCHAR(15),
           @c_ToteNo           NVARCHAR(18), -- (ChewKP01)
           @c_UserKey          NVARCHAR(18), -- (ChewKP01)
           @c_CaseID           NVARCHAR(10), -- (ChewKP02)
           @c_DoCycleCount     NVARCHAR(1),  -- (ChewKP03)
           @c_TaskDetailKeyCC  NVARCHAR(10), -- (ChewKP03)
           @c_PickMethod       NVARCHAR(10), -- (ChewKP04)
           @c_CCKey            NVARCHAR(10)  -- (ChewKP04)

DECLARE @c_NewLineChar NVARCHAR(2)
SET @c_NewLineChar =  master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10) -- (ChewKP01)       


   /* #INCLUDE <SPTPA02_1.SQL> */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      SELECT @c_taskid = CONVERT(NVARCHAR(18), CONVERT(int,( RAND() * 2147483647)) )        
   END

  IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @c_requestedfromid  = FROMID,
             @c_requestedfromloc = FROMLOC,
             @c_requestedtoid  = TOID,
             --@c_requestedtoloc = Logicaltoloc, -- fbr028a - to retrieve from logicaltoloc
             @c_requestedtoloc = ToLOC, -- (Vicky03)
             @c_requestedwavekey = WAVEKEY,
             @c_currentstatus = Status,
             @c_StorerKey = StorerKey,
             @c_Loadkey = Loadkey, -- (Vicky02)
             @c_TaskType = TaskType, -- (VIcky02)
             @c_ToteNo   = DropID,  -- (ChewKP01)
             @c_Userkey  = UserKey,  -- (ChewKP01)
             @c_CaseID   = CaseID,   -- (ChewKP02)
             @c_requestedsku = SKU,   -- (ChewKP04)
             @c_PickMethod  = PickMethod -- (ChewKP04)
      FROM  TASKDETAIL WITH (NOLOCK)
      WHERE TASKDETAILKEY = @c_taskdetailkey
      IF @@ROWCOUNT = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 68675
         --SELECT @c_errmsg = 'NSQL' +CONVERT(NVARCHAR(5),@n_err)+ ' :Invalid TaskDetail Key'
         SELECT @c_errmsg = CONVERT(NVARCHAR(5),@n_err)+ ' InvldTskDetKey(nspRFRSN01)'
      END
   END


   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF @c_userposition = '2' -- (Vicky01)
      BEGIN
           IF @c_fromloc <> @c_requestedfromloc
           BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 68676
--               SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+ ' :Invalid From Loc!'
               SELECT @c_errmsg = CONVERT(NVARCHAR(5),@n_err)+ ' InvldFrmLoc(nspRFRSN01)'
           END
       END -- (Vicky01)
   END

   IF @n_continue=1 OR @n_continue=2
   BEGIN
     IF @c_userposition = '2' -- (Vicky01)
      BEGIN
          IF ISNULL(RTRIM(@c_requestedtoid), '') <> ''
          BEGIN
              IF @c_toid <> @c_requestedtoid AND ISNULL(RTRIM(@c_requestedtoid), '') <> ''
              BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 68677
--                  SELECT @c_errmsg = 'NSQL' +CONVERT(NVARCHAR(5),@n_err)+ ' :Invalid To ID!'
                  SELECT @c_errmsg = CONVERT(NVARCHAR(5),@n_err)+ ' InvldToID(nspRFRSN01)'
              END
           END
       END -- (Vicky01)
   END

   IF @n_continue=1 OR @n_continue=2
   BEGIN
     IF @c_userposition = '2' -- (Vicky01)
     BEGIN
          IF @c_toloc <> @c_requestedtoloc
          BEGIN
             SELECT @n_continue = 3
             SELECT @n_err = 68678
--             SELECT @c_errmsg = 'NSQL' +CONVERT(NVARCHAR(5),@n_err)+ ' :Invalid To Loc!'
   SELECT @c_errmsg = CONVERT(NVARCHAR(5),@n_err)+ ' InvldToLoc(nspRFRSN01)'
          END
     END -- (Vicky01)
   END

   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF @c_currentstatus = '9'
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 68679
--         SELECT @c_errmsg = 'NSQL' +CONVERT(NVARCHAR(5),@n_err)+ ' :Item Already Processed!'
         SELECT @c_errmsg = CONVERT(NVARCHAR(5),@n_err)+ ' ItemAlrdProc(nspRFRSN01)'
      END
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF ISNULL(RTRIM(@c_reasoncode), '') <> ''
      BEGIN
         -- (Vicky01) - Start
         IF @c_userposition <> ''
         BEGIN
           IF @c_userposition = '1'
           BEGIN
             IF NOT EXISTS (SELECT 1 FROM TaskManagerReason WITH (NOLOCK)
                            WHERE TaskManagerReasonKey = @c_reasoncode
                            AND ValidInFromLoc = '1')
             BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 68680
--               SELECT @c_errmsg = 'NSQL' +CONVERT(NVARCHAR(5),@n_err)+ ':Invalid ReasonCode!'
               SELECT @c_errmsg = CONVERT(NVARCHAR(5),@n_err)+ ' InvldRsnCode(nspRFRSN01)'
             END
           END
           ELSE IF @c_userposition = '2'
           BEGIN
             IF NOT EXISTS (SELECT 1 FROM TaskManagerReason WITH (NOLOCK)
                            WHERE TaskManagerReasonKey = @c_reasoncode
                            AND ValidInToLoc = '1')
             BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 68681
--               SELECT @c_errmsg = 'NSQL' +CONVERT(NVARCHAR(5),@n_err)+ ':Invalid ReasonCode!'
               SELECT @c_errmsg = CONVERT(NVARCHAR(5),@n_err)+ ' InvldRsnCode(nspRFRSN01)'
             END
           END
         END
         ELSE
         -- (Vicky01) - End
         BEGIN
             IF NOT EXISTS (SELECT 1 FROM TaskManagerReason WITH (NOLOCK)      
                            WHERE TaskManagerReasonKey = @c_reasoncode      
                            AND ValidInToLoc = '1')      
             BEGIN      
               SELECT @n_continue = 3      
               SELECT @n_err = 68682      
               SELECT @c_errmsg = CONVERT(NVARCHAR(5),@n_err)+ ' InvldRsnCode(nspRFRSN01)'      
             END      
         END  
 
      END      
   END      
      
   IF @n_continue = 1 or @n_continue = 2      
   BEGIN      
         -- (Vicky01) - Start      
         DECLARE @cContinueProcess NVARCHAR(1)      
         SET @cContinueProcess = ''      

         SELECT @cContinueProcess = ISNULL(RTRIM(ContinueProcessing),''),
                @c_DoCycleCount   = DoCycleCount   -- (ChewKP03)
         FROM TASKMANAGERREASON WITH (NOLOCK)      
         WHERE TaskManagerReasonKey = @c_reasoncode      
               
         IF @cContinueProcess <> '1'      
         BEGIN
            -- Get function ID
            DECLARE @nFunc INT
            SET @nFunc = 0
            SELECT @nFunc = Func FROM rdt.rdtMobRec WITH (NOLOCK) WHERE V_TaskDetailKey = @c_TaskDetailKey AND UserName = @c_UserKey
            
            -- Get RDT storer config
            DECLARE @cContProcNotUpdTaskStatus NVARCHAR(1)
            SET @cContProcNotUpdTaskStatus = rdt.rdtGetConfig( @nFunc, 'ContProcNotUpdTaskStatus', @c_StorerKey)
            
            BEGIN TRAN
            -- DO NOT PUT TRAFFICCOP HERE AS IT WILL SKIP THE UPDATE OF CORRESPONSE TASKDETAIL
            -- STATUS FROM TASKMANAGERREASON TABLE
            UPDATE TASKDETAIL WITH (ROWLOCK) SET 
                  Status = CASE WHEN @cContProcNotUpdTaskStatus = '1' THEN Status ELSE '9' END,
                  Reasonkey = CASE WHEN ISNULL(@c_reasoncode, '') = '' THEN Reasonkey ELSE @c_reasoncode END,
                  UserPosition = CASE WHEN @c_userposition <> '' THEN @c_userposition ELSE '2' END, -- (Vicky01)
                  EndTime = getdate(),
                  EditDate = getdate(),
                  EditWho = suser_sname()
             WHERE taskdetailkey = @c_taskdetailkey
             AND STATUS <> '9'
          END
          ELSE
          BEGIN
           BEGIN TRAN

                 UPDATE TASKDETAIL WITH (ROWLOCK)
                 SET Reasonkey = CASE WHEN ISNULL(@c_reasoncode, '') = '' THEN Reasonkey ELSE @c_reasoncode END,
                     UserPosition = CASE WHEN @c_userposition <> '' THEN @c_userposition ELSE '2' END, -- (Vicky01)
                     EndTime = getdate(),
                     EditDate = getdate(),
                     EditWho = suser_sname(),
                     Trafficcop = NULL
                WHERE taskdetailkey = @c_taskdetailkey
                AND STATUS <> '9'
         END
          -- (Vicky01) - End
                SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                IF @n_err <> 0
                BEGIN
                    SELECT @n_continue = 3
                    SELECT @n_err = 68683   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                    SELECT @c_errmsg= CONVERT(NVARCHAR(5),@n_err)+ ' Update Failed On Table TaskDetail(nspRFRSN01)'
                END

                IF @n_continue = 3
                BEGIN
                    ROLLBACK TRAN
                END
                ELSE
                BEGIN
                    COMMIT TRAN
                END

--       END

         -- (Vicky02) - Start
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' TaskDetailKey: ' + @c_taskdetailkey  +  @c_NewLineChar -- (ChewKP01)
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' TaskType: ' + @c_TaskType  + @c_NewLineChar -- (ChewKP01)
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ReasonCode: ' + @c_reasoncode + @c_NewLineChar -- (ChewKP01)
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' UserKey: ' + @c_UserKey + @c_NewLineChar -- (ChewKP01)

         IF @c_TaskType = 'PA'
         BEGIN
            SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' CaseID: ' + @c_CaseID + @c_NewLineChar -- (ChewKP02)
         END
         ELSE
         BEGIN
            SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ToteNo: ' + @c_ToteNo + @c_NewLineChar -- (ChewKP02)
         END


         IF ISNULL(RTRIM(@c_Loadkey), '') <> ''
         BEGIN
           SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' LoadKey: ' + @c_Loadkey  + @c_NewLineChar -- (ChewKP01)
         END

         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' QTY: ' + CAST(@n_qty AS NVARCHAR( 7))  + @c_NewLineChar -- (ChewKP01)
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' DateTime: ' + CONVERT(NVARCHAR,GETDATE(), 121)  + @c_NewLineChar -- (ChewKP01)      

         SELECT @c_ModuleName = CASE WHEN @c_TaskType = 'PA' THEN 'TMPA'
                                     WHEN @c_TaskType = 'PK' THEN 'TMPK'
                                     WHEN @c_TaskType = 'MV' THEN 'TMMV'
                                     WHEN @c_TaskType = 'CC' THEN 'TMCC'
                                     WHEN @c_TaskType = 'CCSV' THEN 'TMCCSV'         -- (ChewKP05)
                                     WHEN @c_TaskType = 'CCSUP' THEN 'TMCCSUP'       -- (ChewKP05)
                                     WHEN @c_TaskType = 'NMV' THEN 'TMNMV'
                                 ELSE 'nspRFRSN01' END

         -- Insert LOG Alert
         SELECT @b_Success = 1
-- (ChewKP04)
--         EXECUTE dbo.nspLogAlert
--          @c_ModuleName   = @c_ModuleName,
--          @c_AlertMessage = @c_AlertMessage,
--          @n_Severity     = 0,
--          @b_success      = @b_Success OUTPUT,
--          @n_err          = @n_Err OUTPUT,
--          @c_errmsg       = @c_Errmsg OUTPUT

         -- (ChewKP04)
         EXEC nspLogAlert
              @c_modulename       = @c_ModuleName
            , @c_AlertMessage     = @c_AlertMessage
            , @n_Severity         = '5'
            , @b_success          = @b_success     OUTPUT
            , @n_err              = @n_Err         --OUTPUT Commented by NLT013, it overrides the old error no, if the error was not 0, but no error happens while executing this SP, error no will be updated as 0
            , @c_errmsg           = @c_Errmsg      OUTPUT
            , @c_Activity	       = 'ReasonScn'
            , @c_Storerkey	       = @c_StorerKey
            , @c_SKU	             = @c_requestedsku
            , @c_UOM	             = ''
            , @c_UOMQty	          = ''
            , @c_Qty	             = @n_qty
            , @c_Lot	             = ''
            , @c_Loc	             = @c_requestedfromloc
            , @c_ID	             = @c_requestedfromid
            , @c_TaskDetailKey	 = @c_taskdetailkey
            , @c_UCCNo	          = ''

         IF NOT @b_Success = 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 68685 
            SELECT @c_errmsg= CONVERT(NVARCHAR(5),@n_err)+ ' Log alter failed(nspRFRSN01)'
         END
         -- (Vicky02) - End

         -- Generate Cycle count Task, when DoCycleCount options =  '1' -- (ChewKP03)
         IF ISNULL(RTRIM(@c_DoCycleCount),'') = '1'
         BEGIN

            IF (ISNULL(RTRIM(@c_TaskType),'') NOT IN ( 'CC' , 'CCSV', 'CCSUP'))
            BEGIN
               INSERT INTO TRACEINFO (Tracename , TimeIn, Step1 , Col1 )
               Values ( 'TMRSN', GETDATE(), 'TsKTYPE' , @c_TaskType )


                  EXECUTE dbo.nspg_getkey
                  'TaskDetailKey'
                  , 10
                  , @c_TaskDetailKeyCC OUTPUT
                  , @b_success OUTPUT
                  , @n_Err     --OUTPUT Commented by NLT013, it overrides the old error no, if the error was not 0, but no error happens while executing this SP, error no will be updated as 0
                  , @c_Errmsg OUTPUT

                  IF NOT @b_success = 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 68686
                     SELECT @c_errmsg= CONVERT(NVARCHAR(5),@n_err)+ ' GetKeyFailed(nspRFRSN01)'
                  END

                  EXECUTE nspg_getkey
      	         'CCKey'
      	         , 10
      	         , @c_CCKey OUTPUT
      	         , @b_success OUTPUT
      	         , @n_Err    --OUTPUT Commented by NLT013, it overrides the old error no, if the error was not 0, but no error happens while executing this SP, error no will be updated as 0
      	         , @c_Errmsg OUTPUT

                  IF NOT @b_success = 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 68687
                     SELECT @c_errmsg= CONVERT(NVARCHAR(5),@n_err)+ ' GetKeyFailed(nspRFRSN01)'
                  END

                  --BEGIN TRAN


                     INSERT INTO dbo.TaskDetail
                       (TaskDetailKey,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,Qty,FromLoc,LogicalFromLoc,FromID,ToLoc,LogicalToLoc
                       ,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide
                       ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber,ListKey,WaveKey,ReasonKey
                       ,Message01,Message02,Message03,RefTaskKey,LoadKey,AreaKey,DropID, SystemQty)
                        SELECT  @c_TaskDetailKeyCC,'CC',StorerKey,SKU,'','',0,0,FromLoc,LogicalFromLoc,'','',''
                       ,'','','SKU','0','','1','1','','',UserPosition,''
                       ,GetDATE(),GetDATE(),'nspRFRSN01',@c_CCKey,'','','','','',''
                       ,'','','',@c_taskdetailkey,'',AreaKey, '', 0
                        FROM dbo.TaskDetail WITH (NOLOCK)
                        WHERE Taskdetailkey = @c_taskdetailkey
                        AND Storerkey = @c_StorerKey

                     IF @@ERROR <> 0
                     BEGIN
                          SELECT @n_continue = 3
                          SELECT @n_err = 68684   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                          SELECT @c_errmsg= CONVERT(NVARCHAR(5),@n_err)+ 'InsTaskFailed'
                     END
      --               ELSE
      --               BEGIN
      --                  COMMIT TRAN
      --               END
            END


         END

   END -- @n_continue = 1 or @n_continue = 2

   IF @n_continue=3
   BEGIN
     IF @c_retrec='01'
     BEGIN
        SELECT @c_retrec='09', @c_appflag = 'RSN'
     END
   END
   ELSE
   BEGIN
     SELECT @c_retrec='01'
   END

  SELECT @c_outstring =  @c_ptcid      + @c_senddelimiter
  + RTRIM(@c_userid)           + @c_senddelimiter
  + RTRIM(@c_taskid)           + @c_senddelimiter
  + RTRIM(@c_databasename)     + @c_senddelimiter
  + RTRIM(@c_appflag)          + @c_senddelimiter
  + RTRIM(@c_retrec)           + @c_senddelimiter
  + RTRIM(@c_server)           + @c_senddelimiter
  + RTRIM(@c_errmsg)

  IF @c_ptcid <> 'RDT'
  BEGIN
    SELECT RTRIM(@c_outstring)
  END

  /* #INCLUDE <SPTPA02_2.SQL> */
  IF @n_continue=3  -- Error Occured - Process And Return
  BEGIN
      SELECT @b_success = 0
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
        IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
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
        execute nsp_logerror @n_err, @c_errmsg, 'nspRFRSN01'
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
        RETURN
     END
  END
  ELSE
  BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
  END

END


GO