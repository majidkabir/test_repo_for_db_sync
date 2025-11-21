SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/    
/* Stored Procedure: ispRLWAV05                                          */    
/* Creation Date: 29-Jan-2016                                            */    
/* Copyright: LF                                                         */    
/* Written by:                                                           */    
/*                                                                       */    
/* Purpose: SOS#359987 - CN Cartes SZ - Release Pick Task                */    
/*                                                                       */    
/* Called By: wave                                                       */    
/*                                                                       */    
/* PVCS Version: 2.0                                                     */    
/*                                                                       */    
/* Version: 5.4                                                          */    
/*                                                                       */    
/* Data Modifications:                                                   */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date        Author   Ver   Purposes                                   */    
/* 23/06/2016  NJOW01   1.0   359987-Update toloc to finalloc            */  
/* 25/07/2016  NJOW02   1.1   359987-remove finalloc                     */  
/* 13/08/2016  TLTING01 1.2   Performance tune                           */  
/* 01/11/2016  NJOW03   1.3   WMS-574 Traditional remove search DPP by   */  
/*                            same style and no assign empty loc with    */  
/*                            qty picked                                 */  
/* 07/11/2016  TLTING02 1.4   Performance tune                           */  
/* 12/02/2018  NJOW04   1.5   WMS-4039 Add Asia Ecom strategy            */  
/* 10/11/2018  NJOW05   1.6   WMS-6697 Change sorting for Hub            */  
/* 04/12/2018  NJOW06   1.7   INC0490581 - Tune Performace               */
/* 27/03/2019  AL01     1.8   INC0511813 Fix order by logicallocation    */
/* 22/01/2020  NJOW07   1.9   WMS-11884 Include skip hop task            */
/* 01-04-2020  Wan01    2.0   Sync Exceed & SCE                          */
/*************************************************************************/     
 
CREATE PROCEDURE [dbo].[ispRLWAV05]        
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
  
    DECLARE  @c_DispatchPiecePickMethod NVARCHAR(10)  
            ,@c_Userdefine02 NVARCHAR(20)  
            ,@c_Userdefine03 NVARCHAR(20)  
            ,@c_ShipTo       NVARCHAR(45)  --NJOW04  
            ,@c_OmniaOrderNo NVARCHAR(20)  
            ,@c_DeviceId NVARCHAR(20)  
            ,@c_IPAddress NVARCHAR(40)  
            ,@c_PortNo NVARCHAR(5)  
            ,@c_DevicePosition NVARCHAR(10)  
            ,@c_PTSLOC NVARCHAR(10)  
            ,@c_PTSStatus NVARCHAR(10)  
            ,@c_InLoc NVARCHAR(10)  
            ,@c_DropId NVARCHAR(20)              
            ,@c_Storerkey NVARCHAR(15)  
            ,@c_Sku NVARCHAR(20)  
            ,@c_Lot NVARCHAR(10)  
            ,@c_FromLoc NVARCHAR(10)  
            ,@c_ID NVARCHAR(18)  
            ,@n_Qty INT  
            ,@c_PickMethod NVARCHAR(10)  
            ,@c_Toloc NVARCHAR(10)  
            ,@c_Taskdetailkey NVARCHAR(10)    
            ,@n_UCCQty INT  
            ,@c_Style NVARCHAR(20)  
            ,@c_Facility NVARCHAR(5)  
            ,@c_NextDynPickLoc NVARCHAR(10)  
            ,@c_UOM NVARCHAR(10)  
            ,@c_DestinationType NVARCHAR(30)  
            ,@c_SameStyleLoc NVARCHAR(10)  
            ,@c_SameStyleLogicalLoc NVARCHAR(30)  
            ,@c_SourceType NVARCHAR(30)  
            ,@c_Pickdetailkey NVARCHAR(18)  
            ,@c_NewPickdetailKey NVARCHAR(18)  
            ,@n_Pickqty INT  
            ,@n_ReplenQty INT  
            ,@n_SplitQty  INT  
            ,@c_Message03 NVARCHAR(20)  
            ,@c_TaskType NVARCHAR(10)   
            ,@c_Orderkey NVARCHAR(10)  
            ,@c_Pickslipno NVARCHAR(10)  
            ,@c_Loadkey NVARCHAR(10)  
            ,@c_InductionLoc NVARCHAR(10)       
            ,@c_PTLWavekey NVARCHAR(10)  
            ,@c_PTLLoadkey NVARCHAR(10)      
            ,@c_LoadlineNumber NVARCHAR(5)   
            ,@c_Loctype NVARCHAR(10)  
            ,@c_curPickdetailkey NVARCHAR(10)  
            ,@c_Lottable01 NVARCHAR(18)  
            ,@n_UCCToFit INT  
            ,@n_UCCCnt INT            
            ,@dt_Lottable05 DATETIME --NJOW07  
  
    --NJOW05  
    DECLARE @cur_PICKSKU CURSOR,   
            @c_SortMode NVARCHAR(10)  
              
    -----Determine order type IFC(I) Or Traditional(T) Or Hub(H) or Asia Ecom(E) or Skip Hop(S)-----  
    IF @n_continue = 1 OR @n_continue = 2  
    BEGIN        
        SELECT TOP 1 @c_Userdefine02 = WAVE.UserDefine02,   
                     @c_Userdefine03 = WAVE.UserDefine03,   
                     @c_Facility = ORDERS.Facility,  
                     @c_DispatchPiecePickMethod = WAVE.DispatchPiecePickMethod,  
                     @c_Storerkey = ORDERS.Storerkey  
        FROM WAVE (NOLOCK)  
        JOIN WAVEDETAIL (NOLOCK) ON WAVE.Wavekey = WAVEDETAIL.WaveKey  
        JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey          
        WHERE WAVE.Wavekey = @c_Wavekey  
                           
        IF @n_debug=1  
           SELECT '@c_Userdefine02', @c_Userdefine02, '@c_Userdefine03', @c_Userdefine03, '@c_DispatchPiecePickMethod', @c_DispatchPiecePickMethod                     
    END  
      
    -----Get Induction Loc for full case-------  
    IF (@n_continue=1 or @n_continue=2) AND @c_DispatchPiecePickMethod IN('I','T','E','S')  --NJOW04  NJOW07
    BEGIN    
       SELECT TOP 1 @c_InductionLoc = CL.Short  
       FROM WAVE (NOLOCK)  
       JOIN CODELKUP CL (NOLOCK) ON WAVE.DispatchCasePickMethod = CL.Code AND CL.Listname = 'DICSEPKMTD'  
       WHERE WAVE.Wavekey = @c_Wavekey  
         
       IF ISNULL(@c_InductionLoc,'')=''  
       BEGIN  
           SELECT @n_continue = 3    
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Induction Not Yet Setup At Listname:DICSEPKMTD. (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
           GOTO RETURN_SP  
       END   
    END  
      
    -----Wave Validation-----  
    IF @n_continue=1 or @n_continue=2    
    BEGIN    
       IF ISNULL(@c_wavekey,'') = ''    
       BEGIN    
          SELECT @n_continue = 3    
          SELECT @n_err = 81010    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Parameters Passed (ispRLWAV05)'    
       END    
    END      
  
    IF @n_continue=1 or @n_continue=2    
    BEGIN            
       IF ISNULL(@c_DispatchPiecePickMethod,'') NOT IN('I','T','H','E','S')  --NJOW04 NJOW07
       BEGIN  
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Code to determine IFC or Traditional or Hub or Asia Ecom or Skip Hop (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
       END                  
    END  
  
    IF @n_continue=1 or @n_continue=2    
    BEGIN            
       IF ISNULL(@c_DispatchPiecePickMethod,'') IN('I','H') AND (ISNULL(@c_Userdefine02,'') = '' OR ISNULL(@c_Userdefine03,'') = '')  
       BEGIN           
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': For IFC/HUB must key-in location range at userdefine02&03 (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
       END                  
    END  
              
    IF @n_continue = 1 OR @n_continue = 2  
    BEGIN  
        IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK)   
                   WHERE TD.Wavekey = @c_Wavekey  
                   AND TD.Sourcetype IN('ispRLWAV05-IFC','ispRLWAV05-TRA','ispRLWAV05-HUB','ispRLWAV05-AE','ispRLWAV05-SH') --NJOW04  NJOW07
                   AND TD.Tasktype IN ('RPF'))   
        BEGIN  
           SELECT @n_continue = 3    
           SELECT @n_err = 81040    
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV05)'         
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
          SELECT @n_err = 81050    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Some orders of this Wave are started picking (ispRLWAV05)'           
        END                   
    END            
      
    --Create Temporary Tables  
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_DispatchPiecePickMethod IN ('T','H','E','S') --NJOW04   NJOW07
    BEGIN  
       --Current wave assigned dynamic pick location    
       CREATE TABLE #DYNPICK_LOCASSIGNED ( Rowref int not NULL identity(1,1) Primary Key  
                                          ,STORERKEY NVARCHAR(15) NULL  
                                          ,SKU NVARCHAR(20) NULL  
                                          ,TOLOC NVARCHAR(10) NULL  
                                          ,Lottable01 NVARCHAR(18) NULL  --NJOW04  
                                          ,Lottable05 DATETIME NULL  --NJOW07  
                                          ,LocationType NVARCHAR(10) NULL --NJOW04  
                                          ,UCCToFit INT DEFAULT(0) --NJOW04  
                                          ) --NJOW04  
       CREATE INDEX IDX_TOLOC ON #DYNPICK_LOCASSIGNED (TOLOC)      --NJOW06
       
       IF @c_DispatchPiecePickMethod IN('T','E','S') --NJOW04  NJOW07
       BEGIN  
          CREATE TABLE #DYNPICK_TASK (Rowref int not NULL identity(1,1) Primary Key  
                                    ,TOLOC NVARCHAR(10) NULL)      
  
          CREATE TABLE #DYNPICK_NON_EMPTY (Rowref int not NULL identity(1,1) Primary Key  
                                    ,LOC NVARCHAR(10) NULL)    
                                    
                                      
          CREATE TABLE #DYNLOC (Rowref int not NULL identity(1,1) Primary KEY
                      ,Loc NVARCHAR(10) NULL
                      ,logicallocation NVARCHAR(18) NULL
                      ,MaxPallet INT NULL)
               CREATE INDEX IDX_DLOC ON #DYNLOC (LOC)    --NJOW06
                      
                      
               CREATE TABLE #EXCLUDELOC (Rowref int not NULL identity(1,1) Primary Key  
                          ,LOC NVARCHAR(10) NULL)
               CREATE INDEX IDX_LOC ON #EXCLUDELOC (LOC)    --NJOW06                      
                                                                 
       END  
    END                                              
      
    -----Generate Traditional,Asia Ecom and Skip Hop Temporary Ref Data-----  
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_DispatchPiecePickMethod IN ('T','E','S') --NJOW04  NJOW07
    BEGIN                  
         INSERT INTO #DYNLOC (Loc, LogicalLocation)            -- AL01
            SELECT Loc, LogicalLocation                             -- AL01
            FROM LOC (NOLOCK)
            WHERE Facility = @c_Facility 
            AND LocationType = 'DYNPPICK'
            AND LocationCategory = 'SHELVING'      --NJOW06
             
        --location have pending Replenishment tasks  
        INSERT INTO #DYNPICK_TASK (TOLOC)  
        SELECT TD.TOLOC  
        FROM   TASKDETAIL TD (NOLOCK)  
        JOIN   LOC L (NOLOCK) ON  TD.TOLOC = L.LOC  
        WHERE  L.LocationType IN('DYNPPICK','DYNPICKP')  --NJOW04   
        AND    L.LocationCategory IN ('SHELVING')   
        AND    L.Facility = @c_Facility  
        AND    TD.Status = '0'          
        AND    TD.Tasktype IN('RPF','RP1','RPT')  
        --AND    TD.Sourcetype = 'ispRLWAV05-TRA'  
        GROUP BY TD.TOLOC  
        HAVING SUM(TD.Qty) > 0  
                  
         --Dynamic pick loc have qty and pending move in  
        INSERT INTO #DYNPICK_NON_EMPTY (LOC)  
        SELECT LLI.LOC  
       FROM   LOTXLOCXID LLI (NOLOCK)  
        JOIN   LOC L (NOLOCK) ON LLI.LOC = L.LOC  
        WHERE  L.LocationType IN ('DYNPPICK','DYNPICKP')  --NJOW04   
        AND    L.Facility = @c_Facility  
        GROUP BY LLI.LOC  
        HAVING SUM(LLI.Qty + LLI.PendingMoveIN) > 0  --NJOW03        
        --HAVING SUM((LLI.Qty + LLI.PendingMoveIN) - LLI.QtyPicked ) > 0      
        
        INSERT INTO #EXCLUDELOC (Loc)
        SELECT E.LOC
        FROM   #DYNPICK_NON_EMPTY E 
        UNION ALL SELECT ReplenLoc.TOLOC
        FROM   #DYNPICK_TASK  ReplenLoc            --NJOW06            
    END  
      
    -----Generate HUB Temporary Ref Data-----  
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_DispatchPiecePickMethod IN ('H')  
    BEGIN                  
       --NJOW05  
       SELECT TOP 1 @c_SortMode = UDF01  
       FROM CODELKUP (NOLOCK)  
       WHERE ListName = 'CARSORT'  
       AND Code = @c_Facility  
       AND Storerkey = @c_Storerkey  
         
       IF ISNULL(@c_SortMode,'') = ''  
          SET @c_SortMode = 'S1'  
         
        IF @c_SortMode = 'S2'  
        BEGIN  
          SET @cur_PICKSKU =   
             CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
                  SELECT PD.Storerkey, PD.SKU, LA.Lottable01 --NJOW04  
                  FROM WAVEDETAIL WD (NOLOCK)  
                  JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey  
                  JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku --NJOW04  
                  JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot --NJOW04  
                  JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
                  JOIN SKUXLOC (NOLOCK) ON PD.Storerkey = SKUXLOC.Storerkey AND PD.Sku = SKUXLOC.Sku AND PD.Loc = SKUXLOC.Loc  
                  WHERE WD.Wavekey = @c_Wavekey  
                  AND LOC.LocationType NOT IN('DYNPPICK','DYNPICKP') --NJOW04  
                  AND LOC.LocationCategory NOT IN('SHELVING')   
                  AND SKUXLOC.LocationType NOT IN ('PICK','CASE')  
                  GROUP BY PD.Storerkey, SKU.Measurement, PD.SKU, LA.Lottable01  --NJOW04                      
                  ORDER BY PD.Storerkey, PD.Sku, LA.Lottable01  --NJOW04                
        END  
        ELSE  
        BEGIN --S1  
          SET @cur_PICKSKU =   
              CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
                  SELECT PD.Storerkey, PD.SKU, LA.Lottable01 --NJOW04  
                  FROM WAVEDETAIL WD (NOLOCK)  
                  JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey  
                  JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku --NJOW04  
                  JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot --NJOW04  
                  JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
                  JOIN SKUXLOC (NOLOCK) ON PD.Storerkey = SKUXLOC.Storerkey AND PD.Sku = SKUXLOC.Sku AND PD.Loc = SKUXLOC.Loc  
                  WHERE WD.Wavekey = @c_Wavekey  
                  AND LOC.LocationType NOT IN('DYNPPICK','DYNPICKP') --NJOW04  
                  AND LOC.LocationCategory NOT IN('SHELVING')   
                  AND SKUXLOC.LocationType NOT IN ('PICK','CASE')  
                  GROUP BY PD.Storerkey, SKU.Measurement, PD.SKU, LA.Lottable01  --NJOW04                      
                  ORDER BY PD.Storerkey, SKU.Measurement, PD.Sku, LA.Lottable01  --NJOW04                
        END         
  
         OPEN @cur_PICKSKU    
         FETCH NEXT FROM @cur_PICKSKU INTO @c_Storerkey, @c_Sku, @c_Lottable01 --NJOW04  
  
         WHILE @@FETCH_STATUS = 0    
         BEGIN                       
            SET @c_ToLoc = ''  
                         
            SELECT TOP 1 @c_ToLoc = LOC.Loc  
            FROM LOC (NOLOCK)  
            LEFT JOIN #DYNPICK_LOCASSIGNED ON LOC.Loc = #DYNPICK_LOCASSIGNED.ToLoc  
            WHERE LOC.LocationCategory = 'PTL'  
            AND LOC.Loc BETWEEN @c_Userdefine02 AND @c_Userdefine03  
            AND LOC.Facility = @c_Facility  
            AND #DYNPICK_LOCASSIGNED.ToLoc IS NULL  
            ORDER BY LOC.Loc  
  
            IF ISNULL(@c_ToLoc,'')=''  
            BEGIN  
                SELECT @n_continue = 3    
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81008   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PTL Location Not Setup / Not enough PTL Location. (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
                GOTO RETURN_SP  
            END   
              
            INSERT INTO #DYNPICK_LOCASSIGNED (Storerkey, Sku, ToLoc, Lottable01)  --NJOW04  
            VALUES (@c_Storerkey, @c_Sku, @c_ToLoc, @c_Lottable01) --NJOW04  
              
            FETCH NEXT FROM @cur_PICKSKU INTO @c_Storerkey, @c_Sku, @c_Lottable01 --NJOW04  
         END  
         CLOSE @cur_PICKSKU    
         DEALLOCATE @cur_PICKSKU                                     
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
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
               END    
        FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey  
       END  
       CLOSE Orders_Pickdet_cur   
       DEALLOCATE Orders_Pickdet_cur  
    END  
       
    -----Generate IFC / Traditional Order / HUB Tasks / Asia Ecom / Skip Hop-----  
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_DispatchPiecePickMethod IN('I','T','H','E','S') --NJOW04  NJOW07
    BEGIN  
       DECLARE cur_PICKUCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
        SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, PD.UOM, PD.DropID,  
               CASE WHEN MIN(PD.PickMethod) = 'P' THEN   
                         'FP'                            
                    ELSE 'PP' END AS PickMethod,  
               SKU.Style,  
               ISNULL(UCC.Qty,0) AS UCCQty,  
               ISNULL(MAX(O.Loadkey),'') AS Loadkey,  
               CASE WHEN LOC.LocationType NOT IN('DYNPPICK','DYNPICKP') AND LOC.LocationCategory <> 'SHELVING' AND SKUXLOC.LocationType NOT IN ('PICK','CASE')   --NJOW04  
                  THEN 'BULK' ELSE 'DPP' END,  
               CASE WHEN @c_DispatchPiecePickMethod IN('T','H','E','S') THEN LA.Lottable01 ELSE '' END, --NJOW004  NJOW07
               CASE WHEN @c_DispatchPiecePickMethod IN('S') THEN LA.Lottable05 ELSE NULL END --NJOW07
        FROM WAVEDETAIL WD (NOLOCK)  
        JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey  
        JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot --NJOW04  
        JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
        JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
        JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku  
        JOIN SKUXLOC (NOLOCK) ON PD.Storerkey = SKUXLOC.Storerkey AND PD.Sku = SKUXLOC.Sku AND PD.Loc = SKUXLOC.Loc  
        LEFT JOIN UCC (NOLOCK) ON PD.DropId = UCC.UccNo  
        WHERE WD.Wavekey = @c_Wavekey  
          ---AND LOC.LocationType NOT IN('DYNPPICK')  
          ---AND LOC.LocationCategory NOT IN('SHELVING')   
          ---AND SKUXLOC.LocationType NOT IN ('PICK','CASE')  
        GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM, SKU.Style, PD.DropID, ISNULL(UCC.Qty,0),  
                 CASE WHEN LOC.LocationType NOT IN('DYNPPICK','DYNPICKP') AND LOC.LocationCategory <> 'SHELVING' AND SKUXLOC.LocationType NOT IN ('PICK','CASE')  --NJOW04  
                    THEN 'BULK' ELSE 'DPP' END,  
                 CASE WHEN @c_DispatchPiecePickMethod IN ('T','H','E','S') THEN LA.Lottable01 ELSE '' END,  --NJOW004   NJOW07
                 CASE WHEN @c_DispatchPiecePickMethod IN('S') THEN LA.Lottable05 ELSE NULL END --NJOW07
        ORDER BY PD.Storerkey, PD.UOM, SKU.Style, PD.Sku, PD.Lot  
                 
       OPEN cur_PICKUCC    
       FETCH NEXT FROM cur_PICKUCC INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @c_DropID, @c_PickMethod, @c_Style, @n_UCCQty, @c_Loadkey, @c_LocType,  
                                        @c_Lottable01, @dt_Lottable05 --NJOW04 NJOW07
         
       IF @c_DispatchPiecePickMethod = 'I'  
          SELECT @c_SourceType = 'ispRLWAV05-IFC'  
       ELSE IF @c_DispatchPiecePickMethod = 'T'  
          SELECT @c_SourceType = 'ispRLWAV05-TRA'   
       ELSE IF @c_DispatchPiecePickMethod = 'H'                          
          SELECT @c_SourceType = 'ispRLWAV05-HUB'   
       ELSE IF @c_DispatchPiecePickMethod = 'E'   --NJOW04                       
          SELECT @c_SourceType = 'ispRLWAV05-AE'   
       ELSE IF @c_DispatchPiecePickMethod = 'S'   --NJOW07
          SELECT @c_SourceType = 'ispRLWAV05-SH'   
            
       SELECT @c_TaskType = 'RPF'  
       SELECT @c_ToLoc = ''  
       SELECT @c_Message03 = ''  
         
       WHILE @@FETCH_STATUS = 0    
       BEGIN   
             --Only IFC will consider DPP location for PTS booking but without taskdetail. If bulk do booking and gen taskdetail                      
             IF @c_DispatchPiecePickMethod IN ('T','H','E','S') AND @c_LocType = 'DPP'   --NJOW04  NJOW07
                GOTO PICKUCC_NEXT_REC             
                  
             --Determine destination direct/dpp/pts/ptl                            
             IF @c_DispatchPiecePickMethod = 'H' --HUB  
             BEGIN  
                SELECT @c_DestinationType = 'PTL'  
             END  
             ELSE  
             BEGIN  
                IF @c_uom = '2'  
                BEGIN  
                    SELECT @c_DestinationType = 'DIRECT'  
                END  
                ELSE -- uom 6 & 7  
                BEGIN  
                    IF @c_DispatchPiecePickMethod = 'I'  --IFC  
                       SELECT @c_DestinationType = 'PTS'                   
                    ELSE IF @c_DispatchPiecePickMethod = 'T' --Traditional  
                       SELECT @c_DestinationType = 'DPP'                         
                    ELSE IF @c_DispatchPiecePickMethod = 'E' AND @c_UOM = '6'  --Asia Ecom conso carton  NJOW04  
                       SELECT @c_DestinationType = 'DP'                                               
                    ELSE IF @c_DispatchPiecePickMethod = 'E' AND @c_UOM = '7'  --Asia Ecom loose  NJOW04  
                       SELECT @c_DestinationType = 'DPP'         
                    ELSE IF @c_DispatchPiecePickMethod = 'S'  --SKIP HOP  NJOW07
                       SELECT @c_DestinationType = 'DPP_SH'                                             
                END  
             END  
  
             --SELECT @c_Message03 = @c_DestinationType  
               
             IF @n_debug=1  
                SELECT '@c_FromLoc', @c_FromLoc, '@c_ID', @c_ID, '@n_Qty', @n_qty, '@c_UOM', @c_UOM, '@c_Lot', @c_Lot, '@n_UCCQty', @n_UCCQty,  
                       '@c_PickMethod', @c_PickMethod, '@c_Style', @c_Style, '@c_DropID', @c_DropID, '@c_DestinationType', @c_DestinationType, '@c_Loadkey', @c_Loadkey  
                                                      
             IF @c_DestinationType = 'DIRECT' --Full carton for an order  
             BEGIN  
               SELECT @c_ToLoc = @c_InductionLoc  
                 
                GOTO INSERT_TASKS  
                DIRECT:  
             END --DIRECT  
                            
             IF @c_DestinationType = 'PTS' --IFC Put To Light(store)  
             BEGIN  
               DECLARE cur_UCCDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
                SELECT O.M_Address4, O.Userdefine03, O.Loadkey   --NJOW04  
                FROM WAVEDETAIL WD (NOLOCK)  
               JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
                JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey  
                WHERE WD.Wavekey = @c_Wavekey  
                AND PD.DropID = @c_DropID  
                AND PD.Storerkey = @c_Storerkey  
                AND PD.Sku = @c_Sku  
                AND PD.Loc = @c_FromLoc  
                AND PD.ID = @c_ID  
                AND PD.Lot = @c_Lot  
                GROUP BY O.M_Address4, O.Userdefine03, O.Loadkey  --NJOW04  
                  
                OPEN cur_UCCDetail    
                FETCH NEXT FROM cur_UCCDetail INTO @c_ShipTo, @c_OmniaOrderNo, @c_Loadkey  
                  
                WHILE @@FETCH_STATUS = 0    
                BEGIN                        
                   SELECT @c_DeviceId = '', @c_IPAddress = '', @c_PortNo = '', @c_DevicePosition = '', @c_PTSLOC = '', @c_PTSStatus = '', @c_InLoc = ''  
  
                  SELECT TOP 1 @c_DeviceId = DP.DeviceID,   
                               @c_IPAddress = DP.IPAddress,   
                               @c_PortNo = DP.PortNo,   
                               @c_DevicePosition = DP.DevicePosition,   
                               @c_PTSLOC = LOC.Loc,  
                               @c_PTSStatus = CASE WHEN ISNULL(PTL.ShipTo,'') <> '' THEN 'OLD' ELSE 'NEW' END,  
                               @c_InLoc = PZ.InLoc,  
                               @c_PTLWavekey = ISNULL(PTL.Wavekey,''),  
                               @c_PTLLoadkey = ISNULL(PTL.Loadkey,'')  
                  FROM LOC (NOLOCK)   
                  JOIN DEVICEPROFILE DP (NOLOCK) ON LOC.Loc = DP.Loc   
                  JOIN PUTAWAYZONE PZ (NOLOCK) ON LOC.Putawayzone = PZ.Putawayzone  
                  LEFT JOIN RDT.rdtPTLStationLog PTL (NOLOCK) ON LOC.Loc = PTL.Loc   
                  WHERE LOC.Loc BETWEEN @c_Userdefine02 AND @c_Userdefine03                    
                  AND LOC.LocationCategory = 'PTS'  
                  AND LOC.Facility = @c_Facility                                      
                  AND (PTL.RowRef IS NULL   
                       OR (PTL.ShipTo = @c_ShipTo AND PTL.Userdefine01 = @c_OmniaOrderNo) --AND PTL.Wavekey = @c_Wavekey)  
                       )  
                  ORDER BY CASE WHEN ISNULL(PTL.Wavekey,'') = @c_Wavekey THEN 0 ELSE 1 END, ISNULL(PTL.ShipTo,'') DESC, ISNULL(PTL.Userdefine01,'') DESC, LOC.LogicalLocation, LOC.Loc  
  
                   IF ISNULL(@c_PTSLOC,'')=''  
                   BEGIN  
                       SELECT @n_continue = 3    
                       SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                       SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PTS Location Not Setup / Not enough PTS Location. (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
                       GOTO RETURN_SP  
                   END   
                    
                  IF @c_PTSStatus = 'NEW' OR @c_Wavekey <> @c_PTLWavekey --no PTL booking or similar booking but by different wave  
                  BEGIN  
                     IF ISNULL(@c_PTLLoadkey,'') <> ''  
                     BEGIN  
                        INSERT INTO RDT.rdtPTLStationLog (Station, IPAddress, Position, Loc, Wavekey, Storerkey, ShipTo, Userdefine01, Loadkey)  
                        VALUES (@c_DeviceId, @c_IPAddress, @c_DevicePosition, @c_PTSLoc, @c_Wavekey, @c_Storerkey, @c_ShipTo, @c_OmniaOrderNo, @c_PTLLoadkey)   
                     END  
                     ELSE  
                     BEGIN  
                        INSERT INTO RDT.rdtPTLStationLog (Station, IPAddress, Position, Loc, Wavekey, Storerkey, ShipTo, Userdefine01, Loadkey)  
                        VALUES (@c_DeviceId, @c_IPAddress, @c_DevicePosition, @c_PTSLoc, @c_Wavekey, @c_Storerkey, @c_ShipTo, @c_OmniaOrderNo, @c_Loadkey)   
                     END  
                       
                      SELECT @n_err = @@ERROR    
                      IF @n_err <> 0    
                      BEGIN  
                          SELECT @n_continue = 3    
                          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RTD.rdtPTLStationLog Failed. (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
                          GOTO RETURN_SP  
                      END     
                  END  
                    
                  --Move order to exising open carton load  
                  IF @c_Loadkey <> @c_PTLLoadkey AND ISNULL(@c_PTLLoadkey,'') <> '' AND @c_PTSStatus = 'OLD'   
                  BEGIN  
                     IF NOT EXISTS (SELECT 1 FROM LOADPLAN (NOLOCK) WHERE Loadkey = @c_PTLLoadkey)  
                     BEGIN  
                         SELECT @n_continue = 3    
                         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81082   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Load# ''' + RTRIM(@c_PTLLoadkey) + ''' Found at open carton. (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
                         GOTO RETURN_SP  
                     END  
  
                     DECLARE cur_LoadOrder CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                         
                         SELECT DISTINCT O.Orderkey  
                         FROM WAVEDETAIL WD (NOLOCK)                                                           
                         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey                                                             
                         WHERE WD.Wavekey = @c_Wavekey                                                         
                         AND O.M_Address4 = @c_ShipTo --NJOW04  
                         AND O.Userdefine03 = @c_OmniaOrderNo  
                         AND O.Loadkey = @c_Loadkey  
                                                                                                            
                      OPEN cur_LoadOrder                                                                    
                      FETCH NEXT FROM cur_LoadOrder INTO @c_Orderkey  
                                                                                                            
                      WHILE @@FETCH_STATUS = 0                                                              
                      BEGIN                                                                                                        
                        SELECT TOP 1 @c_LoadLineNumber = LoadLineNumber  
                        FROM LOADPLANDETAIL(NOLOCK)  
                        WHERE Loadkey = @c_Loadkey  
                        AND Orderkey = @c_Orderkey  
                         
                        EXEC isp_MoveOrderToLoad  
                          @c_LoadKey          
                         ,@c_LoadlineNumber   
                         ,@c_PTLLoadkey      OUTPUT    
                         ,@b_success         OUTPUT  
                         ,@n_err             OUTPUT  
                         ,@c_errmsg          OUTPUT      
  
                         IF @b_success <> 1    
                         BEGIN  
                             SELECT @n_continue = 3    
                             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81084   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Move Load Plan Order Failed. (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
                             GOTO RETURN_SP  
                         END                              
                         
                         FETCH NEXT FROM cur_LoadOrder INTO @c_Orderkey  
                      END  
                      CLOSE cur_LoadOrder    
                      DEALLOCATE cur_LoadOrder                                     
                  END  
                           
                  SELECT @c_ToLoc = @c_InLoc  
                    
                   FETCH NEXT FROM cur_UCCDetail INTO @c_ShipTo, @c_OmniaOrderNo, @c_Loadkey  
                END  
                CLOSE cur_UCCDetail    
                DEALLOCATE cur_UCCDetail                                     
   
                IF @c_LocType = 'BULK'  
                BEGIN  
                   GOTO INSERT_TASKS  
                   PTS:              
                END  
             END --PTS  
               
             IF @c_DestinationType = 'DPP'  --Traditional or Asia Ecom Dynamic Pick Loc for loose  NJOW04  
             BEGIN  
                SELECT @c_NextDynPickLoc = ''  
                                    
                 -- Assign loc with same sku qty already assigned in current replenishment  
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN  
                    SELECT TOP 1 @c_NextDynPickLoc = DL.ToLoc  
                    FROM #DYNPICK_LOCASSIGNED DL  
                    WHERE DL.Storerkey = @c_Storerkey  
                    AND DL.Sku = @c_Sku  
                    AND DL.Lottable01 = @c_Lottable01 --NJOW04  
                    AND DL.LocationType = 'DPP' --NJOW04  
                    ORDER BY DL.ToLoc                       
                END                  
                            
                 -- Assign loc with same sku already assigned in other replenishment not yet start  
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN              
                    SELECT TOP 1 @c_NextDynPickLoc = L.LOC  
                    FROM TASKDETAIL TD (NOLOCK)  
                    JOIN LOTATTRIBUTE LA (NOLOCK) ON TD.Lot = LA.Lot --NJOW04  
                    JOIN LOC L (NOLOCK) ON TD.TOLOC = L.LOC                      
                    WHERE L.LocationType IN ('DYNPPICK')   
                    AND L.LocationCategory IN ('SHELVING')  
                    AND L.Facility = @c_Facility  
                    AND TD.Status = '0'  
                    AND TD.Qty > 0   
                    AND TD.Tasktype = 'RPF'  
                    AND LA.Lottable01 = @c_Lottable01  --NJOW04                     
                    --AND TD.Sourcetype = 'ispRLWAV05-TRA'  
                    AND TD.Storerkey = @c_Storerkey  
                    AND TD.Sku = @c_Sku  
                    ORDER BY L.LogicalLocation, L.Loc  
                END  
  
                 -- Assign loc with same sku already assigned in other replenishment but in transit  
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN              
                    SELECT TOP 1 @c_NextDynPickLoc = L.LOC  
                    FROM TASKDETAIL TD (NOLOCK)  
                    JOIN LOC L (NOLOCK) ON TD.TOLOC = L.LOC                      
                    JOIN LOTATTRIBUTE LA (NOLOCK) ON TD.Lot = LA.Lot --NJOW04  
                    WHERE L.LocationType IN ('DYNPPICK')   
                    AND L.LocationCategory IN ('SHELVING')  
                    AND L.Facility = @c_Facility  
                    AND TD.Status = '0'  
                    AND TD.Qty > 0   
                    AND TD.Tasktype IN('RP1','RPT')  
                    AND LA.Lottable01 = @c_Lottable01 --NJOW04  
                    --AND TD.Sourcetype = 'ispRLWAV05-TRA'  
                    AND TD.Storerkey = @c_Storerkey  
                    AND TD.Sku = @c_Sku  
                    ORDER BY L.LogicalLocation, L.Loc  
                END  
                  
      -- Assign loc with same sku and qty available / pending move in  
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN                
                    SELECT TOP 1 @c_NextDynPickLoc = L.LOC  
                    FROM LOTXLOCXID LLI (NOLOCK)  
                    JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot --NJOW04  
                    JOIN LOC L (NOLOCK) ON  LLI.LOC = L.LOC  
                    WHERE L.LocationType IN('DYNPPICK')  
                    AND L.LocationCategory IN ('SHELVING')  
                    AND   L.Facility = @c_Facility  
                    AND  (LLI.Qty + LLI.PendingMoveIN) > 0  --NJOW03  
                    AND LA.Lottable01 = @c_Lottable01 --NJOW04  
                    --AND  ((LLI.Qty + LLI.PendingMoveIN) - LLI.QtyPicked) > 0   
                    AND  LLI.Storerkey = @c_Storerkey  
                    AND  LLI.Sku = @c_Sku  
                    ORDER BY L.LogicalLocation, L.Loc  
                END  
                  
                -- Assign empty loc that near to same style  
                /*  --NJOW03 Removed  
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN    
                                                               
                   SET @c_SameStyleLoc = ''   
                   SET @c_SameStyleLogicalLoc = ''   
                    SELECT @c_SameStyleLoc = ISNULL(MAX(LLI.LOC),''),  
                           @c_SameStyleLogicalLoc = ISNULL(MAX(L.LogicalLocation),'')  
                    FROM LOTXLOCXID LLI (NOLOCK)  
                    JOIN LOC L (NOLOCK) ON  LLI.LOC = L.LOC  
                    JOIN SKU S (NOLOCK) ON  LLI.Storerkey = S.Storerkey AND LLI.Sku = S.Sku  
                    WHERE L.LocationType IN ('DYNPPICK')  
                    AND L.LocationCategory IN ('SHELVING')  
                    AND  ((LLI.Qty + LLI.PendingMoveIN) - LLI.QtyPicked) > 0   
                    AND  LLI.Storerkey = @c_Storerkey  
                    AND  S.Style = @c_Style                      
  
                    SELECT TOP 1 @c_NextDynPickLoc = L.LOC  
                    FROM   LOC L (NOLOCK)   
                    WHERE  L.LocationType IN ('DYNPPICK')   
                    AND    L.LocationCategory IN ('SHELVING')  
                    AND    L.Facility = @c_Facility  
                    AND    ((L.LOC >= @c_SameStyleLoc AND ISNULL(@c_SameStyleLogicalLoc,'') = '')  
                         OR (L.LogicalLocation >= @c_SameStyleLogicalLoc AND ISNULL(@c_SameStyleLogicalLoc,'') <> ''))  
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
                           )   
                    ORDER BY L.LogicalLocation, L.Loc                      
                END  
                */  
                                  
                -- If no location with same sku sytle found, then assign the empty location  
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN  
                    SELECT TOP 1 @c_NextDynPickLoc = L.LOC  
                              FROM   #DYNLOC L (NOLOCK) 
                              LEFT JOIN #EXCLUDELOC EL ON L.Loc = EL.Loc
                              LEFT JOIN #DYNPICK_LOCASSIGNED DynPick ON L.Loc = DynPick.TOLOC
                              WHERE EL.Loc IS NULL
                              AND DynPick.Toloc IS NULL
                              ORDER BY L.LogicalLocation, L.Loc  --NJOW06

                    --FROM   LOC L (NOLOCK)   
                    --WHERE  L.LocationType = 'DYNPPICK'         --IN ('DYNPPICK')   
                    --AND    L.LocationCategory = 'SHELVING'     --IN ('SHELVING')  
                    --AND    L.Facility = @c_Facility  
                    --AND    NOT EXISTS ( SELECT 1 FROM (  
                    --       SELECT E.LOC  
                    --       FROM   #DYNPICK_NON_EMPTY E   
                    --       UNION ALL SELECT ReplenLoc.TOLOC  
                    --       FROM   #DYNPICK_TASK  ReplenLoc   
                    --       UNION ALL SELECT DynPick.ToLoc  
                    --       FROM       #DYNPICK_LOCASSIGNED  DynPick   
                    -- )  AS A WHERE A.Loc = L.LOC )  
                    -- ORDER BY L.LogicalLocation, L.Loc  
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
                    --       )  
                    --ORDER BY L.LogicalLocation, L.Loc  
                END  
                  
                IF @n_debug = 1  
                   SELECT 'DPP', '@c_NextDynPickLoc', @c_NextDynPickLoc  
                  
                -- Terminate. Can't find any dynamic location  
                TERMINATE:  
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN  
                    SELECT @n_continue = 3    
                    SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                    SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Dynamic Pick Location Not Setup / Not enough Dynamic Pick Location. (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
                    GOTO RETURN_SP  
                END   
            
                SELECT @c_ToLoc = @c_NextDynPickLoc  
                                           
                --Insert current location assigned  
                IF NOT EXISTS (SELECT 1 FROM #DYNPICK_LOCASSIGNED   
                               WHERE Storerkey = @c_Storerkey  
                               AND Sku = @c_Sku  
                               AND ToLoc = @c_ToLoc  
                               AND Lottable01 = @c_Lottable01) --NJOW04  
                BEGIN  
                     INSERT INTO #DYNPICK_LOCASSIGNED (Storerkey, Sku, ToLoc, Lottable01, LocationType)   --NJOW04  
                     VALUES (@c_Storerkey, @c_Sku, @c_Toloc, @c_Lottable01, 'DPP')  
                END  
  
                GOTO INSERT_TASKS  
                DPP:              
             END --DPP                     

             IF @c_DestinationType = 'DPP_SH'  --Skip Hop Dynamic Pick Loc for loose  NJOW07 
             BEGIN  
                SELECT @c_NextDynPickLoc = ''  
                                                                    
                 -- Assign loc with same sku qty already assigned in current replenishment  
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN  
                    SELECT TOP 1 @c_NextDynPickLoc = DL.ToLoc  
                    FROM #DYNPICK_LOCASSIGNED DL  
                    WHERE DL.Storerkey = @c_Storerkey  
                    AND DL.Sku = @c_Sku  
                    AND DL.Lottable01 = @c_Lottable01 --NJOW04  
                    AND DL.Lottable05 = @dt_Lottable05 --NJOW07
                    AND DL.LocationType = 'DPP' --NJOW04  
                    ORDER BY DL.ToLoc                       
                END                  
                            
                -- Assign pick loc of the sku if setup skuxloc.locationtype = 'PICK'
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN  
                   SELECT TOP 1 @c_NextDynPickLoc = SL.Loc
                   FROM SKUXLOC SL (NOLOCK)
                   WHERE SL.Storerkey = @c_Storerkey
                   AND SL.Sku = @c_Sku
                   AND SL.LocationType = 'PICK'
                   ORDER BY SL.Loc
                END                
                            
                -- Assign loc with same sku already assigned in other replenishment not yet start  
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN              
                    SELECT TOP 1 @c_NextDynPickLoc = L.LOC  
                    FROM TASKDETAIL TD (NOLOCK)  
                    JOIN LOTATTRIBUTE LA (NOLOCK) ON TD.Lot = LA.Lot --NJOW04  
                    JOIN LOC L (NOLOCK) ON TD.TOLOC = L.LOC                      
                    WHERE L.LocationType IN ('DYNPPICK')   
                    AND L.LocationCategory IN ('SHELVING')  
                    AND L.Facility = @c_Facility  
                    AND TD.Status = '0'  
                    AND TD.Qty > 0   
                    AND TD.Tasktype = 'RPF'  
                    AND LA.Lottable01 = @c_Lottable01  --NJOW04                     
                    AND LA.Lottable05 = @dt_Lottable05 --NJOW07                    
                    --AND TD.Sourcetype = 'ispRLWAV05-TRA'  
                    AND TD.Storerkey = @c_Storerkey  
                    AND TD.Sku = @c_Sku  
                    ORDER BY L.LogicalLocation, L.Loc  
                END  
  
                 -- Assign loc with same sku already assigned in other replenishment but in transit  
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN              
                    SELECT TOP 1 @c_NextDynPickLoc = L.LOC  
                    FROM TASKDETAIL TD (NOLOCK)  
                    JOIN LOC L (NOLOCK) ON TD.TOLOC = L.LOC                      
                    JOIN LOTATTRIBUTE LA (NOLOCK) ON TD.Lot = LA.Lot --NJOW04  
                    WHERE L.LocationType IN ('DYNPPICK')   
                    AND L.LocationCategory IN ('SHELVING')  
                    AND L.Facility = @c_Facility  
                    AND TD.Status = '0'  
                    AND TD.Qty > 0   
                    AND TD.Tasktype IN('RP1','RPT')  
                    AND LA.Lottable01 = @c_Lottable01 --NJOW04  
                    AND LA.Lottable05 = @dt_Lottable05 --NJOW07                    
                    --AND TD.Sourcetype = 'ispRLWAV05-TRA'  
                    AND TD.Storerkey = @c_Storerkey  
                    AND TD.Sku = @c_Sku  
                    ORDER BY L.LogicalLocation, L.Loc  
                END  
                  
                -- Assign loc with same sku and qty available / pending move in  
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN                
                    SELECT TOP 1 @c_NextDynPickLoc = L.LOC  
                    FROM LOTXLOCXID LLI (NOLOCK)  
                    JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot --NJOW04  
                    JOIN LOC L (NOLOCK) ON  LLI.LOC = L.LOC  
                    WHERE L.LocationType IN('DYNPPICK')  
                    AND L.LocationCategory IN ('SHELVING')  
                    AND   L.Facility = @c_Facility  
                    AND  (LLI.Qty + LLI.PendingMoveIN) > 0  --NJOW03  
                    AND LA.Lottable01 = @c_Lottable01 --NJOW04  
                    AND LA.Lottable05 = @dt_Lottable05 --NJOW07                    
                    --AND  ((LLI.Qty + LLI.PendingMoveIN) - LLI.QtyPicked) > 0   
                    AND  LLI.Storerkey = @c_Storerkey  
                    AND  LLI.Sku = @c_Sku  
                    ORDER BY L.LogicalLocation, L.Loc  
                END                                   
                                            
                -- If no location with same sku sytle found, then assign the empty location  
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN  
                    SELECT TOP 1 @c_NextDynPickLoc = L.LOC  
                              FROM   #DYNLOC L (NOLOCK) 
                              LEFT JOIN #EXCLUDELOC EL ON L.Loc = EL.Loc
                              LEFT JOIN #DYNPICK_LOCASSIGNED DynPick ON L.Loc = DynPick.TOLOC
                              WHERE EL.Loc IS NULL
                              AND DynPick.Toloc IS NULL
                              ORDER BY L.LogicalLocation, L.Loc  --NJOW06
                END  
                  
                IF @n_debug = 1  
                   SELECT 'DPP', '@c_NextDynPickLoc', @c_NextDynPickLoc  
                  
                -- Terminate. Can't find any dynamic location  
                --TERMINATE:  
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN  
                    SELECT @n_continue = 3    
                    SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                    SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Dynamic Pick Location Not Setup / Not enough Dynamic Pick Location. (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
                    GOTO RETURN_SP  
                END   
            
                SELECT @c_ToLoc = @c_NextDynPickLoc  
                                           
                --Insert current location assigned  
                IF NOT EXISTS (SELECT 1 FROM #DYNPICK_LOCASSIGNED   
                               WHERE Storerkey = @c_Storerkey  
                               AND Sku = @c_Sku  
                               AND ToLoc = @c_ToLoc  
                               AND Lottable01 = @c_Lottable01
                               AND Lottable05 = @dt_Lottable05) --NJOW04  
                BEGIN  
                     INSERT INTO #DYNPICK_LOCASSIGNED (Storerkey, Sku, ToLoc, Lottable01, LocationType, Lottable05)   --NJOW04  
                     VALUES (@c_Storerkey, @c_Sku, @c_Toloc, @c_Lottable01, 'DPP',@dt_Lottable05)  
                END  
  
                GOTO INSERT_TASKS  
                DPP_SH:              
             END --DPP-SH                     
               
             IF @c_DestinationType = 'PTL' --HUB processing  
             BEGIN                                
                SELECT @c_NextDynPickLoc = ''  
                                    
                 -- Assign loc with same sku   
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN  
                    SELECT TOP 1 @c_NextDynPickLoc = DL.ToLoc  
                    FROM #DYNPICK_LOCASSIGNED DL  
                    JOIN LOC (NOLOCK) ON DL.ToLoc = LOC.Loc  
                    WHERE DL.Storerkey = @c_Storerkey  
                    AND DL.Sku = @c_Sku  
                    AND DL.Lottable01 = @c_Lottable01 --NJOW04  
                    ORDER BY LOC.LogicalLocation, DL.ToLoc                       
                END                  
                            
                IF @n_debug = 1  
                   SELECT 'PTL', '@c_NextDynPickLoc', @c_NextDynPickLoc  
                  
                -- Terminate. Can't find any dynamic location  
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN  
                    SELECT @n_continue = 3    
                    SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                    SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PTL Location Not Setup / Not enough PTL Location. (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
                    GOTO RETURN_SP  
                END   
            
                SELECT @c_ToLoc = @c_NextDynPickLoc  
                                           
                GOTO INSERT_TASKS  
                PTL:              
             END --PTL  
  
             IF @c_DestinationType = 'DP'  --Asia Ecom Dynamic pick loc for conso carton  NJOW04  
             BEGIN  
                SELECT @c_NextDynPickLoc = ''  
                SELECT @n_UCCToFit = 0  
                SELECT @n_UCCCnt = 0  
                                    
                 -- Assign loc with same sku qty already assigned in current replenishment  
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN  
                    SELECT TOP 1 @c_NextDynPickLoc = DL.ToLoc,  
                                 @n_UCCToFit = DL.UCCToFit  
                    FROM #DYNPICK_LOCASSIGNED DL  
                    WHERE DL.Storerkey = @c_Storerkey  
                    AND DL.Sku = @c_Sku  
                    AND DL.Lottable01 = @c_Lottable01 --NJOW04  
                    AND DL.LocationType = 'DP' --NJOW04  
                    AND DL.UCCToFit > 0  
                    ORDER BY DL.ToLoc                       
                END                  
                            
                 -- Assign loc with same sku already assigned in other replenishment not yet start  
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN                                 
                    SELECT TOP 1 @c_NextDynPickLoc = L.LOC,   
                                 @n_UCCToFit = L.Maxpallet - COUNT(DISTINCT TD.CaseID)  
                    FROM TASKDETAIL TD (NOLOCK)  
                    JOIN LOTATTRIBUTE LA (NOLOCK) ON TD.Lot = LA.Lot --NJOW04  
                    JOIN LOC L (NOLOCK) ON TD.TOLOC = L.LOC                      
                    WHERE L.LocationType IN ('DYNPICKP')   
                    AND L.LocationCategory IN ('SHELVING')  
                    AND L.Facility = @c_Facility  
                    AND TD.Status = '0'  
                    AND TD.Qty > 0   
                    AND TD.Tasktype = 'RPF'  
                    AND LA.Lottable01 = @c_Lottable01  --NJOW04                     
                    --AND TD.Sourcetype = 'ispRLWAV05-TRA'  
                    AND TD.Storerkey = @c_Storerkey  
                    AND TD.Sku = @c_Sku  
                    GROUP BY L.LogicalLocation, L.Loc, L.Maxpallet  
                    HAVING COUNT(DISTINCT TD.CaseID) < L.Maxpallet  
                    ORDER BY L.LogicalLocation, L.Loc  
                      
                    SELECT @n_UCCCnt = CEILING(SUM(LLI.Qty) / (@n_UCCQty * 1.00))  
                    FROM LOTXLOCXID LLI (NOLOCK)  
                    WHERE LLI.Storerkey = @c_Storerkey  
                    AND LLI.Sku = @c_Sku  
                    AND LLI.Loc = @c_NextDynPickLoc  
                      
                    IF @n_UCCCnt > 0  
                    BEGIN  
                      SELECT @n_UCCToFit = @n_UCCToFit - @n_UCCCnt  
                    END  
                      
                    IF @n_UCCToFit <= 0   
                       SELECT @c_NextDynPickLoc = ''                          
                END  
  
                 -- Assign loc with same sku already assigned in other replenishment but in transit  
                /*
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN              
                    SELECT TOP 1 @c_NextDynPickLoc = L.LOC  
                    FROM TASKDETAIL TD (NOLOCK)  
                    JOIN LOC L (NOLOCK) ON TD.TOLOC = L.LOC                      
                    JOIN LOTATTRIBUTE LA (NOLOCK) ON TD.Lot = LA.Lot --NJOW04  
                    WHERE L.LocationType IN ('DYNPPICK')   
                    AND L.LocationCategory IN ('SHELVING')  
                    AND L.Facility = @c_Facility  
                    AND TD.Status = '0'  
                    AND TD.Qty > 0   
                    AND TD.Tasktype IN('RP1','RPT')  
                    AND LA.Lottable01 = @c_Lottable01 --NJOW04  
                    --AND TD.Sourcetype = 'ispRLWAV05-TRA'  
                    AND TD.Storerkey = @c_Storerkey  
                    AND TD.Sku = @c_Sku  
                    ORDER BY L.LogicalLocation, L.Loc  
                END
                */  
                  
                 -- Assign loc with same sku and qty available / pending move in  
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN                
                    SELECT TOP 1 @c_NextDynPickLoc = L.LOC,  
                                 @n_UCCToFit = L.Maxpallet - CEILING(SUM(LLI.Qty + LLI.PendingMoveIN) / (@n_UCCQty * 1.00))  
                    FROM LOTXLOCXID LLI (NOLOCK)  
                    JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot --NJOW04  
                    JOIN LOC L (NOLOCK) ON  LLI.LOC = L.LOC  
                    WHERE L.LocationType IN('DYNPICKP')  
                    AND L.LocationCategory IN ('SHELVING')  
                    AND   L.Facility = @c_Facility  
                    AND  (LLI.Qty + LLI.PendingMoveIN) > 0  --NJOW03  
                    AND LA.Lottable01 = @c_Lottable01 --NJOW04  
                    --AND  ((LLI.Qty + LLI.PendingMoveIN) - LLI.QtyPicked) > 0   
                    AND  LLI.Storerkey = @c_Storerkey  
                    AND  LLI.Sku = @c_Sku  
                    GROUP BY L.LogicalLocation, L.Loc, L.MaxPallet  
                    HAVING CEILING(SUM(LLI.Qty + LLI.PendingMoveIN) / (@n_UCCQty * 1.00)) < L.MaxPallet  
                    ORDER BY L.LogicalLocation, L.Loc  
                END  
                  
                -- Assign empty loc that near to same style  
                /*  --NJOW03 Removed  
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN    
                                                               
                   SET @c_SameStyleLoc = ''   
                   SET @c_SameStyleLogicalLoc = ''   
                    SELECT @c_SameStyleLoc = ISNULL(MAX(LLI.LOC),''),  
                           @c_SameStyleLogicalLoc = ISNULL(MAX(L.LogicalLocation),'')  
                    FROM LOTXLOCXID LLI (NOLOCK)  
                    JOIN LOC L (NOLOCK) ON  LLI.LOC = L.LOC  
                    JOIN SKU S (NOLOCK) ON  LLI.Storerkey = S.Storerkey AND LLI.Sku = S.Sku  
                    WHERE L.LocationType IN ('DYNPPICK')  
                    AND L.LocationCategory IN ('SHELVING')  
                    AND  ((LLI.Qty + LLI.PendingMoveIN) - LLI.QtyPicked) > 0   
                    AND  LLI.Storerkey = @c_Storerkey  
                    AND  S.Style = @c_Style                      
  
                    SELECT TOP 1 @c_NextDynPickLoc = L.LOC  
                    FROM   LOC L (NOLOCK)   
                    WHERE  L.LocationType IN ('DYNPPICK')   
                    AND    L.LocationCategory IN ('SHELVING')  
                    AND    L.Facility = @c_Facility  
                    AND    ((L.LOC >= @c_SameStyleLoc AND ISNULL(@c_SameStyleLogicalLoc,'') = '')  
                         OR (L.LogicalLocation >= @c_SameStyleLogicalLoc AND ISNULL(@c_SameStyleLogicalLoc,'') <> ''))  
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
                           )   
                    ORDER BY L.LogicalLocation, L.Loc                      
                END  
                */  
                                  
                -- If no location with same sku sytle found, then assign the empty location  
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN  
                    SELECT TOP 1 @c_NextDynPickLoc = L.LOC,  
                                 @n_UCCToFit = L.MaxPallet  
                              FROM   #DYNLOC L (NOLOCK) 
                              LEFT JOIN #EXCLUDELOC EL ON L.Loc = EL.Loc
                           LEFT JOIN #DYNPICK_LOCASSIGNED DynPick ON L.Loc = DynPick.TOLOC
                              WHERE EL.Loc IS NULL
                           AND DynPick.Toloc IS NULL
                          ORDER BY L.LogicalLocation, L.Loc    --NJOW06

                    --FROM   LOC L (NOLOCK)   
                    --WHERE  L.LocationType = 'DYNPICKP'         --IN ('DYNPPICK')   
                    --AND    L.LocationCategory = 'SHELVING'     --IN ('SHELVING')  
                    --AND    L.Facility = @c_Facility  
                    --AND    NOT EXISTS ( SELECT 1 FROM (  
                    --       SELECT E.LOC  
                    --       FROM   #DYNPICK_NON_EMPTY E   
                    --       UNION ALL SELECT ReplenLoc.TOLOC  
                    --       FROM   #DYNPICK_TASK  ReplenLoc   
                    --       UNION ALL SELECT DynPick.ToLoc  
                    --       FROM  #DYNPICK_LOCASSIGNED  DynPick   
                    -- )  AS A WHERE A.Loc = L.LOC )  
                    -- ORDER BY L.LogicalLocation, L.Loc  
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
                    --       )  
                    --ORDER BY L.LogicalLocation, L.Loc  
                END  
                  
                IF @n_debug = 1  
                   SELECT 'DP', '@c_NextDynPickLoc', @c_NextDynPickLoc  
                  
                -- Terminate. Can't find any dynamic location  
                --TERMINATE:  
                IF ISNULL(@c_NextDynPickLoc,'')=''  
                BEGIN  
                    SELECT @n_continue = 3    
                    SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81095   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                    SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Dynamic Pick(DP) Location Not Setup / Not enough Dynamic Pick Location. (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
                    GOTO RETURN_SP  
                END   
            
                SELECT @c_ToLoc = @c_NextDynPickLoc  
                  
                SELECT @n_UCCToFit = @n_UCCToFit - 1  
                                           
                --Insert current location assigned                  
                IF NOT EXISTS (SELECT 1 FROM #DYNPICK_LOCASSIGNED   
                               WHERE Storerkey = @c_Storerkey  
                               AND Sku = @c_Sku  
                               AND ToLoc = @c_ToLoc  
                               AND Lottable01 = @c_Lottable01) --NJOW04  
                BEGIN  
                   INSERT INTO #DYNPICK_LOCASSIGNED (Storerkey, Sku, ToLoc, Lottable01, LocationType, UCCToFit)   --NJOW04  
                   VALUES (@c_Storerkey, @c_Sku, @c_Toloc, @c_Lottable01, 'DP', @n_UCCToFit)  
                END  
                ELSE  
                BEGIN  
                   UPDATE #DYNPICK_LOCASSIGNED   
                   SET UCCToFit = @n_UCCToFit  
                   WHERE Storerkey = @c_Storerkey  
                   AND Sku = @c_Sku  
                   AND ToLoc = @c_ToLoc  
                   AND LocationType = 'DP'  
                   AND Lottable01 = @c_Lottable01  
                END  
  
                GOTO INSERT_TASKS  
                DP:              
             END --DP                     
           
          PICKUCC_NEXT_REC:  
  
          --END --While qtyremain  
          FETCH NEXT FROM cur_PICKUCC INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @c_DropID, @c_PickMethod, @c_Style, @n_UCCQty, @c_Loadkey, @c_LocType,  
                                           @c_Lottable01, @dt_Lottable05 --NJOW04  NJOW07
       END --Fetch  
       CLOSE cur_PICKUCC    
       DEALLOCATE cur_PICKUCC                                     
    END         
      
    -----Generate Conso Pickslip No, PackHeader and PickingInfo-------  
    IF @n_continue = 1 or @n_continue = 2    
    BEGIN  
       DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
          SELECT DISTINCT ORDERS.LoadKey     
          FROM WAVEDETAIL (NOLOCK)    
          JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey  
          WHERE WAVEDETAIL.Wavekey = @c_wavekey   
          AND ISNULL(ORDERS.Loadkey,'') <> ''  
          ORDER BY ORDERS.Loadkey  
    
       OPEN CUR_LOAD  
    
       FETCH NEXT FROM CUR_LOAD INTO @c_Loadkey     
    
       WHILE @@FETCH_STATUS <> -1    
       BEGIN              
          SET @c_PickSlipno = ''        
          SELECT @c_PickSlipno = PickheaderKey    
          FROM PickHeader (NOLOCK)    
          WHERE ExternOrderkey = @c_Loadkey  
          AND ISNULL(OrderKey,'') = ''  
                               
          -- Create Pickheader        
          IF ISNULL(@c_PickSlipno, '') = ''    
          BEGIN    
             EXECUTE nspg_GetKey     
             'PICKSLIP',   9,   @c_Pickslipno OUTPUT,   @b_Success OUTPUT,   @n_err OUTPUT,   @c_errmsg OUTPUT        
                  
             SELECT @c_Pickslipno = 'P' + @c_Pickslipno        
                          
  
             INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, TrafficCop)    
                      VALUES (@c_Pickslipno , @c_LoadKey, '', '0', 'LB', '')                
                 
             SELECT @n_err = @@ERROR    
             IF @n_err <> 0    
             BEGIN    
                SELECT @n_continue = 3    
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
             END    
          END   
         
           -- tlting01  
           SET @c_curPickdetailkey = ''  
            DECLARE Orders_Pickdet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
           SELECT Pickdetailkey            
                FROM LOADPLANDETAIL (NOLOCK)  
                JOIN PICKDETAIL (NOLOCK) ON LOADPLANDETAIL.Orderkey = PICKDETAIL.Orderkey  
                WHERE LOADPLANDETAIL.LoadKey = @c_LoadKey     
  
          OPEN Orders_Pickdet_cur   
          FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey   
          WHILE @@FETCH_STATUS = 0 AND (@n_continue = 1 or @n_continue = 2)  
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
                      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81120   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKDETAIL Failed (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
                   END       
           FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey  
          END  
          CLOSE Orders_Pickdet_cur   
          DEALLOCATE Orders_Pickdet_cur        
           
         --Create packheader  
         IF NOT EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE Pickslipno = @c_Pickslipno) AND @n_continue IN(1,2)  
         BEGIN  
             INSERT INTO PACKHEADER (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)        
                    SELECT TOP 1 O.Route, '', '', O.LoadKey, '',O.Storerkey, @c_PickSlipNo         
                    FROM  PICKHEADER PH (NOLOCK)        
                    JOIN  Orders O (NOLOCK) ON (PH.ExternOrderkey = O.Loadkey)        
                    WHERE PH.PickHeaderKey = @c_PickSlipNo  
               
             SET @n_err = @@ERROR  
             IF @n_err <> 0  
             BEGIN  
                SELECT @n_continue = 3    
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81121   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Packheader Table (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
             END  
         END  
           
         --Create Pickinginfo  
     IF (SELECT COUNT(1) FROM PICKINGINFO(NOLOCK) WHERE Pickslipno = @c_Pickslipno) = 0  
          BEGIN  
             INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)  
                             VALUES (@c_Pickslipno ,NULL, NULL, NULL)  
  
             SET @n_err = @@ERROR  
             IF @n_err <> 0  
             BEGIN  
                SELECT @n_continue = 3    
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81122   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert PickingInfo Table (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
             END  
          END            
  
          /*  
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
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81130       
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookUp Table Failed. (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
             END     
          END  
          */          
              
          FETCH NEXT FROM CUR_LOAD INTO @c_LoadKey        
       END     
       CLOSE CUR_LOAD    
       DEALLOCATE CUR_LOAD   
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
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
      END    
    END    
     
RETURN_SP:  
  
    IF (SELECT CURSOR_STATUS('LOCAL','cur_PICKUCC')) >=0   
    BEGIN  
       CLOSE cur_PICKUCC             
       DEALLOCATE cur_PICKUCC        
    END    
  
    IF (SELECT CURSOR_STATUS('LOCAL','cur_PICKSKU')) >=0   
    BEGIN  
       CLOSE cur_PICKSKU             
       DEALLOCATE cur_PICKSKU  
    END    
  
    IF (SELECT CURSOR_STATUS('LOCAL','cur_UCCDetail')) >=0   
    BEGIN  
       CLOSE cur_UCCDetail             
       DEALLOCATE cur_UCCDetail        
    END    
  
    IF (SELECT CURSOR_STATUS('LOCAL','CUR_LOAD')) >=0   
    BEGIN  
       CLOSE CUR_LOAD             
       DEALLOCATE CUR_LOAD        
    END    
  
    IF (SELECT CURSOR_STATUS('LOCAL','cur_LoadOrder')) >=0   
    BEGIN  
       CLOSE cur_LoadOrder             
       DEALLOCATE cur_LoadOrder        
    END    
  
    IF OBJECT_ID('tempdb..#DYNPICK_LOCASSIGNED','u') IS NOT NULL  
       DROP TABLE #DYNPICK_LOCASSIGNED;  
  
    IF OBJECT_ID('tempdb..#DYNPICK_TASK','u') IS NOT NULL  
       DROP TABLE #DYNPICK_TASK;  
  
    IF OBJECT_ID('tempdb..#DYNPICK_NON_EMPTY','u') IS NOT NULL  
       DROP TABLE #DYNPICK_NON_EMPTY;  
           
    IF OBJECT_ID('tempdb..#DYNLOC','u') IS NOT NULL  
       DROP TABLE #DYNLOC;  
       
    IF OBJECT_ID('tempdb..#EXCLUDELOC','u') IS NOT NULL  
       DROP TABLE #EXCLUDELOC;  
         
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV05"    
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
     ,Message02   
     ,Areakey  
     ,Message03  
     ,Caseid  
     ,Loadkey  
--     ,FinalLoc  
    )    
    VALUES    
    (    
      @c_taskdetailkey    
     ,@c_TaskType --Tasktype    
     ,@c_Storerkey    
     ,@c_Sku    
     ,@c_UOM -- UOM,    
     ,@n_UCCQty  -- UOMQty,    
     ,@n_UCCQty  --Qty  
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
     ,''  
     ,@c_Message03  
     ,@c_DropID  
     ,@c_Loadkey  
--     ,@c_ToLoc  --NJOW02  
    )  
      
    SELECT @n_err = @@ERROR    
    IF @n_err <> 0    
    BEGIN  
        SELECT @n_continue = 3    
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81140   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
        GOTO RETURN_SP  
    END     
 END  
   
 --Update taskdetailkey/wavekey to pickdetail  
 IF @n_continue = 1 OR @n_continue = 2  
 BEGIN  
     SELECT @c_Pickdetailkey = '', @n_ReplenQty = @n_Qty  
     WHILE @n_ReplenQty > 0   
     BEGIN                          
         
       SELECT TOP 1 @c_PickdetailKey = PICKDETAIL.Pickdetailkey, @n_PickQty = Qty  
       FROM WAVEDETAIL (NOLOCK)   
       JOIN PICKDETAIL (NOLOCK) ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey  
       WHERE WAVEDETAIL.Wavekey = @c_Wavekey  
       AND ISNULL(PICKDETAIL.Taskdetailkey,'') = ''  
       AND PICKDETAIL.Storerkey = @c_Storerkey  
       AND PICKDETAIL.Sku = @c_sku  
       AND PICKDETAIL.Lot = @c_Lot  
       AND PICKDETAIL.Loc = @c_FromLoc  
       AND PICKDETAIL.ID = @c_ID  
       AND PICKDETAIL.UOM = @c_UOM  
       AND PICKDETAIL.DropID = @c_DropID  
       AND PICKDETAIL.Pickdetailkey > @c_pickdetailkey  
       ORDER BY PICKDETAIL.Pickdetailkey  
         
       SELECT @n_cnt = @@ROWCOUNT  
         
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
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81150     
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
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
                  WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo)        
          SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,         
                 Storerkey, Sku, AltSku, UOM, CASE WHEN UOM IN ('6','7') THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,         
                 DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,         
                 ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,         
                 WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo  
          FROM PICKDETAIL (NOLOCK)  
          WHERE PickdetailKey = @c_PickdetailKey  
                               
          SELECT @n_err = @@ERROR  
          IF @n_err <> 0       
          BEGIN       
             SELECT @n_continue = 3        
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81160     
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
             BREAK      
          END  
            
          UPDATE PICKDETAIL WITH (ROWLOCK)  
          SET Taskdetailkey = @c_TaskdetailKey,  
             Qty = @n_ReplenQty,  
             UOMQTY = CASE WHEN UOM IN('6','7') THEN @n_ReplenQty ELSE UOMQty END,              
             TrafficCop = NULL  
          WHERE Pickdetailkey = @c_PickdetailKey  
          SELECT @n_err = @@ERROR  
      IF @n_err <> 0   
          BEGIN  
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81170     
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
             BREAK  
          END  
          SELECT @n_ReplenQty = 0  
       END       
     END -- While Qty > 0  
 END          
  
 --return back to calling point  
 IF @c_DestinationType = 'DIRECT'  
    GOTO DIRECT  
 IF @c_DestinationType = 'DPP'  
    GOTO DPP  
 IF @c_DestinationType = 'PTS'  
    GOTO PTS  
 IF @c_DestinationType = 'PTL'  
    GOTO PTL  
 IF @c_DestinationType = 'DP' --NJOW04  
    GOTO DP  
 IF @c_Destinationtype = 'DPP_SH' --NJOW07
    GOTO DPP_SH   
        
 END --sp end  

GO