SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***********************************************************************************/
/* Stored Procedure: ispGetOrderStatus                                             */
/* Creation Date:                                                                  */
/* Copyright: IDS                                                                  */
/* Written by:                                                                     */
/*                                                                                 */
/* Purpose: Set Orders Status base on quantity in OrderDetail                      */
/*          WHEN '0'    THEN  'Normal'                                             */
/*          WHEN '1'    THEN  'Partially Allocated'                                */
/*          WHEN '2'    THEN  'Fully Allocated'                                    */
/*          WHEN '3'    THEN  'In Process'                                         */
/*          WHEN '4'    THEN  ''                                                   */
/*          WHEN '5'    THEN  'Picked'                                             */
/*          WHEN '7'    THEN  'Checked'                                            */
/*          WHEN '9'    THEN  'Shipped'                                            */
/*          WHEN 'CANC' THEN  'CANC'                                               */
/*                                                                                 */
/* Called By:                                                                      */
/*                                                                                 */
/* PVCS Version: 1.3                                                               */
/*                                                                                 */
/* Version: 5.4                                                                    */
/*                                                                                 */
/* Data Modifications:                                                             */
/*                                                                                 */
/* Updates:                                                                        */
/* Date         Author     Ver   Purposes                                          */
/* 19-Aug-2005  June             SOS39420 - IDSPH ULP v54 bug fixed                */
/*                                        - Change ULP status update               */
/* 06-Oct-2005  MaryVong         SOS41530 Create configkey 'ULPProcess' to         */
/*                               make use of status control done for ULP           */
/* 05-Dec-2008  Vicky            SOS#116248 - Create configkey 'ClusterPickStatus' */
/*                               to consider Status = 4  (Vicky01)                 */
/* 22-Oct-2010  Shong            CANC status cannot reverse back to 0 (SHONG01)    */
/* 04-Jan-2011  Leong      1.3   SOS#201333 - CANC status cannot reverse           */
/* 04-Apr-2013  Audrey     1.4   SOS#274791 - change int to decimal to cater       */
/*                               huge qty in gram                          (ang01) */
/* 11-Jul-2013  TLTING     1.5   Performance Tune                                  */
/* 31-Oct-2014  TLTING     1.4   Bug fix                                           */
/* 27-May-2016  NJOW01     1.5   Fix-calculate status not to incldue freegoodqty   */
/*                               if 'FREE GOODS ALLOCATION' not turn on            */
/* 11-Nov-2020  SHONG      1.6   Fixing Issues for CANC status change to 1         */
/***********************************************************************************/
CREATE PROC [dbo].[ispGetOrderStatus]
     @c_OrderKey     NVARCHAR(10)
   , @c_StorerKey    NVARCHAR(15)
   , @c_OrdType      NVARCHAR(10)
   , @c_NewStatus    NVARCHAR(10)   OUTPUT -- SOS24456, by June 24.June.2004 - change from NVARCHAR(1) to NVARCHAR(10)
   , @b_Success      int        OUTPUT
   , @n_err          int        OUTPUT
   , @c_errmsg       NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @n_continue int
SELECT @n_continue = 1

IF @n_continue=1 or @n_continue=2
BEGIN
   DECLARE
      @n_OpenQty       decimal,-- (ang01)
      @n_AllocatedQty  decimal,-- (ang01)
      @n_ShippedQty    decimal,-- (ang01)
      @n_QtyPicked     decimal,-- (ang01)
      @n_FreeGoodQty   decimal,-- (ang01)
      @n_ShortPickFlag INT, -- (Vicky01)
      @c_SOStatus      NVARCHAR(10)

   IF ISNULL(RTRIM(@c_OrderKey), '') = ''
      RETURN

   IF NOT EXISTS(SELECT 1 FROM ORDERDETAIL with (NOLOCK) WHERE Orderkey = @c_OrderKey)
      RETURN

   SELECT @n_OpenQty = SUM(CAST(openqty as DECIMAL)),-- (ang01)
          @n_AllocatedQty = SUM(CAST(qtyallocated as DECIMAL)),-- (ang01)
          @n_ShippedQty = SUM(CAST(ShippedQty as DECIMAL)),-- (ang01)
          @n_QtyPicked = SUM(CAST(qtypicked as DECIMAL)),-- (ang01)
          @n_FreeGoodQty = SUM(CAST(freegoodqty as DECIMAL))-- (ang01)
   FROM  ORDERDETAIL od (NOLOCK)
   WHERE Orderkey = @c_OrderKey

   SELECT @c_SOStatus = SOSTATUS
   FROM   ORDERS o WITH (NOLOCK)
   WHERE  o.OrderKey = @c_OrderKey

   IF @n_AllocatedQty IS NULL
      SELECT @n_AllocatedQty = 0
   IF @n_ShippedQty IS NULL
      SELECT @n_ShippedQty = 0
   IF @n_OpenQty IS NULL
      SELECT @n_OpenQty = 0
   IF @n_QtyPicked IS NULL
      SELECT @n_QtyPicked = 0
   IF @n_FreeGoodQty IS NULL
      SELECT @n_FreeGoodQty = 0

   --NJOW01
   IF NOT EXISTS(SELECT 1 FROM STORERCONFIG(NOLOCK) WHERE Storerkey = @c_Storerkey AND Configkey = 'FREE GOODS ALLOCATION' AND Svalue = '1')
   BEGIN
      SELECT @n_FreeGoodQty = 0
   END

   IF @c_OrdType = 'C'
   AND (SELECT svalue
        FROM STORERCONFIG (NOLOCK)
        WHERE Storerkey = @c_StorerKey
         AND  Configkey = 'WTS-ITF') = '1'
   BEGIN
      SELECT @c_NewStatus = CASE
         WHEN ((@n_OpenQty + @n_freegoodqty) > 0 AND (@n_shippedqty > 0) AND (@n_allocatedqty + @n_QtyPicked = 0)) THEN '0' -- Add by June 11.Jun.2004 : SOS24102
         WHEN ((@n_OpenQty + @n_FreeGoodQty) <> @n_AllocatedQty + @n_QtyPicked) AND (@n_ShippedQty = 0) THEN '1'
         WHEN ((@n_OpenQty + @n_FreeGoodQty) = (@n_AllocatedQty + @n_QtyPicked + @n_ShippedQty)) THEN '2'
         WHEN (@n_AllocatedQty > 0) AND (@n_QtyPicked > 0) AND (@n_AllocatedQty <> @n_QtyPicked) THEN '3'
         WHEN ((@n_OpenQty + @n_FreeGoodQty) > 0) AND (@n_QtyPicked > 0) and (@n_AllocatedQty = 0) THEN '5'
         WHEN (@n_ShippedQty > 0) THEN '9'
         WHEN (@n_openQty > 0) THEN '0'
         ELSE @c_NewStatus
         END
   END
   ELSE
   BEGIN
      -- SOS41530 -Start
      -- IF (SELECT svalue
      --     FROM STORERCONFIG (NOLOCK)
      --     WHERE Storerkey = @c_StorerKey
      --      AND  Configkey = 'ULPITF') = '1'
      IF EXISTS (SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE StorerKey = @c_StorerKey AND sValue = '1'
                               AND (ConfigKey = 'ULPITF' OR Configkey = 'ULPProcess') )
      -- End
      BEGIN
         SELECT @c_NewStatus = status
         FROM ORDERS (NOLOCK)
         WHERE Orderkey = @c_Orderkey

         -- SOS39420 - Trigger status update even Orders.Status is 3, 5 or 9
         -- IF @c_NewStatus NOT IN ('3','5','9')
            SELECT @c_NewStatus = CASE
            -- Start : SOS39420
            WHEN (@c_NewStatus = '9') THEN @c_NewStatus
            WHEN ((@n_OpenQty + @n_FreeGoodQty) > 0) AND (@n_QtyPicked > 0) and (@n_AllocatedQty = 0) AND @c_NewStatus < '5'  THEN '5'
            WHEN (@n_AllocatedQty > 0) AND (@n_QtyPicked > 0) AND (@n_AllocatedQty <> @n_QtyPicked) AND @c_NewStatus < '3' THEN '3'
            -- WHEN ((@n_OpenQty + @n_FreeGoodQty) = (@n_AllocatedQty + @n_QtyPicked + @n_ShippedQty)) THEN '2'
            WHEN ((@n_OpenQty + @n_FreeGoodQty) = (@n_AllocatedQty + @n_QtyPicked + @n_ShippedQty)) AND @c_NewStatus < '3' THEN '2'
            -- End : SOS39420
            WHEN ((@n_OpenQty + @n_FreeGoodQty) <> @n_AllocatedQty + @n_QtyPicked)
            AND (@n_AllocatedQty + @n_QtyPicked) > 0 -- Add by June 16.Mar.2004 SOS20468
            AND  @c_NewStatus < '3' -- SOS39420
            AND (@n_ShippedQty = 0) THEN '1'
            -- WHEN (@n_openQty > 0) THEN '0' -- SOS39420
            WHEN (@n_AllocatedQty + @n_ShippedQty + @n_QtyPicked = 0) THEN '0' -- SOS39420
            ELSE @c_NewStatus
            END
      END
      ELSE -- (Vicky01) - Start
      BEGIN
         IF EXISTS (SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE StorerKey = @c_StorerKey AND sValue = '1'
                                  AND ConfigKey = 'ClusterPickStatus')
         BEGIN
            IF EXISTS (SELECT 1 FROM PICKDETAIL (NOLOCK) WHERE Orderkey = @c_Orderkey
                       AND Status <= '4')
            BEGIN
               SET @n_ShortPickFlag = 1
            END
            ELSE
            BEGIN
               SET @n_ShortPickFlag = 0
            END

            SELECT @c_NewStatus =
            CASE
               WHEN (@c_NewStatus = '9') THEN @c_NewStatus
               WHEN (@n_AllocatedQty + @n_ShippedQty + @n_QtyPicked = 0) THEN '0'
               WHEN (@n_ShippedQty > 0) THEN '9'
               WHEN ((@n_OpenQty + @n_FreeGoodQty) > 0) AND (@n_QtyPicked > 0) and (@n_AllocatedQty = 0) AND @n_ShortPickFlag = 0 AND @c_NewStatus < '5'  THEN '5'
               --WHEN (@n_AllocatedQty > 0) AND (@n_QtyPicked > 0) AND (@n_AllocatedQty <> @n_QtyPicked) AND @c_NewStatus < '3' THEN '3'
               WHEN (@n_AllocatedQty > 0) AND (@n_QtyPicked > 0) AND @n_ShortPickFlag > 0 AND @c_NewStatus < '3' THEN '3'
               WHEN ((@n_OpenQty + @n_FreeGoodQty) <> @n_AllocatedQty + @n_QtyPicked) AND (@n_ShippedQty = 0) AND @c_NewStatus < '3' THEN '1'
               WHEN ((@n_OpenQty + @n_FreeGoodQty) = (@n_AllocatedQty + @n_QtyPicked + @n_ShippedQty)) AND @c_NewStatus < '3' THEN '2'
               ELSE @c_NewStatus
            END
         END  -- (Vicky01) - End
         ELSE
         BEGIN
            SELECT @c_NewStatus =
            CASE
               WHEN (@c_NewStatus = '9' OR @c_NewStatus = 'CANC' OR @c_SOStatus = 'CANC') THEN @c_NewStatus
               WHEN (@n_AllocatedQty + @n_ShippedQty + @n_QtyPicked = 0) AND
                    (@c_SOStatus <> 'CANC') -- Shong01
                    THEN '0'
               WHEN (@n_ShippedQty > 0) THEN '9'
               WHEN ((@n_OpenQty + @n_FreeGoodQty) > 0) AND (@n_QtyPicked > 0) and (@n_AllocatedQty = 0)
                     AND (@c_NewStatus < '5') THEN '5'
               WHEN (@n_AllocatedQty > 0) AND (@n_QtyPicked > 0) AND (@n_AllocatedQty <> @n_QtyPicked)
                     AND (@c_NewStatus < '3') THEN '3'
               WHEN ( (@n_OpenQty + @n_FreeGoodQty) <> @n_AllocatedQty + @n_QtyPicked ) AND
                      (@n_ShippedQty = 0) AND
                      (@n_AllocatedQty > 0) AND
                      (@c_NewStatus IN ('0','1','2') ) THEN '1'
               WHEN ((@n_OpenQty + @n_FreeGoodQty) = (@n_AllocatedQty + @n_QtyPicked + @n_ShippedQty))
                     AND (@c_NewStatus < '3') THEN '2'
               ELSE @c_NewStatus
            END
            -- SOS#201333 (End)
         END
      END
   END
END
END -- procedure

GO