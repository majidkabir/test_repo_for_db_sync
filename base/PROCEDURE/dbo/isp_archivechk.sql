SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_archivechk																			*/
/* Creation Date:  13 Jan 2006                                          */
/* Copyright: IDS                                                       */
/* Written by: June                                                     */
/*                                                                      */
/* Purpose: For WMS Auto Email alert. It shows no of records exceed 		*/
/*		  	  90 days.																										*/
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 15-May-2007  June		1.1  	SOS72920 - Use header's editdate instead  */
/*													  of detail's editdate.											*/
/* 01-Sep-2009  TLTING  1.2   Increase the alert Threshold to 1.2 M			*/
/************************************************************************/

CREATE PROC [dbo].[isp_archivechk]
As
begin
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
if OBJECT_ID('tempdb..#tempreccnt') IS NOT NULL 
begin
	drop table #tempreccnt
end

create table #tempreccnt 
(tablename NVARCHAR(20),
 rec_count int NULL,
 min_date  NVARCHAR(20) NULL,
 max_date  NVARCHAR(20) NULL, 
 Attention NVARCHAR(1)  NULL )

insert into #tempreccnt
select tablename = 'PO', rec_count = count(*), min_date = convert(char, min(editdate), 106), max_date = convert(char, max(editdate), 106), ''
from PO (nolock)

insert into #tempreccnt
select tablename = 'PODetail', rec_count = count(a.Pokey), min_date = convert(char, min(b.editdate), 106), max_date = convert(char, max(b.editdate), 106), ''
from PODetail a (nolock)
join PO b (nolock) ON a.POkey = b.POkey


insert into #tempreccnt
select tablename = 'Receipt', rec_count =  count(*), min_date = convert(char, min(editdate), 106), max_date = convert(char, max(editdate), 106), ''
from receipt (nolock)

insert into #tempreccnt
select tablename = 'ReceiptDetail', rec_count =  count(a.receiptkey), min_date = convert(char, min(b.editdate), 106), max_date = convert(char, max(b.editdate), 106), ''
from receiptdetail a (nolock)
join receipt b (nolock) ON a.receiptkey = b.receiptkey

insert into #tempreccnt
select tablename = 'Orders', rec_count =  count(*), min_date = convert(char, min(editdate), 106), max_date = convert(char, max(editdate), 106), ''
from Orders (nolock)

insert into #tempreccnt
select tablename = 'OrderDetail', rec_count =  count(a.orderkey), min_date = convert(char, min(b.editdate), 106), max_date = convert(char, max(b.editdate), 106), ''
from OrderDetail a (nolock)
join Orders b (nolock) ON a.Orderkey = b.Orderkey


insert into #tempreccnt
select tablename = 'LoadPlan', rec_count =  count(*), min_date = convert(char, min(editdate), 106), max_date = convert(char, max(editdate), 106), ''
from LoadPlan (nolock)

insert into #tempreccnt
select tablename = 'LoadPlanDetail', rec_count =  count(a.loadkey), min_date = convert(char, min(b.editdate), 106), max_date = convert(char, max(b.editdate), 106), ''
from LoadPlanDetail a (nolock)
join LoadPlan b (nolock) ON a.Loadkey = b.Loadkey



insert into #tempreccnt
select tablename = 'MBOL', rec_count =  count(*), min_date = convert(char, min(editdate), 106), max_date = convert(char, max(editdate), 106), ''
from MBOL (nolock)

insert into #tempreccnt
select tablename = 'MBOLDetail', rec_count =  count(a.mbolkey), min_date = convert(char, min(b.editdate), 106), max_date = convert(char, max(b.editdate), 106), ''
from MBOLDetail a (nolock)
join Mbol b (nolock) ON a.Mbolkey = b.Mbolkey

insert into #tempreccnt
select tablename = 'PickDetail', rec_count =  count(*), min_date = convert(char, min(editdate), 106), max_date = convert(char, max(editdate), 106), ''
from PickDetail (nolock)

insert into #tempreccnt
select tablename = 'PickHeader', rec_count =  count(*), min_date = convert(char, min(editdate), 106), max_date = convert(char, max(editdate), 106), ''
from PickHeader (nolock)

insert into #tempreccnt
select tablename = 'PickingInfo', rec_count =  count(*), min_date = convert(char, min(isnull(scanoutdate, '')), 106), max_date = convert(char, max(isnull(scanoutdate, '')), 106), ''
from  PickingInfo (nolock)
where ScanOutdate IS NOT NULL

insert into #tempreccnt
select tablename = 'PackHeader', rec_count =  count(*), min_date = convert(char, min(editdate), 106), max_date = convert(char, max(editdate), 106), ''
from PackHeader (nolock)

insert into #tempreccnt
select tablename = 'PackDetail', rec_count =  count(a.PickSlipNo), min_date = convert(char, min(b.editdate), 106), max_date = convert(char, max(b.editdate), 106), ''
from PackDetail a (nolock)
join PackHeader b (nolock) ON a.PickSlipNo = b.PickSlipNo

insert into #tempreccnt
select tablename = 'ITRN', rec_count =  count(*), min_date = convert(char, min(editdate), 106), max_date = convert(char, max(editdate), 106), ''
from ITRN (nolock)

insert into #tempreccnt
select tablename = 'POD', rec_count =  count(*), min_date = convert(char, min(editdate), 106), max_date = convert(char, max(editdate), 106), ''
from POD (nolock)

insert into #tempreccnt
select tablename = 'KIT', rec_count =  count(*), min_date = convert(char, min(editdate), 106), max_date = convert(char, max(editdate), 106), ''
from KIT (nolock)

insert into #tempreccnt
select tablename = 'KITDETAIL', rec_count =  count(a.kitkey), min_date = convert(char, min(b.editdate), 106), max_date = convert(char, max(b.editdate), 106), ''
from KITDETAIL a (nolock)
join Kit b (nolock) ON a.Kitkey = b.kitkey

insert into #tempreccnt
select tablename = 'TRANSFER', rec_count =  count(*), min_date = convert(char, min(editdate), 106), max_date = convert(char, max(editdate), 106), ''
from TRANSFER (nolock)

insert into #tempreccnt
select tablename = 'TRANSFERDETAIL', rec_count =  count(a.transferkey), min_date = convert(char, min(b.editdate), 106), max_date = convert(char, max(b.editdate), 106), ''
from TRANSFERDETAIL a (nolock)
join Transfer b (nolock) ON a.Transferkey = b.Transferkey


insert into #tempreccnt
select tablename = 'ADJUSTMENT', rec_count =  count(*), min_date = convert(char, min(editdate), 106), max_date = convert(char, max(editdate), 106), ''
from ADJUSTMENT (nolock)

insert into #tempreccnt
select tablename = 'ADJUSTMENTDETAIL', rec_count =  count(a.adjustmentkey), min_date = convert(char, min(b.editdate), 106), max_date = convert(char, max(b.editdate), 106), ''
from ADJUSTMENTDETAIL a (nolock)
join Adjustment b (nolock) ON a.Adjustmentkey = b.Adjustmentkey


insert into #tempreccnt
select tablename = 'CCDETAIL', rec_count =  count(*), min_date = convert(char, min(editdate), 106), max_date = convert(char, max(editdate), 106), ''
from CCDETAIL (nolock)

insert into #tempreccnt
select tablename = 'TRANSMITLOG', rec_count =  count(*), min_date = convert(char, min(editdate), 106), max_date = convert(char, max(editdate), 106), ''
from TRANSMITLOG (nolock)

insert into #tempreccnt
select tablename = 'TRANSMITLOG2', rec_count =  count(*), min_date = convert(char, min(editdate), 106), max_date = convert(char, max(editdate), 106), ''
from TRANSMITLOG2 (nolock)

insert into #tempreccnt
select tablename = 'TRANSMITLOG3', rec_count =  count(*), min_date = convert(char, min(editdate), 106), max_date = convert(char, max(editdate), 106), ''
from TRANSMITLOG3 (nolock)


UPDATE #tempreccnt 
 SET Attention = '*'
WHERE rec_count > 1200000 

select * 
from  #tempreccnt (nolock)
where datediff(day, min_date, getdate())> 90 

drop table #tempreccnt


set nocount off 
end

GO