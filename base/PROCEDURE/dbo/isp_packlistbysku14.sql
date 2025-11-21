SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Proc: isp_PackListBySku14                                     */    
/* Creation Date: 17-FEB-2020                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: CSCHONG                                                  */    
/*                                                                      */    
/* Purpose: WMS-12103 SG - PMI - Packing List                           */    
/*        :                                                             */    
/* Called By: r_dw_packing_list_by_Sku14                                */    
/*          :                                                           */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author   Ver   Purposes                                  */    
/************************************************************************/    
CREATE PROC [dbo].[isp_PackListBySku14]  
           @c_PickSlipNo   NVARCHAR(10)    
          ,@c_recgrp       NVARCHAR(5) = 'H'  
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE      
           @n_StartTCnt       INT    
         , @n_Continue        INT  
         , @c_orderkey        NVARCHAR(20)     
    
    
   SET @n_StartTCnt = @@TRANCOUNT    
   SET @n_Continue = 1    
    
   WHILE @@TRANCOUNT > 0    
   BEGIN    
      COMMIT TRAN    
   END    
  
   IF @c_recgrp = 'H'  
   BEGIN  
      GOTO Header  
   END  
   ELSE  
   BEGIN  
      GOTO Detail  
   END  
  
 HEADER:   
 SELECT O.Orderkey     
   ,   ExternOrderKey = ISNULL(RTRIM(O.ExternOrderKey), '')     
   ,   O.Storerkey      
   ,   Consigneekey = ISNULL(RTRIM(O.ConsigneeKey), '')     
   ,   PickSlipNo = PH.PickSlipNo     
   ,   Company    = ISNULL(RTRIM(O.c_Company), '')     
   ,   Address1   = ISNULL(RTRIM(O.c_Address1), '')                              
   ,   Address2   = ISNULL(RTRIM(O.c_Address2), '')       
   ,   Address3   = ISNULL(RTRIM(O.c_Address3), '')                            
   ,   Address4   = ISNULL(RTRIM(O.c_Address4), '')                          
   ,   C_Zip      = ISNULL(RTRIM(o.c_zip), '')                       
   ,   OHRoute    = ISNULL(RTRIM(o.Route), '')                               
   ,   Country    = ISNULL(RTRIM(O.c_Country), '')                               
   ,   DelDate    = O.DeliveryDate                      
   ,   Altsku     = S.ALTSKU                            
   ,   SDescr    = ISNULL(RTRIM(S.DESCR), '')     
   ,   labelno   = ISNULL(PD.labelno, '')     
   ,   TotalCarton= (SELECT COUNT(DISTINCT labelno)FROM PACKDETAIL WITH (NOLOCK) WHERE PACKDETAIL.PickSlipNo = PH.PickSlipNo)    
   ,   PD.Sku    
   ,   QtyCtn    = ISNULL(SUM(FLOOR(PD.Qty/P.OtherUnit1)),0)    
   ,   QtyPack   = ISNULL(SUM(FLOOR(PD.Qty%CAST(P.OtherUnit1 as integer))),0)    
 FROM ORDERS     O  WITH (NOLOCK)    
 JOIN STORER     ST WITH (NOLOCK) ON (ST.StorerKey = O.Storerkey)    
 JOIN PACKHEADER PH WITH (NOLOCK) ON (O.Orderkey = PH.Orderkey AND O.Storerkey = PH.Storerkey)    
 JOIN PACKDETAIL PD WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)    
 JOIN SKU         S WITH (NOLOCK) ON (S.Storerkey = PD.Storerkey)    
                                  AND(S.Sku = PD.Sku)    
 LEFT JOIN PACK P WITH (NOLOCK) ON  P.PackKey = S.PACKKey  
 WHERE  PH.PickSlipNo = @c_PickSlipNo     
   GROUP BY O.Orderkey     
      ,   ISNULL(RTRIM(O.ExternOrderKey), '')    
      ,   O.Storerkey     
      ,   PH.PickSlipNo    
      ,   ISNULL(RTRIM(O.ConsigneeKey), '')     
      ,   ISNULL(RTRIM(O.C_Company), '')   
      ,   ISNULL(RTRIM(O.C_Address1), '')    
      ,   ISNULL(RTRIM(O.C_Address2), '')    
      ,   ISNULL(RTRIM(O.C_Address3), '')    
      ,   ISNULL(RTRIM(O.C_Address4), '')    
      ,   ISNULL(RTRIM(o.Route), '')   
      ,   ISNULL(RTRIM(O.C_Zip), '')    
      ,   ISNULL(RTRIM(O.C_Country), '')    
      ,   O.DeliveryDate   
      ,   S.ALTSKU     
      ,   ISNULL(PD.labelno, '')     
      ,   PD.Sku    
      ,   ISNULL(RTRIM(S.DESCR), '')   
   ORDER BY ISNULL(PD.labelno, '')  
   GOTO QUIT  
     
    
  DETAIL:  
  
  CREATE TABLE #TEMP_PLBSKU14 (  
  Storerkey  NVARCHAR(20),  
  Orderkey   NVARCHAR(20),  
  sku     NVARCHAR(20),  
  Sdescr      NVARCHAR(250),  
  ODQTY       INT,  
  REMQTY     INT,  
  --AASQTYCTN  INT,  
  --OOSQTYPACK INT,  
  Pickslipno NVARCHAR(20),  
  OtherUnit1 FLOAT  
  
  --Sdescr     NVARCHAR(250),  
  
  )   
  
  SET @c_orderkey = ''  
  
  SELECT DISTINCT @c_orderkey = PD.Orderkey  
  FROM PICKDETAIL PD (nolock)  
  where PD.PickSlipNo = @c_PickSlipNo  
  
  INSERT INTO #TEMP_PLBSKU14 (storerkey,Orderkey,sku,Sdescr,Pickslipno,ODQTY,REMQTY,OtherUnit1)  
  select distinct od.storerkey as storerkey,od.orderkey as orderkey, od.altsku as sku,max(s.descr) as sdescr,isnull(pd.pickslipno,'') as pickslipno  
, (OD.OriginalQty) as ODQTY,(OD.OriginalQty-OD.QtyPicked-ShippedQty) as REMQTY,max(p.otherunit1) as otherunit1  
   from orderdetail od (nolock)  
   join sku s (nolock) on s.storerkey = od.StorerKey and s.altsku=od.altsku  
   LEFT JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Storerkey = OD.StorerKey AND pd.orderkey = OD.OrderKey AND OD.sku = PD.sku   
             and pd.OrderLineNumber=od.OrderLineNumber  
   join pack p ( nolock) on p.packkey = s.packkey  
   where od.orderkey = @c_orderkey  
   group by od.storerkey,od.orderkey, od.altsku,pd.pickslipno,OD.OriginalQty,(OD.OriginalQty-OD.QtyPicked-ShippedQty)  
  
   select od.sku as altsku,OD.sdescr as sdescr  
   ,sum(Floor(OD.ODQTY/otherunit1)) as ODQTY,case when sum(Floor(OD.ODQTY%CAST(OD.otherunit1 as integer)))<otherunit1   
      THEN sum(OD.ODQTY%CAST(OD.otherunit1 as integer)) else 0 END as ODPQTY  
   ,floor(sum((REMQTY))/otherunit1) as AASQTYCTN  
   ,ISNULL((FLOOR(sum((REMQTY))%CAST(OD.otherunit1 as integer))),0) as OOSQTYPACK  
   ,OD.Pickslipno  
  FROM #TEMP_PLBSKU14 OD WITH (NOLOCK)   
      --JOIN SKU         S WITH (NOLOCK) ON (S.Storerkey = OD.Storerkey)    
      --                            AND(S.AltSku = OD.Sku)    
                                  --AND S.sku = OD.sku  
     --LEFT JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Storerkey = OD.StorerKey AND pd.orderkey = OD.OrderKey AND OD.sku = PD.sku   
     --        and pd.OrderLineNumber=od.OrderLineNumber  
     --LEFT JOIN PACK P WITH (NOLOCK) ON  P.PackKey = S.PACKKey  
  where od.orderkey=@c_orderkey  
  and ((REMQTY)) > 0  
  group by od.pickslipno,od.sku,od.sdescr,OD.otherunit1  
     ORDER BY od.sku  
  
  goto quit  
  
  QUIT:  
  
  drop table #TEMP_PLBSKU14  
  
   WHILE @@TRANCOUNT < @n_StartTCnt    
   BEGIN    
      BEGIN TRAN    
   END    
    
END -- procedure


GO