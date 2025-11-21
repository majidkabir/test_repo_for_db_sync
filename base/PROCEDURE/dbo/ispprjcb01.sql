SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure:  ispPRJCB01                                        */
/* Creation Date: 06-MAY-2024                                           */
/* Copyright: MAERSK                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  UWP-18748 UK Demeter - JCB Allocation                      */
/*           Allocate full pallet of single sku from bulk by top up     */
/*           order qty if pallet qty more than order qty. UOM 1.        */
/*           Order type = '0' Normal order                              */
/*                                                                      */
/*           set the sp to storerconfig PreAllocationSP                 */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* Github Version: 1.1                                                  */
/*                                                                      */
/* Version: V2                                                          */
/*                                                                      */
/* Data Modifications:                                                  */
/* Updates:                                                             */
/* Date        Author   Rev   Purposes                                  */
/* 2024-06-02  Wan01    1.1   UWP-18392-JCB-MixSkuAllocation for Normal */
/* 2024-10-09  SSA01    1.2   UWP-24678-JCB- Allocation for Kitting and */
/*                                    Decanting                         */
/* 2024-11-13  SOMA01   1.3  Hot fix to populate lottable03 in orderdetail*/
/************************************************************************/
CREATE   PROC [dbo].[ispPRJCB01] (
     @c_OrderKey        NVARCHAR(10)
   , @c_LoadKey         NVARCHAR(10)
   , @c_Wavekey         NVARCHAR(10)
   , @b_Success         INT           OUTPUT
   , @n_Err             INT           OUTPUT
   , @c_ErrMsg          NVARCHAR(250) OUTPUT
   , @b_debug           INT = 0 )
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue    INT,
           @n_StartTCnt   INT

   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''

   DECLARE @c_OrderLineNumber       NVARCHAR(5)
          ,@c_SKU                   NVARCHAR(20)
          ,@c_StorerKey             NVARCHAR(15)
          ,@c_Lottable01            NVARCHAR(18)
          ,@c_Lottable02            NVARCHAR(18)
          ,@c_Lottable03            NVARCHAR(18)
          ,@d_Lottable04            DATETIME
          ,@d_Lottable05            DATETIME
          ,@c_Lottable06            NVARCHAR(30)
          ,@c_Lottable07            NVARCHAR(30)
          ,@c_Lottable08            NVARCHAR(30)
          ,@c_Lottable09            NVARCHAR(30)
          ,@c_Lottable10            NVARCHAR(30)
          ,@c_Lottable11            NVARCHAR(30)
          ,@c_Lottable12            NVARCHAR(30)
          ,@d_Lottable13            DATETIME
          ,@d_Lottable14            DATETIME
          ,@d_Lottable15            DATETIME
          ,@c_Lottable04            NVARCHAR(30)
          ,@c_Lottable05            NVARCHAR(30)
          ,@c_Lottable13            NVARCHAR(30)
          ,@c_Lottable14            NVARCHAR(30)
          ,@c_Lottable15            NVARCHAR(30)
          ,@c_Lot                   NVARCHAR(10)
          ,@c_Loc                   NVARCHAR(10)
          ,@c_ID                    NVARCHAR(18)
          ,@c_Facility              NVARCHAR(5)
          ,@c_PackKey               NVARCHAR(10)
          ,@c_UOM                   NVARCHAR(10)
          ,@c_SQL                   NVARCHAR(MAX) = ''
          ,@c_SQLParm               NVARCHAR(MAX) = ''
          ,@c_Conditions            NVARCHAR(MAX) = ''
          ,@n_OpenQty               INT = 0
          ,@n_PickQty               INT = 0
          ,@n_IDQtyAvai             INT = 0
          ,@n_LotQtyAvai            INT = 0
          ,@n_ExtraQty              INT = 0
          ,@n_QtyLeftToFulfill      INT
          ,@c_PickDetailKey         NVARCHAR(10)          
          ,@c_Type                  NVARCHAR(10)

          , @c_PackUOM3             NVARCHAR(10) = ''                               --(Wan01)
          , @c_IDSku                NVARCHAR(20) =''                                --(Wan01)
          , @c_IDLottable03         NVARCHAR(18)                                    --(SOMA01)
          , @c_OrderLineNoAlloc     NVARCHAR(5) =''                                 --(Wan01)
   
   SET @c_UOM = '1'
   --Added PA.Zonecategory (SSA01)
   SET @c_Conditions = ' AND LOC.LocationType = ''BULK''
                         AND PA.ZoneCategory  = ''EMG''
                         AND NOT EXISTS(SELECT 1 FROM LOTXLOCXID L (NOLOCK) WHERE L.Storerkey = LLI.Storerkey
                                        AND L.Sku = LLI.Sku AND L.Id = LLI.Id AND L.Loc = LLI.Loc
                                        AND (L.QtyAllocated + L.QtyPicked + L.QtyReplen) > 0) '
                         --(Wan01) - START
                         --AND NOT EXISTS(SELECT 1 FROM LOTXLOCXID L (NOLOCK) WHERE L.Storerkey = LLI.Storerkey      
                         --               AND L.Sku <> LLI.Sku AND L.Id = LLI.Id AND L.Loc = LLI.Loc AND L.Qty > 0) ' 
                         --(Wan01) - END
                     + ' AND NOT EXISTS(SELECT 1 FROM PICKDETAIL PD (NOLOCK) WHERE PD.Storerkey = LLI.Storerkey
                                        AND PD.Sku = LLI.Sku AND PD.Lot = LLI.Lot AND PD.ToLoc = LLI.Loc
                                        AND PD.CaseID = LLI.Id AND PD.Status = ''0'') '                              
   SET @c_Type = '0'                                     
                                             
   IF @n_continue IN(1,2)
   BEGIN
      IF ISNULL(@c_Orderkey,'') <> ''
      BEGIN
         DECLARE CUR_ORDER_LINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT OD.StorerKey, OD.OrderKey, OD.OrderLineNumber, OD.Sku, (OD.OpenQty - (OD.QtyAllocated + OD.QtyPicked))
                        ,SKU.Packkey
                        ,OD.LOTTABLE01
                        ,OD.LOTTABLE02
                        ,OD.LOTTABLE03
                        ,OD.LOTTABLE04
                        ,OD.LOTTABLE05
                        ,OD.LOTTABLE06
                        ,OD.LOTTABLE07
                        ,OD.LOTTABLE08
                        ,OD.LOTTABLE09
                        ,OD.LOTTABLE10
                        ,OD.LOTTABLE11
                        ,OD.LOTTABLE12
                        ,OD.LOTTABLE13
                        ,OD.LOTTABLE14
                        ,OD.LOTTABLE15
                        ,O.Facility
         FROM ORDERS AS o WITH (NOLOCK)
         JOIN ORDERDETAIL AS OD WITH (NOLOCK) ON OD.OrderKey = o.OrderKey
         JOIN SKU WITH (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
         JOIN PACK WITH (NOLOCK) ON SKU.Packkey = PACK.Packkey
         WHERE o.OrderKey = @c_OrderKey
         AND (OD.OpenQty - (OD.QtyAllocated + OD.QtyPicked)) > 0
         AND o.SOStatus <> 'CANC' 
         AND o.Status < '9'            
         AND O.Type = @c_Type
         AND SKU.BUSR7 <> '1'                                                 --(SSA01)
         ORDER BY OD.Orderkey, OD.OrderLineNumber
      END
      ELSE IF ISNULL(@c_Loadkey,'') <> ''
      BEGIN
         DECLARE CUR_ORDER_LINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT OD.StorerKey, OD.OrderKey, OD.OrderLineNumber, OD.Sku, (OD.OpenQty - (OD.QtyAllocated + OD.QtyPicked))
                        ,SKU.Packkey
                        ,OD.LOTTABLE01
                        ,OD.LOTTABLE02
                        ,OD.LOTTABLE03
                        ,OD.LOTTABLE04
                        ,OD.LOTTABLE05
                        ,OD.LOTTABLE06
                        ,OD.LOTTABLE07
                        ,OD.LOTTABLE08
                        ,OD.LOTTABLE09
                        ,OD.LOTTABLE10
                        ,OD.LOTTABLE11
                        ,OD.LOTTABLE12
                        ,OD.LOTTABLE13
                        ,OD.LOTTABLE14
                        ,OD.LOTTABLE15
                        ,O.Facility
         FROM ORDERS AS o WITH (NOLOCK)
         JOIN ORDERDETAIL AS OD WITH (NOLOCK) ON OD.OrderKey = o.OrderKey
         JOIN SKU WITH (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
         JOIN PACK WITH (NOLOCK) ON SKU.Packkey = PACK.Packkey
         JOIN LoadPlanDetail LPD WITH (NOLOCK) ON o.OrderKey = LPD.OrderKey
         WHERE LPD.LoadKey = @c_Loadkey
         AND (OD.OpenQty - (OD.QtyAllocated + OD.QtyPicked)) > 0
         AND o.SOStatus <> 'CANC' 
         AND o.Status < '9'                     
         AND O.Type = @c_Type
         AND SKU.BUSR7 <> '1'                                               --(SSA01)
         ORDER BY OD.Orderkey, OD.OrderLineNumber
      END
      ELSE IF ISNULL(@c_Wavekey,'') <> ''
      BEGIN
         DECLARE CUR_ORDER_LINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT OD.StorerKey, OD.OrderKey, OD.OrderLineNumber, OD.Sku, (OD.OpenQty - (OD.QtyAllocated + OD.QtyPicked))
                        ,SKU.Packkey
                        ,OD.LOTTABLE01
                        ,OD.LOTTABLE02
                        ,OD.LOTTABLE03
                        ,OD.LOTTABLE04
                        ,OD.LOTTABLE05
                        ,OD.LOTTABLE06
                        ,OD.LOTTABLE07
                        ,OD.LOTTABLE08
                        ,OD.LOTTABLE09
                        ,OD.LOTTABLE10
                        ,OD.LOTTABLE11
                        ,OD.LOTTABLE12
                        ,OD.LOTTABLE13
                        ,OD.LOTTABLE14
                        ,OD.LOTTABLE15
                        ,O.Facility
         FROM ORDERS AS o WITH (NOLOCK)
         JOIN ORDERDETAIL AS OD WITH (NOLOCK) ON OD.OrderKey = o.OrderKey
         JOIN SKU WITH (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
         JOIN PACK WITH (NOLOCK) ON SKU.Packkey = PACK.Packkey
         JOIN WaveDetail WD WITH (NOLOCK) ON o.OrderKey = WD.OrderKey
         WHERE WD.Wavekey = @c_Wavekey
         AND (OD.OpenQty - (OD.QtyAllocated + OD.QtyPicked)) > 0
         AND o.SOStatus <> 'CANC' 
         AND o.Status < '9'                     
         AND O.Type = @c_Type
         AND SKU.BUSR7 <> '1'                                                          --(SSA01)
         ORDER BY OD.Orderkey, OD.OrderLineNumber
      END
      
      OPEN CUR_ORDER_LINES
      
      FETCH FROM CUR_ORDER_LINES INTO @c_StorerKey, @c_OrderKey, @c_OrderLineNumber, @c_SKU, @n_OpenQty, @c_Packkey,
                                      @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08,
                                      @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15, @c_Facility
                                   
      WHILE @@FETCH_STATUS = 0 AND @n_Continue IN(1,2)
      BEGIN
          IF @b_debug = 1                                                           --(Wan01) - START
          BEGIN
             SELECT @c_OrderKey as orderkey, @c_OrderLineNumber as orderlinenumber, @c_SKU as sku, @n_OpenQty as openqty
          END         
          
          IF NOT EXISTS(SELECT 1 FROM ORDERDETAIL (NOLOCK)
                        WHERE Orderkey = @c_Orderkey
                        AND OrderLineNumber = @c_OrderLineNumber
                        AND ISNUMERIC(UserDefine01) = 1)
          BEGIN
             UPDATE ORDERDETAIL WITH (ROWLOCK)
             SET Userdefine01 = CAST(OpenQty AS NVARCHAR)
                ,Trafficcop = NULL
             WHERE Orderkey = @c_Orderkey
             AND OrderLineNumber = @c_OrderLineNumber

               SET @n_err = @@ERROR
               
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
               SET @n_err = 81010  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Orderdetail Failed. (ispPRJCB01)'
                           + '( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                                                            
            END                                                                                                                
         END 
         
         SELECT @n_OpenQty = OD.OpenQty - (OD.QtyAllocated + OD.QtyPicked)
         FROM ORDERDETAIL OD (NOLOCK)
         WHERE OD.Orderkey = @c_Orderkey 
         AND OD.OrderLineNumber = @c_OrderLineNumber

         IF @n_OpenQty = 0
         BEGIN
            CONTINUE
         END                                                                        

         SET @n_QtyLeftToFulfill = @n_OpenQty
          --Joined  PUTAWAYZONE (SSA01)
         SET @c_SQL = ' DECLARE CUR_INV CURSOR FAST_FORWARD READ_ONLY FOR 
            SELECT LLI.Loc, LLI.ID, 
                   SUM(LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen)
            FROM LOTxLOCxID lli (NOLOCK)
            JOIN LOT (NOLOCK) ON lot.Lot = lli.Lot AND lot.[Status] =''OK''
            JOIN
              (SELECT LLI.Storerkey, LLI.Loc, LLI.ID, LOC.LogicalLocation, LA.Lottable05
               FROM LOTxLOCxID LLI (NOLOCK)
               JOIN LOC (NOLOCK) ON (LLI.Loc = LOC.LOC)
               JOIN ID (NOLOCK) ON (LLI.Id = ID.ID)
               JOIN LOT (NOLOCK) ON (LLI.LOT = LOT.LOT)
               JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT
               JOIN SKUXLOC SL (NOLOCK) ON (LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc)
               JOIN SKU (NOLOCK) ON (LLI.Storerkey = Sku.Storerkey AND LLI.Sku = Sku.Sku)
               JOIN PUTAWAYZONE PA (NOLOCK) ON LOC.Putawayzone = PA.Putawayzone
               WHERE LOC.LocationFlag = ''NONE''
               AND LOC.Status = ''OK''
               AND LOT.Status = ''OK''
               AND ID.Status = ''OK''
               AND LOC.Facility = @c_Facility
               AND (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen) > 0
               AND LLI.STORERKEY = @c_StorerKey
               AND LLI.SKU = @c_SKU ' +
               RTRIM(@c_Conditions) + ' ' +
               CASE WHEN ISNULL(@c_Lottable01,'') <> '' THEN ' AND LA.Lottable01 = @c_Lottable01 ' ELSE '' END +
               CASE WHEN ISNULL(@c_Lottable02,'') <> '' THEN ' AND LA.Lottable02 = @c_Lottable02 ' ELSE '' END +
               CASE WHEN ISNULL(@c_Lottable03,'') <> '' THEN ' AND LA.Lottable03 = @c_Lottable03 ' ELSE '' END +
               CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101' AND @d_Lottable04 IS NOT NULL THEN ' AND LA.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END +
               CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101' AND @d_Lottable05 IS NOT NULL THEN ' AND LA.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END +
               CASE WHEN ISNULL(@c_Lottable06,'') <> '' THEN ' AND LA.Lottable06 = @c_Lottable06 ' ELSE '' END +
               CASE WHEN ISNULL(@c_Lottable07,'') <> '' THEN ' AND LA.Lottable07 = @c_Lottable07 ' ELSE '' END +
               CASE WHEN ISNULL(@c_Lottable08,'') <> '' THEN ' AND LA.Lottable08 = @c_Lottable08 ' ELSE '' END +
               CASE WHEN ISNULL(@c_Lottable09,'') <> '' THEN ' AND LA.Lottable09 = @c_Lottable09 ' ELSE '' END +
               CASE WHEN ISNULL(@c_Lottable10,'') <> '' THEN ' AND LA.Lottable10 = @c_Lottable10 ' ELSE '' END +
               CASE WHEN ISNULL(@c_Lottable11,'') <> '' THEN ' AND LA.Lottable11 = @c_Lottable11 ' ELSE '' END +
               CASE WHEN ISNULL(@c_Lottable12,'') <> '' THEN ' AND LA.Lottable12 = @c_Lottable12 ' ELSE '' END +
               CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101' AND @d_Lottable13 IS NOT NULL THEN ' AND LA.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END +
               CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101' AND @d_Lottable14 IS NOT NULL THEN ' AND LA.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END +
               CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101' AND @d_Lottable15 IS NOT NULL THEN ' AND LA.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END +
             ' ) li ON li.Storerkey = lli.Storerkey AND li.Loc = lli.Loc AND li.ID = lli.ID
            LEFT OUTER JOIN (SELECT od.Storerkey
                                 ,  od.Sku
                                 ,  QtyToAlloc = od.OpenQty - od.QtyAllocated - od.QtyPicked
                             FROM ORDERDETAIL od (NOLOCK)  
                             WHERE od.Orderkey = @c_Orderkey
                             AND od.Userdefine02 IN('''', NULL)) ods ON ods.Storerkey = lli.Storerkey
                                                                     AND ods.Sku = lli.Sku
            WHERE LLI.STORERKEY = @c_StorerKey
            AND (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen) > 0
            GROUP BY lli.Loc, li.LogicalLocation, LLI.ID ' +  
          ' ORDER BY MIN(li.Lottable05)
                   , CASE WHEN COUNT(DISTINCT lli.SKU) = 1 THEN 1 ELSE 9 END
                   , MIN(CASE WHEN lli.Qty = ISNULL(ods.QtyToAlloc,0) THEN 0 
                              WHEN lli.Qty > ISNULL(ods.QtyToAlloc,0) THEN 1
                              ELSE 2 END)
                   , MAX(CASE WHEN lli.Qty = ISNULL(ods.QtyToAlloc,0) THEN 2 
                              WHEN lli.Qty > ISNULL(ods.QtyToAlloc,0) THEN 1
                              ELSE 0 END) DESC
                   , SUM(lli.Qty)
                   , li.LogicalLocation, lli.Loc '
          
         SET @c_SQLParm =  N'@c_StorerKey NVARCHAR(15), @c_SKU NVARCHAR(20), @c_Facility NVARCHAR(5), ' +
                            '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME, ' +
                            '@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), ' +
                            '@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME '
                        +  ',@c_Orderkey NVARCHAR(10)'                              --(Wan01)
         
         EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, 
             @c_StorerKey, @c_SKU, @c_Facility, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
             @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
             @d_Lottable13, @d_Lottable14, @d_Lottable15
            ,@c_Orderkey                                                           --(Wan01) - END    
             
         OPEN CUR_INV                   
                                                            
         FETCH FROM CUR_INV INTO @c_Loc, @c_ID, @n_IDQtyAvai
                                       
         WHILE @@FETCH_STATUS = 0 AND @n_Continue IN(1,2) AND @n_QtyLeftToFulFill > 0 --get pallet of the sku
         BEGIN       
            IF @b_debug = 1
            BEGIN
               SELECT @c_Loc as loc, @c_ID as id, @n_IDQtyAvai as idqtyavai, @n_QtyLeftToFulFill as qtylefttofulfill
            END

            DECLARE CUR_LOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT LLI.Lot, LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen
                  ,LLI.Sku , LA.LOTTABLE03                                          --(Wan01)(SOMA01)
            FROM LOTXLOCXID LLI (NOLOCK)
            JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
            JOIN LOTATTRIBUTE LA (NOLOCK) ON LA.Lot = LOT.Lot                       --(SOMA01)
            WHERE LLI.Storerkey = @c_Storerkey
            --AND LLI.Sku = @c_Sku                                                  --(Wan01)
            AND LLI.Loc = @c_Loc
            AND LLI.ID = @c_ID
            AND LOT.Status = 'OK'
            AND LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen > 0
            ORDER BY CASE WHEN LLI.Sku = @c_Sku THEN 1 ELSE 2 END                   --(Wan01)     

            OPEN CUR_LOT
                                                               
            FETCH FROM CUR_LOT INTO @c_Lot, @n_LotQtyAvai, @c_IDSku , @c_IDLottable03               --(Wan01)(SOMA01)
                                       
            WHILE @@FETCH_STATUS = 0 AND @n_Continue IN(1,2) --get all the sku lots of the pallet 
            BEGIN                                                
               SET @n_PickQty = 0
               SET @c_OrderLineNoAlloc = @c_OrderLineNumber                         --(Wan01) - START
               SET @n_OpenQty = @n_QtyLeftToFulFill

               IF @c_Sku <> @c_IDSku
               BEGIN
                  SET @c_OrderLineNoAlloc = ''
                  SELECT TOP 1
                        @c_OrderLineNoAlloc = OrderLineNumber 
                       ,@n_OpenQty = OpenQty - QtyAllocated - QtyPicked
                  FROM ORDERDETAIL (NOLOCK)
                  WHERE Orderkey = @c_Orderkey
                  AND Sku = @c_IDSku
               END                                                                  --(Wan01) - END
                  
               IF @n_LotQtyAvai > @n_OpenQty                                        --(Wan01)
               BEGIN
                  SET @n_ExtraQty = @n_LotQtyAvai - @n_OpenQty                      --(Wan01)
                  SET @n_PickQty = @n_LotQtyAvai

                  UPDATE ORDERDETAIL WITH (ROWLOCK)
                  SET OpenQty = OpenQty + @n_ExtraQty
                     ,UserDefine01 = CASE WHEN ISNUMERIC(UserDefine01) = 0 THEN OpenQty ELSE UserDefine01 END
                  WHERE Orderkey = @c_Orderkey
                  AND OrderLineNumber = @c_OrderLineNoAlloc                         --(Wan01)
                       
                  SET @n_err = @@ERROR
                      
                  IF @n_err <> 0
                  BEGIN
                     SET @n_continue = 3
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                     SET @n_err = 81020  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Orderdetail Failed. (ispPRJCB01)'
                                 + '( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                                                            
                  END  
               END
               ELSE
               BEGIN
                  SET @n_PickQty = @n_LotQtyAvai
               END
                                 
               IF @c_Sku <> @c_IDSku                                                --(Wan01) - START      
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM ORDERDETAIL (NOLOCK)
                                 WHERE Orderkey = @c_Orderkey
                                 AND Sku = @c_IDSku
                                 )
                  BEGIN
                     SELECT @c_Packkey = p.Packkey
                           ,@c_PackUOM3 = p.PackUOM3
                     FROM SKU s (NOLOCK) 
                     JOIN PACK p (NOLOCK) ON p.packkey = s.packkey     
                     WHERE s.storerkey = @c_Storerkey
                     AND s.Sku  = @c_IDSku

                     SELECT TOP 1 
                           @c_OrderLineNoAlloc = od.OrderLineNumber 
                     FROM ORDERDETAIL od (NOLOCK)
                     WHERE od.Orderkey = @c_Orderkey
                     ORDER BY od.OrderLineNumber DESC

                     SET @c_OrderLineNoAlloc = RIGHT('00000' +
                                                  CONVERT(NVARCHAR(5),
                                                  CONVERT(INT, @c_OrderLineNoAlloc) + 1)
                                                       ,5)
                     INSERT INTO ORDERDETAIL (Orderkey, Orderlinenumber, Storerkey, SKu
                                             ,ExternOrderkey, ExternLineNo, POkey, ExternPOKey, ConsoOrderkey
                                             ,Packkey, UOM, OriginalQty, OpenQty ,EnteredQTY
                                             ,Loadkey, MBOLKey
                                             ,Lottable01, Lottable02, Lottable03, Lottable04, Lottable05
                                             ,Lottable06, Lottable07, Lottable08, Lottable09, Lottable10                                             
                                             ,Lottable11, Lottable12, Lottable13, Lottable14, Lottable15                                            
                                             ,UserDefine01, UserDefine02, UserDefine03, UserDefine04, Userdefine05
                                             ,UserDefine06, UserDefine07, UserDefine08, UserDefine09, Userdefine10, Facility             --(SOMA01)
                                             )
                     SELECT od.Orderkey, @c_OrderLineNoAlloc, od.Storerkey,@c_IDSku
                           ,ExternOrderkey, ExternLineNo, '', '','' 
                           ,@c_Packkey, @c_PackUOM3, @n_PickQty, @n_PickQty, @n_PickQty
                           ,Loadkey, MBOLKey
                           ,'', '', @c_IDLottable03, NULL, NULL                     --(SOMA01)
                           ,'', '', '', '', '' 
                           ,'', '', NULL,  NULL, NULL                                                
                           ,'0', @c_OrderLineNumber,'','',''
                           ,'', '', '', '', '' ,@c_Facility                        --(SOMA01)
                     FROM ORDERDETAIL od (NOLOCK)
                     WHERE Orderkey = @c_Orderkey
                     AND OrderLineNumber = @c_OrderLineNumber
                  END
               END                                                                  --(Wan01) - END

               IF @b_debug = 1
               BEGIN
                  SELECT @c_Lot as lot, @n_LotQtyAvai as lotqtyavai, @n_ExtraQty as extraqty, @n_PickQty as pickqty
               END
                                
               IF @n_PickQty > 0
               BEGIN                                        
                  SET @b_Success = 0
                  SET @c_PickDetailKey = ''
                     
                  EXEC nspg_GetKey
                     @KeyName = 'PickdetailKey',
                     @fieldlength = 10,
                     @keystring = @c_PickDetailKey OUTPUT,
                     @b_Success = @b_Success OUTPUT,
                     @n_err = @n_Err OUTPUT,
                     @c_errmsg = @c_ErrMsg OUTPUT,
                     @b_resultset = 1,
                     @n_batch = 1
                  
                  IF @b_Success = 1
                  BEGIN
                     INSERT INTO PICKDETAIL
                     (
                        PickDetailKey,          CaseID,               PickHeaderKey,
                        OrderKey,               OrderLineNumber,     Lot,
                        Storerkey,              Sku,                  AltSku,
                        UOM,                       UOMQty,               Qty,
                        QtyMoved,               [Status],            DropID,
                        Loc,                     ID,                   PackKey,
                        UpdateSource,           CartonGroup,         CartonType,
                        ToLoc,                   DoReplenish,         ReplenishZone,
                        DoCartonize,            PickMethod,          WaveKey,
                        ShipFlag,               PickSlipNo,          TaskDetailKey,
                        TaskManagerReasonKey,   Notes,                MoveRefKey,   
                        Trafficcop)
                     VALUES 
                      (@c_PickDetailKey,       '',                   '',
                        @c_OrderKey,            @c_OrderLineNoAlloc,  @c_LOT,       --(Wan01)
                        @c_StorerKey,           @c_IDSKU,                '',        --(Wan01)               
                        @c_UOM,                 @n_PickQty,              @n_PickQty,
                        0,                      '0',                  '',
                        @c_LOC,                 @c_ID,                @c_PackKey,
                        '0',                     'STD',               '',
                        '',                        'N',                  '',
                        'N',                     '',                    '',
                        'N',                     '',                    '',
                        '',                        '',                     '',
                        'U')
                        
                     SET @n_err = @@ERROR
                     
                     IF @n_err <> 0
                     BEGIN
                        SET @n_continue = 3
                        SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                        SET @n_err = 81030  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Failed. (ispPRJCB01)'
                                    + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
                     END
                  END  
                  IF @c_IDSku = @c_Sku                                              --(Wan01)
                  BEGIN
                     SET @n_QtyLeftToFulFill = @n_QtyLeftToFulFill - @n_PickQty 
                  END                                                               --(Wan01)
               END               
               
               FETCH FROM CUR_LOT INTO @c_Lot, @n_LotQtyAvai, @c_IDSku ,@c_IDLottable03              --(Wan01)(SOMA01)
            END
            CLOSE CUR_LOT
            DEALLOCATE CUR_LOT
                           
            FETCH FROM CUR_INV INTO @c_Loc, @c_ID, @n_IDQtyAvai              
         END
         CLOSE CUR_INV
         DEALLOCATE CUR_INV
           
         FETCH FROM CUR_ORDER_LINES INTO @c_StorerKey, @c_OrderKey, @c_OrderLineNumber, @c_SKU, @n_OpenQty, @c_Packkey, 
                                         @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08,
                                         @c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15, @c_Facility
      END
      CLOSE CUR_ORDER_LINES
      DEALLOCATE CUR_ORDER_LINES
   END                                
QUIT:

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPRJCB01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO