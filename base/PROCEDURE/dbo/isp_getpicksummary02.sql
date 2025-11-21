SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Stored Proc: isp_GetPickSummary02                                    */      
/* Creation Date: 29-JAN-2018                                           */      
/* Copyright: LF Logistics                                              */      
/* Written by: Wan                                                      */      
/*                                                                      */      
/* Purpose: WMS-3053 - PH Picklist Barcode Summary Report               */      
/*        :                                                             */      
/* Called By: r_dw_pick_summary_02                                      */      
/*          :                                                           */      
/* PVCS Version: 1.1                                                    */      
/*                                                                      */      
/* Version: 7.0                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date     Author      Ver    Purposes                                 */     
/* 19-APR-2018 LZG      1.1    Group same PickSlipNo together           */  
/*                               for any copy (ZG01)                    */  
/* 28-JUN-2018 CSCHONG  1.2    WMS-5401 - add new field (CS01)          */  
/************************************************************************/      
CREATE PROC [dbo].[isp_GetPickSummary02]   
         @c_LoadKey        NVARCHAR(10)      
      ,  @c_RptCopy        NVARCHAR(30)      
      
AS      
BEGIN      
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE        
           @n_StartTCnt       INT      
         , @n_Continue        INT       
      
      
   SET @n_StartTCnt = @@TRANCOUNT      
   SET @n_Continue = 1      
  
 CREATE TABLE #TEMPPS02  
 ( rptseq         INT,  
   facility       NVARCHAR(10),  
   storerkey      NVARCHAR(20),  
   loadkey        NVARCHAR(10),  
   externorderkey NVARCHAR(30),  
   c_company      NVARCHAR(45),  
   printdate      DATETIME,  
   pickslipno     NVARCHAR(20),  
   pickdesc      NVARCHAR(30),  
   rptcopy        NVARCHAR(30),  
   ohgrp          NVARCHAR(30),  
   ohdoor         NVARCHAR(30)  
 )  
      
  CREATE TABLE #TEMPGRPPS02  
 ( loadkey  NVARCHAR(10),  
   pickdesc NVARCHAR(30),  
   pageno   INT,  
   ttlpage  INT)  
      
   SELECT Loadkey = @c_Loadkey, SeqNo, RptCopy = ColValue      
         ,CopyDescr = ColValue + '''s Copy'      
   INTO #TMP_RPTCOPY      
   FROM dbo.fnc_DelimSplit('|', 'Picker|Team Leader')      
   WHERE ColValue = CASE WHEN @c_RptCopy = 'ALL' THEN ColValue ELSE @c_RptCopy END      
  
QUIT_SP:      
    
  
   INSERT INTO #TEMPPS02(rptseq,  
         facility,  
         storerkey,  
         loadkey,  
         externorderkey,  
         c_company,  
         printdate,  
         pickslipno,  
         pickdesc,  
         rptcopy,  
         ohgrp,  
         ohdoor)  
   SELECT RptSeq = ROW_NUMBER() OVER ( ORDER BY OH.Loadkey      
                                             ,  LOC.PickZone      
                                             ,  PD.UOM      
                                             ,  RPT.CopyDescr       -- ZG01  
                                             ,  ISNULL(RTRIM(PD.PickSlipNo),'')      
                                             ,  ISNULL(RTRIM(OH.Externorderkey),'')      
                                             ,  RPT.SeqNo)      
         ,Facility = OH.Facility      
         ,StorerKey= OH.StorerKey      
         ,Loadkey = OH.Loadkey      
         ,Externorderkey = ISNULL(RTRIM(OH.Externorderkey),'')      
         ,C_Company = ISNULL(RTRIM(OH.C_Company),'')      
         ,PrintDate = GETDATE()      
         ,PickSlipNo= ISNULL(RTRIM(PD.PickSlipNo),'')      
         ,PICKDESC = RTRIM(LOC.PickZone)      
                    + '-'      
                    + CASE WHEN PD.UOM = '1' THEN 'Full Pallet'      
                           WHEN PD.UOM = '7' THEN 'Pieces'      
         --CS01 Start  
                           --WHEN LOC.PickZone = 'BULK' AND PD.UOM = '2' THEN 'Partail Pallet'       
                           --WHEN LOC.PickZone <>'BULK' AND PD.UOM = '2' THEN 'Full Case'             
                           --WHEN LOC.PickZone <>'BULK' AND PD.UOM = '6' THEN 'Pieces'  
         WHEN LOC.Locationtype not in ('CASE','PICK') AND PD.UOM in('2','3') THEN 'Partail Pallet'       
                           WHEN LOC.Locationtype in ('CASE','PICK') AND PD.UOM in ('2','3')  THEN 'Full Case'             
                           WHEN LOC.Locationtype in ('CASE','PICK') AND PD.UOM = '6' THEN 'Pieces'  
         --CS01 End      
                           END      
         ,rptcopy = RPT.CopyDescr      
         ,OHGRP = ISNULL(OH.OrderGroup,'')                              --(CS01)  
         ,OHDoor = ISNULL(OH.Door,'')                                   --(CS01)     
   FROM ORDERS OH WITH (NOLOCK)      
   JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.Orderkey = PD.OrderKey)      
   JOIN LOC LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)        
   JOIN #TMP_RPTCOPY RPT ON (OH.loadkey = RPT.Loadkey)      
   WHERE OH.Loadkey = @c_LoadKey      
   GROUP BY OH.Facility      
         ,  OH.StorerKey      
         ,  OH.Loadkey      
         ,  ISNULL(RTRIM(OH.Externorderkey),'')      
         ,  ISNULL(RTRIM(OH.C_Company),'')      
         ,  ISNULL(RTRIM(PD.PickSlipNo),'')      
         ,  LOC.PickZone      
         ,  PD.UOM      
         ,  RPT.SeqNo      
         ,  RPT.CopyDescr  
         ,  ISNULL(OH.OrderGroup,'')                              --(CS01)      
         ,   ISNULL(OH.Door,'')                                   --(CS01)  
         ,   RTRIM(LOC.PickZone)      
                    + '-'      
                    + CASE WHEN PD.UOM = '1' THEN 'Full Pallet'      
                           WHEN PD.UOM = '7' THEN 'Pieces'      
         --CS01 Start  
                           --WHEN LOC.PickZone = 'BULK' AND PD.UOM = '2' THEN 'Partail Pallet'       
                           --WHEN LOC.PickZone <>'BULK' AND PD.UOM = '2' THEN 'Full Case'             
                           --WHEN LOC.PickZone <>'BULK' AND PD.UOM = '6' THEN 'Pieces'  
         WHEN LOC.Locationtype not in ('CASE','PICK') AND PD.UOM in('2','3') THEN 'Partail Pallet'       
                           WHEN LOC.Locationtype in ('CASE','PICK') AND PD.UOM in ('2','3')  THEN 'Full Case'             
                           WHEN LOC.Locationtype in ('CASE','PICK') AND PD.UOM = '6' THEN 'Pieces'  
         --CS01 End      
                           END      
   ORDER BY OH.Loadkey      
         ,  LOC.PickZone      
         ,  PD.UOM      
         ,  RPT.CopyDescr       -- ZG01  
         ,  ISNULL(RTRIM(PD.PickSlipNo),'')      
         ,  ISNULL(RTRIM(OH.Externorderkey),'')      
         ,  RPT.SeqNo      
  
  
   INSERT INTO #TEMPGRPPS02 (loadkey,pickdesc,pageno,ttlpage)  
   SELECT DISTINCT loadkey,PICKDESC  
         ,pageno= ROW_NUMBER() OVER ( ORDER BY loadkey,PICKDESC)  
         ,ttlpage = CASE WHEN COUNT(1) > 8 THEN 2 ELSE 1 END  
   FROM #TEMPPS02  
   GROUP BY loadkey,PICKDESC  
  
     
 select TP02.RptSeq,TP02.Facility, TP02.StorerKey,TP02.Loadkey,TP02.Externorderkey, TP02.C_Company,  
        TP02.PrintDate,TP02.PickSlipNo,TP02.PICKDESC,TP02.rptcopy,TP02.OHGRP,TP02.OHDoor  
       ,TGP02.pageno,TGP02.ttlpage  
 FROM #TEMPPS02 TP02  
 JOIN #TEMPGRPPS02 TGP02 ON TGP02.loadkey = TP02.loadkey and TGP02.PICKDESC = TP02.PICKDESC  
 ORDER BY TP02.RptSeq   
END -- procedure 


GO