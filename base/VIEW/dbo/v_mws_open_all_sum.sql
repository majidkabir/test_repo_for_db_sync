SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_MWS_OPEN_ALL_SUM] AS
(
select o.FACILITY , o.storerkey Storerkey ,CONVERT(VARCHAR(10),o.adddate,120) OrdDate, count(distinct(o.orderkey)) NumOrd,
count(*) NumOrdLines, count(distinct(od.sku)) NumSkus,
count(distinct(case o.status WHEN '0' THEN o.orderkey ELSE NULL END)) S_0,
count(distinct(case o.status WHEN '1' THEN o.orderkey ELSE NULL END)) S_1,
count(distinct(case o.status WHEN '2' THEN o.orderkey ELSE NULL END)) S_2,
count(distinct(case o.status WHEN '3' THEN o.orderkey ELSE NULL END)) S_3,
count(distinct(case o.status WHEN '4' THEN o.orderkey ELSE NULL END)) S_4,
count(distinct(case o.status WHEN '5' THEN o.orderkey ELSE NULL END)) S_5,
count(distinct(case o.status WHEN '9' THEN o.orderkey ELSE NULL END)) S_9,
count(distinct(case o.status WHEN 'CANC' THEN o.orderkey ELSE NULL END)) S_CANC,
sum(od.originalqty) OrdQTY ,
sum(case when o.status = 'CANC' THEN od.originalqty ELSE 0 END)  CancQTY ,
sum(case when o.status = '0' THEN od.originalqty ELSE 0 END)  UnallocQTY ,
sum(case when o.status in ('1','2','3','4','5') THEN od.openqty-(od.qtyallocated+od.qtypicked+od.shippedqty)
         when o.status = '9' THEN od.openqty ELSE 0 END)  ShortQTY ,
sum(case when od.status in ('1','2') THEN od.qtyallocated+od.qtypicked ELSE 0 END)  AllocQTY ,
sum(case when od.status in ('3') THEN od.qtyallocated+od.qtypicked ELSE 0 END)  InPickQTY ,
sum(case when od.status in ('4','5') THEN od.qtyallocated+od.qtypicked ELSE 0 END)  PickedQTY ,
sum(od.shippedqty) ShippedQTY
from orderdetail od(nolock) , orders o(nolock)
where o.orderkey = od.orderkey
and o.loadkey in (select loadkey from loadplan (nolock) where status < '9' UNION ALL select '' )
group by o.facility , o.storerkey,CONVERT(VARCHAR(10),o.adddate,120)
having count(distinct(o.orderkey)) <>
count(distinct(case o.status WHEN '9' THEN o.orderkey ELSE NULL END))+count(distinct(case o.status WHEN 'CANC' THEN o.orderkey ELSE NULL END))
)


GO