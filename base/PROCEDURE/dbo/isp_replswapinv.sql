SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* S Proc: isp_ReplSwapInv                                              */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/* Input Parameters: Storer Key                                         */
/*                                                                      */
/* Output Parameters: None                                              */
/*                                                                      */
/* Return Status: None                                                  */
/*                                                                      */
/* Usage: For Backend Schedule job                                      */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: SQL Schedule Job                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author  Ver.  Purposes                                   */
/* 01/07/2015  NJOW01  1.0   342639-enhances for UA CN/HK               */
/* 19/07/2015  NJOW02  1.1   fix skuxloc.qty update issue               */
/* 13/11/2015  NJOW03  1.2   change pending replen checking by sku level*/
/* 12/12/2015  Wendy01 1.3   Change to allow swap Qtypicked             */
/* 29/12/2016  NJOW04  1.4   367157-Swap lot filter lottable by         */
/*                           codelkup setting. Pick Loc lot sorting.    */
/* 15/03/2017  Leong   1.5   IN00291676 - Enable @n_debug mode.         */
/* 19/06/2017  TLTING  1.6   Devision by zero for CUR_BULK              */
/* 16/08/2017  NJOW05  1.7   WMS-1995 Use pack.casecnt instead of lot10 */
/*                           if AllocateGetCasecntFrLottable is turned  */
/*                           off                                        */
/* 12/11/2017  NJOW06  1.8   Fix skuxloc constraints error              */
/* 11/10/2018  NJOW07  1.9   allow configure filter by pick status and  */
/*                           specific loc,Sku                           */
/* 11/11/2018  NJOW08  2.0   Double 11 Fix commit if call fr releasetask*/
/* 18/07/2019  TLTING01 2.1  Performance tune                           */
/************************************************************************/

CREATE PROC [dbo].[isp_ReplSwapInv]
     @c_StorerKey NVARCHAR(15)
   , @c_ForcePicked CHAR(1) = 'Y'  --NJOW07
   , @c_Loc NVARCHAR(10) = ''      --NJOW07
   , @c_Sku NVARCHAR(20) = ''      --NJOW07
   , @c_callfrom NVARCHAR(30) = 'SQLJOB' --NJOW07  --RELEASETASK,INVMOVE
   , @n_debug INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Err          INT
         , @n_Continue     INT
         , @n_StartTCnt    INT

   --DECLARE @c_Sku          NVARCHAR(20)
   DECLARE @c_BulkLot      NVARCHAR(10)
         , @c_BulkLoc      NVARCHAR(10)
, @c_BulkID       NVARCHAR(18)
         , @c_PickLot      NVARCHAR(10)
         , @c_PickLoc      NVARCHAR(10)
         , @c_PickID       NVARCHAR(18)
         , @c_AvailLot     NVARCHAR(10)
         , @c_AvailID      NVARCHAR(18)
         , @n_AvailQty     INT
         , @n_QtyExpected  INT
         , @n_QtyToMove    INT

   --NJOW01
   DECLARE @c_ReplSwapInv_Mode NVARCHAR(10)
         , @c_BulkLottable10   NVARCHAR(30)
         , @c_AvailLottable10  NVARCHAR(30)
         , @c_PackKey          NVARCHAR(10)
         , @c_UOM              NVARCHAR(10)
         , @c_ErrMsg           NVARCHAR(250)
         , @b_Success          INT
         , @c_lottable01       NVARCHAR(18)
         , @c_lottable02       NVARCHAR(18)
         , @c_lottable03       NVARCHAR(18)
         , @d_lottable04   DATETIME
         , @d_lottable05       DATETIME
         , @c_lottable06       NVARCHAR(30)
         , @c_lottable07       NVARCHAR(30)
         , @c_lottable08       NVARCHAR(30)
         , @c_lottable09       NVARCHAR(30)
         , @c_lottable10       NVARCHAR(30)
         , @c_lottable11       NVARCHAR(30)
         , @c_lottable12       NVARCHAR(30)
         , @d_lottable13       DATETIME
         , @d_lottable14       DATETIME
         , @d_lottable15       DATETIME
         , @d_EffectiveDate    DATETIME
         , @c_AllocateGetCasecntFrLottable NVARCHAR(10) --NJOW05
         , @n_LatestQty        INT --NJOW06


   SET @n_Err       = 0
   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT

   --SET @c_Sku       = ''
   SET @c_BulkLot   = ''
   SET @c_BulkLoc   = ''
   SET @c_BulkID    = ''
   SET @c_PickLot   = ''
   SET @c_PickLoc   = ''
   SET @c_PickID    = ''
   SET @c_AvailLot  = ''
   SET @c_AvailID   = ''
   SET @n_AvailQty  = ''
   SET @n_QtyExpected= ''
   SET @n_QtyToMove  = ''
   
   --NJOW07
   IF ISNULL(@c_ForcePicked,'') = ''
      SET @c_ForcePicked = 'Y'
   IF ISNULL(@c_CallFrom,'') = ''
      SET @c_CallFrom = 'SQLJOB'

   IF @c_callFrom IN('SQLJOB','RELEASETASK') --NJOW07 NJOW08
   BEGIN
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
   END
   ELSE IF @@TRANCOUNT = 0
      BEGIN TRAN 

   /*  --NJOW03 Removed
   IF EXISTS (SELECT 1
              FROM REPLENISHMENT WITH (NOLOCK)
              WHERE Storerkey = @c_Storerkey
              AND Confirmed = 'N')
   BEGIN
      GOTO QUIT
   END
   */

   --NJOW07
   IF @c_CallFrom = 'INVMOVE'
   BEGIN
   	  IF NOT EXISTS (SELECT TOP 1 1 FROM LOTXLOCXID(NOLOCK) WHERE Storerkey = @c_Storerkey AND Sku = @c_Sku AND loc = @c_Loc AND QtyExpected > 0) 
   	     GOTO QUIT
   END
   IF @c_CallFrom = 'RELEASETASK'
   BEGIN
   	  IF NOT EXISTS (SELECT TOP 1 1 FROM LOTXLOCXID(NOLOCK) WHERE Storerkey = @c_Storerkey AND qtyexpected > 0) 
   	     GOTO QUIT
   END

   --NJOW01
   EXEC nspGetRight
      @c_Facility  = NULL,
      @c_StorerKey = @c_StorerKey,
      @c_sku       = NULL,
      @c_ConfigKey = 'ReplSwapInv_Mode',
      @b_Success   = @b_Success            OUTPUT,
      @c_authority = @c_ReplSwapInv_Mode   OUTPUT,
      @n_err       = @n_err                OUTPUT,
      @c_errmsg    = @c_errmsg             OUTPUT

   --NJOW05
   EXEC nspGetRight
      @c_Facility  = NULL,
      @c_StorerKey = @c_StorerKey,
      @c_sku       = NULL,
      @c_ConfigKey = 'AllocateGetCasecntFrLottable',
      @b_Success   = @b_Success                        OUTPUT,
      @c_authority = @c_AllocateGetCasecntFrLottable   OUTPUT,
      @n_err       = @n_err                            OUTPUT,
      @c_errmsg    = @c_errmsg                         OUTPUT


   DECLARE CUR_LOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT
          LOTxLOCxID.Lot
         ,LOTxLOCxID.Loc
         ,LOTxLOCxID.id
         ,LOTxLOCxID.Sku
         ,CASE WHEN @c_callfrom = 'SQLJOB' THEN
             LOTxLOCxID.QtyExpected-LOTxLOCxID.QtyAllocated --Wendy01
          ELSE
          	 LOTxLOCxID.QtyExpected  --NJOW07
          END
   FROM LOTxLOCxID   WITH (NOLOCK)
   JOIN SKUxLOC      WITH (NOLOCK) ON (LOTxLOCxID.StorerKey = SKUxLOC.StorerKey)
                                   AND(LOTxLOCxID.SKU = SKUxLOC.SKU)
                                   AND(LOTxLOCxID.LOC = SKUxLOC.LOC)
   JOIN LOC          WITH (NOLOCK) ON (LOTxLOCxID.LOC = LOC.Loc)    --NJOW01
   WHERE LOTxLOCxID.QtyExpected > 0
   AND LOTxLOCxID.StorerKey = @c_StorerKey
   AND (SKUxLOC.LocationType IN ('PICK', 'CASE') OR
        (LOC.LocationType IN('DYNPPICK','DYNPICKR','DYNPICKP') AND LOTxLOCxID.QtyExpected > 0) OR    --NJOW01
        (LOTxLOCxID.QtyExpected > 0 AND SKUxLOC.QtyExpected = 0))
   --AND (LOTxLOCxID.QtyAllocated=0)    Wendy01
   AND (LOTxLOCxID.QtyPicked > 0 
        OR @c_ForcePicked = 'N')  --NJOW07
   AND (LOC.Loc = @c_Loc OR ISNULL(@c_Loc,'') = '')  --NJOW07 
   AND (LOTxLOCxID.Sku = @c_Sku OR ISNULL(@c_Sku,'') = '') --NJOW07     
   AND NOT EXISTS (SELECT 1 FROM REPLENISHMENT R (NOLOCK)  --NJOW03
                   WHERE R.Storerkey = LOTxLOCxID.Storerkey
                   AND R.Sku = LOTxLOCxID.Sku
                   AND R.Confirmed = 'N'
                   AND @c_CallFrom = 'SQLJOB') --NJOW07
   ORDER BY LOTxLOCxID.Sku
         ,  LOTxLOCxID.Loc

   OPEN CUR_LOC

   FETCH NEXT FROM CUR_LOC INTO @c_PickLot
                              , @c_PickLoc
                              , @c_PickID
                              , @c_Sku
                              , @n_QtyExpected
   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      IF NOT EXISTS (SELECT 1
                     FROM LOTATTRIBUTE WITH (NOLOCK)
                     WHERE LOTATTRIBUTE.Lot = @c_PickLot 
                     AND EXISTS ( Select 1 from CODELKUP     WITH (NOLOCK)   -- TLTING01
                              WHERE (CODELKUP.ListName = N'REPLSWAP')
                              AND (LOTATTRIBUTE.Lottable02 = CODELKUP.Short)
                              AND (LOTATTRIBUTE.Storerkey = CODELKUP.Storerkey) --NJOW01
                              AND (CODELKUP.UDF01 = '1')   ) 
                              )

                     --JOIN CODELKUP     WITH (NOLOCK) ON (CODELKUP.ListName = 'REPLSWAP')
                     --                                AND (LOTATTRIBUTE.Lottable02 = CODELKUP.Short)
                     --                                AND (LOTATTRIBUTE.Storerkey = CODELKUP.Storerkey) --NJOW01
                     --                                AND (CODELKUP.UDF01 = '1')
                     --WHERE LOTATTRIBUTE.Lot = @c_PickLot)
      BEGIN
         GOTO NEXT_LOC
      END

      --NJOW01
      /*
      IF EXISTS (SELECT 1
                 FROM LOTATTRIBUTE WITH (NOLOCK)
                 JOIN CODELKUP     WITH (NOLOCK) ON (CODELKUP.ListName = 'REPLSWAP')
                                                 AND (LOTATTRIBUTE.Lottable02 = CODELKUP.Short)
                                                 AND (LOTATTRIBUTE.Storerkey = CODELKUP.Storerkey)
                                                 AND (CODELKUP.NOTES2 = '0')
                 WHERE LOTATTRIBUTE.Lot = @c_PickLot)
      BEGIN
         GOTO NEXT_LOC
      END
      */

      IF NOT EXISTS (SELECT 1
                     FROM PICKDETAIL WITH (NOLOCK)
                     WHERE Lot = @c_PickLot
                     AND   Loc = @c_PickLoc
                     AND   ID  = @c_PickID
                     AND   Status BETWEEN '5' AND '8') 
         AND @c_ForcePicked <> 'N' --NJOW07
      BEGIN
         GOTO NEXT_LOC
      END

      IF @n_debug = 2
      BEGIN
         SELECT PickDetailKey, Status, Lot, Loc, Id, Qty, StorerKey, Sku, OrderKey, OrderLineNumber
         FROM PickDetail WITH (NOLOCK)
         WHERE Lot = @c_PickLot
         AND   Loc = @c_PickLoc
         AND   ID  = @c_PickID
         AND   Status BETWEEN '5' AND '8'
      END

      IF @c_ReplSwapInv_Mode = 'UA' AND @c_AllocateGetCasecntFrLottable IN ('01','02','03','06','07','08','09','10','11','12') --NJOW01 NJOW03
      BEGIN
        --NJOW01
         DECLARE CUR_BULK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT  c_BulkLot  = LOTxLOCxID.Lot
                  , c_BulkLoc  = LOTxLOCxID.Loc
                  , c_BulkID   = LOTxLOCxID.ID
                  , n_QtyToMove= LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked 
                                 - ISNULL(REP.QtyReplen,0) --NJOW07
            FROM LOTxLOCxID WITH (NOLOCK)
            JOIN LOT        WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)
            JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot)
            JOIN LOC        WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
            JOIN ID         WITH (NOLOCK) ON (LOTxLOCxID.ID  = ID.ID)
            JOIN SKUxLOC    WITH (NOLOCK) ON (LOTxLOCxID.StorerKey = SKUxLOC.StorerKey)
                                          AND(LOTxLOCxID.SKU = SKUxLOC.SKU)
                                          AND(LOTxLOCxID.LOC = SKUxLOC.LOC)
            JOIN SKU  WITH (NOLOCK) ON (LOTxLOCxID.Storerkey = SKU.Storerkey)
                                    AND(LOTxLOCxID.Sku = SKU.Sku)
            JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
            OUTER APPLY (SELECT SUM(RL.QTY) AS QtyReplen  --NJOW07
                         FROM REPLENISHMENT RL (NOLOCK)
                         JOIN LOC TOLOC (NOLOCK) ON RL.ToLoc = TOLOC.Loc 
                         WHERE RL.Lot = LOTxLOCxID.Lot 
                         AND RL.FromLoc = LOTxLOCxID.Loc
                         AND RL.Id = LOTxLOCxID.Id
                         AND RL.Confirmed = 'N'
                         AND NOT (TOLOC.LocationType = 'RPLTMP' AND @c_ReplSwapInv_Mode = 'UA')
                         AND @c_CallFrom <> 'SQLJOB') AS REP
            WHERE LOTxLOCxID.Lot =  @c_PickLot
            AND   LOTxLOCxID.Loc <> @c_PickLoc
            AND  (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - ISNULL(REP.QtyReplen,0)) > 0
            AND   LOT.Status = 'OK'
            AND   LOC.Status = 'OK'
            AND   ID.Status  = 'OK'
            AND   LOC.LocationFlag <> 'DAMAGE' AND LOC.LocationFlag <> 'HOLD'
            AND   SKUxLOC.LocationType NOT IN ('CASE', 'PICK')
            AND   LOC.LocationType NOT IN('DYNPPICK','DYNPICKR','DYNPICKP','RPLTMP')
            ORDER BY 
            CASE WHEN LOTATTRIBUTE.Lottable10 = '0' OR LOTATTRIBUTE.Lottable10 IS NULL OR LOTATTRIBUTE.Lottable10 = '' OR ISNUMERIC(LOTATTRIBUTE.Lottable10) = 0 THEN 
                      CASE WHEN (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - ISNULL(REP.QtyReplen,0)) % 1 = 0 THEN 1 ELSE 0 END
                 ELSE  CASE WHEN
                      (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - ISNULL(REP.QtyReplen,0)) % CONVERT(INT,ISNULL(LOTATTRIBUTE.Lottable10,1)) = 0 THEN 1 ELSE 0 END END
            , (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - ISNULL(REP.QtyReplen,0)), LOTxLOCxID.Loc
      END
      ELSE
      BEGIN
         DECLARE CUR_BULK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT  c_BulkLot  = LOTxLOCxID.Lot
                  , c_BulkLoc  = LOTxLOCxID.Loc
                  , c_BulkID   = LOTxLOCxID.ID
                  , n_QtyToMove= LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked 
                    - ISNULL(REP.QtyReplen,0) --NJOW07
            FROM LOTxLOCxID WITH (NOLOCK)
            JOIN LOT        WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)
            JOIN LOC        WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
            JOIN ID         WITH (NOLOCK) ON (LOTxLOCxID.ID  = ID.ID)
            JOIN SKUxLOC    WITH (NOLOCK) ON (LOTxLOCxID.StorerKey = SKUxLOC.StorerKey)
                                          AND(LOTxLOCxID.SKU = SKUxLOC.SKU)
                                          AND(LOTxLOCxID.LOC = SKUxLOC.LOC)
            JOIN SKU  WITH (NOLOCK) ON (LOTxLOCxID.Storerkey = SKU.Storerkey)
                                    AND(LOTxLOCxID.Sku = SKU.Sku)
            JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
            OUTER APPLY (SELECT SUM(RL.QTY) AS QtyReplen  --NJOW07
                         FROM REPLENISHMENT RL (NOLOCK)
                         JOIN LOC TOLOC (NOLOCK) ON RL.ToLoc = TOLOC.Loc 
                         WHERE RL.Lot = LOTxLOCxID.Lot 
                         AND RL.FromLoc = LOTxLOCxID.Loc
                         AND RL.Id = LOTxLOCxID.Id
                         AND RL.Confirmed = 'N'
                         AND NOT (TOLOC.LocationType = 'RPLTMP' AND @c_ReplSwapInv_Mode = 'UA')
                         AND @c_CallFrom <> 'SQLJOB') AS REP
            WHERE LOTxLOCxID.Lot =  @c_PickLot
            AND   LOTxLOCxID.Loc <> @c_PickLoc
            AND  (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - ISNULL(REP.QtyReplen,0)) > 0
            AND   LOT.Status = 'OK'
            AND   LOC.Status = 'OK'
            AND   ID.Status  = 'OK'
            AND   LOC.LocationFlag <> 'DAMAGE' AND LOC.LocationFlag <> 'HOLD'
            AND   SKUxLOC.LocationType NOT IN ('CASE', 'PICK')
            AND   LOC.LocationType NOT IN('DYNPPICK','DYNPICKR','DYNPICKP','RPLTMP')  --NJOW01
            ORDER BY 
            CASE WHEN PACK.CaseCnt = '0' OR PACK.CaseCnt IS NULL THEN 
                     CASE WHEN (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - ISNULL(REP.QtyReplen,0)) % 1 = 0 THEN 1 ELSE 0 END
                 ELSE  CASE WHEN
                      (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - ISNULL(REP.QtyReplen,0)) % CONVERT(INT,ISNULL(PACK.CaseCnt,1)) = 0 THEN 1 ELSE 0 END END
            , (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - ISNULL(REP.QtyReplen,0)), LOTxLOCxID.Loc
      END

      OPEN CUR_BULK

      FETCH NEXT FROM CUR_BULK INTO @c_BulkLot
                                 ,  @c_BulkLoc
                                 ,  @c_BulkID
                                 ,  @n_QtyToMove

      WHILE @@FETCH_STATUS <> -1 AND @n_QtyExpected > 0
      BEGIN
         IF @c_ReplSwapInv_Mode = 'UA' --NJOW01
         BEGIN
            --NJOW01
            DECLARE CUR_AVAILLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT c_AvailLot = LOTxLOCxID.Lot
                    , c_AvailID  = LOTxLOCxID.ID
                    , n_AvailQty = LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked
               FROM LOTxLOCxID   WITH (NOLOCK)
               JOIN LOT          WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)
               JOIN ID           WITH (NOLOCK) ON (LOTxLOCxID.ID  = ID.ID)
               JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOT.Lot = LOTATTRIBUTE.Lot)
               WHERE LOTxLOCxID.Lot <> @c_PickLot
               AND   LOTxLOCxID.Loc = @c_PickLoc
               AND   LOTxLOCxID.Storerkey = @c_Storerkey
               AND   LOTxLOCxID.Sku = @c_Sku
               AND   LOT.Status = 'OK'
               AND   ID.Status  = 'OK'
               AND   (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) > 0
               ORDER BY ISNULL(LOTATTRIBUTE.Lottable04, '1900-01-01')
                     ,  ISNULL(LOTATTRIBUTE.Lottable05, '1900-01-01')
                     ,  ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),'')
                     ,  LOTxLOCxID.Lot
         END
         ELSE
         BEGIN
              --NJOW04
            SELECT @c_lottable01 = lottable01,
                   @c_lottable02 = lottable02,
                   @c_lottable03 = lottable03,
                   @d_lottable04 = lottable04,
                   @d_lottable05 = lottable05,
                   @c_lottable06 = lottable06,
                   @c_lottable07 = lottable07,
                   @c_lottable08 = lottable08,
  @c_lottable09 = lottable09,
                   @c_lottable10 = lottable10,
                   @c_lottable11 = lottable11,
                   @c_lottable12 = lottable12,
                   @d_lottable13 = lottable13,
                   @d_lottable14 = lottable14,
                   @d_lottable15 = lottable15
            FROM LOTATTRIBUTE (NOLOCK)
            WHERE Lot = @c_PickLot

            DECLARE CUR_AVAILLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT c_AvailLot = LOTxLOCxID.Lot
                    , c_AvailID  = LOTxLOCxID.ID
                    , n_AvailQty = LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked
               FROM LOTxLOCxID   WITH (NOLOCK)
               JOIN LOT          WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)
               JOIN ID           WITH (NOLOCK) ON (LOTxLOCxID.ID  = ID.ID)
               JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOT.Lot = LOTATTRIBUTE.Lot)
               LEFT JOIN CODELKUP CL  WITH (NOLOCK) ON (CL.ListName = 'REPLSWAP')   --NJOW04
                                                    AND(LOTxLOCxID.Storerkey = CL.Storerkey)
                                                    AND(LOTATTRIBUTE.Lottable02 = CL.Short)
               WHERE LOTxLOCxID.Lot <> @c_PickLot
               AND   LOTxLOCxID.Loc = @c_PickLoc
               AND   LOTxLOCxID.Storerkey = @c_Storerkey
               AND   LOTxLOCxID.Sku = @c_Sku
               AND   LOT.Status = 'OK'
               AND   ID.Status  = 'OK'
               AND   (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) > 0
               AND LOTATTRIBUTE.Lottable01 = CASE WHEN ISNULL(CL.Notes2,'') = '1' AND CHARINDEX('LOTTABLE01', ISNULL(CL.Notes,'')) > 0 THEN ISNULL(@c_Lottable01,'') ELSE LOTATTRIBUTE.Lottable01 END  --NJOW04
               AND LOTATTRIBUTE.Lottable02 = CASE WHEN ISNULL(CL.Notes2,'') = '1' AND CHARINDEX('LOTTABLE02', ISNULL(CL.Notes,'')) > 0 THEN ISNULL(@c_Lottable02,'') ELSE LOTATTRIBUTE.Lottable02 END
               AND LOTATTRIBUTE.Lottable03 = CASE WHEN ISNULL(CL.Notes2,'') = '1' AND CHARINDEX('LOTTABLE03', ISNULL(CL.Notes,'')) > 0 THEN ISNULL(@c_Lottable03,'') ELSE LOTATTRIBUTE.Lottable03 END
               AND ISNULL(LOTATTRIBUTE.Lottable04,'') = CASE WHEN CL.Notes2 = '1' AND CHARINDEX('LOTTABLE04', ISNULL(CL.Notes,'')) > 0 THEN ISNULL(@d_Lottable04,'') ELSE ISNULL(LOTATTRIBUTE.Lottable04,'') END
               AND ISNULL(LOTATTRIBUTE.Lottable05,'') = CASE WHEN CL.Notes2 = '1' AND CHARINDEX('LOTTABLE05', ISNULL(CL.Notes,'')) > 0 THEN ISNULL(@d_Lottable05,'') ELSE ISNULL(LOTATTRIBUTE.Lottable05,'') END
               AND LOTATTRIBUTE.Lottable06 = CASE WHEN ISNULL(CL.Notes2,'') = '1' AND CHARINDEX('LOTTABLE06', ISNULL(CL.Notes,'')) > 0 THEN ISNULL(@c_Lottable06,'') ELSE LOTATTRIBUTE.Lottable06 END
               AND LOTATTRIBUTE.Lottable07 = CASE WHEN ISNULL(CL.Notes2,'') = '1' AND CHARINDEX('LOTTABLE07', ISNULL(CL.Notes,'')) > 0 THEN ISNULL(@c_Lottable07,'') ELSE LOTATTRIBUTE.Lottable07 END
               AND LOTATTRIBUTE.Lottable08 = CASE WHEN ISNULL(CL.Notes2,'') = '1' AND CHARINDEX('LOTTABLE08', ISNULL(CL.Notes,'')) > 0 THEN ISNULL(@c_Lottable08,'') ELSE LOTATTRIBUTE.Lottable08 END
               AND LOTATTRIBUTE.Lottable09 = CASE WHEN ISNULL(CL.Notes2,'') = '1' AND CHARINDEX('LOTTABLE09', ISNULL(CL.Notes,'')) > 0 THEN ISNULL(@c_Lottable09,'') ELSE LOTATTRIBUTE.Lottable09 END
               AND LOTATTRIBUTE.Lottable10 = CASE WHEN ISNULL(CL.Notes2,'') = '1' AND CHARINDEX('LOTTABLE10', ISNULL(CL.Notes,'')) > 0 THEN ISNULL(@c_Lottable10,'') ELSE LOTATTRIBUTE.Lottable10 END
               AND LOTATTRIBUTE.Lottable11 = CASE WHEN ISNULL(CL.Notes2,'') = '1' AND CHARINDEX('LOTTABLE11', ISNULL(CL.Notes,'')) > 0 THEN ISNULL(@c_Lottable11,'') ELSE LOTATTRIBUTE.Lottable11 END
               AND LOTATTRIBUTE.Lottable12 = CASE WHEN ISNULL(CL.Notes2,'') = '1' AND CHARINDEX('LOTTABLE12', ISNULL(CL.Notes,'')) > 0 THEN ISNULL(@c_Lottable12,'') ELSE LOTATTRIBUTE.Lottable12 END
               AND ISNULL(LOTATTRIBUTE.Lottable13,'') = CASE WHEN CL.Notes2 = '1' AND CHARINDEX('LOTTABLE13', ISNULL(CL.Notes,'')) > 0 THEN ISNULL(@d_Lottable13,'') ELSE ISNULL(LOTATTRIBUTE.Lottable13,'') END
               AND ISNULL(LOTATTRIBUTE.Lottable14,'') = CASE WHEN CL.Notes2 = '1' AND CHARINDEX('LOTTABLE14', ISNULL(CL.Notes,'')) > 0 THEN ISNULL(@d_Lottable14,'') ELSE ISNULL(LOTATTRIBUTE.Lottable14,'') END
               AND ISNULL(LOTATTRIBUTE.Lottable15,'') = CASE WHEN CL.Notes2 = '1' AND CHARINDEX('LOTTABLE15', ISNULL(CL.Notes,'')) > 0 THEN ISNULL(@d_Lottable15,'') ELSE ISNULL(LOTATTRIBUTE.Lottable15,'') END
               ORDER BY (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) DESC --NJOW04
                     ,  ISNULL(LOTATTRIBUTE.Lottable05, '1900-01-01')
                     ,  ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),'')
                     ,  LOTxLOCxID.Lot
         END

         OPEN CUR_AVAILLOC

         FETCH NEXT FROM CUR_AVAILLOC INTO @c_AvailLot
                                          ,@c_AvailID
                                          ,@n_AvailQty

         WHILE @@FETCH_STATUS <> -1 AND @n_QtyExpected > 0
         BEGIN
            SET @n_Continue = 1

            IF @n_QtyToMove > @n_QtyExpected
            BEGIN
               SET @n_QtyToMove = @n_QtyExpected
            END

            IF @n_QtyToMove > @n_AvailQty
            BEGIN
               SET @n_QtyToMove = @n_AvailQty
            END

            --NJOW06 
            SET @n_LatestQty = 0
            SELECT @n_LatestQty  = Qty - QtyAllocated - QtyPicked 
            FROM LOTXLOCXID (NOLOCK) 
            WHERE Lot = @c_BulkLot
            AND   Loc = @c_BulkLoc
            AND   ID  = @c_BulkID             
            
            IF @n_QtyToMove > @n_LatestQty
            BEGIN
               SET @n_QtyToMove = @n_LatestQty
            END
            
            SET @n_QtyExpected = @n_QtyExpected - @n_QtyToMove
            
            -- Move Bulk Loc to PickLoc
            
            IF @n_QtyToMove > 0 --NJOW06
            BEGIN          

               IF @c_callFrom IN ('SQLJOB','RELEASETASK') --NJOW07 NJOW08
                  BEGIN TRAN  
               	            
	             UPDATE LOTxLOCxID WITH (ROWLOCK)
               SET Qty = Qty - @n_QtyToMove
               WHERE Lot = @c_BulkLot
               AND   Loc = @c_BulkLoc
               AND   ID  = @c_BulkID
               
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  GOTO NEXT_REC
               END
            END
            ELSE
               GOTO NEXT_BULK

            UPDATE ID WITH (ROWLOCK)
               SET Qty = Qty - @n_QtyToMove
            WHERE ID  = @c_BulkID

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               GOTO NEXT_REC
            END

            UPDATE LOTxLOCxID WITH (ROWLOCK)
               SET Qty = Qty + @n_QtyToMove
               ,   QtyExpected = QtyExpected - @n_QtyToMove
            WHERE Lot = @c_PickLot
            AND   Loc = @c_PickLoc
            AND   ID  = @c_PickID

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               GOTO NEXT_REC
            END

            /* --NJOW06 removed
            UPDATE SKUxLOC WITH (ROWLOCK)
               SET QtyExpected = QtyExpected - CASE WHEN QtyExpected > 0 THEN @n_QtyToMove ELSE 0 END
            WHERE Storerkey = @c_Storerkey
            AND   Sku = @c_Sku
            AND   Loc = @c_PickLoc
            
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               GOTO NEXT_REC
            END
            */

            UPDATE ID WITH (ROWLOCK)
               SET Qty = Qty + @n_QtyToMove
            WHERE ID  = @c_PickID

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               GOTO NEXT_REC
            END
            -- Move Pick Loc to BulkLoc

            --NJOW01 Start            
            IF @c_AllocateGetCasecntFrLottable IN ('01','02','03','06','07','08','09','10','11','12') --NJOW05
            BEGIN
               SELECT @c_BulkLottable10 = LA.Lottable10,
                      @c_Packkey = PACK.Packkey,
                      @c_UOM = PACK.PackUOM3
               FROM LOTATTRIBUTE LA (NOLOCK)
               JOIN SKU (NOLOCK) ON LA.Storerkey = SKU.Storerkey AND LA.Sku = SKU.Sku
               JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
               WHERE LA.Lot = @c_BulkLot
               
               SELECT @c_AvailLottable10 = Lottable10,
                      @c_lottable01 = lottable01,
                      @c_lottable02 = lottable02,
                      @c_lottable03 = lottable03,
                      @d_lottable04 = lottable04,
                      @d_lottable05 = lottable05,
                      @c_lottable06 = lottable06,
                      @c_lottable07 = lottable07,
                      @c_lottable08 = lottable08,
                      @c_lottable09 = lottable09,
                      @c_lottable10 = lottable10,
                      @c_lottable11 = lottable11,
                      @c_lottable12 = lottable12,
                      @d_lottable13 = lottable13,
                      @d_lottable14 = lottable14,
                      @d_lottable15 = lottable15
               FROM LOTATTRIBUTE (NOLOCK)
               WHERE Lot = @c_AvailLot
            END
            --NJOW01 End

            IF @c_ReplSwapInv_Mode = 'UA' AND ISNULL(@c_BulkLottable10,'') <> ISNULL(@c_AvailLottable10,'')  --NJOW01
               AND @c_AllocateGetCasecntFrLottable IN ('01','02','03','06','07','08','09','10','11','12') --NJOW05
            BEGIN
               SELECT @d_EffectiveDate = GETDATE()

               IF @n_debug = 1 OR @n_debug = 2
               BEGIN
                  SELECT 'Withdrawal ->'
                        , @c_StorerKey      '@c_StorerKey    '
                        , @c_Sku            '@c_Sku          '
                        , @n_QtyToMove      '@n_QtyToMove    '
                        , @c_AvailLot       '@c_AvailLot     '
                        , @c_PickLoc        '@c_PickLoc      '
                        , @c_AvailID        '@c_AvailID      '
                        , @c_lottable01     '@c_lottable01   '
                        , @c_lottable02     '@c_lottable02   '
                        , @c_lottable03     '@c_lottable03   '
                        , @d_lottable04     '@d_lottable04   '
                        , @d_lottable05     '@d_lottable05   '
                        , @c_lottable06     '@c_lottable06   '
                        , @c_lottable07     '@c_lottable07   '
                        , @c_lottable08     '@c_lottable08   '
                        , @c_lottable09     '@c_lottable09   '
                        , @c_lottable10     '@c_lottable10   '
                        , @c_lottable11     '@c_lottable11   '
                        , @c_lottable12     '@c_lottable12   '
                        , @d_lottable13     '@d_lottable13   '
                        , @d_lottable14     '@d_lottable14   '
                        , @d_lottable15     '@d_lottable15   '
                        , @c_PackKey        '@c_PackKey      '
                        , @c_UOM            '@c_UOM          '
                        , @d_EffectiveDate  '@d_EffectiveDate'

                  SELECT 'Deposit ->', @c_BulkLoc '@c_BulkLoc', @n_QtyToMove '@n_QtyToMove', @c_BulkLottable10 '@c_BulkLottable10', @c_AvailLottable10 '@c_AvailLottable10'
                       , @c_BulkLot '@c_BulkLot', @c_AvailLot '@c_AvailLot'
               END

               --NJOW02
               UPDATE SKUxLOC WITH (ROWLOCK) -- IN00291676
          SET Qty = Qty + @n_QtyToMove
               WHERE Storerkey = @c_Storerkey
               AND   Sku = @c_Sku
               AND   Loc = @c_PickLoc
                              
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  GOTO NEXT_REC
               END
               
               --NJOW06
               UPDATE SKUxLOC WITH (ROWLOCK)
               SET QtyExpected = CASE WHEN QtyExpected > 0 AND (QtyAllocated + QtyPicked) - Qty >= 0 THEN
                                      (QtyAllocated + QtyPicked) - Qty  ELSE QtyExpected END
               WHERE Storerkey = @c_Storerkey
               AND   Sku = @c_Sku
               AND   Loc = @c_PickLoc

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  GOTO NEXT_REC
               END

               EXECUTE nspItrnAddWithdrawal
                        @n_ItrnSysId  = NULL,
                        @c_StorerKey  = @c_StorerKey,
                        @c_Sku        = @c_Sku,
                        @c_Lot        = @c_AvailLot,
                        @c_ToLoc      = @c_PickLoc,
                        @c_ToID       = @c_AvailID,
                        @c_Status     = '',
                        @c_lottable01 = @c_lottable01,
                        @c_lottable02 = @c_lottable02,
                        @c_lottable03 = @c_lottable03,
                        @d_lottable04 = @d_lottable04,
                        @d_lottable05 = @d_lottable05,
                        @c_lottable06 = @c_lottable06,
                        @c_lottable07 = @c_lottable07,
                        @c_lottable08 = @c_lottable08,
                        @c_lottable09 = @c_lottable09,
                        @c_lottable10 = @c_lottable10,
                        @c_lottable11 = @c_lottable11,
                        @c_lottable12 = @c_lottable12,
                        @d_lottable13 = @d_lottable13,
                        @d_lottable14 = @d_lottable14,
                        @d_lottable15 = @d_lottable15,
                        @n_casecnt    = 0,
                        @n_innerpack  = 0,
                        @n_Qty        = @n_QtyToMove,
                        @n_pallet     = 0,
                        @f_cube       = 0,
                        @f_grosswgt   = 0,
                        @f_netwgt   = 0,
                        @f_otherunit1 = 0,
                        @f_otherunit2 = 0,
                        @c_SourceKey  = '',
                        @c_SourceType = 'isp_ReplSwapInv',
                        @c_PackKey    = @c_PackKey,
                        @c_UOM        = @c_UOM,
                        @b_UOMCalc    = 0,
                        @d_EffectiveDate = @d_EffectiveDate,
                        @c_ItrnKey    = '',
                        @b_Success    = @b_Success OUTPUT,
                        @n_err        = @n_err     OUTPUT,
                        @c_errmsg     = @c_errmsg  OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  GOTO NEXT_REC
               END

               -- --NJOW02
               -- UPDATE SKUxLOC WITH (ROWLOCK) -- IN00291676
               -- SET Qty = Qty + @n_QtyToMove
               -- WHERE Storerkey = @c_Storerkey
               -- AND   Sku = @c_Sku
               -- AND   Loc = @c_PickLoc
               --
               -- IF @@ERROR <> 0
               -- BEGIN
               --    SET @n_Continue = 3
               --    GOTO NEXT_REC
               -- END

               EXECUTE nspItrnAddDeposit
                        @n_ItrnSysId  = NULL,
                        @c_StorerKey  = @c_StorerKey,
                        @c_Sku        = @c_Sku,
                        @c_Lot        = '',
                        @c_ToLoc      = @c_BulkLoc,
    @c_ToID       = '',
                        @c_Status     = '',
                        @c_lottable01 = @c_lottable01,
                        @c_lottable02 = @c_lottable02,
                        @c_lottable03 = @c_lottable03,
                        @d_lottable04 = @d_lottable04,
                        @d_lottable05 = @d_lottable05,
                        @c_lottable06 = @c_lottable06,
                        @c_lottable07 = @c_lottable07,
                        @c_lottable08 = @c_lottable08,
                        @c_lottable09 = @c_lottable09,
                        @c_lottable10 = @c_BulkLottable10,
                        @c_lottable11 = @c_lottable11,
                        @c_lottable12 = @c_lottable12,
                        @d_lottable13 = @d_lottable13,
                        @d_lottable14 = @d_lottable14,
                        @d_lottable15 = @d_lottable15,
                        @n_casecnt    = 0,
                        @n_innerpack = 0,
                        @n_Qty        = @n_QtyToMove,
                        @n_pallet     = 0,
                        @f_cube       = 0,
                        @f_grosswgt   = 0,
                        @f_netwgt     = 0,
                        @f_otherunit1 = 0,
                        @f_otherunit2 = 0,
                        @c_SourceKey  = '',
                        @c_SourceType = 'isp_ReplSwapInv',
                        @c_PackKey    = @c_PackKey,
                        @c_UOM  = @c_UOM,
                        @b_UOMCalc    = 0,
                        @d_EffectiveDate = @d_EffectiveDate,
                        @c_ItrnKey    = '',
                        @b_Success    = @b_Success OUTPUT,
                        @n_err        = @n_err     OUTPUT,
                        @c_errmsg     = @c_errmsg  OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  GOTO NEXT_REC
               END

               --NJOW02
               UPDATE SKUxLOC WITH (ROWLOCK)
               SET Qty = Qty - @n_QtyToMove
               WHERE Storerkey = @c_Storerkey
               AND   Sku = @c_Sku
               AND   Loc = @c_BulkLoc

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  GOTO NEXT_REC
               END
            END
            ELSE
            BEGIN
               UPDATE LOTxLOCxID WITH (ROWLOCK)
                  SET Qty = Qty - @n_QtyToMove
               WHERE Lot = @c_AvailLot
               AND   Loc = @c_PickLoc
               AND   ID  = @c_AvailID

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  GOTO NEXT_REC
               END

               UPDATE ID WITH (ROWLOCK)
                  SET Qty = Qty - @n_QtyToMove
               WHERE ID  = @c_AvailID

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  GOTO NEXT_REC
               END

               IF EXISTS (SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)
                          WHERE Lot = @c_AvailLot
                          AND   Loc = @c_BulkLoc
                          AND   ID  = '')
               BEGIN
                  UPDATE LOTxLOCxID WITH (ROWLOCK)
                     SET Qty = Qty + @n_QtyToMove
                  WHERE Lot = @c_AvailLot
                  AND   Loc = @c_BulkLoc
                  AND   ID  = ''
               END
               ELSE
               BEGIN
                  INSERT INTO LOTxLOCxID (Storerkey, Sku, Lot, Loc, ID, Qty)
                  VALUES (@c_Storerkey, @c_Sku, @c_AvailLot, @c_BulkLoc, '', @n_QtyToMove)
               END

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  GOTO NEXT_REC
               END

               UPDATE ID WITH (ROWLOCK)
     SET Qty = Qty + @n_QtyToMove
               WHERE ID  = ''

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
               END
            END

            NEXT_REC:

            IF @c_callFrom IN('SQLJOB','RELEASETASK') --NJOW07 NJOW08
            BEGIN
              IF @@TRANCOUNT > 0
              BEGIN
                 IF @n_Continue = 1 OR @n_Continue = 2
                 BEGIN
                    COMMIT TRAN
                 END
                 ELSE
                 BEGIN
                    ROLLBACK TRAN
                 END
              END
            END
            
            FETCH NEXT FROM CUR_AVAILLOC INTO @c_AvailLot
                                             ,@c_AvailID
                                             ,@n_AvailQty
         END
         NEXT_BULK:
         IF CURSOR_STATUS( 'LOCAL' , 'CUR_AVAILLOC') IN (0, 1)
         BEGIN
            CLOSE CUR_AVAILLOC
            DEALLOCATE CUR_AVAILLOC
         END

         FETCH NEXT FROM CUR_BULK INTO @c_BulkLot
                                    ,  @c_BulkLoc
                                    ,  @c_BulkID
                                    ,  @n_QtyToMove
      END
      NEXT_LOC:
      IF CURSOR_STATUS( 'LOCAL' , 'CUR_BULK') IN (0, 1)
      BEGIN
         CLOSE CUR_BULK
         DEALLOCATE CUR_BULK
      END

      FETCH NEXT FROM CUR_LOC INTO @c_PickLot
                                 , @c_PickLoc
                                 , @c_PickID
                                 , @c_Sku
                                 , @n_QtyExpected

   END
   IF CURSOR_STATUS( 'LOCAL' , 'CUR_LOC') IN (0, 1)
   BEGIN
      CLOSE CUR_LOC
      DEALLOCATE CUR_LOC
   END
   QUIT:

   IF @c_callFrom IN('SQLJOB','RELEASETASK') --NJOW07 NJOW08
   BEGIN   
      WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN
         BEGIN TRAN
      END
   END
   ELSE
   BEGIN
   	  --NJOW07
      IF @n_continue=3  
      BEGIN  
         IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt  
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
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END      
   END   
END

GRANT EXECUTE ON [isp_ReplSwapInv] TO NSQL

GO