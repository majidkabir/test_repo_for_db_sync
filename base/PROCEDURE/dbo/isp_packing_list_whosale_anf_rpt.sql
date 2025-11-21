SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_packing_list_whosale_anf_rpt                   */
/* Creation Date: 2020-11-06                                            */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-15501 ANF - Wholesale Packing List - New                */
/*                                                                      */
/* Called By: r_dw_packing_list_wholesale_anf_rpt                       */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 19-NOV-2020  CSCHONG 1.1   WMS-15501 revised field logic (CS01)      */
/* 27-JAN-2021  CSCHONG 1.1   WMS-15501 revised field logic (CS02)      */
/************************************************************************/

CREATE PROC [dbo].[isp_packing_list_whosale_anf_rpt]
         (  @c_wavekey     NVARCHAR(20)
         )           
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_NoOfLine  INT
         , @n_TotDetail INT
         , @n_LineNeed  INT
         , @n_SerialNo  INT
         , @b_debug     INT

  DECLARE @c_ordkey NVARCHAR(10)
        ,@c_GPickslipno NVARCHAR(10)
        ,@n_GetCartonno INT
        ,@n_CartonNo1 INT
        ,@n_cartonqty INT
        ,@n_MaxRecGrp INT
        ,@n_TTLPID    INT
   
   SET @n_NoOfLine = 10
   SET @n_TotDetail= 0
   SET @n_LineNeed = 0
   SET @n_SerialNo = 0
   SET @b_debug    = 0

   SET @n_cartonno1 = 0
   SET @n_cartonqty=0
   SET @n_TTLPID= 1
   --SET @n_MaxRecGrp = 0


      CREATE TABLE #TMP_PICKHDRWSANF
            (  SeqNo         INT  IDENTITY(1,1) NOT NULL   
            ,  OrderKey      NVARCHAR(10)     
            ,  TTLCTN        INT
            ,  B_Company     NVARCHAR(45)  
            ,  B_Address1    NVARCHAR(45) 
            ,  B_City        NVARCHAR(45)
            ,  B_Address2    NVARCHAR(45)
            ,  M_Company     NVARCHAR(45)  
            ,  M_Address2    NVARCHAR(45) 
            ,  M_contact1    NVARCHAR(45) 
            ,  M_contact2    NVARCHAR(45)
            ,  BuyerNote     NVARCHAR(4000)
            ,  B_Address3    NVARCHAR(45)
            ,  B_Address4    NVARCHAR(45) 
            ,  SupplierBrand NVARCHAR(250) 
            ,  SupplierRef   NVARCHAR(250)  
            ,  ODNotes       NVARCHAR(4000) 
            ,  ODNotes2      NVARCHAR(4000) 
            ,  ODUDF08       NVARCHAR(50)     
            ,  SKU           NVARCHAR(20)    
            ,  PQty          INT  
            ,  NetWGT        FLOAT
            ,  GrossWGT      FLOAT
            ,  CaseID        NVARCHAR(20)
            ,  Wavekey       NVARCHAR(20)
            )

     CREATE TABLE #TMP_RANKPICKHDRWSANF
     ( wavekey        NVARCHAR(20),
       caseid         NVARCHAR(20),
       seqno          INT
   )

   INSERT INTO #TMP_RANKPICKHDRWSANF (wavekey,caseid,seqno)
   SELECT @c_wavekey,pd.caseid,(Rank() OVER ( ORDER BY pd.caseid Asc))
   FROM ORDERS OH (nolock)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'AFWSPRTNER' and C.code=OH.ConsigneeKey
   LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname='ANFDIV' and C1.code=substring(OH.Consigneekey,4,1)
   JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.orderkey=OD.orderkey AND PD.orderlinenumber=OD.Orderlinenumber AND PD.SKU = OD.SKU
   JOIN SKU S WITH (NOLOCK) ON S.storerkey = PD.Storerkey and S.SKU = PD.sku
   WHERE OH.UserDefine09 = @c_wavekey
   group by pd.caseid
   order by caseid

      INSERT INTO #TMP_PICKHDRWSANF
            (  OrderKey 
            ,  TTLCTN             
            ,  B_Company     
            ,  B_Address1     
            ,  B_City    
            ,  B_Address2     
            ,  M_Company     
            ,  M_Address2     
            ,  M_contact1     
            ,  M_contact2     
            ,  BuyerNote        
            ,  B_Address3      
            ,  B_Address4         
            ,  SupplierBrand      
            ,  SupplierRef    
            ,  ODNotes     
            ,  ODNotes2 
            ,  ODUDF08               
            ,  SKU               
            ,  PQty               
            ,  NetWGT              
            ,  GrossWGT 
            ,  CaseID   
            ,  Wavekey          
            )
    SELECT DISTINCT '',--OH.Orderkey,
           count(distinct pd.caseid),
           --(Row_Number() OVER (PARTITION BY pd.caseid ORDER BY pd.caseid,OD.sku Asc)) AS recgrp, 
           ISNULL(ST.B_Company,''),ISNULL(ST.B_Address1,''),ISNULL(ST.B_City,''),ISNULL(ST.B_Address2,''),ISNULL(M_Company,''),
           CASE WHEN ISNULL(C.short,'') = 'ASOS' THEN ISNULL(M_Address1,'') 
                WHEN ISNULL(C.short,'') = 'ZALANDO' THEN ISNULL(M_Address2,'')  ELSE '' END AS M_Address,
           ISNULL(M_Contact1,''),ISNULL(M_Contact2,''),ISNULL(C.notes,'') as BuyerNote,ISNULL(ST.B_Address3,''),ISNULL(ST.B_Address4,''),
           ISNULL(C1.description,'') AS SupplierBrand,
           ISNULL(C.Long,'') + '_' + ISNULL(C.udf01,'') +'_' +  REPLACE(convert(nvarchar(10),getdate(),103),'/',' ') as SupplierRef,ISNULL(OD.notes,''),
           ISNULL(OD.notes2,''),ISNULL(OD.UserDefine08,''),
           CASE WHEN OD.Userdefine07 <> '' THEN OD.Userdefine07
                WHEN OD.Userdefine06 <> '' THEN OD.Userdefine06
                WHEN OD.altsku <> '' THEN OD.altsku  
                Else S.Altsku END,
          CASE WHEN S.Prepackindicator='N' THEN SUM(PD.qty) ELSE  SUM(PD.qty) * (BM.Qty) END,         --CS02
          S.STDGROSSWGT,CAST(C.udf02 as FLOAT),PD.CaseID,@c_wavekey--PD.CaseID
FROM ORDERS OH (nolock)
JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey
LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'AFWSPRTNER' and C.code=OH.ConsigneeKey
LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname='ANFDIV' and C1.code=substring(OH.Consigneekey,4,1)
JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.orderkey=OD.orderkey AND PD.orderlinenumber=OD.Orderlinenumber AND PD.SKU = OD.SKU
JOIN SKU S WITH (NOLOCK) ON S.storerkey = PD.Storerkey and S.SKU = PD.sku
LEFT JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = OH.Storerkey
--LEFT JOIN BillOfMaterial BOM WITH (NOLOCK) ON BOM.storerkey = S.storerkey AND BOM.sku=S.sku
   OUTER APPLY (SELECT BOM.sku as sku,sum(bom.qty) as qty  
                FROM BillOfMaterial BOM WITH (NOLOCK) 
                WHERE  BOM.storerkey = S.storerkey AND BOM.sku=S.sku
                group by bom.sku) AS BM 
WHERE OH.UserDefine09 = @c_wavekey
GROUP BY --OH.Orderkey,
         ISNULL(ST.B_Company,''),ISNULL(ST.B_Address1,''),ISNULL(ST.B_City,''),ISNULL(ST.B_Address2,''),ISNULL(M_Company,''),
         CASE WHEN ISNULL(C.short,'') = 'ASOS' THEN ISNULL(M_Address1,'') 
              WHEN ISNULL(C.short,'') = 'ZALANDO' THEN ISNULL(M_Address2,'')  ELSE '' END,
         ISNULL(M_Contact1,''),ISNULL(M_Contact2,''),ISNULL(C.notes,'') ,ISNULL(ST.B_Address3,''),ISNULL(ST.B_Address4,''),
         ISNULL(C1.description,'') ,ISNULL(OD.notes,''),
         ISNULL(OD.notes2,''),ISNULL(OD.UserDefine08,''), 
         CASE WHEN OD.Userdefine07 <> '' THEN OD.Userdefine07
                WHEN OD.Userdefine06 <> '' THEN OD.Userdefine06
                WHEN OD.altsku <> '' THEN OD.altsku  
                Else S.Altsku END,
         S.STDGROSSWGT,CAST(C.udf02 as FLOAT),
         ISNULL(C.Long,''),ISNULL(C.udf01,''),PD.Caseid,S.Prepackindicator,(BM.Qty)
--ORDER BY pd.caseid,OH.Orderkey


  SELECT @n_TTLPID = max(seqno)
  from #TMP_RANKPICKHDRWSANF
  where Wavekey = @c_wavekey

      
      SELECT DISTINCT OrderKey 
            ,  @n_TTLPID as TTLCTN             
            ,  B_Company     
            ,  B_Address1     
            ,  B_City    
            ,  B_Address2     
            ,  M_Company     
            ,  M_Address2     
            ,  M_contact1     
            ,  M_contact2     
            ,  BuyerNote        
            ,  B_Address3      
            ,  B_Address4         
            ,  SupplierBrand      
            ,  SupplierRef    
            ,  ODNotes     
            ,  ODNotes2 
            ,  ODUDF08               
            ,  SKU               
            ,  SUM(PQTY) as PQty               
            ,  NetWGT              
            ,  GrossWGT 
            ,  rpa.CaseID 
            ,  pa.Wavekey  
            , rpa.seqno
      FROM #TMP_PICKHDRWSANF PA
      JOIN #TMP_RANKPICKHDRWSANF RPA ON RPA.wavekey = PA.Wavekey and RPA.caseid = PA.CaseID
      GROUP BY OrderKey      
          --  ,  TTLCTN     
            ,  B_Company     
            ,  B_Address1     
            ,  B_City    
            ,  B_Address2     
            ,  M_Company     
            ,  M_Address2     
            ,  M_contact1     
            ,  M_contact2     
            ,  BuyerNote        
            ,  B_Address3      
            ,  B_Address4         
            ,  SupplierBrand      
            ,  SupplierRef    
            ,  ODNotes     
            ,  ODNotes2 
            ,  ODUDF08               
            ,  SKU                            
            ,  NetWGT              
            ,  GrossWGT 
            ,  rpa.CaseID   
            ,  pa.Wavekey
            ,  rpa.seqno
      ORDER BY caseid,sku  
      
      DROP TABLE #TMP_PICKHDRWSANF
      GOTO QUIT_SP
   
   QUIT_SP:
END       

GO