SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: nspLPRTSK4                                          */
/* Creation Date: 23-Dec-2014                                            */
/* Copyright: LF                                                         */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: 327746 - PH - CPPI TM Pick Releasing Tasks                   */
/*                                                                       */
/* Called By:                                                            */
/*                                                                       */
/* PVCS Version: 1.5                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 09/06/2015   NJOW01   1.0  343924-group by pallet CBM                 */
/* 30/10/2015   NJOW02   1.1  move raiseerror to control by wrapper      */
/* 06/02/2018   Leong    1.2  INC0125972 - Bug Fix.                      */
/* 01-09-2022   Wan01    1.3  LFWM-3726 - PH -SCE Wave Release Validation*/
/*                            DevOps Combine Script                      */
/* 10-11-2022   Wan02    1.4  LFWM-3840-UAT Philippines Unilever Release */
/*                            Wave Validation (LPRELTASKWITHBOOKING)     */
/* 22-03-2023   WLChooi  1.5  WMS-21950 - Group By Lottable03 (WL01)     */
/*************************************************************************/
CREATE   PROC [dbo].[nspLPRTSK4]
   @c_LoadKey     NVARCHAR(10),
   @n_err         INT          OUTPUT,
   @c_ErrMsg      NVARCHAR(250) OUTPUT,
   @c_Storerkey   NVARCHAR(15) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_Sku NVARCHAR(20)
            ,@c_Lot NVARCHAR(10)
            ,@c_FromLoc NVARCHAR(10)
            ,@c_ToLoc NVARCHAR(10)
            ,@c_ID NVARCHAR(18)
            ,@n_Qty INT
            ,@c_PickMethod NVARCHAR(10)
            ,@c_Taskdetailkey NVARCHAR(10)
            ,@c_TaskType NVARCHAR(10)
            ,@c_UOM NVARCHAR(10)
            ,@c_AreaKey NVARCHAR(10)
            ,@dt_BookingDate DATETIME
            ,@c_Message01 NVARCHAR(20)
            ,@c_PickDetailKey NVARCHAR(10)
            ,@n_CBM_Limit DECIMAL(12,4) --NJOW01
            ,@n_TotalCBM DECIMAL(12,4) --NJOW01
            ,@n_CBMAvailable DECIMAL(12,4) --NJOW01
            ,@c_Svalue NVARCHAR(10) --NJOW01
            ,@c_Prev_AreaKey NVARCHAR(10) --NJOW01
            ,@c_TMGroupKey NVARCHAR(10)--NJOW01
            ,@c_TMGroupKey_Insert NVARCHAR(10)--NJOW01

   DECLARE  @n_continue       INT
           ,@b_success        INT
           ,@n_StartTranCnt   INT

   --(Wan01) - START
   DECLARE  @c_Facility             NVARCHAR(5)    = ''
         ,  @c_LPRelTaskWithBooking NVARCHAR(30)   = ''
         ,  @c_Option5_LPRelTaskWBk NVARCHAR(4000) = ''
         ,  @c_BkNoFromTMSShipment  NVARCHAR(10)   = 'N'
         ,  @n_BookingNo            INT            = 0
         ,  @c_Authority            NVARCHAR(30)   = ''   --WL01
         ,  @c_GroupkeyByAreaLot3   NVARCHAR(10)   = 'N'  --WL01
         ,  @c_Option5              NVARCHAR(4000) = ''   --WL01
         ,  @c_Lottable03           NVARCHAR(50)   = ''   --WL01
         ,  @c_PrevLottable03       NVARCHAR(50)   = ''   --WL01
   
   IF OBJECT_ID('tempdb..#BookLoad','u') IS NOT NULL
   BEGIN
      DROP TABLE #BookLoad;
   END    
    
   CREATE TABLE #BookLoad
      (  RowID       INT            IDENTITY(1,1)  PRIMARY KEY
      ,  LoadKey     NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  BookingNo   INT            NOT NULL DEFAULT(0)
      )

   SELECT @n_continue = 1 ,@n_err = 0 ,@c_ErrMsg = '', @b_Success = 1

   SET @n_StartTranCnt = @@TRANCOUNT

   --(Wan01) - START
   SELECT @c_Facility = lp.facility
         ,@n_BookingNo= ISNULL(lp.BookingNo,0)
   FROM dbo.LoadPlan AS lp
   WHERE lp.LoadKey = @c_LoadKey
   
   SELECT @c_LPRelTaskWithBooking = fgr.Authority
         ,@c_Option5_LPRelTaskWBk = fgr.Option5 
   FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '','LPRELTASKWITHBOOKING') AS fgr
   
   SELECT  @c_BkNoFromTMSShipment = dbo.fnc_GetParamValueFromString('@c_BkNoFromTMSShipment', @c_Option5_LPRelTaskWBk, @c_BkNoFromTMSShipment) 
   
   IF @c_LPRelTaskWithBooking = '1' AND @c_BkNoFromTMSShipment = 'Y'
   BEGIN
      INSERT INTO #BookLoad ( LoadKey, BookingNo )
      SELECT tto.Loadkey, ts.BookingNo
      FROM dbo.TMS_Shipment AS ts WITH (NOLOCK)
      JOIN dbo.TMS_ShipmentTransOrderLink AS tstol WITH (NOLOCK) ON tstol.ShipmentGID = ts.ShipmentGID
      JOIN dbo.TMS_TransportOrder AS tto WITH (NOLOCK) ON tto.ProvShipmentID = tstol.ProvShipmentID
      WHERE tto.Loadkey = @c_LoadKey
      GROUP BY tto.Loadkey, ts.BookingNo
   END
   ELSE
   BEGIN
      INSERT INTO #BookLoad ( LoadKey, BookingNo )
      VALUES ( @c_Loadkey, @n_BookingNo )
   END
   --(Wan01) - END  
      
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
        --Clear invalid taskdetailkey at pickdetail
      UPDATE PICKDETAIL WITH (ROWLOCK)
      SET Taskdetailkey = '',
          TrafficCop = NULL
      FROM ORDERS O (NOLOCK)
      JOIN PICKDETAIL ON O.Orderkey = PICKDETAIL.Orderkey
      LEFT JOIN TASKDETAIL TD (NOLOCK) ON PICKDETAIL.Taskdetailkey = TD.Taskdetailkey
      WHERE ISNULL(TD.Taskdetailkey,'') = ''
      AND O.Loadkey = @c_LoadKey
      AND O.Storerkey = @c_Storerkey

      IF NOT EXISTS( SELECT 1 FROM PickDetail P WITH (NOLOCK)
                     JOIN LoadPlanDetail LPD WITH (NOLOCK)
                       ON  LPD.OrderKey = P.OrderKey
                     JOIN ORDERS O WITH (NOLOCK)
                       ON O.OrderKey = P.OrderKey
                     JOIN LoadPlan LP WITH (NOLOCK)
                       ON LP.LoadKey = LPD.LoadKey
                     WHERE LPD.LoadKey = @c_LoadKey AND
                           P.STATUS = '0' AND
                           ISNULL(P.TaskDetailKey,'') = '')
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81002
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': No task to release'+' ( '+
                            ' SQLSvr MESSAGE= '+ @c_ErrMsg + ' ) '
         GOTO Quit_SP
      END
   END

   IF @c_LPRelTaskWithBooking = '1' AND (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      IF EXISTS (SELECT 1
                 FROM LOADPLAN (NOLOCK)
                 JOIN ORDERS (NOLOCK) ON LOADPLAN.Loadkey = ORDERS.Loadkey
                 --(Wan01) - START
                 --JOIN V_Storerconfig2 SC2 ON ORDERS.Storerkey = SC2.Storerkey AND SC2.Configkey = 'LPRELTASKWITHBOOKING' AND SC2.Svalue = '1'
                 LEFT OUTER JOIN #BookLoad AS bl ON bl.LoadKey = LoadPlan.LoadKey            --(Wan02) When No TMS_SHipment record
                 LEFT OUTER JOIN BOOKING_OUT BO (NOLOCK) ON bl.BookingNo = BO.BookingNo
                 --(Wan01) - END
                 --WHERE ISNULL(LOADPLAN.BookingNo,0) = 0
                 WHERE ISNULL(BO.FinalizeFlag,'') IN ('','N')  
                 AND LOADPLAN.Loadkey = @c_Loadkey
                 AND ORDERS.Storerkey = @c_Storerkey)
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err), @n_Err = 81003
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': This Load Has No Finalized Booking And Not Allow To Release'+' ( '+
                            ' SQLSvr MESSAGE= '+ @c_ErrMsg + ' ) '
         GOTO Quit_SP
      END
   END

   --NJOW01
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
        SELECT @n_CBM_Limit = 999999.9999

        SELECT TOP 1 @c_Svalue = SC.Svalue
        FROM ORDERS O (NOLOCK)
        JOIN STORERCONFIG SC (NOLOCK) ON (O.Facility = SC.Facility OR ISNULL(SC.Facility,'')='') AND O.Storerkey = SC.Storerkey
        AND SC.Configkey = 'RDT_CBMLim'
        AND O.Loadkey = @c_Loadkey
        ORDER BY SC.Facility DESC

        IF ISNUMERIC(@c_Svalue) = 1
        BEGIN
         SELECT @n_CBM_Limit = CONVERT(DECIMAL(12,4), @c_Svalue)
        END
   END

   --WL01 S
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      EXECUTE nspGetRight                                
         @c_Facility  = @c_Facility,                     
         @c_StorerKey = @c_StorerKey,                    
         @c_sku       = '',
         @c_ConfigKey = 'ReleasePickTaskCode',
         @b_Success   = @b_Success   OUTPUT,             
         @c_authority = @c_Authority OUTPUT,             
         @n_err       = @n_Err       OUTPUT,             
         @c_errmsg    = @c_Errmsg    OUTPUT,                           
         @c_Option5   = @c_Option5 OUTPUT
      
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81000
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ': Execute nspGetRight Failed (nspLPRTSK4)' +
                            ' ( ' + ' SQLSvr MESSAGE= '+ @c_ErrMsg + ' ) '
         GOTO Quit_SP
      END

      IF @c_Authority = 'nspLPRTSK4'
      BEGIN
         SELECT @c_GroupkeyByAreaLot3 = dbo.fnc_GetParamValueFromString('@c_GroupkeyByAreaLot3', @c_Option5, @c_GroupkeyByAreaLot3) 
      END
   END
   --WL01 E

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
       SELECT LLI.Storerkey, LLI.Loc, LLI.ID, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS QtyAvailable
       INTO #TMP_LOCXID
       FROM LOTXLOCXID LLI (NOLOCK)
       JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
       JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc --NJOW01
       AND LLI.Storerkey = @c_Storerkey
       AND LLI.Qty > 0
       --AND SL.LocationType NOT IN('PICK','CASE')
       AND LOC.LocationType NOT IN('PICK','CASE') --NJOW01
       GROUP BY LLI.Storerkey, LLI.Loc, LLI.ID

       SELECT PD.Storerkey, PD.Loc, PD.ID, LI.QtyAvailable AS LOCXID_QTYAVAILABLE,
              COUNT(DISTINCT PD.SKU) AS SkuCount, COUNT(DISTINCT PD.LOT) AS LotCount
       INTO #LOCXID_QTYAVAILABLE
       FROM LOADPLANDETAIL LD (NOLOCK)
       JOIN PICKDETAIL PD (NOLOCK) ON LD.Orderkey = PD.Orderkey
       JOIN #TMP_LOCXID LI (NOLOCK) ON PD.Storerkey = LI.Storerkey AND PD.Loc = LI.Loc AND PD.Id = LI.Id
       JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc
       JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc --NJOW01
       WHERE LD.Loadkey = @c_Loadkey
       AND PD.Storerkey = @c_Storerkey
       --AND SL.LocationType NOT IN('PICK','CASE')
       AND LOC.LocationType NOT IN('PICK','CASE') --NJOW01
       GROUP BY PD.Storerkey, PD.Loc, PD.ID, LI.QtyAvailable

       DECLARE cur_PickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, PD.UOM,
               --CASE WHEN ISNULL(LI.LOCXID_QTYAVAILABLE,0) <= 0 AND SL.LocationType NOT IN ('PICK','CASE') THEN
               CASE WHEN ISNULL(LI.LOCXID_QTYAVAILABLE,0) <= 0 AND LOC.LocationType NOT IN ('PICK','CASE') THEN  --NJOW01
                         'FP'
                    ELSE 'PP' END AS PickMethod,
               --CASE WHEN SL.LocationType NOT IN ('PICK','CASE') THEN
               CASE WHEN LOC.LocationType NOT IN ('PICK','CASE') THEN --NJOW01
                         'FPK'
                    ELSE 'FCP' END AS TaskType,
               MAX(O.Door) AS ToLoc,
               AD.Areakey, 
               BO.BookingDate,
               SUM(PD.Qty) * SKU.Stdcube AS TotalCBM,  --NJOW01
               CASE WHEN @c_GroupkeyByAreaLot3 = 'Y' THEN LA.Lottable03 ELSE '' END   --WL01
        FROM LOADPLAN L (NOLOCK)
        JOIN LOADPLANDETAIL LD (NOLOCK) ON L.Loadkey = LD.Loadkey
        JOIN ORDERS O (NOLOCK) ON LD.Orderkey = O.Orderkey
        JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
        JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc
        JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku --NJOW01
        JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
        --LEFT JOIN AREADETAIL AD (NOLOCK) ON LOC.Putawayzone = AD.Putawayzone
        OUTER APPLY (SELECT TOP 1 Areakey FROM AREADETAIL (NOLOCK) WHERE AREADETAIL.Putawayzone = LOC.Putawayzone ORDER BY AREADETAIL.Areakey) AD    
        LEFT JOIN #LOCXID_QTYAVAILABLE LI (NOLOCK) ON PD.Storerkey = LI.Storerkey AND PD.Loc = LI.Loc AND PD.Id = LI.Id
        LEFT JOIN #BookLoad AS bl ON bl.LoadKey = L.LoadKey                                              --(Wan01) 
        LEFT JOIN BOOKING_OUT BO (NOLOCK) ON bl.BookingNo = BO.BookingNo AND ISNULL(L.BookingNo,0) <> 0  --(Wan01)
        JOIN LOTATTRIBUTE LA (NOLOCK) ON LA.Lot = PD.Lot   --WL01
        WHERE L.Loadkey = @c_Loadkey
        AND O.Storerkey = @c_Storerkey
        AND ISNULL(PD.Taskdetailkey,'') = ''
        AND PD.Status = '0'
        GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM,
                 --CASE WHEN ISNULL(LI.LOCXID_QTYAVAILABLE,0) <= 0 AND SL.LocationType NOT IN ('PICK','CASE') THEN
                 CASE WHEN ISNULL(LI.LOCXID_QTYAVAILABLE,0) <= 0 AND LOC.LocationType NOT IN ('PICK','CASE') THEN  --NJOW01
                                  'FP'
                             ELSE 'PP' END,
                        --CASE WHEN SL.LocationType NOT IN ('PICK','CASE') THEN
                        CASE WHEN LOC.LocationType NOT IN ('PICK','CASE') THEN --NJOW01
                                  'FPK'
                             ELSE 'FCP' END,
                 BO.BookingDate, LOC.LogicalLocation, AD.Areakey,  
                 SKU.Stdcube, --NJOW01
                 CASE WHEN @c_GroupkeyByAreaLot3 = 'Y' THEN LA.Lottable03 ELSE '' END   --WL01
        ORDER BY PD.Storerkey, MAX(AD.Areakey), LOC.LogicalLocation, PD.Loc, PD.Sku, PD.Lot

        OPEN cur_PickDetail

        FETCH NEXT FROM cur_PickDetail INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM,
                                            @c_PickMethod, @c_TaskType, @c_ToLoc, @c_Areakey, @dt_BookingDate,
                                            @n_TotalCBM, @c_Lottable03 --NJOW01   --WL01

        SET @n_CBMAvailable = @n_CBM_Limit --NJOW01
        SET @c_Prev_Areakey = '*START*' --NJOW01

        WHILE @@FETCH_STATUS = 0
        BEGIN
          SELECT @c_Message01 = ISNULL(CONVERT(NVARCHAR, @dt_BookingDate,113),'')

           --NJOW01
           IF @c_TaskType = 'FCP'
           BEGIN
              IF @c_Areakey <> @c_Prev_Areakey OR @n_CBMAvailable < @n_TotalCBM
               OR (@c_Lottable03 <> @c_PrevLottable03 AND @c_GroupkeyByAreaLot3 = 'Y')   --WL01
              BEGIN
                 SELECT @n_CBMAvailable = @n_CBM_Limit

                 EXECUTE nspg_getkey
                 'TMGroupKey',
                 10,
                 @c_TMGroupKey    OUTPUT,
                 @b_success       OUTPUT,
                 @n_err           OUTPUT,
                 @c_ErrMsg        OUTPUT

                 IF NOT @b_success = 1
                 BEGIN
                    SELECT @n_continue = 3
                    SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81004
                    SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ': Unable to Get TMGroupKey (nspLPRTSK4)' +
                                       ' ( ' + ' SQLSvr MESSAGE= '+ @c_ErrMsg + ' ) '
                    GOTO Quit_SP
                 END
              END
              SELECT @n_CBMAvailable = @n_CBMAvailable - @n_TotalCBM
              SELECT @c_Prev_Areakey = @c_AreaKey
              SELECT @c_TMGroupKey_Insert = @c_TMGroupKey
              SELECT @c_PrevLottable03 = @c_Lottable03   --WL01
           END
           ELSE
              SELECT @c_TMGroupKey_Insert = ''

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
              SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ': Unable to Get TaskDetailKey (nspLPRTSK4)' +
                                 ' ( ' + ' SQLSvr MESSAGE= '+ @c_ErrMsg + ' ) '
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
                    , Caseid
                    , Priority
                    , SourcePriority
                    , OrderKey
                    , OrderLineNumber
                    , PickDetailKey
                    , PickMethod
                    , STATUS
                    , LoadKey
                    , Areakey
                    , Message01
                    , SystemQty
                    , GroupKey)  --NJOW01
              VALUES (
                     @c_TaskDetailKey
                   , @c_TaskType
                   , @c_Storerkey
                   , @c_Sku
                   , @c_Lot -- Lot,
                   , @c_UOM
                   , 0  -- UOMQty,
                   , @n_Qty
                   , @c_fromloc
                   , @c_ID
                   , @c_ToLoc
                   , @c_ID
                   , 'nspLPRTSK4' --SourceType
                   , @c_LoadKey  --SourceKey
                   , '' -- Caseid
                   , '5' -- Priority
                   , '9' -- SourcePriority
                   , '' -- Orderkey,
                   , '' -- OrderLineNumber
                   , '' -- PickDetailKey
                   , @c_PickMethod
                   , '0'  --Status
                   , @c_LoadKey
                   , @c_AreaKey
                   , @c_Message01
                   , @n_Qty
                   , @c_TMGroupKey_Insert)  --NJOW01

              SELECT @n_err = @@ERROR
              IF @n_err <> 0
              BEGIN
                 SELECT @n_continue = 3
                 SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81006
                 SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': Insert Into TaskDetail Failed (nspLPRTSK4)' +
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
                    ISNULL(P.TaskDetailKey,'') = '' AND
                    P.LOC = @c_fromloc AND
                    P.ID  = @c_id AND
                    P.Sku = @c_Sku AND
                    P.Lot = @c_Lot AND
                    O.Storerkey = @c_Storerkey
                    AND P.UOM = @c_UOM -- INC0125972

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

           END

           FETCH NEXT FROM cur_PickDetail INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM,
                                               @c_PickMethod, @c_TaskType, @c_ToLoc, @c_Areakey, @dt_BookingDate,
                                               @n_TotalCBM, @c_Lottable03 --NJOW01   --WL01
        END
        CLOSE cur_PickDetail
        DEALLOCATE cur_PickDetail
   END

   Quit_SP:

   /*  --NJOW02
   IF @n_continue = 3
   BEGIN
      --IF @@TRANCOUNT > @n_StartTranCnt
      --   ROLLBACK TRAN
         EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'nspLPRTSK4'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012

   END
   ELSE
   BEGIN
      UPDATE LoadPlan WITH (ROWLOCK)
      SET    PROCESSFLAG = 'Y'
      WHERE  LoadKey = @c_LoadKey

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 81013
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': Update of LoadPlan Failed (nspLPRTSK4)'+' ( ' +
                            ' SQLSvr MESSAGE= ' + @c_ErrMsg + ' ) '
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCnt
            COMMIT TRAN
      END
   END
   */
   IF @n_continue <> 3
   BEGIN
       WHILE @@TRANCOUNT > @n_StartTranCnt
          COMMIT TRAN
   END
END

GO