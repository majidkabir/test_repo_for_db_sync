SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************\
*   Modification Log                                                 *
*                                                                    *
*   Modify By SHONG 10-Jan-2004                                      *
*   Found Duplicate lines in Transmitlog                             *
*     - Insert checking                                              *
/* 28-Jan-2019  TLTING_ext 1.1 enlarge externorderkey field length      */
*                                                                    *
\********************************************************************/

CREATE  PROC [dbo].[nsp_InsertTransmitLog]
AS
BEGIN -- main proc
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
declare @c_key NVARCHAR(10),
	@c_line NVARCHAR(5),
	@d_date datetime,
	@c_externorderkey NVARCHAR(50),   --tlting_ext
	@c_XmitLogKey NVARCHAR(10),
	@b_success int,
	@n_err int,
	@c_errmsg NVARCHAR(250)

   DECLARE CUR_1 CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT 
          PICKDETAIL.orderkey, 
          PICKDETAIL.orderlinenumber, 
          CAST( CONVERT( NVARCHAR(20), GetDate(), 106) AS Datetime) AS SysTemDate,
		    ORDERS.ExternOrderKey
   FROM  PICKDETAIL WITH (NOLOCK, INDEX(PICKDETAIL10) )
         JOIN ORDERS (NOLOCK) ON ( ORDERS.OrderKey = PICKDETAIL.ORDERKEY )
   WHERE PICKDETAIL.Status = '9'
     AND PICKDETAIL.ShipFlag = 'Y'
     AND ORDERS.StorerKey = 'FUJI'
     AND ORDERS.ExternOrderKey NOT LIKE 'I%'
     AND ORDERS.ISSUED IS NULL
     AND NOT EXISTS( SELECT 1 FROM TRANSMITLOG WITH (NOLOCK, INDEX(IX_TRANSMITLOG01)) 
                      WHERE TableName = 'OrderDetail'
                      AND   PICKDETAIL.OrderKey = KEY1 
                      AND   PICKDETAIL.OrderLineNumber = KEY2 )
    ORDER BY PICKDETAIL.ORDERKEY
   
   OPEN CUR_1   
   FETCH NEXT FROM CUR_1 INTO @c_key, @c_line, @d_date, @c_externorderkey
   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM TRANSMITLOG WITH (NOLOCK, INDEX(IX_TRANSMITLOG01)) 
                      WHERE TableName = 'OrderDetail'
                      AND   KEY1 = @c_key
                      AND   KEY2 = @c_line)
      BEGIN
         EXECUTE   nspg_getkey
         "XmitLogKey"
         , 10
         , @c_XmitLogKey OUTPUT
         , @b_success OUTPUT
         , @n_err OUTPUT
         , @c_errmsg OUTPUT
      
         INSERT INTO TRANSMITLOG
               (transmitlogkey, tablename,    key1,   key2,   key3, transmitflag, transmitbatch, AddDate, AddWho, EditDate, EditWho)
         VALUES(@c_XmitLogKey,  "OrderDetail",@c_key, @c_line, @c_externorderkey,          "0", "Orders",      @d_date, "dbo",  @d_date,  "dbo")
      END
      FETCH next from cur_1 into @c_key, @c_line, @d_date, @c_externorderkey
   END -- WHILE
   CLOSE CUR_1
   DEALLOCATE CUR_1

-- Added By SHONG 
-- Date : 29th Nov 2000
-- Purpose: FUJI request a aknowledgement for Orders that IDS cannot process due to stock-out
--          To make this happen, User need to change the Extern Order Status (SOStatus) to "CLOSED".
-- Start
   DECLARE CUR2 CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT ORDERDETAIL.OrderKey, 
             ORDERDETAIL.OrderLinenumber, 
             ORDERDETAIL.EditDate, 
             ORDERS.externorderkey
      FROM   ORDERS WITH (NOLOCK)
             JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
      WHERE  ORDERS.StorerKey = 'FUJI'
      AND    ( ORDERS.SOStatus = '9' OR ORDERDETAIL.OpenQty = 0 )
      AND    ORDERS.ExternOrderKey NOT LIKE 'I%'
      AND    ORDERS.ISSUED IS NULL
      AND    (ORDERDETAIL.ShippedQty + ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked = 0)
      AND    NOT EXISTS( SELECT 1 FROM TRANSMITLOG WITH (NOLOCK ) 
                                  WHERE TableName = 'OrderDetail'
                                  AND   KEY1 = ORDERDETAIL.OrderKey
                                  AND   KEY2 = ORDERDETAIL.OrderLineNumber )

   OPEN CUR2
   
   FETCH NEXT FROM CUR2 INTO @c_key, @c_line, @d_date, @c_externorderkey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM TRANSMITLOG WITH (NOLOCK, INDEX(IX_TRANSMITLOG01)) 
                      WHERE TableName = 'OrderDetail'
                      AND   KEY1 = @c_key
                      AND   KEY2 = @c_line)
      BEGIN
         EXECUTE   nspg_getkey
         "XmitLogKey"
         , 10
         , @c_XmitLogKey OUTPUT
         , @b_success OUTPUT
         , @n_err OUTPUT
         , @c_errmsg OUTPUT
      
         IF @b_Success = 1
         BEGIN
            insert into transmitlog
            values(@c_XmitLogKey,"OrderDetail", @c_key, @c_line, @c_externorderkey,"0", "ClosedOrd", @d_date,"dbo",@d_date,"dbo",NULL,NULL)
         END
      END -- if not exists 
      FETCH NEXT FROM CUR2 into @c_key, @c_line, @d_date, @c_externorderkey
   END -- While
   CLOSE CUR2
   DEALLOCATE CUR2

-- to update key3 to externorderkey for those records not updated for some unknown reasons
   UPDATE TRANSMITLOG
      SET trafficcop = NULL, key3 = externorderkey
   FROM TRANSMITLOG, ORDERS (NOLOCK)
   WHERE TRANSMITLOG.key1 = ORDERS.orderkey
     AND key3 = ''
     AND ORDERS.ExternOrderKey not like 'I%'
-- End Modification 28th Nov 2000

END -- main proc

GO