SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE [dbo].[isp_PrtFujiDO_FromArchive]
	@c_StartOrderKey NVARCHAR(10),
	@c_EndOrderKey   NVARCHAR(10)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
        declare @c_serialno NVARCHAR(18),
                @c_sum_serialno NVARCHAR(255),
                @c_orderkey NVARCHAR(10),
                @c_orderlineno NVARCHAR(5)   
     
SELECT   Archive..ORDERDETAIL.Sku,   
         SKU.DESCR,   
         Qty=SUM(Archive..PICKDETAIL.Qty),   
         Archive..ORDERDETAIL.UOM, 
         Archive..ORDERS.StorerKey,  
         Archive..ORDERS.OrderKey,   
         Archive..ORDERS.ExternOrderKey,   
         Archive..ORDERS.DeliveryDate,   
         consignee=substring(Archive..ORDERS.ConsigneeKey,1,11),   
         Archive..ORDERS.C_Company,   
         Archive..ORDERS.C_Address1,   
         Archive..ORDERS.C_Address2,   
         Archive..ORDERS.C_Address3,   
         Archive..ORDERS.C_Address4,   
         Archive..ORDERS.C_Zip,   
         Archive..ORDERS.BuyerPO,   
         Archive..ORDERS.B_Company,   
         Archive..ORDERS.B_Address1,   
         Archive..ORDERS.B_Address2,   
         Archive..ORDERS.B_Address3,   
         Archive..ORDERS.B_Address4,   
         Archive..ORDERS.B_Zip,   
         Archive..ORDERS.PmtTerm,   
         Archive..ORDERS.DeliveryPlace,   
         Archive..ORDERS.Stop,  
         Archive..ORDERS.Salesman,
	 STORER.CreditLimit,
         LOTATTRIBUTE.Lottable01,
         LOTATTRIBUTE.Lottable02,
	 Archive..ORDERDETAIL.OrderLineNumber,
         Archive..ORDERDETAIL.ExternLineNo,
	 Archive..MBOL.EditDate,
	 note1=CONVERT(NVARCHAR(250), Archive..ORDERS.Notes),
	 note2=CONVERT(NVARCHAR(250), Archive..ORDERS.Notes2),
         Archive..ORDERDETAIL.MbolKey,
	 Archive..ORDERS.Printflag,
	 SKU.MANUFACTURERSKU,
         serialno=space(255)
         into #result
    FROM Archive..ORDERDETAIL(nolock),   
         Archive..ORDERS(nolock),   
         SKU (nolock),
         STORER (nolock),
         Archive..PICKDETAIL (nolock),
         LOTATTRIBUTE(nolock),
         Archive..MBOL(nolock)
   WHERE ( Archive..ORDERDETAIL.OrderKey = Archive..ORDERS.OrderKey ) and  
         ( Archive..ORDERDETAIL.Sku = SKU.Sku ) and
	 ( Archive..ORDERS.ConsigneeKey = STORER.StorerKey ) and
	 ( Archive..PICKDETAIL.OrderKey = Archive..ORDERDETAIL.OrderKey ) and
         ( LOTATTRIBUTE.SKU = Archive..PICKDETAIL.Sku ) and
         ( LOTATTRIBUTE.Lot = Archive..PICKDETAIL.Lot ) and
	 ( SKU.Sku = LOTATTRIBUTE.Sku ) and
	 ( Archive..ORDERS.ExternOrderKey between @c_StartOrderKey and @c_EndOrderKey ) and
	 ( Storer.Email2='Fuji') and
	 ( Archive..MBOL.MbolKey = Archive..ORDERDETAIL.MbolKey ) and
	 ( Archive..PICKDETAIL.OrderLineNumber = Archive..ORDERDETAIL.OrderLineNumber ) and
	 ( Archive..PICKDETAIL.OrderKey = Archive..ORDERDETAIL.OrderKey ) and
	 ( Archive..PICKDETAIL.Sku = Archive..ORDERDETAIL.SKu ) 
GROUP BY Archive..ORDERDETAIL.Sku,   
         Archive..ORDERDETAIL.Lottable01,
         SKU.DESCR,      
         Archive..ORDERDETAIL.UOM, 
	 Archive..ORDERS.StorerKey,  
         Archive..ORDERS.OrderKey,   
         Archive..ORDERS.OrderKey,   
         Archive..ORDERS.ExternOrderKey,   
         Archive..ORDERS.DeliveryDate,   
         substring(Archive..ORDERS.ConsigneeKey,1,11),   
         Archive..ORDERS.C_Company,   
         Archive..ORDERS.C_Address1,   
         Archive..ORDERS.C_Address2,   
         Archive..ORDERS.C_Address3,   
         Archive..ORDERS.C_Address4,   
         Archive..ORDERS.C_Zip,   
         Archive..ORDERS.BuyerPO,   
         Archive..ORDERS.B_Company,   
         Archive..ORDERS.B_Address1,   
         Archive..ORDERS.B_Address2,   
         Archive..ORDERS.B_Address3,   
         Archive..ORDERS.B_Address4,   
         Archive..ORDERS.B_Zip,   
         Archive..ORDERS.PmtTerm,   
         Archive..ORDERS.DeliveryPlace,   
         Archive..ORDERS.Stop,  
         Archive..ORDERS.Salesman,
	 STORER.CreditLimit,
         LOTATTRIBUTE.Lottable01,
         LOTATTRIBUTE.Lottable02,
	 Archive..ORDERDETAIL.OrderLineNumber,
         Archive..ORDERDETAIL.ExternLineNo,
	 Archive..MBOL.EditDate,
	 CONVERT(NVARCHAR(250), Archive..ORDERS.Notes),
	 CONVERT(NVARCHAR(250), Archive..ORDERS.Notes2),
         Archive..ORDERDETAIL.MbolKey,
	 Archive..ORDERS.Printflag,
	 SKU.MANUFACTURERSKU     
	 ORDER BY Archive..ORDERDETAIL.ExternLineNo



declare cur1 cursor FAST_FORWARD READ_ONLY
for
select orderkey, orderlinenumber from #result(nolock)


open cur1

fetch next from cur1 into @c_orderkey, @c_orderlineno

while(@@fetch_status=0)
   begin
      declare cur2 cursor FAST_FORWARD READ_ONLY
      for 
      select serialno from serialno
      where orderkey = @c_orderkey
      and orderlinenumber = @c_orderlineno

      open cur2
   
      fetch next from cur2 into @c_serialno

      while (@@fetch_status=0)
         begin

            set @c_sum_serialno = @c_sum_serialno+ dbo.fnc_RTrim(@c_serialno) + ', '
            set @c_serialno = ""

            fetch next from cur2 into @c_serialno
         end

      close cur2
      deallocate cur2
      
      if len(@c_sum_serialno)>0
         set @c_sum_serialno = substring(@c_sum_serialno,1,len(@c_sum_serialno)-1)

      update #result
      set serialno = dbo.fnc_LTrim(@c_sum_serialno)
      where orderkey = @c_orderkey
      and orderlinenumber = @c_orderlineno

      set @c_sum_serialno = ""
      fetch next from cur1 into @c_orderkey, @c_orderlineno
   end

close cur1
deallocate cur1



select * from #result

drop table #result


GO