SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : isp_Ship_Confirm  		                                 */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Retrieve Pack Detail for TBL Interface 							*/
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: 	DTSITF.dbo.isp0102P_RG_TBL_SO_Export				         */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2008-Apr-21  Shong			Getting from Taiwan Live                  */
/* 2010-Jun-21	 GTGOH			SOS#175992 Add parameter TBLType for TBL-DT*/
/*                            (GOH01)                                   */
/* 08-04-2011   GTGOH         SOS#175992 Partial allocation might have  */
/*                            line without pickdetail, result to mapping*/
/*                            change from PICKDETAIL to ORDERDETAIL for */
/*                            Order Type=TBL-DT (GOH02)                 */
/* 2011-May-30  SPChin        SOS217101 - Change to cater same SKU in   */
/*                                        multiple order line           */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/
CREATE proc [dbo].[isp_Ship_Confirm](
   @c_orderkey NVARCHAR(10)
   ,@c_TBLType  NVARCHAR(10) = ''	--GOH01
)
as
begin
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
      
   CREATE TABLE #result(
      labelno        NVARCHAR(20),
      cartonno       int null,
      labelline      NVARCHAR(5) null,
      storerkey      NVARCHAR(15) null,
      sku            NVARCHAR(20) null,
      qty            int null,
      pickslipno     NVARCHAR(10) null,
      externorderkey NVARCHAR(50) null,  --tlting_ext
      externlineno   NVARCHAR(10) null,
      retailsku      NVARCHAR(20) null,
      altsku         NVARCHAR(20) null,
      originalqty    int null,
      userdefined01  NVARCHAR(18) null,
      userdefined02  NVARCHAR(18) null,
      manufacturersku NVARCHAR(20) null,
      tax01          float(8) null,
      tax02          float(8) null,
      userdefined08  NVARCHAR(18) null,
      editdate       datetime null,
      adddate        datetime null,
   )
   
   declare @c_pickslipno NVARCHAR(10)
   
   select distinct @c_pickslipno = pickheaderkey
   from pickheader (nolock)
   where orderkey = @c_orderkey
   
   	insert into #result(labelno, cartonno, labelline, storerkey, sku, qty, pickslipno, editdate, adddate)
		select orders.userdefine04 , 
			packdetail.cartonno, '001', 
			orders.storerkey, orderdetail.sku, 
			isnull(sum(pickdetail.qty),0), 
			packdetail.pickslipno, 
			max(orderdetail.editdate), 
		   max(orderdetail.adddate)  
		from orders with (nolock) 
		join orderdetail with (nolock) on (orders.orderkey = orderdetail.orderkey)
		join sku with (nolock) on (orderdetail.storerkey = sku.storerkey and orderdetail.sku = sku.sku) 
		join pickdetail with (nolock) on (orderdetail.orderkey = pickdetail.orderkey 
			and orderdetail.orderlinenumber = pickdetail.orderlinenumber)
		left join packheader with (nolock) on  (orders.orderkey = packheader.orderkey) 
		left join packdetail with (nolock) on (packheader.pickslipno = packdetail.pickslipno and orderdetail.SKU =packdetail.SKU) 
		where orders.orderkey = @c_orderkey
		and orders.type = @c_TBLType
		group by orders.userdefine04, 
			packdetail.cartonno, packdetail.labelline , 
			orders.storerkey, orderdetail.sku, 
			packdetail.pickslipno, orderdetail.editdate, 
		   orderdetail.adddate, orders.type  
      Union
		select packdetail.labelno, 
			packdetail.cartonno, packdetail.labelline, 
			orders.storerkey, orderdetail.sku, 
			isnull(sum(packdetail.qty),0), 
			packdetail.pickslipno, max(packdetail.editdate), max(packdetail.adddate) 
		from orders with (nolock) 
		join (Select Storerkey,Orderkey,SKU from orderdetail with (nolock) 
            where orderdetail.orderkey = @c_orderkey
            group by Storerkey,Orderkey,SKU) as orderdetail on (orders.orderkey = orderdetail.orderkey)  --SOS217101		
		--join orderdetail with (nolock) on (orders.orderkey = orderdetail.orderkey) --SOS217101
		join sku with (nolock) on (orderdetail.storerkey = sku.storerkey and orderdetail.sku = sku.sku) 
--		left join pickdetail with (nolock) on (orderdetail.orderkey = pickdetail.orderkey 
--			and orderdetail.orderlinenumber = pickdetail.orderlinenumber)
		left join packheader with (nolock) on  (orders.orderkey = packheader.orderkey) 
		join packdetail with (nolock) on (packheader.pickslipno = packdetail.pickslipno and orderdetail.SKU =packdetail.SKU) 
		where orders.orderkey = @c_orderkey
		--and ISNULL(packdetail.labelno,'') <> ''
		and orders.type <> @c_TBLType
		group by packdetail.labelno, 
			packdetail.cartonno, packdetail.labelline , 
			orders.storerkey, orderdetail.sku, 
			packdetail.pickslipno, packdetail.editdate, 
		   packdetail.adddate, orders.type  
		
   update #result
   set externorderkey = orderdetail.externorderkey,
       externlineno = orderdetail.externlineno,
       retailsku = sku.retailsku,
       altsku = orderdetail.altsku,
       originalqty = orderdetail.originalqty,
       userdefined01 = orderdetail.userdefine01,
       userdefined02 = orderdetail.userdefine02,
       manufacturersku = orderdetail.manufacturersku,
       tax01 = orderdetail.tax01,
       tax02 = orderdetail.tax02,
       userdefined08 = orderdetail.userdefine08
   from #result
   Join orderdetail (nolock) on #result.sku = orderdetail.sku 
   Join sku (nolock) on orderdetail.storerkey = sku.storerkey and orderdetail.sku = sku.sku
   where orderdetail.orderkey = @c_orderkey
   
   SELECT * FROM #result
   
   DROP TABLE #result

end



GO