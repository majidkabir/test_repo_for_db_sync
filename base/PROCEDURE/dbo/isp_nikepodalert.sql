SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/          
/* Stored Procedure: isp_NIKEPODAlert                                   */          
/* Creation Date: 10-Jan-2013                                           */          
/* Copyright: LF LOGISTICS                                              */          
/* Written by: Kunakorn                                                 */          
/*                                                                      */          
/* Called By: SQL Scheduler                                             */           
/*                                                                      */          
/* Parameters:                                                          */          
/*                                                                      */          
/* PVCS Version: 1.0                                                    */          
/*                                                                      */          
/* Version: 1.0                                                         */          
/*                                                                      */          
/* Data Modifications:                                                  */          
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 09-Sep-2015  NJOW01   1.0  352330-add next two weeks                 */
/* 05-Mar-2021  NJOW02   1.1  Fix datamart server name from VMHKWMSDMPD1*/
/*                            to LINK_RGN_WMS_PROD_DM.                  */
/*                            Need change to LINK_RGN_WMS_UAT_DM if     */
/*                            deploy to UAT.                            */
/************************************************************************/          
CREATE PROC [dbo].[isp_NIKEPODAlert]          
(  
   @cTo     varchar(max),  
   @cCc     varchar(max) = ''  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS ON  
   SET ANSI_WARNINGS ON  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF          
              
   DECLARE @cBody       nvarchar(MAX),            
           @cEmail1     varchar(MAX),        
           @cEmail2     varchar(MAX),        
           @cRecip      varchar(MAX),        
           @cRecipCc    varchar(MAX),        
           @cOrderkey   varchar(30),        
           @cConsignee  varchar(50),  
     @ShowColoumn varchar(255),        
           @cCompany    nvarchar(Max),        
           @cBranch     nvarchar(MAX),      
           @cSubject    nvarchar(255),       
           @dDelivery   datetime,  
     @ImgName  nvarchar(Max),  
     @ColorDate   nvarchar(150)  
  
/*  --***************script suspend notice*******************
    --this SQL Job script was stop running in TH production for many years. Due to the hardcoded link server caused devops jenkin failure, 
    --we have remark the script until TH request to use this again in future and enhance to use dynamic SQL.
         
 --=================================================Open function Running Date=====================================       
;with nums (i)  
as  
(  
select i = 0  
union all  
select i + 1 from nums where i < 100  
)  
select * into #tempdatelist from (select  convert(varchar,dte,103) Datelink,DATENAME(weekday,dte) DateText,convert(varchar,dte,106) Dateshow  
from (select dte = dateadd(dd,nums.i,(DATEADD(dd,0,DATEADD(mm, DATEDIFF(mm,0,CURRENT_TIMESTAMP),0))))  
from nums) a  
where dte < (DATEADD(mm,1,DATEADD(mm, DATEDIFF(mm,0,CURRENT_TIMESTAMP),0)))) gg  
--================================================close function Date==============================================  
  
set @cSubject ='Auto Report POD for Nike Thailand'  
  
--================================================select DataMaster===============================================  
  
select   
convert(varchar,o.Deliverydate,103) Deliverydate,  
count(distinct o.Orderkey) ImportedOrder,  
sum(od.Originalqty) ImportedUnit,  
count(distinct case when (o.Sostatus < '5'  or o.Sostatus ='canc')  then  case when o.Sostatus = 'canc' then o.Orderkey else NULL end else NULL end) CancelledOrder,  
sum(case when (o.Sostatus < '5'  or o.Sostatus ='canc')  then case when o.Sostatus = 'canc' then od.Originalqty else 0 end else 0 end) CancelledUnit,  
count( distinct o.Orderkey) - count(distinct case when (o.Sostatus < '5'  or o.Sostatus ='canc')  then  case when o.Sostatus = 'canc' then o.Orderkey else NULL end else NULL end) TotalOrder,  
sum(od.Originalqty) - sum(case when (o.Sostatus < '5'  or o.Sostatus ='canc')  then case when o.Sostatus = 'canc' then od.Originalqty else 0 end else 0 end) TotalOrderUint,  
count(distinct case when (o.Sostatus < '5'  or o.Sostatus ='canc')  then  case when o.Sostatus <> 'canc' then o.Orderkey else NULL end else NULL end) PickingOrder,  
sum(case when (o.Sostatus < '5'  or o.Sostatus ='canc')  then case when o.Sostatus <>'canc' then od.Originalqty else 0 end else 0 end) PickingUnit,  
count(distinct case when (o.Sostatus = '5'  and o.Sostatus ='canc')  then o.Orderkey else NULL end) PackOrder,  
sum(case when (o.Sostatus = '5'  and o.Sostatus ='canc')  then  od.Qtypicked else 0 end) PackUnit,  
count( distinct case when (o.Sostatus = '9'  and o.Sostatus <> 'canc')  then o.Orderkey else NULL end) GoodsIssueOrder,  
sum(case when (o.Sostatus = '9'  and o.Sostatus <> 'canc')  then  od.Shippedqty else 0 end) GoodIssuedunit,  
count(distinct case when (od.Originalqty <> (od.shippedqty + od.qtypicked)) and o.Sostatus >='5' and o.Sostatus <> 'canc'  then o.Orderkey else NULL end) OrderShotPicked,  
sum(case when (od.Originalqty <> (od.shippedqty + od.qtypicked)) and o.Sostatus >='5' and o.Sostatus <> 'canc' then od.openQTY else 0 end) UnitShotPicked,  
count(distinct case when (od.Originalqty <> (od.shippedqty + od.qtypicked)) and o.Sostatus >='5' and o.Sostatus <> 'canc'  then od.sku else NULL end) TotalshotSKU,  
CONVERT(DECIMAL(10,2),round(case when (sum(case when o.status >='5' then od.shippedqty + od.qtypicked else 0 end)+sum(case when (od.Originalqty <> (od.shippedqty + od.qtypicked)) and o.status >='5' then od.shippedqty + od.qtypicked else 0 end))=0 then 0 



else   
cast((sum(case when (od.Originalqty <> (od.shippedqty + od.qtypicked)) and o.Sostatus >='5' and o.Sostatus <> 'canc' then od.openQTY else 0 end))as decimal)/(sum(case when o.status >='5' then od.shippedqty + od.qtypicked else 0 end)+sum(case when 
(od.Originalqty <> (od.shippedqty + od.qtypicked)) and o.status >='5' then od.shippedqty + od.qtypicked else 0 end)) end * 100,2)) 'PersendShortPick',  
cast(100 as decimal) - CONVERT(DECIMAL(10,2),round(case when (sum(case when o.status >='5' then od.shippedqty + od.qtypicked else 0 end)+sum(case when (od.Originalqty <> (od.shippedqty + od.qtypicked)) and o.status >='5' then od.shippedqty + od.qtypicked 

else 0 end))=0 then 0 else   
cast((sum(case when (od.Originalqty <> (od.shippedqty + od.qtypicked))  and o.Sostatus >='5' and o.Sostatus <> 'canc' then od.openQTY else 0 end))as decimal)/(sum(case when o.status >='5' then od.shippedqty + od.qtypicked else 0 end)+sum(case when 
(od.Originalqty <> (od.shippedqty + od.qtypicked)) and o.status >='5' then od.shippedqty + od.qtypicked else 0 end)) end * 100,2))  Picksuccess,  
(count(distinct case when (o.Sostatus = '5'  and o.Sostatus ='canc')  then o.Orderkey else NULL end) + (count( distinct case when (o.Sostatus = '9'  and o.Sostatus <> 'canc')  then o.Orderkey else NULL end))) -  
count(distinct case when (od.Originalqty <> (od.shippedqty + od.qtypicked)) and o.Sostatus >='5' and o.Sostatus <> 'canc' then o.Orderkey else NULL end) 'Order100Persend',  
case when (count(distinct case when (o.Sostatus = '5'  and o.Sostatus ='canc')  then o.Orderkey else NULL end) + (count( distinct case when (o.Sostatus = '9'  and o.Sostatus <> 'canc')  then o.Orderkey else NULL end)))=0 then 0 else  
CONVERT(DECIMAL(10,2),round((cast(((count(distinct case when (o.Sostatus = '5'  and o.Sostatus ='canc')  then o.Orderkey else NULL end) + (count( distinct case when (o.Sostatus = '9'  and o.Sostatus <> 'canc')  then o.Orderkey else NULL end))) -  
count(distinct case when (od.Originalqty <> (od.shippedqty + od.qtypicked)) and o.Sostatus >='5' and o.Sostatus <> 'canc'  then o.Orderkey else NULL end)) as decimal(10,2))/  
(count(distinct case when (o.Sostatus = '5'  and o.Sostatus ='canc')  then o.Orderkey else NULL end) + (count( distinct case when (o.Sostatus = '9'  and o.Sostatus <> 'canc')  then o.Orderkey else NULL end))))*100,2)) end 'FillPersend',  
count(distinct case when p.Status <>'1' then p.orderkey else NULL end) TotalDelivered,  
count(distinct case when o.Status <> 'CANC' then case when o.Status=9  and ((o.Deliverydate+ case when R.Zipcodefrom ='BKK' then 1 else 3 end) - (DATEDIFF(d,o.Deliverydate,o.Editdate+3)+1 -  
(DATEDIFF(wk,o.Deliverydate,o.Editdate+3) + CASE WHEN DATEPART(dw,o.Deliverydate)=1 then 1 else 0 End )-  
(DATEDIFF(wk,o.Deliverydate,o.Editdate+3) + CASE WHEN DATEPART(dw,o.Editdate+3)=7 then 1 else 0 End ))) >=0 then o.orderkey else NULL end else NULL end) OntimeDelivered,  
case when count(distinct case when p.Status <>'1' then p.orderkey else NULL end) = 0 then 0 else ((count(distinct case when o.Status <> 'CANC' then case when o.Status=9  and ((o.Deliverydate+ case when R.Zipcodefrom ='BKK' then 1 else 3 end) - 
(DATEDIFF(d,o.Deliverydate,o.Editdate+3)+1  
- (DATEDIFF(wk,o.Deliverydate,o.Editdate+3) + CASE WHEN DATEPART(dw,o.Deliverydate)=1 then 1 else 0 End )  
- (DATEDIFF(wk,o.Deliverydate,o.Editdate+3) + CASE WHEN DATEPART(dw,o.Editdate+3)=7 then 1 else 0 End ))) >=0 then o.orderkey else NULL end else NULL end))/(count(distinct case when p.Status <>'1' then p.orderkey else NULL end)))*100 end 'PersendOn_Time',

  
count(distinct case when P.Status <>'1' and P.Podreceiveddate is not null then p.orderkey else NULL end) POD_Returned,  
count(distinct case when P.Status <>'1' and (DATEDIFF(dd, P.Actualdeliverydate,P.Podreceiveddate))-(DATEDIFF(wk,P.Actualdeliverydate,P.Podreceiveddate)* 2)  
-(CASE WHEN DATENAME(dw,P.Actualdeliverydate) = 'Sunday' THEN 1 ELSE 0 END)-(CASE WHEN DATENAME(dw,P.Podreceiveddate)='Saturday' THEN 1 ELSE 0 END)  
<=(case when R.Zipcodefrom ='BKK' then 3 else 6 end)  then p.orderkey else NULL end) POD_Hit,  
case when count(distinct case when p.Status <>'1' then p.orderkey else NULL end)  = 0 then 0 else CONVERT(DECIMAL(8,2),(cast(count(distinct case when P.Status <>'1' and (DATEDIFF(dd, P.Actualdeliverydate,P.Podreceiveddate))-
(DATEDIFF(wk,P.Actualdeliverydate,P.Podreceiveddate)* 2)  
-(CASE WHEN DATENAME(dw,P.Actualdeliverydate) = 'Sunday' THEN 1 ELSE 0 END)-(CASE WHEN DATENAME(dw,P.Podreceiveddate)='Saturday' THEN 1 ELSE 0 END)  
<=(case when R.Zipcodefrom ='BKK' then 3 else 6 end)  then p.orderkey else NULL end) as decimal(8,2))/count(distinct case when p.Status <>'1' then p.orderkey else NULL end) )*100) end 'HitPersend',  
count(distinct case when p.Status <>'1' then p.orderkey else NULL end)- count(distinct case when P.Status <>'1' and P.Podreceiveddate is not null then p.orderkey else NULL end) PODNotReturn  
  
into #tempMaser  
from LINK_RGN_WMS_PROD_DM.TH_DATAMART.ODS.orders o (nolock)  join LINK_RGN_WMS_PROD_DM.TH_DATAMART.ODS.orderdetail od (nolock) on o.storerkey =od.storerkey and o.orderkey = od.orderkey  
left outer join LINK_RGN_WMS_PROD_DM.TH_DATAMART.ODS.POD P (nolock) on o.orderkey = p.orderkey and o.mbolkey = p.mbolkey  
left outer join LINK_RGN_WMS_PROD_DM.TH_DATAMART.ODS.RouteMaster R (nolock) on o.route = r.route  
where o.storerkey='NIKETH' and o.Deliverydate between   
DATEADD(dd,0,DATEADD(mm, DATEDIFF(mm,0,CURRENT_TIMESTAMP),0)) and DATEADD(WK,2,DATEADD(dd,-1,DATEADD(mm, DATEDIFF(mm,0,CURRENT_TIMESTAMP)+1,0))) --NJOW01  
group by convert(varchar,o.Deliverydate,103)  
  
--===============================================close data master===================================================================================  
  
   BEGIN  
  
      SET @cBody = ''          
          
      SET @cBody = @cBody + '<style type="text/css">           
         ul    {  font-family: Arial; font-size: 11px; color: #686868;  }          
         p.a1  {  font-family: Arial; font-size: 11px; color: #686868;  }          
         p.a2  {  font-family: Arial; font-size: 11px; color: #686868; font-style:italic  }      
   p.a3  {  font-family: Arial; font-size: 16px; color: black;  }          
         table {  font-family: Arial;  }          
         th    {  font-size: 11px;font-family: Tahoma }          
         td    {  font-size: 10px;  }     
         </style>'  
  
      SET @cBody = @cBody + '<p class=a1>Dear All,</p>'          
      SET @cBody = @cBody + '<p class=a2>We would like to inform you on the Nike POD Report,</p>'         
      SET @cBody = @cBody + '<p class=a2>kindly see detail below.</p>'          
          
          
      SET @cBody = @cBody +           
          N'<p class=a3><b>Nike POD Report :'+ DATENAME(month,GETDATE()) +'  '+ DATENAME(YEAR,GETDATE())+ ' (+ Next 2 Week)' + ' &nbsp </b>' +   --NJOW01      
--    N'<img src="http://www.sqlteam.com/images2/SqlTeamHDR2.jpg" border="0" width="270" height="146" />' +  
         N'</p><table border="1" cellspacing="0" cellpadding="1">' +          
         N'<tr><th bgcolor=#00BFFF align=center rowspan="2" colspan="2">Day</th><th bgcolor=#00BFFF align=center colspan="2">Imported</th><th bgcolor=#00BFFF align=center colspan="2">Cancelled</th><th bgcolor=#00BFFF align=center colspan="2">Total Orders



</th><th bgcolor=#00BFFF align=center colspan="2">Picking</th><th bgcolor=#00BFFF align=center colspan="2">Packed</th><th bgcolor=#FAAC58 align=center colspan="2">Goods Issued</th><th bgcolor=#00BFFF align=center rowspan="2">Order Short Picked</th><th bgc

olor=#00BFFF align=center rowspan="2">Units Short Picked</th><th bgcolor=#00BFFF align=center rowspan="2">Total SKU Short</th><th bgcolor=#00BFFF align=center rowspan="2">% Short Picked</th><th bgcolor=#00BFFF align=center rowspan="2">Pick Success %</th><

th bgcolor=#00BFFF align=center colspan="2">Order</th><th bgcolor=#FE642E align=center colspan="3">Delivery</th><th bgcolor=#FE642E align=center colspan="3">POD</th><th bgcolor=#FE642E align=center rowspan="2">PODNotReturn</th></tr>'+  
         N'<tr><th bgcolor=#00BFFF>Orders</th><th bgcolor=#00BFFF>Units</th><th bgcolor=#00BFFF>Orders</th><th bgcolor=#00BFFF>Units</th><th bgcolor=#00BFFF>Orders</th><th bgcolor=#00BFFF>Units</th><th bgcolor=#00BFFF>Orders</th><th bgcolor=#00BFFF>Units<

/th><th bgcolor=#00BFFF>Orders</th><th bgcolor=#00BFFF>Units</th><th bgcolor=#FAAC58>Orders</th><th bgcolor=#FAAC58>Units</th><th bgcolor=#00BFFF>100%</th><th bgcolor=#00BFFF>Fill %</th><th bgcolor=#FE642E>Total</th><th bgcolor=#FE642E>OnTime</th><th bgco

lor=#FE642E>%OnTime</th><th bgcolor=#FE642E>TotalReturn</th><th bgcolor=#FE642E>Hit</th><th bgcolor=#FE642E>Hit%</th>'      
  
 BEGIN  
      SET @cBody = @cBody + CAST ( (   
  
     
 SELECT  
   'td/@align' = 'Left','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99'  else '' end,   
            td =  ISNULL(CAST(d.Dateshow AS nvarchar(99)),''), '',          
            'td/@align' = 'Left','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,          
            td = ISNULL(CAST(d.DateText AS nvarchar(99)),''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,             
            td = replace(convert(varchar,cast(ISNULL(CAST(m.ImportedOrder AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.ImportedUnit AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.CancelledOrder AS nvarchar(99)),'')as money),1), '.00',''), '',         
    'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.CancelledUnit AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.TotalOrder AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.TotalOrderUint AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.PickingOrder AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.PickingUnit AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.PackOrder AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.PackUnit AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'='#FFDEAD',   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.GoodsIssueOrder AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'='#FFDEAD',   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.GoodIssuedunit AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.OrderShotPicked AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.UnitShotPicked AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.TotalshotSKU AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.PersendShortPick AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
   td = replace(convert(varchar,cast(ISNULL(CAST(m.Picksuccess AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.Order100Persend AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.FillPersend AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.TotalDelivered AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.OntimeDelivered AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.PersendOn_Time AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.POD_Returned AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.POD_Hit AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.HitPersend AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'Right','td/@bgcolor'=case d.DateText  when 'Sunday' then '#FFFF99' when 'Saturday'  then '#FFFF99' else '' end,   
            td = replace(convert(varchar,cast(ISNULL(CAST(m.PODNotReturn AS nvarchar(99)),'')as money),1), '.00',''), ''         
          
  
   from #tempdatelist d left outer join #tempMaser m on d.Datelink = m.Deliverydate  
  
            FOR XML PATH('tr'), TYPE             
          ) AS NVARCHAR(MAX) )   
  
         END  
BEGIN  
      SET @cBody = @cBody + CAST ( (   
  
 SELECT  
            td =  ISNULL(CAST('Total' AS nvarchar(99)),''), '',          
            'td/@align' = 'Left',          
            td = ISNULL(CAST('' AS nvarchar(99)),''), '',         
            'td/@align' = 'Left',             
            td = replace(convert(varchar,cast(ISNULL(CAST(sum(sm.ImportedOrder) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(sum(sm.ImportedUnit) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(sum(sm.CancelledOrder) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(sum(sm.CancelledUnit) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(sum(sm.TotalOrder) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(sum(sm.TotalOrderUint) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(sum(sm.PickingOrder) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(sum(sm.PickingUnit) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(sum(sm.PackOrder) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'center',  
            td = replace(convert(varchar,cast(ISNULL(CAST(sum(sm.PackUnit) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(sum(sm.GoodsIssueOrder) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(sum(sm.GoodIssuedunit) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(sum(sm.OrderShotPicked) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(sum(sm.UnitShotPicked) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(sum(sm.TotalshotSKU) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(AVG(sm.PersendShortPick) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
   td = replace(convert(varchar,cast(ISNULL(CAST(AVG(sm.Picksuccess) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(AVG(sm.Order100Persend) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(AVG(sm.FillPersend) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(sum(sm.TotalDelivered) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(sum(sm.OntimeDelivered) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(AVG(sm.PersendOn_Time) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(sum(sm.POD_Returned) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(sum(sm.POD_Hit) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(AVG(sm.HitPersend) AS nvarchar(99)),'')as money),1), '.00',''), '',         
            'td/@align' = 'right',   
            td = replace(convert(varchar,cast(ISNULL(CAST(sum(sm.PODNotReturn) AS nvarchar(99)),'')as money),1), '.00',''), ''         
          
             
  
   from #tempMaser sm   
FOR XML PATH('tr'), TYPE             
          ) AS NVARCHAR(MAX) ) + N'</table>' ;  
  
         END  
           
         
      SET @cBody = @cBody + '<p class=a1><b>Best Regards,</b><br><b>Delivery Team<b/>'          
  
  
  
  
      IF @cEmail2 <> ''  
      BEGIN  
         SET @cRecip = @cEmail2 + ';' + @cTo  
      END  
      ELSE  
      BEGIN  
         SET @cRecip = @cTo  
      END  
      IF @cEmail1 <> ''  
      BEGIN  
         SET @cRecipCc = @cEmail1 + ';' + @cCc  
      END  
      ELSE  
      BEGIN  
         SET @cRecipCc = @cCc  
      END  
  
      EXEC msdb.dbo.sp_send_dbmail   
         @recipients      = @cRecip,  
         @copy_recipients = @cRecipCc,  
         @subject         = @cSubject,  
         @body            = @cBody,  
         @body_format     = 'HTML' ;    
  END   
--   CLOSE GEN_Email  
--   DEALLOCATE GEN_Email  

*/ --suspened********

END /* main procedure */  

GO