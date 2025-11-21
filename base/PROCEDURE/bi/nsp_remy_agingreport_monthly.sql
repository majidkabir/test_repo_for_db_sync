SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                
/* Stored Procedure: nsp_Remy_AgingReport_Monthly                       */                
/* Creation Date:                                                       */                
/* Copyright: LFL                                                       */                
/* Written by:                                                          */                
/*                                                                      */                
/* Purpose:                                                             */                
/*                                                                      */                
/* Called By: Hyperion Rpt                                              */                
/*                                                                      */                
/* Data Modifications:                                                  */                
/*                                                                      */                
/* Updates:                                                             */                
/* Date         Author  Rev   Purposes                                  */                
/* 01-Jan-2017  stv  1.0   First version              */             
/* 27-Nov-2020  Jessica 2.0   update   [好货/QC] /b标准箱数量            */            
/* 30-Dec-2021  stv     2.1   Add six facility                          */   
/* 15-Aug-2021  Aaron Fang     2.2   CN - Remy - AgingReport_JReport_SP_to_BI_Schema   https://jiralfl.atlassian.net/browse/WMS-23263 */ 
/************************************************************************/              
--- exec nsp_Remy_AgingReport_Monthly            
            
CREATE   PROCEDURE [BI].[nsp_Remy_AgingReport_Monthly]            
 @m_storerkey NVARCHAR(10) = '18332'            
AS            
BEGIN            
 Declare @m_count int = 0            
 Declare @m_facilityList nvarchar(2000) = '647,BS10,BS13,CBD01,CBD02,CBD03,CBD10,CBD23,CBD24,CBD25,CDP01,CDP02,CDP03,CDP07,CDP09,CDP12,CDP21,CDR03,CDR04,CDR06,CDR07,CDR08,CDR09,CDR10,CDR11,CDR12,CDP18,CDR20,CDLY,KT04D,WH01,WH03,CBD09,CDP11,CBD12,RCKIT*B,R
  
            
CKIT*D,CKT01,RCKIT*F,CKT01,CDP22,CDP13,AL02,CDP10,CDRCB,LY13,PY06,REMYE,WH05,BTS02,AL02D,18E1,HY10,BS15,CDRDM';            
 SELECT DISTINCT F1 AS Facility into #FacilityList FROM CNLOCAL.dbo.f_splitstr (@m_facilityList,',')                            
            
BEGIN TRY            
 SELECT lli.Storerkey,lli.Sku, lli.Lot,lli.Loc,lli.ID,            
  lli.Qty,lli.QtyAllocated,lli.QtyPicked,lli.QtyExpected,lli.QtyPickInProcess,lli.PendingMoveIN,lli.QtyReplen,            
  Available = lli.Qty - lli.QtyAllocated - lli.QtyPicked ,            
  Lot.Lottable01,Lot.Lottable02,Lot.Lottable03,Lot.Lottable04,Lot.Lottable05,Lot.Lottable06,            
  [Defect description] =  C1.Description ,            
  [Status] = C1.short ,            
  [Defect type] = C1.Long,            
  Lot.Lottable07,Lot.Lottable08,Lot.Lottable09,Lot.Lottable10,Lot.Lottable11,Lot.Lottable12,Lot.Lottable13,Lot.Lottable14,Lot.Lottable15,            
  F.Facility,            
  S.Descr,S.Style,SI.ExtendedField01 as [Color],S.Size,            
  Category = ISNULL(SI.ExtendedField02,'') ,            
  [Product Size] = ISNULL(SI.ExtendedField21,''),            
  [Size(Litre)]= case when SI.ExtendedField02= N'酒' then S.Size else '' end ,             
  PK = case when SI.ExtendedField02= N'酒' then pack.casecnt else NULL END,             
  [Facility定义] = case when F.facility = 'CKT01' and l.loc='RCKIT*D' then 'DP'            
         when F.facility = 'CKT01' and l.loc='RCKIT*B' then 'Bonded'            
       else case when charindex(N'CBD',F.facility) > 0 then 'Bonded' else 'DP' end end ,            
  --[好货/QC] = case when lot.Lottable07 = 'Y' then 'Repairable QC'            
  --     when lot.Lottable07 = 'N' then 'Non-repairable QC'            
  --     when ISNULL(lot.Lottable07,'') not in ('Y','N') then F.userdefine11 end ,            
  --[好货/QC] = case when lot.Lottable07 = 'Y' and f.Facility<>'CDP09' then 'Repairable QC'              
  --     when lot.Lottable07 = 'N' and f.Facility<>'CDP09' then 'Non-repairable QC'              
  --     when  f.Facility in (        
  --  'CDP07','CDP12','CKT01','CDR04','CBD24','CDR03','CDP01',        
  --  'CDP11','CDP02','CDP13','CDP21','CBD01','CBD23','CBD12','CDP03','CDP09')  then F.userdefine11                
  --  when lot.Lottable07 = '' and f.UserDefine11 ='' then N'好货'         
  --  when ISNULL(lot.Lottable07,'') not in ('Y','N')  then 'QC' END , --jESSICA          
  [好货/QC] = case      
when lot.Lottable07 = 'Y' and f.Facility in('CBD02','CDP02','CDP10') then 'Repairable QC'             
when lot.Lottable07 = 'N' and f.Facility in('CBD02','CDP02','CDP10') then 'Non-repairable QC'         
when lot.Lottable07 = '' and f.Facility ='CDP10' then N'好货'             
when  f.Facility not in('CBD02','CDP02','CDP10')  then F.userdefine11 END ,      
           
  Site = F.userdefine12,            
  --[标准箱数量] = case when SI.ExtendedField02= N'酒' then CAST(lli.Qty * cast (S.Size as float) / 8.4 as DECIMAL(15,1)) else NULL end ,            
      [标准箱数量] = case when SI.ExtendedField02= N'酒' then CAST(lli.Qty * cast (S.Size as float) / 8.4 as DECIMAL(16,2)) else NULL end ,  --Jessica       
    [入库日期] = CONVERT(varchar(100), Lot.Lottable05, 101) ,            
  [库存报表时间] = CONVERT(varchar(100), GETDATE(), 101),            
  [库龄] = DATEDIFF(DAY,Lot.Lottable05,GETDATE()),            
  [Inv Age Range] = case when DATEDIFF(DAY,Lot.Lottable05,GETDATE()) > 6*12*30 then N'above 6 years'            
          when DATEDIFF(DAY,Lot.Lottable05,GETDATE()) > 5*12*30 then N'5-6 years'             
          when DATEDIFF(DAY,Lot.Lottable05,GETDATE()) > 4*12*30 then N'4-5 years'             
          when DATEDIFF(DAY,Lot.Lottable05,GETDATE()) > 3*12*30 then N'3-4 years'             
          when DATEDIFF(DAY,Lot.Lottable05,GETDATE()) > 2*12*30 then N'2-3 years'            
          when DATEDIFF(DAY,Lot.Lottable05,GETDATE()) > 1*12*30 then N'1-2 years'            
          when DATEDIFF(DAY,Lot.Lottable05,GETDATE()) > 6*30.5   then N'6-12 months'            
          when DATEDIFF(DAY,Lot.Lottable05,GETDATE()) >= 0     then N'0-6 months'            
          else '??' end,            
  [Return Orders?] = case when charindex(N'退',Lot.Lottable09) > 0 then 'Return'             
        when charindex(N'回',Lot.Lottable09) > 0 then 'Return'             
        when charindex(N'RETURN',upper(Lot.Lottable09)) > 0 then 'Return'             
        else '' end,            
  [No of Pallet] = case when ROW_NUMBER() OVER(PARTITION BY lli.LOC ORDER BY lli.LOC) > 1 then 0 else ROW_NUMBER() OVER(PARTITION BY lli.LOC ORDER BY lli.LOC) end,            
  [Unit Cost] = S.Cost ,            
  [Total Cost] = lli.Qty * S.Cost            
  into #a            
 from BI.V_lotxlocxid lli(nolock)            
 join BI.V_lotattribute lot(nolock) on lli.storerkey = lot.storerkey and lli.lot = lot.lot             
 join BI.V_loc l(nolock) on lli.loc = l.loc            
 join BI.V_sku s(nolock) on lli.storerkey = s.storerkey and lli.sku = s.sku            
 join BI.V_Pack Pack(nolock) on pack.pacKkey  =  s.packkey            
 join BI.V_facility f(nolock) on l.facility = f.facility             
 join #FacilityList tempf (nolock) on tempf.facility = f.facility            
 left join BI.V_codelkup C1(nolock) on C1.listname = 'RMDeteCode' and C1.Storerkey = lli.Storerkey and C1.Code = lot.Lottable06             
 left join BI.V_SkuInfo SI(nolock) on S.Storerkey = SI.Storerkey and S.Sku = SI.SKu            
 where lli.storerkey = @m_storerkey AND LLi.Qty > 0             
END TRY            
BEGIN CATCH            
 PRINT 'Data Error'            
END CATCH            
             
 -- result export             
 SELECT @m_count = count(1) from #a WITH (NOLOCK)          
             
 IF @m_count <> 0            
  SELECT * FROM #a(NOLOCK)            
 ELSE            
  SELECT 'Data Error' as [Err Msg]            
END

GO