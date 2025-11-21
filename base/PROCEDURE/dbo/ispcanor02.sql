SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispCANOR02                                         */
/* Creation Date: 13-Jul-2020                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-14053 [RG] [KR] Levis B2B Post Cancel Auto Move (Exceed)*/   
/*                                                                      */
/* Called By: isp_OrderCancel_Wrapper from Orders Update Trigger        */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */ 
/* 9/8/21       ian      INC1583102 Support id with >10 , <19 character */    
/************************************************************************/

CREATE PROC [dbo].[ispCANOR02]   
   @c_Orderkey      NVARCHAR(10),  
   @b_Success       INT           OUTPUT,
   @n_Err           INT           OUTPUT, 
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue     INT,
           @n_StartTCnt    INT
                                             
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
	
   DECLARE @c_OrderLineNumber    NVARCHAR(5)
         , @c_SKU                NVARCHAR(30)
         , @c_OriginalQty        INT
         , @c_OpenQty            INT
         , @c_ShippedQty         INT
         
         , @c_BlockLocation      NVARCHAR(50)
         , @n_OrdDetQty          INT
         , @n_LotLocIDQty        INT
         , @n_SumLotLocIDQty     INT
         , @c_Lot                NVARCHAR(10)
         , @c_Loc                NVARCHAR(10)
         , @c_ID                 NVARCHAR(18) --ian        INC1583102
         , @c_FromLoc            NVARCHAR(10)
         , @c_ToLoc              NVARCHAR(10)
         , @c_Packkey            NVARCHAR(10)
         , @c_UOM                NVARCHAR(10)
         , @c_sourcekey          NVARCHAR(20)
         , @n_QtyLeftToFulfill   INT
         , @n_QtyAvailable       INT
         , @c_Storerkey          NVARCHAR(15)

   SET @b_Success= 1
   SET @n_Err    = 0
   SET @c_ErrMsg = ''
   SET @n_Continue = 1
   SET @n_StartTCnt = @@TRANCOUNT
   SET @c_sourcekey     = ''

   --Get Storerkey
   IF(@n_Continue = 1 or @n_Continue = 2)
   BEGIN
      SELECT @c_Storerkey = Storerkey
      FROM ORDERS (NOLOCK)
      WHERE Orderkey = @c_Orderkey
   END

   --Find FromLoc and ToLoc
   IF(@n_Continue = 1 or @n_Continue = 2)
   BEGIN
      SELECT @c_FromLoc = ISNULL(Long,'')
           , @c_ToLoc   = ISNULL(Short,'')
      FROM CODELKUP (NOLOCK)
      WHERE LISTNAME = 'LEVTOLOC' AND CODE = 'AUTOMOVE'

      IF (ISNULL(@c_FromLoc,'') = '' OR ISNULL(@c_ToLoc,'') = '')
      BEGIN
         SELECT @n_Continue = 3 
         SELECT @n_Err = 38002
         SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Codelkup FromLoc OR ToLoc is empty or NULL. (ispCANOR02)'
         GOTO QUIT_SP 
      END
   END

   --Main Process
   IF(@n_Continue = 1 or @n_Continue = 2)
   BEGIN
      --Cursor to find OpenQTY as @n_QtyLeftToFulfill
      DECLARE CURSOR_QTY CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT OH.Storerkey, OH.Orderkey, OD.OrderLineNumber, OD.SKU, SUM(OD.OpenQty)
      FROM ORDERS     OH WITH (NOLOCK)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
      WHERE OH.OrderKey  = @c_Orderkey
      AND   OH.Storerkey = @c_Storerkey
      AND   OD.OpenQTY > 0
      AND   OH.Doctype = 'N'
      GROUP BY OH.Storerkey, OH.Orderkey, OD.OrderLineNumber, OD.SKU

      OPEN CURSOR_QTY

      FETCH NEXT FROM CURSOR_QTY INTO @c_Storerkey, @c_Orderkey,@c_OrderLineNumber, @c_sku, @n_QtyLeftToFulfill

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         SELECT @c_PackKey = SKU.PackKey
              , @c_UOM     = PACK.PACKUOM3
         FROM SKU (NOLOCK)
         JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
         WHERE SKU.SKU = @c_SKU

         SET @c_sourcekey = @c_Orderkey + @c_OrderLineNumber
   
         --Nested cursor to find QtyAvailable from LotxLocxID
         DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT LOTxLOCxID.LOT,
                LOTxLOCxID.LOC,
                LOTxLOCxID.ID,
                QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN)
         FROM LOTxLOCxID (NOLOCK)
         JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
         JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
         JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT)
         JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT
         JOIN SKUXLOC SL (NOLOCK) ON (LOTxLOCxID.Storerkey = SL.Storerkey AND LOTxLOCxID.Sku = SL.Sku AND LOTxLOCxID.Loc = SL.Loc)
         WHERE -- LOC.LocationFlag <> 'HOLD' 
         -- AND LOC.LocationFlag <> 'DAMAGE' 
         -- AND LOC.Status <> 'HOLD'         
         -- AND LOT.Status <> 'HOLD'         
         -- AND ID.Status <> 'HOLD'          
         -- AND LOC.Facility = @c_Facility
         -- AND                              
         (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen + LOTxLOCxID.PendingMoveIN) > 0
         AND LOTxLOCxID.STORERKEY = @c_StorerKey
         AND LOTxLOCxID.SKU = @c_SKU
         AND LOC.HOSTWHCODE = 'U'
         AND LOTxLOCxID.LOC = @c_FromLoc
   
         OPEN CURSOR_AVAILABLE
   
         FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable
   
         WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)
         BEGIN
            IF(@n_QtyLeftToFulfill <= @n_QtyAvailable) --If OpenQty < LotxLocxID.Qty, just take the OpenQty
            BEGIN
               SET @n_QtyAvailable = @n_QtyLeftToFulfill
               SET @n_QtyLeftToFulfill = 0
            END
            ELSE
            BEGIN
               SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyAvailable
            END
   
            IF(@n_Continue = 1 or @n_Continue = 2)
            BEGIN
               EXECUTE nspItrnAddMove
                  @n_ItrnSysId      = NULL,
                  @c_itrnkey        = NULL,
                  @c_Storerkey      = @c_StorerKey,
                  @c_SKU            = @c_SKU,
                  @c_Lot            = @c_Lot,
                  @c_FromLoc        = @c_Loc,
                  @c_FromID         = @c_ID,
                  @c_ToLoc          = @c_ToLoc,
                  @c_ToID           = @c_ID,
                  @c_Status         = '',
                  @c_Lottable01     = '',
                  @c_Lottable02     = '',
                  @c_Lottable03     = '',
                  @d_Lottable04     = NULL,
                  @d_Lottable05     = NULL,
                  @c_Lottable06     = '',          
                  @c_Lottable07     = '',          
                  @c_Lottable08     = '',          
                  @c_Lottable09     = '',          
                  @c_Lottable10     = '',          
                  @c_Lottable11     = '',          
                  @c_Lottable12     = '',          
                  @d_Lottable13     = NULL,        
                  @d_Lottable14     = NULL,        
                  @d_Lottable15     = NULL,        
                  @n_casecnt        = 0,
                  @n_innerpack      = 0,
                  @n_Qty            = @n_QtyAvailable,
                  @n_Pallet         = 0,
                  @f_Cube           = 0,
                  @f_GrossWgt       = 0,
                  @f_NetWgt         = 0,
                  @f_OtherUnit1     = 0,
                  @f_OtherUnit2     = 0,
                  @c_SourceKey      = @c_sourcekey,
                  @c_SourceType     = 'ispCANOR02',
                  @c_PackKey        = @c_PackKey,
                  @c_UOM            = @c_UOM,
                  @b_UOMCalc        = 1,
                  @d_EffectiveDate  = NULL,
                  @b_Success        = @b_Success   OUTPUT,
                  @n_err            = @n_Err       OUTPUT,
                  @c_errmsg         = @c_Errmsg    OUTPUT
   
               IF @b_Success <> 1
               BEGIN
                  SELECT @n_Continue = 3
                  GOTO QUIT_SP
               END
            END
   
            FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable
         END
         CLOSE CURSOR_AVAILABLE
         DEALLOCATE CURSOR_AVAILABLE
         --Nested cursor to find QtyAvailable from LotxLocxID
         FETCH NEXT FROM CURSOR_QTY INTO @c_Storerkey, @c_Orderkey,@c_OrderLineNumber, @c_sku, @n_QtyLeftToFulfill
      END
      CLOSE CURSOR_QTY
      DEALLOCATE CURSOR_QTY
      --Cursor to find OpenQTY as @n_QtyLeftToFulfill
   END
   --Main Process End

   SET @n_Err = @@ERROR
	                    
   IF @n_Err <> 0
   BEGIN
      SELECT @n_Continue = 3 
      SELECT @n_Err = 38002
      SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update Taskdetail Failed. (ispCANOR02)'
      GOTO QUIT_SP 
   END   
      
QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process AND Return
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispCANOR02'		
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
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