SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: ispRLWAV27                                          */  
/* Creation Date: 21-JUN-2019                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-9242 - SG THGSG Release Wave                             */
/*                                                                       */  
/* Called By: wave                                                       */  
/*                                                                       */  
/* PVCS Version: 1.2                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */  
/*13/08/2019   WLChooi  1.1   Change validation - In case user forgot to */
/*                            release wave, user can still release wave  */
/*                            before packing takes place (WL01)          */
/* 01-04-2020  Wan01    1.2   Sync Exceed & SCE                          */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLWAV27]      
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
    
    DECLARE @n_continue int,    
            @n_starttcnt int,         -- Holds the current transaction count  
            @n_debug int,
            @n_cnt int
            
    SELECT  @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
    SELECT  @n_debug = 0

    DECLARE @c_Storerkey            NVARCHAR(15)
            ,@c_Facility            NVARCHAR(5)
            ,@c_TaskType            NVARCHAR(10)            
            ,@c_SourceType          NVARCHAR(30)
            ,@c_Priority            NVARCHAR(10)
            ,@c_Toloc               NVARCHAR(10)
            ,@c_PickMethod          NVARCHAR(10)
            ,@c_Message03           NVARCHAR(20)
            ,@c_PickCondition_SQL   NVARCHAR(4000)
            ,@c_LinkTaskToPick_SQL  NVARCHAR(4000)
            ,@c_ToLoc_Strategy      NVARCHAR(30)
            ,@c_ToLoc_StrategyParam NVARCHAR(4000)
            ,@c_DropID              NVARCHAR(20)
            ,@n_QtyShort            INT
            ,@n_QtyAvailable        INT
            ,@n_QtyReplen           INT
            ,@c_Sku                 NVARCHAR(20)
            ,@c_Lot                 NVARCHAR(10)
            ,@c_Loc                 NVARCHAR(10)
            ,@c_ID                  NVARCHAR(18)
            ,@c_ToID                NVARCHAR(18)
            ,@n_Qty                 INT
            ,@c_Orderkey            NVARCHAR(10)
            ,@n_CaseCnt             INT
            ,@c_UOM                 NVARCHAR(10)
            ,@n_UOMQty              INT
            ,@c_SourcePriority      NVARCHAR(10)
            ,@n_TotCtn              INT
            ,@n_InsertQty           INT
            ,@c_UCCNo               NVARCHAR(20)
            ,@d_Lottable05          DATETIME
            ,@c_UserDefine02        NVARCHAR(20)
            ,@c_LoadPlanGrp         NVARCHAR(10)
            ,@n_CountLOC            INT
            ,@n_CountOrd            INT
            ,@c_Loadkey             NVARCHAR(10)
            ,@c_Pickslipno          NVARCHAR(10)     
            ,@c_Pickzone            NVARCHAR(10)     
            ,@n_CountOrdGrp         INT
            ,@c_OrdGrp              NVARCHAR(20)
    
    CREATE TABLE #PTLLOC(
    ID               INT IDENTITY(1,1) NOT NULL,
    LOC              NVARCHAR(10) )

    CREATE TABLE #OrdKey(
    ID               INT IDENTITY(1,1) NOT NULL,
    Orderkey         NVARCHAR(10),
    OriginalQty      INT,
    GrossWgt         FLOAT )

    CREATE TABLE #PZ(
    ID               INT IDENTITY(1,1) NOT NULL,
    Loadkey          NVARCHAR(10),
    Pickzone         NVARCHAR(10),
    Pickslipno       NVARCHAR(10)
    )

    CREATE TABLE #OrderGroup(
    OrderGroup      NVARCHAR(20)
    )

    IF @@TRANCOUNT = 0
       BEGIN TRAN

    -----Get Storerkey, facility, WAVE.UserDefine02
    IF  (@n_continue = 1 OR @n_continue = 2)
    BEGIN
        SELECT TOP 1 @c_Storerkey    = O.Storerkey, 
                     @c_Facility     = O.Facility,
                     @c_UserDefine02 = W.UserDefine02,  
                     @c_LoadPlanGrp  = W.LoadPlanGroup 
        FROM WAVE W (NOLOCK)
        JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
        JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
        AND W.Wavekey = @c_Wavekey 
    END

    --WL01 Start
    -----Wave Validation-----            
    --IF @n_continue = 1 OR @n_continue = 2
    --BEGIN 
    --   IF NOT EXISTS (SELECT 1 
    --                  FROM WAVEDETAIL WD (NOLOCK)
    --                  JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
    --                  WHERE WD.Wavekey = @c_Wavekey                   
    --                  AND PD.Status = '0'
    --                 )
    --   BEGIN
    --      SELECT @n_continue = 3  
    --      SELECT @n_err = 83000  
    --      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV27)'       
    --   END      
    --END

    IF @n_continue = 1 OR @n_continue = 2
    BEGIN 
       IF NOT EXISTS (SELECT 1 
                      FROM WAVE W (NOLOCK)
                      WHERE W.Wavekey = @c_Wavekey              
                      AND W.[Status] = '0'     
                     )
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83000  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This wave has been released. (ispRLWAV27)'       
       END      
    END
    --WL01 End

    --For Wave Conso by Pickzone
    IF @n_continue IN(1,2)
    BEGIN
       INSERT INTO #PZ
       SELECT DISTINCT O.Loadkey, LOC.PICKZONE, ISNULL(PH.Pickheaderkey,'')  
       FROM WAVEDETAIL WD (NOLOCK)    
       JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
       JOIN ORDERDETAIL OD (NOLOCK) ON O.ORDERKEY = OD.ORDERKEY  
       JOIN PICKDETAIL PD (NOLOCK) ON PD.ORDERKEY = O.ORDERKEY AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER AND PD.SKU = OD.SKU
       JOIN LOC (NOLOCK) ON LOC.LOC = PD.LOC
       LEFT JOIN PICKHEADER PH (NOLOCK) ON O.Loadkey = PH.ExternOrderkey AND ISNULL(PH.Orderkey,'') = ''   
       WHERE WD.Wavekey = @c_wavekey 
       GROUP BY O.Loadkey, LOC.PICKZONE, ISNULL(PH.Pickheaderkey,'')  
       ORDER BY O.Loadkey, LOC.PICKZONE, ISNULL(PH.Pickheaderkey,'')   
    END         

    --Check OrdersGroup
    --MULTI - Assign to PTL
    --Single - Gen Pickslip only
    --Mixed - Prompt error and Quit
    IF @n_continue IN(1,2) 
    BEGIN
       INSERT INTO #OrderGroup
       SELECT DISTINCT LTRIM(RTRIM(ISNULL(O.ORDERGROUP,'')))
       FROM WAVEDETAIL WD (NOLOCK)
       JOIN WAVE W (NOLOCK) ON WD.Wavekey = W.Wavekey
       JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
       WHERE WD.Wavekey = @c_Wavekey

       SELECT @n_CountOrdGrp = COUNT(1)
       FROM #OrderGroup

       IF(@n_CountOrdGrp > 1) --Mixed
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83020  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Wave contain Multi and Single Orders. (ispRLWAV27)' 
       END
       ELSE IF @n_CountOrdGrp = 1
       BEGIN
          SELECT TOP 1 @c_OrdGrp = OrderGroup
          FROM #OrderGroup

          IF(@c_OrdGrp = 'SINGLE')
          BEGIN
             IF EXISTS (SELECT 1 FROM WAVE W (NOLOCK) 
                   WHERE W.Wavekey = @c_Wavekey
                   AND W.[Status] = '1')
             BEGIN
                SELECT @n_continue = 3  
                SELECT @n_err = 83025    
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has been released. (ispRLWAV27)'       
             END

             IF (@n_continue = 1 OR @n_continue = 2)
             BEGIN
                GOTO GENPICKSLIP
             END
          END
          ELSE IF(@c_OrdGrp NOT IN ('SINGLE','MULTI'))
          BEGIN
             SELECT @n_continue = 3  
             SELECT @n_err = 83030  
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Wave contain NEITHER Multi NOR Single Orders. (ispRLWAV27)' 
          END
       END
       ELSE
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83035  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found OrderGroup less than 1. (ispRLWAV27)' 
       END
    END
    
    --Single will not do the following part START
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_OrdGrp = 'MULTI'
    BEGIN
        IF EXISTS (SELECT 1 FROM OrderToLocDetail OTLD (NOLOCK) 
                   WHERE OTLD.Wavekey = @c_Wavekey
                   AND OTLD.StoreGroup = 'THGSG'
                   AND OTLD.PTSZone = @c_UserDefine02 )
        BEGIN
           SELECT @n_continue = 3  
           SELECT @n_err = 83037    
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has been released. (ispRLWAV27)'       
        END                 
    END

    --Save into temp table
    IF @n_continue IN(1,2) AND @c_OrdGrp = 'MULTI'
    BEGIN
       INSERT INTO #OrdKey
       SELECT O.Orderkey, SUM(OD.OriginalQty), SUM(SKU.GrossWgt) 
       FROM WAVEDETAIL WD (NOLOCK)
       JOIN WAVE W (NOLOCK) ON WD.Wavekey = W.Wavekey
       JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
       JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
       JOIN SKU (NOLOCK) ON O.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku  
       WHERE WD.Wavekey = @c_Wavekey   
       GROUP BY O.Orderkey

       SELECT @n_CountOrd = COUNT(1)
       FROM #OrdKey

       INSERT INTO #PTLLOC
       SELECT TOP (@n_CountOrd) LOC
       FROM LOC (NOLOCK)
       WHERE LOC.Putawayzone = @c_UserDefine02
       AND LOC.LocationType = 'PTL'
       AND LOC.LocationRoom = @c_Storerkey
       ORDER BY LOC.LogicalLocation, LOC.LOC
       
       SELECT @n_CountLoc = COUNT(1)
       FROM #PTLLOC

       IF (@n_CountOrd <> @n_CountLOC) --Check if there are enough LOC for orderkey in the wave
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83040  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not Enough LOC for Orders. (ispRLWAV27)' 
       END
    END 

    --Assign Orders to PTL location
    IF @n_continue IN(1,2) AND @c_OrdGrp = 'MULTI'
    BEGIN
       DECLARE cur_pick CURSOR FAST_FORWARD READ_ONLY FOR  
       SELECT O.Orderkey, P.LOC
       FROM #OrdKey O
       JOIN #PTLLOC P (NOLOCK) ON P.ID = O.ID
       GROUP BY O.Orderkey, P.LOC
       ORDER BY SUM(OriginalQty) DESC, SUM(GrossWgt) DESC   

       OPEN cur_pick  
       
       FETCH NEXT FROM cur_pick INTO @c_Orderkey, @c_Loc
       
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN
          INSERT INTO OrderToLocDetail (Orderkey, Loc, CartonID, Wavekey, PTSZone, Status, StoreGroup)
          VALUES(@c_Orderkey, @c_Loc, '', @c_Wavekey, @c_UserDefine02, 0, 'THGSG')

          SELECT @n_err = @@ERROR
          IF @n_err <> 0    
          BEGIN    
             SELECT @n_continue = 3    
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert OrderToLocDetail Failed (ispRLWAV27)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
          END
      
          FETCH NEXT FROM cur_pick INTO @c_Orderkey, @c_Loc
       END
       CLOSE cur_pick
       DEALLOCATE cur_pick       
    END
    --Single will not do the following part END
  
    -------Generate Pickslip No------
GENPICKSLIP:
    IF @n_continue = 1 or @n_continue = 2 
    BEGIN 
       --IF (@c_LoadPlanGrp = 'WVLPGRP01') --LP Group By Loadplan Conso
       --BEGIN
       --   EXEC isp_CreatePickSlip
       --        @c_Wavekey = @c_Wavekey
       --       ,@c_ConsolidateByLoad = 'Y'
       --       ,@c_LinkPickSlipToPick = 'N'  --Y=Update pickslipno to pickdetail.pickslipno 
       --  --     ,@c_Refkeylookup = 'Y'
       --       ,@c_AutoScanIn = 'N'  --Y=Auto scan in the pickslip N=Not auto scan in     
       --       ,@b_Success = @b_Success OUTPUT
       --       ,@n_Err = @n_err OUTPUT 
       --       ,@c_ErrMsg = @c_errmsg OUTPUT         
       --   IF @b_Success = 0
       --      SELECT @n_continue = 3  
       --END  --Load Conso
       --ELSE IF (@c_LoadPlanGrp = 'WVLPGRP02') --LP Group By Orderkey Discrete
       --BEGIN
          EXEC isp_CreatePickSlip
              @c_Wavekey = @c_WaveKey
             ,@c_ConsolidateByLoad = 'N'
             ,@c_LinkPickSlipToPick = 'N'  --Y=Update pickslipno to pickdetail.pickslipno 
             ,@c_AutoScanIn = 'N'  --Y=Auto scan in the pickslip N=Not auto scan in     
             ,@b_Success = @b_Success OUTPUT
             ,@n_Err = @n_err OUTPUT 
             ,@c_ErrMsg = @c_errmsg OUTPUT

          IF @b_Success = 0
             SELECT @n_continue = 3  
       --END  --Orderkey
       --ELSE IF (@c_LoadPlanGrp = 'WVLPGRP03') --LP Group By Pickzone
       --BEGIN 
       --   DECLARE CUR_WAVE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
       --     SELECT Loadkey, PickZone, Pickslipno
       --     FROM #PZ  
       --     ORDER BY Loadkey, Pickzone, Pickslipno
            
       --     OPEN CUR_WAVE  
            
       --     FETCH NEXT FROM CUR_WAVE INTO @c_Loadkey, @c_Pickzone, @c_Pickslipno  
       --     WHILE @@FETCH_STATUS <> -1
       --     BEGIN
       --        IF ISNULL(@c_Pickslipno,'') = ''   --Pickslipno
       --        BEGIN  
       --           EXECUTE nspg_GetKey 'PICKSLIP',   9,   @c_Pickslipno OUTPUT,   @b_Success OUTPUT,   @n_err OUTPUT,   @c_errmsg OUTPUT                        
       --           SELECT @c_Pickslipno = 'P' + @c_Pickslipno        
                  
       --           INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, Loadkey, Storerkey, Wavekey, ConsoOrderKey)    
       --           VALUES (@c_Pickslipno , @c_Loadkey, '', '0', '5', @c_Loadkey, @c_Storerkey, @c_wavekey, @c_Pickzone)                
                  
       --           SELECT @n_err = @@ERROR    
       --           IF @n_err <> 0    
       --           BEGIN    
       --              SELECT @n_continue = 3    
       --              SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       --              SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (ispRLWAV27)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
       --           END  

                  --UPDATE PICKDETAIL WITH (ROWLOCK)   
                  --SET  PICKDETAIL.Pickslipno = @c_Pickslipno
                  --    ,PICKDETAIL.TrafficCop = NULL  
                  --FROM PICKDETAIL
                  --JOIN LOC (NOLOCK) ON PICKDETAIL.LOC = LOC.LOC
                  --JOIN WAVEDETAIL (NOLOCK) ON WAVEDETAIL.ORDERKEY = PICKDETAIL.ORDERKEY
                  --JOIN LOADPLANDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey  
                  --WHERE WAVEDETAIL.Wavekey = @c_wavekey 
                  --AND LOADPLANDETAIL.LOADKEY = @c_Loadkey
                  --AND LOC.PICKZONE = @c_Pickzone
                  --AND PICKDETAIL.PickSlipNo <> @c_Pickslipno

                  --SELECT @n_err = @@ERROR    
                  --IF @n_err <> 0    
                  --BEGIN    
                  --   SELECT @n_continue = 3    
                  --   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                  --   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PICKDETAIL Failed (ispRLWAV27)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
                  --END 

                  --INSERT INTO RefKeyLookUp (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber)  
                  --SELECT DISTINCT PD.PickdetailKey, @c_Pickslipno, PD.OrderKey, PD.OrderLineNumber
                  --FROM LOADPLANDETAIL LD (NOLOCK)  
                  --JOIN PICKDETAIL PD (NOLOCK) ON LD.Orderkey = PD.Orderkey   
                  --JOIN LOC (NOLOCK) ON LOC.LOC = PD.LOC
                  --LEFT JOIN RefKeyLookup RKL (NOLOCK) ON PD.Pickdetailkey = RKL.Pickdetailkey               
                  --WHERE LD.Loadkey = @c_Loadkey AND LOC.Pickzone = @c_Pickzone
                  --AND RKL.Pickdetailkey IS NULL

                  --SELECT @n_err = @@ERROR    
                  --IF @n_err <> 0     
                  --BEGIN    
                  --   SELECT @n_continue = 3    
                  --   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                  --   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookUp Table Failed (ispRLWAV27)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
                  --END 
               --END  --Pickslipno
               --FETCH NEXT FROM CUR_WAVE INTO @c_Loadkey, @c_Pickzone, @c_Pickslipno  
            --END --CURSOR
       --END  --Pickzone    
    END    
            
    -----Update Wave Status-----
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN  
       UPDATE WAVE WITH (ROWLOCK)
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
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV27)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV27"  
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
 END --sp end

GO