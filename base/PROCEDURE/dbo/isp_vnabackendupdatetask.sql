SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_VNABackendUpdateTask                            */
/* Creation Date: 22-Mar-2024                                            */
/* Copyright: MAERSK                                                     */
/* Written by: WLChooi                                                   */
/*                                                                       */
/* Purpose: UWP-16615 - Task Scheduler - create a backend DB job to      */
/*          synchronize the VNAIN and VNAOUT tasks                       */
/*                                                                       */
/* Called By:                                                            */
/*                                                                       */
/* GitHub Version: 1.2                                                   */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver.  Purposes                                   */
/* 21-Mar-2024  WLChooi 1.0   DevOps Combine Script                      */
/* 01-OCT-2024  Ansuman 1.1   UWP-20570: Create 1 VNAOUT Task for Replenishment if From 
                              & To Locations are in same Aisle           */
/* 29-OCT-2024  Wan01   1.2   UWP-26065[FCR-952][UL]VNAOUT Task priorities*/
/*                            based on a code list value                 */
/*************************************************************************/
CREATE   PROCEDURE [dbo].[isp_VNABackendUpdateTask] 
      @c_Storerkey NVARCHAR(15)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue  INT
         , @n_starttcnt INT -- Holds the current transaction count    
         , @n_debug     INT
         , @n_cnt       INT
         , @b_success   INT
         , @n_err       INT
         , @c_errmsg    NVARCHAR(255)

   SELECT @n_starttcnt = @@TRANCOUNT
        , @n_Continue = 1
        , @b_success = 0
        , @n_err = 0
        , @c_errmsg = N''
        , @n_cnt = 0

   DECLARE @c_UOM                NVARCHAR(10)
         , @c_Taskdetailkey      NVARCHAR(10)
         , @c_ToLoc              NVARCHAR(10)
         , @c_LogicalPNDLoc      NVARCHAR(10)
         , @c_Facility           NVARCHAR(5)
         , @c_LocAisle           NVARCHAR(10)
         , @c_ToLocAisle         NVARCHAR(10)                                       --Ansuman
         , @c_DeviceID           NVARCHAR(20)
         , @c_Status             NVARCHAR(10)
         , @c_PATaskType         NVARCHAR(10)
         , @c_ReplenPickTaskType NVARCHAR(10)
         , @c_PNDLoc             NVARCHAR(10)
         , @c_SourceType         NVARCHAR(10)
         , @c_DeviceProfileKey   NVARCHAR(10)
         , @n_PendingMoveIn      INT
         , @c_Lot                NVARCHAR(10)
         , @c_FromLoc            NVARCHAR(10)
         , @c_ID                 NVARCHAR(18)
         , @c_Sku                NVARCHAR(20)
         , @c_Message02          NVARCHAR(10)

         , @b_PA_Caller          BIT          = 0                                   --(Wan01)
         , @b_RPF_FPK_Caller     BIT          = 0                                   --(Wan01)
         , @c_TaskType           NVARCHAR(10) = ''                                  --(Wan01)
         , @c_Priority           NVARCHAR(10) = ''                                  --(Wan01)

   DECLARE @CUR_VNA              CURSOR                                             --(Wan01)

   SET @c_UOM = N'1'
   SET @c_Status = N'Q'
   SET @c_PATaskType = N'VNAIN'
   SET @c_ReplenPickTaskType = N'VNAOUT'
   SET @c_SourceType = N'ispRLWAV69'

   --(Wan01) - START
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      SET @CUR_VNA = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TD.TaskType
      FROM TaskDetail TD WITH (NOLOCK)
      LEFT OUTER JOIN CODELKUP CL (NOLOCK) ON  cl.ListName = 'ULTASKPRI'
                                           AND cl.Code = td.TaskType
                                           AND cl.Short <> '' 
                                           AND cl.Short IS NOT NULL
      WHERE TD.TaskType IN ( @c_PATaskType, @c_ReplenPickTaskType ) 
      AND TD.Storerkey = @c_Storerkey 
      AND TD.[Status] = @c_Status 
      GROUP BY TD.TaskType
           , CASE WHEN cl.ListName IS NOT NULL THEN cl.Short
                  WHEN cl.ListName IS NULL AND TD.TaskType = 'VNAIN'  THEN '99998'
                  WHEN cl.ListName IS NULL AND TD.TaskType = 'VNAOUT' THEN '99999'
                  END
      ORDER BY CASE WHEN cl.ListName IS NOT NULL THEN cl.Short
                    WHEN cl.ListName IS NULL AND TD.TaskType = 'VNAIN'  THEN '99998'
                    WHEN cl.ListName IS NULL AND TD.TaskType = 'VNAOUT' THEN '99999'
                    END

      OPEN @CUR_VNA

      FETCH NEXT FROM @CUR_VNA INTO @c_TaskType

      WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
      BEGIN
         IF @c_TaskType = @c_PATaskType
         BEGIN
            SET @b_PA_Caller = 1
            GOTO PA_TASK
            PA_CALLER:
         END
         ELSE IF @c_TaskType = @c_ReplenPickTaskType
         BEGIN
            SET @b_RPF_FPK_Caller = 1
            GOTO REPLENPICK_TASK
            RPF_FPK_CALLER:
         END
         FETCH NEXT FROM @CUR_VNA INTO @c_TaskType
      END
      CLOSE @CUR_VNA
      DEALLOCATE @CUR_VNA

      SET @n_Continue = 4
   END
   --(Wan01) - END
   
   --PA Task
   PA_TASK:                                                                         --(Wan01)
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      DECLARE CUR_PA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TD.TaskDetailKey
           , TD.ToLoc
           , L.LocAisle
           , L.Facility
      FROM TaskDetail TD WITH (NOLOCK)
      JOIN LOC L WITH (NOLOCK) ON L.Loc = TD.ToLoc
      WHERE TD.TaskType = @c_PATaskType 
      AND TD.Storerkey = @c_Storerkey 
      AND TD.[Status] = @c_Status 
      GROUP BY TD.TaskDetailKey
             , TD.ToLoc
             , L.LocAisle
             , L.Facility
      ORDER BY TD.TaskDetailKey
             , TD.ToLoc

      OPEN CUR_PA

      FETCH NEXT FROM CUR_PA
      INTO @c_Taskdetailkey
         , @c_ToLoc
         , @c_LocAisle
         , @c_Facility

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_DeviceID = N''
         SET @c_DeviceProfileKey = N''

         SELECT TOP 1 @c_DeviceID = DP.DeviceID
                    , @c_DeviceProfileKey = DP.DeviceProfileKey
         FROM DeviceProfile DP WITH (NOLOCK)
         JOIN LOC L WITH (NOLOCK) ON DP.Loc = L.Loc
         WHERE DP.DeviceType = 'VNATRUCK'
         AND   DP.[Status] = 'IDLE'
         AND   L.LocAisle = @c_LocAisle
         AND   L.Facility = @c_Facility

         IF ISNULL(@c_DeviceID, '') = ''
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_err = 83030
            SELECT @c_errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                               + N': Cannot find available VNA Device for PA Task. (isp_VNABackendUpdateTask)'
         END
         ELSE
         BEGIN
            SELECT @c_Message02 = TD.Message02 from TaskDetail TD WITH (NOLOCK) WHERE TD.TaskDetailKey = @c_Taskdetailkey;
            IF @c_Message02 = 'RP2'
            BEGIN
                UPDATE TaskDetail
                SET UserKey = LEFT(@c_DeviceID, 18)
                  , TrafficCop = NULL
                  , EditWho = SUSER_SNAME()
                  , EditDate = GETDATE()
                WHERE TaskDetailKey = @c_Taskdetailkey
            END
            ELSE
            BEGIN
               UPDATE TaskDetail
               SET UserKey = LEFT(@c_DeviceID, 18)
                 , Listkey = @c_Taskdetailkey
                 , TrafficCop = NULL
                 , EditWho = SUSER_SNAME()
                 , EditDate = GETDATE()
               WHERE TaskDetailKey = @c_Taskdetailkey
            END
            
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
            END

            --Trigger will reset Userkey if updating status to 0
            UPDATE TaskDetail
            SET [Status] = '0'
              , TrafficCop = NULL
              , EditWho = SUSER_SNAME()
              , EditDate = GETDATE()
            WHERE TaskDetailKey = @c_Taskdetailkey

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
            END

            UPDATE DeviceProfile
            SET [Status] = 'BUSY'
            WHERE DeviceProfileKey = @c_DeviceProfileKey

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
            END

            --Generate TL2
            EXEC dbo.ispGenTransmitLog2 @c_TableName = N'WSTSKMOVEVNA'
                                      , @c_Key1 = @c_Taskdetailkey
                                      , @c_Key2 = @c_DeviceID
                                      , @c_Key3 = @c_Storerkey
                                      , @c_TransmitBatch = N''
                                      , @b_Success = @b_Success OUTPUT
                                      , @n_err = @n_err OUTPUT
                                      , @c_errmsg = @c_errmsg OUTPUT

            IF @n_err <> 0
            BEGIN
               SET @n_Continue = 3
            END
         END

         FETCH NEXT FROM CUR_PA
         INTO @c_Taskdetailkey
            , @c_ToLoc
            , @c_LocAisle
            , @c_Facility
      END
      CLOSE CUR_PA
      DEALLOCATE CUR_PA

      IF @b_PA_Caller = 1 GOTO PA_CALLER                                            --(Wan01) 
   END
 
   --REPLEN & PICK Task
   --Message03 = RPF - REPLEN
   --Message03 - FPK - Pick
   REPLENPICK_TASK:                                                                 --(Wan01)
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      DECLARE CUR_REPLEN_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TD.TaskDetailKey
           , TD.Lot
           , TD.FromLoc
           , TD.FromID
           , TD.ToLoc
           , TD.SKU
           , L.LocAisle
           , L.Facility
           , TD.Qty
           , l2.LocAisle                                                            --Ansuman
      FROM TaskDetail TD WITH (NOLOCK)
      JOIN LOC L WITH (NOLOCK) ON L.Loc = TD.FromLoc
      JOIN LOC l2 WITH (NOLOCK) ON l2.Loc = TD.ToLoc                                --Ansuman
      WHERE TD.TaskType = @c_ReplenPickTaskType
      AND   TD.Storerkey = @c_Storerkey
      AND   TD.[Status] = @c_Status
      AND   TD.UOM = @c_UOM
      GROUP BY TD.TaskDetailKey
             , TD.Lot
             , TD.FromLoc
             , TD.FromID
             , TD.ToLoc
             , TD.SKU
             , L.LocAisle
             , L.Facility
             , TD.Qty
             , TD.[Priority]
             , l2.LocAisle                                                          --Ansuman
      ORDER BY TD.[Priority]
             , TD.TaskDetailKey

      OPEN CUR_REPLEN_PICK

      FETCH NEXT FROM CUR_REPLEN_PICK
      INTO @c_Taskdetailkey
         , @c_Lot
         , @c_FromLoc
         , @c_ID
         , @c_ToLoc
         , @c_Sku
         , @c_LocAisle
         , @c_Facility
         , @n_PendingMoveIn
         , @c_ToLocAisle                                                            --Ansuman

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_DeviceID = N''
         SET @c_PNDLoc = N''
         SET @c_LogicalPNDLoc = N''
         SET @c_DeviceProfileKey = N''

         SELECT TOP 1 @c_DeviceID = DP.DeviceID
                    , @c_DeviceProfileKey = DP.DeviceProfileKey
         FROM DeviceProfile DP WITH (NOLOCK)
         JOIN LOC L WITH (NOLOCK) ON DP.Loc = L.Loc
         WHERE DP.DeviceType = 'VNATRUCK'
         AND   DP.[Status] = 'IDLE'
         AND   L.LocAisle = @c_LocAisle
         AND   L.Facility = @c_Facility

         IF @c_LocAisle <> @c_ToLocAisle                                            --Ansuman
         BEGIN
            SELECT TOP 1 @c_PNDLoc = L.Loc
                       , @c_LogicalPNDLoc = L.LogicalLocation
            FROM LOC L WITH (NOLOCK)
            LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON LLI.Loc = L.Loc
            WHERE L.LocationType = 'PND' 
            AND L.LocAisle = @c_LocAisle 
            AND L.Facility = @c_Facility
            GROUP BY L.Loc, L.LogicalLocation
            HAVING SUM(ISNULL(LLI.Qty, 0) + ISNULL(LLI.PendingMoveIN, 0)) = 0
            ORDER BY L.Loc
         END

         IF ISNULL(@c_DeviceID, '') = ''
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_err = 83035
            SELECT @c_errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                               + N': Cannot find available VNA Device for task ' + @c_Taskdetailkey + '. (isp_VNABackendUpdateTask)'
         END
         ELSE IF ISNULL(@c_PNDLoc, '') = '' AND @c_LocAisle <> @c_ToLocAisle        --Ansuman
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_err = 83040
            SELECT @c_errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                               + N': Cannot find available PND Loc for task ' + @c_Taskdetailkey + '. (isp_VNABackendUpdateTask)'
         END
         ELSE
         BEGIN
            SELECT @c_Message02 = TD.Message02 from TaskDetail TD WITH (NOLOCK) WHERE TD.TaskDetailKey = @c_Taskdetailkey;
            IF @c_Message02 = 'RP2'
            BEGIN
                UPDATE TaskDetail
                SET UserKey = LEFT(@c_DeviceID, 18)
                      , TrafficCop = NULL
                      , EditWho = SUSER_SNAME()
                      , EditDate = GETDATE()
                WHERE TaskDetailKey = @c_Taskdetailkey
            END
            ELSE
            BEGIN
               UPDATE TaskDetail
               SET UserKey = LEFT(@c_DeviceID, 18)
                 , Listkey = @c_Taskdetailkey
                 , TrafficCop = NULL
                 , EditWho = SUSER_SNAME()
                 , EditDate = GETDATE()
               WHERE TaskDetailKey = @c_Taskdetailkey
            END

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
            END
            IF @c_LocAisle <> @c_ToLocAisle                                         --Ansuman
            BEGIN
               UPDATE TaskDetail
               SET ToLoc = @c_PNDLoc
                 , LogicalToLoc = @c_LogicalPNDLoc
                 , TransitLOC = @c_PNDLoc
                 --, PendingMoveIn = @n_PendingMoveIn
               WHERE TaskDetailKey = @c_Taskdetailkey

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
               END

               SET @n_Err = 0 
               EXEC rdt.rdt_Putaway_PendingMoveIn   
                      @cUserName = ''  
                     ,@cType = 'LOCK'  
                     ,@cFromLoc = @c_FromLOC  
                     ,@cFromID = @c_ID  
                     ,@cSuggestedLOC = @c_PNDLoc  
                     ,@cStorerKey = @c_Storerkey
                     ,@nErrNo = @n_Err OUTPUT  
                     ,@cErrMsg = @c_Errmsg OUTPUT  
                     ,@cSKU = @c_Sku  
                     ,@nPutawayQTY    = @n_PendingMoveIn  
                     ,@cFromLOT       = @c_Lot  
                     ,@cTaskDetailKey = @c_TaskdetailKey  
                     ,@nFunc = 0  
                     ,@nPABookingKey = 0  
                     ,@cMoveQTYAlloc = '1'  
                     ,@cMoveQTYReplen= '1'
                                                                                                                     
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
               END
            END                                                                     --Ansuman
            --Trigger will reset Userkey if updating status to 0
            UPDATE TaskDetail
            SET [Status] = '0'
              , TrafficCop = NULL
              , EditWho = SUSER_SNAME()
              , EditDate = GETDATE()
            WHERE TaskDetailKey = @c_Taskdetailkey

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
            END

            UPDATE DeviceProfile
            SET [Status] = 'BUSY'
            WHERE DeviceProfileKey = @c_DeviceProfileKey

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
            END

            --Generate TL2
            EXEC dbo.ispGenTransmitLog2 @c_TableName = N'WSTSKPICKVNA'
                                      , @c_Key1 = @c_Taskdetailkey
                                      , @c_Key2 = @c_DeviceID
                                      , @c_Key3 = @c_Storerkey
                                      , @c_TransmitBatch = N''
                                      , @b_Success = @b_Success OUTPUT
                                      , @n_err = @n_err OUTPUT
                                      , @c_errmsg = @c_errmsg OUTPUT
            IF @n_err <> 0
            BEGIN
               SET @n_Continue = 3
            END
         END

         FETCH NEXT FROM CUR_REPLEN_PICK
         INTO @c_Taskdetailkey
            , @c_Lot
            , @c_FromLoc
            , @c_ID
            , @c_ToLoc
            , @c_Sku
            , @c_LocAisle
            , @c_Facility
            , @n_PendingMoveIn
            , @c_ToLocAisle                                                            --Ansuman
      END
      CLOSE CUR_REPLEN_PICK
      DEALLOCATE CUR_REPLEN_PICK
      IF @b_RPF_FPK_Caller = 1 GOTO RPF_FPK_CALLER                                     --(Wan01)
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_PA') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_PA
      DEALLOCATE CUR_PA
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_REPLEN_PICK') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_REPLEN_PICK
      DEALLOCATE CUR_REPLEN_PICK
   END

   IF @n_Continue = 3 -- Error Occured - Process And Return    
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_VNABackendUpdateTask'
      RAISERROR(@c_errmsg, 16, 1) WITH SETERROR -- SQL2012    
      RETURN
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
END --sp end  

GO