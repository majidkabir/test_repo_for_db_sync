SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/* author: Tiz  
   date:   2015-05-21  
   purpose: Move inventory before allocation

   CHANGED : stvL change to uccal project
   V0.1: Avaiable qty
   V0.2: Add SKU.busr5 at #OrderSum
   v0.3: Add Orders.orderkey at #OrderSum
   
   author: Michael 
   date:   2020-08-07
   DATE				NAME		VER		PURPOSE
   15-08-2023	   Alex Wang    1.6	    [CN] Speedo Replenishment SP Move to CNWMSCUBE	https://jiralfl.atlassian.net/browse/WMS-23374
*/  

-- exec  [nsp_Speedo_Check_Order_level]

CREATE   proc [dbo].[nsp_Speedo_Check_Order_level]

as  
IF OBJECT_ID('tempdb..#OrderSum','u') IS NOT NULL  DROP TABLE #OrderSum;
CREATE TABLE #OrderSum  
(TotalOpenQty  int,    
 storerkey  nvarchar(10),    
 sku  nvarchar(20),
 busr5 nvarchar(30),
 orderkey nvarchar(30)
 )  

IF OBJECT_ID('tempdb..#InvByLocLevel','u') IS NOT NULL  DROP TABLE #InvByLocLevel;
CREATE TABLE #InvByLocLevel
(LocLevel  nvarchar(5),    
 storerkey  nvarchar(10), 
 UCCNO nvarchar(30),
 sku  nvarchar(20),
 UCC# nvarchar(30),
 Loc nvarchar(10),
 UCCQty int,
 Lottable05 nvarchar(30)
 )  

INSERT INTO #OrderSum  
(TotalOpenQty,storerkey,sku,busr5)  
SELECT sum(openqty),ORD.storerkey,ORD.sku,SK.busr5
FROM DBO.orderdetail ORD(nolock)
JOIN DBO.SKU SK(nolock) ON ORD.sku=SK.sku and ORD.storerkey=SK.storerkey
WHERE ORD.storerkey='SPEEDO' and ORD.facility='BTS03' and status='0' 
--and sk.sku = '5051746686978'
AND isnull(ORD.loadkey,'') <> '' 
GROUP BY ORD.storerkey,ORD.sku,SK.busr5

INSERT INTO #InvByLocLevel
(LocLevel,storerkey,sku,UCCNO,UCC#,Loc,UCCQty,Lottable05)
 SELECT b.LocLevel,a.storerkey,a.sku,f.uccno,
 case when isnull(a.id,'')='' then N'此Level2库位无ID/UCC,请核实!' else isnull(a.id,'')end as [箱号],
 a.Loc,f.qty, CONVERT(varchar(100), g.Lottable05, 111)as Lottable05
 FROM DBO.lotxlocxid a(nolock)
 JOIN DBO.loc b(nolock) on a.loc=b.loc
 JOIN DBO.ucc f (nolock) on a.storerkey = f.storerkey and a.sku = f.sku and a.loc = f.loc --and f.uccno = '00250537440005990711'
 JOIN DBO.LOTATTRIBUTE g (nolock) on a.storerkey=g.storerkey and a.sku=g.sku and a.lot=g.lot
 WHERE a.storerkey='SPEEDO' and b.facility='BTS03' and b.loclevel='2'
   
SELECT aa.storerkey,aa.orderkey,cc.UCCNO,
	case when isnull(cc.UCC#,'')='' then N'Level2也无库存' else cc.UCC# end as [箱号],
	case when isnull(cc.loc,'')='' then N'Level2也无库存' else cc.loc end as [Fromloc],
	case when isnull(cc.UCCQty,'')='' then 0 else cc.UCCQty end as [Avaiable Qty],
	aa.sku,
	aa.busr5,
	aa.TotalOpenQty as[所有订单总数BySKU],
	isnull(bb.TotalQty,0)[Level1库存总数BySKU],
	(aa.TotalOpenQty-isnull(bb.TotalQty,0))as [缺失数BySKU],
	 CC.Lottable05
FROM #OrderSum aa(nolock) 
LEFT JOIN (select sum(qty-qtyallocated-qtypicked) as TotalQty,sku,storerkey
FROM DBO.skuxloc a(nolock) 
JOIN DBO.loc b(nolock) on (a.loc=b.loc)
WHERE a.storerkey='SPEEDO' and loclevel='1' 
GROUP BY a.sku,a.storerkey
having sum(qty-qtyallocated-qtypicked)>0) bb 
	on aa.storerkey=bb.storerkey and aa.sku=bb.sku
LEFT JOIN #InvByLocLevel cc(nolock) 
on aa.storerkey=cc.storerkey and aa.sku=cc.sku
WHERE TotalOpenQty>isnull(bb.TotalQty,0) 

GO