SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Proc: isp_PackListBySku12                                     */    
/* Creation Date: 30-MAR-2018                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: Wan                                                      */    
/*                                                                      */    
/* Purpose: WMS-4391 -CN-IKEA-Packing list                              */    
/*        :                                                             */    
/* Called By: r_dw_packing_list_by_Sku12                                */    
/*          :                                                           */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author   Ver   Purposes                                  */    
/* 29-OCT-2018 CSCHONG  1.1   WMS-4391-revised field logic (CS01)       */    
/* 15-AUG-2019 WLChooi  1.2   WMS-10249 - Add new field (WL01)          */    
/* 27-DEC-2019 CSCHONG  1.3   WMS-11546 - revised field logic (CS02)    */   
/* 27-MAR-2020 ALiang   1.4   INC1092542- Support multi OD with same SKU*/   
/* 13-JUL-2020 WLChooi  1.5   WMS-14186 - Add column level decryption   */
/*                            (WL02)                                    */
/************************************************************************/    
CREATE PROC [dbo].[isp_PackListBySku12]    
     @c_Storerkey         NVARCHAR(20),    
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

   --WL02 START
   DECLARE @c_Orderkey NVARCHAR(10) = '',
           @b_success  INT = 1,
           @n_Err      INT = 0,
           @c_ErrMsg   NVARCHAR(255) = ''

   SELECT @c_Orderkey = Orderkey
   FROM PACKHEADER (NOLOCK)
   WHERE Pickslipno = @c_PickSlipNo

   CREATE TABLE #TMP_DECRYPTEDDATA (
      Orderkey     NVARCHAR(10) NULL,
      C_contact1   NVARCHAR(45) NULL,
      C_Address1   NVARCHAR(45) NULL,
      C_Address2   NVARCHAR(45) NULL,
      C_Address3   NVARCHAR(45) NULL,
      C_Address4   NVARCHAR(45) NULL,
   )

   CREATE NONCLUSTERED INDEX IDX_TMP_DECRYPTEDDATA ON #TMP_DECRYPTEDDATA (Orderkey)

   EXEC isp_Open_Key_Cert_Orders_PI
      @n_Err    = @n_Err    OUTPUT,
      @c_ErrMsg = @c_ErrMsg OUTPUT

   IF ISNULL(@c_ErrMsg,'') <> ''
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END

   INSERT INTO #TMP_DECRYPTEDDATA
   SELECT Orderkey, C_contact1, C_Address1, C_Address2, C_Address3, C_Address4 
   FROM fnc_GetDecryptedOrderPI(@c_Orderkey)
   --WL02 END
      
   SELECT Orderkey = O.Orderkey     
   --,   ExternOrderKey = ISNULL(RTRIM(PH.OrderRefNo), '')     
     ,   O.Storerkey     
     ,   ST_Company = ISNULL(RTRIM(ST.Company), '')     
     ,   PickSlipNo = PH.PickSlipNo     
     ,   MCompany    =  ISNULL(RTRIM(O.m_Company), '')    
     ,   Address1   =  ISNULL(RTRIM(t.c_Address1), '')   --WL02                                
     ,   Address2   =  ISNULL(RTRIM(t.c_Address2), '')   --WL02          
     ,   Address3   =  ISNULL(RTRIM(t.c_Address3), '')   --WL02                                   
     ,   Address4   =  ISNULL(RTRIM(t.c_Address4), '')   --WL02                                  
     ,   SGWGT      = S.STDGROSSWGT                               
     ,   SCUBE      = S.STDCUBE                               
     ,   Contact1   =  ISNULL(RTRIM(t.c_Contact1), '')   --WL02     
   --,   ODQty     = MIN(OD.originalQty)  
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
     ,   DropID = ISNULL(PD.DropID,'')     --WL01     
     ,   C8 = lbl.C8                       --CS02    
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
   LEFT JOIN #TMP_DECRYPTEDDATA t on t.Orderkey = O.Orderkey   --WL02
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
      ,   ISNULL(RTRIM(t.c_Address1), '')   --WL02    
      ,   ISNULL(RTRIM(t.c_Address2), '')   --WL02    
      ,   ISNULL(RTRIM(t.c_Address3), '')   --WL02    
      ,   ISNULL(RTRIM(t.c_Address4), '')   --WL02    
      ,   S.STDGROSSWGT,S.STDCUBE    
      ,   ISNULL(RTRIM(t.C_Contact1), '')   --WL02      
      ,  CASE WHEN o.userdefine02 = 'en' THEN ISNULL(RTRIM(S.BUSR1), '') else ISNULL(RTRIM(S.Descr), '') END         --CS01    
      ,   ISNULL(PD.CartonNo, 0)    
      ,   LEFT(PD.Sku,8) -- PD.Sku             --CS01    
   -- ,   PH.editdate    
      ,   lbl.A2    
      ,   lbl.A3    
      ,   lbl.A4    
      ,   lbl.B1    
      ,   lbl.B3    
      ,   lbl.B4    
      ,   lbl.B5    
      ,   lbl.B7    
      ,   lbl.B9    
      ,   lbl.B10      
      ,   lbl.B11    
      ,   lbl.B12    
      ,   lbl.B14    
      ,   lbl.B16    
      ,   lbl.B18    
      ,   lbl.B21          
      ,   lbl.C1    
      ,   lbl.C3    
      ,   lbl.C5    
      ,   lbl.C7    
      ,   lbl.B4    
      ,   lbl.B4b    
      ,   ISNULL(PD.Qty,0)    
      ,   ISNULL(PIF.qty,0)    
      ,   ISNULL(PD.DropID,'')     --WL01     
      ,   lbl.C8                   --CS02    
     --,   ISNULL(c1.long,'') + ISNULL(C1.udf01,'') + ISNULL(C1.UDF02,'')    
     --       + ISNULL(C1.UDF03,'') + ISNULL(C1.UDF04,'')    
      Order by PH.PickSlipNo,ISNULL(PD.CartonNo, 0) ,O.Orderkey ,LEFT(PD.Sku,8) --PD.Sku       --CS01    
      
   WHILE @@TRANCOUNT < @n_StartTCnt    
   BEGIN    
      BEGIN TRAN    
   END   
    
--WL02 START
QUIT_SP:
   IF @n_continue=3  -- Error Occured - Process And Return  
    BEGIN  
       SELECT @b_success = 0  
       IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt  
       BEGIN  
          ROLLBACK TRAN  
       END  
       ELSE  
       BEGIN  
          WHILE @@TRANCOUNT > @n_starttcnt  
          BEGIN  
             COMMIT TRAN  
          END  
       END  
       execute nsp_logerror @n_err, @c_errmsg, "isp_PackListBySku12"  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
       RETURN  
    END  
    ELSE  
    BEGIN  
       SELECT @b_success = 1  
       WHILE @@TRANCOUNT > @n_starttcnt  
       BEGIN  
          COMMIT TRAN  
       END  
       RETURN  
    END
--WL02 END

END -- procedure    


GO