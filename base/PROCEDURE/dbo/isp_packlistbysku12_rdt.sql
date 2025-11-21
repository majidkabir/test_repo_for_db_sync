SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Proc: isp_PackListBySku12_rdt                                 */    
/* Creation Date: 15-APR-2019                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: CSCHONG                                                  */    
/*                                                                      */    
/* Purpose: WMS-7781 -convert printing to SPooler                       */    
/*        :                                                             */    
/* Called By: r_dw_packing_list_by_Sku12e_rdt                           */    
/*          :                                                           */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author   Ver   Purposes                                  */  
/* 27-MAR-2020 ALiang 1.1   INC1092542- Support multi OD with same SKU  */     
/************************************************************************/    
CREATE PROC [dbo].[isp_PackListBySku12_rdt]    
     @c_PickSlipNo        NVARCHAR(10),    
     @c_StartCartonNo     NVARCHAR(10) = '',    
     @c_EndCartonNo       NVARCHAR(10) = ''    
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
    
 WHILE @@TRANCOUNT > 0    
 BEGIN    
  COMMIT TRAN    
 END    
    
 IF ISNULL(@c_StartCartonno,'') = ''    
 BEGIN    
   SET @c_StartCartonno = '1'    
 END    
    
    
 IF ISNULL(@c_EndCartonno,'') = ''    
 BEGIN    
   SET @c_EndCartonno = '99999'    
 END    
    
 SELECT Orderkey = O.Orderkey     
 --  ,   ExternOrderKey = ISNULL(RTRIM(PH.OrderRefNo), '')     
   ,   O.Storerkey     
   ,   ST_Company = ISNULL(RTRIM(ST.Company), '')     
   ,   PickSlipNo = PH.PickSlipNo     
   ,   MCompany    =  ISNULL(RTRIM(O.m_Company), '')    
   ,   Address1   =  ISNULL(RTRIM(o.c_Address1), '')                                    
   ,   Address2   =  ISNULL(RTRIM(o.c_Address2), '')         
   ,   Address3   =  ISNULL(RTRIM(o.c_Address3), '')                                  
   ,   Address4   =  ISNULL(RTRIM(o.c_Address4), '')                                
   ,   SGWGT      = S.STDGROSSWGT                               
   ,   SCUBE      = S.STDCUBE                               
   ,   Contact1   =  ISNULL(RTRIM(o.c_Contact1), '')    
 --,   ODQty     = MIN(OD.originalQty)   AL 1.1   
   ,   ODQty     = SUM(OD.originalQty)     
   ,   CartonNo   = ISNULL(PD.CartonNo, 0)     
   ,   TotalCarton= (SELECT COUNT(DISTINCT CartonNo)FROM PACKDETAIL WITH (NOLOCK) WHERE PACKDETAIL.PickSlipNo = PH.PickSlipNo)    
   ,   SKU = LEFT(PD.Sku,8)                                                    --CS01    
   ,   Qty        = ISNULL(PD.Qty,0)    
   ,   PICQTY     = ISNULL(PIF.qty,0)    
   ,   PHEdate    = MIN(PH.editdate)    
   ,   BUSR1    =  CASE WHEN o.userdefine02 = 'en' THEN ISNULL(RTRIM(S.BUSR1), '') else ISNULL(RTRIM(S.Descr), '') END               --(CS01)    
   ,   A2 = lbl.A2--CASE WHEN ISNULL(C1.Code,'')='A2' THEN C1.Notes ELSE '' END    
   ,   A3 = lbl.A3--CASE WHEN ISNULL(C1.Code,'')='A3' THEN C1.Notes ELSE '' END    
   ,   A4 = lbl.A4--CASE WHEN ISNULL(C1.Code,'')='A4' THEN C1.Notes ELSE '' END    
   ,   B1 = lbl.B1--CASE WHEN ISNULL(C1.Code,'')='B1' THEN C1.Notes ELSE '' END    
   ,   B3 = lbl.B3--CASE WHEN ISNULL(C1.Code,'')='B3' THEN C1.Notes ELSE '' END    
   --,   B4 = ISNULL(c1.long,'') + ISNULL(C1.udf01,'') + ISNULL(C1.UDF02,'')    
   --         + ISNULL(C1.UDF03,'') + ISNULL(C1.UDF04,'')    
   ,   B4 = lbl.B4    
   ,   B5 = lbl.B5--CASE WHEN ISNULL(C1.Code,'')='B5' THEN C1.Notes ELSE '' END        
   ,   B7 = lbl.B7--CASE WHEN ISNULL(C1.Code,'')='B7' THEN C1.Notes ELSE '' END         
   ,   B9 = lbl.B9--CASE WHEN ISNULL(C1.Code,'')='B9' THEN C1.Notes ELSE '' END         
   ,   B10 = lbl.B10--CASE WHEN ISNULL(C1.Code,'')='B10' THEN C1.Notes ELSE '' END    
   ,   B11 = lbl.B11--CASE WHEN ISNULL(C1.Code,'')='B11' THEN C1.Notes ELSE '' END         
   ,   B12 = lbl.B12--CASE WHEN ISNULL(C1.Code,'')='B12' THEN C1.Notes ELSE '' END       
   ,   B14 = lbl.B14--CASE WHEN ISNULL(C1.Code,'')='B14' THEN C1.Notes ELSE '' END           
   ,   B16 = lbl.B16--CASE WHEN ISNULL(C1.Code,'')='B16' THEN C1.Notes ELSE '' END    
   ,   B18 = lbl.B18--CASE WHEN ISNULL(C1.Code,'')='B18' THEN C1.Notes ELSE '' END    
   ,   B21 = lbl.B21--CASE WHEN ISNULL(C1.Code,'')='B21' THEN C1.Notes ELSE '' END    
   ,   C1 = lbl.C1--CASE WHEN ISNULL(C1.Code,'')='C1' THEN C1.Notes ELSE '' END    
   ,   C3 = lbl.C3--CASE WHEN ISNULL(C1.Code,'')='C3' THEN C1.Notes ELSE '' END    
   ,   C5 = lbl.C5--CASE WHEN ISNULL(C1.Code,'')='C5' THEN C1.Notes ELSE '' END    
   ,   C7 = lbl.C7--CASE WHEN ISNULL(C1.Code,'')='C7' THEN C1.Notes ELSE '' END    
   ,   B4b = lbl.B4b    
 FROM ORDERS     O  WITH (NOLOCK)    
 JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=O.OrderKey    
 JOIN STORER     ST WITH (NOLOCK) ON (ST.StorerKey = O.Storerkey)    
 JOIN PACKHEADER PH WITH (NOLOCK) ON (O.Orderkey = PH.Orderkey AND O.Storerkey = PH.Storerkey)    
 JOIN PACKDETAIL PD WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo and PD.SKU = OD.SKU)    
 JOIN SKU         S WITH (NOLOCK) ON (S.Storerkey = PD.Storerkey)    
            AND(S.Sku = PD.Sku)    
 LEFT JOIN STORER C WITH (NOLOCK) ON (C.StorerKey = O.storerkey)    
 LEFT JOIN PACKINFO PIF WITH (NOLOCK) ON PIF.Pickslipno = PD.PickSlipNo AND PIF.cartonno = PD.CartonNo    
 LEFT JOIN fnc_GetPacksku12Label (@c_PickSlipNo) lbl ON (lbl.pickslipno = PH.Pickslipno)    
 --LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.LISTNAME='IKEADel' AND C1.storerkey = O.StorerKey AND c1.short=o.Userdefine08    
 WHERE  PH.PickSlipNo = @c_PickSlipNo     
 AND PD.CartonNo >= CAST(@c_StartCartonno as INT)     
 AND PD.CartonNo <= CAST(@c_EndCartonno as INT)     
 GROUP BY O.Orderkey     
    ,   ISNULL(RTRIM(PH.OrderRefNo), '')     
    ,   O.Storerkey     
    ,   ISNULL(RTRIM(ST.Company), '')     
    ,   PH.PickSlipNo    
    ,   ISNULL(RTRIM(O.m_Company), '')    
    ,   ISNULL(RTRIM(O.C_Address1), '')    
    ,   ISNULL(RTRIM(O.C_Address2), '')    
    ,   ISNULL(RTRIM(O.C_Address3), '')    
    ,   ISNULL(RTRIM(O.C_Address4), '')    
    ,   S.STDGROSSWGT,S.STDCUBE    
    ,   ISNULL(RTRIM(O.C_Contact1), '')    
    ,  CASE WHEN o.userdefine02 = 'en' THEN ISNULL(RTRIM(S.BUSR1), '') else ISNULL(RTRIM(S.Descr), '') END         --CS01    
    ,   ISNULL(PD.CartonNo, 0)    
    ,   LEFT(PD.Sku,8) -- PD.Sku             --CS01    
 --    ,   PH.editdate    
   ,lbl.A2    
   ,lbl.A3    
   ,lbl.A4    
   ,lbl.B1    
   ,lbl.B3    
   ,lbl.B4    
   ,lbl.B5    
   ,lbl.B7    
   ,lbl.B9    
   ,lbl.B10      
   ,lbl.B11    
   ,lbl.B12    
   ,lbl.B14    
   ,lbl.B16    
   ,lbl.B18    
   ,lbl.B21          
   ,lbl.C1    
   ,lbl.C3    
   ,lbl.C5    
   ,lbl.C7    
   ,lbl.B4    
   ,lbl.B4b    
   , ISNULL(PD.Qty,0)    
   ,ISNULL(PIF.qty,0)    
   --,   ISNULL(c1.long,'') + ISNULL(C1.udf01,'') + ISNULL(C1.UDF02,'')    
   --       + ISNULL(C1.UDF03,'') + ISNULL(C1.UDF04,'')    
   Order by PH.PickSlipNo,ISNULL(PD.CartonNo, 0) ,O.Orderkey ,LEFT(PD.Sku,8) --PD.Sku       --CS01    
    
 WHILE @@TRANCOUNT < @n_StartTCnt    
 BEGIN    
  BEGIN TRAN    
 END    
    
END -- procedure    


GO