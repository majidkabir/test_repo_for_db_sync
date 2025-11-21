SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispSHPMO05                                            */
/* Creation Date: 10-JAN-2019                                              */
/* Copyright: IDS                                                          */
/* Written by:  WLCHOOI                                                    */
/*                                                                         */
/* Purpose: WMS-7390 - [RG] LevisB2B - Exceed - Post MBOL Auto Move        */
/*        :                                                                */
/*                                                                         */
/* Called By: ispPostMBOLShipWrapper                                       */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 10-JUL-2019  WLChooi 1.1   Remove filter HOLD loc (WL01)                */
/* 29-AUG-2019  NIKJIAN 1.2   INC0823719 - Filter ShortPick logic (nik01)  */
/***************************************************************************/
CREATE PROC [dbo].[ispSHPMO05]
(     @c_MBOLkey     NVARCHAR(10)
  ,   @c_Storerkey   NVARCHAR(15)
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Debug              INT
         , @n_Continue           INT
         , @n_StartTCnt          INT

   DECLARE @n_PStatusCnt         INT
         , @n_PLoadStatusCnt     INT

         , @c_Orderkey           NVARCHAR(10)
         , @c_OrderLineNumber    NVARCHAR(5)
         , @c_SKU                NVARCHAR(30)
         , @c_OriginalQty        INT
         , @c_OpenQty            INT
         , @c_ShippedQty         INT


         , @c_PLoadKey           NVARCHAR(10)
         , @c_PLoadStatus        NVARCHAR(10)

         , @c_BlockLocation       NVARCHAR(50)
         , @n_OrdDetQty			  INT
         , @n_LotLocIDQty         INT
         , @n_SumLotLocIDQty      INT
         , @c_Lot          NVARCHAR(10)
         , @c_Loc          NVARCHAR(10)
         , @c_ID           NVARCHAR(10)
         , @c_FromLoc      NVARCHAR(10)
         , @c_ToLoc        NVARCHAR(10)
         , @c_Packkey      NVARCHAR(10)
         , @c_UOM          NVARCHAR(10)
         , @c_sourcekey    NVARCHAR(20)
         , @n_QtyLeftToFulfill INT
         , @n_QtyAvailable INT

   SET @b_Success= 1
   SET @n_Err    = 0
   SET @c_ErrMsg = ''
   SET @b_Debug = '1'
   SET @n_Continue = 1
   SET @n_StartTCnt = @@TRANCOUNT

   SET @n_PStatusCnt    = 0
   SET @n_PLoadStatusCnt= 0
   SET @c_PLoadKey      = ''
   SET @c_PLoadStatus   = ''
   SET @c_sourcekey     = ''

   --Find FromLoc and ToLoc
   IF(@n_Continue = 1 or @n_Continue = 2)
   BEGIN
   SELECT @c_FromLoc = ISNULL(Long,'')
         ,@c_ToLoc   = ISNULL(Short,'')
   FROM CODELKUP (NOLOCK)
   WHERE LISTNAME = 'LEVTOLOC' AND CODE = 'AUTOMOVE'
   END

   --Main Process
   IF(@n_Continue = 1 or @n_Continue = 2)
   BEGIN
    --Cursor to find OpenQTY as @n_QtyLeftToFulfill
   DECLARE CURSOR_QTY CURSOR FAST_FORWARD READ_ONLY FOR
	   SELECT DISTINCT OH.Storerkey, OH.Orderkey, OD.OrderLineNumber,OD.SKU, (OD.OPENQTY-OD.QTYALLOCATED-OD.QTYPICKED-OD.SHIPPEDQTY) --(nik01)
	   FROM MBOLDETAIL MD WITH (NOLOCK)
	   JOIN ORDERS     OH WITH (NOLOCK) ON (MD.Orderkey = OH.Orderkey)
	   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
	   WHERE MD.MBOLKey   = @c_MBOLkey
	   AND   OH.Storerkey = @c_Storerkey
	  -- AND   OD.OpenQTY <> 0--(nik01)
	  AND (OD.OPENQTY-OD.QTYALLOCATED-OD.QTYPICKED-OD.SHIPPEDQTY) >0   --(nik01)
	  AND   OH.Doctype = 'N'

   OPEN CURSOR_QTY

   FETCH NEXT FROM CURSOR_QTY INTO @c_Storerkey, @c_Orderkey,@c_OrderLineNumber, @c_sku, @n_QtyLeftToFulfill

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN

   SELECT @c_PackKey = SKU.PackKey
		,@c_UOM = PACK.PACKUOM3
   FROM SKU (NOLOCK)
   JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
   WHERE SKU.SKU = @c_SKU

   SET @c_sourcekey = @c_Orderkey+@c_OrderLineNumber

   --Nested cursor to find QtyAvailable from LotxLocxID
   DECLARE CURSOR_AVAILABLE CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT LOTxLOCxID.LOT,
             LOTxLOCxID.LOC,
             LOTxLOCxID.ID,
             QTYAVAILABLE = (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen)
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
      JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
      JOIN LOT (NOLOCK) ON (LOTXLOCXID.LOT = LOT.LOT)
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.LOT = LA.LOT
      JOIN SKUXLOC SL (NOLOCK) ON (LOTxLOCxID.Storerkey = SL.Storerkey AND LOTxLOCxID.Sku = SL.Sku AND LOTxLOCxID.Loc = SL.Loc)
      WHERE -- LOC.LocationFlag <> 'HOLD'  --WL01
     -- AND LOC.LocationFlag <> 'DAMAGE'   --WL01
     -- AND LOC.Status <> 'HOLD'           --WL01
     -- AND LOT.Status <> 'HOLD'           --WL01
     -- AND ID.Status <> 'HOLD'            --WL01
     -- AND LOC.Facility = @c_Facility
     -- AND                                --WL01
     (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QtyReplen) > 0
      AND LOTxLOCxID.STORERKEY = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU
      AND LOC.HOSTWHCODE = 'U'
      AND LOTxLOCxID.LOC = @c_FromLoc

   OPEN CURSOR_AVAILABLE

   FETCH NEXT FROM CURSOR_AVAILABLE INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable

   WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)
   BEGIN
		IF(@n_QtyLeftToFulfill < @n_QtyAvailable) --If OpenQty < LotxLocxID.Qty, just take the OpenQty
		BEGIN
			SET @n_QtyAvailable = @n_QtyLeftToFulfill
			SET @n_QtyLeftToFulfill = 0
		END
		ELSE
			SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyAvailable

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
      @c_Lottable06     = '',              --(CS01)
      @c_Lottable07     = '',              --(CS01)
      @c_Lottable08     = '',              --(CS01)
      @c_Lottable09     = '',              --(CS01)
      @c_Lottable10     = '',              --(CS01)
      @c_Lottable11     = '',              --(CS01)
      @c_Lottable12     = '',              --(CS01)
      @d_Lottable13     = NULL,            --(CS01)
      @d_Lottable14     = NULL,            --(CS01)
      @d_Lottable15     = NULL,            --(CS01)
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
      @c_SourceType     = 'ispSHPMO05',
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

   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispSHPMO05'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
        COMMIT TRAN
      END
      RETURN
   END
END

GO