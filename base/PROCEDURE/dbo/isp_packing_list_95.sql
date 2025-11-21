SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 
/******************************************************************************/              
/* Store Procedure: isp_Packing_List_95                                       */              
/* Creation Date: 12-JAN-2021                                                 */              
/* Copyright: IDS                                                             */              
/* Written by: CSCHONG                                                        */              
/*                                                                            */              
/* Purpose: WMS-16011 - [CN] PVH_Packing list_CR                              */  
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_packing_list_95                                           */              
/*                                                                            */              
/* PVCS Version: 1.0                                                          */              
/*                                                                            */              
/* Version: 1.0                                                               */              
/*                                                                            */              
/* Data Modifications:                                                        */              
/*                                                                            */              
/* Updates:                                                                   */              
/* Date         Author    Ver.  Purposes                                      */    
/******************************************************************************/     
  
CREATE PROC [dbo].[isp_Packing_List_95]             
           (@c_Pickslipno NVARCHAR(10),
            @c_Type       NVARCHAR(10) = 'H')              
AS            
BEGIN            
   SET NOCOUNT ON            
   SET ANSI_WARNINGS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @c_MCompany        NVARCHAR(45)  
         , @c_Externorderkey  NVARCHAR(30)  
         , @c_C_Addresses     NVARCHAR(200)   
         , @c_loadkey         NVARCHAR(10)  
         , @c_Userdef03       NVARCHAR(20)  
         , @c_salesman        NVARCHAR(30)  
         , @c_phone1          NVARCHAR(18)
         , @c_contact1        NVARCHAR(30)  
  
         , @n_TTLQty          INT   
         , @c_shippername     NVARCHAR(45)  
         , @c_Sku             NVARCHAR(20)  
         , @c_Size            NVARCHAR(5)  
         , @c_PickLoc         NVARCHAR(10) 
         , @n_NoOfLine        INT  
         , @c_getOrdKey       NVARCHAR(10)
         , @c_rpttype         NVARCHAR(20)
         , @c_OHUDF03         NVARCHAR(50)
         , @c_storerkey       NVARCHAR(20)

 SET @n_NoOfLine = 6
 SET @c_getOrdKey = ''
 SET @c_rpttype = ''             
 SET @c_OHUDF03 = ''

 IF ISNULL(@c_Type,'') = '' SET @c_Type = 'H' 
  
  
 CREATE TABLE #PACKLIST95 
         ( c_Contact1      NVARCHAR(30) NULL 
         , C_Addresses     NVARCHAR(200) NULL 
         , c_phone1        NVARCHAR(45) NULL
         , OrdDate         NVARCHAR(10) NULL
         , M_Company       NVARCHAR(45) NULL   
         , PickLOC         NVARCHAR(10)  NULL 
         , PickSlipno      NVARCHAR(20) NULL   
         , SNotes1         NVARCHAR(120) NULL 
         , PSKU            NVARCHAR(20)  NULL
         , Pqty            INT               
         , OrderKey        NVARCHAR(10)  NULL          
         , RecGrp          INT
         , A01             NVARCHAR(200)  NULL
         , A02             NVARCHAR(200)  NULL
         , A03             NVARCHAR(200)  NULL
         , A04             NVARCHAR(200)  NULL
         , A05             NVARCHAR(200)  NULL
         , A06             NVARCHAR(200)  NULL
         , A07             NVARCHAR(200)  NULL
         , A08             NVARCHAR(200)  NULL
         , A09             NVARCHAR(200)  NULL
         , A10             NVARCHAR(200)  NULL
         , A11             NVARCHAR(200)  NULL
         , A12             NVARCHAR(200)  NULL
         , A13             NVARCHAR(200)  NULL
         , A14             NVARCHAR(200)  NULL
         , A15             NVARCHAR(200)  NULL 
         , A16             NVARCHAR(200)  NULL 
         , A17             NVARCHAR(200)  NULL 
         , A18             NVARCHAR(200)  NULL 
         , A19             NVARCHAR(200)  NULL 
         , A20             NVARCHAR(200)  NULL 
         , A21             NVARCHAR(200)  NULL
         , A22             NVARCHAR(200)  NULL
         , A23             NVARCHAR(200)  NULL
         , A24             NVARCHAR(200)  NULL
         , A25             NVARCHAR(200)  NULL
         , A26             NVARCHAR(200)  NULL
         , A27             NVARCHAR(200)  NULL
         , A28             NVARCHAR(200)  NULL
         , CompanyDesc     NVARCHAR(120)  NULL 
         , RptType         NVARCHAR(20) NULL
         )  
         
         
   /*CS01 Start*/
   
   IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)
              WHERE Orderkey = @c_Pickslipno)
   BEGIN
      SET @c_getOrdKey = @c_Pickslipno 
   END           
   ELSE
   BEGIN
      SELECT DISTINCT @c_getOrdKey = OrderKey
      FROM PackHeader AS ph WITH (NOLOCK)
      WHERE ph.PickSlipNo=@c_Pickslipno
   END   

   SELECT @c_OHUDF03 = OH.Userdefine03
          ,@c_storerkey = OH.Storerkey
   FROM ORDERS OH WITH (NOLOCK)
   WHERE OH.Orderkey = @c_getOrdKey

   SELECT @c_rpttype = RTRIM(C.short)
   FROM Codelkup  C WITH (nolock)
   WHERE c.listname = 'PVHshop'
   AND C.code = @c_OHUDF03
  AND C.storerkey = @c_storerkey
   
   /*CS01 END*/ 
  
  INSERT INTO #PACKLIST95 ( c_Contact1    
                           , C_Addresses   
                           , c_phone1    
                           , OrdDate    
                           , M_Company     
                           , PickLOC       
                           , PickSlipno       
                           , SNotes1     
                           , PSKU          
                           , Pqty          
                           , OrderKey       
                           , RecGrp  
                           ,  A01       
                           ,  A02   
                           ,  A03  
                           ,  A04    
                           ,  A05    
                           ,  A06    
                           ,  A07    
                           ,  A08    
                           ,  A09    
                           ,  A10    
                           ,  A11    
                           ,  A12
                           ,  A13     
                           ,  A14  
                           ,  A15    
                           ,  A16    
                           ,  A17
                           ,  A18
                           ,  A19  
                           ,  A20
                           ,  A21 
                           ,  A22
                           ,  A23
                           ,  A24
                           ,  A25
                           ,  A26
                           ,  A27
                           ,  A28  
                           , CompanyDesc    
                           , RptType
                        )             
   SELECT ISNULL(OH.c_Contact1,''),(OH.C_address2 + OH.C_address3 + OH.C_address4),
                   ISNULL(OH.c_phone1,''),CONVERT(NVARCHAR(10),OH.OrderDate,23),ISNULL(OH.M_Company,''),
                   PD.LOC,PH.PickSlipno,ISNULL(S.notes1,''),PD.SKU,PD.qty,OH.OrderKey,1
                   --(Row_Number() OVER (PARTITION BY PD.Orderkey ORDER BY PD.LOC Asc)-1)/@n_NoOfLine 
                 ,   A1 = lbl.A01                                   
                 ,   A2 = lbl.A02
                 ,   A3 = lbl.A03
                 ,   A4 = lbl.A04
                 ,   A5 = lbl.A05
                 ,   A6 = lbl.A06
                 ,   A7 = lbl.A07
                 ,   A8 = lbl.A08
                 ,   A9 = lbl.A09
                 ,   A10 = lbl.A10
                 ,   A11 = lbl.A11
                 ,   A12 = lbl.A12
                 ,   A13 = lbl.A13 
                 ,   A14 = lbl.A14 
                 ,   A15 = lbl.A15
                 ,   A16 = lbl.A16
                 ,   A17 = lbl.A17
                 ,   A18 = lbl.A18 
                 ,   A19 = lbl.A19
                 ,   A20 = lbl.A20
                 ,   A21 = lbl.A21 
                 ,   A22 = lbl.A22
                 ,   A23 = lbl.A23
                 ,   A24 = lbl.A24
                 ,   A25 = lbl.A25
                 ,   A26 = lbl.A26
                 ,   A27 = lbl.A27
                 ,   A28 = lbl.A28 
                 ,   CompanyDesc = ISNULL(C.description,'')   
                 ,   RptType = @c_rpttype
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = OH.Orderkey
   JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey 
                            AND PD.orderlinenumber = ORDDET.orderlinenumber
   JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.Storerkey=PD.Storerkey
   JOIN STORER STO WITH (NOLOCK) ON OH.shipperkey = STO.Storerkey  
   JOIN PACKHEADER PH WITH (NOLOCK) ON PH.Orderkey = OH.Orderkey     
   LEFT JOIN fnc_PackingList95 (@c_getOrdKey) lbl ON (lbl.orderkey = OH.Orderkey)   
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.code=OH.userdefine03 and C.listname='PVHshop' 
   AND   C.storerkey=OH.StorerKey                 
   WHERE PD.Orderkey = @c_getOrdKey
   --AND PD.Caseid = CASE WHEN ISNULL(@c_labelno,'') <> '' THEN  @c_labelno ELSE PD.Caseid END
   ORDER By PD.LOC

  IF @c_Type = 'H'
  BEGIN
        SELECT DISTINCT Pickslipno,Orderkey,RptType
        FROM #PACKLIST95  
        ORDER BY Pickslipno,Orderkey
  END
  ELSE
  BEGIN

      SELECT c_Contact1    
                           , C_Addresses   
                           , c_phone1    
                           , OrdDate    
                           , M_Company     
                           , PickLOC       
                           , PickSlipno       
                           , SNotes1     
                           , PSKU          
                           , Pqty          
                           , OrderKey       
                           , RecGrp  
                           ,  A01       
                           ,  A02   
                           ,  A03  
                           ,  A04    
                           ,  A05    
                           ,  A06    
                           ,  A07    
                           ,  A08    
                           ,  A09    
                           ,  A10    
                           ,  A11    
                           ,  A12
                           ,  A13     
                           ,  A14  
                           ,  A15    
                           ,  A16    
                           ,  A17
                           ,  A18
                           ,  A19  
                           ,  A20
                           ,  A21 
                           ,  A22
                           ,  A23
                           ,  A24
                           ,  A25
                           ,  A26
                           ,  A27
                           ,  A28 
                           ,  CompanyDesc
   FROM #PACKLIST95  
   ORDER BY Pickslipno,Orderkey,PickLoc  
    
  END
               
END



GO