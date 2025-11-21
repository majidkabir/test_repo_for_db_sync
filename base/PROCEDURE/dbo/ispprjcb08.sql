SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure:  ispPRJCB08                                        */
/* Creation Date: 2024-10-09                                            */
/* Copyright: MAERSK Logistics                                          */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  UWP-24678 [FCR-805] [JCB] Allocation for Kitting and       */
/*           Decanting                                                  */
/*           Allocate Pallet with Exact Orderdetail.Qty. UOM 7.         */
/*           Order type = '2' Kitting CABS/LandPower order              */
/*                                                                      */
/*           set the sp to storerconfig PreAllocationSP                 */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* Version: V2                                                          */
/*                                                                      */
/* Data Modifications:                                                  */
/* Updates:                                                             */
/* Date        Author   Rev   Purposes                                  */
/* 2024-10-09  SSA01    1.1   UWP-24678-JCB- Allocation for Kitting and */
/*                                    Decanting                         */
/* 2024-11-07  SSA02    1.2   Updated to exclude pallets which used for */
/*                                      Kitting                         */
/* 2025-02-05  SKE140   1.3   UWP-29250 Updated condtion to exclude the */
/*                              JCB-ALLOC                               */
/************************************************************************/
CREATE   PROC [dbo].[ispPRJCB08] (
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

   DECLARE @n_Continue              INT = 1 
          ,@n_StartTCnt             INT = @@TRANCOUNT

   DECLARE @c_OrderLineNumber       NVARCHAR(5)    = ''
          ,@c_SKU                   NVARCHAR(20)   = ''
          ,@c_StorerKey             NVARCHAR(15)   = ''
          ,@c_Lottable01            NVARCHAR(18)   = ''
          ,@c_Lottable02            NVARCHAR(18)   = ''
          ,@c_Lottable03            NVARCHAR(18)   = ''
          ,@d_Lottable04            DATETIME
          ,@d_Lottable05            DATETIME
          ,@c_Lottable06            NVARCHAR(30)   = ''
          ,@c_Lottable07            NVARCHAR(30)   = ''
          ,@c_Lottable08            NVARCHAR(30)   = ''
          ,@c_Lottable09            NVARCHAR(30)   = ''
          ,@c_Lottable10            NVARCHAR(30)   = ''
          ,@c_Lottable11            NVARCHAR(30)   = ''
          ,@c_Lottable12            NVARCHAR(30)   = ''
          ,@d_Lottable13            DATETIME
          ,@d_Lottable14            DATETIME
          ,@d_Lottable15            DATETIME
          ,@c_Lottable04            NVARCHAR(30)   = ''
          ,@c_Lottable05            NVARCHAR(30)   = ''
          ,@c_Lottable13            NVARCHAR(30)   = ''
          ,@c_Lottable14            NVARCHAR(30)   = ''
          ,@c_Lottable15            NVARCHAR(30)   = ''
          ,@c_Lot                   NVARCHAR(10)   = ''
          ,@c_Loc                   NVARCHAR(10)   = ''
          ,@c_PickLoc               NVARCHAR(10)   = ''
          ,@c_ID                    NVARCHAR(18)   = ''
          ,@c_Facility              NVARCHAR(5)    = ''
          ,@c_PackKey               NVARCHAR(10)   = ''
          ,@c_UOM                   NVARCHAR(10)   = ''
          ,@c_SQL                   NVARCHAR(MAX)  = ''
          ,@c_SQLParm               NVARCHAR(MAX)  = ''
          ,@c_Conditions            NVARCHAR(MAX)  = ''
          ,@n_OpenQty               INT            = 0
          ,@n_PickQty               INT            = 0
          ,@n_QtyAvai               INT            = 0
          ,@n_QtyToAlloc            INT            = 0
          ,@n_CaseCnt               INT            = 0
          ,@n_CaseReq               INT            = 0
          ,@n_CaseAvai              INT            = 0
          ,@n_QtyLeftToFulfill      INT            = 0
          ,@c_PickDetailKey         NVARCHAR(10)   = ''
          ,@c_Type                  NVARCHAR(10)   = ''

          ,@CUR_ORDER_LINES         CURSOR
          ,@CUR_INV                 CURSOR   
          ,@CUR_OD                  CURSOR

   SET @b_Success = 1
   SET @n_Err     = 0
   SET @c_ErrMsg  = ''
   SET @c_UOM     = '7'
    --(SSA02) - Added condition to exclude pallet which used for K4 Kitting
   SET @c_Type = '2'
   SET @c_Conditions = ' AND LOC.LocationType = ''BULK'''
                     + ' AND PA.ZoneCategory  = ''EMG''' 
                     + ' AND NOT EXISTS(SELECT 1 FROM LOTXLOCXID L (NOLOCK) WHERE L.Storerkey = LLI.Storerkey      
                         AND L.Sku <> LLI.Sku AND L.Loc = LLI.Loc AND L.Id = LLI.Id AND L.Qty > 0) '
                     +'  AND NOT EXISTS(SELECT 1 FROM PICKDETAIL PD (NOLOCK)
			                   JOIN ORDERS O (NOLOCK) ON PD.ORDERKEY = O.ORDERKEY
										     JOIN LOTxLOCxID L (NOLOCK) ON PD.Storerkey = LLI.Storerkey
										     WHERE PD.ID = L.ID AND L.Storerkey = LLI.Storerkey AND L.ID =LLI.ID
                         AND O.Type = ''6'') '
                     + ' AND NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE LISTNAME = ''JCBEXALLOC''  AND CODE = @c_Type AND UDF01 = ''1'' AND LONG = LOC.Loc AND LONG IS NOT NULL)  '

 
                                             
   IF ISNULL(@c_Orderkey,'') <> ''
   BEGIN
      SET @n_Continue = 4
   END
   ELSE IF ISNULL(@c_Loadkey,'') <> ''
   BEGIN
      SET @CUR_ORDER_LINES = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT OD.StorerKey, OD.Sku
                     ,Openqty = SUM(OD.OpenQty - (OD.QtyAllocated + OD.QtyPicked))
                     ,SKU.Packkey
                     ,LOTTABLE01 = ISNULL(OD.LOTTABLE01,'')
                     ,LOTTABLE02 = ISNULL(OD.LOTTABLE02,'')
                     ,LOTTABLE03 = ISNULL(OD.LOTTABLE03,'')
                     ,LOTTABLE04 = ISNULL(OD.LOTTABLE04,'19000101') 
                     ,LOTTABLE05 = ISNULL(OD.LOTTABLE05,'19000101') 
                     ,LOTTABLE06 = ISNULL(OD.LOTTABLE06,'')
                     ,LOTTABLE07 = ISNULL(OD.LOTTABLE07,'')
                     ,LOTTABLE08 = ISNULL(OD.LOTTABLE08,'')
                     ,LOTTABLE09 = ISNULL(OD.LOTTABLE09,'')
                     ,LOTTABLE10 = ISNULL(OD.LOTTABLE10,'')
                     ,LOTTABLE11 = ISNULL(OD.LOTTABLE11,'')
                     ,LOTTABLE12 = ISNULL(OD.LOTTABLE12,'')
                     ,LOTTABLE13 = ISNULL(OD.LOTTABLE13,'19000101')
                     ,LOTTABLE14 = ISNULL(OD.LOTTABLE14,'19000101')
                     ,LOTTABLE15 = ISNULL(OD.LOTTABLE15,'19000101')
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
      AND SKU.BUSR7 <> '1'
      GROUP BY OD.StorerKey, OD.Sku
            ,  SKU.Packkey
            ,  ISNULL(OD.LOTTABLE01,'')
            ,  ISNULL(OD.LOTTABLE02,'')
            ,  ISNULL(OD.LOTTABLE03,'')
            ,  ISNULL(OD.LOTTABLE04,'19000101') 
            ,  ISNULL(OD.LOTTABLE05,'19000101') 
            ,  ISNULL(OD.LOTTABLE06,'')
            ,  ISNULL(OD.LOTTABLE07,'')
            ,  ISNULL(OD.LOTTABLE08,'')
            ,  ISNULL(OD.LOTTABLE09,'')
            ,  ISNULL(OD.LOTTABLE10,'')
            ,  ISNULL(OD.LOTTABLE11,'')
            ,  ISNULL(OD.LOTTABLE12,'')
            ,  ISNULL(OD.LOTTABLE13,'19000101')
            ,  ISNULL(OD.LOTTABLE14,'19000101')
            ,  ISNULL(OD.LOTTABLE15,'19000101')
            ,  O.Facility
      ORDER BY OD.Storerkey, OD.Sku
   END
   ELSE IF ISNULL(@c_Wavekey,'') <> ''
   BEGIN
      SET @CUR_ORDER_LINES = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT OD.StorerKey, OD.Sku
                     ,OpenQty = SUM(OD.OpenQty - (OD.QtyAllocated + OD.QtyPicked))
                     ,SKU.Packkey
                     ,LOTTABLE01 = ISNULL(OD.LOTTABLE01,'')
                     ,LOTTABLE02 = ISNULL(OD.LOTTABLE02,'')
                     ,LOTTABLE03 = ISNULL(OD.LOTTABLE03,'')
                     ,LOTTABLE04 = ISNULL(OD.LOTTABLE04,'19000101') 
                     ,LOTTABLE05 = ISNULL(OD.LOTTABLE05,'19000101') 
                     ,LOTTABLE06 = ISNULL(OD.LOTTABLE06,'')
                     ,LOTTABLE07 = ISNULL(OD.LOTTABLE07,'')
                     ,LOTTABLE08 = ISNULL(OD.LOTTABLE08,'')
                     ,LOTTABLE09 = ISNULL(OD.LOTTABLE09,'')
                     ,LOTTABLE10 = ISNULL(OD.LOTTABLE10,'')
                     ,LOTTABLE11 = ISNULL(OD.LOTTABLE11,'')
                     ,LOTTABLE12 = ISNULL(OD.LOTTABLE12,'')
                     ,LOTTABLE13 = ISNULL(OD.LOTTABLE13,'19000101')
                     ,LOTTABLE14 = ISNULL(OD.LOTTABLE14,'19000101')
                     ,LOTTABLE15 = ISNULL(OD.LOTTABLE15,'19000101')
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
      AND o.Type = @c_Type 
      AND SKU.BUSR7 <> '1'
      GROUP BY OD.StorerKey, OD.Sku
            ,  SKU.Packkey
            ,  ISNULL(OD.LOTTABLE01,'')
            ,  ISNULL(OD.LOTTABLE02,'')
            ,  ISNULL(OD.LOTTABLE03,'')
            ,  ISNULL(OD.LOTTABLE04,'19000101') 
            ,  ISNULL(OD.LOTTABLE05,'19000101') 
            ,  ISNULL(OD.LOTTABLE06,'')
            ,  ISNULL(OD.LOTTABLE07,'')
            ,  ISNULL(OD.LOTTABLE08,'')
            ,  ISNULL(OD.LOTTABLE09,'')
            ,  ISNULL(OD.LOTTABLE10,'')
            ,  ISNULL(OD.LOTTABLE11,'')
            ,  ISNULL(OD.LOTTABLE12,'')
            ,  ISNULL(OD.LOTTABLE13,'19000101')
            ,  ISNULL(OD.LOTTABLE14,'19000101')
            ,  ISNULL(OD.LOTTABLE15,'19000101')
            ,  O.Facility
      ORDER BY OD.Storerkey, OD.Sku
   END
   IF @n_continue IN(1,2)
   BEGIN
     OPEN @CUR_ORDER_LINES

     FETCH FROM @CUR_ORDER_LINES INTO @c_StorerKey, @c_SKU, @n_OpenQty, @c_Packkey
                                    , @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05
                                    , @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10
                                    , @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
                                    , @c_Facility

     WHILE @@FETCH_STATUS = 0 AND @n_Continue IN(1,2)
     BEGIN
        SET @n_QtyLeftToFulfill = @n_OpenQty

        SET @c_PickLoc = ''
        --(SSA03)
        SET @c_SQL = N'SELECT TOP 1 @c_PickLoc = SL.Loc'
                   + ' FROM SKUXLOC SL (NOLOCK)'
                   + ' JOIN LOC (NOLOCK) ON SL.Loc = LOC.Loc'
                   + ' OUTER APPLY (SELECT TOP 1 PD.LOC'
                   +              ' FROM PICKDETAIL PD (NOLOCK)'
                   +   CASE  WHEN ISNULL(@c_Loadkey,'') <> ''
                             THEN ' JOIN LOADPLANDETEAIl lpd (NOLOCK) ON lpd.Orderkey = pd.Orderkey'
                             WHEN ISNULL(@c_Wavekey,'') <> ''
                             THEN ' JOIN WAVEDETAIL wd (NOLOCK) ON wd.Orderkey = pd.Orderkey'
                             END
                   +              ' WHERE PD.Loc = SL.Loc'
                   +              ' AND PD.Storerkey = SL.Storerkey'
                   +              ' AND PD.Sku = SL.Sku'
                   +   CASE  WHEN ISNULL(@c_Loadkey,'') <> ''
                             THEN ' AND lpd.Loadkey = @c_Loadkey'
                             WHEN ISNULL(@c_Wavekey,'') <> ''
                             THEN ' AND wd.Wavekey = @c_Wavekey'
                             END
                   +              ' ) OP'
                   + ' WHERE LOC.Facility = @c_Facility'
                   + ' AND SL.Storerkey = @c_Storerkey'
                   + ' AND SL.Sku = @c_Sku'
                   + ' AND LOC.LocationType = ''PICK'''
                   + ' AND SL.LocationType IN (''PICK'',''CASE'')'

                   + ' ORDER BY CASE WHEN OP.Loc IS NOT NULL THEN 1 ELSE 2 END'
                   +         ', SL.Qty, LOC.LogicalLocation, LOC.Loc'

        SET @c_SQLParm = N'@c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10)'
                       +' ,@c_StorerKey NVARCHAR(15), @c_SKU NVARCHAR(20), @c_Facility NVARCHAR(5)'
                       +' ,@c_PickLoc NVARCHAR(10) OUTPUT'

        EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm
           , @c_Loadkey, @c_Wavekey
           , @c_StorerKey, @c_SKU, @c_Facility
           , @c_PickLoc OUTPUT

        IF ISNULL(@c_PickLoc,'') = ''
        BEGIN
           SET @n_continue = 3
           SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
           SET @n_err = 81010  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Pick Loc not found for Sku: ' + RTRIM(@c_Sku) + '. (ispPRJCB08)'
                       + '( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
           BREAK
        END

        IF @b_debug = 1
        BEGIN
           SELECT @c_OrderKey as orderkey, @c_OrderLineNumber as orderlinenumber, @c_SKU as sku, @n_OpenQty as openqty, @c_PickLoc AS PickLoc
        END

        SET @c_SQL = N'SET @CUR_INV = CURSOR FAST_FORWARD READ_ONLY FOR
           SELECT LLI.Lot, LLI.Loc, LLI.ID,
                 (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen - ISNULL(REPLEN.ReplenQty,0))
           FROM LOTxLOCxID LLI (NOLOCK)
           JOIN LOC (NOLOCK) ON (LLI.Loc = LOC.LOC)
           JOIN ID (NOLOCK) ON (LLI.Id = ID.ID)
           JOIN LOT (NOLOCK) ON (LLI.LOT = LOT.LOT)
           JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT
           JOIN SKUXLOC SL (NOLOCK) ON (LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc)
           JOIN SKU (NOLOCK) ON (LLI.Storerkey = Sku.Storerkey AND LLI.Sku = Sku.Sku)
           JOIN PUTAWAYZONE pa (NOLOCK) ON loc.Putawayzone = pa.Putawayzone
           OUTER APPLY (SELECT SUM(PD.Qty) AS RePlenQty
                          FROM PICKDETAIL PD (NOLOCK)
                          WHERE PD.Storerkey = LLI.Storerkey
                          AND PD.Sku = LLI.Sku
                          AND PD.Lot = LLI.Lot
                          AND PD.ToLoc = LLI.Loc
                          AND PD.CaseID = LLI.Id
                          AND PD.Status = ''0'') AS REPLEN
           WHERE LOC.LocationFlag = ''NONE''
           AND LOC.Status = ''OK''
           AND LOT.Status = ''OK''
           AND ID.Status = ''OK''
           AND LOC.Facility = @c_Facility
           AND (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen - ISNULL(REPLEN.ReplenQty,0)) > 0
           AND LLI.STORERKEY = @c_StorerKey
           AND LLI.SKU = @c_SKU ' +
           RTRIM(@c_Conditions) + ' ' +
           CASE WHEN ISNULL(@c_Lottable01,'') <> '' THEN ' AND LA.Lottable01 = @c_Lottable01 ' ELSE '' END +
           CASE WHEN ISNULL(@c_Lottable02,'') <> '' THEN ' AND LA.Lottable02 = @c_Lottable02 ' ELSE '' END +
           CASE WHEN ISNULL(@c_Lottable03,'') <> '' THEN ' AND LA.Lottable03 = @c_Lottable03 ' ELSE '' END +
           CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101'
                THEN ' AND LA.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) ' ELSE ' ' END +
           CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101'
                THEN ' AND LA.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) ' ELSE ' ' END +
           CASE WHEN ISNULL(@c_Lottable06,'') <> '' THEN ' AND LA.Lottable06 = @c_Lottable06 ' ELSE '' END +
           CASE WHEN ISNULL(@c_Lottable07,'') <> '' THEN ' AND LA.Lottable07 = @c_Lottable07 ' ELSE '' END +
           CASE WHEN ISNULL(@c_Lottable08,'') <> '' THEN ' AND LA.Lottable08 = @c_Lottable08 ' ELSE '' END +
           CASE WHEN ISNULL(@c_Lottable09,'') <> '' THEN ' AND LA.Lottable09 = @c_Lottable09 ' ELSE '' END +
           CASE WHEN ISNULL(@c_Lottable10,'') <> '' THEN ' AND LA.Lottable10 = @c_Lottable10 ' ELSE '' END +
           CASE WHEN ISNULL(@c_Lottable11,'') <> '' THEN ' AND LA.Lottable11 = @c_Lottable11 ' ELSE '' END +
           CASE WHEN ISNULL(@c_Lottable12,'') <> '' THEN ' AND LA.Lottable12 = @c_Lottable12 ' ELSE '' END +
           CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101'
                THEN ' AND LA.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) ' ELSE ' ' END +
           CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101'
                THEN ' AND LA.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) ' ELSE ' ' END +
           CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101'
                THEN ' AND LA.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) ' ELSE ' ' END +
           ' ORDER BY LA.Lottable05, LOC.LogicalLocation, LLI.Loc;
             OPEN @CUR_INV'

        SET @c_SQLParm =  N'@c_StorerKey NVARCHAR(15), @c_SKU NVARCHAR(20), @c_Facility NVARCHAR(5), @c_Type NVARCHAR(10)'
                       + ', @c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME'
                       + ', @c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30)'
                       + ', @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME '
                       + ', @CUR_INV CURSOR OUTPUT'

        EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm
              ,  @c_StorerKey, @c_SKU, @c_Facility ,@c_Type
              ,  @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05
              ,  @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10
              ,  @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
              ,  @CUR_INV OUTPUT



        FETCH FROM @CUR_INV INTO @c_Lot, @c_Loc, @c_ID, @n_QtyAvai

        WHILE @@FETCH_STATUS = 0 AND @n_Continue IN(1,2) AND @n_QtyLeftToFulFill > 0
        BEGIN
           IF @b_debug = 1
           BEGIN
              SELECT @c_Loc as loc, @c_ID as id, @n_QtyAvai as qtyavai, @n_QtyLeftToFulFill as qtylefttofulfill
           END

           SET @c_SQL= N'SET @CUR_OD = CURSOR FAST_FORWARD READ_ONLY FOR'
                     + ' SELECT od.OrderKey, od.OrderlineNumber'
                     + ',QtyToAlloc = od.Openqty - od.Qtyallocated - od.qtypicked'
                     + ' FROM ORDERDETAIL od (NOLOCK)'
                     + CASE WHEN ISNULL(@c_Loadkey,'') <> ''
                            THEN ' JOIN LOADPLANDETEAIl lpd (NOLOCK) ON lpd.Orderkey = od.Orderkey'
                            WHEN ISNULL(@c_Wavekey,'') <> ''
                            THEN ' JOIN WAVEDETAIL wd (NOLOCK) ON wd.Orderkey = od.Orderkey'
                            END
                     + ' WHERE od.Storerkey  = @c_Storerkey'
                     + ' AND   od.Sku  = @c_Sku'
                     + ' AND   od.Openqty - od.Qtyallocated - od.qtypicked > 0'
                     + CASE WHEN ISNULL(@c_Loadkey,'') <> ''
                            THEN ' AND lpd.Loadkey = @c_Loadkey'
                            WHEN ISNULL(@c_Wavekey,'') <> ''
                            THEN ' AND wd.Wavekey = @c_Wavekey'
                            END
                     +  CASE WHEN ISNULL(@c_Lottable01,'') <> ''
                             THEN ' AND od.Lottable01 = @c_Lottable01 ' ELSE '' END
                     +  CASE WHEN ISNULL(@c_Lottable02,'') <> ''
                             THEN ' AND od.Lottable02 = @c_Lottable02 ' ELSE '' END
                     +  CASE WHEN ISNULL(@c_Lottable03,'') <> ''
                             THEN ' AND od.Lottable03 = @c_Lottable03 ' ELSE '' END
                     +  CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable04 ,112) <> '19000101'
                             THEN ' AND od.Lottable04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) '
                             ELSE ' ' END
                     +  CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable05 ,112) <> '19000101'
                             THEN ' AND od.Lottable05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) '
                             ELSE ' ' END
                     +  CASE WHEN ISNULL(@c_Lottable06,'') <> ''
                             THEN ' AND od.Lottable06 = @c_Lottable06 ' ELSE '' END
                     +  CASE WHEN ISNULL(@c_Lottable07,'') <> ''
                             THEN ' AND od.Lottable07 = @c_Lottable07 ' ELSE '' END
                     +  CASE WHEN ISNULL(@c_Lottable08,'') <> ''
                             THEN ' AND od.Lottable08 = @c_Lottable08 ' ELSE '' END
                     +  CASE WHEN ISNULL(@c_Lottable09,'') <> ''
                             THEN ' AND od.Lottable09 = @c_Lottable09 ' ELSE '' END
                     +  CASE WHEN ISNULL(@c_Lottable10,'') <> ''
                             THEN ' AND od.Lottable10 = @c_Lottable10 ' ELSE '' END
                     +  CASE WHEN ISNULL(@c_Lottable11,'') <> ''
                             THEN ' AND od.Lottable11 = @c_Lottable11 ' ELSE '' END +
                     +  CASE WHEN ISNULL(@c_Lottable12,'') <> ''
                             THEN ' AND od.Lottable12 = @c_Lottable12 ' ELSE '' END +
                     +  CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable13 ,112) <> '19000101'
                             THEN ' AND od.Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) '
                             ELSE ' ' END +
                     +  CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable14 ,112) <> '19000101'
                             THEN ' AND od.Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) '
                             ELSE ' ' END +
                     +  CASE WHEN CONVERT(NVARCHAR(8) ,@d_Lottable15 ,112) <> '19000101'
                             THEN ' AND od.Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) '
                             ELSE ' ' END
                     + ' ORDER BY od.Orderkey, od.Orderlinenumber; OPEN @CUR_OD'

           SET @c_SQLParm = N'@c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10)'
                          +' ,@c_StorerKey NVARCHAR(15), @c_SKU NVARCHAR(20), @c_Facility NVARCHAR(5),  @c_Type NVARCHAR(10)'
                          +' ,@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME'
                          +' ,@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30)'
                          +' ,@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME'
                          +' ,@CUR_OD CURSOR OUTPUT'

           EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm
              , @c_Loadkey, @c_Wavekey
              , @c_StorerKey, @c_SKU, @c_Facility , @c_Type
              , @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05
              , @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10
              , @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
              , @CUR_OD OUTPUT

           FETCH FROM @CUR_OD INTO @c_Orderkey, @c_OrderLineNumber, @n_QtyToAlloc

           WHILE @@FETCH_STATUS = 0 AND @n_Continue IN(1,2) AND @n_QtyAvai > 0
           BEGIN
              IF @n_QtyAvai <= @n_QtyToAlloc
              BEGIN
                 SET @n_PickQty = @n_QtyAvai
              END
              ELSE
              BEGIN
                 SET @n_PickQty = @n_QtyToAlloc
              END

              IF @n_PickQty > 0
              BEGIN
                 SET @b_Success = 0
                 SET @c_PickDetailKey = ''

                 IF NOT EXISTS(SELECT 1 FROM LOTXLOCXID (NOLOCK) WHERE lot = @c_Lot AND loc = @c_PickLoc AND Id = '')
                 BEGIN
                    INSERT INTO LOTXLOCXID (Storerkey, Sku, Lot, Loc, Id, Qty)
                    VALUES (@c_Storerkey, @c_Sku, @c_Lot, @c_PickLoc, ''  , 0)

                    SELECT @n_err = @@ERROR

                    IF @n_err <> 0
                    BEGIN
                       SET @n_continue = 3
                       SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                       SET @n_err = 81040  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                       SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Lotxlocxid Table Failed. (ispPRJCB08)'
                             + '( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
                    END
                 END

                 IF NOT EXISTS(SELECT 1 FROM SKUXLOC (NOLOCK) WHERE Storerkey = @c_Storerkey AND Sku = @c_Sku AND loc = @c_PickLoc)
                 BEGIN
                    INSERT INTO SKUXLOC (Storerkey, Sku, Loc, Qty)
                    VALUES (@c_Storerkey, @c_Sku, @c_PickLoc, 0)

                    SELECT @n_err = @@ERROR

                    IF @n_err <> 0
                    BEGIN
                       SET @n_continue = 3
                       SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                       SET @n_err = 81050  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                       SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert SkuxLoc Table Failed. (ispPRJCB08)'
                                + '( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
                    END
                 END

                 IF @n_Continue IN(1,2)
                 BEGIN
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
                       PickDetailKey,          CaseID,              PickHeaderKey,
                       OrderKey,               OrderLineNumber,     Lot,
                       Storerkey,              Sku,                 AltSku,
                       UOM,                    UOMQty,              Qty,
                       QtyMoved,               [Status],            DropID,
                       Loc,                    ID,                  PackKey,
                       UpdateSource,           CartonGroup,         CartonType,
                       ToLoc,                  DoReplenish,         ReplenishZone,
                       DoCartonize,            PickMethod,          WaveKey,
                       ShipFlag,               PickSlipNo,          TaskDetailKey,
                       TaskManagerReasonKey,   Notes,               MoveRefKey,
                       Trafficcop)
                       VALUES
                       (@c_PickDetailKey,      @c_ID,               '',         --caseid as id from bulk
                       @c_OrderKey,            @c_OrderLineNumber,  @c_LOT,
                       @c_StorerKey,           @c_SKU,              '',
                       @c_UOM,                 @n_PickQty,          @n_PickQty,
                       0,                      '0',                 '',
                       @c_PickLoc,             '',                  @c_PackKey, --loose ID for pick loc
                       '0',                    'STD',               '',
                       @c_Loc,                 'N',                 '',         --toloc as loc from bulk
                       'N',                    '',                  '',
                       'N',                    '',                  '',
                       '',                     '',                  '',
                       'U')

                       SET @n_err = @@ERROR

                       IF @n_err <> 0
                       BEGIN
                          SET @n_continue = 3
                          SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                          SET @n_err = 81060  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                          SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Failed. (ispPRJCB08)'
                                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
                       END

                       SET @n_QtyAvai = @n_QtyAvai -  @n_PickQty
                       SET @n_QtyLeftToFulFill = @n_QtyLeftToFulFill - @n_PickQty
                    END
                 END
              END
              FETCH FROM @CUR_OD INTO @c_Orderkey, @c_OrderLineNumber, @n_QtyToAlloc
           END
           CLOSE @CUR_OD
           DEALLOCATE @CUR_OD

           NEXT_LLI:

           FETCH FROM @CUR_INV INTO @c_Lot, @c_Loc, @c_ID, @n_QtyAvai
        END
        CLOSE @CUR_INV
        DEALLOCATE @CUR_INV

        FETCH FROM @CUR_ORDER_LINES INTO @c_StorerKey, @c_SKU, @n_OpenQty, @c_Packkey
                                       , @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05
                                       , @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10
                                       , @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
                                       , @c_Facility
     END
     CLOSE @CUR_ORDER_LINES
     DEALLOCATE @CUR_ORDER_LINES
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPRJCB08'
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