SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispRLTRF01                                                  */
/* Creation Date: 19-Nov-2014                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Release Transfer Task;                                      */
/*        : SOS#315609 - Project Merlion - Transfer Release Task        */
/* Called By: Release Transfer Task                                     */
/*          : isp_ReleaseTransfer_Wrapper                               */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver Purposes                                    */
/* 28-Jan-2016  Wan01   1.1 Additional checking.SOS#367388              */
/* 28-Jan-2016  Wan02   1.1 To Outbound Lane.SOS#315609                 */
/* 08-Apr-2016  Wan03   1.2 Fixed - commit line by line                 */
/* 11-Apr-2016  Wan04   1.2 Fixed - update full pallet task status to Q */
/*                          After Finalized                             */
/* 27-JUL-2016  Barnett 1.4 FBR - 373411 ASRS Picking Priority (BL01)   */
/************************************************************************/
CREATE PROC [dbo].[ispRLTRF01] 
            @c_TransferKey NVARCHAR(10)
         ,  @b_Success     INT = 0  OUTPUT 
         ,  @n_err         INT = 0  OUTPUT 
         ,  @c_errmsg      NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 

         , @c_ReasonCode         NVARCHAR(10)
         , @c_Remarks            NVARCHAR(200)

         , @c_TransferLineNumber NVARCHAR(5)
         , @c_FromStorerkey      NVARCHAR(15)
         , @c_FromID             NVARCHAR(18)
         , @c_FromLoc            NVARCHAR(10)
         , @n_FromQty            INT
         , @n_Qty                INT

         , @c_TaskdetailKey      NVARCHAR(10)
         , @c_ToLoc              NVARCHAR(10)
         , @c_FinalLoc           NVARCHAR(10)   
         , @c_LogicalFromLoc     NVARCHAR(18)   
         , @c_LogicalToLoc       NVARCHAR(18) 
         
         , @c_Status             NVARCHAR(10)
         , @c_IDStatus           NVARCHAR(10)
         , @c_PalletFlag         NVARCHAR(30)

         , @c_MessageName        NVARCHAR(15)
         , @c_MessageType        NVARCHAR(10)
         
         , @c_OutboundLane       NVARCHAR(10)         --(Wan02)
         , @c_TaskType           NVARCHAR(10)         --(Wan02)
         , @c_PickMethod         NVARCHAR(10)         --(Wan02)

         , @b_callout            INT                  --(Wan03)
		 , @c_Priority           NVARCHAR(10)		  --(BL01)
                      
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   SET @b_callout  = 1                                --(Wan03)

   IF NOT EXISTS ( SELECT 1
                   FROM TRANSFERDETAIL TFD WITH (NOLOCK)
                   WHERE TFD.TransferKey = @c_Transferkey 
                   AND Status IN ('0', '5')
                 )
   BEGIN
--      SET @n_Continue = 3
      SET @n_err = 61000
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': All ID tasks had been released. (ispRLTRF01)'
      GOTO QUIT 
   END 

   -- Lottable06 to tolottable06 must not be same if type = 'DP' -- Duty payment
   IF EXISTS ( SELECT 1
               FROM TRANSFER WITH (NOLOCK)
               JOIN TRANSFERDETAIL WITH (NOLOCK) ON (TRANSFER.TransferKey = TRANSFERDETAIL.TransferKey)
               WHERE TRANSFER.TransferKey = @c_Transferkey 
               AND   TRANSFER.Type = 'DP'
               AND   TRANSFERDETAIL.Lottable06 = TRANSFERDETAIL.ToLottable06
            )
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 61001  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Transferring same Lottable06 found for Duty Payment'
                   +'.(ispRLTRF01)' 
      GOTO QUIT      
   END


   -- Invalid ID Qty
   IF EXISTS ( SELECT 1
               FROM TRANSFERDETAIL WITH (NOLOCK)
               WHERE TransferKey = @c_Transferkey 
               AND   FromQty <> ToQty
               AND   Status = '0'
            )
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 61005  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ID Transfer From Qty '
                   +'and To Qty are not tally (ispRLTRF01)' 
      GOTO QUIT      
   END

   -- Block release addition ID record that had been called out ( transferdetail.status <> '0' for the same ID)
   -- regardless of taskdetail status that had been released --24/Nov/2014
--   IF EXISTS ( SELECT 1 
--               FROM TRANSFERDETAIL TFD WITH (NOLOCK)
--               WHERE TFD.TransferKey = @c_Transferkey 
--               AND TFD.Status = '0'
--               AND EXISTS ( SELECT 1 
--                            FROM TRANSFERDETAIL WITH (NOLOCK)
--                            WHERE TransferKey = TFD.Transferkey
--                            AND   TransferLineNumber <> TFD.TransferLineNumber
--                            AND   FromLoc   = TFD.FromLoc
--                            AND   FromID    = TFD.FromID
--                            AND   Status    <> '0' )
--              ) 
   IF  EXISTS ( SELECT 1
                FROM TRANSFERDETAIL TFD WITH (NOLOCK)
                JOIN TASKDETAIL     TD  WITH (NOLOCK) ON  (TD.Sourcekey = TFD.TransferKey)
                                                      AND (TD.FromLoc   = TFD.FromLoc)
                                                      AND (TD.FromID    = TFD.FromID)
                WHERE TFD.TransferKey = @c_Transferkey
                AND   TFD.Status = '0'
                AND   TD.TaskType IN ('ASRSTRF', 'ASRSMV')      -- (Wan02)
                AND   TD.SourceType= 'ispRLTRF01'               -- (Wan02)
              )
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 61015
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ID had been called out. (ispRLTRF01)'
      GOTO QUIT       
   END
   
   --(Wan02) - START    
   IF EXISTS (SELECT 1
              FROM TRANSFER TF WITH (NOLOCK)
              WHERE TF.TransferKey = @c_Transferkey 
              AND   TF.Status < '9' 
              AND   TF.UserDefine01 <> '' AND TF.UserDefine01 IS NOT NULL 
              AND   NOT EXISTS(  SELECT 1
                                 FROM LOC  STG WITH (NOLOCK) 
                                 JOIN LOC  LOC WITH (NOLOCK) ON (STG.PutAwayZone = LOC.PutAwayZone)
                                 WHERE  STG.LOC = TF.UserDefine01   
                                 AND   STG.LocationCategory = 'STAGING'
                                 AND   LOC.LocationCategory = 'ASRSOUTST'
                              )
                  )
   BEGIN      
      SET @n_Continue = 3
      SET @n_err = 61017
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Outbound Lane. (ispRLTRF01)'
      GOTO QUIT 
   END
   --(Wan02) - END
 
   CREATE TABLE  #TFD
    ( Rowref   int not NULL Identity(1,1) Primary Key,
      FromLoc  NVARCHAR(10), FromID NVARCHAR(18), FromQty int) 

   --(Wan01) - START
   CREATE TABLE  #TSK
    ( Rowref   int not NULL Identity(1,1) Primary Key,
      FromID   NVARCHAR(18), FromQty int) 
   --(Wan01) - END

   INSERT INTO #TFD (FromLoc, FromID, FromQty)
   SELECT TFD.FromLoc, TFD.FromID, SUM(TFD.FromQty)
   FROM TRANSFERDETAIL TFD WITH (NOLOCK)
   WHERE TFD.TransferKey = @c_Transferkey 
   AND   TFD.Status < '9'  
   GROUP BY TFD.TransferKey
         ,  TFD.FromLoc
         ,  TFD.FromID

   --(Wan01) - START
   INSERT INTO #TSK (FromID, FromQty)
   SELECT TFD.FromID, ISNULL(SUM(TFD.FromQty),0)
   FROM #TFD
   JOIN TASKDETAIL TD ON (#TFD.FromID  = TD.FromID) 
   JOIN TRANSFERDETAIL TFD WITH (NOLOCK) ON (TD.Sourcekey = TFD.Transferkey)
                                         AND(TD.FromID = TFD.FromID)
   WHERE TD.TaskType IN ('ASRSTRF', 'ASRSMV')      -- (Wan02)
   AND   TD.Status < '9'
   AND   TD.SourceType= 'ispRLTRF01'               -- (Wan02)
   GROUP BY TFD.FromID 

   IF EXISTS ( SELECT 1
               FROM #TFD
               JOIN #TSK ON (#TFD.FromID = #TSK.FromID)
               JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (#TFD.FromID  = LLI.ID) 
               GROUP BY #TFD.FromID, #TFD.FromQty, #TSK.FromQty, LLI.ID
               HAVING (#TFD.FromQty + #TSK.FromQty) > ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked),0)
            )
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 61018   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': '
                  + ' Total Transfer ID Qty is greater then inventory ID Qty (ispRLTRF01)' 
      GOTO QUIT
   END
   --(Wan01) - END

   IF EXISTS ( SELECT 1
               FROM #TFD
               LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON (#TFD.FromLoc = LLI.Loc)
                                                      AND(#TFD.FromID  = LLI.ID) 
               GROUP BY #TFD.FromLoc,#TFD.FromID, #TFD.FromQty, LLI.Loc, LLI.ID 
               HAVING #TFD.FromQty > ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked),0)
            )
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 61020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': '
                  + ' Transfer ID Qty is greater then inventory ID Qty (ispRLTRF01)' 
      GOTO QUIT
   END

   IF NOT EXISTS ( SELECT 1
               FROM TRANSFERDETAIL TFD WITH (NOLOCK)
               WHERE TFD.TransferKey = @c_Transferkey 
               GROUP BY TFD.TransferKey
                     ,  TFD.FromLoc
                     ,  TFD.FromID
               HAVING EXISTS (SELECT 1 
                              FROM LOTxLOCxID LLI WITH (NOLOCK) 
                              WHERE (TFD.FromLoc = LLI.Loc)
                              AND   (TFD.FromID = LLI.ID) 
                              GROUP BY LLI.Loc, LLI.ID 
                              HAVING SUM(TFD.FromQty) <= SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked))
            )
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 61025
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No task to release. (ispRLTRF01)'
      GOTO QUIT 
   END 

   BEGIN TRAN
   DECLARE CUR_TRFDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT ReasonCode= ISNULL(TRANSFER.ReasonCode,'')
         ,Remarks   = ISNULL(TRANSFER.Remarks,'')
         ,TRANSFERDETAIL.FromStorerkey
         ,TRANSFERDETAIL.FromLoc
         ,TRANSFERDETAIL.FromID
         ,Qty = SUM(TRANSFERDETAIL.FromQty)
         ,OutboundLane = ISNULL(RTRIM(TRANSFER.UserDefine01),'')        --(Wan02)
   FROM TRANSFER WITH (NOLOCK)
   JOIN TRANSFERDETAIL WITH (NOLOCK) ON (TRANSFER.Transferkey = TRANSFERDETAIL.Transferkey)
   WHERE TRANSFER.Transferkey = @c_TransferKey
   AND   TRANSFERDETAIL.Status = '0'
   GROUP BY ISNULL(TRANSFER.ReasonCode,'')
         ,  ISNULL(TRANSFER.Remarks,'')
         ,  TRANSFERDETAIL.FromStorerkey
         ,  TRANSFERDETAIL.FromLoc
         ,  TRANSFERDETAIL.FromID
         ,  ISNULL(RTRIM(TRANSFER.UserDefine01),'')                     --(Wan02)
   OPEN CUR_TRFDET

   FETCH NEXT FROM CUR_TRFDET INTO @c_ReasonCode
                                 , @c_Remarks
                                 , @c_FromStorerkey
                                 , @c_FromLoc
                                 , @c_FromID
                                 , @n_FromQty
                                 , @c_OutboundLane                      --(Wan02)

   WHILE @@FETCH_STATUS <> -1 --AND @n_continue = 1                     --(Wan03)
   BEGIN
      SET @b_callout  = 1                                               --(Wan03)      
      SET @c_Status = '4'
      SET @n_Qty = 0

      SELECT @n_Qty = SUM(Qty - QtyAllocated - QtyPicked)
      FROM LOTxLOCxID WITH (NOLOCK)
      WHERE Loc = @c_FromLoc
      AND   ID  = @c_FromID 
      GROUP BY Loc, ID 
      -- FULL Pallet
      IF @n_Qty = @n_FromQty
      BEGIN
         SET @c_Status = '5'
         --(Wan02) - START
         IF @c_OutboundLane = ''
         BEGIN
            SET @b_callout = 0                                 --(Wan03)
            GOTO UPD_STATUS
         END
         --(Wan02) - END
      END

      -- ID release before
      IF EXISTS ( SELECT 1
                  FROM TASKDETAIL WITH (NOLOCK)
                  WHERE TaskType  IN ( 'ASRSTRF', 'ASRSMV' )   -- (Wan02) 
                  AND   Sourcekey = @c_TransferKey
                  AND   FromLoc   = @c_FromLoc
                  AND   FromID    = @c_FromID 
                  AND   SourceType= 'ispRLTRF01'               -- (Wan02)
                )
      BEGIN
         SET @b_callout = 0                                    --(Wan03)
         GOTO UPD_STATUS
      END

      --Update
      UPD_STATUS:

      BEGIN TRAN                                               --(Wan03)
      -- Update to detail status to indicate release task '4'
      -- Full pallet record status = '5'
      UPDATE TRANSFERDETAIL WITH (ROWLOCK)
      SET Status = @c_Status
         ,Trafficcop = NULL
         ,EditDate   = GETDATE()
         ,EditWho    = SUSER_NAME()
      WHERE Transferkey = @c_Transferkey
      AND   FromLoc = @c_FromLoc
      AND   FromID  = @c_FromID
 
      SET @n_err = @@ERROR   

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TRANFERDETAIL Failed. (ispRLTRF01)' 
         GOTO NEXT_DET  
      END 

      -- HOlD ID If ID originally not hold, update id.palletflag = 'TRFZUNHOLD' 
      -- IF ID is originallly HOLD, update id.palletflag = 'TRFZHOLD'
      -- Hold ID for all if there is partial id transfer otherwise not to hold
      IF @c_Status = '4'
      BEGIN
         SELECT @c_IDStatus = Status
               ,@c_PalletFlag =  ISNULL(RTRIM(PalletFlag),'')
         FROM ID WITH (NOLOCK)
         WHERE Id = @c_FromID   
            
         IF @c_PalletFlag = ''  
         BEGIN
            IF @c_IDStatus = 'HOLD'  -- HOLD ID IF It is Not HOLD 
            BEGIN
               SET @c_PalletFlag = 'TRFZHOLD'
            END
            ELSE
            BEGIN
               SET @c_PalletFlag = 'TRFZUNHOLD'
               -- Call InventoryHold SP to hold
               EXEC nspInventoryHoldWrapper
                  '',               -- lot
                  '',               -- loc
                  @c_fromid,        -- id
                  '',               -- storerkey
                  '',               -- sku
                  '',               -- lottable01
                  '',               -- lottable02
                  '',               -- lottable03
                  NULL,             -- lottable04
                  NULL,             -- lottable05
                  '',               -- lottable06
                  '',               -- lottable07    
                  '',               -- lottable08
                  '',               -- lottable09
                  '',               -- lottable10
                  '',               -- lottable11
                  '',               -- lottable12
                  NULL,             -- lottable13
                  NULL,             -- lottable14
                  NULL,             -- lottable15
                  'TRFHOLD',        -- status  
                  '1',              -- hold
                  @b_success OUTPUT,
                  @n_err OUTPUT,
                  @c_errmsg OUTPUT,
                  'Release Transfer Hold' -- remark

               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 61045
                  SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Hold ID Fail. (ispRLTRF01)' 
                                      + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '
                  GOTO NEXT_DET 
               END
            END
    
            UPDATE ID WITH (ROWLOCK)
            SET PalletFlag = @c_PalletFlag
               ,Trafficcop = NULL
               ,EditDate   = GETDATE()
               ,EditWho    = SUSER_NAME()
            WHERE Id = @c_FromID
            
            SET @n_err = @@ERROR   

            IF @n_err <> 0    
            BEGIN  
               SET @n_continue = 3    
               SET @n_err = 61050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update ID Failed. (ispRLTRF01)' 
               GOTO NEXT_DET  
            END 
         END 
      END

      --(Wan03) - START
      IF @b_callout = 0 
      BEGIN
         GOTO NEXT_DET
      END
      --(Wan03) - END


      -- Create Taskdetail

      SET @b_success = 1    
      EXECUTE   nspg_getkey    
               'TaskDetailKey'    
              , 10    
              , @c_TaskdetailKey OUTPUT    
              , @b_success       OUTPUT    
              , @n_err           OUTPUT    
              , @c_errmsg        OUTPUT 

      IF NOT @b_success = 1    
      BEGIN    
         SET @n_continue = 3    
         SET @n_err = 61030  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert TASKDETAIL Failed. (ispRLTRF01)' 
         GOTO NEXT_DET  
      END          

      SET @c_LogicalFromLoc = ''
      SELECT @c_LogicalFromLoc = ISNULL(LogicalLocation,'')  
      FROM LOC WITH (NOLOCK)
      WHERE ( Loc = @c_Fromloc )

      --(Wan02) - START
      SET @c_ToLoc = ''
      SET @c_LogicalToLoc = ''
      SET @c_FinalLoc = ''

      IF @c_Status = '4'
      BEGIN
         SET @c_TaskType = 'ASRSTRF' 
         SET @c_PickMethod = '' 
     
         SELECT @c_ToLoc = Loc  
              , @c_LogicalToLoc = ISNULL(LogicalLocation,'')
         FROM LOC WITH (NOLOCK)
         WHERE ( LocationCategory = 'ASRSGTM' And LocationGroup = 'GTMLOOP' )

         SELECT @c_FinalLoc = Loc 
         FROM LOC WITH (NOLOCK)
         WHERE ( LocationCategory = 'ASRSGTMWS' AND LocationGroup = 'GTMWS' )
      END
      ELSE IF @c_Status = '5'
      BEGIN 
         SET @c_TaskType = 'ASRSMV' 
         SET @c_PickMethod = 'MV'   
         SET @c_FinalLoc = @c_OutboundLane

         SELECT @c_ToLoc = LOC.Loc  
              , @c_LogicalToLoc = ISNULL(LOC.LogicalLocation,'')
         FROM LOC  STG WITH (NOLOCK) 
         JOIN LOC  LOC WITH (NOLOCK) ON (STG.PutAwayZone = LOC.PutAwayZone)
         WHERE STG.LOC = @c_FinalLoc 
         AND   STG.LocationCategory = 'STAGING'
         AND   LOC.LocationCategory = 'ASRSOUTST'
      END
      --(Wan02) - END

		--(BL01 BEGIN)
		SELECT @c_Priority = Short
		FROM CodeLKup (NOLOCK) WHERE ListName = 'DTPriority' AND Code = @c_TaskType


		IF ISNULL(@c_Priority,'') =''
		BEGIN
		SELECT @c_Priority = Short
		FROM CodeLKup (NOLOCK) WHERE ListName = 'DTPriority' AND Code = 'DEFAULT'

		IF ISNULL(@c_Priority,'') ='' SET @c_Priority = 5
		END 
		--(BL01 END)

      INSERT INTO TASKDETAIL    
         (    
            TaskDetailKey    
         ,  TaskType    
         ,  Storerkey    
         ,  Sku    
         ,  UOM    
         ,  UOMQty    
         ,  Qty    
         ,  SystemQty  
         ,  Lot    
         ,  FromLoc    
         ,  FromID    
         ,  ToLoc    
         ,  ToID 
         ,  LogicalFromLoc    
         ,  LogicalToLoc
         ,  FinalLoc
         ,  SourceType    
         ,  SourceKey 
         ,  PickMethod           --(Wan02)   
         ,  Priority    
         ,  [Status]
         ,  Message01            --ReasonKey
         ,  StatusMsg 
         )    
      VALUES    
         (    
            @c_Taskdetailkey    
         ,  @c_TaskType          -- Tasktype    
         ,  @c_FromStorerkey     -- Storerkey
         ,  ''                   -- Sku
         ,  ''                   -- UOM,    
         ,  0                    -- UOMQty
         ,  0                    -- SystemQty
         ,  0                    -- systemqty  
         ,  ''                   -- Lot
         ,  @c_Fromloc           -- from loc
         ,  @c_FromID            -- from id    
         ,  @c_ToLoc             -- To Loc
         ,  ''                   -- to id 
         ,  @c_LogicalfromLoc    -- Logical from loc    
         ,  @c_LogicalToLoc      -- Logical to loc 
         ,  @c_FinalLoc   
         ,  'ispRLTRF01'         -- Sourcetype    
         ,  @c_Transferkey       -- Sourcekey
         ,  @c_PickMethod        --(Wan02)   
         ,  @c_Priority          -- Priority    --(BL01)
         ,  '0'                  -- Status
         ,  @c_ReasonCode        -- ReasonCode
         ,  @c_Remarks           -- Remarks
         )  

      SET @n_err = @@ERROR   

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61035   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert TASKDETAIL Failed. (ispRLTRF01)' 
         GOTO NEXT_DET  
      END 

      -- (Wan04) - START
      IF @c_Status = '5'
      BEGIN
         GOTO NEXT_DET
      END 
      -- (Wan04) - END

      SET @c_MessageName  = 'MOVE'
      SET @c_MessageType  = 'SEND'

      EXEC isp_TCP_WCS_MsgProcess
               @c_MessageName  = @c_MessageName
            ,  @c_MessageType  = @c_MessageType
            ,  @c_PalletID     = @c_FromID
            ,  @c_FromLoc      = @c_FromLoc
            ,  @c_ToLoc	       = @c_ToLoc
            ,  @c_Priority	   = @c_Priority  --(BL01)
            ,  @c_TaskDetailKey= @c_Taskdetailkey
            ,  @b_Success      = @b_Success  OUTPUT
            ,  @n_Err          = @n_Err      OUTPUT
            ,  @c_ErrMsg       = @c_ErrMsg   OUTPUT
      
      IF @b_Success <> 1    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Execute isp_TCP_WCS_MsgProcess Failed. (ispRLTRF01)' 
                      + '( ' + @c_ErrMsg + ' )'
         GOTO NEXT_DET
      END 
 
      NEXT_DET:
      --(Wan03) - START

      IF @n_Continue=3
      BEGIN
         IF @@TRANCOUNT > 0
         BEGIN
            ROLLBACK TRAN
         END
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END   
      END
      SET @n_continue = 1                                      
      --(Wan03) - END

      FETCH NEXT FROM CUR_TRFDET INTO @c_ReasonCode
                                    , @c_Remarks
                                    , @c_FromStorerkey
                                    , @c_FromLoc
                                    , @c_FromID
                                    , @n_FromQty
                                    , @c_OutboundLane                      --(Wan02)
   END
   CLOSE CUR_TRFDET
   DEALLOCATE CUR_TRFDET

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      DECLARE CUR_TFD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TRANSFERDETAIL.TransferLineNumber
            ,TRANSFERDETAIL.FromID                                         --(Wan04)
            ,OutboundLane = ISNULL(RTRIM(TRANSFER.UserDefine01),'')        --(Wan04)
      FROM TRANSFER WITH (NOLOCK)                                          --(Wan04
      JOIN TRANSFERDETAIL WITH (NOLOCK) ON (TRANSFER.Transferkey = TRANSFERDETAIL.Transferkey)
      WHERE TRANSFERDETAIL.TransferKey = @c_TransferKey
      AND   TRANSFERDETAIL.Status = '5'

      OPEN CUR_TFD

      FETCH NEXT FROM CUR_TFD INTO  @c_TransferLineNumber 
                                  , @c_FromID                              --(Wan04) 
                                  , @c_OutboundLane                        --(Wan04)
                                  
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Finalized Full Pallet Tranfer ID
         EXEC ispFinalizeTransfer
               @c_Transferkey = @c_Transferkey
            ,  @b_Success     = @b_Success   OUTPUT 
            ,  @n_err         = @n_err       OUTPUT 
            ,  @c_errmsg      = @c_errmsg    OUTPUT
            ,  @c_TransferLineNumber = @c_TransferLineNumber

         IF @b_Success <> 1 
         BEGIN
            SET @n_continue = 3    
            SET @n_err = 61055  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Execute ispFinalizeTransfer Failed. (ispRLTRF01)' 
                         + @c_errmsg
            GOTO QUIT
         END

         IF @c_OutboundLane <> ''
         BEGIN
            UPDATE TASKDETAIL WITH (ROWLOCK)
            SET Status = 'Q'
              , Trafficcop = NULL
              , EditWho  = SUSER_NAME()
              , EditDate = GETDATE()
            WHERE TaskType = 'ASRSMV'
            AND   FromID = @c_FromID
            AND   Sourcekey = @c_Transferkey
            AND   Status = '0'

            SET @n_err = @@ERROR   

            IF @n_err <> 0    
            BEGIN  
               SET @n_continue = 3    
               SET @n_err = 61060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TASKDETAIL Failed. (ispRLTRF01)' 
               GOTO QUIT  
            END 
         END

         FETCH NEXT FROM CUR_TFD INTO  @c_TransferLineNumber
                                     , @c_FromID                           --(Wan04) 
                                     , @c_OutboundLane                     --(Wan04)
      END
      CLOSE CUR_TFD
      DEALLOCATE CUR_TFD
   END

QUIT:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_TRFDET') in (0 , 1)  
   BEGIN
      CLOSE CUR_TRFDET
      DEALLOCATE CUR_TRFDET
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_TFD') in (0 , 1)  
   BEGIN
      CLOSE CUR_TFD
      DEALLOCATE CUR_TFD
   END

   --(Wan03) - START
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END 
   --(Wan03) - END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLTRF01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      SET @c_errmsg = 'Tasks Released And Full Pallet Finalized'
   END
END -- procedure

GO