SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: nspLPRTSK1                                          */  
/* Creation Date:                                                        */  
/* Copyright: IDS                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: Loadplan Task Release Strategy for IDSUS TITAN Project       */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* PVCS Version: 1.4                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/* 26-Feb-2010  Vicky    1.0  PROC area should not check MaxPallet       */  
/*                            (Vicky01)                                  */  
/* 27-Apr-2010  Vicky    1.1  Add configkey to turn on or off of Auto    */  
/*                            generate WCSLP interface (Vicky02)         */  
/* 07-May-2010  Vicky    1.2  Fixes on the update of unused location in  */  
/*                            LoadplanLaneDetail should be looking at    */  
/*                            the unused LocationCategory instead of     */  
/*                            location in Taskdetail (Vicky03)           */  
/* 26-May-2010  NJOW01   1.3  158203 - New Pick task detail insertion    */  
/*                            (OPK). if pickqty <= ctnpickqty            */  
/* 22-Jul-2010  NJOW02   1.3  182662-Fix system release OPK task without */  
/*                            any setup. Add zero qty checking           */  
/* 02-Aug-2010  NJOW03   1.3  185720 - direct to HVCP if 1 pick task more*/  
/*                            than 1 ship to or 1 PO                     */  
/* 04-Mar-2011  Leong    1.4  SOS# 205643 - Get StorerKey From PickDetail*/  
/* 15-Jul-2011  NJOW04   1.5  220637-OPK Cater for Non-BOM sku           */
/* 22-Aug-2011	NJOW05   1.6  210656-Option to select LP go to HVCP      */
/* 20-Mar-2012  ChewKP   1.7  SOS#239089 PND Checking by Facility        */
/*                            (ChewKP01)                                 */
/* 28-Mar-2012  NJOW06   1.8  238872-Allow to handle MULTI-STORER        */
/* 28-Oct-2012  NJOW07   1.9  314930 - Move process flag checking        */
/*                            to wrapper and move raiseerror to control  */
/*                            by wrapper                                 */
/*************************************************************************/  
  
CREATE PROC [dbo].[nspLPRTSK1]  
   @c_LoadKey     NVARCHAR(10),  
   @n_err         INT          OUTPUT,  
   @c_ErrMsg      NVARCHAR(250) OUTPUT,
   @c_Storerkey   NVARCHAR(15) = '' --NJOW06  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_continue       INT  
          ,@c_PickDetailKey  NVARCHAR(10)  
          ,@c_TaskDetailKey  NVARCHAR(10)  
          ,@c_pickloc        NVARCHAR(10)  
          ,@b_success        INT  
          ,@n_ShipTo         INT  
          ,@c_PickMethod     NVARCHAR(10)  
          ,@c_RefTaskKey     NVARCHAR(10)  
          ,@n_POCnt          INT  --NJOW03  
  
   DECLARE @n_cnt            INT  
  
   DECLARE @c_Sku            NVARCHAR(20)  
          ,@c_id             NVARCHAR(18)  
          ,@c_fromloc        NVARCHAR(10)  
          ,@c_toloc          NVARCHAR(10)  
          ,@c_PnDLocation    NVARCHAR(10)  
          ,@n_InWaitingList  INT  
          ,@n_SkuCnt         INT  
          ,@n_PickQty        INT  
          ,@c_Status         NVARCHAR(10)  
          --,@c_StorerKey      NVARCHAR(15)  --NJOW06
          ,@n_PalletQty      INT  
          ,@n_StartTranCnt   INT  
          ,@c_LaneType       NVARCHAR(20)  
          ,@c_Priority       NVARCHAR(10)  
          ,@c_PickTaskType   NVARCHAR(10) --NJOW01  
          ,@n_CtnPickQty     INT      --NJOW01  
          ,@c_ToId           NVARCHAR(18) --NJOW01  
          ,@c_Lot            NVARCHAR(10) --NJOW01  
          ,@c_MasterSku      NVARCHAR(20) --NJOW01  
          ,@n_BOMQty         INT      --NJOW01  
          ,@n_CaseCnt        INT      --NJOW01  
          ,@n_PickQtyCase    INT      --NJOW01  
          ,@c_DispatchPalletPickMethod NVARCHAR(10) --NJOW05
  
   SELECT @n_continue = 1  
         ,@n_err = 0  
         ,@c_ErrMsg = ''  
         
   DECLARE @c_Facility   NVARCHAR(5), 
           @c_authority  NVARCHAR(10),
           @c_autogenwcs NVARCHAR(10), -- (Vicky02)              
           @c_PrepackByBOM NVARCHAR(10) --NJOW04         
  
   SET @n_StartTranCnt = @@TRANCOUNT  

   --SET @c_StorerKey = '' -- SOS# 205643    --NJOW06
   SET @c_Facility = ''  
      
   SELECT TOP 1 @c_Facility = O.Facility, 
                --@c_StorerKey = O.StorerKey, --NJOW06
                @c_DispatchPalletPickMethod = ISNULL(lp.DispatchPalletPickMethod,'')  --NJOW05
   FROM LoadPlan lp WITH (NOLOCK)
   JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lp.Loadkey = lpd.Loadkey
   JOIN ORDERS o WITH (NOLOCK) ON o.OrderKey = lpd.OrderKey 
   WHERE lp.LoadKey = @c_LoadKey
   AND o.Storerkey = @c_Storerkey --NJOW06
   ORDER BY lpd.LoadLineNumber
  
   BEGIN TRAN  
  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
   	  /* --NJOW07
      IF EXISTS( SELECT 1 FROM LoadPlan WITH (NOLOCK)  
                 WHERE LoadKey = @c_LoadKey AND ProcessFlag = 'L' )  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81001  
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ': This Load is Currently Being Processed!'+' ( '+  
                            ' SQLSvr MESSAGE= '+ @c_ErrMsg + ' ) '  
      END       
      ELSE
      */  
      IF NOT EXISTS( SELECT 1 FROM PickDetail P WITH (NOLOCK)  
                     JOIN LoadPlanDetail LPD WITH (NOLOCK)  
                       ON  LPD.OrderKey = P.OrderKey  
                     JOIN ORDERS O WITH (NOLOCK)  
                       ON O.OrderKey = P.OrderKey  
                     JOIN LoadPlan LP WITH (NOLOCK)  
                       ON LP.LoadKey = LPD.LoadKey  
                     WHERE LPD.LoadKey = @c_LoadKey AND  
                           P.STATUS = '0' AND  
                           P.TaskDetailKey IS NULL) --AND
                           --O.Storerkey = @c_Storerkey ) --NJOW06
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81002  
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': No task to release'+' ( '+  
                            ' SQLSvr MESSAGE= '+ @c_ErrMsg + ' ) '  
         GOTO Quit_SP
      END  
  
      IF NOT EXISTS( SELECT 1 FROM LoadPlanLaneDetail LPLD WITH (NOLOCK)  
                      WHERE  LPLD.LoadKey = @c_LoadKey AND  
                      LPLD.LocationCategory = 'STAGING' )  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81014  
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': Staging lane must assign to Load when release task.'+' ( '+  
                            ' SQLSvr MESSAGE= '+ @c_ErrMsg + ' ) '  
         GOTO Quit_SP
      END  
   END  
   /*  --NJOW07
   ELSE  
   BEGIN 
         BEGIN TRAN  

         UPDATE LoadPlan  
         SET    PROCESSFLAG = 'L'  
         WHERE  LoadKey = @c_LoadKey  
         
  
         SELECT @n_err = @@ERROR  
         IF @n_err<>0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81003  
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ': Update of LoadPlan Failed (nspLPRTSK1)'+' ( '+  
                               ' SQLSvr MESSAGE= ' + @c_ErrMsg + ' ) '  
            ROLLBACK TRAN  
         END  
         ELSE  
         BEGIN  
            COMMIT TRAN  
         END 
   END  
   */ 
  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      SELECT @c_PickDetailKey = ''  
      SELECT @c_pickloc = ''  

      --NJOW04 
      SELECT @b_Success = 0
      EXECUTE nspGetRight 
              @c_Facility,  -- facility
              @c_StorerKey, -- Storerkey
              null,         -- Sku
              'PrepackByBOM',   -- Configkey
              @b_success      output,
              @c_PrepackByBOM output, 
              @n_err          output,
              @c_errmsg       output
  
      DECLARE C_PickTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT P.LOC  
              , P.ID  
              , COUNT (DISTINCT O.ConsigneeKey) AS ShipTo  
              , SUM (P.Qty) AS AllocatedQty  
              , LP.Priority  
              , COUNT (DISTINCT O.ExternOrderkey) AS POCnt  --NJOW03  
              , P.StorerKey -- SOS# 205643  
         FROM   PickDetail P WITH (NOLOCK)  
                JOIN LoadPlanDetail LPD WITH (NOLOCK)  
                     ON  LPD.OrderKey = P.OrderKey  
                JOIN ORDERS O WITH (NOLOCK)  
                     ON  O.OrderKey = P.OrderKey  
                JOIN LoadPlan LP WITH (NOLOCK)  
                     ON LP.LoadKey = LPD.LoadKey  
         WHERE  LPD.LoadKey = @c_LoadKey AND  
                P.STATUS='0' AND  
                P.TaskDetailKey IS NULL AND
                O.Storerkey = @c_Storerkey --NJ0W06                
         GROUP BY P.LOC  
                , P.ID  
                , LP.Priority  
                , P.StorerKey -- SOS# 205643  
  
      OPEN C_PickTask  
      FETCH NEXT FROM C_PickTask INTO @c_FromLoc, @c_ID, @n_ShipTo, @n_PickQty, @c_Priority, @n_POCnt, @c_StorerKey -- SOS# 205643
  
      WHILE (@@FETCH_STATUS<>-1)  
      BEGIN  
  
         SET @c_ToLoc = ''  
         SET @c_PickTaskType = 'PK' --NJOW01  
  
         SELECT TOP 1  
              --@c_StorerKey = StorerKey -- SOS# 205643  
                @n_SkuCnt = COUNT(DISTINCT Sku)  
               ,@c_Sku = MAX(Sku)  
               ,@n_PalletQty = SUM(Qty - QtyPicked)  
               ,@c_Lot = MAX(Lot)  --NJOW01  
         FROM   LOTxLOCxID LLI WITH (NOLOCK)  
         WHERE  LLI.ID = @c_ID  
         AND    LLI.StorerKey = @c_StorerKey -- SOS# 205643  
       --GROUP BY LLI.StorerKey              -- SOS# 205643  
  
         --NJOW01 Start  
         IF @c_PrepackByBOM = '1' --NJOW04
         BEGIN         	         
            SELECT @c_MasterSku = LA.LOTTABLE03  
            FROM LOTATTRIBUTE LA (NOLOCK)  
            WHERE LA.Lot = @c_Lot  
            
            IF (SELECT COUNT(1) FROM SKU (NOLOCK) WHERE SKU.Storerkey = @c_StorerKey AND SKU.Sku = @c_MasterSku) = 0  
            BEGIN  
               SET @c_MasterSku = @c_Sku  
            END  
            
            SELECT @n_BOMQty = ISNULL(SUM(Qty), 0)  
            FROM   BillOfMaterial WITH (NOLOCK)  
            WHERE  Storerkey = @c_Storerkey  
            AND    Sku = @c_MasterSku  
            
            SELECT @n_CaseCnt = ISNULL(MAX(PACK.CaseCnt),0)  
            FROM UPC WITH (NOLOCK) JOIN PACK WITH (NOLOCK) ON (UPC.Packkey = PACK.Packkey)  
            WHERE UPC.UOM = 'CS'  
            AND UPC.Storerkey = @c_Storerkey  
            AND UPC.Sku = @c_MasterSku  
         END
         BEGIN
            --NJOW04
            SET @c_mastersku = @c_SKU
            SET @n_BOMQty = 1

	  	  	  SELECT @n_CaseCnt = PACK.CaseCnt
	          FROM SKU (NOLOCK) 
	          JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
	          WHERE SKU.Storerkey = @c_Storerkey
	          AND SKU.Sku = @c_mastersku                      
         END
  
         SELECT @n_CtnPickQty = SKU.CtnPickQty  
         FROM SKU WITH (NOLOCK)  
         WHERE SKU.Sku = @c_MasterSku  
         AND SKU.StorerKey = @c_StorerKey  
  
         IF @n_CtnPickQty = 0  
         BEGIN  
            SELECT @n_CtnPickQty = STORER.CtnPickQty  
            FROM STORER WITH (NOLOCK)  
            WHERE STORER.StorerKey = @c_Storerkey  
         END  
  
         IF @n_BOMQty > 0 AND @n_CaseCnt > 0  
         BEGIN  
           SELECT @n_PickQtyCase = CEILING(@n_PickQty / (@n_BOMQty * @n_CaseCnt))   -- NJOW02  
         END  
         ELSE  
         BEGIN  
           SELECT @n_PickQtyCase = @n_PickQty  
         END  
  
         IF @n_CtnPickQty >= @n_PickQtyCase AND @n_PalletQty <> @n_PickQty AND @n_CtnPickQty > 0  --NJOW02  
         BEGIN  
            SET @c_PickTaskType = 'OPK'  
            SET @c_PnDLocation = ''  
            SET @c_Status = '0'  
         END  
         --NJOW01 End  
  
         IF @n_SkuCnt > 1  
         BEGIN  
            SET @n_SkuCnt = 1  
         END  
         ELSE  
         BEGIN  
            SET @c_Sku = ''  
         END  
  
         IF @n_PalletQty = @n_PickQty  
         BEGIN  
            SET @c_PickMethod = 'FP' -- Full Pallet  
         END  
         ELSE  
         BEGIN  
            SET @c_PickMethod = 'PP' -- Partial Pallet  
         END  
  
         -- Is Loadplan.UserDefine08 = 'Y' (Work Order)  
         -- Then go to VAS Location  
         IF @c_PickTaskType = 'PK'  --NJOW01  
         BEGIN  
            IF EXISTS( SELECT 1 FROM Loadplan WITH (NOLOCK)  
                       WHERE  LoadKey = @c_LoadKey AND  
                       ISNUMERIC(UserDefine10) = 1 ) --NJOW01
                       AND @c_DispatchPalletPickMethod <> '2' --NJOW05
            BEGIN  
               SET @c_LaneType = 'VAS'  
  
               SELECT TOP 1 @c_ToLoc = LOC  
               FROM   LoadPlanLaneDetail LPLD WITH (NOLOCK)  
               WHERE  LPLD.LoadKey = @c_LoadKey AND  
                      LPLD.LocationCategory = 'VAS'  
            END  
            ELSE  
            IF @n_ShipTo = 1 AND @n_POCnt = 1  -- 1 Ship to then go to processing area -NJOW03 1 PO  
               AND @c_DispatchPalletPickMethod <> '2' --NJOW05
            BEGIN  
               --SET @c_LaneType = 'Processing Area'  -- (ChewKP01)
               SET @c_LaneType = 'PROC'  -- (ChewKP01)
  
               SELECT TOP 1 @c_ToLoc = LPLD.LOC  
               FROM   LoadPlanLaneDetail LPLD WITH (NOLOCK)  
               LEFT OUTER JOIN ( SELECT LoadKey  
                                      , TOLOC  
                                      , COUNT(DISTINCT ToId) AS Pallets  
                                FROM   TaskDetail TD WITH (NOLOCK)  
                                WHERE  TD.LoadKey = @c_LoadKey AND  
                                       TD.SourceType = 'nspLPRTSK1'  
    														GROUP BY LoadKey, TOLOC  
                                ) AS TDL  
                                ON  TDL.LoadKey = LPLD.LoadKey  
               LEFT OUTER JOIN LOC L WITH (NOLOCK)  
                               ON  L.Loc = TDL.TOLOC  
               WHERE LPLD.LoadKey = @c_LoadKey AND  
                     LPLD.LocationCategory = 'PROC' --AND  
                    -- (TDL.Pallets<L.MaxPallet OR TDL.Pallets IS NULL) -- (Vicky01)  
            END  
            ELSE  
            BEGIN  
               SET @c_LaneType = 'HVCP'  
  
               SELECT TOP 1 @c_ToLoc = LPLD.LOC  
               FROM LoadPlanLaneDetail LPLD WITH (NOLOCK)  
               LEFT OUTER JOIN ( SELECT LoadKey  
                                      , TOLOC  
                                      , COUNT(DISTINCT TOID) AS Pallets  
                                FROM   TaskDetail TD WITH (NOLOCK)  
                                WHERE  TD.LoadKey = @c_LoadKey AND  
                                       TD.SourceType = 'nspLPRTSK1'  
                                GROUP BY LoadKey, TOLOC  
                               ) AS TDL  
                               ON  TDL.LoadKey = LPLD.LoadKey  
               LEFT OUTER JOIN LOC L WITH (NOLOCK)  
                            ON (L.Loc = TDL.TOLOC AND (TDL.Pallets < L.MaxPallet OR TDL.Pallets IS NULL)) -- (Vicky01)  
               WHERE LPLD.LoadKey = @c_LoadKey AND  
                     LPLD.LocationCategory = 'HVCP' --AND  
                   -- (TDL.Pallets<L.MaxPallet OR TDL.Pallets IS NULL)  
            END  
  
            IF ISNULL(RTRIM(@c_ToLoc),'') = ''  
            BEGIN  
                SELECT @n_continue = 3  
                SELECT @c_ErrMsg = CONVERT(CHAR(250) ,@n_err), @n_err = 81004  
                SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': No (' + @c_LaneType +  
                                   ') Lanes Assigned to Load, Generate Task Failed (nspLPRTSK1)'  
                GOTO Quit_SP
            END  
         END --@c_PickTaskType = 'PK'  
  
         -- INSERT Task from VNA to Pick & Drop Location  
         IF (@n_continue = 1 OR @n_continue = 2) AND @c_PickTaskType = 'PK' --NJOW01  
         BEGIN  
            SET @c_PnDLocation = ''  
            
            
            SELECT TOP 1 @c_PnDLocation = L.LOC  
            FROM   LOC L WITH (NOLOCK)  
            JOIN LOC FromLOC WITH (NOLOCK)  
               ON  FromLOC.LocAisle = L.LocAisle 
                   AND FromLOC.Facility = L.Facility --NJOW05 
            LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK)  
               ON  LLI.Loc = L.Loc  
            WHERE  L.LocationCategory IN ('PnD_Ctr' ,'PnD_Out') AND  
                   FromLOC.LOC = @c_fromloc  AND
                   L.Facility = @c_Facility -- (ChewKP01)
            GROUP BY  
                  CASE  
                     WHEN @c_LaneType = 'HVCP' AND L.LocationCategory='PnD_Ctr' THEN 1  
                     WHEN @c_LaneType = 'VAS'  AND L.LocationCategory='PnD_Ctr' THEN 1  
                     WHEN @c_LaneType = 'PROC' AND L.LocationCategory='PnD_Out' THEN 1  
                     ELSE 2  
                  END  
                , L.LOC  
                , L.LogicalLocation  
                , L.LocAisle  
            HAVING SUM(ISNULL(LLI.Qty ,0)+ISNULL(LLI.PendingMoveIN ,0))=0  
            ORDER BY  
                  L.LocAisle  
                , CASE  
                     WHEN @c_LaneType = 'HVCP' AND L.LocationCategory='PnD_Ctr' THEN 1  
                     WHEN @c_LaneType = 'VAS'  AND L.LocationCategory='PnD_Ctr' THEN 1  
                     WHEN @c_LaneType = 'PROC' AND L.LocationCategory='PnD_Out' THEN 1  
                     ELSE 2  
                  END  
                , L.LogicalLocation  
                , L.LOC  
  
             -- If No more Empty P&D Location, then just get 1st P&D Location  
             IF ISNULL(RTRIM(@c_PnDLocation),'') = ''  
             BEGIN  
               SELECT TOP 1 @c_PnDLocation = L.LOC  
               FROM LOC L WITH (NOLOCK)  
               JOIN LOC FromLOC WITH (NOLOCK)  
                 ON FromLOC.LocAisle = L.LocAisle  
                 AND FromLOC.Facility = L.Facility --NJOW05
               WHERE L.LocationCategory IN ('PnD_Ctr' ,'PnD_Out') AND  
                     FromLOC.LOC = @c_fromloc AND 
                     L.Facility = @c_Facility -- (ChewKP01)
               GROUP BY  
                     CASE  
                        WHEN @c_LaneType = 'HVCP' AND L.LocationCategory='PnD_Ctr' THEN 1  
                        WHEN @c_LaneType = 'VAS'  AND L.LocationCategory='PnD_Ctr' THEN 1  
                        WHEN @c_LaneType = 'PROC' AND L.LocationCategory='PnD_Out' THEN 1  
                        ELSE 2  
                     END  
                   , L.LOC  
                   , L.LogicalLocation  
                   , L.LocAisle  
               ORDER BY  
                     L.LocAisle  
                   , CASE  
                        WHEN @c_LaneType = 'HVCP' AND L.LocationCategory='PnD_Ctr' THEN 1  
                        WHEN @c_LaneType = 'VAS'  AND L.LocationCategory='PnD_Ctr' THEN 1  
                        WHEN @c_LaneType = 'PROC' AND L.LocationCategory='PnD_Out' THEN 1  
                        ELSE 2  
                     END  
                   , L.LogicalLocation  
                   , L.LOC  
  
               IF ISNULL(RTRIM(@c_PnDLocation) ,'') <> ''  
               BEGIN  
                  SET @n_InWaitingList = 1  
                  SET @c_Status = 'Q'  
               END  
               ELSE  
               BEGIN  
                  SET @c_Status = '0'  
               END  
            END  
            ELSE  
            BEGIN  
               SET @n_InWaitingList = 0  
               SET @c_Status = '0'  
            END  
         END  
  
         IF @n_continue = 1 OR @n_continue = 2  
         BEGIN  
            -- Create 2 Tasks. 1 to PnD location, another from PnD Location to the Final Destination  
            -- Insert into taskdetail Main  
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
               SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81005  
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ': Unable to Get TaskDetailKey (nspLPRTSK1)' +  
                                  ' ( ' + ' SQLSvr MESSAGE= '+ @c_ErrMsg + ' ) '  
               GOTO Quit_SP
            END  
            ELSE  
            BEGIN  
               IF @c_PickTaskType = 'OPK'  --NJOW01  
               BEGIN  
                  SET @c_ToId = ''  
               END  
               ELSE  
               BEGIN  
                  SET @c_ToId = @c_ID  
               END  
  
               INSERT TASKDETAIL  
                     ( TaskDetailKey  
                     , TaskType  
                     , Storerkey  
                     , Sku  
                     , Lot  
                     , UOM  
                     , UOMQty  
                     , Qty  
                     , FromLoc  
                     , FromID  
                     , ToLoc  
                     , ToId  
                     , SourceType  
                     , SourceKey  
                     , Caseid  
                     , Priority  
                     , SourcePriority  
                     , OrderKey  
                     , OrderLineNumber  
                     , PickDetailKey  
                     , PickMethod  
                     , STATUS  
                     , LoadKey )  
               VALUES (  
                      @c_TaskDetailKey  
                    , @c_PickTaskType  --NJOW01 PK/OPK  
                    , @c_Storerkey  
                    , @c_Sku  
                    , '' -- Lot,  
                    , '' -- UOM,  
                    , 0  -- UOMQty,  
                    , @n_PickQty  
                    , @c_fromloc  
                    , @c_id  
                    , @c_PnDLocation  
                    , @c_ToId  --NJOW01  
                    , 'nspLPRTSK1'  
                    , @c_LoadKey  
                    , '' -- Caseid  
                    , @c_Priority -- Priority  
            , '9'  
                    , '' -- Orderkey,  
                    , '' -- OrderLineNumber  
                    , '' -- PickDetailKey  
                    , @c_PickMethod  
                    , @c_Status  
                    , @c_LoadKey )  
  
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81006  
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': Insert Into TaskDetail Failed (nspLPRTSK1)' +  
                                     ' ( '+' SQLSvr MESSAGE= ' + @c_ErrMsg + ' ) '  
                  GOTO QUIT_SP  
               END  
  
               -- Update the Pickdetail TaskDetailKey  
               DECLARE CUR_PICKDETAILKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                  SELECT P.PickDetailKey FROM PickDetail P WITH (NOLOCK)  
                  JOIN LoadPlanDetail LPD WITH (NOLOCK)  
                     ON  LPD.OrderKey = P.OrderKey  
                  JOIN ORDERS O WITH (NOLOCK)  
                     ON  O.OrderKey = P.OrderKey  
                  WHERE  LPD.LoadKey = @c_LoadKey AND  
                     P.STATUS = '0' AND  
                     P.TaskDetailKey IS NULL AND  
                     P.LOC = @c_fromloc AND  
                     P.ID  = @c_id AND 
                     O.Storerkey = @c_Storerkey --NJOW06
  
               OPEN CUR_PICKDETAILKEY  
               FETCH NEXT FROM CUR_PICKDETAILKEY INTO @c_PickDetailKey  
  
               WHILE @@FETCH_STATUS <> -1  
               BEGIN  
                  UPDATE PICKDETAIL WITH (ROWLOCK)  
                  SET TaskDetailKey = @c_TaskDetailKey,  
                      TrafficCop = NULL  
                  WHERE PickDetailKey = @c_PickDetailKey  
  
                  FETCH NEXT FROM CUR_PICKDETAILKEY INTO @c_PickDetailKey  
               END  
               CLOSE CUR_PICKDETAILKEY  
               DEALLOCATE CUR_PICKDETAILKEY  
               -- End Update PickDetail  
  
               SET @c_RefTaskKey = @c_TaskDetailKey  
  
               IF (@n_continue=1 OR @n_continue=2) AND @c_PickTaskType = 'PK'  
               BEGIN  
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
                     SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81007  
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': Unable to Get TaskDetailKey (nspLPRTSK1)' +  
                                        ' ( '+' SQLSvr MESSAGE= ' + @c_ErrMsg + ' ) '  
                     GOTO Quit_SP
                  END  
                  ELSE  
                  BEGIN  
                     INSERT TASKDETAIL  
                           ( TaskDetailKey  
                           , TaskType  
                           , Storerkey  
                           , Sku  
                           , Lot  
                           , UOM  
                           , UOMQty  
                           , Qty  
                           , FromLoc  
                           , FromID  
                           , ToLoc  
                           , ToId  
                           , SourceType  
                           , SourceKey  
                           , CaseId  
                           , Priority  
                           , SourcePriority  
                           , OrderKey  
                           , OrderLineNumber  
                           , PickDetailKey  
                           , PickMethod  
                           , RefTaskKey  
                           , [Status]  
                           , LoadKey )  
                     VALUES  
                           ( @c_TaskDetailKey  
    , 'NMV'  
                           , @c_Storerkey  
                           , @c_Sku  
                           , ''  -- Lot,  
                           , ''  -- UOM,  
                           , 0   -- UOMQty,  
                           , @n_PickQty  
                           , @c_PnDLocation  
                           , @c_id  
                           , @c_toloc  
                           , @c_id  
                           , 'nspLPRTSK1'  
                           , @c_LoadKey  
                           , ''  -- Caseid,  
                           , @c_Priority  
                           , '9'  
                           , ''  -- Orderkey,  
                           , ''  -- OrderLineNumber  
                           , ''  -- PickDetailKey  
                           , @c_PickMethod  
                           , @c_RefTaskKey  
                           , 'W'  
                           , @c_LoadKey )  
  
                     SELECT @n_err = @@ERROR  
                     IF @n_err <> 0  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @c_ErrMsg = CONVERT(CHAR(250) ,@n_err), @n_err = 81008  
                        SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ': Insert Into TaskDetail Failed (nspLPRTSK1)' +  
                                           ' ( '+' SQLSvr MESSAGE= ' + @c_ErrMsg + ' ) '  
                        GOTO QUIT_SP  
                     END  
                  END  
               END  -- If continue  
            END -- insert into taskdetail  
         END-- Insert into taskdetail Main  
  
         FETCH NEXT FROM C_PickTask INTO @c_FromLoc, @c_ID, @n_ShipTo, @n_PickQty, @c_Priority, @n_POCnt, @c_StorerKey -- SOS# 205643  
      END -- WHILE 1=1  
      CLOSE C_PickTask  
      DEALLOCATE C_PickTask  
   END--**  
  
   IF NOT EXISTS(SELECT 1 FROM ORDERS (NOLOCK)
                 WHERE Storerkey NOT IN (SELECT Storerkey  
                                         FROM TASKDETAIL (NOLOCK)
                                         WHERE Loadkey = @c_Loadkey)
                 AND Loadkey = @c_Loadkey)
   BEGIN  --NJOW06
      -- Release Lane if No Task required to move to the Lane  
      -- (Vicky03) - Start  
      SELECT DISTINCT LOC.LocationCategory  
      INTO #TEMPLANE  
      FROM TaskDetail TD WITH (NOLOCK)  
      JOIN LOC WITH (NOLOCK) ON (LOC.LOC = TD.ToLOC)  
      WHERE TD.LoadKey = @c_LoadKey AND  
            TD.SourceType = 'nspLPRTSK1' AND  
            TD.[Status] NOT IN ('9' ,'S' ,'R')  
      
      IF @@rowcount > 0  
      BEGIN  
         UPDATE LoadPlanLaneDetail  
         SET [Status] = '9'  
         WHERE LoadKey = @c_LoadKey  
         AND   [Status] < '9'  
         AND   LocationCategory NOT IN (SELECT LocationCategory FROM #TEMPLANE)  
         AND   LocationCategory <> 'STAGING'  
      END  
      -- (Vicky03) - End  
   END
--Comment By (Vicky03) - Start  
/*  
    DECLARE CUR_RELEASE_LANE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
       SELECT DISTINCT LPLD.LOC  
       FROM   LoadPlanLaneDetail LPLD WITH (NOLOCK)  
       WHERE  LPLD.LoadKey = @c_LoadKey  
       AND    LPLD.[Status] < '9'  
       AND    LPLD.LocationCategory <> 'STAGING'  
  
    OPEN CUR_RELEASE_LANE  
  
    FETCH NEXT FROM CUR_RELEASE_LANE INTO @c_toloc  
  
  
    WHILE @@FETCH_STATUS <> -1  
    BEGIN  
  
  
       IF NOT EXISTS(SELECT 1  
                    FROM   TaskDetail TD WITH (NOLOCK)  
                    WHERE  TD.LoadKey = @c_LoadKey AND  
                           TD.SourceType = 'nspLPRTSK1' AND  
                           TD.[Status] NOT IN ('9' ,'S' ,'R') AND  
                           TD.ToLoc = @c_toloc)  
       BEGIN  
          UPDATE LoadPlanLaneDetail  
            SET [Status] = '9'  
          WHERE  LoadKey = @c_LoadKey  
          AND    [Status] < '9'  
          AND    LOC = @c_toloc  
       END  
  
       FETCH NEXT FROM CUR_RELEASE_LANE INTO @c_toloc  
    END  
    CLOSE CUR_RELEASE_LANE  
    DEALLOCATE CUR_RELEASE_LANE  
*/  
-- Comment By (Vicky03) - End  
  
   -- Trigger outbound IML for WCS  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      SELECT @b_success = 0  
  
      /*DECLARE @c_Facility   NVARCHAR(5),  
              @c_authority  NVARCHAR(10),  
              @c_AutoGenWCS NVARCHAR(10) -- (Vicky02)  
  
      SET @c_StorerKey = '' -- SOS# 205643  
      SET @c_Facility = ''  
  
      SELECT TOP 1 @c_Facility = O.Facility,  
                   @c_StorerKey = O.StorerKey  
      FROM LoadPlanDetail LPD WITH (NOLOCK)  
      JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey  
      WHERE LPD.LoadKey = @c_LoadKey  
      ORDER BY LPD.LoadLineNumber*/  
  
      -- (Vicky02) - Start  
      EXECUTE nspGetRight  
               @c_Facility,  -- facility  
               @c_StorerKey, -- Storerkey  
               NULL,         -- Sku  
               'AutoGenWCSLP',   -- Configkey  
               @b_success    OUTPUT,  
               @c_AutoGenWCS OUTPUT,  
               @n_err        OUTPUT,  
               @c_errmsg     OUTPUT  
  
      IF @c_AutoGenWCS = '1' AND @b_success = 1  
      BEGIN  
      -- (Vicky02) - End  
         EXECUTE nspGetRight  
                  @c_Facility,  -- facility  
                  @c_StorerKey, -- Storerkey  
                  NULL,         -- Sku  
                  'WMSWCSLP',   -- Configkey  
                  @b_success    OUTPUT,  
                  @c_authority  OUTPUT,  
                  @n_err        OUTPUT,  
                  @c_errmsg     OUTPUT  
  
         IF @c_authority = '1' AND @b_success = 1  
         BEGIN  
            EXEC dbo.ispGenTransmitLog3 'WMSWCSLP', @c_LoadKey, '' , '', ''  
               , @b_success OUTPUT  
               , @n_err OUTPUT  
               , @c_errmsg OUTPUT  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3  
               GOTO Quit_SP  
            END  
         END  
      END -- (Vicky02)  
   END  
  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      DECLARE @c_OrderKey           NVARCHAR(10),  
              @c_OrderPickHeaderKey NVARCHAR(10),  
              @c_LoadPickHeaderKey  NVARCHAR(10)  
  
      IF NOT EXISTS(SELECT 1 FROM PICKHEADER P WITH (NOLOCK) WHERE P.ExternOrderKey = @c_LoadKey  
                    AND P.OrderKey = '')  
      BEGIN  
         SELECT @b_success = 0  
  
         EXECUTE nspg_GetKey  
               'PICKSLIP',  
               9,  
               @c_LoadPickHeaderKey OUTPUT,  
               @b_success           OUTPUT,  
               @n_err               OUTPUT,  
               @c_errmsg            OUTPUT  
  
         SELECT @c_LoadPickHeaderKey = 'P' + @c_LoadPickHeaderKey  
  
         INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderkey, OrderKey, PickType, Zone, TrafficCop)  
         VALUES (@c_LoadPickHeaderKey, @c_LoadKey, '', '0', 'C', '')  
  
         SELECT @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81009  
            SELECT @c_ErrMsg = 'NSQL'+ CONVERT(CHAR(5), @n_err) + ': Insert Into PickHeader Failed (nspLPRTSK1)' +  
                               ' ( '+' SQLSvr MESSAGE= ' + @c_ErrMsg + ' ) '  
            GOTO Quit_SP  
         END  
      END  
  
      DECLARE Cur_OrderKey CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
         SELECT O.OrderKey  
         FROM LoadPlanDetail lpd WITH (NOLOCK)  
         JOIN ORDERS o WITH (NOLOCK) ON o.OrderKey = lpd.OrderKey  
         WHERE lpd.LoadKey = @c_LoadKey  
         AND o.Storerkey = @c_Storerkey --NJOW06
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
            VALUES (@c_OrderPickHeaderKey, @c_Loadkey, @c_OrderKey, '0', 'D', '')  
  
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81010  
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+ ': Insert Into PickHeader Failed (nspLPRTSK1)'+' ( ' +  
                                  ' SQLSvr MESSAGE='+@c_ErrMsg + ' ) '  
               GOTO Quit_SP  
            END  
  
            IF NOT EXISTS (SELECT 1 FROM PACKHEADER P WITH (NOLOCK)  
                           WHERE P.LoadKey = @c_LoadKey  
                             AND P.OrderKey = @c_OrderKey  
                             AND P.PickSlipNo = @c_OrderPickHeaderKey)  
            BEGIN  
               INSERT INTO PackHeader  
                  ( PickSlipNo,  
                    StorerKey,  
                    [Route],  
                    OrderKey,  
                    OrderRefNo,  
                    LoadKey,  
                    ConsigneeKey,  
                    [Status] )  
               VALUES  
                  ( @c_OrderPickHeaderKey,  
                    @c_StorerKey,  
                    '',  -- Route  
                    @c_OrderKey,  
                    '',  -- OrderRefNo  
                    @c_LoadKey,  
                    '',  -- ConsigneeKey,  
                    '0' )  
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81011  
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': Insert Into PackHeader Failed (nspLPRTSK1)'+' ( '+  
                                     ' SQLSvr MESSAGE=' + @c_ErrMsg + ' ) '  
                  GOTO Quit_SP  
               END  
            END  
  
            UPDATE PICKDETAIL  
               SET PickSlipNo = @c_OrderPickHeaderKey, TrafficCop = NULL  
            WHERE OrderKey = @c_OrderKey  
  
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81012  
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': Update PickDetail Failed (nspLPRTSK1)'+' ( '+  
                                  ' SQLSvr MESSAGE= ' + @c_ErrMsg + ' ) '  
               GOTO Quit_SP  
            END  
         END  
         FETCH NEXT FROM Cur_OrderKey INTO @c_OrderKey  
      END  
      CLOSE Cur_OrderKey  
      DEALLOCATE Cur_OrderKey  
   END  
  
   Quit_SP:  
  
   IF @n_continue = 3  
   BEGIN  
      IF @@TRANCOUNT > @n_StartTranCnt  
         ROLLBACK TRAN  
         /* --NJOW07
         EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'nspLPRTSK1'  
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
         */
   END  
   ELSE  
   BEGIN  
   /* --NJOW07
      UPDATE LoadPlan WITH (ROWLOCK)  
      SET    PROCESSFLAG = 'Y'  
      WHERE  LoadKey = @c_LoadKey  
        
      SELECT @n_err = @@ERROR  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81013  
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': Update of LoadPlan Failed (nspLPRTSK1)'+' ( ' +  
                            ' SQLSvr MESSAGE= ' + @c_ErrMsg + ' ) '  
      END  
      ELSE  
      BEGIN  
      */
         WHILE @@TRANCOUNT > @n_StartTranCnt  
            COMMIT TRAN  
      --END  
   END  
END


GO