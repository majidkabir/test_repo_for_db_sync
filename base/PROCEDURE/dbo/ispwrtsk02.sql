SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/**************************************************************************/  
/* Stored Procedure: ispWRTSK02                                           */  
/* Creation Date: 10-Jun-2014                                             */  
/* Copyright: LF                                                          */  
/* Written by:                                                            */  
/*                                                                        */  
/* Purpose: SOS#313157 - TW - (Echo) Wave Plan Task Release               */  
/*                                                                        */ 
/* Input Parameters:  @c_Wavekey  - (Wave #)                              */
/*                                                                        */
/* Output Parameters:  None                                               */
/*                                                                        */
/* Return Status:  None                                                   */
/*                                                                        */
/* Usage:                                                                 */
/*                                                                        */
/* Called By:                                                             */  
/*                                                                        */  
/* PVCS Version: 1.0                                                      */  
/*                                                                        */  
/*                                                                        */  
/* Data Modifications:                                                    */  
/*                                                                        */  
/* Updates:                                                               */  
/* Date         Author   Ver  Purposes                                    */  
/* 04/09/2014   NJOW01   1.0  313157-Map priority to orders.priority      */
/*                            Fix grouping multi order line per sku issue */
/* 18-DEC-2014  YTWan    1.1  SOS#328693 - TW - Wave Plane Task Release   */
/*                            Adding GroupKey (Wan01)                     */
/* 31-OCT-2016  Shong    1.2  WMS-249 - Replenishment enhancements        */
/* 09-NOV-2016  Wan02    1.3  Fixed Replen from Loc not filter by facility*/
/**************************************************************************/  
CREATE PROC [dbo].[ispWRTSK02] 
   @c_WaveKey  NVARCHAR(10),
   @b_Success  INT OUTPUT, 
   @n_err      INT OUTPUT, 
   @c_errmsg   NVARCHAR(250) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON       -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @n_continue        INT,
           @n_StartTranCnt    INT

   DECLARE @c_CurrentSKU      NVARCHAR(20),
           @c_FromLoc         NVARCHAR(10),
           @c_ToLOC           NVARCHAR(10),               
           @c_Fromid          NVARCHAR(18),
           @c_TaskDetailKey   NVARCHAR(10),
           @c_AreaKey         NVARCHAR(10),
           @c_LoadKey         NVARCHAR(10), 
           @c_LogicalFromLoc  NVARCHAR(10),  
           @c_Storerkey       NVARCHAR(15),
           @c_PickMethod      NVARCHAR(10), 
           @c_Userdefine01    NVARCHAR(18),      
           @c_Priority        NVARCHAR(10),
           @c_UOM             NVARCHAR(10),
           @n_UOMQty          INT,
           @c_TaskType        NVARCHAR(10),
           @c_TaskType2       NVARCHAR(10),
           @c_Susr4           NVARCHAR(20),
           @c_OrderKey        NVARCHAR(10),
           @c_Lottable02      NVARCHAR(18),
           @d_Lottable04      DATETIME,
           @n_PickQty         INT,
           @c_PickDetailKey   NVARCHAR(10),
           @c_Door            NVARCHAR(10),
           @c_OVAS            NVARCHAR(30),
           @n_Pallet          INT,
           @n_Casecnt         INT,
           @c_TSUOM           NVARCHAR(10),
           @n_TSUOMQty        INT, 
           @b_Debug           INT 
         
         , @n_rowcount        INT                  --(Wan01)
         , @n_nooftasks       INT                  --(Wan01)
         , @c_Sourcekey       NVARCHAR(30)         --(Wan01)
         , @c_TaskGroupKey    NVARCHAR(10)         --(Wan01)
          
   SET @n_StartTranCnt  =  @@TRANCOUNT
   SET @n_continue      = 1
   
   IF @c_errmsg = 'DEBUG'
   BEGIN 
      SET @b_Debug = 1
      SET @c_errmsg = '' 
   END
      
   
   DELETE [WaveRelErrorReport] WHERE WaveKey = @c_WaveKey  
      
   IF EXISTS(SELECT 1
                 FROM   WAVEDETAIL w WITH (NOLOCK)
                 JOIN   ORDERS O WITH (NOLOCK) ON O.OrderKey = w.OrderKey 
                 LEFT OUTER JOIN  LOC WITH (NOLOCK) ON O.Door = LOC.Loc 
                 WHERE  w.WaveKey = @c_WaveKey
                 AND    LOC.LOC IS NULL)  
   BEGIN  
      SELECT TOP 1 @c_errmsg = 'ORDER DOOR NOT A Valid Location: ' + O.Door + '. OrderKey = ' + RTRIM(O.OrderKey) 
                  FROM   WAVEDETAIL w WITH (NOLOCK)
                     JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = w.OrderKey 
                     LEFT OUTER JOIN LOC WITH (NOLOCK) ON O.Door = LOC.Loc 
                  WHERE  w.WaveKey = @c_WaveKey 
                  AND    LOC.LOC IS NULL 
                     
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '-----------------------------------')         
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '  Orders Door Not A Valid Location')      
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '-----------------------------------')
            
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, CONVERT(CHAR(10), 'OrderKey') + SPACE(5) + CONVERT(CHAR(10), 'DOOR') )        
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, REPLICATE('-', 10) + SPACE(5) + REPLICATE('-', 10) )
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) 
      SELECT W.WaveKey,
             CONVERT(NCHAR(10), O.OrderKey) + SPACE(5) + CONVERT(NCHAR(10), O.Door)
      FROM   WAVEDETAIL w WITH (NOLOCK)
      JOIN   ORDERS O WITH (NOLOCK) ON O.OrderKey = w.OrderKey 
      LEFT OUTER JOIN LOC WITH (NOLOCK) ON O.Door = LOC.Loc 
      WHERE  w.WaveKey = @c_WaveKey                              
   END   

   IF EXISTS(SELECT 1 FROM WaveRelErrorReport WITH (NOLOCK) WHERE WaveKey = @c_WaveKey)
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_ErrMsg = CONVERT(CHAR(250) ,@n_err)
            ,@n_err = 81001 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
             ': Found Invalid Data, Please print the Wave Release Error Log (ispWRTSK02)'
      GOTO RETURN_SP
   END             

   SELECT @c_userdefine01 = Userdefine01 -- C=Consolidate
   FROM WAVE (NOLOCK)
   WHERE Wavekey = @c_Wavekey
   
 
   /****************************************************************
   *  Begin of Pick task 
   ****************************************************************/

    IF @c_Userdefine01 = 'C'
    BEGIN
    DECLARE C_PickTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT '' AS Orderkey, p.StorerKey, p.SKU, p.LOC, p.ID, SUM(p.Qty),  
              LEFT(ISNULL(LA.Lottable02,''),4) AS Lottable02,  LA.Lottable04, ISNULL(Loc.LogicalLocation,''),
              MIN(o.Priority) AS Priority, MIN(o.Door) AS Door, p.UOM, MIN(p.UOMQty), 
              ISNULL(ad.Areakey,'') as Areakey, MIN(o.Loadkey) AS Loadkey, MIN(ISNULL(cn.Susr4,'')) AS Susr4,
              MAX(CASE WHEN ISNULL(CL.Code,'') <> '' THEN
                   SKU.OVAS ELSE '' END) AS OVAS, PACK.Pallet, PACK.Casecnt               
       FROM WAVEDETAIL w WITH (NOLOCK)
       JOIN ORDERS o WITH (NOLOCK) ON w.Orderkey = o.Orderkey
       JOIN PICKDETAIL p WITH (NOLOCK) ON o.OrderKey = p.OrderKey
       JOIN SKU WITH (NOLOCK) ON p.Storerkey = SKU.Storerkey AND p.Sku = SKU.Sku
       JOIN PACK WITH (NOLOCK) ON SKU.Packkey = PACK.Packkey
       JOIN LOC WITH (NOLOCK) ON LOC.Loc = p.loc   
       JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LA.Lot = P.Lot   
       LEFT JOIN AREADETAIL ad WITH (NOLOCK) ON LOC.PutawayZone = ad.PutawayZone
       LEFT JOIN STORER cn WITH (NOLOCK) ON o.Consigneekey = cn.Storerkey AND cn.Consigneefor = 'PNG'
       LEFT JOIN CODELKUP CL (NOLOCK) ON (p.Storerkey = CL.Storerkey AND CL.UDF01='OVAS' AND CL.Listname='SECONDARY' AND cn.Secondary = CL.Code)
       WHERE W.WaveKey = @c_WaveKey  
       AND  p.Status = '0' 
       AND ( p.TaskDetailKey IS NULL OR p.TaskDetailKey = '' )  
       GROUP BY p.StorerKey, p.SKU, p.LOC, p.ID, LEFT(ISNULL(LA.Lottable02,''),4),
             LA.Lottable04, Loc.LogicalLocation, p.UOM, ad.Areakey, PACK.Pallet, PACK.Casecnt
       ORDER BY MIN(o.priority), p.Sku,  
                MAX(CASE WHEN ISNULL(CL.Code,'') <> '' THEN SKU.OVAS ELSE '' END),
                ISNULL(Loc.LogicalLocation,''), P.Loc END
    ELSE
    BEGIN
    DECLARE C_PickTask CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT p.OrderKey, p.StorerKey, p.SKU, p.LOC, p.ID, SUM(p.Qty),  
              LEFT(ISNULL(LA.Lottable02,''),4) AS Lottable02,  LA.Lottable04, ISNULL(Loc.LogicalLocation,''),
              o.Priority, o.Door, p.UOM, SUM(p.UOMQty) AS UOMQty, ISNULL(ad.Areakey,'') AS Areakey, o.Loadkey, ISNULL(cn.Susr4,'') AS Susr4,
              CASE WHEN ISNULL(CL.Code,'') <> '' THEN
                   ISNULL(SKU.OVAS,'') ELSE '' END AS OVAS, PACK.Pallet, PACK.Casecnt  
       FROM WAVEDETAIL w WITH (NOLOCK)
       JOIN ORDERS o WITH (NOLOCK) ON w.Orderkey = o.Orderkey
       JOIN PICKDETAIL p WITH (NOLOCK) ON o.OrderKey = p.OrderKey
       JOIN SKU WITH (NOLOCK) ON p.Storerkey = SKU.Storerkey AND p.Sku = SKU.Sku
       JOIN PACK WITH (NOLOCK) ON SKU.Packkey = PACK.Packkey
       JOIN LOC WITH (NOLOCK) ON LOC.Loc = p.loc   
       JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LA.Lot = P.Lot   
       LEFT JOIN AREADETAIL ad WITH (NOLOCK) ON LOC.PutawayZone = ad.PutawayZone
       LEFT JOIN STORER cn WITH (NOLOCK) ON o.Consigneekey = cn.Storerkey AND cn.Consigneefor = 'PNG'
       LEFT JOIN CODELKUP CL (NOLOCK) ON (p.Storerkey = CL.Storerkey AND CL.UDF01='OVAS' AND CL.Listname='SECONDARY' AND cn.Secondary = CL.Code)
       WHERE W.WaveKey = @c_WaveKey  
       AND  p.Status = '0' 
       AND ( p.TaskDetailKey IS NULL OR p.TaskDetailKey = '' )  
       GROUP BY p.OrderKey, p.StorerKey, p.SKU, p.LOC, p.ID, LEFT(ISNULL(LA.Lottable02,''),4),
             LA.Lottable04, Loc.LogicalLocation, o.Priority, o.Door, p.UOM, --p.UOMQty, --NJOW01
             ISNULL(ad.Areakey,''), o.Loadkey, ISNULL(cn.Susr4,''), ISNULL(SKU.OVAS,''), ISNULL(CL.Code,''),
             PACK.Pallet, PACK.Casecnt
       ORDER BY o.Priority, p.Orderkey, p.SKU, 
                CASE WHEN ISNULL(CL.Code,'') <> '' THEN ISNULL(SKU.OVAS,'') ELSE '' END,
                ISNULL(Loc.LogicalLocation,''), p.Loc
    END

    OPEN C_PickTask

    FETCH NEXT FROM C_PickTask INTO @c_OrderKey, @c_StorerKey, @c_CurrentSKU, @c_FromLoc, 
                  @c_FromID, @n_PickQty, @c_Lottable02, @d_Lottable04, @c_LogicalFromLoc, @c_Priority, 
                  @c_Door, @c_UOM, @n_UOMQty, @c_Areakey, @c_Loadkey, @c_Susr4, @c_OVAS, @n_Pallet, @n_Casecnt
                  
    WHILE (@@FETCH_STATUS<>-1)
    BEGIN
       SET @c_ToLoc = ISNULL(@c_Door,'')
       SET @c_TSUom = '6'
       SET @n_TSUOMQty = @n_PickQty
       SET @c_PickMethod = 'PP'
       SET @c_TaskType = 'VNPK'
              
       /*IF (SELECT SUM(Qty - QtyAllocated - QtyPicked) 
           FROM LOTXLOCXID (NOLOCK) 
           WHERE Loc = @c_FromLoc
           AND ID = @c_FromID
           AND Storerkey = @c_Storerkey
           AND Sku = @c_CurrentSKU) <= 0 */
           
       IF @n_Pallet > 0 
       BEGIN
           IF @n_PickQty % @n_Pallet = 0
           BEGIN
             SET @c_PickMethod = 'FP'
             SET @c_TaskType = 'FPK' 
             SET @c_TSUOM = '1'
             SET @n_TSUOMQty = 1
          END
       END
       
       IF @n_Casecnt > 0 AND @c_PickMethod = 'PP'
       BEGIN
           IF @n_PickQty % @n_Casecnt = 0
           BEGIN
             SET @c_TSUOM = '2'
             SET @n_TSUOMQty = FLOOR(@n_PickQty / @n_Casecnt)
           END
       END
          
       SET @c_TaskType2 = ''
       SELECT TOP 1 @c_TaskType2 = Short
       FROM CODELKUP (NOLOCK)
       WHERE Listname = 'AREATSKTYP'   
       AND Storerkey = @c_StorerKey
       AND Code = @c_Areakey
       
       IF ISNULL(@c_TaskType2,'') <> ''
       BEGIN
          SET @c_TaskType = @c_TaskType2      
       END    
       --Create task detail
       EXECUTE nspg_getkey
       'TaskDetailKey',
       10,
       @c_TaskDetailKey OUTPUT,
       @b_Success OUTPUT,
       @n_err OUTPUT,
       @c_ErrMsg OUTPUT
       IF NOT @b_Success=1
       BEGIN
           SELECT @n_continue = 3
           SELECT @c_ErrMsg = CONVERT(CHAR(250) ,@n_err)
                 ,@n_err = 81006 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                  ': Unable to Get TaskDetailKey (ispWRTSK02)'
             +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                 +' ) '
           CLOSE C_PickTask
           DEALLOCATE C_PickTask
           GOTO RETURN_SP
       END
       ELSE
       BEGIN
           INSERT TASKDETAIL
             (
               TaskDetailKey, TaskType, Storerkey, Sku, Lot, UOM,
               UOMQty, Qty, FromLoc, FromID, ToLoc, ToId, SourceType,
               SourceKey, Caseid, Priority, SourcePriority, OrderKey,
               OrderLineNumber, PickDetailKey, PickMethod, STATUS,
               WaveKey, AreaKey, SystemQty, LogicalFromLoc, LoadKey,
               Message01, Message02, Message03 
             )
           VALUES
                (
                  @c_TaskDetailKey
                  , @c_TaskType
                  , @c_Storerkey
                  , @c_CurrentSKU
                  ,'' -- Lot,
                  , @c_TSUOM     -- UOM,
                  , @n_TSUOMQty  -- UOMQty,
                  , @n_PickQty 
                  , @c_FromLoc -- FromLoc
                  , @c_FromID  -- FromID
                  , @c_ToLoc   -- ToLoc
                  , @c_FromID  -- ToID
                  , 'ispWRTSK02'
                  , @c_WaveKey  -- SourceKey
                  , ''          -- Caseid
                  , @c_Priority -- Priority
                  , @c_Priority -- Source Priority
                  , @c_OrderKey -- Orderkey,
                  , '' -- OrderLineNumber
                  , '' -- PickDetailKey
                  , @c_PickMethod
                  , '0'
                  , @c_WaveKey 
                  , @c_AreaKey  
                  , @n_PickQty  
                  , @c_LogicalFromLoc -- LogicalFromLoc
                  , @c_LoadKey
                  , @c_Susr4 --message01
                  , @c_Lottable02 --message02
                  , @c_OVAS --message03
                )
           
           SELECT @n_err = @@ERROR
           IF @n_err<>0
           BEGIN
               SELECT @n_continue = 3
               SELECT @c_ErrMsg = CONVERT(CHAR(250) ,@n_err)
                     ,@n_err = 81007 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
               ': Insert Into TaskDetail Failed (ispWRTSK02)'
                     +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                     +' ) '
               CLOSE C_PickTask
               DEALLOCATE C_PickTask
           
               GOTO RETURN_SP
           END                 
           
           -- Update the Pickdetail TaskDetailKey
           IF @c_Userdefine01 = 'C'
           BEGIN
              DECLARE CUR_PICKDETAILKEY CURSOR LOCAL FAST_FORWARD READ_ONLY
                 FOR SELECT p.PickDetailKey
                     FROM  PICKDETAIL p WITH (NOLOCK) 
                     JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LA.Lot = p.Lot 
                     WHERE p.STATUS = '0'
                     AND (p.TaskDetailKey IS NULL OR p.TaskDetailKey = '') 
                     AND p.LOC = @c_FromLoc
                     AND p.ID  = @c_FromID
                     AND p.Storerkey = @c_StorerKey
                     AND p.Sku = @c_CurrentSKU
                     AND LEFT(ISNULL(LA.Lottable02,''),4) = @c_Lottable02 
                     AND LA.Lottable04 = @d_Lottable04 
                     AND p.UOM = @c_UOM
           END        
           ELSE
           BEGIN
              DECLARE CUR_PICKDETAILKEY CURSOR LOCAL FAST_FORWARD READ_ONLY
                 FOR SELECT p.PickDetailKey
                     FROM  PICKDETAIL p WITH (NOLOCK) 
                     JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LA.Lot = p.Lot 
                     WHERE p.OrderKey = @c_OrderKey
                     AND p.STATUS = '0'
                     AND (p.TaskDetailKey IS NULL OR p.TaskDetailKey = '') 
                     AND p.LOC = @c_FromLoc
                     AND p.ID  = @c_FromID
                     AND p.Storerkey = @c_StorerKey
                     AND p.Sku = @c_CurrentSKU
                     AND LEFT(ISNULL(LA.Lottable02,''),4) = @c_Lottable02 
                     AND LA.Lottable04 = @d_Lottable04 
                     AND p.UOM = @c_UOM
                     --AND p.UOMQty = @n_UOMQty  --NJOW01
           END
           
           OPEN CUR_PICKDETAILKEY
           FETCH NEXT FROM CUR_PICKDETAILKEY INTO @c_PickDetailKey
           
           WHILE @@FETCH_STATUS<>-1
           BEGIN
               UPDATE PICKDETAIL WITH (ROWLOCK)
               SET    TaskDetailKey = @c_TaskDetailKey
                     ,TrafficCop = NULL
               WHERE  PickDetailKey = @c_PickDetailKey
           
               SET @n_err = @@ERROR
              IF @n_err<>0
              BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_ErrMsg = CONVERT(CHAR(250) ,@n_err)
                        ,@n_err = 81008 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                         ': Update of Pickdetail Failed (ispWRTSK02)'+' ( '
                        +' SQLSvr MESSAGE='+@c_ErrMsg
                        +' ) '
           
                  CLOSE CUR_PICKDETAILKEY
                  DEALLOCATE CUR_PICKDETAILKEY
                  
                  CLOSE C_PickTask
                  DEALLOCATE C_PickTask
           
                  GOTO RETURN_SP
              END
              FETCH NEXT FROM CUR_PICKDETAILKEY INTO @c_PickDetailKey
           END --While CUR_PICKDETAILKEY
           CLOSE CUR_PICKDETAILKEY
           DEALLOCATE CUR_PICKDETAILKEY
       END --insert taskdetail


       FETCH NEXT FROM C_PickTask INTO @c_OrderKey, @c_StorerKey, @c_CurrentSKU, @c_FromLoc, 
                       @c_FromID, @n_PickQty, @c_Lottable02, @d_Lottable04, @c_LogicalFromLoc, @c_Priority, 
                       @c_Door, @c_UOM, @n_UOMQty, @c_Areakey, @c_Loadkey, @c_Susr4, @c_OVAS, @n_Pallet, @n_Casecnt
    END -- WHILE C_PickTask
    CLOSE C_PickTask
    DEALLOCATE C_PickTask                 

   /****************************************************************
   *  End of Pick task 
   ****************************************************************/
   /****************************************************************
   *  Begin of Replenishment task --Shong
   ****************************************************************/
   
   DECLARE @c_LOT             NVARCHAR(10)
         , @c_LOC             NVARCHAR(10)
         , @n_QtyToReplen     INT
         , @n_ReplenTaskQty   INT 
         , @n_FromQty         INT
         , @c_Facility        NVARCHAR(5) 
         , @c_LogicalToLoc    NVARCHAR(10)  
         , @c_SKU             NVARCHAR(20) 
         , @c_ID              NVARCHAR(18)  
   
   -- Extract all the Over Allocated Pick Location 
   DECLARE CUR_REPLENISHMENT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT LLI.Lot, 
          LLI.Loc, 
          (LLI.QtyAllocated + LLI.QtyPicked) - LLI.Qty AS [QtyToReplen],
          LOC.Facility, 
          LOC.LogicalLocation,
          LLI.StorerKey,  
          LLI.Sku   
   FROM LOTxLOCxID LLI WITH (NOLOCK)  
   JOIN PICKDETAIL AS p WITH (NOLOCK) ON p.Lot = LLI.Lot AND p.Loc = LLI.Loc AND p.ID = LLI.Id 
   JOIN WAVEDETAIL AS WD WITH (NOLOCK) ON WD.OrderKey = p.OrderKey 
   JOIN LOC AS LOC WITH (NOLOCK) ON LOC.Loc = LLI.Loc 
   WHERE LLI.Qty < LLI.QtyAllocated + LLI.QtyPicked 
   AND   WD.WaveKey = @c_WaveKey 
   AND   EXISTS(SELECT 1 FROM SKUxLOC AS sl WITH (NOLOCK)
                WHERE sl.StorerKey = LLI.StorerKey 
                  AND sl.Sku = LLI.Sku 
                  AND sl.Loc = LLI.Loc 
                  AND sl.LocationType IN ('PICK','CASE') )
   ORDER BY LOC.LogicalLocation   
   
   OPEN CUR_REPLENISHMENT
   
   FETCH FROM CUR_REPLENISHMENT INTO @c_LOT, @c_LOC, @n_QtyToReplen, @c_Facility, @c_LogicalToLoc, @c_Storerkey, @c_SKU
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @n_ReplenTaskQty = 0 
      
      SELECT @n_ReplenTaskQty = ISNULL(SUM(Qty),0)  
      FROM   TaskDetail AS TD WITH (NOLOCK) 
      WHERE  TD.TaskType = 'RPF' 
      AND    TD.[Status] IN ('0','1','2','3') 
      AND    TD.ToLoc = @c_LOC 
      AND    TD.Lot = @c_LOT 
      
      IF @b_Debug = 1
      BEGIN
         PRINT ''
         PRINT '     @c_SKU: ' + @c_SKU 
         PRINT '     @c_FromLOC: ' + @c_FromLoc 
         PRINT '     @n_QtyToReplen: ' + CAST(@n_QtyToReplen AS VARCHAR(10))
         PRINT '     @n_ReplenTaskQty: ' + CAST(@n_ReplenTaskQty AS VARCHAR(10))
      END
      
      IF @n_ReplenTaskQty > = @n_QtyToReplen 
         GOTO GET_NEXT_REPLEN
      
      SET @n_QtyToReplen = @n_QtyToReplen - ISNULL(@n_ReplenTaskQty,0) 
      
      WHILE @n_QtyToReplen > 0 
      BEGIN
         SET @n_FromQty = 0 
         SET @c_FromLoc = ''
         SET @c_PickMethod = 'FP'
         -- Get Next Available Location
         -- Take from Location with Full Pallet
         SELECT TOP 1 
                @c_FromLoc = LLI.LOC, 
                @n_FromQty = LLI.QTY, 
                @c_FromID  = LLI.Id 
         FROM   LOTxLOCxID AS LLI WITH (NOLOCK) 
         JOIN LOC (NOLOCK) ON (LLI.Loc = LOC.LOC AND LOC.LocationFlag NOT IN ('HOLD','DAMAGE')      
                               AND LOC.Status <> 'HOLD')  
         JOIN ID (NOLOCK) ON (LLI.Id = ID.ID AND ID.STATUS <> 'HOLD')     
         JOIN LOT (NOLOCK) ON (LLI.LOT = LOT.LOT AND LOT.STATUS <> 'HOLD')   
         JOIN SKUxLOC AS sl WITH (NOLOCK) ON sl.StorerKey = LLI.StorerKey 
                     AND sl.Sku = LLI.Sku 
                     AND sl.Loc = LLI.Loc 
                     AND sl.LocationType NOT IN ('CASE','PICK')                     
         WHERE  LLI.LOT = @c_LOT 
         AND    LLI.QtyAllocated = 0 
         AND    LLI.QtyPicked = 0  
         AND    LLI.QtyReplen = 0 
         AND    LLI.Qty > 0
         AND    LOC.Facility = @c_Facility         --(Wan02) Fixed 
         ORDER BY LLI.Qty, LOC.LogicalLocation
         
         -- If cannot find the full pallet, take patial pallet 
         IF ISNULL(RTRIM(@c_FromLoc), '') = ''
         BEGIN
            SET @c_PickMethod = 'PP'
            
            SELECT TOP 1 
                   @c_FromLoc = LLI.LOC, 
                   @n_FromQty = LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen,                   
                   @c_FromID  = LLI.Id  
            FROM   LOTxLOCxID AS LLI WITH (NOLOCK) 
            JOIN LOC (NOLOCK) ON (LLI.Loc = LOC.LOC AND LOC.LocationFlag NOT IN ('HOLD','DAMAGE')      
                                  AND LOC.Status <> 'HOLD')  
            JOIN ID (NOLOCK) ON (LLI.Id = ID.ID AND ID.STATUS <> 'HOLD')     
            JOIN LOT (NOLOCK) ON (LLI.LOT = LOT.LOT AND LOT.STATUS <> 'HOLD')   
            JOIN SKUxLOC AS sl WITH (NOLOCK) ON sl.StorerKey = LLI.StorerKey 
                        AND sl.Sku = LLI.Sku 
                        AND sl.Loc = LLI.Loc 
                        AND sl.LocationType NOT IN ('CASE','PICK')                     
            WHERE  LLI.LOT = @c_LOT 
            AND    LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen > 0  
            AND    LOC.Facility = @c_Facility         --(Wan02) Fixed
            ORDER BY LLI.Qty, LOC.LogicalLocation           
         END  
         
         -- Can't find location, stop here
         IF ISNULL(RTRIM(@c_FromLoc), '') = '' 
            BREAK 
         
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
            SET @c_LogicalFromLoc = ''  
            SELECT TOP 1 @c_AreaKey = AreaKey    
                       , @c_LogicalFromLoc = ISNULL(RTRIM(LogicalLocation),'')    
            FROM LOC LOC WITH (NOLOCK)    
            JOIN AREADETAIL ARD WITH (NOLOCK) ON (LOC.PutawayZone = ARD.PutawayZone)    
            WHERE LOC.Loc = @c_FromLoc     
            
            -- Priority Logic - Default to 5
            SET @c_Priority = '5'
            
            -- If still have pending replen task generated from other wave, set to lower priority?
            IF @n_ReplenTaskQty > 0 
            BEGIN
               SET @c_Priority = '6'                    
            END
            
            DECLARE @n_QtyRequiredByThisWave INT, 
                       @n_NoOfOrders            INT 
               
            SET @n_QtyRequiredByThisWave = 0 
            SET @n_NoOfOrders = 0 
               
            SELECT @n_QtyRequiredByThisWave = ISNULL(SUM(P.Qty),0), 
                   @n_NoOfOrders = COUNT(DISTINCT P.OrderKey)  
            FROM   PICKDETAIL AS p WITH (NOLOCK) 
            WHERE  P.[Status] < '9' 
            AND    P.Lot = @c_Lot
            AND    P.LOC = @c_LOC 
            AND    EXISTS(SELECT 1 FROM WAVEDETAIL AS WD WITH (NOLOCK)
                           WHERE WD.WaveKey = @c_WaveKey
                           AND   p.OrderKey = WD.OrderKey)
            
            -- If not required by this Wave, set to low priotity 
            IF @n_QtyRequiredByThisWave = 0 
               SET @c_Priority = '9'
            ELSE
            BEGIN
               -- If already have task generated
               IF EXISTS(SELECT 1 FROM TASKDETAIL TD WITH (NOLOCK) 
                         WHERE TD.TaskType = 'RPF'   
                         AND   TD.[Status] IN ('0','1','2','3') 
                         AND   TD.ToLoc = @c_LOC 
                         AND   TD.Lot = @c_LOT 
                         AND   TD.WaveKey = @c_WaveKey)
               BEGIN
                  -- If replenishment is for more than 1 order, set to low priority
                  IF @n_NoOfOrders > 1
                  BEGIN
                     SET @c_Priority = '7' 
                  END                                          
               END                                 
            END                           
            
            INSERT TASKDETAIL
              (
                TaskDetailKey, TaskType, Storerkey, Sku, UOM, UOMQty, Qty, SystemQty, Lot, FromLoc, FromID, ToLoc, ToID, SourceType, 
                SourceKey, Priority, SourcePriority, STATUS, LogicalFromLoc, LogicalToLoc, PickMethod, Wavekey, Listkey, Areakey, 
                Message03, CaseID, LoadKey, OrderKey 
              )
            VALUES  (
                 @c_taskdetailkey
               , 'RPF' -- TaskType 
               , @c_Storerkey 
               , @c_Sku 
               , '1' -- UOM 
               , @n_FromQty -- UOM Qty
               , @n_FromQty -- Qty  
               , @n_FromQty -- System Qty
               , @c_Lot
               , @c_FromLoc
               , @c_FromID -- From ID 
               , @c_LOC -- to Loc 
               , '' -- to id      
               , 'ispWRTSK02' -- Sourcetype      
               , @c_Wavekey   -- Sourcekey      
               , @c_Priority  -- Priority           
               , '9' -- Sourcepriority      
               , '0' -- Status      
               , @c_LogicalFromLoc -- Logical from loc      
               , @c_LogicalToLoc   -- Logical to loc      
               , @c_PickMethod
               , @c_Wavekey
               , ''
               , @c_Areakey
               , '' -- Message03 
               , '' -- CaseId
               , '' -- LoadKey
               , '' -- Orderkey 
                )    
    
            SET @n_err = @@ERROR     
    
            IF @n_err <> 0      
            BEGIN    
    
               SET @n_continue = 3      
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
               SET @n_err = 81013   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
    
               GOTO RETURN_SP    
            END 
            
            UPDATE LOTxLOCxID WITH (ROWLOCK) 
               SET QtyReplen =  QtyReplen + @n_FromQty, 
                   TrafficCop = NULL, 
                   EditDate = GETDATE(),
                   EditWho = SUSER_SNAME()
            WHERE LOT = @c_LOT 
            AND   LOC = @c_FromLoc 
            AND   ID  = @c_FromID
            
            IF @n_FromQty > @n_QtyToReplen
            BEGIN
               SET @n_QtyToReplen = 0
               BREAK
            END
            ELSE
               SET @n_QtyToReplen = @n_QtyToReplen - @n_FromQty
               
         END -- @b_success = 1                  
      END -- WHILE @n_QtyToReplen > 0
   
      GET_NEXT_REPLEN:
      FETCH FROM CUR_REPLENISHMENT INTO @c_LOT, @c_LOC, @n_QtyToReplen, @c_Facility, @c_LogicalToLoc, @c_Storerkey, @c_SKU 
   END
   
   CLOSE CUR_REPLENISHMENT
   DEALLOCATE CUR_REPLENISHMENT

   /****************************************************************
   *  End of Replenishment task 
   ****************************************************************/
              
   --(Wan01) - Generate Task Group (START)
   DECLARE CUR_TASKGRP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT StorerKey
      ,  TaskType
      ,  Areakey
      ,  Sourcekey
      ,  OrderKey
      ,  COUNT(1)
   FROM TASKDETAIL WITH (NOLOCK)
   WHERE WaveKey = @c_WaveKey 
   AND  SourceType = 'ispWRTSK02' 
   AND  Status = '0'
   AND (GroupKey IS NULL OR GroupKey = '')
   GROUP BY StorerKey
         ,  TaskType
         ,  Areakey
         ,  Sourcekey
         ,  OrderKey
   ORDER BY MIN (TaskdetailKey)

   OPEN CUR_TASKGRP

   FETCH NEXT FROM CUR_TASKGRP INTO @c_StorerKey
                                 ,  @c_TaskType
                                 ,  @c_Areakey
                                 ,  @c_Sourcekey
                                 ,  @c_OrderKey
                                 ,  @n_nooftasks
               
   WHILE (@@FETCH_STATUS<>-1)
   BEGIN
      SET @n_rowcount = 0

      SELECT @n_rowcount = CONVERT(INT, CASE WHEN ISNUMERIC(CL.Short) = 1 THEN ISNULL(CL.Short,'0') ELSE '0' END)
      FROM CODELKUP CL WITH (NOLOCK)
      WHERE ListName = 'TSKBALN'
      AND   Code = @c_TaskType

      IF @n_rowcount = 9999999
      BEGIN
         SET @n_rowcount = 0
      END

      WHILE @n_nooftasks > 0 
      BEGIN
         EXECUTE nspg_getkey
               'TaskGroupKey' 
            ,   10 
            ,   @c_TaskGroupKey  OUTPUT 
            ,   @b_Success       OUTPUT 
            ,   @n_err           OUTPUT 
            ,   @c_ErrMsg        OUTPUT

         
         IF NOT @b_Success=1
         BEGIN
           SET @n_continue = 3
           SET @c_ErrMsg = CONVERT(CHAR(250) ,@n_err)
           SET @n_err = 81010 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                  ': Unable to Get TaskGroupKey (ispWRTSK02)'
                 +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                 +' ) '
           GOTO RETURN_SP
         END

         SET ROWCOUNT @n_rowcount 

         UPDATE TASKDETAIL WITH (ROWLOCK)
         SET GroupKey = @c_TaskGroupKey
            ,EditDate = GETDATE()
            ,EditWho  = SUSER_NAME()
            ,Trafficcop = NULL
         WHERE WaveKey = @c_WaveKey 
         AND  TaskType   = @c_TaskType
         AND  Storerkey  = @c_Storerkey
         AND  SourceType = 'ispWRTSK02' 
         AND  SourceKey  = @c_Sourcekey
         AND  AreaKey    = @c_AreaKey
         AND  Orderkey   = @c_Orderkey
         AND  Status = '0'
         AND (GroupKey IS NULL OR GroupKey = '')

         SET @n_rowcount = @@ROWCOUNT
         SET @n_err = @@ERROR

         SET ROWCOUNT 0

         IF @n_err<>0
         BEGIN
            SET @n_continue = 3
            SET @c_ErrMsg = CONVERT(CHAR(250) ,@n_err)
            SET @n_err = 81015 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                  ': Update Taskdetail fail. (ispWRTSK02)'
                 +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg
                 +' ) '
            GOTO RETURN_SP
         END

         SET @n_nooftasks = @n_nooftasks - @n_rowcount
      END

      FETCH NEXT FROM CUR_TASKGRP INTO @c_StorerKey
                                    ,  @c_TaskType
                                    ,  @c_Areakey
                                    ,  @c_Sourcekey
                                    ,  @c_OrderKey
                                    ,  @n_nooftasks   
   END
   CLOSE CUR_TASKGRP
   DEALLOCATE CUR_TASKGRP
   --(Wan01) - Generate Task Group (END) 



   
      
                 
RETURN_SP:
   --(Wan01) - Generate Task Group (START) 
   IF CURSOR_STATUS('LOCAL' , 'CUR_TASKGRP') in (0 , 1)  
   BEGIN  
      CLOSE CUR_TASKGRP  
      DEALLOCATE CUR_TASKGRP  
   END  
   --(Wan01) - Generate Task Group (END) 

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCnt
         BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @n_err, @c_errmsg, 'ispWRTSK02'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- Procedure
 

GO