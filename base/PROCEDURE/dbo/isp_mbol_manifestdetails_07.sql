SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 
/******************************************************************************/              
/* Store Procedure: isp_Mbol_Manifestdetails_07                               */              
/* Creation Date: 10-SEP-2019                                                 */              
/* Copyright: IDS                                                             */              
/* Written by: CSCHONG                                                        */              
/*                                                                            */              
/* Purpose: WMS-10489 -  CN_PUMA_POD_Report(CR)                               */  
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_manifest_detail_07.srd                                    */              
/*                                                                            */              
/* PVCS Version: 1.0                                                          */              
/*                                                                            */              
/* Version: 1.0                                                               */              
/*                                                                            */              
/* Data Modifications:                                                        */              
/*                                                                            */              
/* Updates:                                                                   */              
/* Date         Author    Ver.  Purposes                                      */     
/* 2020-Apr-29  WLChooi   1.1   WMS-13127 - Add new column (WL01)             */
/******************************************************************************/     
  
CREATE PROC [dbo].[isp_Mbol_Manifestdetails_07]             
       (@c_Mbolkey  NVARCHAR(10))              
AS            
BEGIN            
   SET NOCOUNT ON            
   SET ANSI_WARNINGS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
  DECLARE @c_getmbolkey       NVARCHAR(10)
         ,@c_consigneekey     NVARCHAR(45)
         ,@c_short            NVARCHAR(10)
         ,@c_Preshort         NVARCHAR(10)
         ,@c_delimiter        NVARCHAR(1)
         ,@c_getnotes         NVARCHAR(50)
         
   CREATE TABLE #TEMPMANIFESTTBL07CAT
  ( mbolkey         NVARCHAR(10) NULL,
    Storerkey       NVARCHAR(15) NULL,
    UDF01           NVARCHAR(80) NULL,
    TTLCtn          INT)
  
   CREATE TABLE #TEMPMANIFESTTBL07
  ( mbolkey         NVARCHAR(10) NULL,
    Storerkey       NVARCHAR(15) NULL,
    Consigneekey    NVARCHAR(15) NULL,
    c_company       NVARCHAR(45) NULL,
    c_address1      NVARCHAR(45) NULL,
    c_address2      NVARCHAR(45) NULL,
    c_address3      NVARCHAR(45) NULL,
    c_address4      NVARCHAR(45) NULL,
    c_StateCity     NVARCHAR(95) NULL,
    c_zip           NVARCHAR(18) NULL,
    c_contact1      NVARCHAR(30) NULL,
    c_phone1        NVARCHAR(18) NULL,
    c_phone2        NVARCHAR(18) NULL,
    qty             INT,
    Company         NVARCHAR(45) NULL,
    Address1        NVARCHAR(30) NULL,
    Address2        NVARCHAR(30) NULL,
    Address3        NVARCHAR(30) NULL,
    Address4        NVARCHAR(30) NULL,
    Contact1        NVARCHAR(30) NULL,
    Phone1          NVARCHAR(30) NULL,
    CartonCnt       INT,
    Short           NVARCHAR(80) NULL,
    ProdUnit        NVARCHAR(150) NULL,
    Carrier_Company NVARCHAR(45) NULL,
    email1          NVARCHAR(60) NULL,
    Contact2        NVARCHAR(30) NULL,
    Phone2          NVARCHAR(30) NULL,
    editdate        DATETIME ,
    deliverydate    DATETIME,
    domain          NVARCHAR(10) NULL,
    notes1          NVARCHAR(4000) NULL,
    shipdate        DATETIME ,
    SHOWFOOTER      NVARCHAR(1),
    UDF01           NVARCHAR(60) NULL   --WL01
  )
  
   SET @c_delimiter =','
   SET @c_short = ''
   SET @c_Preshort = ''
   SET @c_getnotes = ','

   INSERT INTO #TEMPMANIFESTTBL07CAT (Storerkey,mbolkey,UDF01,TTLCtn)
   SELECT  O.Storerkey,MD.Mbolkey ,(Codelkup.UDF01) as UDF01 ,COUNT(distinct PD.labelno)
   FROM PackHeader PH WITH (NOLOCK) JOIN PACKDETAIL PD WITH (NOLOCK) ON ( PH.PickSlipNO = PD.PickSlipNO )   --IN00381920
   JOIN ORDERS O WITH (NOLOCK) ON ( PH.LoadKey = O.LoadKey  and PH.StorerKey = O.StorerKey)                 --IN00381920
   JOIN MBOLDETAIL MD WITH (NOLOCK) ON MD.Orderkey = O.Orderkey
   JOIN SKU SKU WITH (NOLOCK) ON ( PD.Storerkey = SKU.Storerkey  and PD.SKU = SKU.SKU)
   LEFT OUTER JOIN CodeLKUP WITH (NOLOCK) ON ( CodeLKUP.ListName = 'SKUFLAG' AND CodeLKUP.Code = RTRIM(SKU.skugroup))      
   WHERE MD.Mbolkey  =  @c_mbolkey
   GROUP by MD.Mbolkey,O.Storerkey,Codelkup.UDF01
  
   INSERT INTO #TEMPMANIFESTTBL07
  (
    mbolkey,Storerkey,Consigneekey,c_company,    
    c_address1,c_address2,c_address3,c_address4,    
    c_StateCity,c_zip,c_contact1,c_phone1,c_phone2,qty,    
    Company,Address1,Address2,Address3,Address4,    
    CONtact1,PhONe1,CartonCnt,    
    Short,ProdUnit,Carrier_Company,email1,    
    Contact2,PhoNe2,editdate,deliverydate,domain,    
    notes1,shipdate,SHOWFOOTER,
    UDF01 )   --WL01
    SELECT MBOL.Mbolkey,
         ORDERS.Storerkey,  
         ORDERS.Consigneekey,   
         ORDERS.C_Company,   
         ORDERS.C_Address1,   
         ORDERS.C_Address2,   
         ORDERS.C_Address3,   
         ORDERS.C_Address4,    
         RTRIM(ISNULL(ORDERS.C_State,''))+'('+RTRIM(ISNULL(ORDERS.C_City,'')) + ')' AS state_city,  
         ORDERS.C_Zip,    
         ORDERS.C_contact1,   
         ORDERS.C_Phone1,   
         ORDERS.C_Phone2, 
         QTY = SUM (ORDERDETAIL.ShippedQty + ORDERDETAIL.QtyPicked ),
         STORER.company,
         STORER.Address1,     
         STORER.Address2, 
         STORER.Address3,
         STORER.Address4,
         STORER.CONtact1,
         STORER.PhONe1,
         0,
         --CartonCnt = ISNULL(( 
         --   SELECT COUNT( DISTINCT PD.PickSlipNo +''+ CONVERT(char(10),PD.CartonNo) )
         --  FROM PackHeader PH WITH (NOLOCK) JOIN PACKDETAIL PD WITH (NOLOCK) ON ( PH.PickSlipNO = PD.PickSlipNO )   --IN00381920
         --            JOIN ORDERS O WITH (NOLOCK) ON ( PH.LoadKey = O.LoadKey  and PH.StorerKey = O.StorerKey)            --IN00381920
         --   WHERE O.Mbolkey  = MBOL.Mbolkey  
         --   AND   ISNULL(O.Consigneekey, '') = ISNULL(ORDERS.Consigneekey, '')), 0),
         /*Item_Type = Left(LTRIM(ORDERDETAIL.SKU), 1),*/
         ISNULL(CodeLKUP.udf01,'') as Short,
         ProdUnit = ISNULL(RTRIM(LTRIM(CodeLKUP.Long)), ''),
         Carrier_Company = ISNULL(CARRIER.Company, ''), 
         STORER.Email1, 
         STORER.CONtact2, 
         STORER.PhONe2,
         MBOL.Editdate, 
         MBOL.Editdate + ISNULL(cast(CL2.short as int),0) AS deliverydate, 
         CL3.Short AS Domain, 
         Notes1 = (SELECT ST.Notes1 FROM STORER ST WITH (NOLOCK) WHERE Storerkey = ORDERS.Storerkey) ,
         ShipDate =  MBOL.Shipdate,
         ISNULL(CL4.SHORT,'') AS SHOWFOOTER,
         ISNULL(CL5.UDF01,'')   --WL01
   FROM ORDERDETAIL WITH (NOLOCK)   
   JOIN ORDERS WITH (NOLOCK) ON ( ORDERDETAIL.OrderKey = ORDERS.OrderKey )   
   JOIN STORER WITH (NOLOCK) ON ( STORER.StorerKey = ORDERS.StorerKey )   
   JOIN MBOL WITH (NOLOCK)   ON ( ORDERDETAIL.Mbolkey = MBOL.Mbolkey )
   JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku)
   LEFT OUTER JOIN STORER CARRIER WITH (NOLOCK) ON ( MBOL.Carrierkey = CARRIER.Storerkey )
   LEFT OUTER JOIN CodeLKUP WITH (NOLOCK) ON ( CodeLKUP.ListName = 'SKUFLAG' AND CodeLKUP.Code = RTRIM(SKU.skugroup)) 
   LEFT OUTER JOIN Codelkup CL2 WITH (NOLOCK)  
        ON (CL2.Listname = 'CityLdTime' AND substring(CL2.code,1,4) = 'PUMA' AND CHARINDEX(LTRIM(RTRIM(CL2.description)), ORDERS.c_city) > 0)
   LEFT OUTER JOIN CODELKUP CL3 WITH (NOLOCK)  ON (CL3.Listname = 'STRDOMAIN' AND
                           CL3.Code = ORDERS.StorerKey) 
   LEFT OUTER JOIN CODELKUP CL4 WITH (NOLOCK)  ON (CL4.Listname = 'REPORTCFG' AND
                           CL4.Storerkey = ORDERS.StorerKey AND CL4.Long = 'r_dw_manifest_detail_07' AND CL4.Code = 'ShowFooter')
   OUTER APPLY ( SELECT MAX(ISNULL(CLK.UDF01,'')) AS UDF01 FROM CODELKUP CLK (NOLOCK)  --WL01
                 WHERE CLK.Listname = 'ORDERGROUP' AND CLK.Code = ORDERS.OrderGroup    --WL01
                 AND CLK.Storerkey = ORDERS.Storerkey ) AS CL5                         --WL01
   WHERE ( MBOL.Mbolkey = @c_mbolkey ) 
   GROUP BY  MBOL.Mbolkey,
         ORDERS.Storerkey,  
         ORDERS.Consigneekey,   
         ORDERS.C_Company,   
         ORDERS.C_Address1,   
         ORDERS.C_Address2,   
         ORDERS.C_Address3,   
         ORDERS.C_Address4,   
         ORDERS.C_City,   
         ORDERS.C_Zip,   
         ORDERS.C_contact1,   
         ORDERS.C_Phone1,  
         ORDERS.C_Phone2,  
         STORER.company,
         STORER.Address1,     
         STORER.Address2,
         STORER.Address3,
         STORER.Address4,
         STORER.CONtact1,
         STORER.PhONe1,
         CodeLKUP.udf01,
         ISNULL(RTRIM(LTRIM(CodeLKUP.Long)), ''),
         ISNULL(CARRIER.Company, ''), 
         STORER.Email1,   
         STORER.CONtact2, 
         STORER.PhONe2,
         ORDERS.C_State, 
         MBOL.Editdate,   
         CL2.short,  
         CL3.Short,
         MBOL.Shipdate,
         ISNULL(CL4.SHORT,''),
         ISNULL(CL5.UDF01,'')                 --WL01  
   
   SELECT T07.mbolkey as mbolkey,T07.Storerkey,T07.Consigneekey,T07.c_company,    
   T07.c_address1,T07.c_address2,T07.c_address3,T07.c_address4,    
   T07.c_StateCity,T07.c_zip,T07.c_contact1,T07.c_phone1,T07.c_phone2,qty as qty,    
   T07.Company,T07.Address1,T07.Address2,T07.Address3,T07.Address4,    
   T07.CONtact1,PhONe1,TC07.TTLCtn as CartonCnt,    
   T07.Short,T07.ProdUnit,T07.Carrier_Company,T07.email1,    
   T07.Contact2,T07.PhoNe2,T07.editdate,T07.deliverydate,T07.domain,    
   T07.notes1,T07.shipdate,T07.SHOWFOOTER,
   T07.UDF01   --WL01
   FROM #TEMPMANIFESTTBL07 T07 
   JOIN #TEMPMANIFESTTBL07CAT TC07 ON TC07.mbolkey = T07.mbolkey AND TC07.Storerkey = T07.Storerkey
                                  AND TC07.UDF01 = T07.Short
    --GROUP BY T07.mbolkey,T07.Storerkey,T07.Consigneekey,T07.c_company,    
    --T07.c_address1,T07.c_address2,T07.c_address3,T07.c_address4,    
    --T07.c_StateCity,T07.c_zip,T07.c_contact1,T07.c_phone1,T07.c_phone2,    
    --T07.Company,Address1,Address2,Address3,T07.Address4,    
    --T07.CONtact1,PhONe1,TC07.TTLCtn,
    --T07.Short,T07.ProdUnit,T07.Carrier_Company,T07.email1,    
    --T07.Contact2,PhoNe2,T07.editdate,T07.deliverydate,T07.domain,    
    --T07.notes1,T07.shipdate,T07.SHOWFOOTER
   ORDER BY T07.mbolkey desc
               
END



GO