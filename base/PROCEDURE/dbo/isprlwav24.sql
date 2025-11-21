SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************/  
/* Stored Procedure: ispRLWAV24                                             */  
/* Creation Date: 07-Mar-2019                                               */  
/* Copyright: LFL                                                           */  
/* Written by:                                                              */  
/*                                                                          */  
/* Purpose: WMS-8050 - CN MAST Release tasks                                */
/*                                                                          */  
/* Called By: wave                                                          */  
/*                                                                          */  
/* PVCS Version: 1.4                                                        */  
/*                                                                          */  
/* Version: 7.0                                                             */  
/*                                                                          */  
/* Data Modifications:                                                      */  
/*                                                                          */  
/* Updates:                                                                 */  
/* Date        Author   Ver   Purposes                                      */  
/* 09-May-2019 NJOW01   1.0   Fix condition                                 */
/* 09-May-2019 NJOW02   1.1   Userdefine01 allow more value                 */
/* 03-Jun-2019 NJOW03   1.2   WMS-9196 Enhancement on task priority and     */
/*                            include single order full case to packstation */
/* 21-Jun-2019 NJOW04   1.3   Fix null value filtering for ECOM_SINGLE_FLAG */
/* 01-04-2020  Wan01    1.4   Sync Exceed & SCE                             */
/* 28-03-2022  NJOW05   1.5   WMS-19303 Support loc table at mastgroup      */
/* 28-03-2022  NJOW05   1.6   DEVOPS combine script                         */
/****************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLWAV24]      
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

    DECLARE  @c_Storerkey NVARCHAR(15)
            ,@c_Facility NVARCHAR(5)
            ,@c_Sku NVARCHAR(20)
            ,@c_PickLot NVARCHAR(10)
            ,@c_Lot NVARCHAR(10)
            ,@c_FromLoc NVARCHAR(10)
            ,@c_Toloc NVARCHAR(10)
            ,@c_ID NVARCHAR(18)
            ,@c_ToID NVARCHAR(18)
            ,@n_Qty INT
            ,@c_SourceType NVARCHAR(30)
            ,@c_TaskType NVARCHAR(10)
            ,@c_UOM NVARCHAR(10)
            ,@n_UOMQty INT
            ,@c_PickMethod NVARCHAR(10)            
            ,@c_Priority NVARCHAR(10)
            ,@c_Taskdetailkey NVARCHAR(10)  
            ,@c_Taskdetailkey_PND NVARCHAR(10)  
            ,@c_PickDetailKey NVARCHAR(10)
            ,@c_NewPickdetailkey NVARCHAR(10)
            ,@n_PickQty INT
            ,@n_TaskBalQty INT
            ,@n_LocBalQty INT
            ,@c_TaskState NVARCHAR(10)
            ,@c_SQL      NVARCHAR(MAX)
            ,@c_SQLParm  NVARCHAR(1000)
            ,@c_Lottable01 NVARCHAR(18)    
            ,@c_Lottable02 NVARCHAR(18)    
            ,@c_Lottable03 NVARCHAR(18)    
            ,@d_Lottable04 DATETIME  
            ,@d_Lottable05 DATETIME   
            ,@c_Lottable06 NVARCHAR(30)    
            ,@c_Lottable07 NVARCHAR(30)    
            ,@c_Lottable08 NVARCHAR(30)    
            ,@c_Lottable09 NVARCHAR(30)    
            ,@c_Lottable10 NVARCHAR(30)    
            ,@c_Lottable11 NVARCHAR(30)    
            ,@c_Lottable12 NVARCHAR(30)    
            ,@d_Lottable13 DATETIME   
            ,@d_Lottable14 DATETIME    
            ,@d_Lottable15 DATETIME            
            ,@c_CaseId     NVARCHAR(20)            
            ,@c_SourcePriority      NVARCHAR(10)
            ,@c_LinkTaskToPick_SQL  NVARCHAR(4000)
            ,@c_PickCondition_SQL   NVARCHAR(4000) 
            ,@c_Message01           NVARCHAR(20)
            ,@c_Userdefine01 NVARCHAR(20)
            ,@c_Userdefine02 NVARCHAR(20)
            ,@c_Userdefine03 NVARCHAR(20) --NJOW03
            ,@c_DocType NVARCHAR(1)
            ,@c_BatchNo NVARCHAR(10)
            ,@c_CLPriority NVARCHAR(10) --NJOW03
            ,@c_Floor NVARCHAR(3) --NJOW05
            ,@c_PrevFloor NVARCHAR(30) --NJOW05
            ,@c_CheckFloor NVARCHAR(1) --NJOW05
            
    DECLARE @c_Field01 NVARCHAR(60)
           ,@c_Field02 NVARCHAR(60)
           ,@c_Field03 NVARCHAR(60)
           ,@c_Field04 NVARCHAR(60)
           ,@c_Field05 NVARCHAR(60)
           ,@c_Field06 NVARCHAR(60)
           ,@c_Field07 NVARCHAR(60)
           ,@c_Field08 NVARCHAR(60)
           ,@c_Field09 NVARCHAR(60)
           ,@c_Field10 NVARCHAR(60)              
           ,@c_TableColumnName NVARCHAR(250)  -- e.g. SKU.Busr1
           ,@c_TableName NVARCHAR(30)  
           ,@c_ColumnName NVARCHAR(30)  
           ,@c_ColumnType NVARCHAR(10)  
           ,@c_SQLField NVARCHAR(2000)  
           ,@c_SQLWhere NVARCHAR(2000)  
           ,@c_SQLGroup NVARCHAR(2000)  
           ,@c_SQLDYN01 NVARCHAR(2000)  
           ,@c_SQLDYN02 NVARCHAR(2000)         
           ,@n_NoofTotePerBatch INT
           ,@c_Loadkey NVARCHAR(10)
           ,@c_PrevLoadkey NVARCHAR(10)
                  
    SET @c_SourceType = 'ispRLWAV24'    
    SET @c_Priority = '9'
    SET @c_TaskType = 'RPF'
    SET @c_PickMethod = 'PP'
    SET @c_SourcePriority = '9'

    -----Wave Validation-----            
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN 
       IF NOT EXISTS (SELECT 1 
                      FROM WAVEDETAIL WD (NOLOCK)
                      JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                      LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType 
                      WHERE WD.Wavekey = @c_Wavekey                   
                      AND PD.Status = '0'
                      AND TD.Taskdetailkey IS NULL
                     )
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83000  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV24)'           
       END      
    END
    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK) 
                   WHERE TD.Wavekey = @c_Wavekey
                   AND TD.Sourcetype = @c_SourceType
                   AND TD.Tasktype IN(@c_TaskType)
                   AND TD.Status <> 'X') 
           OR 
           EXISTS (SELECT 1 
                   FROM WAVEDETAIL WD (NOLOCK)
                   JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey            
                   JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey       
                   WHERE WD.Wavekey = @c_Wavekey    
                   AND ISNULL(PD.notes,'') <> '' 
                   AND ISNULL(PD.Pickslipno,'') <> '' 
                   AND O.Doctype <> 'E')                                          
        BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83010    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV24)'       
        END                 
    END
    
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       IF EXISTS (SELECT 1 
                  FROM WAVEDETAIL WD (NOLOCK)
                  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                  WHERE WD.Wavekey = @c_Wavekey
                  AND O.Status = '0')
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83020    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not allow to release. Found some order in the wave is not allocated yet. (ispRLWAV24)'       
       END
    END   
    
    -----Get Storerkey, facility
    IF  (@n_continue = 1 OR @n_continue = 2)
    BEGIN
        SELECT TOP 1 @c_Storerkey = O.Storerkey, 
                     @c_Facility = O.Facility,
                     @c_Userdefine01 = W.Userdefine01,
                     @c_Userdefine02 = W.USerdefine02,
                     @C_Userdefine03 = W.Userdefine03, --NJOW03
                     @c_DocType = O.DocType
        FROM WAVE W (NOLOCK)
        JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
        JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
        AND W.Wavekey = @c_Wavekey 
    END
            
    --Validate wave field for B2B
    IF (@n_continue = 1 OR @n_continue = 2) AND @c_DocType <> 'E'
    BEGIN
       --IF ISNULL(@c_Userdefine01,'') NOT IN ('1','2')           
       IF NOT EXISTS(SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'MASTGROUP' AND Short = @c_Userdefine01 AND Storerkey = @c_Storerkey) --NJOW02
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83030    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Must key-in grouping method in userdefine01 for B2B. (ispRLWAV24)'       
       END
       ELSE IF ISNUMERIC(@c_Userdefine02) <> 1 OR ISNULL(@c_Userdefine02,'') = ''
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83040    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid total tote for each batch value in userdefine02 for B2B. (ispRLWAV24)'       
       END
       ELSE IF CAST(@c_Userdefine02 AS INT) <= 0 OR CAST(@c_Userdefine02 AS INT) > 50 
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83050    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Total tote for each batch value in userdefine02 must be between 1-50 for B2B. (ispRLWAV24)'               
       END                     
    END   
    
    ----Set Priority  NJOW03
    IF (@n_continue = 1 OR @n_continue = 2)
    BEGIN
       IF ISNULL(@c_Userdefine03,'') IN ('1','2','3','4','5','6','7','8','9')
       BEGIN
          SET @c_Priority = @c_Userdefine03
          SET @c_SourcePriority = @c_Userdefine03     
       END
       ELSE
       BEGIN
           SET @c_CLPriority = ''
           
           SELECT TOP 1 @c_CLPriority = Long
           FROM CODELKUP (NOLOCK)
           WHERE Listname = 'MASTPRIOR'
           AND Short = CASE WHEN ISNULL(@c_DocType, '') = '' THEN 'N' ELSE @c_DocType END 
           AND Storerkey = @c_Storerkey
           
           IF ISNULL(@c_CLPriority,'') <> ''
           BEGIN
             SET @c_Priority = @c_CLPriority
             SET @c_SourcePriority = @c_CLPriority    
           END            
       END
    END
        
    --Create pickdetail Work in progress temporary table
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       CREATE TABLE #PickDetail_WIP(
          [PickDetailKey] [nvarchar](18) NOT NULL PRIMARY KEY,
          [CaseID] [nvarchar](20) NOT NULL DEFAULT (' '),
          [PickHeaderKey] [nvarchar](18) NOT NULL,
          [OrderKey] [nvarchar](10) NOT NULL,
          [OrderLineNumber] [nvarchar](5) NOT NULL,
          [Lot] [nvarchar](10) NOT NULL,
          [Storerkey] [nvarchar](15) NOT NULL,
          [Sku] [nvarchar](20) NOT NULL,
          [AltSku] [nvarchar](20) NOT NULL DEFAULT (' '),
          [UOM] [nvarchar](10) NOT NULL DEFAULT (' '),
          [UOMQty] [int] NOT NULL DEFAULT ((0)),
          [Qty] [int] NOT NULL DEFAULT ((0)),
          [QtyMoved] [int] NOT NULL DEFAULT ((0)),
          [Status] [nvarchar](10) NOT NULL DEFAULT ('0'),
          [DropID] [nvarchar](20) NOT NULL DEFAULT (''),
          [Loc] [nvarchar](10) NOT NULL DEFAULT ('UNKNOWN'),
          [ID] [nvarchar](18) NOT NULL DEFAULT (' '),
          [PackKey] [nvarchar](10) NULL DEFAULT (' '),
          [UpdateSource] [nvarchar](10) NULL DEFAULT ('0'),
          [CartonGroup] [nvarchar](10) NULL,
          [CartonType] [nvarchar](10) NULL,
          [ToLoc] [nvarchar](10) NULL  DEFAULT (' '),
          [DoReplenish] [nvarchar](1) NULL DEFAULT ('N'),
          [ReplenishZone] [nvarchar](10) NULL DEFAULT (' '),
          [DoCartonize] [nvarchar](1) NULL DEFAULT ('N'),
          [PickMethod] [nvarchar](1) NOT NULL DEFAULT (' '),
          [WaveKey] [nvarchar](10) NOT NULL DEFAULT (' '),
          [EffectiveDate] [datetime] NOT NULL DEFAULT (getdate()),
          [AddDate] [datetime] NOT NULL DEFAULT (getdate()),
          [AddWho] [nvarchar](128) NOT NULL DEFAULT (suser_sname()),
          [EditDate] [datetime] NOT NULL DEFAULT (getdate()),
          [EditWho] [nvarchar](128) NOT NULL DEFAULT (suser_sname()),
          [TrafficCop] [nvarchar](1) NULL,
          [ArchiveCop] [nvarchar](1) NULL,
          [OptimizeCop] [nvarchar](1) NULL,
          [ShipFlag] [nvarchar](1) NULL DEFAULT ('0'),
          [PickSlipNo] [nvarchar](10) NULL,
          [TaskDetailKey] [nvarchar](10) NULL,
          [TaskManagerReasonKey] [nvarchar](10) NULL,
          [Notes] [nvarchar](4000) NULL,
          [MoveRefKey] [nvarchar](10) NULL DEFAULT (''),
          [WIP_Refno] [nvarchar](30) NULL DEFAULT (''),
          [Channel_ID] [bigint] NULL DEFAULT ((0)))      
    END
        
    WHILE @@TRANCOUNT > 0
    BEGIN
       COMMIT TRAN
    END
    
    BEGIN TRAN   
    ----Reallocate VNA pickdetail to Mezzanine----
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
      --Get available qty from Mezzanine that can swap from pickdetail at VNA
      DECLARE cur_pickloc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT LOTxLOCxID.Storerkey, LOTxLOCxID.Sku, LOTxLOCxID.Lot, LOTxLOCxID.Loc, LOTxLOCxID.Id,
             LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen,
             LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
             LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
             LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15 
      FROM LOTATTRIBUTE LA (NOLOCK) 
      JOIN LOT (NOLOCK) ON LOT.LOT = LA.LOT 
      JOIN LOTxLOCxID (NOLOCK) ON LOTXLOCXID.Lot = LOT.LOT   
      JOIN SKUXLOC (NOLOCK) ON SKUXLOC.Storerkey = LOTxLOCxID.Storerkey AND SKUXLOC.Sku = LOTxLOCxID.Sku AND SKUXLOC.Loc = LOTxLOCxID.Loc 
      JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC
      JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID  
      JOIN (SELECT DISTINCT PD.Storerkey, PD.Sku    
            FROM ORDERS O (NOLOCK) 
            JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
            JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Orderkey
            JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc 
            AND WD.Wavekey = @c_Wavekey
            AND PD.UOM IN ('7')
            AND LOC.LocationCategory = 'VNA') AS BulkSku ON LOTxLOCxID.Storerkey = BulkSku.Storerkey AND LOTxLOCxID.Sku = BulkSku.Sku  
      WHERE LOT.STATUS = 'OK' 
      AND LOC.STATUS = 'OK' 
      AND ID.STATUS = 'OK'   
      AND LOC.LocationFlag = 'NONE' 
      AND LOC.Facility = @c_facility  
      AND LOC.LocationCategory = 'Mezzanine'
      AND LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen > 0
      ORDER BY LOTxLOCxID.Storerkey, LOTxLOCxID.Sku, LA.Lottable05,  LOC.LogicalLocation, LOC.Loc      
      
      OPEN cur_pickloc  
       
      FETCH NEXT FROM cur_pickloc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ID, @n_Qty,
                                       @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                       @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                                       @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15 
       
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
          --get pickdetail from VNA which can swap to available at Mezzanine
         SELECT @C_SQL = N'
            DECLARE cur_Bulkloc CURSOR FAST_FORWARD READ_ONLY FOR  
                SELECT PD.Pickdetailkey, PD.Lot, PD.Qty           
                FROM WAVEDETAIL WD (NOLOCK)
                JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
                JOIN PICKDETAIL PD (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber 
                JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
                JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
                WHERE WD.Wavekey = @c_Wavekey
                AND PD.Status = ''0''
                AND PD.UOM IN (''7'')
                AND LOC.LocationCategory = ''VNA''
                AND PD.Storerkey = @c_Storerkey
                AND PD.Sku = @c_Sku
                AND ISNULL(PD.Taskdetailkey,'''') = ''''      
                AND OD.Lottable01 = CASE WHEN OD.Lottable01 <> '''' AND OD.Lottable01 IS NOT NULL THEN @c_Lottable01 ELSE OD.Lottable01 END
                AND OD.Lottable02 = CASE WHEN OD.Lottable02 <> '''' AND OD.Lottable02 IS NOT NULL THEN @c_Lottable02 ELSE OD.Lottable02 END
                AND OD.Lottable03 = CASE WHEN OD.Lottable03 <> '''' AND OD.Lottable03 IS NOT NULL THEN @c_Lottable03 ELSE OD.Lottable03 END
                AND 0 = CASE WHEN CONVERT(NVARCHAR(8) ,OD.Lottable04 ,112) <> ''19000101'' AND OD.Lottable04 IS NOT NULL THEN ISNULL(DATEDIFF(DAY, OD.Lottable04, @d_Lottable04),1) ELSE 0 END
                AND 0 = CASE WHEN CONVERT(NVARCHAR(8) ,OD.Lottable05 ,112) <> ''19000101'' AND OD.Lottable05 IS NOT NULL THEN ISNULL(DATEDIFF(DAY, OD.Lottable05, @d_Lottable05),1) ELSE 0 END
                AND OD.Lottable06 = CASE WHEN OD.Lottable06 <> '''' AND OD.Lottable06 IS NOT NULL THEN @c_Lottable06 ELSE OD.Lottable06 END
                AND OD.Lottable07 = CASE WHEN OD.Lottable07 <> '''' AND OD.Lottable07 IS NOT NULL THEN @c_Lottable07 ELSE OD.Lottable07 END
                AND OD.Lottable08 = CASE WHEN OD.Lottable08 <> '''' AND OD.Lottable08 IS NOT NULL THEN @c_Lottable08 ELSE OD.Lottable08 END
                AND OD.Lottable09 = CASE WHEN OD.Lottable09 <> '''' AND OD.Lottable09 IS NOT NULL THEN @c_Lottable09 ELSE OD.Lottable09 END
                AND OD.Lottable10 = CASE WHEN OD.Lottable10 <> '''' AND OD.Lottable10 IS NOT NULL THEN @c_Lottable10 ELSE OD.Lottable10 END
                AND OD.Lottable11 = CASE WHEN OD.Lottable11 <> '''' AND OD.Lottable11 IS NOT NULL THEN @c_Lottable11 ELSE OD.Lottable11 END
                AND OD.Lottable12 = CASE WHEN OD.Lottable12 <> '''' AND OD.Lottable12 IS NOT NULL THEN @c_Lottable12 ELSE OD.Lottable12 END
                AND 0 = CASE WHEN CONVERT(NVARCHAR(8) ,OD.Lottable13 ,112) <> ''19000101'' AND OD.Lottable13 IS NOT NULL THEN ISNULL(DATEDIFF(DAY, OD.Lottable13, @d_Lottable13),1) ELSE 0 END
                AND 0 = CASE WHEN CONVERT(NVARCHAR(8) ,OD.Lottable14 ,112) <> ''19000101'' AND OD.Lottable14 IS NOT NULL THEN ISNULL(DATEDIFF(DAY, OD.Lottable14, @d_Lottable14),1) ELSE 0 END
                AND 0 = CASE WHEN CONVERT(NVARCHAR(8) ,OD.Lottable15 ,112) <> ''19000101'' AND OD.Lottable15 IS NOT NULL THEN  ISNULL(DATEDIFF(DAY, OD.Lottable15, @d_Lottable15),1) ELSE 0 END ' +
                ' ORDER BY CASE WHEN PD.Lot = ''' + RTRIM(@c_Lot) + ''' THEN 1 ELSE 2 END, LA.Lottable04 DESC, LOC.LogicalLocation DESC, PD.Loc DESC '

             SET @c_SQLParm =  N'@c_Wavekey    NVARCHAR(10), @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20),' +
                                '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +
                                '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +
                                '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME ' 
             
             EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Wavekey, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                                @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
                                @d_Lottable13, @d_Lottable14, @d_Lottable15
                                
         OPEN cur_Bulkloc  
          
         FETCH NEXT FROM cur_Bulkloc INTO @c_Pickdetailkey, @c_PickLot, @n_Pickqty
          
         WHILE @@FETCH_STATUS = 0 AND @n_Qty > 0 AND @n_continue IN(1,2)
         BEGIN
              IF @n_Qty >= @n_PickQty
              BEGIN
                --swap pickdetail to pick include swap to different lot
                 UPDATE PICKDETAIL WITH (ROWLOCK)
                 SET Qty = 0
                 WHERE Pickdetailkey = @c_Pickdetailkey

               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update PickDetail Table. (ispRLWAV24)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END      
                 
                 UPDATE PICKDETAIL WITH (ROWLOCK)
                 SET Lot = @c_Lot,
                     Loc = @c_ToLoc,
                     Id = @c_ID,
                     Qty = @n_PickQty,
                     Notes = 'Swap from VNA',
                     UOM = '6'
                 WHERE Pickdetailkey = @c_Pickdetailkey

               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83070     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update PickDetail Table. (ispRLWAV24)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END  
               
               SET @n_Qty = @n_Qty - @n_PickQty    
              END              
              ELSE
              BEGIN
                --split pickdetail to pick
                 UPDATE PICKDETAIL WITH (ROWLOCK)
                 SET Qty = Qty - @n_Qty
                 WHERE Pickdetailkey = @c_Pickdetailkey
                 
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
               END                  
            
                 INSERT INTO PICKDETAIL
                           (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, 
                            Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],         
                            DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
                            ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,           
                            WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo,            
                            TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey)               
               SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, @c_Lot,                                      
                      Storerkey, Sku, AltSku, '6', CASE WHEN UOM IN('6','7') THEN @n_Qty ELSE UOMQty END , @n_Qty, QtyMoved, Status,       
                      '', @c_ToLoc, @c_ID, PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                                      
                      WaveKey, EffectiveDate, NULL, ShipFlag, PickSlipNo,                                                               
                      TaskDetailKey, TaskManagerReasonKey, 'Split From Pickdetail#'+@c_Pickdetailkey , MoveRefKey                                                           
               FROM PICKDETAIL (NOLOCK)                                                                                             
               WHERE PickdetailKey = @c_Pickdetailkey

               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83040     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert PickDetail Table. (ispRLWAV24)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END      
               
               SET @n_Qty = 0    
              END
            
            FETCH NEXT FROM cur_Bulkloc INTO @c_Pickdetailkey, @c_PickLot, @n_Pickqty
         END
         CLOSE cur_Bulkloc
         DEALLOCATE cur_Bulkloc
                                                              
         FETCH NEXT FROM cur_pickloc INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ID, @n_Qty,
                                          @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                          @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                                          @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15          
      END
      CLOSE cur_pickloc
      DEALLOCATE cur_pickloc              
    END

    IF @n_continue = 3
       ROLLBACK
    ELSE
       COMMIT TRAN   
        
    BEGIN TRAN   
    ----Reallocate VNA pickdetail to VAN and PnD in replenish----
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
      --Get available qty from replenish task include PND that can merge from pickdetail at VNA
      SELECT TD.Storerkey, TD.Sku, TD.Lot, TD.FromLoc AS Loc, TD.FromID AS ID, 
             CASE WHEN (TD.Qty - TD.SystemQty) > (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) THEN
                  (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)  ELSE (TD.Qty - TD.SystemQty) END AS TaskBalQty,  --NJOW01
             LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked AS LocBalQty,
             LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
             LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
             LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15 
      INTO #TMP_REPLEN       
      FROM TASKDETAIL TD (NOLOCK)
      JOIN LOTATTRIBUTE LA (NOLOCK) ON TD.Lot = LA.Lot
      JOIN LOTXLOCXID LLI (NOLOCK) ON TD.Lot = LLI.Lot AND TD.FromLoc = LLI.Loc AND TD.FromID = LLI.ID
      WHERE TD.TaskType = 'RPF' 
      AND TD.Status = '0' 
      AND TD.SourceType = @c_SourceType
      AND TD.Qty > TD.SystemQty
      AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked > 0
      UNION ALL    
      SELECT TD.Storerkey, TD.Sku, PND.Lot, PND.FromLoc AS Loc, PND.FromID AS ID, 
             CASE WHEN (TD.Qty - TD.SystemQty) > (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) THEN
                  (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)  ELSE (TD.Qty - TD.SystemQty) END AS TaskBalQty,  --NJOW01
             LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked AS LocBalQty, 
             LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
             LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
             LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15 
      FROM TASKDETAIL TD (NOLOCK)
      JOIN TASKDETAIL PND ON TD.Taskdetailkey = PND.Sourcekey AND TD.Storerkey = PND.Storerkey AND TD.Sku = PND.Sku
      JOIN LOTATTRIBUTE LA (NOLOCK) ON PND.Lot = LA.Lot
      JOIN LOTXLOCXID LLI (NOLOCK) ON PND.Lot = LLI.Lot AND PND.FromLoc = LLI.Loc AND PND.FromID = LLI.ID
      WHERE TD.TaskType = 'RPF' 
      AND PND.TaskType = 'RPT' 
      AND TD.Status = '9'  
      AND PND.Taskdetailkey IS NOT NULL
      AND PND.Status NOT IN('9','X')
      AND TD.SourceType = @c_SourceType
      AND TD.Qty > TD.SystemQty
      AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked > 0

      DECLARE cur_replen CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT REP.Storerkey, REP.Sku, REP.Lot, REP.Loc, REP.ID, SUM(REP.TaskBalQty), SUM(REP.LocBalQty),
             REP.Lottable01, REP.Lottable02, REP.Lottable03, REP.Lottable04, REP.Lottable05, 
             REP.Lottable06, REP.Lottable07, REP.Lottable08, REP.Lottable09, REP.Lottable10, 
             REP.Lottable11, REP.Lottable12, REP.Lottable13, REP.Lottable14, REP.Lottable15 
      FROM #TMP_REPLEN REP
      JOIN LOC (NOLOCK) ON REP.Loc = LOC.Loc
      WHERE REP.TaskBalQty > 0 --NJOW01
      GROUP BY REP.Storerkey, REP.Sku, REP.Lot, REP.Loc, REP.ID, LOC.LocationType, LOC.LocationGroup, LOC.LogicalLocation, Loc.LocationCategory,
               REP.Lottable01, REP.Lottable02, REP.Lottable03, REP.Lottable04, REP.Lottable05, 
               REP.Lottable06, REP.Lottable07, REP.Lottable08, REP.Lottable09, REP.Lottable10, 
               REP.Lottable11, REP.Lottable12, REP.Lottable13, REP.Lottable14, REP.Lottable15        
      ORDER BY REP.Storerkey, REP.Sku, CASE WHEN LOC.LocationCategory = 'VNA' THEN 1 ELSE 2 END, 
               REP.Lottable04, LOC.LogicalLocation, REP.Loc      
      
      OPEN cur_replen  
       
      FETCH NEXT FROM cur_replen INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ID, @n_TaskBalQty, @n_LocBalQty,
                                       @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                       @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                                       @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15 
       
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
         IF @n_TaskBalQty < @n_LocBalQty --make sure qty not over task bal qty or loc bal qty
            SET @n_Qty = @n_TaskBalQty 
         ELSE 
            SET @n_Qty = @n_LocBalQty
        
        --print  '@c_Sku ' + @c_sku + ' @c_Lot ' + @c_lot + ' @c_ToLoc ' + @c_toloc + ' @c_ID ' + @c_id +  ' @n_TaskBalQty ' + cast(@n_taskbalqty as nvarchar) + ' @n_LocBalQty ' + cast(@n_LocBalQty as nvarchar)   
         
          --get pickdetail from VNA which can swap to replen at VNA and PND
         SELECT @C_SQL = N'
            DECLARE cur_BulklocRep CURSOR FAST_FORWARD READ_ONLY FOR  
                SELECT PD.Pickdetailkey, PD.Lot, PD.Qty           
                FROM WAVEDETAIL WD (NOLOCK)
                JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
                JOIN PICKDETAIL PD (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber 
                JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
                JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
                LEFT JOIN #TMP_REPLEN TR ON PD.Lot = TR.Lot AND PD.Loc = TR.Loc AND PD.Id = TR.Id 
                WHERE WD.Wavekey = @c_Wavekey
                AND PD.Status = ''0''
                AND PD.UOM IN (''7'')
                AND LOC.LocationCategory = ''VNA''
                AND PD.Storerkey = @c_Storerkey
                AND PD.Sku = @c_Sku
                AND ISNULL(PD.Taskdetailkey,'''') = ''''      
                AND OD.Lottable01 = CASE WHEN OD.Lottable01 <> '''' AND OD.Lottable01 IS NOT NULL THEN @c_Lottable01 ELSE OD.Lottable01 END
                AND OD.Lottable02 = CASE WHEN OD.Lottable02 <> '''' AND OD.Lottable02 IS NOT NULL THEN @c_Lottable02 ELSE OD.Lottable02 END
                AND OD.Lottable03 = CASE WHEN OD.Lottable03 <> '''' AND OD.Lottable03 IS NOT NULL THEN @c_Lottable03 ELSE OD.Lottable03 END
                AND 0 = CASE WHEN CONVERT(NVARCHAR(8) ,OD.Lottable04 ,112) <> ''19000101'' AND OD.Lottable04 IS NOT NULL THEN ISNULL(DATEDIFF(DAY, OD.Lottable04, @d_Lottable04),1) ELSE 0 END
                AND 0 = CASE WHEN CONVERT(NVARCHAR(8) ,OD.Lottable05 ,112) <> ''19000101'' AND OD.Lottable05 IS NOT NULL THEN ISNULL(DATEDIFF(DAY, OD.Lottable05, @d_Lottable05),1) ELSE 0 END
                AND OD.Lottable06 = CASE WHEN OD.Lottable06 <> '''' AND OD.Lottable06 IS NOT NULL THEN @c_Lottable06 ELSE OD.Lottable06 END
                AND OD.Lottable07 = CASE WHEN OD.Lottable07 <> '''' AND OD.Lottable07 IS NOT NULL THEN @c_Lottable07 ELSE OD.Lottable07 END
                AND OD.Lottable08 = CASE WHEN OD.Lottable08 <> '''' AND OD.Lottable08 IS NOT NULL THEN @c_Lottable08 ELSE OD.Lottable08 END
                AND OD.Lottable09 = CASE WHEN OD.Lottable09 <> '''' AND OD.Lottable09 IS NOT NULL THEN @c_Lottable09 ELSE OD.Lottable09 END
                AND OD.Lottable10 = CASE WHEN OD.Lottable10 <> '''' AND OD.Lottable10 IS NOT NULL THEN @c_Lottable10 ELSE OD.Lottable10 END
                AND OD.Lottable11 = CASE WHEN OD.Lottable11 <> '''' AND OD.Lottable11 IS NOT NULL THEN @c_Lottable11 ELSE OD.Lottable11 END
                AND OD.Lottable12 = CASE WHEN OD.Lottable12 <> '''' AND OD.Lottable12 IS NOT NULL THEN @c_Lottable12 ELSE OD.Lottable12 END
                AND 0 = CASE WHEN CONVERT(NVARCHAR(8) ,OD.Lottable13 ,112) <> ''19000101'' AND OD.Lottable13 IS NOT NULL THEN ISNULL(DATEDIFF(DAY, OD.Lottable13, @d_Lottable13),1) ELSE 0 END
                AND 0 = CASE WHEN CONVERT(NVARCHAR(8) ,OD.Lottable14 ,112) <> ''19000101'' AND OD.Lottable14 IS NOT NULL THEN ISNULL(DATEDIFF(DAY, OD.Lottable14, @d_Lottable14),1) ELSE 0 END
                AND 0 = CASE WHEN CONVERT(NVARCHAR(8) ,OD.Lottable15 ,112) <> ''19000101'' AND OD.Lottable15 IS NOT NULL THEN  ISNULL(DATEDIFF(DAY, OD.Lottable15, @d_Lottable15),1) ELSE 0 END 
                AND TR.Loc IS NULL ' +  --only retrieve pickdetail without other replen task                
                ' GROUP BY PD.Pickdetailkey, PD.Lot, PD.Qty, LA.Lottable04, LOC.LogicalLocation, PD.Loc ' +                        --              
                ' ORDER BY CASE WHEN PD.Lot = ''' + RTRIM(@c_Lot) + ''' THEN 1 ELSE 2 END, LA.Lottable04 DESC, LOC.LogicalLocation DESC, PD.Loc DESC '

             SET @c_SQLParm =  N'@c_Wavekey    NVARCHAR(10), @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20),' +
                                '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +
                                '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +
                                '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME ' 
             
             EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_Wavekey, @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                                @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
                                @d_Lottable13, @d_Lottable14, @d_Lottable15
                                
         OPEN cur_BulklocRep  
          
         FETCH NEXT FROM cur_BulklocRep INTO @c_Pickdetailkey, @c_PickLot, @n_Pickqty
          
         WHILE @@FETCH_STATUS = 0 AND @n_Qty > 0 AND @n_continue IN(1,2)
         BEGIN            
            --print  '@c_Pickdetailkey ' + @c_Pickdetailkey + ' @c_PickLot ' + @c_PickLot + ' @n_Pickqty ' + cast(@n_Pickqty as nvarchar)+  ' @n_Qty ' + cast(@n_Qty as nvarchar)   

              IF @n_Qty >= @n_PickQty
              BEGIN
                --swap pickdetail to pick include swap to different lot
                 UPDATE PICKDETAIL WITH (ROWLOCK)
                 SET Qty = 0
                 WHERE Pickdetailkey = @c_Pickdetailkey

               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83080     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update PickDetail Table. (ispRLWAV24)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END      
                 
                 UPDATE PICKDETAIL WITH (ROWLOCK)
                 SET Lot = @c_Lot,
                     Loc = @c_ToLoc,
                     Id = @c_ID,
                     Qty = @n_PickQty,
                     Notes = 'Swap from VNA'
                 WHERE Pickdetailkey = @c_Pickdetailkey

               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83090     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update PickDetail Table. (ispRLWAV24)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END  
               
               SET @n_Qty = @n_Qty - @n_PickQty    
              END              
              ELSE
              BEGIN
                --split pickdetail to pick
                 UPDATE PICKDETAIL WITH (ROWLOCK)
                 SET Qty = Qty - @n_Qty
                 WHERE Pickdetailkey = @c_Pickdetailkey
                 
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
               END                  
            
                 INSERT INTO PICKDETAIL
                           (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, 
                            Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],         
                            DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
                            ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,           
                            WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo,            
                            TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey)               
               SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, @c_Lot,                                      
                      Storerkey, Sku, AltSku, UOM, CASE WHEN UOM IN('6','7') THEN @n_Qty ELSE UOMQty END , @n_Qty, QtyMoved, Status,       
                      '', @c_ToLoc, @c_ID, PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                                      
                      WaveKey, EffectiveDate, NULL, ShipFlag, PickSlipNo,                                                               
                      TaskDetailKey, TaskManagerReasonKey, 'Split From Pickdetail#'+@c_Pickdetailkey , MoveRefKey                                                           
               FROM PICKDETAIL (NOLOCK)                                                                                             
               WHERE PickdetailKey = @c_Pickdetailkey

               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83100     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert PickDetail Table. (ispRLWAV24)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END      
               
               SET @n_Qty = 0    
              END
            
            FETCH NEXT FROM cur_BulklocRep INTO @c_Pickdetailkey, @c_PickLot, @n_Pickqty
         END
         CLOSE cur_BulklocRep
         DEALLOCATE cur_BulklocRep
                                                              
         FETCH NEXT FROM cur_replen INTO @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ID, @n_TaskBalQty, @n_LocBalQty,
                                         @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                         @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                                         @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15 
      END
      CLOSE cur_replen
      DEALLOCATE cur_replen            
    END
    IF @n_continue = 3
       ROLLBACK
    ELSE
       COMMIT TRAN   

    BEGIN TRAN   
    ----Combine VNA and PnD pickdetail to existing replen task----
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
      --Get available qty from replenish task include PND that can merge from pickdetail of same loc
      DECLARE cur_combinereplen CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT TD.Taskdetailkey, TD.Storerkey, TD.Sku, TD.Lot, TD.FromLoc AS Loc, TD.FromID AS ID, 
                TD.Qty - TD.SystemQty AS TaskBalQty, 
                --CASE WHEN (TD.Qty - TD.SystemQty) > (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) THEN
                --  (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)  ELSE (TD.Qty - TD.SystemQty) END AS TaskBalQty,  --NJOW01
                'REP', '' AS Taskdetailkey_PND, TD.CaseID
         FROM TASKDETAIL TD (NOLOCK)
         JOIN LOTXLOCXID LLI (NOLOCK) ON TD.Lot = LLI.Lot AND TD.FromLoc = LLI.Loc AND TD.FromID = LLI.ID --NJOW01         
         WHERE TD.TaskType = 'RPF' 
         AND TD.Status = '0'
         AND TD.SourceType = @c_SourceType
         AND TD.Qty > TD.SystemQty
         UNION ALL    
         SELECT TD.Taskdetailkey, TD.Storerkey, TD.Sku, PND.Lot, PND.FromLoc AS Loc, PND.FromID AS ID, 
                TD.Qty - TD.SystemQty AS TaskBalQty, 
                --CASE WHEN (TD.Qty - TD.SystemQty) > (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) THEN
                --  (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)  ELSE (TD.Qty - TD.SystemQty) END AS TaskBalQty,  --NJOW01
                'PND', PND.TaskDetailKey, PND.CaseID 
         FROM TASKDETAIL TD (NOLOCK)
         JOIN TASKDETAIL PND ON TD.Taskdetailkey = PND.Sourcekey AND TD.Storerkey = PND.Storerkey AND TD.Sku = PND.Sku
         JOIN LOTXLOCXID LLI (NOLOCK) ON PND.Lot = LLI.Lot AND PND.FromLoc = LLI.Loc AND PND.FromID = LLI.ID --NJOW01         
         WHERE TD.TaskType = 'RPF' 
         AND PND.TaskType = 'RPT' 
         AND TD.Status = '9'  
         AND PND.Taskdetailkey IS NOT NULL
         AND PND.Status NOT IN('9','X')
         AND TD.SourceType = @c_SourceType
         AND TD.Qty > TD.SystemQty
            
      OPEN cur_combinereplen  
       
      FETCH NEXT FROM cur_combinereplen INTO @c_Taskdetailkey, @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ID, @n_Qty, @c_TaskState, @c_Taskdetailkey_PND, @c_CaseID
       
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN       
          --get pickdetail from replen which can merge to replen task at vna and PND
         DECLARE cur_RepLocPickDet CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT DISTINCT PD.Pickdetailkey, PD.Qty           
            FROM WAVEDETAIL WD (NOLOCK)
            JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey  
            WHERE WD.Wavekey = @c_Wavekey
            AND PD.Status = '0'
            AND PD.UOM IN ('7')
            AND PD.Lot = @c_Lot
            AND PD.Loc =  @c_ToLoc
            AND PD.Id = @c_ID
            AND PD.Storerkey = @c_Storerkey
            AND PD.Sku = @c_Sku
            AND ISNULL(PD.Taskdetailkey,'') = '' 
            ORDER BY PD.Qty 
                                
         OPEN cur_RepLocPickDet  
          
         FETCH NEXT FROM cur_RepLocPickDet INTO @c_Pickdetailkey, @n_Pickqty
          
         WHILE @@FETCH_STATUS = 0 AND @n_Qty > 0 AND @n_continue IN(1,2)
         BEGIN            
              IF @n_Qty >= @n_PickQty
              BEGIN
                --Assign pickdetail to the task
                 UPDATE PICKDETAIL WITH (ROWLOCK)
                 SET TaskDetailkey = CASE WHEN @c_TaskState = 'PND' THEN @c_Taskdetailkey_PND ELSE @c_Taskdetailkey END,
                     DropID =  CASE WHEN @c_TaskState = 'PND' THEN @c_CaseID ELSE DropID END,
                     TrafficCop = NULL
                 WHERE Pickdetailkey = @c_Pickdetailkey  
                                                                                                                                    
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83110     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update PickDetail Table. (ispRLWAV24)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END
               
               IF @c_TaskState = 'PND'  
               BEGIN
                    --Pick and drop loc no need update qty replen
                  UPDATE TASKDETAIL WITH (ROWLOCK)
                  SET Message03 = CASE WHEN ISNULL(Message03,'') = '' THEN 'WV:' + @c_Wavekey ELSE Message03 END,
                      SystemQty = SystemQty + @n_PickQty,
                      Priority = '2', --NJOW03
                      TrafficCop = NULL
                  WHERE Taskdetailkey = @c_Taskdetailkey

                  UPDATE TASKDETAIL WITH (ROWLOCK)
                  SET Message03 = CASE WHEN ISNULL(Message03,'') = '' THEN 'WV:' + @c_Wavekey ELSE Message03 END,
                      TrafficCop = NULL
                  WHERE Taskdetailkey = @c_Taskdetailkey_PND
               END
               ELSE
               BEGIN                
                  UPDATE TASKDETAIL WITH (ROWLOCK)
                  SET Message03 = CASE WHEN ISNULL(Message03,'') = '' THEN 'WV:' + @c_Wavekey ELSE Message03 END,
                      SystemQty = SystemQty + @n_PickQty,
                      QtyReplen = CASE WHEN QtyReplen - @n_PickQty < 0 THEN 0 ELSE QtyReplen - @n_PickQty END,
                      Priority = '2' --NJOW03
                  WHERE Taskdetailkey = @c_Taskdetailkey
               END
               
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83120     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update Taskdetail Table. (ispRLWAV24)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END      
                                                                    
               SET @n_Qty = @n_Qty - @n_PickQty    
              END              
              ELSE
              BEGIN
                --split pickdetail to pick
                 UPDATE PICKDETAIL WITH (ROWLOCK)
                 SET Qty = Qty - @n_Qty
                 WHERE Pickdetailkey = @c_Pickdetailkey
                 
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
               END                  
            
                 INSERT INTO PICKDETAIL
                           (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, 
                            Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],         
                            DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
                            ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,           
                            WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo,            
                            TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey)               
               SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,                                      
                      Storerkey, Sku, AltSku, UOM, CASE WHEN UOM IN('6','7') THEN @n_Qty ELSE UOMQty END , @n_Qty, QtyMoved, Status,       
                      @c_CaseID, Loc, Id, PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                                      
                      WaveKey, EffectiveDate, NULL, ShipFlag, PickSlipNo,                                                               
                      @c_Taskdetailkey, TaskManagerReasonKey, 'Split From Pickdetail#'+@c_Pickdetailkey + ' (MergeTsk)' , MoveRefKey                                                           
               FROM PICKDETAIL (NOLOCK)                                                                                             
               WHERE PickdetailKey = @c_Pickdetailkey

               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83130     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert PickDetail Table. (ispRLWAV24)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END      
               
               IF @c_TaskState = 'PND'  
               BEGIN
                    --Pick and drop loc no need update qty replen
                  UPDATE TASKDETAIL WITH (ROWLOCK)
                  SET Message03 = CASE WHEN ISNULL(Message03,'') = '' THEN 'WV:' + @c_Wavekey ELSE Message03 END,
                      SystemQty = SystemQty + @n_PickQty,
                      Priority = '2' --NJOW03                      
                  WHERE Taskdetailkey = @c_Taskdetailkey
               END
               ELSE
               BEGIN
                  UPDATE TASKDETAIL WITH (ROWLOCK)
                  SET Message03 = CASE WHEN ISNULL(Message03,'') = '' THEN 'WV:' + @c_Wavekey ELSE Message03 END,
                      SystemQty = SystemQty + @n_PickQty,
                      QtyReplen = CASE WHEN QtyReplen - @n_PickQty < 0 THEN 0 ELSE QtyReplen - @n_PickQty END,
                      Priority = '2' --NJOW03                      
                  WHERE Taskdetailkey = @c_Taskdetailkey
               END

               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83140     -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update Taskdetail Table. (ispRLWAV24)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END      
               
               SET @n_Qty = 0    
              END
            
            FETCH NEXT FROM cur_RepLocPickDet INTO @c_Pickdetailkey, @n_Pickqty
         END
         CLOSE cur_RepLocPickDet
         DEALLOCATE cur_RepLocPickDet
                                                              
         FETCH NEXT FROM cur_combinereplen INTO @c_Taskdetailkey, @c_Storerkey, @c_Sku, @c_Lot, @c_ToLoc, @c_ID, @n_Qty, @c_TaskState, @c_Taskdetailkey_PND, @c_CaseID
      END
      CLOSE cur_combinereplen
      DEALLOCATE cur_combinereplen              
    END
    IF @n_continue = 3
       ROLLBACK
    ELSE
       COMMIT TRAN   
    
    WHILE @@TRANCOUNT < @n_starttcnt
    BEGIN
       BEGIN TRAN
    END
    
    IF @@TRANCOUNT  = 0
      BEGIN TRAN        

    --Initialize Pickdetail work in progress staging table
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       EXEC isp_CreatePickdetail_WIP
            @c_Loadkey               = ''
           ,@c_Wavekey               = @c_wavekey  
           ,@c_WIP_RefNo             = @c_SourceType 
           ,@c_PickCondition_SQL     = ''
           ,@c_Action                = 'I'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
           ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
           ,@b_Success               = @b_Success OUTPUT
           ,@n_Err                   = @n_Err     OUTPUT 
           ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
        IF @b_Success <> 1
        BEGIN
           SET @n_continue = 3
        END          
    END

    -----Create full case task from VNA to Pack station for B2C (Single order) NJOW03
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        SET @c_Message01 = 'PACKSTATION-EC'
       SET @c_PickCondition_SQL = 'AND PICKDETAIL.UOM = ''2'' AND LOC.LocationCategory = ''VNA'' AND ISNULL(PICKDETAIL.Taskdetailkey,'''') = '''' AND ORDERS.DocType = ''E'' AND ISNULL(ORDERS.ECOM_SINGLE_Flag,'''') = ''S'' '         
       SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM AND ORDERS.DocType = ''E'' AND ISNULL(ORDERS.ECOM_SINGLE_Flag,'''') = ''S'' '
       SET @c_ToLoc = 'DTCPACKST'
             
       EXEC isp_CreateTaskByPick
            @c_TaskType              = @c_TaskType
           ,@c_Wavekey               = @c_Wavekey  
           ,@c_ToLoc                 = @c_ToLoc       
           ,@c_ToLoc_Strategy        = ''
           ,@c_PickMethod            = @c_PickMethod   -- ?=Auto determine FP/PP by inv qty available  ?TASKQTY=(Qty available - taskqty)  ?ROUNDUP=Qty available - (qty - systemqty)
           ,@c_Priority              = @c_Priority      
           ,@c_SourcePriority        = @c_SourcePriority           
           ,@c_Message01             = @c_Message01      
           ,@c_SourceType            = @c_SourceType      
           ,@c_SourceKey             = @c_Wavekey         
           ,@c_CallSource            = 'WAVE' -- WAVE / LOADPLAN 
           ,@c_PickCondition_SQL     = @c_PickCondition_SQL   -- Additional condition to filter pickdetail. e.g. AND PICKDETAIL.UOM='2' AND LOC.LoctionType = 'OTHER'
           ,@c_LinkTaskToPick        = 'WIP'    -- N=No update taskdetailkey to pickdetail Y=Update taskdetailkey to pickdetail  WIP=Update taskdetailkey to pickdetail_wip
           ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL   -- Additional sql condition to retrieve the pickdetail like AND PICKDETAIL.UOM = @c_UOM or Order BY
           ,@c_ReserveQtyReplen      = 'N'    -- TASKQTY=Reserve all task qty for replenish at Lotxlocxid ROUNDUP=Reserve round up to full carton/pallet qty only (qty - systemqty)
           ,@c_ReservePendingMoveIn  = 'N'    -- N=No update @n_qty to @n_PendingMoveIn Y=Update @n_qty to @n_PendingMoveIn           ,@c_WIP_RefNo             = @c_SourceType     -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
           ,@c_WIP_RefNo             = @c_SourceType     -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
           ,@c_RoundUpQty            = 'N'    -- FC=Round up qty to full carton by packkey/ucc FP=Round up qty to full pallet by packkey/ucc  FL=Round up to full location qty
           ,@c_SplitTaskByCase       = 'Y'    -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.
           ,@c_ZeroSystemQty         = 'N'    -- N=@n_SystemQty will copy from @n_Qty if @n_SystemQty=0 Y=@n_SystemQty force to zero.
           ,@c_SplitTaskByOrder      = 'N'    -- N=No slip by order Y=Split TASK by Order.            
           ,@c_CombineTasks          = 'N'    -- N=No combine Y=Combine task of same lot,from/to loc and id. usually apply for replenishment task with round up full case/pallet and systemqty is the actual pickdetail.qty
                                              -- Combine qty is depend on whether the first task extra qty (qty-systemqty) is sufficient for subsequence tasks of different load/wave. Will increase task qty if insufficient.
                                              -- C=Same as Y option but only combine when extra qty (qty-systemqty) is sufficient to cover systemqty. Usually apply for combine carton per task.
                                              -- M=Combine task of same lot,from/to loc and id without checking extra qty. direct merge.
           ,@c_TaskIgnoreLot         = 'N'    -- N=Task with lot  Y=Task ignore lot  
           ,@c_TaskUOM               = ''     -- Fix UOM value for task               
           ,@b_Success               = @b_Success OUTPUT
           ,@n_Err                   = @n_Err     OUTPUT        
           ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
       IF @b_Success <> 1
       BEGIN
          SET @n_continue = 3
       END                                      
    END
         
    -----Create full case task from VNA to Pack station for B2B
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        SET @c_Message01 = 'PACKSTATION'
       SET @c_PickCondition_SQL = 'AND PICKDETAIL.UOM = ''2'' AND LOC.LocationCategory = ''VNA'' AND ISNULL(PICKDETAIL.Taskdetailkey,'''') = '''' AND ORDERS.DocType <> ''E'' AND ISNULL(ORDERS.ECOM_SINGLE_Flag,'''') <> ''S'''  --NJOW03       
       SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM AND ORDERS.DocType <> ''E'' AND ISNULL(ORDERS.ECOM_SINGLE_Flag,'''') <> ''S'' ' --NJOW03
       SET @c_ToLoc = 'MASTPACKST'
             
       EXEC isp_CreateTaskByPick
            @c_TaskType              = @c_TaskType
           ,@c_Wavekey               = @c_Wavekey  
           ,@c_ToLoc                 = @c_ToLoc       
           ,@c_ToLoc_Strategy        = ''
           ,@c_PickMethod            = @c_PickMethod   -- ?=Auto determine FP/PP by inv qty available  ?TASKQTY=(Qty available - taskqty)  ?ROUNDUP=Qty available - (qty - systemqty)
           ,@c_Priority              = @c_Priority      
           ,@c_SourcePriority        = @c_SourcePriority           
           ,@c_Message01             = @c_Message01      
           ,@c_SourceType            = @c_SourceType      
           ,@c_SourceKey             = @c_Wavekey         
           ,@c_CallSource            = 'WAVE' -- WAVE / LOADPLAN 
           ,@c_PickCondition_SQL     = @c_PickCondition_SQL   -- Additional condition to filter pickdetail. e.g. AND PICKDETAIL.UOM='2' AND LOC.LoctionType = 'OTHER'
           ,@c_LinkTaskToPick        = 'WIP'    -- N=No update taskdetailkey to pickdetail Y=Update taskdetailkey to pickdetail  WIP=Update taskdetailkey to pickdetail_wip
           ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL   -- Additional sql condition to retrieve the pickdetail like AND PICKDETAIL.UOM = @c_UOM or Order BY
           ,@c_ReserveQtyReplen      = 'N'    -- TASKQTY=Reserve all task qty for replenish at Lotxlocxid ROUNDUP=Reserve round up to full carton/pallet qty only (qty - systemqty)
           ,@c_ReservePendingMoveIn  = 'N'    -- N=No update @n_qty to @n_PendingMoveIn Y=Update @n_qty to @n_PendingMoveIn           ,@c_WIP_RefNo             = @c_SourceType     -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
           ,@c_WIP_RefNo             = @c_SourceType     -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
           ,@c_RoundUpQty            = 'N'    -- FC=Round up qty to full carton by packkey/ucc FP=Round up qty to full pallet by packkey/ucc  FL=Round up to full location qty
           ,@c_SplitTaskByCase       = 'Y'    -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.
           ,@c_ZeroSystemQty         = 'N'    -- N=@n_SystemQty will copy from @n_Qty if @n_SystemQty=0 Y=@n_SystemQty force to zero.
           ,@c_SplitTaskByOrder      = 'N'    -- N=No slip by order Y=Split TASK by Order.            
           ,@c_CombineTasks          = 'N'    -- N=No combine Y=Combine task of same lot,from/to loc and id. usually apply for replenishment task with round up full case/pallet and systemqty is the actual pickdetail.qty
                                              -- Combine qty is depend on whether the first task extra qty (qty-systemqty) is sufficient for subsequence tasks of different load/wave. Will increase task qty if insufficient.
                                              -- C=Same as Y option but only combine when extra qty (qty-systemqty) is sufficient to cover systemqty. Usually apply for combine carton per task.
                                              -- M=Combine task of same lot,from/to loc and id without checking extra qty. direct merge.
           ,@c_TaskIgnoreLot         = 'N'    -- N=Task with lot  Y=Task ignore lot  
           ,@c_TaskUOM               = ''     -- Fix UOM value for task               
           ,@b_Success               = @b_Success OUTPUT
           ,@n_Err                   = @n_Err     OUTPUT        
           ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
       IF @b_Success <> 1
       BEGIN
          SET @n_continue = 3
       END                                      
    END
    
    -----Create Replenishment from bulk to pick with full case based on pickdetail
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN            
        SET @c_Message01 = 'PICKLOC'
       SET @c_PickCondition_SQL = 'AND PICKDETAIL.UOM = ''7'' AND LOC.LocationCategory = ''VNA'' AND ISNULL(PICKDETAIL.Taskdetailkey,'''') = '''' '         
       SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = ''7'' '
       SET @c_ToLoc = 'MASTDPP'
             
       EXEC isp_CreateTaskByPick
            @c_TaskType              = @c_TaskType
           ,@c_Wavekey               = @c_Wavekey  
           ,@c_ToLoc                 = @c_ToLoc       
           ,@c_ToLoc_Strategy        = ''
           ,@c_PickMethod            = @c_PickMethod   -- ?=Auto determine FP/PP by inv qty available  ?TASKQTY=(Qty available - taskqty)  ?ROUNDUP=Qty available - (qty - systemqty)
           ,@c_Priority              = @c_Priority      
           ,@c_SourcePriority        = @c_SourcePriority           
           ,@c_Message01             = @c_Message01       
           ,@c_SourceType            = @c_SourceType      
           ,@c_SourceKey             = @c_Wavekey         
           ,@c_CallSource            = 'WAVE' -- WAVE / LOADPLAN 
           ,@c_PickCondition_SQL     = @c_PickCondition_SQL   -- Additional condition to filter pickdetail. e.g. AND PICKDETAIL.UOM='2' AND LOC.LoctionType = 'OTHER'
           ,@c_LinkTaskToPick        = 'WIP'    -- N=No update taskdetailkey to pickdetail Y=Update taskdetailkey to pickdetail  WIP=Update taskdetailkey to pickdetail_wip
           ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL   -- Additional sql condition to retrieve the pickdetail like AND PICKDETAIL.UOM = @c_UOM or Order BY
           ,@c_ReserveQtyReplen      = 'ROUNDUP'-- TASKQTY=Reserve all task qty for replenish at Lotxlocxid ROUNDUP=Reserve round up to full carton/pallet qty only (qty - systemqty)
           ,@c_ReservePendingMoveIn  = 'N'    -- N=No update @n_qty to @n_PendingMoveIn Y=Update @n_qty to @n_PendingMoveIn           ,@c_WIP_RefNo             = @c_SourceType     -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
           ,@c_WIP_RefNo             = @c_SourceType     -- referencekey for filtering pickdetail_wip table. optional and only apply for WIP
           ,@c_RoundUpQty            = 'FC'   -- FC=Round up qty to full carton by packkey/ucc FP=Round up qty to full pallet by packkey/ucc  FL=Round up to full location qty
           ,@c_SplitTaskByCase       = 'Y'    -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.
           ,@c_ZeroSystemQty         = 'N'    -- N=@n_SystemQty will copy from @n_Qty if @n_SystemQty=0 Y=@n_SystemQty force to zero.
           ,@c_SplitTaskByOrder      = 'N'    -- N=No slip by order Y=Split TASK by Order.            
           ,@c_CombineTasks          = 'C'    -- N=No combine Y=Combine task of same lot,from/to loc and id. usually apply for replenishment task with round up full case/pallet and systemqty is the actual pickdetail.qty
                                              -- Combine qty is depend on whether the first task extra qty (qty-systemqty) is sufficient for subsequence tasks of different load/wave. Will increase task qty if insufficient.
                                              -- C=Same as Y option but only combine when extra qty (qty-systemqty) is sufficient to cover systemqty. Usually apply for combine carton per task.
                                              -- M=Combine task of same lot,from/to loc and id without checking extra qty. direct merge.
           ,@c_MergedTaskPriority    = '2'    -- Set the priority of merged task based on @c_combineTasks setting.  --NJOW03                                              
           ,@c_TaskIgnoreLot         = 'N'    -- N=Task with lot  Y=Task ignore lot  
           ,@c_TaskUOM               = '2'     -- Fix UOM value for task               
           ,@b_Success               = @b_Success OUTPUT
           ,@n_Err                   = @n_Err     OUTPUT        
           ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
       IF @b_Success <> 1
       BEGIN
          SET @n_continue = 3
       END                                      
    END
    
    --Generate NON-BEAUTY batch number and update to pickdetail for B2B only
    IF (@n_continue = 1 or @n_continue = 2) AND @c_DocType <> 'E'  --NJOW01
    BEGIN
       --Cleare caseid, pickslipno and notes
       UPDATE #PickDetail_WIP
       SET Caseid = '',
           Pickslipno = '',
           Notes = ''
                   
       DECLARE CUR_CODELKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT TOP 10 Long   
          FROM CODELKUP WITH (NOLOCK)  
          WHERE ListName = 'MASTGROUP'  
          AND Short = @c_Userdefine01   
          AND Storerkey = @c_Storerkey
          ORDER BY CASE WHEN Long = 'LOC.FLOOR' THEN 1 ELSE 2 END, --NJOW05
                   Code  
         
       OPEN CUR_CODELKUP  
         
       FETCH NEXT FROM CUR_CODELKUP INTO @c_TableColumnName  
         
       SELECT @c_SQLField = '', @c_SQLWhere = '', @c_SQLGroup = '', @n_cnt = 0, @c_CheckFloor = 'N' 
       WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
       BEGIN  
       	  IF @c_TableColumnName = 'LOC.FLOOR'  --NJOW05
       	     SET @c_CheckFloor = 'Y'
       	     
          SET @n_cnt = @n_cnt + 1   
          SET @c_TableName = LEFT(@c_TableColumnName, CharIndex('.', @c_TableColumnName) - 1)  
          SET @c_ColumnName = SUBSTRING(@c_TableColumnName,   
                              CharIndex('.', @c_TableColumnName) + 1, LEN(@c_TableColumnName) - CharIndex('.', @c_TableColumnName))  
       
          IF ISNULL(RTRIM(@c_TableName), '') NOT IN ('SKU','LOC')  --NJOW05
          BEGIN  
             SELECT @n_continue = 3  
             SELECT @n_err = 83150  
             SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Grouping Only Allow Refer To SKU/LOC Table's Fields. Invalid Table: "+RTRIM(@c_TableColumnName)+" (ispRLWAV24)"  
             GOTO RETURN_SP                      
          END   
         
          SET @c_ColumnType = ''  
          SELECT @c_ColumnType = DATA_TYPE   
          FROM   INFORMATION_SCHEMA.COLUMNS   
          WHERE  TABLE_NAME = @c_TableName  
          AND    COLUMN_NAME = @c_ColumnName  
         
          IF ISNULL(RTRIM(@c_ColumnType), '') = ''   
          BEGIN  
             SELECT @n_continue = 3  
             SELECT @n_err = 83160  
             SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Invalid Column Name: " + RTRIM(@c_TableColumnName)+ ". (ispRLWAV24)"  
             GOTO RETURN_SP                      
          END   
            
          IF @c_ColumnType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint','text')  
          BEGIN  
             SELECT @n_continue = 3  
             SELECT @n_err = 83170  
             SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Numeric/Text Column Type Is Not Allowed For  Grouping: " + RTRIM(@c_TableColumnName)+ ". (ispRLWAV24)"  
             GOTO RETURN_SP                      
          END   
         
          IF @c_ColumnType IN ('char', 'nvarchar', 'varchar','nchar')
          BEGIN  
             SELECT @c_SQLField = @c_SQLField + ',' + RTRIM(@c_TableColumnName)  
             SELECT @c_SQLWhere = @c_SQLWhere + ' AND ' + RTRIM(@c_TableColumnName) + '=' +   
                    CASE WHEN @n_cnt = 1 THEN '@c_Field01'  
                         WHEN @n_cnt = 2 THEN '@c_Field02'  
                         WHEN @n_cnt = 3 THEN '@c_Field03'  
                         WHEN @n_cnt = 4 THEN '@c_Field04'  
                         WHEN @n_cnt = 5 THEN '@c_Field05'  
                         WHEN @n_cnt = 6 THEN '@c_Field06'  
                         WHEN @n_cnt = 7 THEN '@c_Field07'  
                         WHEN @n_cnt = 8 THEN '@c_Field08'  
                         WHEN @n_cnt = 9 THEN '@c_Field09'  
                         WHEN @n_cnt = 10 THEN '@c_Field10' END  
          END           
       
          IF @c_ColumnType IN ('datetime')    
          BEGIN  
             SELECT @c_SQLField = @c_SQLField + ', CONVERT(NVARCHAR(10),' + RTRIM(@c_TableColumnName) + ',112)'  
             SELECT @c_SQLWhere = @c_SQLWhere + ' AND CONVERT(NVARCHAR(10),' + RTRIM(@c_TableColumnName) + ',112)=' +   
                    CASE WHEN @n_cnt = 1 THEN '@c_Field01'  
                         WHEN @n_cnt = 2 THEN '@c_Field02'  
                         WHEN @n_cnt = 3 THEN '@c_Field03'  
                         WHEN @n_cnt = 4 THEN '@c_Field04'  
                         WHEN @n_cnt = 5 THEN '@c_Field05'  
                         WHEN @n_cnt = 6 THEN '@c_Field06'  
                         WHEN @n_cnt = 7 THEN '@c_Field07'  
                         WHEN @n_cnt = 8 THEN '@c_Field08'  
                         WHEN @n_cnt = 9 THEN '@c_Field09'  
                         WHEN @n_cnt = 10 THEN '@c_Field10' END  
          END  
                                        
          FETCH NEXT FROM CUR_CODELKUP INTO  @c_TableColumnName  
       END   
       CLOSE CUR_CODELKUP  
       DEALLOCATE CUR_CODELKUP   
                
       SELECT @c_SQLGroup = @c_SQLField  
       WHILE @n_cnt < 10  
       BEGIN  
          SET @n_cnt = @n_cnt + 1  
           SELECT @c_SQLField = @c_SQLField + ','''''        
       
          SELECT @c_SQLWhere = @c_SQLWhere + ' AND ''''=' +   
                 CASE WHEN @n_cnt = 1 THEN 'ISNULL(@c_Field01,'''')'  
                      WHEN @n_cnt = 2 THEN 'ISNULL(@c_Field02,'''')'  
                      WHEN @n_cnt = 3 THEN 'ISNULL(@c_Field03,'''')'  
                      WHEN @n_cnt = 4 THEN 'ISNULL(@c_Field04,'''')'  
                      WHEN @n_cnt = 5 THEN 'ISNULL(@c_Field05,'''')'  
                      WHEN @n_cnt = 6 THEN 'ISNULL(@c_Field06,'''')'  
                      WHEN @n_cnt = 7 THEN 'ISNULL(@c_Field07,'''')'  
                      WHEN @n_cnt = 8 THEN 'ISNULL(@c_Field08,'''')'  
                      WHEN @n_cnt = 9 THEN 'ISNULL(@c_Field09,'''')'  
                      WHEN @n_cnt = 10 THEN 'ISNULL(@c_Field10,'''')' END          
       END         
       
       SELECT @c_SQLDYN01 = 'DECLARE cur_Group CURSOR FAST_FORWARD READ_ONLY FOR '  
          + ' SELECT ORDERS.Loadkey ' + @c_SQLField   
          + ' FROM #PickDetail_WIP PICKDETAIL '  
          + ' JOIN ORDERS (NOLOCK) ON PICKDETAIL.Orderkey = ORDERS.Orderkey '
          + ' JOIN SKU WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku) '  
          + ' JOIN LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc) '  --NJOW05
          + ' WHERE SKU.Busr9 <> ''BEAUTY'' '
          + ' AND PICKDETAIL.UOM <> ''2'' '
          + ' GROUP BY ORDERS.Loadkey ' + @c_SQLGroup  
          + ' ORDER BY ORDERS.Loadkey ' + @c_SQLGroup  
                   
       EXEC (@c_SQLDYN01)  
       
       OPEN cur_Group  
       
       FETCH NEXT FROM cur_Group INTO @c_Loadkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,   
                                      @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
      
       SET @n_NoofTotePerBatch = CAST(@c_Userdefine02 AS INT)
       SET @n_cnt = 1
       SET @c_BatchNo = ''
       SET @c_PrevLoadkey = ''
       SET @c_PrevFloor = ''      

       WHILE @@FETCH_STATUS = 0  AND @n_continue IN(1,2)    
       BEGIN
       	   IF @c_CheckFloor = 'Y'  --NJOW05
       	      SET @c_Floor = @c_Field01
       	   
           IF @n_cnt > @n_NoofTotePerBatch OR @c_PrevLoadkey <> @c_Loadkey 
              OR (@c_PrevFloor <> @c_Floor AND @c_CheckFloor = 'Y')  --NJOW05
              SET @n_cnt = 1
           
           IF @n_cnt = 1
           BEGIN
             SELECT @b_success = 0  
             EXECUTE nspg_GetKey  
                'RLWAV24',  
                9,  
                @C_BatchNo     OUTPUT,  
                @b_success     OUTPUT,  
                @n_err         OUTPUT,  
                @c_errmsg      OUTPUT  
               
             IF @b_success <> 1  
             BEGIN  
                SELECT @n_continue = 3  
             END              
           END   
  
          SELECT @c_SQLDYN02 = 'DECLARE cur_pickbatch CURSOR FAST_FORWARD READ_ONLY FOR '  
          + ' SELECT PICKDETAIL.Pickdetailkey '  
          + ' FROM #PickDetail_WIP PICKDETAIL '  
          + ' JOIN SKU WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku) '  
          + ' JOIN LOADPLANDETAIL WITH (NOLOCK) ON (PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey) '  
          + ' JOIN LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc) '  --NJOW05
          + ' WHERE SKU.Busr9 <> ''BEAUTY'' '
          + ' AND LOADPLANDETAIL.Loadkey = @c_LoadKey '  
          + ' AND PICKDETAIL.UOM <> ''2'' '          
          + @c_SQLWhere  
          + ' ORDER BY PICKDETAIL.Pickdetailkey '  
          
          EXEC sp_executesql @c_SQLDYN02,   
               N'@c_Loadkey NVARCHAR(10), @c_Field01 NVARCHAR(60), @c_Field02 NVARCHAR(60),@c_Field03 NVARCHAR(60),@c_Field04 NVARCHAR(60),  
                 @c_Field05 NVARCHAR(60), @c_Field06 NVARCHAR(60), @c_Field07 NVARCHAR(60), @c_Field08 NVARCHAR(60), @c_Field09 NVARCHAR(60), @c_Field10 NVARCHAR(60)',   
               @c_Loadkey,  
               @c_Field01,   
               @c_Field02,   
               @c_Field03,   
               @c_Field04,   
               @c_Field05,   
               @c_Field06,   
               @c_Field07,   
               @c_Field08,   
               @c_Field09,   
               @c_Field10   
          
           OPEN cur_pickbatch  
                                   
           FETCH NEXT FROM cur_pickbatch INTO @c_Pickdetailkey 
           WHILE @@FETCH_STATUS = 0  
           BEGIN          
              UPDATE #PickDetail_WIP
              SET Pickslipno = 'M' + @c_BatchNo,
                  Notes = 'M' + RTRIM(@c_BatchNo) + '-' + RIGHT('00'+CAST(@n_cnt AS NVARCHAR),2),
                  CaseID = RIGHT('00'+CAST(@n_cnt AS NVARCHAR),2)                   
              WHERE Pickdetailkey = @c_Pickdetailkey    
                  
              FETCH NEXT FROM cur_pickbatch INTO @c_Pickdetailkey 
           END                
           CLOSE cur_pickbatch
           DEALLOCATE cur_pickbatch                         
          
           SET @n_cnt = @n_cnt + 1
           SET @c_PrevLoadkey = @c_Loadkey 
           
           IF @c_CheckFloor = 'Y'  --NJOW05
       	      SET @c_PrevFloor = @c_Floor
       	              
           FETCH NEXT FROM cur_Group INTO @c_Loadkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,   
                                         @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10            
       END
       CLOSE cur_Group
       DEALLOCATE cur_Group
    END

    --Generate BEAUTY batch number and update to pickdetail for B2B only
    IF (@n_continue = 1 or @n_continue = 2) AND @c_DocType <> 'E' --NJOW01
    BEGIN
       DECLARE CUR_CODELKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
          SELECT TOP 10 Long   
          FROM CODELKUP WITH (NOLOCK)  
          WHERE ListName = 'MASTGROUP'  
          AND Short = '3'   
          AND Storerkey = @c_Storerkey
          ORDER BY CASE WHEN Long = 'LOC.FLOOR' THEN 1 ELSE 2 END, --NJOW05
                   Code  
         
       OPEN CUR_CODELKUP  
         
       FETCH NEXT FROM CUR_CODELKUP INTO @c_TableColumnName  
         
       SELECT @c_SQLField = '', @c_SQLWhere = '', @c_SQLGroup = '', @n_cnt = 0, @c_CheckFloor = 'N' 
       WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
       BEGIN  
       	  IF @c_TableColumnName = 'LOC.FLOOR'  --NJOW05
       	     SET @c_CheckFloor = 'Y'
       	
          SET @n_cnt = @n_cnt + 1   
          SET @c_TableName = LEFT(@c_TableColumnName, CharIndex('.', @c_TableColumnName) - 1)  
          SET @c_ColumnName = SUBSTRING(@c_TableColumnName,   
                              CharIndex('.', @c_TableColumnName) + 1, LEN(@c_TableColumnName) - CharIndex('.', @c_TableColumnName))  
       
          IF ISNULL(RTRIM(@c_TableName), '') NOT IN('SKU','LOC')  --NJOW05
          BEGIN  
             SELECT @n_continue = 3  
             SELECT @n_err = 83180  
             SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Grouping Only Allow Refer To SKU/LOC Table's Fields. Invalid Table: "+RTRIM(@c_TableColumnName)+" (ispRLWAV24)"  
             GOTO RETURN_SP                      
          END   
         
          SET @c_ColumnType = ''  
          SELECT @c_ColumnType = DATA_TYPE   
          FROM   INFORMATION_SCHEMA.COLUMNS   
          WHERE  TABLE_NAME = @c_TableName  
          AND    COLUMN_NAME = @c_ColumnName  
         
          IF ISNULL(RTRIM(@c_ColumnType), '') = ''   
          BEGIN  
             SELECT @n_continue = 3  
             SELECT @n_err = 83190  
             SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Invalid Column Name: " + RTRIM(@c_TableColumnName)+ ". (ispRLWAV24)"  
             GOTO RETURN_SP                      
          END   
            
          IF @c_ColumnType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint','text')  
          BEGIN  
             SELECT @n_continue = 3  
             SELECT @n_err = 83200  
             SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Numeric/Text Column Type Is Not Allowed For  Grouping: " + RTRIM(@c_TableColumnName)+ ". (ispRLWAV24)"  
             GOTO RETURN_SP                      
          END   
         
          IF @c_ColumnType IN ('char', 'nvarchar', 'varchar','nchar')
          BEGIN  
             SELECT @c_SQLField = @c_SQLField + ',' + RTRIM(@c_TableColumnName)  
             SELECT @c_SQLWhere = @c_SQLWhere + ' AND ' + RTRIM(@c_TableColumnName) + '=' +   
                    CASE WHEN @n_cnt = 1 THEN '@c_Field01'  
                         WHEN @n_cnt = 2 THEN '@c_Field02'  
                         WHEN @n_cnt = 3 THEN '@c_Field03'  
                         WHEN @n_cnt = 4 THEN '@c_Field04'  
                         WHEN @n_cnt = 5 THEN '@c_Field05'  
                         WHEN @n_cnt = 6 THEN '@c_Field06'  
                         WHEN @n_cnt = 7 THEN '@c_Field07'  
                         WHEN @n_cnt = 8 THEN '@c_Field08'  
                         WHEN @n_cnt = 9 THEN '@c_Field09'  
                         WHEN @n_cnt = 10 THEN '@c_Field10' END  
          END           
       
          IF @c_ColumnType IN ('datetime')    
          BEGIN  
             SELECT @c_SQLField = @c_SQLField + ', CONVERT(NVARCHAR(10),' + RTRIM(@c_TableColumnName) + ',112)'  
             SELECT @c_SQLWhere = @c_SQLWhere + ' AND CONVERT(NVARCHAR(10),' + RTRIM(@c_TableColumnName) + ',112)=' +   
                    CASE WHEN @n_cnt = 1 THEN '@c_Field01'  
                         WHEN @n_cnt = 2 THEN '@c_Field02'  
                         WHEN @n_cnt = 3 THEN '@c_Field03'  
                         WHEN @n_cnt = 4 THEN '@c_Field04'  
                         WHEN @n_cnt = 5 THEN '@c_Field05'  
                         WHEN @n_cnt = 6 THEN '@c_Field06'  
                         WHEN @n_cnt = 7 THEN '@c_Field07'  
                         WHEN @n_cnt = 8 THEN '@c_Field08'  
                         WHEN @n_cnt = 9 THEN '@c_Field09'  
                         WHEN @n_cnt = 10 THEN '@c_Field10' END  
          END  
                                        
          FETCH NEXT FROM CUR_CODELKUP INTO  @c_TableColumnName  
       END   
       CLOSE CUR_CODELKUP  
       DEALLOCATE CUR_CODELKUP   
                
       SELECT @c_SQLGroup = @c_SQLField  
       WHILE @n_cnt < 10  
       BEGIN  
          SET @n_cnt = @n_cnt + 1  
           SELECT @c_SQLField = @c_SQLField + ','''''        
       
          SELECT @c_SQLWhere = @c_SQLWhere + ' AND ''''=' +   
                 CASE WHEN @n_cnt = 1 THEN 'ISNULL(@c_Field01,'''')'  
                      WHEN @n_cnt = 2 THEN 'ISNULL(@c_Field02,'''')'  
                      WHEN @n_cnt = 3 THEN 'ISNULL(@c_Field03,'''')'  
                      WHEN @n_cnt = 4 THEN 'ISNULL(@c_Field04,'''')'  
                      WHEN @n_cnt = 5 THEN 'ISNULL(@c_Field05,'''')'  
                      WHEN @n_cnt = 6 THEN 'ISNULL(@c_Field06,'''')'  
                      WHEN @n_cnt = 7 THEN 'ISNULL(@c_Field07,'''')'  
                      WHEN @n_cnt = 8 THEN 'ISNULL(@c_Field08,'''')'  
                      WHEN @n_cnt = 9 THEN 'ISNULL(@c_Field09,'''')'  
                      WHEN @n_cnt = 10 THEN 'ISNULL(@c_Field10,'''')' END          
       END         
       
       SELECT @c_SQLDYN01 = 'DECLARE cur_Group CURSOR FAST_FORWARD READ_ONLY FOR '  
          + ' SELECT ORDERS.Loadkey ' + @c_SQLField   
          + ' FROM #PickDetail_WIP PICKDETAIL '  
          + ' JOIN ORDERS (NOLOCK) ON PICKDETAIL.Orderkey = ORDERS.Orderkey '
          + ' JOIN SKU WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku) '  
          + ' JOIN LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc) '  --NJOW05
          + ' WHERE SKU.Busr9 = ''BEAUTY'' '
          + ' AND PICKDETAIL.UOM <> ''2'' '
          + ' GROUP BY ORDERS.Loadkey ' + @c_SQLGroup  
          + ' ORDER BY ORDERS.Loadkey ' + @c_SQLGroup  
         
       EXEC (@c_SQLDYN01)  
       
       OPEN cur_Group  
       
       FETCH NEXT FROM cur_Group INTO @c_Loadkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,   
                                      @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
      
       SET @n_NoofTotePerBatch = CAST(@c_Userdefine02 AS INT)
       SET @n_cnt = 1
       SET @c_BatchNo = ''
       SET @c_PrevLoadkey = ''
       SET @c_PrevFloor = ''      
              
       WHILE @@FETCH_STATUS = 0  AND @n_continue IN(1,2)    
       BEGIN
       	   IF @c_CheckFloor = 'Y'  --NJOW05
       	      SET @c_Floor = @c_Field01

           IF @n_cnt > @n_NoofTotePerBatch OR @c_PrevLoadkey <> @c_Loadkey 
              OR (@c_PrevFloor <> @c_Floor AND @c_CheckFloor = 'Y')  --NJOW05           
              SET @n_cnt = 1
           
           IF @n_cnt = 1
           BEGIN
             SELECT @b_success = 0  
             EXECUTE nspg_GetKey  
                'RLWAV24',  
                9,  
                @C_BatchNo     OUTPUT,  
                @b_success     OUTPUT,  
                @n_err         OUTPUT,  
                @c_errmsg      OUTPUT  
               
             IF @b_success <> 1  
             BEGIN  
                SELECT @n_continue = 3  
             END              
           END   
  
          SELECT @c_SQLDYN02 = 'DECLARE cur_pickbatch CURSOR FAST_FORWARD READ_ONLY FOR '  
          + ' SELECT PICKDETAIL.Pickdetailkey '  
          + ' FROM #PickDetail_WIP PICKDETAIL '  
          + ' JOIN SKU WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku) '  
          + ' JOIN LOADPLANDETAIL WITH (NOLOCK) ON (PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey) '  
          + ' JOIN LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc) ' --NJOW05           
          + ' WHERE SKU.Busr9 = ''BEAUTY'' '
          + ' AND LOADPLANDETAIL.Loadkey = @c_LoadKey '  
          + ' AND PICKDETAIL.UOM <> ''2'' '
          + @c_SQLWhere  
          + ' ORDER BY PICKDETAIL.Pickdetailkey '  
          
          EXEC sp_executesql @c_SQLDYN02,   
               N'@c_Loadkey NVARCHAR(10), @c_Field01 NVARCHAR(60), @c_Field02 NVARCHAR(60),@c_Field03 NVARCHAR(60),@c_Field04 NVARCHAR(60),  
                 @c_Field05 NVARCHAR(60), @c_Field06 NVARCHAR(60), @c_Field07 NVARCHAR(60), @c_Field08 NVARCHAR(60), @c_Field09 NVARCHAR(60), @c_Field10 NVARCHAR(60)',   
               @c_Loadkey,  
               @c_Field01,   
               @c_Field02,   
               @c_Field03,   
               @c_Field04,   
               @c_Field05,   
               @c_Field06,   
               @c_Field07,   
               @c_Field08,   
               @c_Field09,   
               @c_Field10   
          
           OPEN cur_pickbatch  
          
           FETCH NEXT FROM cur_pickbatch INTO @c_Pickdetailkey 
           WHILE @@FETCH_STATUS = 0  
           BEGIN          
              UPDATE #PickDetail_WIP
              SET Pickslipno = 'M' + @c_BatchNo,
                  Notes = 'M' + RTRIM(@c_BatchNo) + '-' + RIGHT('00'+CAST(@n_cnt AS NVARCHAR),2),
                  CaseID = RIGHT('00'+CAST(@n_cnt AS NVARCHAR),2)
              WHERE Pickdetailkey = @c_Pickdetailkey
                  
              FETCH NEXT FROM cur_pickbatch INTO @c_Pickdetailkey 
           END                
           CLOSE cur_pickbatch
           DEALLOCATE cur_pickbatch                         
          
           SET @n_cnt = @n_cnt + 1
           SET @c_PrevLoadkey = @c_Loadkey 

           IF @c_CheckFloor = 'Y'  --NJOW05
       	      SET @c_PrevFloor = @c_Floor
           
           FETCH NEXT FROM cur_Group INTO @c_Loadkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,   
                                         @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10            
       END
       CLOSE cur_Group
       DEALLOCATE cur_Group
    END
                                 
    -----Update pickdetail_WIP work in progress staging table back to pickdetail 
    IF @n_continue = 1 or @n_continue = 2
    BEGIN
       EXEC isp_CreatePickdetail_WIP
             @c_Loadkey               = ''
            ,@c_Wavekey               = @c_wavekey  
            ,@c_WIP_RefNo             = @c_SourceType 
            ,@c_PickCondition_SQL     = ''
            ,@c_Action                = 'U'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
            ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
            ,@b_Success               = @b_Success OUTPUT
            ,@n_Err                   = @n_Err     OUTPUT 
            ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
       IF @b_Success <> 1
       BEGIN
          SET @n_continue = 3
       END             
    END    
                    
    -----Generate Pickslip No------    
    IF @n_continue = 1 or @n_continue = 2 
    BEGIN
       IF @c_DocType <> 'E'  
       BEGIN    
          EXEC isp_CreatePickSlip
               @c_Wavekey = @c_Wavekey
              ,@c_LinkPickSlipToPick = 'N'  --Y=Update pickslipno to pickdetail.pickslipno 
              ,@c_ConsolidateByLoad = 'Y'
              ,@c_PickslipType = '7'  --change to same as pickslip report to avoid duplicate
              ,@b_Success = @b_Success OUTPUT
              ,@n_Err = @n_err OUTPUT 
              ,@c_ErrMsg = @c_errmsg OUTPUT        
          
          IF @b_Success = 0
             SELECT @n_continue = 3
       END       
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
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83150   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV24)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
       END  
    END  
   
RETURN_SP:

    -----Delete pickdetail_WIP work in progress staging table
    IF @n_continue IN (1,2)
    BEGIN
       EXEC isp_CreatePickdetail_WIP
             @c_Loadkey               = ''
            ,@c_Wavekey               = @c_wavekey  
            ,@c_WIP_RefNo             = @c_SourceType 
            ,@c_PickCondition_SQL     = ''
            ,@c_Action                = 'D'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
            ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
            ,@b_Success               = @b_Success OUTPUT
            ,@n_Err                   = @n_Err     OUTPUT 
            ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
       IF @b_Success <> 1
       BEGIN
          SET @n_continue = 3
       END             
    END
    
    IF OBJECT_ID('tempdb..#PICKDETAIL_WIP') IS NOT NULL
       DROP TABLE #PICKDETAIL_WIP

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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV24"  
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