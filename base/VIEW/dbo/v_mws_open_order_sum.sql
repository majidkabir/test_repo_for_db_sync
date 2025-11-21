SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_MWS_OPEN_ORDER_SUM] AS (
select o.storerkey Storerkey , o.loadkey LoadKey,o.type OrdType, o.ordergroup OrdGrp,
CONVERT(VARCHAR(19),max(od.editdate),120) LastActivityDate, o.orderkey,
count(*) NumOrdLines, count(distinct(od.sku)) NumSkus, min(o.status) OrdStatus,
count((case od.status WHEN '0' THEN od.orderlinenumber ELSE NULL END)) S_0,
count((case od.status WHEN '1' THEN od.orderlinenumber ELSE NULL END)) S_1,
count((case od.status WHEN '2' THEN od.orderlinenumber ELSE NULL END)) S_2,
count((case od.status WHEN '3' THEN od.orderlinenumber ELSE NULL END)) S_3,
count((case od.status WHEN '4' THEN od.orderlinenumber ELSE NULL END)) S_4,
count((case od.status WHEN '5' THEN od.orderlinenumber ELSE NULL END)) S_5,
count((case od.status WHEN '9' THEN od.orderlinenumber ELSE NULL END)) S_9,
count((case od.status WHEN 'CANC' THEN od.orderlinenumber ELSE NULL END)) S_CANC,
sum(od.originalqty) OrdQTY ,
sum(case when o.status = 'CANC' THEN od.originalqty ELSE 0 END)  CancQTY ,
sum(case when o.status = '0' THEN od.originalqty ELSE 0 END)  UnallocQTY ,
sum(case when o.status in ('1','2','3','4','5') THEN od.openqty-(od.qtyallocated+od.qtypicked+od.shippedqty)
         when o.status = '9' THEN od.openqty ELSE 0 END)  ShortQTY ,
sum(case when od.status in ('1','2') THEN od.qtyallocated+od.qtypicked ELSE 0 END)  AllocQTY ,
sum(case when od.status in ('3') THEN od.qtyallocated+od.qtypicked ELSE 0 END)  InPickQTY ,
sum(case when od.status in ('5') THEN od.qtyallocated+od.qtypicked ELSE 0 END)  PickedQTY ,
sum(od.shippedqty) ShippedQTY
from orderdetail od(nolock) , orders o(nolock)
where o.orderkey = od.orderkey
and o.loadkey in (select loadkey from loadplan (nolock) where status < '9' UNION ALL select '' )
group by o.storerkey , o.loadkey, o.type, o.ordergroup, o.orderkey
)


GO