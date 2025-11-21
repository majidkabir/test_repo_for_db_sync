SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[isp_export_header_model]
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	SELECT 'H' 'RecordType',
		Convert(NVARCHAR(10), OrderS.Orderkey )'UpIDHeaderID',
		total.lineshipped 'Linesshipped',
		Convert(NVARCHAR(20), ORDERS.ExternOrderKey) 'ExternOrderkey',   
         	convert(NVARCHAR(10), ORDERS.OrderGroup) 'OrderGroup',   
		REPLACE(dbo.fnc_LTrim(dbo.fnc_RTrim(convert(NVARCHAR(11), convert(datetime, B_Fax2, 103), 106))), ' ', '-') 'DeliveryDate', 
         	REPLACE(dbo.fnc_LTrim(dbo.fnc_RTrim(convert(NVARCHAR(11), PICKINGINFO.ScanOutDate, 106))), ' ', '-') 'ScanOutDate',
		'' 'ExpectedArrivalDate',
		' ' 'Transactiontype',
		'N' 'OpenFlag',
		'' 'FreightAmount',
		'' 'VATAmount',
		'' 'NoofBoxes',
		Convert(NVARCHAR(10), orders.LoadKey) 'DN'
   from orders (nolock) join transmitlog (nolock)
      on orders.orderkey = transmitlog.key1
         and tablename = 'PICK'
         and transmitflag = '0'
         and substring(orders.type,1,1) = 'M'
   join pickinginfo (nolock)
      on pickinginfo.pickslipno = transmitlog.key3
   join (select o.externorderkey, count(*) as lineshipped
         from orderdetail od (nolock) join orders o (nolock)
            on od.orderkey = o.orderkey
         join transmitlog t (nolock)
            on o.orderkey = t.key1
               and tablename = 'PICK'
               and transmitflag = '0'
               and substring(o.type,1,1) = 'M'
         where (qtypicked+shippedqty) > 0
         group by o.externorderkey ) as total
      on orders.externorderkey = total.externorderkey
END

GO