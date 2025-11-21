SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispProcessOrders                                   */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Auto Allocation/Pre-Allocation for E1 Orders                */
/*                                                                   	*/
/*                                                                      */
/* Called By: isp0036P_RG_E1_Import                                     */ 
/*                                                                      */
/* Parameters:  None                                                    */
/*                                                                      */
/* PVCS Version: 1.0	                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 03-Jan-2008  Shong      Proceed with Pre-allocation if No records    */
/*                         Found for Allocate Orders OWORDPRC SOS#89405 */
/* 21-Jul-2017  TLTING     SET Option                                   */
/************************************************************************/
CREATE PROCEDURE [dbo].[ispProcessOrders] 
AS
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @c_OrderKey NVARCHAR(10)
DECLARE @b_success int
DECLARE @c_TransmitLogKey NVARCHAR(10),
        @n_Continue int, 
        @c_NewTransmitLogKey NVARCHAR(10)

-- Added By SHONG on 02-01-2004
-- To have better manage of Commit and Rollback trans
DECLARE @n_starttcnt int
DECLARE @n_ProcessedOrder int,
        @n_MaxOrderAllocPerBatch int,
        @n_err int,
        @n_cnt int

SELECT @c_OrderKey = SPACE(10)
-- Allocation for UserDefine08 type 2

SELECT @n_Continue = 1

IF NOT EXISTS (SELECT 1 FROM TransmitLog (NOLOCK) WHERE TableName = 'OWORDPRC'
AND   TransmitFlag IN ('0', '1'))
BEGIN
   -- SOS#89405
   -- SELECT @n_Continue = 3
   GOTO DO_PREALLOCATION
END

SELECT @n_MaxOrderAllocPerBatch = 0
SELECT @n_MaxOrderAllocPerBatch = CASE WHEN ISNUMERIC(NSQLValue) = 1 
                                       THEN Cast(NSQLValue as int)
                                       ELSE 0
                                  END
FROM   nSQLConfig (NOLOCK)
WHERE  ConfigKey = 'OW_AutoAlloc_MaxOrdPerBatch'

IF @n_Continue = 1 OR @n_Continue = 2
BEGIN
   BEGIN TRANSACTION

   UPDATE TransmitLog
   SET TransmitFlag = '1'
   WHERE TableName = 'OWORDPRC'
   AND   TransmitFlag = '0'

   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
      ROLLBACK TRANSACTION
      SELECT @n_Continue = 3
   END
ELSE
   BEGIN
      COMMIT TRAN
   END
END

IF @n_Continue = 1 OR @n_Continue = 2
BEGIN
   SELECT @n_ProcessedOrder = 0

   -- Modified By SHONG on 31th Jul 2003
   -- SOS# 12800 Request to change auto allocation waiting time from 30 minutes to 10 minutes
   DECLARE C_AllocateOrder CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT Key1, TransmitLogKey 
      FROM   TransmitLog (NOLOCK)
      WHERE TableName = 'OWORDPRC'
      AND   TransmitFlag = '1'
      AND   DateDiff(minute, AddDate, GetDate()) > 10
      ORDER BY KEY1

   OPEN C_AllocateOrder

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_AllocateOrder INTO @c_OrderKey, @c_TransmitLogKey  

      IF @@FETCH_STATUS <> 0
         BREAK

      IF @n_ProcessedOrder > @n_MaxOrderAllocPerBatch AND @n_MaxOrderAllocPerBatch > 0
         BREAK

      -- Added By SHONG 19th June 2002
      -- Make sure orderdetail is exists before it doing any allocation
      IF EXISTS( SELECT 1 FROM ORDERDETAIL (NOLOCK) WHERE OrderKey = @c_OrderKey)
      BEGIN
         SELECT @n_starttcnt=@@TRANCOUNT

         BEGIN TRANSACTION

         EXECUTE nspOrderProcessing  @c_OrderKey,'','N','N','',@b_success OUTPUT,0,''

         IF @b_success = 1
         BEGIN
            -- SOS 7005
            -- commented by wally 8.aug.02
            -- should be updated  after the insert into transmitlog
            -- UPDATE TRANSMITLOG
            --    SET TransmitFlag = '9'
            --  WHERE TableName = 'OWORDPRC'
            --    AND   Key1 = @c_OrderKey
            --    AND   TransmitFlag = '1'

            -- Added By SHONG on 24th Feb 2003
            -- Create Email Alert for OW Order Auto allocation
            IF EXISTS (SELECT OrderKey FROM ORDERDETAIL (NOLOCK) WHERE Orderkey = @c_Orderkey
                       Group By OrderKey
                       Having SUM(Qtyallocated) < SUM(OpenQty) )
            BEGIN
               INSERT INTO ErrLog (ErrorID, SystemState, Module, ErrorText)
               VALUES (8888, '0', 'ispProcessOrders', @c_OrderKey)
            END

            IF NOT EXISTS( SELECT 1 FROM TRANSMITLOG (NOLOCK) WHERE TableName = 'OWORDALLOC' AND Key1 = @c_OrderKey)
            BEGIN
               /* Start - Add by June 8.Mar.02 - Create 'OWORDALLOC' record for Order Type2 */
               SELECT @b_success = 0
               EXECUTE nspg_getkey
               'TransmitlogKey'
               ,10
               , @c_NewTransmitLogKey OUTPUT
               , @b_success OUTPUT
               , 0
               , ''
               IF @b_success = 1
               BEGIN
                  -- Modify by SHONG
                  -- Date: 17 May 2002
                  -- SOS# 5820
                  INSERT INTO TRANSMITLOG(transmitlogkey, tablename, key1, key2, key3, transmitflag, transmitbatch)
                  VALUES(@c_NewTransmitLogKey, 'OWORDALLOC', @c_OrderKey, '', '', '0', '')
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                  END

                  -- SOS 7005
                  -- wally 8.aug.02
                  -- updates the transmitflag right after insert into transmitlog
                  -- to ensure that order was indeed allocated
                  UPDATE TRANSMITLOG WITH (ROWLOCK) 
                  SET TransmitFlag = '9'
                  WHERE TableName = 'OWORDPRC'
                  AND   Key1 = @c_OrderKey
                  AND   TransmitFlag = '1'
                  AND   TransmitLogKey = @c_TransmitLogKey

                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                  END

                  SELECT @n_ProcessedOrder = @n_ProcessedOrder + 1
                  -- SOS# 5820
                  -- Comment By SHONG
                  -- This step was taking care by DX Macro
                  --EXECUTE ispExe2OW_allocpickship
               END
               /* End - Add by June 8.Mar.02 - Create 'OWORDALLOC' record for Order Type2 */
            END
            ELSE -- Added By SHONG on 29-Dec-2003, if OWORDALLOC exists in transmitlog, update to 9
            BEGIN
               UPDATE TRANSMITLOG
               SET TransmitFlag = '9'
               WHERE TableName = 'OWORDPRC'
               AND   Key1 = @c_OrderKey
               AND   TransmitFlag = '1'
               AND   TransmitLogKey = @c_TransmitLogKey

               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_Continue = 3
               END
            END
            -- END -- QtyAllocated > 0 -- Add by June 12.Jun.02
         END -- if @b_success = 1
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
         END
         ELSE
         BEGIN
            SELECT @b_success = 1
            WHILE @@TRANCOUNT > @n_starttcnt
            BEGIN
               COMMIT TRAN
            END
         END
      END -- if exists order lines
   END
   CLOSE C_AllocateOrder
   DEALLOCATE C_AllocateOrder
END -- if continue = 1
-- Added by SHONG 03 Jul 2002
-- Update the flag to '5' where Order can't allocate and more then 2 days
UPDATE TRANSMITLOG
SET TransmitFlag = '5'
WHERE TableName = 'OWORDPRC'
AND   TransmitFlag = '1'
AND   DateDiff(day, Adddate, GetDate()) > 2
-- end

DO_PREALLOCATION:

SELECT @n_Continue = 1
IF NOT EXISTS (SELECT 1 FROM TransmitLog (NOLOCK) WHERE TableName = 'OWPREALLOC'
AND   TransmitFlag IN ('0', '1'))
BEGIN
   SELECT @n_Continue = 3
END

SELECT @c_OrderKey = SPACE(10)

IF  @n_Continue = 1 OR  @n_Continue = 2
BEGIN
   -- PreAllocation for UserDefine08 type 4
   UPDATE TransmitLog
   SET TransmitFlag = '1'
   WHERE TableName = 'OWPREALLOC'
   AND   TransmitFlag = '0'
END

IF  @n_Continue = 1 OR @n_Continue = 2
BEGIN
   -- Modified By SHONG on 31th Jul 2003
   -- SOS# 12800 Request to change auto allocation waiting time from 30 minutes to 10 minutes

   DECLARE C_PreAlloc_Order CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT Key1, TransmitLogKey 
      FROM   TransmitLog (NOLOCK)
      WHERE TableName = 'OWPREALLOC'
      AND   TransmitFlag = '1'
      AND   DateDiff(minute, AddDate, GetDate()) > 10
      ORDER BY Key1 

   OPEN C_PreAlloc_Order

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_PreAlloc_Order INTO @c_OrderKey, @c_TransmitLogKey 

      IF @@FETCH_STATUS <> 0
         BREAK

      -- Added By SHONG 19th June 2002
      -- Make sure orderdetail is exists before it doing any allocation
      IF EXISTS( SELECT 1 FROM ORDERDETAIL (NOLOCK) WHERE OrderKey = @c_OrderKey)
      BEGIN
         SELECT @b_success = 1
         EXECUTE nspPreallocateOrderProcessing  @c_OrderKey,'', '','N','N','',@b_success,0,''

         IF @b_success = 1
         BEGIN
            IF EXISTS (SELECT 1 FROM ORDERDETAIL (NOLOCK) WHERE Orderkey = @c_Orderkey And QtyPreAllocated > 0)
            BEGIN  -- End Add by Shong 19.Jun.02
               UPDATE TRANSMITLOG WITH (ROWLOCK) 
               SET TransmitFlag = '9'
               WHERE TableName = 'OWPREALLOC'
               AND   Key1 = @c_OrderKey
               AND   TransmitFlag = '1'
               AND   TransmitLogKey = @c_TransmitLogKey
            END
         END
      END -- if exists order lines
   END -- while
   CLOSE C_PreAlloc_Order
   DEALLOCATE C_PreAlloc_Order
END -- if continue = 1

GO