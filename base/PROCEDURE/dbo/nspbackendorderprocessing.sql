SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  nspBackEndOrderProcessing                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Backend allocate orders                                     */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.12                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author      Purposes                                    */
/* 2002-08-05   Admin       Created                                     */
/* 2002-11-18   wkloo       Script sent by Ricky from IDSTW             */
/* 2002-11-18   wkloo       Script sent by Ricky from IDSTW             */
/* 2004-03-17   mvong       Added Drop Object                           */
/* 2004-04-20   wtshong     Bug fixing                                  */
/* 2004-04-28   wjtan       bug fixes                                   */
/* 2004-08-30   wtshong     Added Unilever Taiwan Transportation        */
/*                          Interface.                                  */
/* 2004-08-30   wtshong     Debug                                       */
/* 2004-10-11   admin       Modified by Shong                           */
/* 2006-11-27   wtshong     Change to cursor loop                       */
/* 2006-11-27   dhung       SOS63167 Fixed infinite loop and runtime    */
/*                          error when no order to allocate             */
/* 2010-06-24   GTGOH       SOS#175982 - Add in parameter for OrderType */
/*                          (GOH01)                                     */
/************************************************************************/

CREATE PROC [dbo].[nspBackEndOrderProcessing]  @c_StorerKey NVARCHAR(15)
													,@c_OrderType NVARCHAR(10) = ''	--GOH01
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_OrderCount int,
           @c_OrderKey   NVARCHAR(10),
           @b_Success    int ,
           @n_err        int,
           @c_errmsg     NVARCHAR(60)

   CREATE TABLE #ORD ( OrderKey NVARCHAR(10) )

   IF @c_storerkey = '%' 
   BEGIN 
      SET ROWCOUNT 10 
      INSERT INTO #ORD
      SELECT ORDERS.ORDERKEY
      FROM   ORDERS (NOLOCK)
      WHERE  ORDERS.STATUS = '0'
      AND    (ORDERS.ISSUED <> 'Y' OR ORDERS.ISSUED IS NULL)
      ORDER BY ORDERKEY 
   END 
   ELSE
   BEGIN
      IF @c_StorerKey <> 'UTL'
         SET ROWCOUNT 10 

      IF @c_StorerKey <> 'UTL'
      BEGIN
			IF RTRIM(ISNULL(@c_OrderType,'')) = ''	  --GOH01
			BEGIN  --GOH01
				INSERT INTO #ORD
				SELECT ORDERS.ORDERKEY
				FROM   ORDERS (NOLOCK)
				WHERE  ORDERS.STATUS = '0'
				AND    (ORDERS.ISSUED <> 'Y' OR ORDERS.ISSUED IS NULL)
				AND    ORDERS.StorerKey = @c_StorerKey 
				ORDER BY ORDERKEY 
			--GOH01 Start
			END
			ELSE
			BEGIN
				INSERT INTO #ORD
				SELECT ORDERS.ORDERKEY
				FROM   ORDERS (NOLOCK)
				WHERE  ORDERS.STATUS = '0'
				AND    (ORDERS.ISSUED <> 'Y' OR ORDERS.ISSUED IS NULL)
				AND    ORDERS.StorerKey = @c_StorerKey 
				AND	 ORDERS.TYPE = @c_OrderType	
				ORDER BY ORDERKEY 
			END
			--GOH01 End
      END 
      ELSE 
      BEGIN
         INSERT INTO #ORD
         SELECT ORDERS.ORDERKEY
         FROM   ORDERS (NOLOCK)
         WHERE  ORDERS.STATUS = '0'
         AND    (ORDERS.ISSUED <> 'Y' OR ORDERS.ISSUED IS NULL)
         AND    (ORDERS.OrderGroup = 'IMPORT')  
         AND    ORDERS.StorerKey = @c_StorerKey 
      END 

   END 
   
   SET ROWCOUNT 0

   SELECT @n_OrderCount = 1
   
   SELECT @c_OrderKey = ''
   
   WHILE @@TRANCOUNT > 0
      COMMIT TRAN 

   DECLARE C_OrderCursor CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT ORDERKEY
   FROM   #ORD
   ORDER BY ORDERKEY 

   OPEN C_OrderCursor

   FETCH NEXT FROM C_OrderCursor INTO @c_OrderKey 
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SELECT @b_Success = 1

      SELECT 'Processing Order ' + @c_OrderKey + ' Start at ' + CONVERT( NVARCHAR(20), GetDate())

      BEGIN TRAN

      EXEC nspOrderProcessing
           @c_OrderKey
      ,    ''
      ,    'N'
      ,    'N'
      ,    ''
      ,    @b_success OUTPUT
      ,    0
      ,    @c_errmsg OUTPUT
      IF @b_success <> 1
      BEGIN
         Select @c_errmsg = 'nspBackEndOrderProcessing :' + dbo.fnc_RTrim(@c_errmsg)
         ROLLBACK TRAN
         BREAK
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END      
      
      SELECT 'Processing Order ' + @c_OrderKey + ' End at ' + CONVERT( NVARCHAR(20), GetDate())

      BEGIN TRAN

      UPDATE ORDERS WITH (ROWLOCK) 
         SET STATUS = '1',
             TrafficCop = NULL
      WHERE  OrderKey =  @c_OrderKey
      AND    STATUS = '0'
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table ORDERS. (nspBackEndOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         ROLLBACK TRAN
         BREAK
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END
      
      BEGIN TRAN
      -- Update flag to processed
      UPDATE ORDERS WITH (ROWLOCK) 
         SET ISSUED = 'Y',
             TrafficCop = NULL
      WHERE  OrderKey =  @c_OrderKey
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table ORDERS. (nspBackEndOrderProcessing)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         ROLLBACK TRAN
         BREAK
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END
      
      SELECT @n_OrderCount = @n_OrderCount + 1


      -- Added By SHONG on 30-Aug-2004
      -- Unilever Taiwan interface 
      -- Begin       
--       DECLARE @n_QtyAllocated    int,
--               @c_XStorerKey      NVARCHAR(15) 
-- 
--       SELECT @c_XStorerKey = STORERKEY
--       FROM   ORDERS (NOLOCK)
--       WHERE  OrderKey = @c_OrderKey
--       
--       IF EXISTS(SELECT 1 FROM StorerConfig (NOLOCK) WHERE ConfigKey = 'UTLITF' AND sValue = '1'
--                 AND StorerKey = @c_XStorerKey )
--       BEGIN
--          SELECT @n_QtyAllocated = SUM(QtyAllocated) 
--          FROM   ORDERDETAIL (NOLOCK)
--          WHERE  OrderKey = @c_OrderKey
-- 
--          IF @n_QtyAllocated > 0 
--          BEGIN
--             EXEC ispGenTransmitLog2 'UTLALORD'
--             , @c_OrderKey           -- Key1
--             , ''                    -- Key2
--             , @c_XStorerKey         -- Key3
--             , ''
--             , @b_success OUTPUT
--             , @n_err OUTPUT
--             , @c_errmsg OUTPUT
--    
--             IF NOT @b_success=1
--             BEGIN
--                RAISERROR ('Generate Interface Record Failed.', 16, 1)
--                ROLLBACK TRANSACTION
--                BREAK 
--             END
--          END 
--       END -- UTLITF turn on
      -- End UTL Interface
      FETCH NEXT FROM C_OrderCursor INTO @c_OrderKey
   END -- while
END -- Procedure


GO