SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE  [dbo].[nspExportAlControl] -- drop proc nspExportAlControl
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @c_alloc NVARCHAR(10),
   @n_orderline int ,
   @n_hashtot int, 
   @c_adddate NVARCHAR(8)
   
   DECLARE @n_count int, 
           @n_continue int, 
           @b_success int, 
           @n_err int,  
           @c_errmsg   NVARCHAR(250),
           @c_batchno int
           
   SELECT ALLOC=count(distinct orderdetail.orderkey),
   Orderline = count(orderdetail.externlineno),
   Hashtot = sum(orderdetail.qtyallocated/PACK.CASECNT),
   Adddate =  RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, getdate()))),4) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, getdate()))),2) +
   RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, getdate()))),2) ,
   Batchno = Ncounter.keycount
   INTO #temp
   FROM ORDERDETAIL (NOLOCK),
   ORDERS (NOLOCK),
   TRANSMITLOG (NOLOCK),
   PACK (NOLOCK),
   ncounter (NOLOCK)
   WHERE  ORDERDETAIL.OrderKey = ORDERS.OrderKey
   AND   Orderdetail.qtyallocated > 0
   AND   Orders.Orderkey = Orderdetail.Orderkey
   AND   Orderdetail.Orderlinenumber  = Transmitlog.Key2
   AND   Transmitlog.Key1=Orderdetail.Orderkey
   AND   Transmitlog.Transmitflag = '0'
   AND   Transmitlog.TableName = 'Orders'
   AND   Orderdetail.qtypicked+orderdetail.shippedqty = 0
   AND   PACK.Packkey = 'U'+Orderdetail.SKU
   AND   Ncounter.Keyname = 'ALBatch'
   AND   Orders.Externorderkey Not in (select distinct externorderkey from orderdetail (nolock)
                                       where externorderkey is not null and qtypicked+shippedqty > 0
                                       group by  externorderkey
                                       having count (*) > 1)
   GROUP BY ORDERDETAIL.ExternOrderKey,
   ORDERS.BILLTOKEY,
   ORDERDETAIL.ExternLineNo ,
   ORDERDETAIL.Sku,
   ORDERDETAIL.EditDate,
   ORDERS.DeliveryDate,
   ORDERS.OrderDate,
   PACK.Casecnt,NCounter.Keycount

   SELECT   @c_alloc  =alloc,
   @n_orderline = orderline,
   @n_hashtot = hashtot,
   @c_adddate = adddate ,
   @c_batchno = batchno
   FROM #temp, ncounter (NOLOCK) 
   WHERE ncounter.keyname = 'ALbatch'
   GROUP BY alloc,orderline,hashtot,ADDDATE,batchno
   
   SELECT @c_alloc,@n_orderline, @n_hashtot,@c_adddate,@c_batchno
   SET rowcount 1
   BEGIN
      EXEC nspg_getkey 'ALbatch', 10, @c_batchno OUTPUT, @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT

   END
   DROP TABLE #temp
END



GO