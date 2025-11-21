SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRLWAV01                                          */  
/* Creation Date: 28-Nov-2012                                            */  
/* Copyright: IDS                                                        */  
/* Written by: NJOW                                                      */  
/*                                                                       */  
/* Purpose: SOS#256796 - Release Replenishmnt Task                       */  
/*                                                                       */  
/* Called By: wave                                                       */  
/*                                                                       */  
/* PVCS Version: 2.6                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */  
/* 01-Nov-2013 NJOW01   1.0   Validate location cube include facility    */
/* 05-Nov-2013 Chee01   1.1   Insert RefKeyLookUp, Remove task generation*/
/*                            for Loc.LocationCategory = RESALE          */ 
/* 16-Dec-2013 NJOW02   1.2   DPP Loc with PICK Location type not allow  */
/*                            assign with other SKU                      */
/* 24-Jan-2014 Chee02   1.3   REMOVE filter SL.LocationType NOT IN       */
/*                            ('PICK','CASE') for Launch order           */ 
/* 24-Mar-2014 TLTING   1.4   SQL2012 Bug                                */
/* 28-Apr-2014 NJOW03   1.5   309316-Add release XDOCK staging to        */
/*                            induction move task                        */
/* 06-May-2014 NJOW04   1.6   Change listkey to message02                */
/* 29-May-2014 SPChin   1.7   SOS# 312500 - verify Sku.StdCube.          */
/* 15-Jan-2015 NJOW05   1.8   Fix empty location assign to include cube  */
/*                            occupied checking for those stock in       */
/*                            conveyer. (Retail/Wholesale)               */
/* 09-Jul-2015 NJOW06   1.9   343964-amend the logic                     */
/* 07-Sep-2015 NJOW07   2.0   343964-amend the logic to determine launch */
/*                             order pickmethod.                         */
/* 28-Mar-2016 NJOW08   2.1   367050-amend the logic to determine launch */
/*                            order pickmethod.                          */
/* 11-Aug-2016 TLTING01 2.2   Remove SET ROWCOUNT, Performance tune      */ 
/* 24-Aug-2016 NJOW09   2.3   Check Valid Loc when insert locxlocxid.    */
/*                            performance tuning.                        */
/* 13-Feb-2017 TLTING02 2.4   Performance tune                           */ 
/* 03-Oct-2019 NJOW10   2.5   WMS-9533 Add Ecom order handling           */
/* 01-04-2020  Wan01    2.6   Sync Exceed & SCE                          */
/* 31-07-2022  KY01     2.7   Performance tune                           */
/*************************************************************************/   
CREATE   PROCEDURE [dbo].[ispRLWAV01]      
  @c_wavekey      NVARCHAR(10)  
 ,@b_Success      int        OUTPUT  
 ,@n_err          int        OUTPUT  
 ,@c_errmsg       NVARCHAR(250)  OUTPUT  
 AS  
 BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
    
    DECLARE        @n_continue int,    
                   @n_starttcnt int,         -- Holds the current transaction count  
                   @n_debug int,
                   @n_cnt int
    SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
    SELECT @n_debug = 0

    DECLARE @c_Userdefine01 NVARCHAR(20)
            ,@c_Storerkey NVARCHAR(15)
            ,@c_Sku NVARCHAR(20)
            ,@c_Lot NVARCHAR(10)
            ,@c_FromLoc NVARCHAR(10)
            ,@c_ID NVARCHAR(18)
            ,@n_Qty INT
            --,@n_QtyRemain INT
            ,@n_QtyRemain_DP INT
            --,@n_QtyLoose INT
            ,@c_PickMethod NVARCHAR(10)
            ,@c_Toloc NVARCHAR(10)
            ,@c_Taskdetailkey NVARCHAR(10)  
            ,@n_UCCQty INT
            ,@c_Style NVARCHAR(20)
            ,@c_StartDynamicLoc  NVARCHAR(20)
            ,@c_DynamicLoc_Zone NVARCHAR(10)
            ,@c_SkuPutawayZone NVARCHAR(10) --NJOW06
            ,@c_Facility NVARCHAR(5)
            ,@c_NextDynPickLoc NVARCHAR(10)
            ,@c_LastRotateDynPickLoc NVARCHAR(10)
            ,@c_UOM NVARCHAR(10)
            ,@c_DestinationType NVARCHAR(30)
            ,@n_stdcube DECIMAL(13,5)
            ,@n_LocCubeAvailable DECIMAL(13,5)
            ,@n_LocCartonAllow INT
            ,@n_CartonToReplen INT
            ,@c_Lottable01 NVARCHAR(18)
            ,@c_Lottable02 NVARCHAR(18)
            ,@c_Lottable03 NVARCHAR(18)
            ,@c_SameStyleLoc NVARCHAR(10)
            ,@c_SourceType NVARCHAR(30)
            ,@c_Pickdetailkey NVARCHAR(18)
            ,@c_NewPickdetailKey NVARCHAR(18)
            ,@n_Pickqty INT
            ,@n_ReplenQty INT
            ,@n_SplitQty  INT
            ,@c_Orderkey NVARCHAR(10)
            ,@c_Pickslipno NVARCHAR(10)
            ,@c_Message03 NVARCHAR(20)
            ,@c_notes1 NVARCHAR(100)
            ,@c_ErrSku NVARCHAR(20) -- SOS# 312500
            ,@c_TaskType NVARCHAR(10) --NJOW03
            ,@c_LocationCategory NVARCHAR(10) --NJOW06
            ,@c_curPickdetailkey NVARCHAR(10)

    -----Wave Validation-----
    IF @n_continue=1 or @n_continue=2  
    BEGIN  
       IF ISNULL(@c_wavekey,'') = ''  
       BEGIN  
          SELECT @n_continue = 3  
          SELECT @n_err = 81000  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Parameters Passed (ispRLWAV01)'  
       END  
    END    
            
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                   WHERE TD.Wavekey = @c_Wavekey
                   AND TD.Sourcetype IN('ispRLWAV01-LAUNCH','ispRLWAV01-RETAIL','ispRLWAV01-XDOCK','ispRLWAV01-REPLEN','ispRLWAV01-ECOM') --NJOW03
                   AND TD.Tasktype IN ('RPF','MVF')) --NJOW03
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 81001  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV01)'       
        END                 
    END

    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 
                  FROM WAVEDETAIL WD(NOLOCK)
                  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                  WHERE O.Status > '2'
                  AND WD.Wavekey = @c_Wavekey)
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 81002  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Some orders of this Wave are started picking (ispRLWAV01)'         
        END                 
    END

    IF @n_continue = 1 OR @n_continue = 2 -- SOS# 312500
    BEGIN
       IF EXISTS ( SELECT 1 FROM WaveDetail WD WITH (NOLOCK)
                   JOIN Orders O WITH (NOLOCK) ON (WD.OrderKey = O.OrderKey)
                   JOIN OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
                   JOIN Sku S WITH (NOLOCK) ON (OD.StorerKey = S.StorerKey AND OD.Sku = S.Sku)
                   WHERE S.StdCube >= 100000000 -- overflow for DECIMAL(13,5)
                   AND WD.WaveKey = @c_Wavekey )
       BEGIN
          SELECT TOP 1 @c_ErrSku = OD.Sku
          FROM WaveDetail WD WITH (NOLOCK)
          JOIN Orders O WITH (NOLOCK) ON (WD.OrderKey = O.OrderKey)
          JOIN OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
          JOIN Sku S WITH (NOLOCK) ON (OD.StorerKey = S.StorerKey AND OD.Sku = S.Sku)
          WHERE S.StdCube >= 100000000
          AND WD.WaveKey = @c_Wavekey
    
          SELECT @n_continue = 3
          SELECT @n_err = 81019
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. ' +
                           'Sku ' + ISNULL(RTRIM(@c_ErrSku),'') + ' cube setup is too large. (ispRLWAV01)'
       END
    END
    
    -----Determine order type Launch(L) Or Retail/Wholesale(N) Or XDOCK(X) OR Leisure Replenishment(R)-----
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN      
        /*SELECT @c_Userdefine01 = UserDefine01
        FROM WAVE (NOLOCK)
        WHERE Wavekey = @c_Wavekey*/
        
        --NJOW01
        SELECT TOP 1 @c_Userdefine01 = WAVE.UserDefine01, @c_Facility = ORDERS.Facility
        FROM WAVE (NOLOCK)
        JOIN WAVEDETAIL (NOLOCK) ON WAVE.Wavekey = WAVEDETAIL.WaveKey
        JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey        
        WHERE WAVE.Wavekey = @c_Wavekey
                 
        IF ISNULL(@c_Userdefine01,'') = ''
        BEGIN
          SELECT TOP 1 @c_userdefine01 = CL.Short
          FROM WAVEDETAIL WD(NOLOCK)
          JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
          JOIN CODELKUP CL (NOLOCK) ON O.OrderGroup = CL.Code AND CL.Listname = 'ORDERGROUP'
          AND WD.Wavekey = @c_Wavekey 
        END
        
        IF @n_debug=1
           SELECT '@c_Userdefine01', @c_Userdefine01
        
        IF ISNULL(@c_Userdefine01,'') NOT IN('L','N','X','R','E') --NJOW03
        BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81003   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Code to determine Launch or Retail/Wholesale or Xdock Order (ispRLWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
        END 
        ELSE
        BEGIN
          --NJOW03
          IF @c_Userdefine01 = 'X'
             SELECT @c_TaskType = 'MVF'
          ELSE
             SELECT @c_TaskType = 'RPF'             
        END
    END

    --Create Temporary Tables
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_Userdefine01 IN ('N','L','R','E') --NJOW03
    BEGIN
       --Current wave assigned dynamic pick location  
       CREATE TABLE #DYNPICK_LOCASSIGNED ( STORERKEY NVARCHAR(15) NULL
                                          ,SKU NVARCHAR(20) NULL
                                          ,TOLOC NVARCHAR(10) NULL
                                          ,UCCQty INT NULL
                                          ,LOCCubeAvailable DECIMAL(13,5) NULL
                                          ,LOCATIONTYPE NVARCHAR(10) NULL
                                          ,LOT NVARCHAR(10) NULL)

       CREATE TABLE #DYNPICK_TASK (TOLOC NVARCHAR(10) NULL)    

       CREATE TABLE #DYNPICK_NON_EMPTY (LOC NVARCHAR(10) NULL)
       CREATE INDEX IDX_DYNPICK_NON_EMPTY ON #DYNPICK_NON_EMPTY (LOC) --Performance Tuning   NJOW09                                                                   
    END                                            
    
    -----Retail/Wholesale, ECOM Validation-----    
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_Userdefine01 IN('N','E')
    BEGIN
        SELECT TOP 1 @c_Toloc = LOC.Loc 
        FROM LOC (NOLOCK)  
        WHERE LOC.locationtype='DYNPICKP'
        AND LOC.[Cube] = 0
        AND LOC.PickZone <> 'LAUNCH'
        AND LOC.Facility = @c_Facility --NJOW01

        IF ISNULL(@c_Toloc,'') <> ''
        BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81004   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Dynamic Pick Location '+  RTRIM(@c_Toloc) +' Cube Not Yet Setup For Retail/Wholesale/ECOM Order (ispRLWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
        END
        SET @c_Toloc = ''
    END 
    
    -----Get Storerkey
    IF  (@n_continue = 1 OR @n_continue = 2)
    BEGIN
        SELECT TOP 1 @c_Storerkey = O.Storerkey
        FROM WAVEDETAIL WD(NOLOCK)
        JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
        AND WD.Wavekey = @c_Wavekey 
    END
    
    -----Create LOC BY ID data temporary table for full/partial pallet picking checking (FP/PP)
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_Userdefine01 IN ('N','L','R','E') --NJOW03
    BEGIN
        SELECT LLI.Storerkey, LLI.Loc, LLI.ID, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS QtyAvailable,
                (SELECT TOP 1 Qty FROM UCC (NOLOCK) 
                WHERE LLI.Storerkey = UCC.Storerkey AND LLI.Loc = UCC.Loc AND LLI.Id = UCC.Id AND UCC.Status='1') AS UCCQty
        INTO #TMP_LOCXID
        FROM LOTXLOCXID LLI (NOLOCK)
        JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
        JOIN SKUXLOC SL (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc 
        AND LOC.LocationType <> 'DYNPICKP' 
        AND LOC.LocationType <> (CASE WHEN @c_Userdefine01 IN('N','E') THEN 'DYNPPICK' ELSE '*IGNORE*' END) --Launch ord will replen from DPP to DP
--        AND SL.LocationType NOT IN('PICK','CASE')   -- Chee02
        AND LLI.Storerkey = @c_Storerkey
        AND LLI.Qty > 0
        GROUP BY LLI.Storerkey, LLI.Loc, LLI.ID  
        OPTION ( FORCE ORDER )                                    --KY01
        
        SELECT PD.Storerkey, PD.Loc, PD.ID, 
               CASE WHEN LI.QtyAvailable < ISNULL(LI.UCCQty,0) AND LOC.LocationType <> 'DYNPPICK' AND LOC.LocationHandling = '1' THEN 
                    -- loose allocation of last carton of the pallet will be full carton picked by RDT, so qtyavailable will be zero
                    -- for bulk pallet location only. 
                      0  
               ELSE LI.QtyAvailable END AS LOCXID_QTYAVAILABLE,                  
               COUNT(DISTINCT PD.SKU) AS SkuCount, COUNT(DISTINCT PD.LOT) AS LotCount,
               SUM(CASE WHEN PD.UOM = '2' THEN 1 ELSE 0 END) AS UOM2Count, --NJOW07
               SUM(CASE WHEN PD.UOM = '6' THEN 1 ELSE 0 END) AS UOM6Count, --NJOW07
               SUM(CASE WHEN PD.UOM = '7' THEN 1 ELSE 0 END) AS UOM7Count  --NJOW07
        INTO #LOCXID_QTYAVAILABLE
        FROM WAVEDETAIL WD (NOLOCK)
        JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
        JOIN #TMP_LOCXID LI (NOLOCK) ON PD.Storerkey = LI.Storerkey AND PD.Loc = LI.Loc AND PD.Id = LI.Id
        JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
        JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc 
        WHERE WD.Wavekey = @c_Wavekey
        AND LOC.LocationType <> 'DYNPICKP' 
        AND LOC.LocationType <> (CASE WHEN @c_Userdefine01 IN ('N','E') THEN 'DYNPPICK' ELSE '*IGNORE*' END) --Launch ord will replen from DPP to DP
--        AND SL.LocationType NOT IN('PICK','CASE')   -- Chee02
        GROUP BY PD.Storerkey, PD.Loc, PD.ID,
                  CASE WHEN LI.QtyAvailable < ISNULL(LI.UCCQty,0) AND LOC.LocationType <> 'DYNPPICK' AND LOC.LocationHandling = '1' THEN 
                      0 
                  ELSE LI.QtyAvailable END                               
    END
   
    --Generate Retail/Wholesale/Launch/ECOM Temporary Ref Data
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_Userdefine01 IN('N','L','R','E')
    BEGIN
        --Performance tuning NJOW09
        SELECT DISTINCT SKU.Putawayzone 
        INTO #TMP_SKUPAZONE
        FROM ORDERS O (NOLOCK)
        JOIN ORDERDETAIL OD(NOLOCK) ON O.Orderkey = OD.Orderkey
        JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.sku
        WHERE O.Userdefine09 = @c_Wavekey
      
        --Permanent pick location 
        SELECT DISTINCT L.Loc, SL.LocationType --NJOW02
        INTO #TMP_PP_LOC
        FROM SKUXLOC SL (NOLOCK) 
        JOIN LOC L (NOLOCK) ON SL.Loc = L.Loc        
        WHERE L.LocationType IN('DYNPPICK') 
        AND L.PickZone <> 'LAUNCH'
        AND SL.LocationType IN ('PICK','CASE')
        AND  L.Putawayzone IN (SELECT Putawayzone FROM #TMP_SKUPAZONE) --NJOW09
    END
 
    -----Generate Retail/Wholesale, ECOM Temporary Ref Data-----
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_Userdefine01 IN('N','R','E')
    BEGIN               
        --Get DP expected cube from replenishment tasks from other wave. Physical stock not reach destination yet
        /*SELECT TD.ToLoc, SUM(TD.Qty * SKU.Stdcube) AS CubeOccupy
        INTO #TMP_TASKCUBE
        FROM TASKDETAIL TD (NOLOCK)
        JOIN SKU (NOLOCK) ON TD.Storerkey = SKU.Storerkey AND TD.Sku = SKU.Sku
        JOIN LOC (NOLOCK) ON TD.ToLoc = LOC.Loc
        AND  TD.Status = '0'
        AND  TD.Tasktype = 'RPF'
        AND  TD.Sourcetype = 'ispRLWAV01-RETAIL'
        AND  TD.Qty > 0
        AND  LOC.LocationType IN('DYNPICKP')
        GROUP BY TD.TOLOC*/
        SELECT TD.LogicalToLoc AS ToLoc, SUM(PD.Qty * SKU.Stdcube) AS CubeOccupy
        INTO #TMP_TASKCUBE
        FROM TASKDETAIL TD (NOLOCK)
        JOIN SKU (NOLOCK) ON TD.Storerkey = SKU.Storerkey AND TD.Sku = SKU.Sku
        JOIN LOC (NOLOCK) ON TD.LogicalToLoc = LOC.Loc
        JOIN PICKDETAIL PD (NOLOCK) ON TD.Taskdetailkey = PD.Taskdetailkey
        JOIN LOC PKLOC (NOLOCK) ON PD.Loc = PKLOC.Loc
        AND  PD.Status = '0' --stock have not reach DP yet, maybe task status is 9 but still in conveyer
        AND  TD.Tasktype = 'RPF'
        AND  TD.Sourcetype IN('ispRLWAV01-RETAIL','ispRLWAV01-ECOM')
        AND  TD.Qty > 0
        AND  LOC.LocationType IN('DYNPICKP')
        AND  PKLOC.LocationType NOT IN('DYNPICKP')
        AND  LOC.Putawayzone IN (SELECT Putawayzone FROM #TMP_SKUPAZONE) --NJOW09
        GROUP BY TD.LogicalToLoc  

        --Get cube picked in DP loc where pickdetail status=3 but qty still at allocated counter.
        SELECT PD.Loc, SUM(PD.Qty * SKU.Stdcube) AS CubePicked3
        INTO #TMP_DPPICKED_STATUS3
        FROM TASKDETAIL TD (NOLOCK)
        JOIN SKU (NOLOCK) ON TD.Storerkey = SKU.Storerkey AND TD.Sku = SKU.Sku
        JOIN PICKDETAIL PD (NOLOCK) ON TD.Taskdetailkey = PD.Taskdetailkey
        JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
        AND  PD.Status = '3'
        AND  TD.Tasktype = 'RPF'
        AND  TD.Sourcetype IN ('ispRLWAV01-RETAIL','ispRLWAV01-ECOM')
        AND  TD.Qty > 0
        AND  LOC.LocationType IN('DYNPICKP')
        GROUP BY PD.Loc  
                 
        --Get DP location cube available include expected replen cube and current stock. 
        --Pickdetail.status=3 consider physically picked but still under qty allocated counter(Updated by RDT)
        SELECT L.Loc, CONVERT(DECIMAL(13,5),L.[Cube] - ISNULL(SUM((SL.Qty - SL.QtyPicked) * S.Stdcube),0) - ISNULL(T.CubeOccupy,0) + ISNULL(P3.CubePicked3,0)) AS LOCCubeAvailable,
               L.Pickzone, L.Putawayzone, L.Facility, L.LocationType, L.LocationCategory, L.LogicalLocation 
        INTO #TMP_LOCCUBE
        FROM LOC L (NOLOCK)        
        LEFT JOIN SKUXLOC SL (NOLOCK) ON SL.Loc = L.Loc
        LEFT JOIN SKU S (NOLOCK) ON SL.Storerkey = S.Storerkey AND SL.Sku = S.Sku
        LEFT JOIN #TMP_TASKCUBE T ON SL.Loc = T.ToLoc 
        LEFT JOIN #TMP_DPPICKED_STATUS3 P3 ON SL.Loc = P3.Loc
        WHERE L.LocationType IN('DYNPICKP')
        AND L.PickZone <> 'LAUNCH'
        AND    L.Putawayzone IN (SELECT Putawayzone FROM #TMP_SKUPAZONE) --NJOW09
        GROUP BY L.Loc, L.[Cube], L.Pickzone, L.Putawayzone, L.Facility, L.LocationType, L.LocationCategory, L.LogicalLocation, T.CubeOccupy, P3.CubePicked3
        
        --location have pending Replenishment tasks
        INSERT INTO #DYNPICK_TASK (TOLOC)
        SELECT TD.TOLOC
        FROM   TASKDETAIL TD (NOLOCK)
        JOIN   LOC L (NOLOCK) ON  TD.TOLOC = L.LOC
        WHERE  L.LocationType IN('DYNPICKP','DYNPPICK') 
        --AND    LOC.PickZone = @c_DynamicLoc_Zone
        --AND    LOC.Facility = @c_Facility
        AND    TD.Status = '0'
        AND    TD.Tasktype = 'RPF'
        --AND    TD.Sourcetype = 'ispRLWAV01-RETAIL'
        AND    L.PickZone <> 'LAUNCH'
        AND    L.Putawayzone IN (SELECT Putawayzone FROM #TMP_SKUPAZONE) --NJOW09
        GROUP BY TD.TOLOC
        HAVING SUM(TD.Qty) > 0
        
         --Dynamic pick loc have qty and pending move in                 
        INSERT INTO #DYNPICK_NON_EMPTY (LOC)
        SELECT LLI.LOC
        FROM   LOTXLOCXID LLI (NOLOCK)
        JOIN   LOC L (NOLOCK) ON LLI.LOC = L.LOC
        WHERE  L.LocationType IN ('DYNPICKP','DYNPPICK') 
        AND    L.PickZone <> 'LAUNCH'
        --AND    LOC.PickZone = @c_DynamicLoc_Zone 
        --AND    LOC.Facility = @c_Facility
         AND    L.Putawayzone IN (SELECT Putawayzone FROM #TMP_SKUPAZONE) --NJOW09
        GROUP BY LLI.LOC
        HAVING SUM((LLI.Qty + LLI.PendingMoveIN) - LLI.QtyPicked ) > 0                     
    END
            
    BEGIN TRAN  
    
    --Remove taskdetailkey and add wavekey from pickdetail of the wave    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        -- tlting01
        SET @c_curPickdetailkey = ''
         DECLARE Orders_Pickdet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT Pickdetailkey
               FROM WAVEDETAIL WITH (NOLOCK)  
               JOIN PICKDETAIL WITH (NOLOCK)  ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey
               WHERE WAVEDETAIL.Wavekey = @c_Wavekey 

         OPEN Orders_Pickdet_cur 
         FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey 
         WHILE @@FETCH_STATUS = 0 
         BEGIN 
               UPDATE PICKDETAIL WITH (ROWLOCK) 
                SET PICKDETAIL.TaskdetailKey = '',
                    PICKDETAIL.Wavekey = @c_Wavekey, 
                    EditWho    = SUSER_SNAME(),
                    EditDate   = GETDATE(),
                    TrafficCop = NULL
                WHERE PICKDETAIL.Pickdetailkey = @c_curPickdetailkey
              SELECT @n_err = @@ERROR
               IF @n_err <> 0 
               BEGIN
                  CLOSE Orders_Pickdet_cur 
                  DEALLOCATE Orders_Pickdet_cur                  
                 SELECT @n_continue = 3  
                 SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END      
            FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey
         END
         CLOSE Orders_Pickdet_cur 
         DEALLOCATE Orders_Pickdet_cur
    END
     
    -----Generate Retail/Wholesale, ECOM Order Tasks-----
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_Userdefine01 IN('N','R','E') --NJOW06
    BEGIN
       DECLARE cur_RetailWholesale CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
        SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, PD.UOM,
               (SELECT TOP 1 Qty FROM UCC (NOLOCK) 
                WHERE PD.Lot = UCC.Lot AND PD.Loc = UCC.Loc AND PD.Id = UCC.Id AND UCC.Status = '1') AS UCCQty,
               CASE WHEN ISNULL(LI.LOCXID_QTYAVAILABLE,0) <= 0 AND LOC.LocationHandling = '1' THEN 
                         'FP'                          
                    ELSE 'PP' END AS PickMethod,
               SKU.Style,
               CONVERT(DECIMAL(13,5),SKU.Stdcube) AS stdcube,
               SKU.Putawayzone,
               CONVERT(NVARCHAR(100),SKU.Notes1) AS Notes1                                                                                       
        FROM WAVEDETAIL WD (NOLOCK)
        JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
        JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
        JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
        JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc
         JOIN #LOCXID_QTYAVAILABLE LI (NOLOCK) ON PD.Storerkey = LI.Storerkey AND PD.Loc = LI.Loc AND PD.Id = LI.Id
        WHERE WD.Wavekey = @c_Wavekey
          AND LOC.LocationType NOT IN('DYNPPICK','DYNPICKP')
          AND SL.LocationType NOT IN('PICK','CASE')
          AND LOC.LocationCategory NOT IN('RESALE')  -- Chee01
        GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM, SKU.Style, CONVERT(DECIMAL(13,5),SKU.Stdcube), SKU.Putawayzone, LI.LOCXID_QTYAVAILABLE,
                 LOC.LocationHandling, CONVERT(NVARCHAR(100),SKU.Notes1)
        ORDER BY PD.Storerkey, PD.UOM, SKU.Style, PD.Sku, PD.Lot
               
       OPEN cur_RetailWholesale  
       FETCH NEXT FROM cur_RetailWholesale INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, 
                                                @n_UCCQty, @c_PickMethod, @c_Style, @n_Stdcube, @c_DynamicLoc_Zone, @c_Notes1 
       IF @c_Userdefine01 = 'R' --Leisure replenishment                                               
          SELECT @c_SourceType = 'ispRLWAV01-REPLEN' --NJOW06    
       ELSE IF @c_Userdefine01 = 'E'
          SELECT @c_SourceType = 'ispRLWAV01-ECOM'
       ELSE
          SELECT @c_SourceType = 'ispRLWAV01-RETAIL' 
       
       WHILE @@FETCH_STATUS = 0  
       BEGIN    
           IF @n_debug=1
              SELECT 'Retail','@c_FromLoc', @c_FromLoc, '@c_ID', @c_ID, '@n_Qty', @n_qty, '@c_UOM', @c_UOM, '@n_UCCQty', @n_UCCQty, '@c_PickMethod', @c_PickMethod,
                     '@c_Style', @c_Style, '@n_StdCube', @n_stdcube, '@c_DynamicLoc_zone', @c_Dynamicloc_zone, '@c_Notes1', @c_Notes1 
                     
          SELECT @n_UCCQty = ISNULL(@n_UCCQty,0)

          IF ISNULL(@n_Stdcube,0) = 0
          BEGIN
              SELECT @n_continue = 3  
              SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81006   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
              SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Sku Cube Not Setup Yet: '+ RTRIM(@c_Sku)  +' Cannot Proceed  (ispRLWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
              GOTO RETURN_SP  
          END

           --SELECT @n_QtyRemain = @n_Qty            
           --WHILE @n_QtyRemain > 0 --loop pickdetail
           --BEGIN
               --IF @n_debug=1
                  --SELECT '@n_QtyRemain', @n_QtyRemain

             --Determine destination direct/dp/dpp
             IF @c_Userdefine01 = 'R' --Leisure replenishment  NJOW06
             BEGIN
                 SELECT @c_DestinationType = 'DPP'
             END
             ELSE
             BEGIN
                IF @c_uom = '2' --full carton for an order send to direct out inducton
                BEGIN
                   SELECT @c_DestinationType = 'DIRECT'
                   IF @c_Notes1 = 'ODDSIZE'
                       SELECT @c_ToLoc = 'IND1002'
                   ELSE                    
                      SELECT @c_ToLoc = 'IND1001'
                   --SELECT @n_Qty = @n_QtyRemain 
                   --SELECT @n_QtyRemain = 0                       
                END
                ELSE IF @c_uom = '6' AND ISNULL(@n_UCCQty,0) > 0 
                BEGIN
                    --full conso carton go to DP. A carton will be completely picked
                    SELECT @c_DestinationType = 'DP'                
                END
                ELSE IF @c_uom = '7'  
                BEGIN
                    --loose conso carton go to DPP. Allocated partial carton but RDT will pick full carton. carton will have left over after picking. 
                    --will consider PP first if found. Dynamic Permanent Pick(DPP) or Permanent Pick(PP)               
                    SELECT @c_DestinationType = 'DPP'  
                END
                ELSE
                BEGIN
                    SELECT @c_DestinationType = 'DPP'
                END    
             END            
             
             /*ELSE
             BEGIN -- @c_uom='6' (dp) or '7' (dpp) conso carton
                 --check is there any loose conso carton allocte from a pallet loc. 
                 IF ISNULL(@n_UCCQty,0) > 0 
                    SELECT @n_QtyLoose = @n_QtyRemain % @n_UCCQty
                 ELSE
                   SELECT @n_QtyLoose = @n_QtyRemain --if can't find uccqty all replen to DPP
                 
                 --will always work on DP first then DPP  
                IF @n_QtyRemain = @n_QtyLoose
                BEGIN
                   --loose conso carton go to DPP. Allocated partial carton but RDT will pick full carton. carton will have left over after picking. 
                   SELECT @c_DestinationType = 'DPP'
                   SELECT @n_Qty = @n_QtyRemain 
                   SELECT @n_QtyRemain = 0
                END                     
                ELSE
                BEGIN
                   --full conso carton go to DP. A carton will be completely picked
                   SELECT @c_DestinationType = 'DP'
                   SELECT @n_Qty = @n_Qty - @n_QtyLoose --exclude loose qty later replen to DPP
                   SELECT @n_QtyRemain = @n_QtyRemain - @n_Qty                     
                END                                    
             END*/
             
             IF @n_debug=1
                SELECT '@c_DestinationType', @c_DestinationType, '@n_Qty', @n_Qty                              
             
             SELECT @c_Message03 = @c_DestinationType
             
             IF @c_DestinationType = 'DIRECT' --Full carton for an order
             BEGIN
                GOTO INSERT_TASKS
                DIRECT:
             END --DIRECT
             
             IF @c_DestinationType = 'DP'
             BEGIN
                 SELECT @n_QtyRemain_DP = @n_Qty
                 WHILE @n_QtyRemain_DP > 0 --loop the qty to fit DP Loc by cube
                 BEGIN
                    SELECT @c_NextDynPickLoc = ''
                    
                    IF @n_debug = 1
                       SELECT 'DP','@n_QtyRemain_DP',@n_QtyRemain_DP
                         
                    -- Assign loc with same sku qty already assigned in current replenishment
                   IF ISNULL(@c_NextDynPickLoc,'')=''
                   BEGIN
                       SELECT TOP 1 @c_NextDynPickLoc = ToLoc, 
                                    @n_LocCubeAvailable = CONVERT(DECIMAL(13,5), LOCCubeAvailable) 
                       FROM #DYNPICK_LOCASSIGNED 
                       WHERE Storerkey = @c_Storerkey
                       AND Sku = @c_Sku
                       AND LocCubeAvailable >= CONVERT(DECIMAL(13,5),@n_UCCQty * @n_Stdcube)
                       AND LocationType IN('DYNPICKP')
                       ORDER BY ToLoc                     
                   END
                             
                    -- Assign loc with same sku already assigned in other replenishment within same zone
                   IF ISNULL(@c_NextDynPickLoc,'')=''
                   BEGIN            
                       SELECT TOP 1 @c_NextDynPickLoc = L.LOC,
                                    @n_LocCubeAvailable = CONVERT(DECIMAL(13,5), L.LOCCubeAvailable) 
                       FROM TASKDETAIL TD (NOLOCK)
                       JOIN #TMP_LOCCUBE L (NOLOCK) ON TD.TOLOC = L.LOC                       
                       WHERE L.LocationType IN ('DYNPICKP') 
                       AND L.PutawayZone = @c_DynamicLoc_Zone 
                       --AND LOC.Facility = @c_Facility
                       AND TD.Status = '0'
                       AND TD.Qty > 0 
                       AND TD.Tasktype = 'RPF'
                       AND TD.Sourcetype IN('ispRLWAV01-RETAIL','ispRLWAV01-ECOM')
                       AND TD.Storerkey = @c_Storerkey
                       AND TD.Sku = @c_Sku
                       AND L.LOCCubeAvailable >= CONVERT(DECIMAL(13,5),@n_UCCQty * @n_Stdcube)
                       ORDER BY CASE WHEN L.LocationCategory = 'FLOWRACK' THEN 0 ELSE 1 END, L.LogicalLocation, L.Loc
                   END
                   
                    -- Assign loc with same sku and qty available
                   IF ISNULL(@c_NextDynPickLoc,'')=''
                   BEGIN              
                       SELECT TOP 1 @c_NextDynPickLoc = L.LOC,
                                    @n_LocCubeAvailable = CONVERT(DECIMAL(13,5), L.LOCCubeAvailable) 
                       FROM LOTXLOCXID LLI (NOLOCK)
                       JOIN #TMP_LOCCUBE L (NOLOCK) ON  LLI.LOC = L.LOC
                       WHERE L.LocationType IN ('DYNPICKP')
                       AND   L.PutawayZone = @c_DynamicLoc_Zone
                       AND   L.Pickzone <> 'LAUNCH' 
                       --AND   LOC.Facility = @c_Facility
                       AND  (LLI.Qty - LLI.QtyPicked) > 0 
                       AND  L.LOCCubeAvailable >= CONVERT(DECIMAL(13,5),@n_UCCQty * @n_Stdcube)
                       AND  LLI.Storerkey = @c_Storerkey
                       AND  LLI.Sku = @c_Sku
                       ORDER BY CASE WHEN L.LocationCategory = 'FLOWRACK' THEN 0 ELSE 1 END, L.LogicalLocation, L.Loc  

                   END
                   
                   -- If no location with same sku found, then assign the empty location
                   IF ISNULL(@c_NextDynPickLoc,'')=''
                   BEGIN
                        SELECT TOP 1 @c_NextDynPickLoc = L.LOC,
                                    @n_LocCubeAvailable = CONVERT(DECIMAL(13,5), L.LocCubeAvailable) 
                       FROM   #TMP_LOCCUBE L (NOLOCK) 
                       WHERE  L.LocationType IN ('DYNPICKP') 
                       --AND    LOC.Facility = @c_Facility
                       AND    L.PutawayZone = @c_DynamicLoc_Zone 
                       AND    L.LOCCubeAvailable >= CONVERT(DECIMAL(13,5),@n_UCCQty * @n_Stdcube)
                       AND    NOT EXISTS(
                                  SELECT 1
                                  FROM   #DYNPICK_NON_EMPTY E
                                  WHERE  E.LOC = L.LOC
                              ) AND
                              NOT EXISTS(
                                  SELECT 1
                                  FROM   #DYNPICK_TASK AS ReplenLoc
                                  WHERE  ReplenLoc.TOLOC = L.LOC
                              ) AND
                              NOT EXISTS(
                                  SELECT 1
                                  FROM   #DYNPICK_LOCASSIGNED AS DynPick
                                  WHERE  DynPick.ToLoc = L.LOC
                              ) AND
                              NOT EXISTS(
                                  SELECT 1
                                  FROM   #TMP_TASKCUBE AS DynTaskCube
                                  WHERE  DynTaskCube.ToLoc = L.LOC
                                  AND DynTaskCube.CubeOccupy > 0
                              ) --NJOW05                                                          
                       ORDER BY CASE WHEN L.LocationCategory = 'FLOWRACK' THEN 0 ELSE 1 END, L.LogicalLocation, L.Loc --Get flowrack loc first then other
                   END
                   
                   -- Can't find any DP-dynamic location, Use DPP logic
                   IF ISNULL(@c_NextDynPickLoc,'')=''
                   BEGIN
                       SELECT @c_DestinationType = 'DPP'
                       SELECT @n_Qty = @n_QtyRemain_DP
                       SELECT @c_Message03 = RTRIM(@c_DestinationType) + '-DP FULL'                       
                      IF @n_debug=1
                         SELECT 'LOC NOT FOUND TRIGGER DPP LOGIC'

                       GOTO DPP_LOGIC
                   END 
          
                   SELECT @c_ToLoc = @c_NextDynPickLoc
               
                   SELECT @n_LocCartonAllow = FLOOR(@n_LocCubeAvailable / CONVERT(DECIMAL(13,5),@n_UCCQty * @n_Stdcube)) -- available carton space of the loc
                   SELECT @n_CartonToReplen = FLOOR(@n_QtyRemain_DP / @n_UCCQty)  -- remain carton replen to
                   
                   -- By right uom 6 all should be full case, in case data not correct use DPP logic to avoid indefinite loop
                   IF @n_CartontoReplen = 0 AND @n_QtyRemain_DP > 0  
                   BEGIN
                       SELECT @c_DestinationType = 'DPP'
                       SELECT @n_Qty = @n_QtyRemain_DP
                       
                      IF @n_debug=1
                         SELECT 'FOUND INVALID CASE TRIGGER DPP LOGIC'

                       GOTO DPP_LOGIC
                   END

                   IF @n_LocCartonAllow >= @n_CartonToReplen --if loc cube more than request
                      SELECT @n_Qty = @n_CartonToReplen * @n_UCCQty --replen all
                   ELSE
                      SELECT @n_Qty = @n_LocCartonAllow * @n_UCCQty --replen available only
                      
                   SELECT @n_QtyRemain_DP = @n_QtyRemain_DP - @n_Qty 
                   
                   SELECT @n_LocCubeAvailable = @n_LocCubeAvailable - (@n_Qty * @n_StdCube) --calculate new loc available cube

                    IF @n_debug = 1
                       SELECT 'DP','@c_NextDynPickLoc',@c_NextDynPickLoc, '@n_LocCartonAllow', @n_LocCartonAllow, '@n_CartonToReplen', @n_CartonToReplen,
                              '@n_Qty', @n_Qty, '@n_QtyRemain_DP', @n_QtyRemain_DP, '@n_LocCubeAvailable', @n_LocCubeAvailable
                            
                   --Insert/update current location assigned
                   IF EXISTS (SELECT 1 FROM #DYNPICK_LOCASSIGNED 
                                  WHERE Storerkey = @c_Storerkey
                                  AND Sku = @c_Sku
                                  AND ToLoc = @c_ToLoc)                                 
                   BEGIN
                        --update loc cube available
                        UPDATE #DYNPICK_LOCASSIGNED
                        SET LOCCubeAvailable = @n_LocCubeAvailable  
                       WHERE Storerkey = @c_Storerkey
                       AND Sku = @c_Sku
                       AND ToLoc = @c_ToLoc
                   END
                   ELSE                                                                    
                   BEGIN
                        INSERT INTO #DYNPICK_LOCASSIGNED (Storerkey, Sku, ToLoc, LOCCubeAvailable, LocationType)
                        VALUES (@c_Storerkey, @c_Sku, @c_Toloc, @n_LocCubeAvailable, 'DYNPICKP')
                   END
                   
                   UPDATE #TMP_LOCCUBE
                   SET LocCubeAvailable = @n_LocCubeAvailable
                   WHERE Loc = @c_ToLoc 

                   GOTO INSERT_TASKS
                   DP:            
                END --while qtyremaindp                 
             END --DP                                     
             
             DPP_LOGIC:
             IF @c_DestinationType = 'DPP'  ----will consider PP first if found. Dynamic Permanent Pick(DPP) or Permanent Pick(PP)                
             BEGIN
                 SELECT @c_NextDynPickLoc = ''
                 
                 SELECT @c_Lottable01 = Lottable01, @c_Lottable02 = Lottable02, @c_Lottable03 = Lottable03
                 FROM LOTATTRIBUTE (NOLOCK)
                 WHERE LOT = @c_Lot 
                 
                 -- Assign loc with same sku qty already assigned in current replenishment
                IF ISNULL(@c_NextDynPickLoc,'')=''
                BEGIN
                    SELECT TOP 1 @c_NextDynPickLoc = DL.ToLoc
                    FROM #DYNPICK_LOCASSIGNED DL
                    JOIN LOTATTRIBUTE LA (NOLOCK) ON DL.Lot = LA.Lot
                    WHERE DL.Storerkey = @c_Storerkey
                    AND DL.Sku = @c_Sku
                    AND DL.LocationType IN('DYNPPICK')
                    AND LA.Lottable01 = @c_Lottable01
                    AND LA.Lottable02 = @c_Lottable02
                    AND LA.Lottable03 = @c_Lottable03
                    ORDER BY DL.ToLoc                     
                END                

                 -- Assign pick loc (PP) if found
                IF ISNULL(@c_NextDynPickLoc,'')=''
                BEGIN
                    SELECT TOP 1 @c_NextDynPickLoc = SL.Loc
                    FROM SKUXLOC SL (NOLOCK)
                    JOIN LOC (NOLOCK) ON SL.Loc = LOC.Loc --NJOW09                    
                    WHERE SL.Storerkey = @c_Storerkey
                    AND SL.Sku = @c_Sku
                    AND SL.LocationType IN('CASE','PICK')
                    ORDER BY SL.Loc     
                    IF ISNULL(@c_NextDynPickLoc,'')<>''
                    BEGIN
                      SELECT @c_DestinationType = 'PP' -- Permanent pick location
                      SELECT @c_Message03 = RTRIM(@c_Message03) + '-PP'
                    END              
                END                
                          
                 -- Assign loc with same sku already assigned in other replenishment within same zone
                IF ISNULL(@c_NextDynPickLoc,'')=''
                BEGIN            
                    SELECT TOP 1 @c_NextDynPickLoc = L.LOC
                    FROM TASKDETAIL TD (NOLOCK)
                    JOIN LOC L (NOLOCK) ON TD.TOLOC = L.LOC
                    JOIN LOTATTRIBUTE LA (NOLOCK) ON TD.Lot = LA.Lot         
                    WHERE L.LocationType IN ('DYNPPICK') 
                    AND L.PutawayZone = @c_DynamicLoc_Zone 
                    --AND LOC.Facility = @c_Facility
                    AND TD.Status = '0'
                    AND TD.Qty > 0 
                    AND TD.Tasktype = 'RPF'
                    --AND TD.Sourcetype = 'ispRLWAV01-RETAIL'
                    AND TD.Storerkey = @c_Storerkey
                    AND TD.Sku = @c_Sku
                    AND LA.Lottable01 = @c_Lottable01
                    AND LA.Lottable02 = @c_Lottable02
                    AND LA.Lottable03 = @c_Lottable03                    
                    ORDER BY L.LogicalLocation, L.Loc
                END
                
                 -- Assign loc with same sku, Lottables and qty available / pending move in
                IF ISNULL(@c_NextDynPickLoc,'')=''
                BEGIN              
                    SELECT TOP 1 @c_NextDynPickLoc = L.LOC
                    FROM LOTXLOCXID LLI (NOLOCK)
                    JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
                    JOIN LOC L (NOLOCK) ON  LLI.LOC = L.LOC
                    WHERE L.LocationType IN ('DYNPPICK')
                    AND   L.PutawayZone = @c_DynamicLoc_Zone
                    AND   L.Pickzone <> 'LAUNCH' 
                    --AND   LOC.Facility = @c_Facility
                    AND  ((LLI.Qty + LLI.PendingMoveIN) - LLI.QtyPicked) > 0 
                    AND  LLI.Storerkey = @c_Storerkey
                    AND  LLI.Sku = @c_Sku
                    AND LA.Lottable01 = @c_Lottable01
                    AND LA.Lottable02 = @c_Lottable02
                    AND LA.Lottable03 = @c_Lottable03                    
                    ORDER BY L.LogicalLocation, L.Loc
                END
                
                -- Assign empty loc that near to same style
                IF ISNULL(@c_NextDynPickLoc,'')=''
                BEGIN                                                                        
                    SELECT @c_SameStyleLoc = MAX(LLI.LOC)
                    FROM LOTXLOCXID LLI (NOLOCK)
                    JOIN LOC L (NOLOCK) ON  LLI.LOC = L.LOC
                    JOIN SKU S (NOLOCK) ON  LLI.Storerkey = S.Storerkey AND LLI.Sku = S.Sku
                    WHERE L.LocationType IN ('DYNPPICK')
                    AND   L.PutawayZone = @c_DynamicLoc_Zone
                    AND   L.Pickzone <> 'LAUNCH' 
                    AND  ((LLI.Qty + LLI.PendingMoveIN) - LLI.QtyPicked) > 0 
                    AND  LLI.Storerkey = @c_Storerkey
                    AND  S.Style = @c_Style

                    SELECT TOP 1 @c_NextDynPickLoc = L.LOC
                    FROM   LOC L (NOLOCK) 
                    WHERE  L.LocationType IN ('DYNPPICK') 
                    --AND    LOC.Facility = @c_Facility
                    AND    L.PutawayZone = @c_DynamicLoc_Zone 
                    AND    L.LOC >= @c_SameStyleLoc
                    AND    NOT EXISTS(
                               SELECT 1
                               FROM   #DYNPICK_NON_EMPTY E
                               WHERE  E.LOC = L.LOC
                           ) AND
                           NOT EXISTS(
                               SELECT 1
                               FROM   #DYNPICK_TASK AS ReplenLoc
                               WHERE  ReplenLoc.TOLOC = L.LOC
                           ) AND
                           NOT EXISTS(
                               SELECT 1
                               FROM   #DYNPICK_LOCASSIGNED AS DynPick
                               WHERE  DynPick.ToLoc = L.LOC
                           ) AND --NJOW02
                           NOT EXISTS (
                               SELECT 1
                               FROM #TMP_PP_LOC AS PPLoc
                               WHERE PPLoc.Loc = L.LOC
                           )
                    ORDER BY L.LogicalLocation, L.Loc                    
                END
                                
                -- If no location with same sku found, then assign the empty location
                IF ISNULL(@c_NextDynPickLoc,'')=''
                BEGIN
                    SELECT TOP 1 @c_NextDynPickLoc = L.LOC
                    FROM   LOC L (NOLOCK) 
                    LEFT JOIN ( SELECT E.LOC
                               FROM   #DYNPICK_NON_EMPTY E 
                               UNION ALL
                               SELECT ReplenLoc.TOLOC
                               FROM   #DYNPICK_TASK AS ReplenLoc
                               UNION ALL
                               SELECT DynPick.ToLoc
                               FROM   #DYNPICK_LOCASSIGNED AS DynPick
                               UNION ALL
                               SELECT PPLoc.Loc
                               FROM #TMP_PP_LOC AS PPLoc
                               ) AS A ON A.LOC = L.LOC
                    WHERE  L.LocationType IN ('DYNPPICK') 
                    --AND    LOC.Facility = @c_Facility
                    AND    L.PutawayZone = @c_DynamicLoc_Zone 
                    AND    A.LOC IS NULL
                    --AND    LOC.LOC >= @c_StartDynamicLoc 
                    --AND    NOT EXISTS(
                    --           SELECT 1
                    --           FROM   #DYNPICK_NON_EMPTY E
                    --           WHERE  E.LOC = L.LOC
                    --       ) AND
                    --       NOT EXISTS(
                    --           SELECT 1
                    --           FROM   #DYNPICK_TASK AS ReplenLoc
                    --           WHERE  ReplenLoc.TOLOC = L.LOC
                    --       ) AND
                    --       NOT EXISTS(
                    --           SELECT 1
                    --           FROM   #DYNPICK_LOCASSIGNED AS DynPick
                    --           WHERE  DynPick.ToLoc = L.LOC
                    --       ) AND --NJOW02
                    --       NOT EXISTS (
                    --           SELECT 1
                    --           FROM #TMP_PP_LOC AS PPLoc
                    --           WHERE PPLoc.Loc = L.LOC
                    --       )                           
                    ORDER BY L.LogicalLocation, L.Loc
                END
                
                -- if no more empty location, Assign loc with same sku and qty available / pending move in without check lottables
                IF ISNULL(@c_NextDynPickLoc,'')=''
                BEGIN              
                    SELECT TOP 1 @c_NextDynPickLoc = L.LOC
                    FROM LOTXLOCXID LLI (NOLOCK)
                    JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
                    JOIN LOC L (NOLOCK) ON  LLI.LOC = L.LOC
                    WHERE L.LocationType IN ('DYNPPICK')
                    AND   L.PutawayZone = @c_DynamicLoc_Zone
                    AND   L.Pickzone <> 'LAUNCH' 
                    --AND   LOC.Facility = @c_Facility
                    AND  ((LLI.Qty + LLI.PendingMoveIN) - LLI.QtyPicked) > 0 
                    AND  LLI.Storerkey = @c_Storerkey
                    AND  LLI.Sku = @c_Sku
                    --AND LA.Lottable01 = @c_Lottable01
                    --AND LA.Lottable02 = @c_Lottable02
                    --AND LA.Lottable03 = @c_Lottable03                    
                    ORDER BY L.LogicalLocation, L.Loc
                END

                 IF @n_debug = 1
                    SELECT 'DPP', '@c_NextDynPickLoc', @c_NextDynPickLoc
                
                -- Terminate. Can't find any dynamic location
                TERMINATE:
                IF ISNULL(@c_NextDynPickLoc,'')=''
                BEGIN
                    SELECT @n_continue = 3  
                    SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81007   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                    SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Dynamic Pick Location Not Setup / Not enough Dynamic Pick Location. (ispRLWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                    GOTO RETURN_SP
                END 
          
                SELECT @c_ToLoc = @c_NextDynPickLoc
                                         
                --Insert current location assigned
                IF NOT EXISTS (SELECT 1 FROM #DYNPICK_LOCASSIGNED 
                               WHERE Storerkey = @c_Storerkey
                               AND Sku = @c_Sku
                               AND ToLoc = @c_ToLoc) AND @c_DestinationType = 'DPP'
                BEGIN
                     INSERT INTO #DYNPICK_LOCASSIGNED (Storerkey, Sku, ToLoc, LocationType, Lot)
                     VALUES (@c_Storerkey, @c_Sku, @c_Toloc, 'DYNPPICK', @c_Lot )
                END

                GOTO INSERT_TASKS
                DPP:            
             END --DPP                                    

          --END --While qtyremain
          FETCH NEXT FROM cur_RetailWholesale INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, 
                                                   @n_UCCQty, @c_PickMethod, @c_Style, @n_Stdcube, @c_DynamicLoc_Zone, @c_Notes1  
       END --Fetch
       CLOSE cur_RetailWholesale  
       DEALLOCATE cur_RetailWholesale                                   
    END   

    -----Launch Order Initialization and Validation-----    
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_Userdefine01 = 'L'
    BEGIN
        SELECT @c_StartDynamicLoc = Wave.UserDefine02
        FROM   WAVE (NOLOCK)
        WHERE  WaveKey = @c_WaveKey

        IF ISNULL(@c_StartDynamicLoc,'') = ''
        BEGIN
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81008   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Start Dynamic Pick Location(Userdefine02) Cannot Be Blank for Launch Orders! (ispRLWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
        END
        ELSE
        BEGIN        
           SELECT @c_DynamicLoc_Zone = ISNULL(LOC.PickZone ,''), 
                  @c_Facility = LOC.Facility
           FROM   LOC (NOLOCK)
           WHERE  LOC = @c_StartDynamicLoc
    
           IF ISNULL(@c_DynamicLoc_Zone,'') <> 'LAUNCH'    
           BEGIN
              SELECT @n_continue = 3  
              SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81009   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
              SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Pick Zone for Dynamic Start location '+ RTRIM(@c_StartDynamicLoc)  +' Cannot Be Blank and Must be LAUNCH (ispRLWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
           END 
        END 
    END 

    -----Generate Launch Order Tasks-----    
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_Userdefine01 = 'L'
    BEGIN                                   
       --Dynamic pick loc in other replenishment task with same zone/facility
       INSERT INTO #DYNPICK_TASK (TOLOC)
       SELECT TD.TOLOC
       FROM   TASKDETAIL TD (NOLOCK)
              JOIN LOC (NOLOCK) ON  TD.TOLOC = LOC.LOC
       WHERE  LOC.LocationType IN('DYNPICKP','DYNPPICK') 
       --AND    LOC.PickZone = @c_DynamicLoc_Zone
       AND    LOC.Facility = @c_Facility
       AND    TD.Status = '0'
       AND    TD.Tasktype = 'RPF'
       --AND    TD.Sourcetype = 'ispRLWAV01-LAUNCH'
       GROUP BY TD.TOLOC
       HAVING SUM(TD.QTY) > 0

        --Dynamic pick loc with qty and same zone/facility 
       INSERT INTO #DYNPICK_NON_EMPTY (LOC)
       SELECT SKUxLOC.LOC
       FROM   SKUxLOC (NOLOCK)
              JOIN LOC (NOLOCK) ON SKUxLOC.LOC = LOC.LOC
       WHERE  LOC.LocationType IN ('DYNPICKP','DYNPPICK') 
       --AND    LOC.PickZone = @c_DynamicLoc_Zone 
       AND    LOC.Facility = @c_Facility
       GROUP BY SKUxLOC.LOC
       HAVING SUM(SKUxLOC.Qty - SKUxLOC.QtyPicked) > 0
              
       DECLARE cur_Launch CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT PD.Storerkey,
                 PD.Sku,
                 PD.Lot,
                 PD.Loc,
                 PD.ID,
                 SUM(PD.Qty),                          
                 CASE WHEN ISNULL(LI.LOCXID_QTYAVAILABLE,0) <= 0 AND LOC.LocationHandling = '1' AND LOC.LocationType <> 'DYNPPICK'  --Bulk & Pallet handling loc only
                      AND LI.SkuCount = 1 AND LI.LotCount = 1 
                      AND ( (LI.UOM2Count = 0 AND LI.UOM6Count > 0 AND LI.UOM7Count = 0) OR ((LI.UOM2Count > 0 OR LI.UOM7Count > 0) AND LI.UOM6Count = 0) OR --NJOW07
                            ((LI.UOM2Count > 0 OR LI.UOM7Count > 0) AND LI.UOM6Count > 0 AND PD.UOM <> '6') ) THEN --NJOW08
                          'FP'                          
                     ELSE 'PP' END AS PickMethod,
                 (SELECT TOP 1 Qty FROM UCC (NOLOCK) 
                  WHERE PD.Lot = UCC.Lot AND PD.Loc = UCC.Loc AND PD.Id = UCC.Id AND UCC.Status = '1') AS UCCQTY,
                 SKU.Style,
                 PD.UOM,
                 SKU.Putawayzone, --NJOW06                                                                           
                 LOC.LocationCategory --NJOW06
          FROM WAVEDETAIL WD (NOLOCK)
          JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
          JOIN #LOCXID_QTYAVAILABLE LI (NOLOCK) ON PD.Storerkey = LI.Storerkey AND PD.Loc = LI.Loc AND PD.Id = LI.Id
          JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
          JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
          JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc 
          WHERE WD.Wavekey = @c_Wavekey   
          AND LOC.LocationType NOT IN('DYNPICKP')  --Launch include replen from DPP to DP
--            AND SL.LocationType NOT IN('PICK','CASE')  -- Chee02
          GROUP BY PD.Storerkey,
                   PD.Sku,
                   PD.Lot,
                   PD.Loc,
                   PD.Id,
                   SKU.Style,
                   LI.LOCXID_QTYAVAILABLE,
                   LOC.LocationHandling,
                   PD.UOM,               
                   LOC.LocationType,
                   LI.SkuCount,
                   LI.LotCount,
                   SKU.Putawayzone, --NJOW06
                   LOC.LocationCategory, --NJOW06
                            LI.UOM2Count, --NJOW7
                            LI.UOM6Count, --NJOW7
                            LI.UOM7Count  --NJOW7
          ORDER BY PD.Storerkey, SKU.Style, PD.Sku, 
                   CASE WHEN ISNULL(LI.LOCXID_QTYAVAILABLE,0) <= 0 AND LOC.LocationHandling = '1' AND LOC.LocationType <> 'DYNPPICK'  --NJOW08
                        AND LI.SkuCount = 1 AND LI.LotCount = 1 
                        AND ((LI.UOM2Count > 0 OR LI.UOM7Count > 0) AND LI.UOM6Count > 0 AND PD.UOM = '6') THEN 0 ELSE 1 END,                  
                   8                          
      
       OPEN cur_Launch  
       FETCH NEXT FROM cur_Launch INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_PickMethod, @n_UCCQty, @c_Style, @c_UOM, @c_SkuPutawayzone, @c_LocationCategory
       
       SELECT @c_SourceType = 'ispRLWAV01-LAUNCH'    
       -- Assign Dynamic pick loc and Create Replenishment tasks
       WHILE @@FETCH_STATUS = 0 
       BEGIN               

           SELECT @n_UCCQty = ISNULL(@n_UCCQty,0)

          IF @n_debug=1
             SELECT '@c_Sku', @c_Sku, '@c_Lot', @c_Lot, '@c_FromLoc', @c_FromLoc, '@c_Id', @c_Id, '@c_PickMethond', @c_PickMethod, '@n_UCCQty', @n_UCCQty, '@c_Uom', @c_Uom, '@c_LocationCategory ',@c_LocationCategory  

            --NJOW06 Start
           SELECT @c_DynamicLoc_Zone = 'LAUNCH'
            
            IF @c_uom = '2' --full carton for an order send to direct out inducton
           BEGIN
              SELECT @c_DestinationType = 'DIRECT_LAUNCH'
              SELECT @c_ToLoc = 'IND1001'
           END
           ELSE IF @c_uom = '6' 
           BEGIN
              --full conso carton go to launch. A carton will be completely picked
              SELECT @c_DestinationType = 'LAUNCH'                
           END
           ELSE IF @c_uom = '7'  
           BEGIN
              --loose conso carton go to DPP. 
              SELECT @c_DestinationType = 'DPP_LAUNCH'  
           END
           ELSE
           BEGIN
              SELECT @c_DestinationType = 'LAUNCH'
           END                

          SELECT @c_Message03 = @c_DestinationType  

          IF @c_DestinationType = 'DIRECT_LAUNCH'
          BEGIN
             GOTO INSERT_TASKS
             DIRECT_LAUNCH:
          END
          --NJOW06 End
                                                          
          IF @c_DestinationType = 'LAUNCH' --NJOW06
          BEGIN
             SELECT @c_NextDynPickLoc = ''
             
             SELECT @n_UCCQty = ISNULL(@n_UCCQty,0)
             
             -- Rotate location mode triggered
             IF ISNULL(@c_LastRotateDynPickLoc,'') <> ''
             BEGIN
               --Try to combine same sku/UCC Qty into same loc
               SELECT TOP 1 @c_NextDynPickLoc = ToLoc 
               FROM #DYNPICK_LOCASSIGNED 
               WHERE Storerkey = @c_Storerkey
               AND Sku = @c_Sku
               AND LocationType = 'DYNPICKP' --NJOW06
               --AND UCCQty = @n_UCCQty                                              
                
               -- Rotate
               IF ISNULL(@c_NextDynPickLoc,'')=''
               BEGIN
                  SELECT TOP 1 @c_NextDynPickLoc = LOC.LOC
                  FROM   LOC (NOLOCK)
                  WHERE  LOC.LocationType IN ('DYNPICKP') 
                  AND    LOC.PickZone = @c_DynamicLoc_Zone 
                  AND    LOC.Facility = @c_Facility
                  AND    LOC.Loc > @c_LastRotateDynPickLoc
                  ORDER BY LOC.LOC
             
                  IF @n_debug=1
                     SELECT 'Rotate @c_NextDynPickLoc', @c_NextDynPickLoc, '@c_LastRotateDynPickLoc', @c_LastRotateDynPickLoc          
                     
                  IF ISNULL(@c_NextDynPickLoc,'')=''
                     GOTO TERMINATE                       
               END
               
               SELECT @c_LastRotateDynPickLoc = @c_NextDynPickLoc                            
             END
             
              -- Assign loc with same sku/ucc qty already assigned in current replenishment
             IF ISNULL(@c_NextDynPickLoc,'')=''
             BEGIN
                 SELECT TOP 1 @c_NextDynPickLoc = ToLoc 
                 FROM #DYNPICK_LOCASSIGNED 
                 WHERE @c_Storerkey = @c_Storerkey
                 AND Sku = @c_Sku
                 AND LocationType = 'LAUNCH' --NJOW06
                 --AND UCCQty = @n_UCCQty                                             
             END
                       
              -- Assign loc with same sku/ucc qty already assigned in other replenishment within same start loc and zone
             IF ISNULL(@c_NextDynPickLoc,'')=''
             BEGIN            
                 SELECT TOP 1 @c_NextDynPickLoc = LOC.LOC
                 FROM   TASKDETAIL TD (NOLOCK)
                 JOIN LOC (NOLOCK) ON TD.TOLOC = LOC.LOC
                 WHERE LOC.LocationType IN ('DYNPICKP') 
                 AND LOC.PickZone = @c_DynamicLoc_Zone 
                 AND LOC.Facility = @c_Facility
                     AND LOC.LOC >= @c_StartDynamicLoc 
                 AND TD.Status = '0'
                 AND TD.Qty > 0 
                 AND TD.Tasktype = 'RPF'
                 AND TD.Sourcetype = 'ispRLWAV01-LAUNCH'
                 AND TD.Storerkey = @c_Storerkey
                 AND TD.Sku = @c_Sku
                 --AND TD.UOMQty = @n_UCCQty              
             END
             
              -- Assign loc with same sku/UCC Qty and qty available
             IF ISNULL(@c_NextDynPickLoc,'')=''
             BEGIN              
                 SELECT TOP 1 @c_NextDynPickLoc = LOC.LOC
                 FROM LotxLocxID LLI (NOLOCK)
                 JOIN UCC (NOLOCK) ON LLI.Lot = UCC.Lot AND LLI.Loc = UCC.Loc AND LLI.Id = UCC.Id
                 JOIN LOC (NOLOCK) ON  LLI.LOC = LOC.LOC
                 WHERE LOC.LocationType IN ('DYNPICKP')
                 AND   LOC.PickZone = @c_DynamicLoc_Zone 
                 AND   LOC.Facility = @c_Facility
                     AND   LOC.LOC >= @c_StartDynamicLoc 
                 AND  (LLI.Qty - LLI.QtyPicked) > 0 
                 --AND  UCC.Qty = @n_UCCQty
                 AND  LLI.Storerkey = @c_Storerkey
                 AND  LLI.Sku = @c_Sku
             END
             
             -- If no location with same sku/UCC Qty found, then assign the empty location
             IF ISNULL(@c_NextDynPickLoc,'')=''
             BEGIN
                 SELECT TOP 1 @c_NextDynPickLoc = LOC.LOC
                 FROM   LOC (NOLOCK) 
                 WHERE  LOC.Facility = @c_Facility 
                 AND    LOC.LocationType IN ('DYNPICKP') 
                 AND    LOC.PickZone = @c_DynamicLoc_Zone 
                 AND    LOC.LOC >= @c_StartDynamicLoc 
                 AND    NOT EXISTS(
                            SELECT 1
                            FROM   #DYNPICK_NON_EMPTY E
                            WHERE  E.LOC = LOC.LOC
                        ) AND
                        NOT EXISTS(
                            SELECT 1
                            FROM   #DYNPICK_TASK AS ReplenLoc
                            WHERE  ReplenLoc.TOLOC = LOC.LOC
                        ) AND
                        NOT EXISTS(
                            SELECT 1
                            FROM   #DYNPICK_LOCASSIGNED AS DynPick
                            WHERE  DynPick.ToLoc = LOC.LOC
                        )
                 ORDER BY LOC.LogicalLocation, LOC.LOC
             END 
             
             --If no more DP loc then rotate
             /*
             IF ISNULL(@c_NextDynPickLoc,'')=''
             BEGIN
                SELECT @c_LastRotateDynPickLoc = @c_StartDynamicLoc
                SELECT @c_NextDynPickLoc = @c_StartDynamicLoc
             END
             */
                                                 
             -- Terminate. Can't find any dynamic location
             IF ISNULL(@c_NextDynPickLoc,'')=''
             BEGIN
                 SELECT @n_continue = 3  
                 SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Dynamic Pick Location Not Setup / Not enough Dynamic Pick Location. (ispRLWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                 GOTO RETURN_SP
             END 
             
             SELECT @c_ToLoc = @c_NextDynPickLoc
             
             IF @n_debug=1
                SELECT '@c_ToLoc', @c_ToLoc                                 
             
             --Insert/update current location assigned
             IF NOT EXISTS (SELECT 1 FROM #DYNPICK_LOCASSIGNED 
                            WHERE Storerkey = @c_Storerkey
                            AND Sku = @c_Sku
                            AND ToLoc = @c_ToLoc)
                            --AND UCCQty = @n_UCCQty)                                  
             BEGIN
                  --INSERT INTO #DYNPICK_LOCASSIGNED (Storerkey, Sku, ToLoc, UCCQty)
                  --VALUES (@c_Storerkey, @c_Sku, @c_Toloc, @n_UCCQty )
                  INSERT INTO #DYNPICK_LOCASSIGNED (Storerkey, Sku, ToLoc, LocationType) --NJOW06
                  VALUES (@c_Storerkey, @c_Sku, @c_Toloc, 'DYNPICKP')
             END
             
             --SELECT @c_DestinationType = 'LAUNCH'
             --SELECT @c_Message03 = @c_DestinationType
             GOTO INSERT_TASKS
             LAUNCH:
          END

          --NJOW06
          IF @c_DestinationType = 'DPP_LAUNCH' AND @c_LocationCategory = 'VNA' ----will consider PP first if found. Dynamic Permanent Pick(DPP) or Permanent Pick(PP)                
          BEGIN
              SELECT @c_NextDynPickLoc = ''              
              SELECT @c_DynamicLoc_Zone = @c_SkuPutawayzone 
              
              SELECT @c_Lottable01 = Lottable01, @c_Lottable02 = Lottable02, @c_Lottable03 = Lottable03
              FROM LOTATTRIBUTE (NOLOCK)
              WHERE LOT = @c_Lot 
              
              -- Assign loc with same sku qty already assigned in current replenishment
             IF ISNULL(@c_NextDynPickLoc,'')=''
             BEGIN
                 SELECT TOP 1 @c_NextDynPickLoc = DL.ToLoc
                 FROM #DYNPICK_LOCASSIGNED DL
                 JOIN LOTATTRIBUTE LA (NOLOCK) ON DL.Lot = LA.Lot
                 WHERE DL.Storerkey = @c_Storerkey
                 AND DL.Sku = @c_Sku
                 AND DL.LocationType IN('DYNPPICK')
                 AND LA.Lottable01 = @c_Lottable01
                 AND LA.Lottable02 = @c_Lottable02
                 AND LA.Lottable03 = @c_Lottable03
                 ORDER BY DL.ToLoc                     
             END                

              -- Assign pick loc (PP) if found
             IF ISNULL(@c_NextDynPickLoc,'')=''
             BEGIN
                 SELECT TOP 1 @c_NextDynPickLoc = SL.Loc
                 FROM SKUXLOC SL (NOLOCK)
                 WHERE SL.Storerkey = @c_Storerkey
                 AND SL.Sku = @c_Sku
                 AND SL.LocationType IN('CASE','PICK')
                 ORDER BY SL.Loc     
                 IF ISNULL(@c_NextDynPickLoc,'')<>''
                 BEGIN
                   SELECT @c_DestinationType = 'PP_LAUNCH' -- Permanent pick location
                   SELECT @c_Message03 = RTRIM(@c_Message03) + '-PP'
                 END              
             END                
                       
              -- Assign loc with same sku already assigned in other replenishment within same zone
             IF ISNULL(@c_NextDynPickLoc,'')=''
             BEGIN            
                 SELECT TOP 1 @c_NextDynPickLoc = L.LOC
                 FROM TASKDETAIL TD (NOLOCK)
                 JOIN LOC L (NOLOCK) ON TD.TOLOC = L.LOC
                 JOIN LOTATTRIBUTE LA (NOLOCK) ON TD.Lot = LA.Lot         
                 WHERE L.LocationType IN ('DYNPPICK') 
                 AND L.PutawayZone = @c_DynamicLoc_Zone 
                 --AND LOC.Facility = @c_Facility
                 AND TD.Status = '0'
                 AND TD.Qty > 0 
                 AND TD.Tasktype = 'RPF'
                 --AND TD.Sourcetype = 'ispRLWAV01-LAUNCH'
                 AND TD.Storerkey = @c_Storerkey
                 AND TD.Sku = @c_Sku
                 AND LA.Lottable01 = @c_Lottable01
                 AND LA.Lottable02 = @c_Lottable02
                 AND LA.Lottable03 = @c_Lottable03                    
                 ORDER BY L.LogicalLocation, L.Loc
             END
             
              -- Assign loc with same sku, Lottables and qty available / pending move in
             IF ISNULL(@c_NextDynPickLoc,'')=''
             BEGIN              
                 SELECT TOP 1 @c_NextDynPickLoc = L.LOC
                 FROM LOTXLOCXID LLI (NOLOCK)
                 JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
                 JOIN LOC L (NOLOCK) ON  LLI.LOC = L.LOC
                 WHERE L.LocationType IN ('DYNPPICK')
                 AND   L.PutawayZone = @c_DynamicLoc_Zone 
                 AND   L.Pickzone <> 'LAUNCH' 
                 --AND   LOC.Facility = @c_Facility
                 AND  ((LLI.Qty + LLI.PendingMoveIN) - LLI.QtyPicked) > 0 
                 AND  LLI.Storerkey = @c_Storerkey
                 AND  LLI.Sku = @c_Sku
                 AND LA.Lottable01 = @c_Lottable01
                 AND LA.Lottable02 = @c_Lottable02
                 AND LA.Lottable03 = @c_Lottable03                    
                 ORDER BY L.LogicalLocation, L.Loc
             END
             
             -- Assign empty loc that near to same style
             IF ISNULL(@c_NextDynPickLoc,'')=''
             BEGIN                                               
                 SELECT @c_SameStyleLoc = MAX(LLI.LOC)
                 FROM LOTXLOCXID LLI (NOLOCK)
                 JOIN LOC L (NOLOCK) ON  LLI.LOC = L.LOC
                 JOIN SKU S (NOLOCK) ON  LLI.Storerkey = S.Storerkey AND LLI.Sku = S.Sku
                 WHERE L.LocationType IN ('DYNPPICK')
                 AND   L.PutawayZone = @c_DynamicLoc_Zone 
                 AND   L.Pickzone <> 'LAUNCH' 
                 AND  ((LLI.Qty + LLI.PendingMoveIN) - LLI.QtyPicked) > 0 
                 AND  LLI.Storerkey = @c_Storerkey
                 AND  S.Style = @c_Style

                 SELECT TOP 1 @c_NextDynPickLoc = L.LOC
                 FROM   LOC L (NOLOCK) 
                 WHERE  L.LocationType IN ('DYNPPICK') 
                 --AND    LOC.Facility = @c_Facility
                 AND    L.PutawayZone = @c_DynamicLoc_Zone 
                 AND    L.LOC >= @c_SameStyleLoc
                 AND    NOT EXISTS(
                            SELECT 1
                            FROM   #DYNPICK_NON_EMPTY E
                            WHERE  E.LOC = L.LOC
                        ) AND
                        NOT EXISTS(
                            SELECT 1
                            FROM   #DYNPICK_TASK AS ReplenLoc
                            WHERE  ReplenLoc.TOLOC = L.LOC
                        ) AND
                        NOT EXISTS(
                            SELECT 1
                            FROM   #DYNPICK_LOCASSIGNED AS DynPick
                            WHERE  DynPick.ToLoc = L.LOC
                        ) AND --NJOW02
                        NOT EXISTS (
                            SELECT 1
                            FROM #TMP_PP_LOC AS PPLoc
                            WHERE PPLoc.Loc = L.LOC
                        )
                 ORDER BY L.LogicalLocation, L.Loc                    
             END
                             
             -- If no location with same sku found, then assign the empty location
             IF ISNULL(@c_NextDynPickLoc,'')=''
             BEGIN
                 SELECT TOP 1 @c_NextDynPickLoc = L.LOC
                 FROM   LOC L (NOLOCK) 
                 WHERE  L.LocationType IN ('DYNPPICK') 
                 --AND    LOC.Facility = @c_Facility
                 AND    L.PutawayZone = @c_DynamicLoc_Zone 
                 --AND    LOC.LOC >= @c_StartDynamicLoc 
                 AND    NOT EXISTS(
                            SELECT 1
                            FROM   #DYNPICK_NON_EMPTY E
                            WHERE  E.LOC = L.LOC
                        ) AND
                        NOT EXISTS(
                            SELECT 1
                            FROM   #DYNPICK_TASK AS ReplenLoc
                            WHERE  ReplenLoc.TOLOC = L.LOC
                        ) AND
                        NOT EXISTS(
                            SELECT 1
                            FROM   #DYNPICK_LOCASSIGNED AS DynPick
                            WHERE  DynPick.ToLoc = L.LOC
                        ) AND --NJOW02
                        NOT EXISTS (
                            SELECT 1
                            FROM #TMP_PP_LOC AS PPLoc
                            WHERE PPLoc.Loc = L.LOC
                        )
                        
                 ORDER BY L.LogicalLocation, L.Loc
             END
             
             -- if no more empty location, Assign loc with same sku and qty available / pending move in without check lottables
             IF ISNULL(@c_NextDynPickLoc,'')=''
             BEGIN              
                 SELECT TOP 1 @c_NextDynPickLoc = L.LOC
                 FROM LOTXLOCXID LLI (NOLOCK)
                 JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
                 JOIN LOC L (NOLOCK) ON  LLI.LOC = L.LOC
                 WHERE L.LocationType IN ('DYNPPICK')
                 AND   L.PutawayZone = @c_DynamicLoc_Zone 
                 AND   L.Pickzone <> 'LAUNCH' 
                 --AND   LOC.Facility = @c_Facility
                 AND  ((LLI.Qty + LLI.PendingMoveIN) - LLI.QtyPicked) > 0 
                 AND  LLI.Storerkey = @c_Storerkey
                 AND  LLI.Sku = @c_Sku
                 --AND LA.Lottable01 = @c_Lottable01
                 --AND LA.Lottable02 = @c_Lottable02
                 --AND LA.Lottable03 = @c_Lottable03                    
                 ORDER BY L.LogicalLocation, L.Loc
             END

              IF @n_debug = 1
                 SELECT 'DPP LAUNCH', '@c_NextDynPickLoc', @c_NextDynPickLoc
             
             -- Terminate. Can't find any dynamic location
             TERMINATE_LAUNCH:
             IF ISNULL(@c_NextDynPickLoc,'')=''
             BEGIN
                 SELECT @n_continue = 3  
                 SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81011   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Dynamic Pick Location Not Setup / Not enough Dynamic Pick Location. (ispRLWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                 GOTO RETURN_SP
             END 
          
             SELECT @c_ToLoc = @c_NextDynPickLoc
                                      
             --Insert current location assigned
             IF NOT EXISTS (SELECT 1 FROM #DYNPICK_LOCASSIGNED 
                            WHERE Storerkey = @c_Storerkey
                            AND Sku = @c_Sku
                            AND ToLoc = @c_ToLoc) AND @c_DestinationType = 'DPP_LAUNCH'
             BEGIN
                  INSERT INTO #DYNPICK_LOCASSIGNED (Storerkey, Sku, ToLoc, LocationType, Lot)
                  VALUES (@c_Storerkey, @c_Sku, @c_Toloc, 'DYNPPICK', @c_Lot )
             END

             GOTO INSERT_TASKS
             DPP_LAUNCH:            
          END --DPP                                                
          
          FETCH NEXT FROM cur_Launch INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_PickMethod, @n_UCCQty, @C_Style, @c_UOM, @c_SkuPutawayzone, @c_LocationCategory 
      END                       
      CLOSE cur_Launch  
      DEALLOCATE cur_Launch                                    
    END

    -----Generate XDock Move Tasks-----    
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_Userdefine01 = 'X'  --NJOW03
    BEGIN
       SET @c_Sku  = ''
       SET @n_UCCQty = 0
       SET @c_UOM = ''
       SET @c_Lot = ''
       SET @c_toloc  = 'IND1001'
       SET @c_PickMethod = 'FP'
       SET @c_DestinationType = 'XDOCKIND'
       SET @c_DynamicLoc_Zone = ''
       SET @c_Message03 = ''
       SET @c_SourceType = 'ispRLWAV01-XDOCK'    

       DECLARE cur_Xdock CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT PD.Storerkey, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty
          FROM WAVEDETAIL WD (NOLOCK)
          JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
          JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
          WHERE WD.Wavekey = @c_Wavekey
          GROUP BY PD.Storerkey, PD.Loc, PD.ID
          ORDER BY PD.Storerkey, PD.Loc, PD.ID
       
       OPEN cur_Xdock  
       FETCH NEXT FROM cur_Xdock INTO @c_Storerkey, @c_FromLoc, @c_ID, @n_Qty
       
       WHILE @@FETCH_STATUS = 0  
       BEGIN    
          GOTO INSERT_TASKS
          XDOCK:            
         
          FETCH NEXT FROM cur_Xdock INTO @c_Storerkey, @c_FromLoc, @c_ID, @n_Qty       
       END
       CLOSE cur_Xdock  
       DEALLOCATE cur_Xdock                                           
    END
    
    -----Generate Pickslip No-------
    IF (@n_continue = 1 or @n_continue = 2) AND @c_Userdefine01 <> 'E' --NJOW10
    BEGIN
       DECLARE CUR_ORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT OrderKey   
          FROM   WAVEDETAIL (NOLOCK)  
          WHERE  Wavekey = @c_wavekey   
  
       OPEN CUR_ORDER  
  
       FETCH NEXT FROM CUR_ORDER INTO @c_Orderkey   
  
       WHILE @@FETCH_STATUS <> -1  
       BEGIN  
          SET @c_PickSlipno = ''      
          SELECT @c_PickSlipno = PickheaderKey  
          FROM   PICKHEADER (NOLOCK)  
          WHERE  OrderKey = @c_OrderKey
          AND    Wavekey = @c_Wavekey
          AND    Zone = '8'
                             
          -- Create Pickheader      
          IF ISNULL(@c_PickSlipno, '') = ''  
          BEGIN  
             EXECUTE nspg_GetKey   
             'PICKSLIP',   9,   @c_Pickslipno OUTPUT,   @b_Success OUTPUT,   @n_err OUTPUT,   @c_errmsg OUTPUT      
                
             SELECT @c_Pickslipno = 'P' + @c_Pickslipno      
                        
             INSERT INTO PICKHEADER  
               (PickHeaderKey, Wavekey, Orderkey, PickType, Zone, TrafficCop)  
             VALUES  
               (@c_Pickslipno, @c_Wavekey, @c_OrderKey, '0' ,'8','')      
               
             SELECT @n_err = @@ERROR  
             IF @n_err <> 0  
             BEGIN  
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81011   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (ispRLWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
             END  
          END 
       
         -- tlting01
         SET @c_curPickdetailkey = ''
         DECLARE Orders_Pickdet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT Pickdetailkey
            FROM PICKDETAIL WITH (NOLOCK)  
            WHERE  OrderKey = @c_OrderKey  

         OPEN Orders_Pickdet_cur 
         FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey 
         WHILE @@FETCH_STATUS = 0 
         BEGIN 

                UPDATE PICKDETAIL WITH (ROWLOCK)  
                SET    PickSlipNo = @c_PickSlipNo    
                      ,EditWho    = SUSER_SNAME()    
                      ,EditDate   = GETDATE()                    
                      ,TrafficCop = NULL   
                WHERE PICKDETAIL.Pickdetailkey = @c_curPickdetailkey
                SELECT @n_err = @@ERROR  
                IF @n_err <> 0  
                BEGIN  
                   CLOSE Orders_Pickdet_cur 
                   DEALLOCATE Orders_Pickdet_cur                  
                   SELECT @n_continue = 3  
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81012   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKDETAIL Failed (ispRLWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                END        
            FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey
         END
         CLOSE Orders_Pickdet_cur 
         DEALLOCATE Orders_Pickdet_cur

          -- Chee01
          IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookUp WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
          BEGIN
             INSERT INTO dbo.RefKeyLookUp (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber)
             SELECT PickdetailKey, PickSlipNo, OrderKey, OrderLineNumber 
             FROM PICKDETAIL (NOLOCK)  
             WHERE PickSlipNo = @c_PickSlipNo  
             SELECT @n_err = @@ERROR  
             IF @n_err <> 0   
             BEGIN  
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81018     
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookUp Table Failed. (ispRLWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
             END   
          END        
            
          FETCH NEXT FROM CUR_ORDER INTO @c_OrderKey      
       END   
       CLOSE CUR_ORDER  
       DEALLOCATE CUR_ORDER 
    END      

    -----Update Wave Status-----
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN  
       UPDATE WAVE 
          --SET STATUS = '1' -- Released        --(Wan01) 
          SET TMReleaseFlag = 'Y'               --(Wan01) 
           ,  TrafficCop = NULL                 --(Wan01) 
           ,  EditWho = SUSER_SNAME()           --(Wan01) 
           ,  EditDate= GETDATE()               --(Wan01)
       WHERE WAVEKEY = @c_wavekey  
       SELECT @n_err = @@ERROR  
       IF @n_err <> 0  
       BEGIN  
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81013   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END  
    END  
   
RETURN_SP:

    IF @n_continue=3  -- Error Occured - Process And Return  
    BEGIN  
       SELECT @b_success = 0  
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV01"  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
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

 INSERT_TASKS:
 --function to insert taskdetail
 SELECT @b_success = 1  
 EXECUTE   nspg_getkey  
 "TaskDetailKey"  
 , 10  
 , @c_taskdetailkey OUTPUT  
 , @b_success OUTPUT  
 , @n_err OUTPUT  
 , @c_errmsg OUTPUT  
 IF NOT @b_success = 1  
 BEGIN  
    SELECT @n_continue = 3  
 END  

 IF @b_success = 1  
 BEGIN      
   INSERT TASKDETAIL  
    (  
      TaskDetailKey  
     ,TaskType  
     ,Storerkey  
     ,Sku  
     ,UOM  
     ,UOMQty  
     ,Qty  
     ,SystemQty
     ,Lot  
     ,FromLoc  
     ,FromID  
     ,ToLoc  
     ,ToID  
     ,SourceType  
     ,SourceKey  
     ,Priority  
     ,SourcePriority  
     ,Status  
     ,LogicalFromLoc  
     ,LogicalToLoc  
     ,PickMethod
     ,Wavekey
     --,Listkey  
     ,Message02  --NJOW04
     ,Areakey
     ,Message03
    )  
    VALUES  
    (  
      @c_taskdetailkey  
     ,@c_TaskType --Tasktype  --NJOW03
     ,@c_Storerkey  
     ,@c_Sku  
     ,@c_UOM -- UOM,  
     ,@n_UCCQty  -- UOMQty,  
     ,@n_Qty  
     ,@n_Qty  --systemqty
     ,@c_Lot   
     ,@c_fromloc   
     ,@c_ID -- from id  
     ,@c_toloc 
     ,@c_ID -- to id  
     ,@c_SourceType --Sourcetype  
     ,@c_Wavekey --Sourcekey  
     ,'5' -- Priority  
     ,'9' -- Sourcepriority  
     ,'0' -- Status  
     ,@c_FromLoc --Logical from loc  
     ,@c_ToLoc --Logical to loc  
     ,@c_PickMethod
     ,@c_Wavekey
     ,@c_DestinationType
     ,@c_DynamicLoc_Zone
     ,@c_Message03
    )
    
    SELECT @n_err = @@ERROR  
    IF @n_err <> 0  
    BEGIN
        SELECT @n_continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81014   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
        GOTO RETURN_SP
    END   
 END
 
 --Update/Insert pending move in when replen to DPP to cater for other Putaway and remain stock move from launch
 IF (@n_continue = 1 or @n_continue = 2) AND @c_DestinationType IN('DPP','PP','DPP_LAUNCH','PP_LAUNCH')  --NJOW06
 BEGIN     
     IF NOT EXISTS(SELECT 1 FROM LOTXLOCXID LLI(NOLOCK)
                   WHERE LLI.Storerkey = @c_Storerkey
                   AND LLI.Sku = @c_Sku 
                   AND LLI.Lot = @c_Lot
                   AND LLI.Loc = @c_Toloc
                   AND LLI.Id = @c_ID)
     BEGIN          
       IF NOT EXISTS (SELECT 1 FROM LOC(NOLOCK) WHERE Loc = @c_Toloc) --NJOW09
       BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81015   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Location ''' + RTRIM(@c_ToLoc) + ''' (ispRLWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
          GOTO RETURN_SP         
       END
       ELSE       
       BEGIN
          INSERT INTO LOTXLOCXID (Storerkey, Sku, Lot, Loc, ID, Qty, PendingMoveIN)          
                         VALUES (@c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ID, 0, @n_Qty)
       END
     END
     ELSE
     BEGIN
       UPDATE LOTXLOCXID WITH (ROWLOCK)
       SET PendingMoveIN = PendingMoveIN + @n_Qty
       WHERE Storerkey = @c_Storerkey
       AND Sku = @c_Sku
       AND Lot = @c_Lot
       AND Loc = @c_ToLoc
       AND ID = @c_ID
     END    
 END
 
 --Update taskdetailkey/wavekey to pickdetail
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
     SELECT @c_Pickdetailkey = '', @n_ReplenQty = @n_Qty
     WHILE @n_ReplenQty > 0 
    BEGIN                        
       --SET ROWCOUNT 1   
       
       SELECT TOP 1 @c_PickdetailKey = PICKDETAIL.Pickdetailkey, @n_PickQty = Qty
       FROM WAVEDETAIL (NOLOCK) 
       JOIN PICKDETAIL (NOLOCK) ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey
       WHERE WAVEDETAIL.Wavekey = @c_Wavekey
       AND ( PICKDETAIL.Taskdetailkey = '' OR PICKDETAIL.Taskdetailkey IS NULL )
       AND PICKDETAIL.Storerkey = @c_Storerkey
       AND PICKDETAIL.Sku = @c_sku
       AND PICKDETAIL.Lot = @c_Lot
       AND PICKDETAIL.Loc = @c_FromLoc
       AND PICKDETAIL.ID = @c_ID
       AND PICKDETAIL.UOM = @c_UOM
       AND PICKDETAIL.Pickdetailkey > @c_pickdetailkey
       ORDER BY PICKDETAIL.Pickdetailkey
       
       SELECT @n_cnt = @@ROWCOUNT
       --SET ROWCOUNT 0
       
       IF @n_cnt = 0
           BREAK
       
       IF @n_PickQty <= @n_ReplenQty
       BEGIN
          UPDATE PICKDETAIL WITH (ROWLOCK)
          SET Taskdetailkey = @c_TaskdetailKey,
              TrafficCop = NULL
          WHERE Pickdetailkey = @c_PickdetailKey
          SELECT @n_err = @@ERROR
          IF @n_err <> 0 
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81015   
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
             BREAK
         END 
         SELECT @n_ReplenQty = @n_ReplenQty - @n_PickQty
       END
       ELSE
       BEGIN  -- pickqty > replenqty   
          SELECT @n_SplitQty = @n_PickQty - @n_ReplenQty
          EXECUTE nspg_GetKey      
          'PICKDETAILKEY',      
          10,      
          @c_NewPickdetailKey OUTPUT,         
          @b_success OUTPUT,      
          @n_err OUTPUT,      
          @c_errmsg OUTPUT      
          IF NOT @b_success = 1      
          BEGIN
             SELECT @n_continue = 3      
             BREAK      
          END      
                
          INSERT PICKDETAIL      
                 (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                  Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,       
                  DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                  WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo )      
          SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,       
                 Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                 '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,       
                 ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,       
                 WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo
          FROM PICKDETAIL (NOLOCK)
          WHERE PickdetailKey = @c_PickdetailKey
                             
          SELECT @n_err = @@ERROR
          IF @n_err <> 0     
          BEGIN     
             SELECT @n_continue = 3      
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81016   
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
             BREAK    
          END
          
          UPDATE PICKDETAIL WITH (ROWLOCK)
          SET Taskdetailkey = @c_TaskdetailKey,
             Qty = @n_ReplenQty,
             UOMQTY = CASE UOM WHEN '6' THEN @n_ReplenQty ELSE UOMQty END,            
             TrafficCop = NULL
          WHERE Pickdetailkey = @c_PickdetailKey
          SELECT @n_err = @@ERROR
          IF @n_err <> 0 
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81017   
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
             BREAK
          END
          SELECT @n_ReplenQty = 0
       END     
     END -- While Qty > 0
 END        

 --return back to calling point
 IF @c_DestinationType = 'DIRECT'
    GOTO DIRECT
 IF @c_DestinationType = 'DP'
    GOTO DP
 IF @c_DestinationType IN ('DPP','PP')
    GOTO DPP
 IF @c_DestinationType = 'LAUNCH'
    GOTO LAUNCH
 IF @c_DestinationType = 'DIRECT_LAUNCH' --NJOW06
    GOTO DIRECT_LAUNCH
 IF @c_DestinationType IN('DPP_LAUNCH','PP_LAUNCH') --NJOW06
    GOTO DPP_LAUNCH
 IF @c_DestinationType = 'XDOCKIND'  --NJOW03
    GOTO XDOCK
      
 END --sp end

GO