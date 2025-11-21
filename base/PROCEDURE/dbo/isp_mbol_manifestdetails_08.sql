SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 
/******************************************************************************/              
/* Store Procedure: isp_Mbol_Manifestdetails_08                               */              
/* Creation Date: 31-MAR-2021                                                 */              
/* Copyright: IDS                                                             */              
/* Written by: CSCHONG                                                        */              
/*                                                                            */              
/* Purpose: WMS-16674-N - Lagardere POD Report                                */  
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_manifest_detail_08.srd                                    */              
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
  
CREATE PROC [dbo].[isp_Mbol_Manifestdetails_08]             
       (@c_Mbolkey      NVARCHAR(10)
        )              
AS            
BEGIN            
   SET NOCOUNT ON            
   SET ANSI_WARNINGS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @c_getmbolkey       NVARCHAR(10)
          ,@c_storerkey        NVARCHAR(10)
          ,@n_CntRec           INT
          ,@n_maxline          INT
          ,@n_Rowno            INT
          ,@n_getRowno         INT

  
   SET @c_storerkey = ''
   SET @n_CntRec = 1
   SET @n_maxline = 20
   SET @n_Rowno = 1
   
   SET @c_getmbolkey = ''

    
   SELECT TOP 1 @c_storerkey  = OH.storerkey
   FROM ORDERS OH WITH (NOLOCK)  
   WHERE OH.mbolkey = @c_Mbolkey 
   
   CREATE TABLE #TEMPMNFTBLD08
   (mbolkey         NVARCHAR(10) NULL,
    Storerkey       NVARCHAR(15) NULL,
    Consigneekey    NVARCHAR(20) NULL,
    st1company      NVARCHAR(45) NULL,
    st1address1     NVARCHAR(45) NULL,
    st1contact1     NVARCHAR(50) NULL,
    st1phone1       NVARCHAR(50) NULL,
    qty             INT NULL,
    st2company      NVARCHAR(45) NULL,
    ST2_add         NVARCHAR(250) NULL,
    STC2_Contact    NVARCHAR(80) NULL,
    CartonCnt       INT ,
    STC2_Phone      NVARCHAR(80) NULL,
    DELdate         DATETIME NULL ,
    Domain          NVARCHAR(10) NULL,
    shipdate        DATETIME NULL, 
    TransMethod     NVARCHAR(30) NULL,
    PODBarcode      NVARCHAR(120) DEFAULT('') ,
    Cntconsignee    INT    
   )

      INSERT INTO #TEMPMNFTBLD08
      (mbolkey,Storerkey,Consigneekey,st1company,    
       st1address1,st1contact1,st1phone1,  
       Qty,st2company,ST2_add,STC2_Contact,    
       CartonCnt,STC2_Phone,DELdate,shipdate,Domain,TransMethod,PODBarcode,Cntconsignee)
        SELECT MBOL.Mbolkey,
               ORDERS.Storerkey,  
               ORDERS.Consigneekey,   
               ISNULL(STC1.Company,'') AS ST1Company,   
               ISNULL(F.Address1,''),      
               ISNULL(F.contact1,''),   
               ISNULL(F.Phone1,''),   
         QTY = ISNULL(( 
                       SELECT SUM(PD.qty)
                       FROM PackHeader PH WITH (NOLOCK) JOIN PACKDETAIL PD WITH (NOLOCK) ON ( PH.PickSlipNO = PD.PickSlipNO )  
                       JOIN ORDERS O WITH (NOLOCK) ON ( PH.LoadKey = O.LoadKey  and PH.StorerKey = O.StorerKey)           
                       WHERE O.Mbolkey  = MBOL.Mbolkey  
                       AND   ISNULL(O.Consigneekey, '') = ISNULL(ORDERS.Consigneekey, '')), 0),
         ISNULL(STC2.company,'') ST2_Company,
         ISNULL(CL5.Notes,'') AS ST2_add,
         ISNULL(CL5.short,'') AS STC2_Contact,      
         CartonCnt = ISNULL(( 
            SELECT COUNT( DISTINCT PD.PickSlipNo +''+ CONVERT(char(10),PD.CartonNo) )
           FROM PackHeader PH WITH (NOLOCK) JOIN PACKDETAIL PD WITH (NOLOCK) ON ( PH.PickSlipNO = PD.PickSlipNO )   --IN00381920
                     JOIN ORDERS O WITH (NOLOCK) ON ( PH.LoadKey = O.LoadKey  and PH.StorerKey = O.StorerKey)            --IN00381920
            WHERE O.Mbolkey  = MBOL.Mbolkey  
            AND   ISNULL(O.Consigneekey, '') = ISNULL(ORDERS.Consigneekey, '')), 0),      
         ISNULL(cl5.long,'') AS STC2_Phone,
         MBOL.shipdate
             + CASE
                 WHEN Isnull(cl5.UDF04, '') = 'T' THEN Isnull(Cast(CL5.UDF02 AS INT), 0) --s01
                 WHEN Isnull(cl5.UDF04, '') = 'A' THEN Isnull(Cast(CL5.UDF03 AS INT), 0) --s01
                 ELSE 0
               END                    AS deliverydate, 
         ShipDate =  MBOL.Shipdate,    
         ISNULL(CL3.Short,'') AS Domain,
         Isnull(cl5.UDF04, '') AS TransMethod,
        'POD-18' + ISNULL(RIGHT(CL3.Short,3),'') + MBOL.Mbolkey AS Barcode,
         Cntconsignee = ISNULL(( 
                                SELECT COUNT( DISTINCT ST2.storerkey)
                                FROM  ORDERS O WITH (NOLOCK) 
                                LEFT JOIN STORER ST2 WITH (NOLOCK) ON ( ST2.StorerKey = O.consigneekey AND ST2.type='2')  
                                WHERE O.Mbolkey  = MBOL.Mbolkey  
                                AND   ISNULL(O.Consigneekey, '') = ISNULL(ORDERS.Consigneekey, '')), 0)  
   FROM ORD RDETAIL WITH (NOLOCK)   
   JOIN ORDERS WITH (NOLOCK) ON ( ORDERDETAIL.OrderKey = ORDERS.OrderKey )   
   JOIN STORER WITH (NOLOCK) ON ( STORER.StorerKey = ORDERS.StorerKey )   
   JOIN MBOL WITH (NOLOCK)   ON ( ORDERDETAIL.Mbolkey = MBOL.Mbolkey )
   JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku)
-- LEFT OUTER JOIN STORER CARRIER WITH (NOLOCK) ON ( MBOL.Carrierkey = CARRIER.Storerkey )
   --LEFT OUTER JOIN CodeLKUP WITH (NOLOCK) ON ( CodeLKUP.ListName = 'SKUFLAG' AND CodeLKUP.Code = RTRIM(SKU.SUSR1)) 
   --LEFT OUTER JOIN Codelkup CL2 WITH (NOLOCK)  
   --     ON (CL2.Listname = 'CityLdTime' AND substring(CL2.code,1,4) = 'PUMA' AND CHARINDEX(LTRIM(RTRIM(CL2.description)), ORDERS.c_city) > 0)
   LEFT OUTER JOIN CODELKUP CL3 WITH (NOLOCK)  ON (CL3.Listname = 'STRDOMAIN' AND
                           CL3.Code = ORDERS.StorerKey) 
  LEFT JOIN STORER STC1 WITH (NOLOCK) ON ( STC1.StorerKey = ORDERS.storerkey AND STC1.type='1')   
  LEFT JOIN STORER STC2 WITH (NOLOCK) ON ( STC2.StorerKey = ORDERS.consigneekey AND STC2.type='2')  
  LEFT OUTER JOIN CODELKUP CL5 WITH (NOLOCK)  ON (CL5.Listname = 'LAGAEPA' AND
                           CL5.Storerkey = ORDERS.StorerKey AND CL5.Code = SUBSTRING(ORDERS.consigneekey,CHARINDEX('-',ORDERS.consigneekey)+1,10) )
  JOIN dbo.FACILITY F WITH (NOLOCK) ON f.Facility=ORDERS.facility
   WHERE ( MBOL.Mbolkey = @c_Mbolkey ) 
   GROUP BY  MBOL.Mbolkey,
         ORDERS.Storerkey,  
         ORDERS.Consigneekey,     
         ISNULL(F.Address1,''),     
         ISNULL(F.contact1,''),   
         ISNULL(F.Phone1,''),  
         ORDERS.C_State, 
         CL3.Short,
         MBOL.Shipdate,
         ISNULL(STC1.Company,''),ISNULL(STC2.Company,'') ,
         ISNULL(CL5.Notes,''),ISNULL(CL5.short,''),ISNULL(cl5.long,''),Isnull(cl5.UDF04, ''),CL5.UDF02,CL5.UDF03 
  

 
   
   SELECT mbolkey,Storerkey,Consigneekey,st1company,    
       st1address1,st1contact1,st1phone1,  
       Qty,st2company,ST2_add,STC2_Contact,    
       CartonCnt,STC2_Phone,DELdate AS deliverydate,Domain,shipdate,transmethod,PODBarcode,Cntconsignee
   FROM #TEMPMNFTBLD08 
   ORDER BY mbolkey, Consigneekey 
               
END

QUIT:


GO