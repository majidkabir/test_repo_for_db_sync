SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
               
/************************************************************************/                          
/* STORE PROCEDURE: isp_jp_Fanatics_RPT_Weekly_Carton                   */                          
/* CREATION DATE  : 21-July-2023                                        */                          
/* WRITTEN BY   : ZACK                                                  */                          
/*                                                                      */                          
/* PURPOSE: COUNT WEEKLY CARTON USED                                    */                     
/* Conditions : o.storerkey ='FJ' and doctype ='E'                      */  
/*				and m.shipdate in current 7 days                        */                     
/*                                                                      */                         
/* UPDATES:                                                             */                          
/*                                                                      */                         
/* DATE     AUTHOR   VER.  PURPOSES                                     */                          
/* 20230721 zack     1.0  Request from CPI 57 BY HIROI-SAN              */     
/* 20230801 zack     1.1  Request DEPLOY IN JPWMS PROD & UAT https://jiralfl.atlassian.net/browse/WMS-23175 */  
/************************************************************************/                     
CREATE PROCEDURE [BI].[isp_jp_Fanatics_RPT_Weekly_Carton]                     
                    
AS                    
BEGIN                    
 -- SET NOCOUNT ON added to prevent extra result sets from                    
 -- interfering with SELECT statements.                    
 SET NOCOUNT ON;   
 


IF OBJECT_ID('tempdb..#FJ_Weekly_CartonReport','u') IS NOT NULL  DROP TABLE #FJ_Weekly_CartonReport;
create table #FJ_Weekly_CartonReport(
	Carton_Type NVARCHAR(100),                    
	CTN_QTY INT   
 );



DECLARE 
@CTN1 NVARCHAR(20)='',
@CTN2 NVARCHAR(20)='',
@CTN3 NVARCHAR(20)='',
@CTN4 NVARCHAR(20)='',
@CTN5 NVARCHAR(20)='',
@SEVENDAYAGO NVARCHAR(50)=CONVERT(DATE, DATEADD(DAY, -7, GETDATE())),
@TTODAY NVARCHAR(50)=CONVERT(DATE, GETDATE())

--SELECT @SEVENDAYAGO,@TTODAY

			
--delete #FJ_Weekly_CartonReport;
			  
			  
--SELECT * FROM #FJ_Weekly_CartonReport(NOLOCK)
                    

select top 1 @CTN1=ph.CtnTyp1 ,@CTN2=ph.CtnTyp2,@CTN3=ph.CtnTyp3,@CTN4=ph.CtnTyp4,@CTN5=ph.CtnTyp5
from orders o (nolock) 
join mbol m (nolock) on (o.mbolkey=m.mbolkey)
join packheader ph (nolock) on (o.orderkey=ph.orderkey)
where o.storerkey ='FJ' and doctype ='E'
--and  m.shipdate BETWEEN DATEADD(DAY, -7, GETDATE()) AND CONVERT(DATE, GETDATE())
and  m.shipdate BETWEEN @SEVENDAYAGO AND @TTODAY
ORDER BY PH.CtnTyp5 DESC,PH.CtnTyp4 DESC,PH.CtnTyp3 DESC,PH.CtnTyp2 DESC



--SELECT @CTN1,@CTN2,@CTN3,@CTN4,@CTN5



IF @CTN5<>''
BEGIN
	--SELECT 'CTN5 HAS VALUE'
	insert into  #FJ_Weekly_CartonReport (                    
	Carton_Type,                    
	CTN_QTY    
	) select ph.CtnTyp5 as 'CartonType',count(1) as 'CTN QTY' 
	from orders o (nolock) 
	join mbol m (nolock) on (o.mbolkey=m.mbolkey)
	join packheader ph (nolock) on (o.orderkey=ph.orderkey)
	where o.storerkey ='FJ' and doctype ='E'
	and ph.CtnTyp5 <>''
	--and  m.shipdate BETWEEN DATEADD(DAY, -7, GETDATE()) AND CONVERT(DATE, GETDATE())
	and  m.shipdate BETWEEN @SEVENDAYAGO AND @TTODAY
	group by ph.CtnTyp5
END

IF @CTN4<>''
BEGIN
	--SELECT 'CTN4 HAS VALUE'
	insert into  #FJ_Weekly_CartonReport (                    
	Carton_Type,                    
	CTN_QTY    
	) select ph.CtnTyp4 as 'CartonType',count(1) as 'CTN QTY' 
	from orders o (nolock) 
	join mbol m (nolock) on (o.mbolkey=m.mbolkey)
	join packheader ph (nolock) on (o.orderkey=ph.orderkey)
	where o.storerkey ='FJ' and doctype ='E'
	and ph.CtnTyp4 <>''
	--and  m.shipdate BETWEEN DATEADD(DAY, -7, GETDATE()) AND CONVERT(DATE, GETDATE())
	and  m.shipdate BETWEEN @SEVENDAYAGO AND @TTODAY
	group by ph.CtnTyp4
END



IF @CTN3<>''
BEGIN
	--SELECT 'CTN3 HAS VALUE'
	insert into  #FJ_Weekly_CartonReport (                    
	Carton_Type,                    
	CTN_QTY    
	) select ph.CtnTyp3 as 'CartonType',count(1) as 'CTN QTY' 
	from orders o (nolock) 
	join mbol m (nolock) on (o.mbolkey=m.mbolkey)
	join packheader ph (nolock) on (o.orderkey=ph.orderkey)
	where o.storerkey ='FJ' and doctype ='E'
	and ph.CtnTyp3 <>''
	--and  m.shipdate BETWEEN DATEADD(DAY, -7, GETDATE()) AND CONVERT(DATE, GETDATE())
	and  m.shipdate BETWEEN @SEVENDAYAGO AND @TTODAY
	group by ph.CtnTyp3
END


IF @CTN2<>''
BEGIN
	--SELECT 'CTN2 HAS VALUE'
	insert into  #FJ_Weekly_CartonReport (                    
	Carton_Type,                    
	CTN_QTY    
	) select ph.CtnTyp2 as 'CartonType',count(1) as 'CTN QTY' 
	from orders o (nolock) 
	join mbol m (nolock) on (o.mbolkey=m.mbolkey)
	join packheader ph (nolock) on (o.orderkey=ph.orderkey)
	where o.storerkey ='FJ' and doctype ='E'
	and ph.CtnTyp2 <>''
	--and  m.shipdate BETWEEN DATEADD(DAY, -7, GETDATE()) AND CONVERT(DATE, GETDATE())
	and  m.shipdate BETWEEN @SEVENDAYAGO AND @TTODAY
	group by ph.CtnTyp2
END



insert into  #FJ_Weekly_CartonReport (                    
Carton_Type,                    
CTN_QTY                  
)  select ph.ctntyp1 as 'CartonType',count(1) as 'CTN QTY' 
from orders o (nolock) 
join mbol m (nolock) on (o.mbolkey=m.mbolkey)
join packheader ph (nolock) on (o.orderkey=ph.orderkey)
where o.storerkey ='FJ' and doctype ='E'
--and  m.shipdate BETWEEN DATEADD(DAY, -7, GETDATE()) AND CONVERT(DATE, GETDATE())
and  m.shipdate BETWEEN @SEVENDAYAGO AND @TTODAY
group by ph.ctntyp1


                   
select Carton_Type,sum(CTN_QTY) as 'CTN_QTY' 
from #FJ_Weekly_CartonReport(nolock)
group by Carton_Type
order by Carton_Type


--DROP table #FJ_Weekly_CartonReport          
    
END 

GO