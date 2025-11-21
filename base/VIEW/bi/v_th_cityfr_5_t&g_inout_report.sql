SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/******************************************************************************************/
--TH_CTX_LCTH_ADIDAS View in THWMS PROD Catalog https://jiralfl.atlassian.net/browse/WMS-18651
/* Date          Author      Ver.  Purposes									                     */
/* 28-Dec-2021   Rungtham    1.0   Created									                     */												
/******************************************************************************************/
CREATE   VIEW [BI].[V_TH_CITYFR_5_T&G_inout_report]
AS
select Principal,Type,Date,WMSDoc,CTXDoc,ShipToFrom,Name,Sku,Descr,StockStatus,CD,Brand,ReceiveDate,case when Qty>=0 then qty end as QtyIn,case when Qty<0 then qty end as QtyOut,UOM,Lottable06,ID,Loc,lot06
from
(
select case when rd.Lottable06='CTX' then 'CTX Holding' when rd.Lottable06='CFF' then 'CITYFR' when rd.Lottable06='T&G' then 'T&G' else 'Other' end as Principal,
	r.RECType as Type,
	r.EditDate as Date,
	r.ReceiptKey as WMSDoc,
	r.ExternReceiptKey as CTXDoc,
	r.CarrierKey as ShipToFrom,
	st.Company as Name,
	rd.Sku as Sku,
	s.DESCR as Descr,
	rd.Lottable01 as StockStatus,
	rd.Lottable02 as CD,
	rd.Lottable03 as Brand,
	rd.Lottable05 as ReceiveDate,
	sum(rd.QtyReceived) as Qty,
	p.PackUOM3 as UOM,
	case when rd.Lottable06='CTX' then 'CTX' when rd.Lottable06='CFF' then 'CITYFR' when rd.Lottable06='T&G' then 'T&G' else 'Other' end as Lottable06,
	rd.toid as ID,
	rd.toloc as Loc,
	rd.Lottable06 as lot06
from DBO.V_RECEIPT r WITH (NOLOCK) INNER join V_RECEIPTDETAIL rd WITH (NOLOCK) ON r.StorerKey=rd.StorerKey and r.ReceiptKey=rd.ReceiptKey
	left join DBO.v_sku s WITH (NOLOCK) ON rd.StorerKey=s.StorerKey and rd.Sku=s.Sku
	left join DBO.V_STORER st WITH (NOLOCK) ON r.CarrierKey=st.StorerKey
	left join DBO.V_PACK p WITH (NOLOCK) ON s.PACKKey=p.PackKey
where r.StorerKey='CITYFR' and convert(date,rd.DateReceived)=convert(date,getdate()-1) and rd.FinalizeFlag='Y' and rd.QtyReceived>0
group by case when rd.Lottable06='CTX' then 'CTX Holding' when rd.Lottable06='CFF' then 'CITYFR' when rd.Lottable06='T&G' then 'T&G' else 'Other' end, 
	r.RECType,r.EditDate,r.ReceiptKey,r.ExternReceiptKey,r.CarrierKey,st.Company,rd.Sku,s.DESCR,rd.Lottable01,rd.Lottable02,rd.Lottable03,rd.Lottable05,p.PackUOM3,case when rd.Lottable06='CTX' then 'CTX' when rd.Lottable06='CFF' then 'CITYFR' when rd.Lottable06='T&G' then 'T&G' else 'Other' end,rd.toid,rd.toloc,lottable06

union all

select case when l.Lottable06='CTX' then 'CTX Holding' when l.Lottable06='CFF'  then 'CITYFR' when l.Lottable06='T&G' then 'T&G' else 'Other' end as Principal,
	o.Type as Type,
	o.EditDate as Date,
	o.OrderKey as WMSDoc,
	o.ExternOrderKey as CTXDoc,
	o.ConsigneeKey as ShipToFrom,
	st.Company as Name,
	pd.Sku as Sku,
	s.DESCR as Descr,
	l.Lottable01 as StockStatus,
	l.Lottable02 as CD,
	l.Lottable03 as Brand,
	l.Lottable05 as ReceiveDate,
	sum(pd.Qty*-1) as Qty,
	p.PackUOM3 as UOM,
	case when l.Lottable06='CTX' then 'CTX Holding' when l.Lottable06='CFF'  then 'CITYFR' when l.Lottable06='T&G' then 'T&G' else 'Other' end as Lottable06,
	pd.id as ID,
	pd.loc as Loc,
	l.Lottable06 as lot06
from DBO.V_ORDERS  o WITH (NOLOCK) inner join V_PICKDETAIL pd WITH (NOLOCK) ON o.StorerKey=pd.StorerKey and o.OrderKey=pd.OrderKey
	left join DBO.v_sku s WITH (NOLOCK) ON pd.StorerKey=s.StorerKey and pd.Sku=s.Sku
	left join DBO.V_STORER st WITH (NOLOCK) ON o.ConsigneeKey=st.StorerKey
	left join DBO.V_LOTATTRIBUTE l WITH (NOLOCK) ON pd.StorerKey=l.StorerKey and pd.lot=l.lot
	left join DBO.V_PACK p WITH (NOLOCK) ON s.PACKKey=p.PackKey
where o.StorerKey='CITYFR' and convert(date,o.editdate)=convert(date,getdate()-1) and o.Status='9'
group by case when l.Lottable06='CTX' then 'CTX Holding' when l.Lottable06='CFF'  then 'CITYFR' when l.Lottable06='T&G' then 'T&G' else 'Other' end, o.ConsigneeKey, st.Company,o.Type,o.EditDate,o.OrderKey,o.ExternOrderKey,o.ConsigneeKey,pd.Sku,s.DESCR,l.Lottable01,l.Lottable02,l.Lottable03,l.Lottable05,p.PackUOM3,case when l.Lottable06='CTX' then 'CTX Holding' when l.Lottable06='CFF'  then 'CITYFR' when l.Lottable06='T&G' then 'T&G' else 'Other' end,pd.id,pd.loc,lottable06
) a
where a.cd like ('AB%') and a.Principal = 'T&G'

GO