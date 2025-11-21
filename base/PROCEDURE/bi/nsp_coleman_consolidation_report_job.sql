SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/******************************************************************************/  
/* DB: KRWMS                                                                  */  
/* Purpose: Report that consolidates inventory via in/out/return              */  
/* Requester: KR DC5 Coleman Team                                             */  
/*                                                                            */  
/* Modifications log:                                                         */  
/*                                                                            */  
/* Date       Rev  Author     Purposes										  */
/* 2019-09-30 1.0  Cloud      Created									      */
/* 2022-12-06 1.1  Min        Edited to fit KRWMS for Logireport              */
/* 2023-02-07 1.1  Min        KR_Create SP in BI schema for LogiReport	https://jiralfl.atlassian.net/browse/LFPM926-759 */  
/*                                                                            */  
/******************************************************************************/  

--execute BI.nsp_Coleman_consolidation_report_job 'COLEMAN','20190801','20190802'

CREATE   PROCEDURE [BI].[nsp_Coleman_consolidation_report_job](
	  @cInventoryDate DATE)
as
BEGIN
      SET NOCOUNT ON;  -- keeps the output generated to a minimum 
      SET ANSI_NULLS OFF;
      SET QUOTED_IDENTIFIER OFF;
      SET CONCAT_NULL_YIELDS_NULL OFF;

IF OBJECT_ID('tempdb..#result','u') IS NOT NULL  DROP TABLE #result;
	Create table #result(
	DATE date NOT NULL,
	SKU NVARCHAR(20) NOT NULL,
	DESCRIPTION NVARCHAR(200) NOT NULL,
	INBOUND INT NOT NULL,
	OUTBOUND INT NOT NULL,
	RTN INT NOT NULL,
	INVENTORY INT NOT NULL
	)

IF OBJECT_ID('tempdb..#result_Inv','u') IS NOT NULL  DROP TABLE #result_Inv;
	Create table #result_Inv(
	DATE date NOT NULL,
	SKU NVARCHAR(20) NOT NULL,
	HOLD_QTY INT NOT NULL,
	DMG_QTY INT NOT NULL,
	AVA_QTY INT NOT NULL
	)

IF OBJECT_ID('tempdb..#result_IBD','u') IS NOT NULL  DROP TABLE #result_IBD;
	Create table #result_IBD(
	DATE date NOT NULL,
	SKU NVARCHAR(20) NOT NULL,
	IBD_QTY INT NOT NULL
	)

IF OBJECT_ID('tempdb..#result_OBD','u') IS NOT NULL  DROP TABLE #result_OBD;
	Create table #result_OBD(
	DATE date NOT NULL,
	SKU NVARCHAR(20) NOT NULL,
	OBD_QTY INT NOT NULL
	)

IF OBJECT_ID('tempdb..#result_RTN','u') IS NOT NULL  DROP TABLE #result_RTN;
	Create table #result_RTN(
	DATE date NOT NULL,
	SKU NVARCHAR(20) NOT NULL,
	RTN_QTY INT NOT NULL
	)


--declare cursor
DECLARE CMCursor CURSOR    

FOR	SELECT max(inventorydate) FROM  BI.V_DAILYINVENTORY(nolock)
WHERE storerkey = 'COLEMAN' and InventoryDate >= @cInventoryDate

--open cursor    
OPEN CMCursor

--start cursor
FETCH NEXT FROM  CMCursor INTO @cInventoryDate
WHILE @@FETCH_STATUS =0

BEGIN
Insert into #result(
DATE,SKU,DESCRIPTION,INBOUND,OUTBOUND,RTN,INVENTORY)
SELECT @cInventoryDate,sku,descr,'','','','' 
FROM BI.V_SKU(nolock)
WHERE storerkey = 'coleman'

INSERT INTO #result_Inv(date,sku,HOLD_QTY,DMG_QTY,AVA_QTY)
SELECT 
inventorydate,
sku,
sum(case when loc = 'cm-hold' then qty else '0' end),
sum(case when loc = 'cm-damage' then qty else '0' end),
sum(case when loc in('cm-hold','cm-damage') then '0' else qty-qtyallocated-qtypicked end)
 FROM  BI.V_DAILYINVENTORY(nolock)
WHERE storerkey = 'coleman' and inventorydate = @cInventoryDate
GROUP BY inventorydate,sku

INSERT INTO #result_IBD(date,sku,IBD_QTY)
SELECT cast(editdate as date),sku,sum(qty)  
FROM BI.v_itrn(nolock) 
WHERE storerkey = 'coleman' and sourcetype = 'ntrReceiptDetailUpdate'
and cast(editdate as date) = @cInventoryDate
GROUP BY cast(editdate as date),sku

INSERT INTO #result_OBD(date,sku,OBD_QTY)
SELECT cast(editdate as date),sku,sum(qty)  
FROM BI.v_itrn(nolock) 
WHERE storerkey = 'coleman' and sourcetype = 'ntrPickDetailUpdate'
and cast(editdate as date) = @cInventoryDate
GROUP BY cast(editdate as date),sku


        FETCH NEXT FROM  CMCursor INTO @cInventoryDate
    END    

--close cursor
CLOSE CMCursor
--release cursor
DEALLOCATE CMCursor

SELECT 
a.date as [date],
a.sku as [SKU],
a.description as [DESCRIPTION]
,CASE WHEN isnull(c.IBD_QTY,'') = ''  then '0' else c.IBD_QTY end as [Inbound]
,CASE WHEN ISNULL(d.OBD_QTY,'') = ''  then '0' else ABS(d.OBD_QTY) end as [Outbound]
,CASE WHEN ISNULL(e.RTN_QTY,'') = ''  then '0' else e.RTN_QTY end as [Return]
,CASE WHEN ISNULL(b.HOLD_QTY,'') = ''  then '0' else b.HOLD_QTY end as [Hold Inventory]
,CASE WHEN ISNULL(b.DMG_QTY,'') = ''  then '0' else b.DMG_QTY end as [Damage Inventory]
,CASE WHEN ISNULL(b.AVA_QTY,'') = ''  then '0' else b.AVA_QTY end as [Available Inventory]
 FROM #result as a
left join #result_INV as b on a.date = b.date and a.sku = b.sku
left join #result_IBD as c on a.date = c.date and a.sku = c.sku
left join #result_OBD as d on a.date = d.date and a.sku = d.sku
left join #result_RTN as e on a.date = e.date and a.sku = e.sku
GROUP BY A.DATE,A.SKU,a.description
,c.IBD_QTY
,d.OBD_QTY
,e.RTN_QTY
,b.HOLD_QTY
,b.DMG_QTY
,b.AVA_QTY
ORDER BY A.DATE,A.SKU

END

GO