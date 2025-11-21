SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: nspLPRTSK5                                          */
/* Creation Date:                                                        */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: Loadplan Task Release Strategy for Merlion Project           */
/*                                                                       */
/* Called By:                                                            */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 29-Oct-2014  Barnett  1.0  Initial Development                        */
/* 06-Mar-2015  Barnett  1.0  Added checking for SpecialHandling ='H'    */
/* 01-Apr-2015  Barnett  1.0  UPDATE PickDetail filter by Loadkey,       */
/*                            Orderkey, ID                               */
/* 05-May-2015  Barnett  1.0  Added Full Pallet sent to GTM Process.     */
/*                            - Dynamic Query Logic to allow user edit   */
/*                              the Query script in Codelkup             */
/* 05-May-2015  TKLIM    1.0  Fix ToLoc for Full Pallet callout          */
/* 14-JAN-2016  Barnett  1.1  Add Extra Check on PickDetail Check        */
/* 19-JAN-2016  Barnett  1.2  Exclude Those PickDetail Line without ID   */
/* 23-JAN-2016  Barnett  1.3  Only Release the Task Where Pallet In ASRS */
/*                            Location. None ASRS Location need to Manual*/
/*                            Pick, until user reallocate to new Pallet  */
/*                            then do another TaskRelease.               */
/* 26-MAY-2016  Leong         IN00049940 - TraceInfo (temp only).        */
/* 14-JUL-2016  Barnett  1.4  FBR - 373411 ASRS Picking Priority         */ 
/* 25-Apr-2017  TKLIM    1.4  Insert PickHeader for KPI report (TK01)    */
/*************************************************************************/

CREATE PROC [dbo].[nspLPRTSK5]
   @c_LoadKey     NVARCHAR(10),
   @n_err         INT            OUTPUT,
   @c_ErrMsg      NVARCHAR(250)  OUTPUT,
   @c_Storerkey   NVARCHAR(15)   = '' --NJOW06
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue                    INT
         , @c_PickDetailKey               NVARCHAR(10)
         , @c_TaskDetailKey               NVARCHAR(10)
         , @c_pickloc                     NVARCHAR(10)
         , @b_success                     INT
         , @b_Success1                    INT
         , @n_ShipTo                      INT
         , @c_PickMethod                  NVARCHAR(10)
         , @c_RefTaskKey                  NVARCHAR(10)
         , @n_POCnt                       INT  --NJOW03
         , @n_SourceType                  NVARCHAR(30)

   DECLARE @c_Facility                    NVARCHAR(5)
         , @c_authority                   NVARCHAR(10)

   DECLARE @c_Sku                         NVARCHAR(20)
         , @c_Id                          NVARCHAR(18)
         , @c_FromLoc                     NVARCHAR(10)
         , @c_Toloc                       NVARCHAR(10)
         , @c_FinalLoc                    NVARCHAR(10)
         , @c_PnDLocation                 NVARCHAR(10)
         , @n_InWaitingList               INT
         , @n_SkuCnt                      INT
         , @n_PickQty                     INT
         , @c_Status                      NVARCHAR(10)
         , @n_PalletQty                   INT
         , @n_StartTranCnt                INT
         , @c_LaneType                    NVARCHAR(20)
         , @c_Priority                    NVARCHAR(10)
         , @c_PickTaskType                NVARCHAR(10)   --NJOW01
         , @n_CtnPickQty                  INT            --NJOW01
         , @c_ToId                        NVARCHAR(18)   --NJOW01
         , @c_Lot                         NVARCHAR(10)   --NJOW01
         , @c_MasterSku                   NVARCHAR(20)   --NJOW01
         , @n_BOMQty                      INT            --NJOW01
         , @n_CaseCnt                     INT            --NJOW01
         , @n_PickQtyCase                 INT            --NJOW01
         , @c_DispatchPalletPickMethod    NVARCHAR(10)   --NJOW05
         , @c_OrderKey                    NVARCHAR(20)
         , @c_OrderPickHeaderKey          NVARCHAR(10)   --TK01

  DECLARE  @c_ExecStatements              NVARCHAR(4000)
         , @c_WhereClause                 NVARCHAR(4000)
         , @c_ExecArguments               NVARCHAR(4000)
         , @c_MessageName                 NVARCHAR(15)
         , @c_MessageType                 NVARCHAR(10)
         , @c_OrigMessageID               NVARCHAR(10)
         , @c_UD1                         NVARCHAR(20)
         , @c_UD2                         NVARCHAR(20)
         , @c_UD3                         NVARCHAR(20)
         , @c_SerialNo                    INT
         , @b_debug                       INT
         , @c_MessageGroup                NVARCHAR(20)
         , @c_SProcName                   NVARCHAR(100)

   DECLARE @c_GTMLoop                     NVARCHAR(10)
         , @c_GTMWS                       NVARCHAR(10)
         , @c_SUSR4                       NVARCHAR(18) -- IN00049940

   SET  @n_continue           = 1
   SET  @n_err                = 0
   SET  @c_ErrMsg             = ''
   SET  @b_Success1           = 0

   -- Default Parameter
   SET @c_ExecStatements      = ''
   SET @c_ExecArguments       = ''
   SET @c_MessageGroup        = 'WCS'
   SET @c_MessageName         = 'MOVE'
   SET @c_SProcName           = ''
   SET @c_OrigMessageID       = ''
   SET @c_FromLoc             = ''
   SET @c_ToLoc               = ''
   SET @c_Priority            = '' --373411
   SET @c_UD1                 = ''
   SET @c_UD2                 = ''
   SET @c_UD3                 = ''
   SET @c_TaskDetailKey       = ''
   SET @c_SerialNo            = ''
   SET @b_debug               = '0'
   SET @b_Success             = '1'
   SET @n_Err                 = '0'
   SET @c_ErrMsg              = ''
   SET @n_SourceType          = 'nspLPRTSK5'
   SET @c_Sku                 = ''
   SET @c_Lot                 =''
   SET @n_StartTranCnt        = @@TRANCOUNT
   SET @c_Facility            = ''

   -- Constant Variables
   Select @c_GTMLOOP = Loc FROM LOC WITH (NOLOCK) WHERE LocationCategory = 'ASRSGTM' and LocationGroup ='GTMLOOP'
   Select @c_GTMWS   = Loc FROM LOC WITH (NOLOCK) WHERE LocationCategory = 'ASRSGTM' and LocationGroup ='GTMWS'

   -----------
   BEGIN TRAN
   -----------
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN

   --Validate The Loadkey Status already release task or not.
   IF NOT EXISTS( SELECT 1 FROM PickDetail P WITH (NOLOCK)
                  JOIN LoadPlanDetail LPD WITH (NOLOCK)
                     ON  LPD.OrderKey = P.OrderKey
                  JOIN ORDERS O WITH (NOLOCK)
                     ON O.OrderKey = P.OrderKey
                  JOIN LoadPlan LP WITH (NOLOCK)
                     ON LP.LoadKey = LPD.LoadKey
                  WHERE LPD.LoadKey = @c_LoadKey AND
                        P.STATUS < '5' AND
                  ISNULL(RTRIM(P.TaskDetailKey), '') = '')

   BEGIN
      -- (barnett 1.1 Start)
      -- No More Task Release, but Pending task to Pick
      IF EXISTS (
                  SELECT 1
                  FROM PickDetail P WITH (NOLOCK)
                  JOIN LoadPlanDetail LPD WITH (NOLOCK) ON  LPD.OrderKey = P.OrderKey
                  JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = P.OrderKey
                  JOIN LoadPlan LP WITH (NOLOCK) ON LP.LoadKey = LPD.LoadKey
                  JOIN TaskDetail TD WITH (NOLOCK) ON TD.TaskDetailKey = P.TaskDetailKey AND TD.[Status] <>'9'  -- Non Complete Pick Task
                                                  AND TD.TaskType = 'ASRSPK'
                  WHERE LPD.LoadKey = @c_LoadKey AND P.STATUS < '5' AND ISNULL(RTRIM(P.TaskDetailKey), '') <> '')

      BEGIN
         SET @n_continue = 3
         SET @n_err = 81002
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': No New task to release, Pending Tasks For ASRS Picking '+ @n_SourceType +')'
         GOTO QUIT_SP
      END

      --If PickdetailCnt = Picked Record Cnt, All Task Picked.
      IF (
            (  SELECT COUNT(*)
               FROM PickDetail P WITH (NOLOCK)
               JOIN LoadPlanDetail LPD WITH (NOLOCK) ON  LPD.OrderKey = P.OrderKey
               JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = P.OrderKey
               JOIN LoadPlan LP WITH (NOLOCK) ON LP.LoadKey = LPD.LoadKey
               WHERE LPD.LoadKey = @c_LoadKey AND P.STATUS = '5'
            )  =
            (  SELECT COUNT(*)
               FROM PickDetail P WITH (NOLOCK)
               JOIN LoadPlanDetail LPD WITH (NOLOCK) ON  LPD.OrderKey = P.OrderKey
               JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = P.OrderKey
               JOIN LoadPlan LP WITH (NOLOCK) ON LP.LoadKey = LPD.LoadKey
               WHERE LPD.LoadKey = @c_LoadKey)
          )
      BEGIN
         SET @n_continue = 3
         SET @n_err = 81003
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': All Task Picked, No more task to release, '+ @n_SourceType +')'
         GOTO QUIT_SP
      END
      -- (barnett 1.1 End)


      SET @n_continue = 3
      SET @n_err = 81001
      SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': No more task to release, '+ @n_SourceType +')'
      GOTO QUIT_SP
   END

   --Create Cursor to loop PickDetail 1 by 1
   DECLARE C_PickTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT P.LOC
            , P.ID
            , COUNT (DISTINCT O.ConsigneeKey) AS ShipTo
            , SUM (P.Qty) AS AllocatedQty
          --  , isnull(LP.Priority, '5') AS 'Priority'
            , COUNT (DISTINCT O.ExternOrderkey) AS POCnt
            , P.OrderKey
            , P.StorerKey
      FROM  PickDetail P WITH (NOLOCK)
      JOIN  LoadPlanDetail LPD WITH (NOLOCK)
         ON LPD.OrderKey = P.OrderKey
      JOIN  ORDERS O WITH (NOLOCK)
         ON O.OrderKey = P.OrderKey
      JOIN  LoadPlan LP WITH (NOLOCK)
         ON LP.LoadKey = LPD.LoadKey
      JOIN  Loc Loc WITH (NOLOCK)
         ON Loc.Loc = P.Loc and Loc.LocationCategory ='ASRS'  -- Only Release the Task Where Pallet In ASRS Location. (BARNETT 1.3)
      WHERE LPD.LoadKey = @c_LoadKey AND
            P.STATUS < '5' AND
            ISNULL(RTRIM(P.TaskDetailKey), '') = ''
            AND P.ID <> ''  -- Exclude Those PickDetail Line without ID. (BARNETT 1.2)
          --AND O.Storerkey = @c_Storerkey
      GROUP BY P.LOC
             , P.ID
             , LP.Priority
             , P.StorerKey
             , P.OrderKey

   OPEN C_PickTask
   FETCH NEXT FROM C_PickTask INTO @c_FromLoc, @c_Id, @n_ShipTo, @n_PickQty, @n_POCnt, @c_OrderKey, @c_StorerKey

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      SELECT @c_TaskDetailKey = ''

      --Get Balance Qty On Pallet
      SELECT @n_PalletQty = sum(Qty)
      FROM  LOTxLOCxID WITH (NOLOCK)
      WHERE Loc = @c_FromLoc and ID = @c_Id
      GROUP BY  Loc, ID

      -- Full Pallet pick and move to Staging
      SELECT @c_Sku = Sku
      FROM  LOTxLOCxID WITH (NOLOCK)
      WHERE Loc = @c_FromLoc and ID =@c_Id

      -- IN00049940 (Start)
      SELECT @c_SUSR4 = ''
      SELECT @c_SUSR4 = ISNULL(RTRIM(SUSR4),'')
      FROM SKU WITH (NOLOCK)
      WHERE StorerKey = @c_StorerKey AND Sku = @c_Sku

      IF ISNULL(RTRIM(@c_SUSR4),'') <> ''
      BEGIN
         INSERT TraceInfo ( TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5
                           , Col1, Col2, Col3, Col4, Col5 )
         VALUES ( @n_SourceType, GETDATE(), @c_OrderKey, @c_StorerKey, @c_Sku, @c_SUSR4, @c_FromLoc
                , @c_Id, @n_PalletQty, @n_PickQty, SYSTEM_USER, '')
      END
      -- IN00049940 (End)

      -- Process the Full Pallet Pick First.
      IF @n_PalletQty = @n_PickQty
      BEGIN
         SET @c_PickMethod = 'PK' -- Full Pallet
         SET @c_PickTaskType ='ASRSMV' -- ASRS MOVE OutBound
         SELECT  @c_ToId = '', @c_Status = 'Q', @c_PnDLocation = '', @c_FinalLoc = '', @c_Sku = '', @c_WhereClause = ''

         -- TK01 - Fix ToLoc for Full Pallet callout - Start
         -- Get Staging Lane Info.
         -- SELECT @c_PnDLocation = LOC.Putawayzone, @c_FinalLoc = LPLD.Loc
         -- FROM LoadPlanLaneDetail  LPLD WITH (NOLOCK)
         -- JOIN LOC LOC WITH (NOLOCK) on LOC.LOC = LPLD.LOC AND LOC.LocationCategory ='STAGING'
         -- WHERE LPLD.LoadKey = @c_LoadKey AND LPLD.LocationCategory ='STAGING'

         SELECT @c_PnDLocation = PLOC.Loc, @c_FinalLoc = LPLD.Loc
         FROM LoadPlanLaneDetail  LPLD WITH (NOLOCK)
         JOIN LOC LLOC WITH (NOLOCK) ON LLOC.LOC = LPLD.LOC AND LLOC.LocationCategory ='STAGING'
         JOIN LOC PLOC WITH (NOLOCK) ON PLOC.PutawayZone = LLOC.PutawayZone AND PLOC.LocationCategory = 'ASRSOUTST'
         WHERE LPLD.LoadKey = @c_LoadKey
         -- TK01 - Fix ToLoc for Full Pallet callout - End

         -- Prepare The where Clause
         SELECT TOP 1 @c_WhereClause = ISNULL(Notes, '')
         FROM CODELKUP WITH (NOLOCK) WHERE ListName = N'ASRSFP2GTM' AND Storerkey = @c_Storerkey

         IF @c_WhereClause <> ''
         BEGIN
            SET @b_Success1 = 0

            --Prepare Base SQL script
            SELECT @c_ExecStatements = 'SELECT @b_Success1 = ''1''  FROM SKU SKU WITH (NOLOCK) WHERE SKU = @c_Sku AND SKU.Storerkey = @c_Storerkey ' + @c_WhereClause
            SET @c_ExecArguments = N'@c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @b_Success1 INT OUTPUT'

            EXECUTE sp_executesql @c_ExecStatements, @c_ExecArguments , @c_Storerkey, @c_Sku, @b_Success1 OUTPUT

            IF @b_Success1 = 1
            BEGIN
               SET @c_PickMethod = 'FP' -- Full Pallet
               SET @c_PickTaskType ='ASRSPK' -- sent to GTM
               SELECT  @c_ToId = '', @c_Status = 0, @c_PnDLocation = '', @c_FinalLoc = ''

               GOTO GetKey
            END
         END

         UPDATE P
         SET P.Status = '5'
         FROM PickDetail P
         JOIN LoadPlanDetail LPD WITH (NOLOCK) ON  LPD.OrderKey = P.OrderKey
         WHERE LPD.LoadKey = @c_LoadKey AND P.STATUS = '0' AND ISNULL(RTRIM(P.TaskDetailKey), '') = ''
         AND P.ID = @c_Id AND P.OrderKey = @c_OrderKey

         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 81004
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': Update PickDetail Failed '+ @n_SourceType +')'+' ( '+
                               ' SQLSvr MESSAGE= ' + @c_ErrMsg + ' ) '
            CLOSE C_PickTask
            DEALLOCATE C_PickTask

            GOTO Quit_SP
         END

         -- If without LoadPlanLane setting, Go for Pick and hold process.
         IF ISNULL(@c_PnDLocation ,'') ='' OR (SELECT 1 FROM Orders WITH (NOLOCK) WHERE OrderKey = @c_OrderKey AND SpecialHandling = 'H')=1
         BEGIN
            UPDATE ID WITH (ROWLOCK)
            SET PalletFlag = 'PACKNHOLD'
            WHERE ID = @c_Id

            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 81005
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': Update ID.PalletFlag Failed '+ @n_SourceType +')'+' ( '+
                                  ' SQLSvr MESSAGE= ' + @c_ErrMsg + ' ) '
               CLOSE C_PickTask
               DEALLOCATE C_PickTask

               GOTO Quit_SP
            END

            -- Pick And Hold no need create task Detail at this moment
            GOTO End_Cursor
         END
      END
      ELSE
      BEGIN
         SET @c_PickMethod = 'PP' -- Partial Pallet
         SET @c_PickTaskType ='ASRSPK'
         SELECT @c_ToId = '', @c_Status = '0', @c_PnDLocation = '', @c_FinalLoc = ''

      GetKey:
         -- send to GTM and then send back ASRS
         SET @c_PnDLocation = @c_GTMLOOP  -- P6200 = GTM Loop
         SET @c_FinalLoc = @c_GTMWS
      END

      --Get TaskDetailKey
      EXECUTE nspg_getkey
            'TaskDetailKey',
            10,
            @c_TaskDetailKey OUTPUT,
            @b_success       OUTPUT,
            @n_err           OUTPUT,
            @c_ErrMsg        OUTPUT

      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81006
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ': Unable to Get TaskDetailKey '+ @n_SourceType +')' +
                            ' ( ' + ' SQLSvr MESSAGE= '+ @c_ErrMsg + ' ) '
         CLOSE C_PickTask
         DEALLOCATE C_PickTask

         GOTO Quit_SP
      END

	    --(373411 BEGIN)
		SELECT @c_Priority = Short
		FROM CodeLKup (NOLOCK) WHERE ListName = 'DTPriority' AND Code = @c_PickTaskType


		IF ISNULL(@c_Priority,'') =''
		BEGIN
			SELECT @c_Priority = Short
			FROM CodeLKup (NOLOCK) WHERE ListName = 'DTPriority' AND Code = 'DEFAULT'

			IF ISNULL(@c_Priority,'') ='' SET @c_Priority = 5
		END 
		-- (373411 END)

      --Create TaskDetail
      INSERT TASKDETAIL ( TaskDetailKey  , TaskType  , Storerkey  , Sku  , Lot
                        , UOM  , UOMQty  , Qty  , FromLoc  , FromID  , ToLoc
                        , ToId  , SourceType  , SourceKey  , Caseid  , Priority  , SourcePriority
                        , OrderKey  , OrderLineNumber  , PickDetailKey  , PickMethod  , STATUS  , LoadKey
                        , FinalId, LogicalFromLoc, LogicalToLoc, StatusMsg, Holdkey, UserKey, UserPosition
                        , UserKeyOverRide, StartTime, EndTime, ListKey, WaveKey, ReasonKey
                        , Message01, Message02, Message03, AddDate, AddWho, EditDate, EditWho
                        , RefTaskKey, Areakey, DropId, TransitCount, TransitLoc, FinalLOC )
      SELECT  @c_TaskDetailKey  , @c_PickTaskType, @c_Storerkey, @c_Sku, @c_Lot
            , '', 0, 0, @c_FromLoc, @c_Id, @c_PnDLocation
            , '', @n_SourceType, @c_LoadKey, '', @c_Priority, @c_Priority
            , @c_OrderKey, '', '', @c_PickMethod, @c_Status, @c_LoadKey
            , '' , '' , '' , '' , '' , '' , ''
            , '' , GETDATE() , GETDATE() , '' , '' , ''
            , '' , '' , '' , GETDATE() , SYSTEM_USER , GETDATE() , SYSTEM_USER  --(TKLIM)
            , '' , '' , '' , '' , '' , @c_FinalLoc

      SELECT @n_err = @@ERROR

      IF @n_err<>0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err), @n_err = 81007
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+ ': Insert Into TaskDetail Failed '+ @n_SourceType +')'+
                            ' ( '+' SQLSvr MESSAGE='+@c_ErrMsg +' ) '
         CLOSE C_PickTask
         DEALLOCATE C_PickTask

         GOTO QUIT_SP
      END

      -- Update the TaskDetailKey to Pickdetail Table
      UPDATE PD WITH (ROWLOCK)
         SET TaskDetailKey = @c_TaskDetailKey
           , TrafficCop = NULL
      FROM PICKDETAIL PD
      JOIN LoadPlanDetail LPD WITH (NOLOCK) ON  LPD.OrderKey = PD.OrderKey
      WHERE  LPD.LoadKey = @c_LoadKey AND PD.ID = @c_Id AND PD.OrderKey = @c_OrderKey

      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err), @n_err = 81008
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+ ': Failed to Update TaskDetailKey to PickDetail Table '+ @n_SourceType +')' +
                            ' ( '+' SQLSvr MESSAGE='+@c_ErrMsg +' ) '
         CLOSE C_PickTask
         DEALLOCATE C_PickTask

         GOTO QUIT_SP
      END

      End_Cursor:
         FETCH NEXT FROM C_PickTask INTO @c_FromLoc, @c_Id, @n_ShipTo, @n_PickQty, @n_POCnt, @c_OrderKey, @c_StorerKey

      END -- WHILE 1=1
      CLOSE C_PickTask
      DEALLOCATE C_PickTask
   END


   --TK01 - Insert PickHeader (Start)
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  

      DECLARE Cur_OrderKey CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
         SELECT O.OrderKey  
         FROM LoadPlanDetail lpd WITH (NOLOCK)  
         JOIN ORDERS o WITH (NOLOCK) ON o.OrderKey = lpd.OrderKey  
         WHERE lpd.LoadKey = @c_LoadKey  
         AND o.Storerkey = @c_Storerkey
         ORDER BY lpd.LoadLineNumber  
  
      OPEN Cur_OrderKey  
  
      FETCH NEXT FROM Cur_OrderKey INTO @c_OrderKey  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         IF NOT EXISTS(SELECT 1 FROM PICKHEADER p WITH (NOLOCK) WHERE p.ExternOrderKey = @c_LoadKey  
                        AND p.OrderKey = @c_OrderKey)  
         BEGIN  
            EXECUTE nspg_GetKey  
                     'PICKSLIP',  
                     9,  
                     @c_OrderPickHeaderKey OUTPUT,  
                     @b_success            OUTPUT,  
                     @n_err                OUTPUT,  
                     @c_errmsg             OUTPUT  
  
            SELECT @c_OrderPickHeaderKey = 'P' + @c_OrderPickHeaderKey  
  
            INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderkey, Orderkey, PickType, Zone, TrafficCop)  
            VALUES (@c_OrderPickHeaderKey, @c_Loadkey, @c_OrderKey, '0', '3', '')  
  
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81010  
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+ ': Insert Into PickHeader Failed (nspLPRTSK5)'+' ( ' +  
                                    ' SQLSvr MESSAGE='+@c_ErrMsg + ' ) '  
               GOTO Quit_SP  
            END  
  
         END  
         FETCH NEXT FROM Cur_OrderKey INTO @c_OrderKey  
      END  
      CLOSE Cur_OrderKey  
      DEALLOCATE Cur_OrderKey  
   END
   --TK01 - Insert PickHeader (End)


   Quit_SP:
   IF @n_continue = 3
   BEGIN
      IF @@TRANCOUNT > @n_StartTranCnt
      ROLLBACK TRAN
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, @n_SourceType
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      -- Release the LoadPlan.
      UPDATE LoadPlan WITH (ROWLOCK)
      SET    PROCESSFLAG = 'Y'
      WHERE  LoadKey = @c_LoadKey

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 81010
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': Update of LoadPlan Failed '+ @n_SourceType +')'
         GOTO Quit_SP
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCnt
            COMMIT TRAN
      END
   END
END

GO