SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/      
/* Stored Procedure: ispRLWAV04                                          */      
/* Creation Date: 11-Jan-2016                                            */      
/* Copyright: LF                                                         */      
/* Written by:                                                           */      
/*                                                                       */      
/* Purpose: SOS#358768 - Lulu HK Release Pick Task                       */      
/*                                                                       */      
/* Called By: wave                                                       */      
/*                                                                       */      
/* PVCS Version: 1.7                                                     */      
/*                                                                       */      
/* Version: 5.4                                                          */      
/*                                                                       */      
/* Data Modifications:                                                   */      
/*                                                                       */      
/* Updates:                                                              */      
/* Date        Author   Ver   Purposes                                   */  
/* 13-Aug-2016 TLTING01 1.1   Performance tune                           */ 
/* 19-Dec-2016 Wan01    1.2   WMS-821 - HKCPI - lulu- re-release TM Task */
/*                            after pickdetail re-allocate               */
/* 27-Feb-2017 TLTING   1.3   Variable Nvarchar                          */
/* 13-Mar-2019 NJOW01   1.4   WMS-7940 add RPF task (Cancelled)          */
/* 27-Nov-2019 NJOW02   1.5   WMS-11212 generate replenishment record for*/
/*                            specific zone to replenish by paper based  */ 
/* 01-04-2020  Wan01    1.7   Sync Exceed & SCE                          */
/* 04-Jun-2020 NJOW03   1.6  WMS-11212 Add validation                   */ 
/*************************************************************************/       

CREATE PROCEDURE [dbo].[ispRLWAV04]          
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
                
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0    
   SELECT @n_debug = 1    
    
   DECLARE @c_OrderType             NVARCHAR(10)    
         , @c_Orderkey              NVARCHAR(10)    
         , @c_Storerkey             NVARCHAR(15)    
         , @c_Consigneekey          NVARCHAR(15)    
         , @c_Sku                   NVARCHAR(20)    
         , @c_Lot                   NVARCHAR(10)    
         , @c_FromLoc               NVARCHAR(10)    
         , @c_ID                    NVARCHAR(18)    
         , @n_Qty                   INT        
         , @c_Areakey               NVARCHAR(10)    
         , @c_Facility              NVARCHAR(5)    
         , @c_Packkey               NVARCHAR(10)    
         , @c_UOM                   NVARCHAR(10)       
         , @c_Pickslipno            NVARCHAR(10)    
         , @c_Loadkey               NVARCHAR(10)    
         , @c_PickZone              NVARCHAR(10)        
         , @n_Pickqty               INT    
         , @n_ReplenQty             INT    
         , @c_Pickdetailkey         NVARCHAR(18)    
         , @c_Taskdetailkey         NVARCHAR(10)     
         , @c_TaskType              NVARCHAR(10)     
         , @c_PickMethod            NVARCHAR(10)    
         , @c_Toloc                 NVARCHAR(10)    
         , @c_SourceType            NVARCHAR(30)    
         , @c_Message03             NVARCHAR(20)    
         , @c_LogicalFromLoc        NVARCHAR(18)    
         , @c_LogicalToLoc          NVARCHAR(18)             
         , @c_Priority              NVARCHAR(10)       
         , @c_ListName              NVARCHAR(10)    
         , @c_TableColumnName       NVARCHAR(250)  
         , @c_SQLGroup              NVARCHAR(2000)   
         , @c_SQL                   NVARCHAR(4000)  
         , @n_Found                 INT     
         , @c_curPickdetailkey      NVARCHAR(10)   
         
         , @c_TaskStatus            NVARCHAR(10)                        --(Wan01)
         , @n_TaskShort             INT                                 --(Wan01)
         
         --NJOW01
         /*
         DECLARE
           @c_Door                  NVARCHAR(10)                       
         , @c_Userdefine02          NVARCHAR(20)                       
         , @c_Userdefine03          NVARCHAR(20)                       
         , @n_TotalPickCBM          DECIMAL(12,6)                      
         , @n_TotalLocCBM           DECIMAL(12,6)                      
         , @n_StdCube               DECIMAL(12,6)                      
         , @n_QtyRemain             INT                                
          , @n_taskQty               INT 
          , @n_CubicCapacity_Bal     DECIMAL(12,6)    
          , @n_QtyCanFit             INT
          , @c_Groupkey              NVARCHAR(10)
          */
          
          --NJOW02
          DECLARE 
           @c_Userdefine01          NVARCHAR(20)                       
          , @c_ReplenishmentKey      NVARCHAR(10)                       
          , @C_ToID                  NVARCHAR(18)                       
          , @c_DropID                NVARCHAR(20)                       
          , @c_OLDID                 NVARCHAR(20)                       
          , @n_ReplenSeq             INT                                
          , @n_zonecnt1              INT                                
          , @n_zonecnt2              INT                                
          , @c_authority             NVARCHAR(30)                       
          , @c_option1               NVARCHAR(50)                       
              
   SET @c_Areakey         = ''    
   SET @c_Orderkey        = ''                  
   SET @c_Priority        = '9'                     
    
   WHILE @@TRANCOUNT > 0     
   BEGIN      
      COMMIT TRAN      
   END      

   -----Determine order type ECOM Or Retail-----    
   
   SELECT TOP 1 @c_Storerkey = OH.Storerkey  
               ,@c_OrderType = CASE WHEN OH.Type = 'LULUECOM' THEN 'ECOM' ELSE 'RETAIL' END    
               ,@c_Facility  = OH.Facility    
               --,@c_Door = ISNULL(OH.Door,'') --NJOW01
               ,@c_Userdefine01 = W.Userdefine01 --NJOW02
               --,@c_Userdefine02 = W.Userdefine02 --NJOW01
               --,@c_Userdefine03 = W.Userdefine03 --NJOW01
   FROM WAVE W WITH (NOLOCK)
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON (W.Wavekey = WD.Wavekey)
   JOIN ORDERS     OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)    
   WHERE W.Wavekey = @c_Wavekey     
       
   IF ISNULL(@c_wavekey,'') = ''      
   BEGIN      
      SET @n_continue = 3      
      SET @n_err = 81000      
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Parameters Passed (ispRLWAV04)'     
      GOTO RETURN_SP     
   END      
   
   IF ISNULL(@c_Userdefine01,'') <> ''
   BEGIN
         SELECT @n_zonecnt1 = COUNT(DISTINCT colvalue) FROM dbo.fnc_DelimSplit(',', @c_Userdefine01) WHERE ISNULL(colvalue,'') <> ''        
        
         SELECT @n_zonecnt2 = COUNT(DISTINCT Putawayzone)  
         FROM PUTAWAYZONE (NOLOCK)
         WHERE Putawayzone IN (SELECT colvalue FROM dbo.fnc_DelimSplit(',', @c_Userdefine01))
         
         IF ISNULL(@n_zonecnt1,0) <> ISNULL(@n_zonecnt2,0) 
         BEGIN
          SET @n_continue = 3      
          SET @n_err = 81005      
          SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Putawayzone Parameters Passed at userdefine01 (ispRLWAV04)'     
          GOTO RETURN_SP     
         END 
         
       --NJOW03
   	   IF EXISTS(SELECT 1 
   	             FROM REPLENISHMENT (NOLOCK) 
   	             WHERE Wavekey = @c_Wavekey
   	             AND OriginalFromLoc = 'ispRLWAV04')
       BEGIN    
          SET @n_continue = 3      
          SET @n_err = 81006      
          SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released for Paper based replenishment. (ispRLWAV04)'      
          GOTO RETURN_SP         
       END               
   END
    
   -----Wave Validation-----    
   --(Wan01) - START            
   --IF EXISTS ( SELECT 1 FROM TASKDETAIL TD WITH (NOLOCK)     
   --            WHERE TD.Wavekey = @c_Wavekey    
   --            AND TD.Sourcetype IN('ispRLWAV04-RETAIL','ispRLWAV04-ECOM')    
   --            AND TD.Tasktype IN ('SPK', 'PK') )    
   --BEGIN    
   --   SET @n_continue = 3      
   --   SET @n_err = 81001      
   --  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV04)'      
   --   GOTO RETURN_SP         
   --END                   
   --(Wan01) - END 

   IF EXISTS ( SELECT 1         
               FROM WAVEDETAIL WD WITH (NOLOCK)        
               JOIN ORDERS O WITH (NOLOCK) ON WD.Orderkey = O.Orderkey        
               WHERE O.Status > '5'        
               AND WD.Wavekey = @c_Wavekey)        
   BEGIN        
      SET @n_continue = 3          
      SET @n_err = 81010          
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Some orders of this Wave are started picking (ispRLWAV04)'               
      GOTO RETURN_SP        
   END                   
    
   IF EXISTS ( SELECT 1    
               FROM WAVEDETAIL WD WITH (NOLOCK)    
               JOIN ORDERS     OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)    
               WHERE WD.Wavekey = @c_Wavekey     
               GROUP BY WD.Wavekey    
               HAVING COUNT( DISTINCT CASE WHEN OH.Type = 'LULUECOM'  THEN 'ECOM' ELSE 'RETAIL' END ) > 1)    
   BEGIN    
      SET @n_continue = 3      
      SET @n_err = 81020      
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Mix order type in this Wave (ispRLWAV04)'           
      GOTO RETURN_SP    
   END     
   
   --NJOW02
   Execute nspGetRight                                
      @c_Facility  = @c_facility,                     
      @c_StorerKey = @c_StorerKey,                    
      @c_sku       = '',                          
      @c_ConfigKey = 'ReleaseWave_SP', -- Configkey         
      @b_Success   = @b_success   OUTPUT,             
      @c_authority = @c_authority OUTPUT,             
      @n_err       = @n_err       OUTPUT,             
      @c_errmsg    = @c_errmsg    OUTPUT,             
      @c_Option1   = @c_option1   OUTPUT           
       
   --NJOW01
   /*IF @c_Door = 'ALLOC'
   BEGIN
        CREATE TABLE #TMP_EMPTYDPP (LOC NVARCHAR(10) NULL, 
                                    LogicalLocation NVARCHAR(30) NULL,
                                    CubicCapacity DECIMAL(12,6) Default(0.00),
                                    Sku NVARCHAR(20) NULL)
              
        IF ISNULL(@c_Userdefine02,'') = '' OR ISNULL(@c_Userdefine03,'') = ''
        BEGIN
         SET @n_continue = 3      
         SET @n_err = 81000      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': DPP Location range must key-in at userdefine02 and userdefine03. (ispRLWAV04)'           
         GOTO RETURN_SP               
        END
      
      SET @c_Sku = ''
      SELECT TOP 1 @c_Sku = SKU.SKU
      FROM WAVEDETAIL WD WITH (NOLOCK)    
      JOIN PICKDETAIL PD WITH (NOLOCK) ON (WD.Orderkey = PD.Orderkey)    
      JOIN SKU WITH (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku   
      WHERE WD.Wavekey = @c_Wavekey     
      AND SKU.StdCube = 0
      
      IF ISNULL(@c_Sku,'') <> ''
      BEGIN    
         SET @n_continue = 3      
         SET @n_err = 81010      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found Sku ''' + RTRIM(@c_Sku) + ''' with 0 CMB is not allowed. (ispRLWAV04)'           
         GOTO RETURN_SP    
      END  
      
      SET @c_FromLoc = ''
      SELECT TOP 1 @c_FromLoc = Loc
      FROM LOC (NOLOCK) 
      WHERE Facility = @c_Facility
      AND LocationType = 'DPP'
      AND Loc BETWEEN @c_Userdefine02 AND @c_Userdefine03 
      AND CubicCapacity = 0

      IF ISNULL(@c_FromLoc,'') <> ''
      BEGIN    
         SET @n_continue = 3      
         SET @n_err = 81020      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found Loc ''' + RTRIM(@c_FromLoc) + ''' with 0 CMB is not allowed. (ispRLWAV04)'           
         GOTO RETURN_SP    
      END  
      
      INSERT INTO #TMP_EMPTYDPP (Loc, CubicCapacity, Sku, LogicalLocation)
      SELECT LOC.Loc, LOC.CubicCapacity, '', LOC.LogicalLocation
      FROM LOC (NOLOCK) 
      OUTER APPLY (SELECT SUM((LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIn) AS Qty
                   FROM LOTXLOCXID LLI (NOLOCK)
                   WHERE LLI.Loc = LOC.Loc) AS STK
      WHERE LOC.Facility = @c_Facility
      AND LOC.LocationType = 'DPP'
      AND LOC.Loc BETWEEN @c_Userdefine02 AND @c_Userdefine03 
      AND ISNULL(STK.Qty,0) = 0
      
      SELECT @n_TotalPickCBM = CONVERT(DECIMAL(12,6), SUM(SKU.StdCube * PD.Qty))
      FROM WAVEDETAIL WD WITH (NOLOCK)    
      JOIN PICKDETAIL PD WITH (NOLOCK) ON (WD.Orderkey = PD.Orderkey)    
      JOIN SKU WITH (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku   
      WHERE WD.Wavekey = @c_Wavekey     

      SELECT @n_TotalLocCBM =  SUM(CubicCapacity)
      FROM #TMP_EMPTYDPP (NOLOCK) 
      
      IF ISNULL(@n_TotalLocCBM, 0.00) < ISNULL(@n_TotalPickCBM, 0.00)
      BEGIN    
         SET @n_continue = 3      
         SET @n_err = 81030      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insufficient Empty DPP Loc CMB for the Wave. Loc CBM: ' + RTRIM(CAST(@n_TotalLocCBM AS NVARCHAR)) +  ' Required CBM: ' + RTRIM(CAST(@n_TotalPickCBM AS NVARCHAR)) + ' (ispRLWAV04)'           
         GOTO RETURN_SP    
      END            
   END   
   */
  
   -- Make sure loadkey not exists in multiple wave
   /*
   IF EXISTS ( SELECT 1  
               FROM LoadPlanDetail LPD WITH (NOLOCK)   
               JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey   
               WHERE EXISTS(SELECT 1 FROM WAVEDETAIL W WITH (NOLOCK)  
                            JOIN LoadplanDetail LPD2 WITH (NOLOCK) ON LPD2.OrderKey = W.OrderKey  
                            WHERE LPD2.LoadKey = LPD.LoadKey  
                              AND W.WaveKey = @c_Wavekey)  
               GROUP BY LPD.LoadKey   
               HAVING COUNT(DISTINCT O.UserDefine09) > 1 )  
   BEGIN    
      SET @n_continue = 3      
      SET @n_err = 81040     
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Found loadkey exists in multiple wave. (ispRLWAV04)'           
      GOTO RETURN_SP    
   END 
   */  
  
    -- Check unique loadplan group  
   SET @c_listname = ''  
   SELECT @c_listname = ISNULL(RTRIM(CODELIST.Listname),'')    
   FROM WAVE     WITH (NOLOCK)     
   JOIN CODELIST WITH (NOLOCK) ON WAVE.LoadPlanGroup = CODELIST.Listname AND CODELIST.ListGroup = 'WAVELPGROUP'    
   WHERE WAVE.Wavekey = @c_WaveKey    
  
   IF @c_listname <> ''  
   BEGIN  
      DECLARE CUR_CODELKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT TOP 10  Long     
      FROM   CODELKUP WITH (NOLOCK)    
      WHERE  ListName = @c_ListName    
      ORDER BY Code    
         
      OPEN CUR_CODELKUP    
         
      FETCH NEXT FROM CUR_CODELKUP INTO @c_TableColumnName    
         
      SET @c_SQLGroup = ''  
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         SET @c_SQLGroup = @c_SQLGroup + @c_TableColumnName + ', '           
         FETCH NEXT FROM CUR_CODELKUP INTO @c_TableColumnName    
      END     
      CLOSE CUR_CODELKUP    
      DEALLOCATE CUR_CODELKUP     
         
      IF RIGHT(@c_SQLGroup,2) = ', '  
      BEGIN  
         SET @c_SQLGroup = SUBSTRING(@c_SQLGroup,1 ,LEN(@c_SQLGroup) - 1)  
      END  
  
      IF LEN(@c_SQLGroup) > 0  
      BEGIN  
         SET @n_Found = 0  
         SET @c_SQL = ' SELECT @n_Found = 1'    
                    + ' FROM  WAVEDETAIL WITH (NOLOCK)'    
                    + ' JOIN ORDERS WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)'   
                    + ' WHERE WAVEDETAIL.Wavekey = @c_Wavekey'   
                    + ' GROUP BY ' + @c_SQLGroup   
                    + ' HAVING COUNT(DISTINCT ORDERS.Loadkey) > 1'    
  
            
         EXEC sp_executesql @c_SQL     
                          , N' @c_Wavekey NVARCHAR(10), @n_Found INT OUTPUT'      
                          , @c_Wavekey                          
                          , @n_Found OUTPUT   
  
         IF @n_Found = 1  
         BEGIN    
            SET @n_continue = 3      
            SET @n_err = 81030      
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Different Loadkey with same Loadplan group Found. (ispRLWAV04)'           
            GOTO RETURN_SP    
         END    
      END  
   END       
  
   BEGIN TRAN      
    
   --Remove taskdetailkey and add wavekey from pickdetail of the wave        
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN    
      -- tlting01
      SET @c_curPickdetailkey = ''
      DECLARE Orders_Pickdet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT Pickdetailkey 
               ,TaskDetailKey = ISNULL(RTRIM(TaskDetailKey),'')         --(Wan01)         
         FROM WAVEDETAIL WITH (NOLOCK)      
         JOIN PICKDETAIL WITH (NOLOCK) ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey    
         JOIN LOC WITH (NOLOCK) ON PICKDETAIL.Loc = LOC.Loc  --NJOW02
         WHERE WAVEDETAIL.Wavekey = @c_Wavekey            
         AND PICKDETAIL.Status = '0'                                    --(Wan01)
         AND LOC.Putawayzone NOT IN (SELECT colvalue FROM dbo.fnc_DelimSplit(',', @c_Userdefine01))   --NJOW02

      OPEN Orders_Pickdet_cur 
      FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey
                                             ,@c_TaskDetailKey          --(Wan01)
      WHILE @@FETCH_STATUS = 0  
      BEGIN 
         --(Wan01) - START
         IF @c_TaskDetailKey <> ''
         BEGIN
            SET @n_cnt = 0
            SET @c_TaskStatus = ''
            SET @n_TaskShort  = 0
            SELECT @n_cnt = 1
               ,   @c_TaskStatus = Status
               ,   @n_TaskShort  = CASE WHEN SystemQty > Qty THEN 1 ELSE 0 END
            FROM TASKDETAIL WITH (NOLOCK)
            WHERE TaskDetailKey = @c_TaskDetailKey

            IF @n_cnt = 0 OR (@c_TaskStatus = '9' AND @n_TaskShort  = 1)
            BEGIN
               SET @c_TaskDetailKey = ''                     -- PickDETAIL.Taskdetailkey not found or TASKDETAIL.Status = '9'
            END 
         END
         --(Wan01) - END
        
         UPDATE PICKDETAIL WITH (ROWLOCK)     
            SET --PICKDETAIL.TaskdetailKey = ''             --(Wan01)
              PICKDETAIL.TaskDetailKey = @c_TaskDetailKey   --(Wan01)    
            , PICKDETAIL.Wavekey = @c_Wavekey      
            , EditWho    = SUSER_SNAME()    
            , EditDate   = GETDATE()    
            , TrafficCop = NULL     
            WHERE PICKDETAIL.Pickdetailkey = @c_curPickdetailkey 
         SET @n_err = @@ERROR    
         IF @n_err <> 0     
         BEGIN    
            CLOSE Orders_Pickdet_cur 
            DEALLOCATE Orders_Pickdet_cur
            SET @n_continue = 3      
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
            SET @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
            GOTO RETURN_SP    
         END     
         
         NEXT_REC:                                                      --(Wan01)   
         FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey
                                               , @c_TaskDetailKey       --(Wan01)
      END
      CLOSE Orders_Pickdet_cur 
      DEALLOCATE Orders_Pickdet_cur
   END    
   SET @c_TaskDetailKey = ''                                            --(Wan01)

   --Remove toloc,dropid,notes pickdetail of the wave for specific zone to replenish by paper based--NJOW02        
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN    
      SET @c_curPickdetailkey = ''
      DECLARE Orders_Pickdet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT PD.Pickdetailkey
         FROM WAVEDETAIL WD (NOLOCK)      
         JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey    
         JOIN LOC WITH (NOLOCK) ON PD.Loc = LOC.Loc
         LEFT JOIN REPLENISHMENT R (NOLOCK) ON PD.Lot = R.Lot AND PD.Loc = R.FromLoc AND PD.Id = R.ID AND WD.Wavekey = R.Wavekey --AND PD.Toloc = R.ToLoc
         WHERE WD.Wavekey = @c_Wavekey            
         AND PD.Status = '0' 
         AND PD.Loc <> PD.ToLoc
         AND R.ReplenishmentKey IS NULL
         AND LOC.Putawayzone IN (SELECT colvalue FROM dbo.fnc_DelimSplit(',', @c_Userdefine01))

      OPEN Orders_Pickdet_cur 
      FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey

      WHILE @@FETCH_STATUS = 0  AND @n_continue IN(1,2)
      BEGIN         
        UPDATE PICKDETAIL WITH (ROWLOCK)     
           SET ToLoc      = '',
               DropId     = '',
               Notes      = '',
               EditWho    = SUSER_SNAME(),    
               EditDate   = GETDATE(),    
               TrafficCop = NULL     
           WHERE PICKDETAIL.Pickdetailkey = @c_curPickdetailkey 
           
        SET @n_err = @@ERROR
        
        IF @n_err <> 0     
        BEGIN    
           SET @n_continue = 3      
           SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
           SET @n_err = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
           SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
        END     
         
          FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey
      END
      CLOSE Orders_Pickdet_cur 
      DEALLOCATE Orders_Pickdet_cur
   END    

        
   --Create Temporary Tables   
   IF (@n_continue = 1 OR @n_continue = 2)  AND @c_OrderType = 'ECOM'  
      --AND @c_Door <> 'ALLOC' --NJOW01
   BEGIN    
      CREATE TABLE  #Orders (  
          RowRef    BIGINT IDENTITY(1,1) Primary Key,  
          OrderKey  NVARCHAR(10)  
         ,SKUCount  INT  
         ,TotalPick INT  
         )                                                   
   END   

   -----Retail Order Initialization and Validation-----     
    
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_OrderType = 'RETAIL'    
     --AND @c_Door <> 'ALLOC' --NJOW01      
   BEGIN         
      -----Generate RETAIL Order Tasks-----    
      IF (@n_continue = 1 OR @n_continue = 2)      
      BEGIN    
         DECLARE cur_Retail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
         SELECT PD.Storerkey     
              , PD.Sku     
              , PD.Lot     
              , PD.Loc     
              , PD.ID     
              , SUM(PD.Qty)                              
              --, CASE WHEN OH.TYPE ='LULUSTOR' 
              --       THEN 'STOTE'  
              --       ELSE 'PP' END AS PickMethod     
              , 'PP' AS PickMethod
              , SKU.Packkey    
              , MIN(PD.UOM)    
              , PD.Orderkey
              , OH.Consigneekey
         FROM WAVEDETAIL  WD          WITH (NOLOCK)    
         JOIN ORDERS      OH          WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey    
         JOIN ORDERDETAIL OD          WITH (NOLOCK) ON OH.Orderkey = OD.Orderkey    
         JOIN PICKDETAIL  PD          WITH (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber    
         JOIN LOC                     WITH (NOLOCK) ON PD.Loc = LOC.Loc    
         JOIN SKU                     WITH (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku    
         WHERE WD.Wavekey = @c_Wavekey 
         AND PD.Status = '0'                                         --(Wan01)  
         AND ISNULL(PD.TaskDetailKey,'') = ''                        --(Wan01)    
         AND LOC.Putawayzone NOT IN (SELECT colvalue FROM dbo.fnc_DelimSplit(',', @c_Userdefine01))   --NJOW02
         GROUP BY PD.Storerkey     
                , PD.Sku      
                , PD.Lot     
                , PD.Loc     
                , PD.Id   
                --, CASE WHEN OH.TYPE ='LULUSTOR' 
                --     THEN 'STOTE'  
                --     ELSE 'PP' END      
                , SKU.Packkey    
                , PD.Orderkey
                , OH.Consigneekey
         ORDER BY PD.Storerkey, PD.Sku                              
    
         OPEN cur_Retail      
         FETCH NEXT FROM cur_Retail INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_PickMethod, @c_Packkey, @c_UOM, @c_Orderkey, @c_Consigneekey
    
         SET @c_SourceType = 'ispRLWAV04-RETAIL'        
         SET @c_ToLoc = ''          
                  
         SET @c_LogicalToLoc = ''      
         SET @c_Priority  = '5'                       
         SET @c_Tasktype = 'SPK'

         -- Create Replenishment tasks    
         WHILE @@FETCH_STATUS = 0     
         BEGIN     
            SET @c_Message03 = @c_Orderkey
            
            GOTO RELEASE_PK_TASKS    
            RETAIL:    
      
            FETCH NEXT FROM cur_Retail INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_PickMethod, @c_Packkey, @c_UOM, @c_Orderkey, @c_Consigneekey
         END    
         CLOSE cur_Retail    
         DEALLOCATE cur_Retail    
      END
   END    
  
   -----Generate ECOM Order Tasks-----   
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_OrderType = 'ECOM'    
      --AND @c_Door <> 'ALLOC' --NJOW01
   BEGIN    
      INSERT INTO #ORDERS (PD.Orderkey, SkuCount, TotalPick)  
      SELECT PD.Orderkey  
            ,SkuCount = Count(DISTINCT PD.Sku)  
            ,TotalPick= SUM(PD.Qty)  
      FROM WAVEDETAIL WD WITH (NOLOCK)  
      JOIN ORDERS     OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)  
      JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)  
      WHERE WD.Wavekey  = @c_Wavekey  
      AND   OH.Type= 'LULUECOM'  
      GROUP BY PD.Orderkey  
  
      -- Retrieve SINGLES & MULTI  
      DECLARE CUR_ECOM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT PD.Storerkey     
           , PD.Sku     
           , PD.Lot     
           , PD.Loc     
           , PD.ID     
           , SUM(PD.Qty)                              
           , CASE WHEN TMP.SKUCount = 1 AND TMP.TotalPick = 1 THEN 'SINGLES' ELSE 'MULTIS' END 
           , Orderkey = CASE WHEN TMP.SKUCount = 1 AND TMP.TotalPick = 1 THEN '' ELSE PD.Orderkey END  
      FROM #ORDERS TMP  
      JOIN PICKDETAIL PD  WITH (NOLOCK) ON (TMP.Orderkey = PD.Orderkey)  
      JOIN LOC        LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)  
      WHERE PD.Status = '0'  
      AND ISNULL(PD.TaskDetailKey,'') = ''                              --(Wan01) 
      AND LOC.Putawayzone NOT IN (SELECT colvalue FROM dbo.fnc_DelimSplit(',', @c_Userdefine01))   --NJOW02
      --AND  LOC.LocationType = 'DYNPPICK'          
      GROUP BY CASE WHEN TMP.SKUCount = 1 AND TMP.TotalPick = 1 THEN '' ELSE PD.Orderkey END
              , PD.Storerkey     
              , PD.Sku     
              , PD.Lot     
              , PD.Loc     
              , PD.ID     
              , CASE WHEN TMP.SKUCount = 1 AND TMP.TotalPick = 1 THEN 'SINGLES' ELSE 'MULTIS' END    
      ORDER BY 7, Orderkey  
            ,  PD.Loc   
            ,  PD.Sku  
                
      OPEN CUR_ECOM      
      FETCH NEXT FROM CUR_ECOM INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty   
                                  , @c_PickMethod, @c_Orderkey   
    
      SET @c_SourceType = 'ispRLWAV04-ECOM'        
      WHILE @@FETCH_STATUS = 0      
      BEGIN        
         SET @c_tasktype = 'PK'    
         SET @c_ToLoc = ''          
         SET @c_LogicalToLoc = ''      
         SET @c_UOM = ''  
         IF @c_PickMethod = 'MULTIS'
         BEGIN
            SET @c_Message03 = @c_Orderkey
            SET @c_Priority = '5'
         END
         ELSE
         BEGIN
            SET @c_Message03 = @c_Wavekey
            SET @c_Priority = '4'
         END
            
         GOTO RELEASE_PK_TASKS    
         ECOM:   
         FETCH NEXT FROM CUR_ECOM INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty   
                                     , @c_PickMethod, @c_Orderkey              
      END --Fetch    
      CLOSE CUR_ECOM      
      DEALLOCATE CUR_ECOM                                     
    
   END    

   -----Generate ALLOC Order RPF asks----- NJOW01  
   /*IF (@n_continue = 1 OR @n_continue = 2)AND @c_Door = 'ALLOC' 
   BEGIN
      DECLARE cur_alloc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT PD.Storerkey     
           , PD.Sku     
           , PD.Lot     
           , PD.Loc     
           , PD.ID     
           , SUM(PD.Qty)                              
           , 'PP' AS PickMethod
           , SKU.Packkey    
           , MIN(PD.UOM)    
           , CONVERT(DECIMAL(12,6),SKU.StdCube)
      FROM WAVEDETAIL  WD          WITH (NOLOCK)    
      JOIN ORDERS      OH          WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey    
      JOIN ORDERDETAIL OD          WITH (NOLOCK) ON OH.Orderkey = OD.Orderkey    
      JOIN PICKDETAIL  PD          WITH (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber    
      JOIN LOC                     WITH (NOLOCK) ON PD.Loc = LOC.Loc    
      JOIN SKU                     WITH (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku    
      OUTER APPLY (SELECT SUM(P.Qty) AS QtyAllocated
                   FROM PICKDETAIL P (NOLOCK)                                      
                   JOIN SKU S (NOLOCK) ON P.Storerkey = S.Storerkey AND P.Sku = S.Sku
                   JOIN WAVEDETAIL (NOLOCK) ON P.Orderkey = WAVEDETAIL.Orderkey
                   WHERE WAVEDETAIL.Wavekey = @c_Wavekey
                   AND S.Style = SKU.Style 
                   AND S.Color = SKU.Color) AS SC
      WHERE WD.Wavekey = @c_Wavekey 
      AND PD.Status = '0'                                         
      AND ISNULL(PD.TaskDetailKey,'') = ''                        
      GROUP BY PD.Storerkey     
             , PD.Sku      
             , PD.Lot     
             , PD.Loc     
             , PD.Id   
             , SKU.Packkey
             , CONVERT(DECIMAL(12,6),SKU.StdCube)    
             , LEFT(SKU.Style,3)
             , ISNULL(SC.QtyAllocated,0) 
             , SKU.Style
             , SKU.Color
      ORDER BY LEFT(SKU.Style,3), ISNULL(SC.QtyAllocated,0) DESC, SKU.Style, SKU.Color, SUM(PD.Qty) DESC, PD.Sku                              
      
      OPEN cur_alloc   
         
      FETCH NEXT FROM cur_alloc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_PickMethod, @c_Packkey, @c_UOM, @n_StdCube
      
      SET @c_SourceType = 'ispRLWAV04-ALLOC'        
      SET @c_ToLoc = ''          
      SET @c_LogicalToLoc = ''      
      SET @c_Priority  = '5'                       
      SET @c_Tasktype = 'RPF'
      SET @c_Message03 = 'ALLOC'

      -- Create Replenishment tasks    
      WHILE @@FETCH_STATUS = 0  AND @n_continue IN(1,2)   
      BEGIN              
         
          SET @n_QtyRemain = @n_Qty
             
          WHILE @n_QtyRemain > 0 AND @n_continue IN(1,2)
          BEGIN                  
              SET @c_ToLoc = ''
              SET @n_taskQty = 0
              SET @n_CubicCapacity_Bal = 0.00
              
              --Search available DPP of same sku
              SELECT TOP 1 @c_ToLoc = Loc, 
                          @n_CubicCapacity_Bal = CubicCapacity
              FROM #TMP_EMPTYDPP
              WHERE Sku = @c_SKU
              AND CubicCapacity >= @n_StdCube                
              ORDER BY LogicalLocation, Loc
                          
              --Search empty DPP
              IF ISNULL(@c_ToLoc,'') = ''
              BEGIN               
                 SELECT TOP 1 @c_ToLoc = Loc, 
                              @n_CubicCapacity_Bal = CubicCapacity
                 FROM #TMP_EMPTYDPP
                 WHERE Sku = ''
                 AND CubicCapacity >= @n_StdCube                
                 ORDER BY LogicalLocation, Loc                         
              END
              
              --No more DPP available
              IF  ISNULL(@c_ToLoc,'') = ''
              BEGIN
               SET @n_continue = 3      
               SET @n_err = 81060      
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Unable find available DPP Location. (ispRLWAV04)'                          
              END
              
              SET @n_QtyCanFit = FLOOR(@n_CubicCapacity_Bal / @n_StdCube)
              
              IF @n_QtyCanFit >= @n_QtyRemain
                 SET @n_TaskQty = @n_QtyRemain
              ELSE 
                 SET @n_TaskQty = @n_QtyCanFit    
                 
              SET @n_QtyRemain = @n_QtyRemain - @n_TaskQty
              
              UPDATE #TMP_EMPTYDPP
              SET CubicCapacity = CubicCapacity - (@n_TaskQty * @n_StdCube),
                  SKU = @c_Sku
              WHERE Loc = @c_ToLoc
                                    
           EXEC isp_InsertTaskDetail   
                        @c_TaskType              = @c_TaskType             
                       ,@c_Storerkey             = @c_Storerkey
                       ,@c_Sku                   = @c_Sku
                       ,@c_Lot                   = @c_Lot 
                       ,@c_UOM                   = ''      
                       ,@n_UOMQty                = 0     
                       ,@n_Qty                   = @n_TaskQty      
                       ,@c_FromLoc               = @c_Fromloc      
                       ,@c_LogicalFromLoc        = @c_FromLoc 
                       ,@c_FromID                = @c_ID     
                       ,@c_ToLoc                 = @c_ToLoc       
                       ,@c_LogicalToLoc          = @c_ToLoc 
                       ,@c_ToID                  = @c_ID       
                       ,@c_PickMethod            = @c_PickMethod
                       ,@c_Priority              = @c_Priority     
                       ,@c_SourcePriority        = '9'      
                       ,@c_SourceType            = @c_SourceType      
                       ,@c_SourceKey             = @c_Wavekey      
                       ,@c_WaveKey               = @c_Wavekey      
                       ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
                       ,@c_Message03             = @c_Message03
                       ,@c_LinkTaskToPick        = 'Y' 
                       ,@c_LinkTaskToPick_SQL    = ''  
                       ,@c_ReservePendingMoveIn  = 'Y'
                       ,@c_WIP_RefNo             = ''
                       ,@b_Success               = @b_Success OUTPUT
                       ,@n_Err                   = @n_err OUTPUT 
                       ,@c_ErrMsg                = @c_errmsg OUTPUT        
                    
            IF @b_Success <> 1 
            BEGIN
               SELECT @n_continue = 3  
            END
         END
                      
         FETCH NEXT FROM cur_alloc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_PickMethod, @c_Packkey, @c_UOM, @n_StdCube
      END    
      CLOSE cur_alloc    
      DEALLOCATE cur_alloc                     
      
      --Assign group key to task
      IF @n_continue IN(1,2)
      BEGIN
          DECLARE CUR_TASKGROUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT TD.Storerkey, TD.Sku, TD.FromLoc, TD.FromID
            FROM TASKDETAIL TD (NOLOCK)
            WHERE Wavekey = @c_Wavekey
            AND TaskType = 'RPF'
            AND SourceType = @c_SourceType
 
         OPEN CUR_TASKGROUP      
    
         FETCH NEXT FROM CUR_TASKGROUP INTO @c_Storerkey, @c_Sku, @c_FromLoc, @c_ID           
    
         WHILE @@FETCH_STATUS <> -1      
         BEGIN      
              SET @c_GroupKey = ''
              
              EXECUTE nspg_GetKey       
               'WAV04GRPKEY'    
            ,  10    
            ,  @c_Groupkey   OUTPUT    
            ,  @b_Success    OUTPUT    
            ,  @n_err        OUTPUT    
            ,  @c_errmsg     OUTPUT       
            
            IF @b_success <> 1
               SET @n_continue = 3                    
              
              UPDATE TASKDETAIL WITH (ROWLOCK)
              SET Groupkey = @c_Groupkey
              WHERE Wavekey = @c_Wavekey
             AND TaskType = 'RPF'
             AND SourceType = @c_SourceType
             AND Storerkey = @c_Storerkey
             AND Sku = @c_Sku
             AND FromLoc = @c_FromLoc
             AND FromID = @c_ID

            SET @n_err = @@ERROR
                  
            IF @n_err <> 0      
            BEGIN      
               SET @n_continue = 3      
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
               SET @n_err = 81050 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TASKDETAIL Failed (ispRLWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
            END                

            FETCH NEXT FROM CUR_TASKGROUP INTO @c_Storerkey, @c_Sku, @c_FromLoc, @c_ID                      
         END
         CLOSE CUR_TASKGROUP
         DEALLOCATE CUR_TASKGROUP                         
      END
   END
   */
   
   --NJOW02
   -----Generate replenishment record for specific zone to replenish by paper based. 
   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@c_Userdefine01,'') <> ''  --AND  @c_Door <> 'ALLOC'
   BEGIN
        SET @n_ReplenSeq = 0
        
        SELECT @n_ReplenSeq = ISNULL(COUNT(DISTINCT PD.DropID),0)
        FROM WAVEDETAIL WD (NOLOCK)
        JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
        JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
        WHERE WD.Wavekey = @c_Wavekey
        AND ISNULL(PD.DropID,'') <> ''
        AND ISNULL(PD.ToLoc,'') <> ''
      AND LOC.Putawayzone IN (SELECT colvalue FROM dbo.fnc_DelimSplit(',', @c_Userdefine01))   
              
      SELECT @c_ToLoc = Code  
      FROM CODELKUP (NOLOCK)
      WHERE Listname = 'LUREPLEN' 
      
      DECLARE cur_PickReplen CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT PD.Storerkey     
           , PD.Sku     
           , PD.Lot     
           , PD.Loc     
           , PD.ID     
           , SUM(PD.Qty)                              
           , SKU.Packkey    
           , PACK.PackUOM3   
      FROM WAVEDETAIL  WD          WITH (NOLOCK)    
      JOIN ORDERS      OH          WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey    
      JOIN ORDERDETAIL OD          WITH (NOLOCK) ON OH.Orderkey = OD.Orderkey    
      JOIN PICKDETAIL  PD          WITH (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber    
      JOIN LOC                     WITH (NOLOCK) ON PD.Loc = LOC.Loc    
      JOIN SKU                     WITH (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku    
      JOIN PACK                    WITH (NOLOCK) ON SKU.Packkey = PACK.Packkey
      WHERE WD.Wavekey = @c_Wavekey 
      AND PD.Status = '0'         
      AND ISNULL(PD.ToLoc,'') = ''
      AND ISNULL(PD.DropId,'') = ''
      AND LOC.Putawayzone IN (SELECT colvalue FROM dbo.fnc_DelimSplit(',', @c_Userdefine01))   
      GROUP BY PD.Storerkey     
             , PD.Sku      
             , PD.Lot     
             , PD.Loc     
             , PD.Id   
             , SKU.Packkey   
             , PACK.PackUOM3   
      ORDER BY PD.Storerkey, PD.Sku, PD.Loc, PD.Lot                              
      
      OPEN cur_PickReplen      
      FETCH NEXT FROM cur_PickReplen INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_Packkey, @c_UOM
                        
      -- Create Replenishment records
      WHILE @@FETCH_STATUS = 0  AND @n_continue IN(1,2)   
      BEGIN                 
          SET @n_ReplenSeq = @n_ReplenSeq + 1

         EXECUTE nspg_getkey
            'REPLENISHKEY'
            , 10
            , @c_ReplenishmentKey OUTPUT
            , @b_success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT
            
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
          
          IF @c_Option1 = 'ORIGINALID'
          BEGIN
              SET @c_ToId = @c_ID
          END     
          ELSE
          BEGIN             
            SET @c_OldID = ''         
            IF SUBSTRING(@c_ID, 8,1) = '*'  --The ID was converted before.
            BEGIN
                SELECT TOP 1 @c_OldID = PalletFlag
                FROM ID (NOLOCK)
                WHERE ID = @c_ID
            END
            
            IF ISNULL(@c_OldId,'') <> ''
               SET @c_ToID = SUBSTRING(@c_ReplenishmentKey,4,7) + '*' + SUBSTRING(@C_OldID,1,10)
            ELSE
               SET @c_ToID = SUBSTRING(@c_ReplenishmentKey,4,7) + '*' + SUBSTRING(@C_ID,1,10)            
          END
                  
         SET @c_DropID = @c_Wavekey + '-V' + RIGHT('0000' + RTRIM(LTRIM(CAST(@n_ReplenSeq AS NVARCHAR))),4)

         DECLARE cur_PickDet CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
            SELECT PD.Pickdetailkey, PD.Qty 
            FROM PICKDETAIL PD (NOLOCK)
            JOIN WAVEDETAIL WD (NOLOCK) ON PD.Orderkey = WD.Orderkey
            WHERE WD.Wavekey = @c_Wavekey
            AND PD.Storerkey = @c_Storerkey
            AND PD.Sku = @c_Sku
            AND PD.Lot = @c_Lot
            AND PD.Loc = @c_FromLoc
            AND PD.Id = @c_ID
            AND PD.Status = '0'
            ORDER BY PD.Pickdetailkey
            
         OPEN cur_PickDet      
         
         FETCH NEXT FROM cur_PickDet INTO @c_Pickdetailkey, @n_PickQty
                       
         WHILE @@FETCH_STATUS = 0  AND @n_continue IN(1,2)               
         BEGIN   
              IF @c_Option1 = 'ORIGINALID' 
              BEGIN
               UPDATE PICKDETAIL WITH (ROWLOCK)
                 SET Qty = @n_PickQty,
                     ToLoc = @c_ToLoc,
                     DropId = @c_DropID,
                     Notes = @c_DropID
                 WHERE Pickdetailkey = @c_Pickdetailkey
                 
               SET @n_err = @@ERROR
               
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3      
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                  SET @n_err = 81070  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update Pickdetail Table. (ispRLWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                
               END                                                   
              END
              ELSE
              BEGIN                                  
                 UPDATE PICKDETAIL WITH (ROWLOCK)
                 SET Qty = 0
                 WHERE Pickdetailkey = @c_Pickdetailkey
                 
               SET @n_err = @@ERROR
               
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3      
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                  SET @n_err = 81060  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update Pickdetail Table. (ispRLWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                
               END                                                  
                                                     
               /*EXEC dbo.nspItrnAddMove
                        @n_ItrnSysId      = NULL
                     ,  @c_StorerKey      = @c_Storerkey
                     ,  @c_Sku            = @c_Sku
                     ,  @c_Lot            = @c_Lot
                     ,  @c_FromLoc        = @c_FromLoc
                     ,  @c_FromID         = @c_ID
                     ,  @c_ToLoc          = @c_FromLoc
                     ,  @c_ToID           = @c_ToID
                     ,  @c_Status         = 'OK'
                     ,  @c_lottable01     = '' 
                     ,  @c_lottable02     = '' 
                     ,  @c_lottable03     = '' 
                     ,  @d_lottable04     = '' 
                     ,  @d_lottable05     = '' 
                     ,  @n_casecnt        = 0.00 
                     ,  @n_innerpack      = 0.00 
                     ,  @n_qty            = @n_PickQty
                     ,  @n_pallet         = 0.00 
                     ,  @f_cube           = 0.00
                     ,  @f_grosswgt       = 0.00  
                     ,  @f_netwgt         = 0.00  
                     ,  @f_otherunit1     = 0.00  
                     ,  @f_otherunit2     = 0.00  
                     ,  @c_SourceKey      = ''
                     ,  @c_SourceType     = 'ispRLWAV04'
                     ,  @c_PackKey        = @c_Packkey
                     ,  @c_UOM            = @c_UOM
                     ,  @b_UOMCalc        = 0
                     ,  @d_EffectiveDate  = NULL
                     ,  @c_itrnkey        = ''
                     ,  @b_Success        = @b_Success      OUTPUT
                     ,  @n_err            = @n_err          OUTPUT
                     ,  @c_errmsg         = @c_errmsg       OUTPUT  
                     ,  @c_MoveRefKey     = NULL  
                */                 
                                   
                 EXEC nspItrnAddMove
                   @n_ItrnSysId = null,
                   @c_StorerKey = @c_Storerkey,
                   @c_Sku = @c_Sku,
                   @c_Lot = @c_Lot,
                   @c_FromLoc = @c_FromLoc,
                   @c_FromID = @c_ID,
                   @c_ToLoc = @c_FromLoc,
                   @c_ToID = @c_ToID,
                   @c_Status = 'OK',
                   @c_lottable01 = '',
                   @c_lottable02 = '',
                   @c_lottable03 = '',
                   @d_lottable04 = null,
                   @d_lottable05 = null,
                   @c_lottable06 = '',
                   @c_lottable07 = '',
                   @c_lottable08 = '',
                   @c_lottable09 = '',
                   @c_lottable10 = '',
                   @c_lottable11 = '',
                   @c_lottable12 = '',
                   @d_lottable13 = null,
                   @d_lottable14 = null,
                   @d_lottable15 = null,
                   @n_casecnt = 0,
                   @n_innerpack = 0,
                   @n_qty = @n_PickQty,
                   @n_pallet = 0,
                   @f_cube = 0,
                   @f_grosswgt = 0,
                   @f_netwgt = 0,
                   @f_otherunit1 = 0,
                   @f_otherunit2 = 0,
                   @c_SourceKey = null,
                   @c_SourceType = 'ispRLWAV04',
                   @c_PackKey = @c_Packkey,
                   @c_UOM = @c_UOM,
                   @b_UOMCalc = null,
                   @d_EffectiveDate = null,
                   @c_itrnkey = null,
                   @b_Success = @b_Success OUTPUT,
                   @n_err = @n_err OUTPUT,
                   @c_errmsg = @c_errmsg OUTPUT,
                   @c_MoveRefKey = null
                   --@c_Channel = null,
                   --@n_Channel_ID = null
                   
                   IF @b_success <> 1
                      SET @n_continue = 3
                    
               UPDATE PICKDETAIL WITH (ROWLOCK)
                 SET Qty = @n_PickQty,
                     ID = @c_ToID,
                     ToLoc = @c_ToLoc,
                     DropId = @c_DropID,
                     Notes = @c_DropID
                 WHERE Pickdetailkey = @c_Pickdetailkey
                 
               SET @n_err = @@ERROR
               
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3      
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                  SET @n_err = 81070  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update Pickdetail Table. (ispRLWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                
               END                                      
               
               IF ISNULL(@c_OldId,'') <> ''
               BEGIN             
                    UPDATE ID WITH (ROWLOCK)
                    SET PalletFlag = @c_OldID
                    WHERE ID = @c_ToID
                 END
                 ELSE
                 BEGIN
                 UPDATE ID WITH (ROWLOCK)
                    SET PalletFlag = @c_ID
                    WHERE ID = @c_ToID
                 END   
               
               SET @n_err = @@ERROR          
               
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3      
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                  SET @n_err = 81080  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update ID Table. (ispRLWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
               END                                                              
            END
                                    
            FETCH NEXT FROM cur_PickDet INTO @c_Pickdetailkey, @n_PickQty
         END
         CLOSE cur_PickDet
         DEALLOCATE cur_PickDet
         
         IF ISNULL(@c_OldId,'') = ''  
           SET @c_OldID = @c_ID
                
         INSERT INTO REPLENISHMENT (ReplenishmentKey, ReplenishmentGroup,
                        StorerKey,      SKU,         FromLOC,         ToLOC,
                        Lot,            Id,          Qty,             UOM,
                        PackKey,        Priority,    QtyMoved,        QtyInPickLOC,
                        RefNo,          Confirmed,   ReplenNo,        Wavekey,
                        Remark,         OriginalQty, OriginalFromLoc, ToID)
                    VALUES (
                        @c_ReplenishmentKey,         '',
                        @c_StorerKey,   @c_Sku,      @c_FromLoc,      @c_ToLoc,
                        @c_Lot,         @c_ToId,       @n_Qty,          @c_UOM,
                        @c_Packkey,     '5',             0,               0,
                        @c_DropID,      'N',         @c_Wavekey,    @c_WaveKey,
                        '',                 @n_Qty,      'ispRLWAV04',    @c_ToId)
         
         SET @n_err = @@ERROR
         
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3      
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
            SET @n_err = 81090  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Replenishment Table. (ispRLWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                
         END                        
                
         FETCH NEXT FROM cur_PickReplen INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_Packkey, @c_UOM
      END    
      CLOSE cur_PickReplen    
      DEALLOCATE cur_PickReplen              
   END
         
   -----Generate Pickslip No-------    
    
   IF @n_continue = 1 or @n_continue = 2      
   BEGIN    
      DECLARE CUR_PS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT DISTINCT     
          OrderKey = LPD.Orderkey 
         ,LoadKey  = LPD.LoadKey 
      FROM WAVEDETAIL      WD  WITH (NOLOCK)     
      JOIN LOADPLANDETAIL  LPD WITH (NOLOCK) ON (WD.Orderkey = LPD.Orderkey)    
      WHERE  WD.Wavekey = @c_wavekey       
    
      OPEN CUR_PS      
    
      FETCH NEXT FROM CUR_PS INTO @c_Orderkey, @c_LoadKey           
    
      WHILE @@FETCH_STATUS <> -1      
      BEGIN      
         SET @c_PickZone = CASE WHEN @c_OrderKey = '' THEN 'LP' ELSE '8' END    
    
         SET @c_PickSlipno = ''          
         SELECT @c_PickSlipno = PickheaderKey      
         FROM   PICKHEADER (NOLOCK)      
         WHERE  Wavekey  = @c_Wavekey    
         AND    OrderKey = @c_OrderKey    
         AND    ExternOrderKey = @c_LoadKey    
         AND    Zone =  @c_PickZone               
         
         --NJOW02
         IF ISNULL(@c_PickSlipno, '') = '' AND ISNULL(@c_Orderkey,'') <> ''
         BEGIN
            SELECT @c_PickSlipno = PickheaderKey      
            FROM   PICKHEADER (NOLOCK)      
            WHERE  OrderKey = @c_OrderKey    
         END   
    
         -- Create Pickheader          
         IF ISNULL(@c_PickSlipno, '') = ''      
         BEGIN      
            EXECUTE nspg_GetKey       
               'PICKSLIP'    
            ,  9    
            ,  @c_Pickslipno OUTPUT    
            ,  @b_Success    OUTPUT    
            ,  @n_err        OUTPUT    
            ,  @c_errmsg     OUTPUT          
                 
            SET @c_Pickslipno = 'P' + @c_Pickslipno          
                         
            INSERT INTO PICKHEADER      
                     (  PickHeaderKey    
                     ,  Wavekey    
                     ,  Orderkey    
                     ,  ExternOrderkey    
                     ,  Loadkey    
                     ,  PickType    
                     ,  Zone    
                     ,  TrafficCop    
                     )      
            VALUES      
                     (  @c_Pickslipno    
                     ,  @c_Wavekey    
                     ,  @c_OrderKey    
                     ,  @c_Loadkey    
                     ,  @c_Loadkey    
                     ,  '0'     
                     ,  @c_PickZone    
                     ,  ''    
                     )          
    
            SET @n_err = @@ERROR      
            IF @n_err <> 0      
            BEGIN      
               SET @n_continue = 3      
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
               SET @n_err = 81100  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (ispRLWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
            END      
         END  

         -- IF print from Wave Pickslip, and later release wave, need to make sure refkeylookup record  
         -- is sync with pickdetail record, hence delete and regenerate refkeylookup again  
         IF EXISTS (SELECT 1 FROM REFKEYLOOKUP WITH (NOLOCK)       
                    WHERE PickSlipNo = @c_PickSlipNo    
                    AND   Loadkey    = @c_Loadkey)  
            AND @c_Orderkey = ''                     
         BEGIN     
            DELETE FROM REFKEYLOOKUP WITH (ROWLOCK)  
            WHERE PickSlipNo = @c_PickSlipNo    
            AND   Loadkey    = @c_Loadkey  
  
            SET @n_err = @@ERROR      
            IF @n_err <> 0      
            BEGIN      
               SET @n_continue = 3      
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
               SET @n_err = 81090 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': DELETE REFKEYLOOKUP Failed (ispRLWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
            END    
         END     
  
        -- tlting01
        SET @c_curPickdetailkey = ''

         IF @c_Orderkey <> ''    
         BEGIN    
            DECLARE Orders_Pickdet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
               SELECT Pickdetailkey          
               FROM PICKDETAIL WITH (NOLOCK)       
               WHERE  OrderKey = @c_OrderKey   
         END    
         ELSE    
         BEGIN   
            SELECT PD.Pickdetailkey          
            FROM ORDERS     OH WITH (NOLOCK)    
            JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)      
            WHERE  OH.Loadkey = @c_Loadkey   
         END   

         OPEN Orders_Pickdet_cur 
         FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey 
         WHILE @@FETCH_STATUS = 0 AND (@n_continue = 1 or @n_continue = 2)
         BEGIN 
               UPDATE PICKDETAIL WITH (ROWLOCK)      
               SET  PickSlipNo = @c_PickSlipNo     
                   ,EditWho = SUSER_SNAME()    
                   ,EditDate= GETDATE()     
                   ,TrafficCop = NULL     
               WHERE PICKDETAIL.Pickdetailkey = @c_curPickdetailkey 
               SET @n_err = @@ERROR    
               IF @n_err <> 0     
               BEGIN    
                  CLOSE Orders_Pickdet_cur 
                  DEALLOCATE Orders_Pickdet_cur
                  SET @n_continue = 3      
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                  SET @n_err = 81100 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Pickdetail Failed (ispRLWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
               END         
            FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey
         END
         CLOSE Orders_Pickdet_cur 
         DEALLOCATE Orders_Pickdet_cur             
    
         IF NOT EXISTS (SELECT 1 FROM REFKEYLOOKUP WITH (NOLOCK)       
                        WHERE PickSlipNo = @c_PickSlipNo    
                        AND   Loadkey    = @c_Loadkey)   
            AND @c_OrderKey = ''                    
         BEGIN     
            INSERT INTO REFKEYLOOKUP       
                     (  PickDetailkey      
                     ,  Orderkey      
                     ,  OrderLineNumber      
                     ,  Loadkey      
                     ,  PickSlipNo      
                     )       
            SELECT   PD.PickDetailKey      
                  ,  PD.Orderkey      
                  ,  PD.OrderLineNumber      
                  ,  @c_Loadkey      
                  ,  @c_PickSlipNo       
            FROM ORDERS     OH WITH (NOLOCK)    
            JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)      
            WHERE  OH.Loadkey = @c_Loadkey    
    
            SET @n_err = @@ERROR      
            IF @n_err <> 0      
            BEGIN      
               SET @n_continue = 3      
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
               SET @n_err = 81110 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert REFKEYLOOKUP Failed (ispRLWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
            END    
         END    
               
         IF NOT EXISTS (SELECT 1 FROM PICKINGINFO WITH (NOLOCK)       
                        WHERE PickSlipNo = @c_PickSlipNo)    
         BEGIN    
            INSERT INTO PICKINGINFO (PickSlipNo, ScanIndate, PickerID)    
            VALUES (@c_PickSlipNo, GETDATE(), SUSER_SNAME())    
    
            SET @n_err = @@ERROR      
            IF @n_err <> 0      
            BEGIN   
               SET @n_continue = 3      
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
               SET @n_err = 81120 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKINGINFO Failed (ispRLWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
            END  
         END    
    
         FETCH NEXT FROM CUR_PS INTO @c_Orderkey, @c_LoadKey           
      END       
      CLOSE CUR_PS      
      DEALLOCATE CUR_PS     
   END    
    
   -----Update Wave Status-----    
   IF @n_continue = 1 or @n_continue = 2      
   BEGIN          
      UPDATE WAVE WITH (ROWLOCK)    
       --SET STATUS = '1' -- Released        --(Wan01) 
       SET TMReleaseFlag = 'Y'               --(Wan01) 
        ,  TrafficCop = NULL                 --(Wan01)    
         , EditWho = SUSER_SNAME()    
         , EditDate= GETDATE()     
      WHERE WAVEKEY = @c_wavekey      
    
      SET @n_err = @@ERROR      
      IF @n_err <> 0      
      BEGIN      
        SET @n_continue = 3      
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 81130   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
      END      
   END      
  
   -- Make sure all pickdetail have taskdetailkey stamped (Chee01)  
   IF EXISTS ( SELECT 1   
               FROM WAVEDETAIL WD  WITH (NOLOCK)     
               JOIN PICKDETAIL PD  WITH (NOLOCK) ON (WD.Orderkey = PD.Orderkey)    
               JOIN LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc) --NJOW02
               WHERE WD.Wavekey = @c_Wavekey   
               AND LOC.Putawayzone NOT IN (SELECT colvalue FROM dbo.fnc_DelimSplit(',', @c_Userdefine01))   --NJOW02
               AND PD.Status < '5'                                    --(Wan01)
               AND ISNULL(PD.Taskdetailkey,'') = ''    
               AND PD.Storerkey = @c_Storerkey )    
   BEGIN    
      SET @n_continue = 3      
      SET @n_err = 81140  
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': TaskDetailkey not updated to pickdetail. (ispRLWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '         
      GOTO RETURN_SP    
   END   
    
   RETURN_SP:    
    
   WHILE @@TRANCOUNT < @n_starttcnt    
   BEGIN      
      BEGIN TRAN      
   END      
    
   IF @n_continue=3  -- Error Occured - Process And Return      
   BEGIN      
      SET @b_success = 0      
    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt      
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
      execute nsp_logerror @n_err, @c_errmsg, 'ispRLWAV04'      
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN      
   END      
   ELSE      
   BEGIN      
      SET @b_success = 1      
      WHILE @@TRANCOUNT > @n_starttcnt      
      BEGIN      
         COMMIT TRAN      
      END      
      RETURN      
   END    
    
   RELEASE_PK_TASKS:    
       
   --function to insert taskdetail    
   IF (@n_continue = 1 or @n_continue = 2)     
   BEGIN   
      SET @c_LogicalFromLoc = ''  
      SELECT TOP 1 @c_AreaKey = AreaKey    
                 , @c_LogicalFromLoc = ISNULL(RTRIM(LogicalLocation),'')    
      FROM LOC        LOC WITH (NOLOCK)    
      JOIN AREADETAIL ARD WITH (NOLOCK) ON (LOC.PutawayZone = ARD.PutawayZone)    
      WHERE LOC.Loc = @c_FromLoc     
    
      SET @c_LoadKey = ''  
      SELECT Top 1 @c_LoadKey = O.LoadKey   
      FROM dbo.PickDetail PD WITH (NOLOCK)  
      INNER JOIN dbo.Orders O WITH (NOLOCK)  ON O.OrderKEy = PD.OrderKey   
      WHERE PD.WaveKey = @c_WaveKey  
      AND PD.Status = '0'  
      AND PD.SKU = @c_SKU  
      AND PD.Lot = @c_Lot  
      AND PD.Loc = @c_FromLoc  
      AND PD.ID  = @c_ID  
      
      IF ISNULL(@c_Message03,'') = ''
      BEGIN
         SET @n_continue = 3      
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 81150   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Empty Message03 is not allowed. (ispRLWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '               
         GOTO RETURN_SP    
      END

      IF ISNULL(@c_Areakey,'') = ''
      BEGIN
         SET @n_continue = 3      
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 81160   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Empty Areakey is not allowed. (ispRLWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '               
         GOTO RETURN_SP    
      END
              
      SET @b_success = 1      
      EXECUTE   nspg_getkey      
               'TaskDetailKey'      
              , 10      
              , @c_taskdetailkey OUTPUT      
              , @b_success       OUTPUT      
              , @n_err           OUTPUT      
              , @c_errmsg        OUTPUT      
      IF NOT @b_success = 1      
      BEGIN      
         SET @n_continue = 3      
         GOTO RETURN_SP    
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
         ,Listkey      
         ,Areakey    
         ,Message03   
         ,CaseID 
         ,LoadKey    
         ,OrderKey 
         )      
         VALUES      
         (      
         @c_taskdetailkey      
         ,@c_TaskType --Tasktype      
         ,@c_Storerkey      
         ,@c_Sku      
         ,@c_UOM -- UOM,      
         ,0  -- UOMQty,      
         ,@n_Qty      
         ,@n_Qty  --systemqty    
         ,@c_Lot       
         ,@c_fromloc       
         ,@c_ID -- from id      
         ,@c_toloc     
         ,@c_ID -- to id      
         ,@c_SourceType --Sourcetype      
         ,@c_Wavekey    --Sourcekey      
         ,@c_Priority   -- Priority        
         ,'9' -- Sourcepriority      
         ,'N' -- Status      
         ,@c_LogicalFromLoc --Logical from loc      
         ,@c_LogicalToLoc   --Logical to loc      
         ,@c_PickMethod    
         ,@c_Wavekey    
         ,''    
         ,@c_Areakey    
         ,@c_Message03  
         ,'' -- caseid
         ,@c_LoadKey  
         ,@c_Orderkey                                             
         )    
    
         SET @n_err = @@ERROR     
    
         IF @n_err <> 0      
         BEGIN    
    
            SET @n_continue = 3      
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
            SET @n_err = 81170   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
    
            GOTO RETURN_SP    
         END       
      END    
   END    
    
   --Update taskdetailkey/wavekey to pickdetail    
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN
      SET @n_ReplenQty = @n_Qty 

      DECLARE CUR_PICKD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
      SELECT PD.PickdetailKey    
            ,PD.Qty    
      FROM WAVEDETAIL WD  WITH (NOLOCK)     
      JOIN PICKDETAIL PD  WITH (NOLOCK) ON (WD.Orderkey = PD.Orderkey)    
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (PD.Orderkey = OD.Orderkey) AND (PD.OrderLineNumber = OD.OrderLineNumber)    
      WHERE WD.Wavekey = @c_Wavekey    
      AND PD.Status = '0'
      AND ISNULL(PD.Taskdetailkey,'') = ''    
      AND PD.Storerkey = @c_Storerkey    
      AND PD.Sku = @c_sku    
      AND PD.Lot = @c_Lot    
      AND PD.Loc = @c_FromLoc    
      AND PD.ID  = @c_ID    
      AND PD.Orderkey = CASE WHEN ISNULL(@c_Orderkey,'') <> '' THEN @c_Orderkey ELSE PD.Orderkey END
      ORDER BY PD.PickDetailKey     
    
      OPEN CUR_PICKD      
    
      FETCH NEXT FROM CUR_PICKD INTO @c_PickdetailKey    
                                    ,@n_PickQty    
         
      WHILE @@FETCH_STATUS <> -1 AND @n_ReplenQty > 0     
      BEGIN    
    
         UPDATE PICKDETAIL WITH (ROWLOCK)    
         SET Taskdetailkey = @c_TaskdetailKey    
            ,EditWho = SUSER_SNAME()    
            ,EditDate= GETDATE()     
            ,TrafficCop = NULL    
         WHERE Pickdetailkey = @c_PickdetailKey    
    
         SET @n_err = @@ERROR    
         IF @n_err <> 0     
         BEGIN    
            SET @n_continue = 3    
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
            SET @n_err = 81180      
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV04)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
            BREAK    
         END     
                   
         SET @n_ReplenQty = @n_ReplenQty - @n_PickQty     
         NEXT_PD:              
         FETCH NEXT FROM CUR_PICKD INTO @c_PickdetailKey    
                                       ,@n_PickQty    
      END    
      CLOSE CUR_PICKD    
      DEALLOCATE CUR_PICKD    
   END  
     
   IF @c_OrderType = 'ECOM'       
      GOTO ECOM                  
   IF @c_OrderType = 'RETAIL'    
      GOTO RETAIL        
END --sp end

GO