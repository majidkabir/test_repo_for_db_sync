SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-28_Overview order monitoring] as 
select StorerKey,
CONVERT(varchar, OrderDate, 105) as OrderDate , CONVERT(varchar, OrderDate, 108) as TimeOrderDate, 
OrderKey , ExternOrderKey  ,notes as RecieptNumber, 
ConsigneeKey, C_Company,
CONVERT(varchar, addDate, 105) as API_LF_Received , CONVERT(varchar, addDate, 108) as TimeAPI_LF_Received ,

case when status='0' then '0_Opened - API LF Received'  
	when status='1' then '1_Partially Allocated'
	when status='2' then '2_Fully Allocated'
	when status='3' then '3_InProcess - Pick,Pack'
	when status='5' then '5_Picked'
	when status='9' then '9_Shipped - OrderCompleted'
	else status
end as LatestStatus ,
 CONVERT(varchar, editDate, 105) as UpdateDate , CONVERT(varchar, editDate, 108) as TimeUpdateDate
from ORDERS with (nolock) 
where StorerKey = 'YVESR' 
and addDate > CAST(DATEADD(day, -30, GetDate()) as date)

GO