SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 
/******************************************************************************/              
/* Store Procedure: isp_Mbol_Manifestdetails_05                               */              
/* Creation Date: 23-MAR-2017                                                 */              
/* Copyright: IDS                                                             */              
/* Written by: CSCHONG                                                        */              
/*                                                                            */              
/* Purpose: WMS-1384 - CN_Columbia_POD_Modify_Request                         */  
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_manifest_detail_05.srd                                    */              
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
  
CREATE PROC [dbo].[isp_Mbol_Manifestdetails_05]             
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
         
  
  
   CREATE TABLE #TEMPMANIFESTTBL05
  ( mbolkey         NVARCHAR(10) NULL,
    Storerkey       NVARCHAR(15) NULL,
    Consigneekey    NVARCHAR(15) NULL,
    c_company       NVARCHAR(45) NULL,
    c_address1      NVARCHAR(45) NULL,
    c_address2      NVARCHAR(45) NULL,
    c_address3      NVARCHAR(45) NULL,
    c_address4      NVARCHAR(45) NULL,
    c_contact1      NVARCHAR(30) NULL,
    c_phone1        NVARCHAR(18) NULL,
    c_StateCity     NVARCHAR(95) NULL,
    c_zip           NVARCHAR(18) NULL,
    qty             INT,
    SCompany        NVARCHAR(45) NULL,
    Address1        NVARCHAR(30) NULL,
    Address2        NVARCHAR(30) NULL,
    Address3        NVARCHAR(30) NULL,
    Address4        NVARCHAR(30) NULL,
    CONtact1        NVARCHAR(30) NULL,
    PhONe1          NVARCHAR(30) NULL,
    Notes           NVARCHAR(4000) NULL,
    CartonCnt       INT,
    Item_Type       NVARCHAR(5) NULL,
    Short           NVARCHAR(80) NULL,
    ProdUnit        NVARCHAR(150) NULL,
    Carrier_Company NVARCHAR(45) NULL,
    Principle       NVARCHAR(250) NULL,
    TransMethod_0   NVARCHAR(5) NULL, 
    TransMethod_1   NVARCHAR(5) NULL, 
    TransMethod_2   NVARCHAR(5) NULL, 
    TransMethod_3   NVARCHAR(5) NULL, 
    editdate        DATETIME ,
    arrivaldate     DATETIME,
    Remarks         NVARCHAR(250) NULL,
    CompanyName     NVARCHAR(45) NULL
    
  )
  
  
   SET @c_delimiter =','
   SET @c_short = ''
   SET @c_Preshort = ''
   SET @c_getnotes = ','
  
   INSERT INTO #TEMPMANIFESTTBL05
  (
  	 mbolkey,Storerkey,Consigneekey,c_company,    
    c_address1,c_address2,c_address3,c_address4,    
    c_contact1,c_phone1,c_StateCity,c_zip,qty,    
    SCompany,Address1,Address2,Address3,Address4,    
    CONtact1,PhONe1,Notes,CartonCnt,Item_Type,    
    Short,ProdUnit,Carrier_Company,Principle,    
    TransMethod_0,TransMethod_1,TransMethod_2,    
    TransMethod_3,editdate,arrivaldate,Remarks,    
    CompanyName )
  SELECT MBOL.Mbolkey,
         ORDERS.Storerkey,  
         ORDERS.Consigneekey,   
         ORDERS.C_Company,   
         ORDERS.C_Address1,   
         ORDERS.C_Address2,   
         ORDERS.C_Address3,   
         ORDERS.C_Address4,   
         ORDERS.C_contact1,   
         ORDERS.C_Phone1,   
			RTRIM(ISNULL(ORDERS.C_State,''))+'('+RTRIM(ISNULL(ORDERS.C_City,'')) + ')' AS state_city,  
			ORDERS.C_Zip,
         QTY = SUM (ORDERDETAIL.ShippedQty + ORDERDETAIL.QtyPicked ),
			STORER.company,

         FACILITY.Userdefine11 AS Address1,     
         FACILITY.Userdefine12 AS Address2,
         FACILITY.Userdefine13 AS Address3, 
         FACILITY.Userdefine14 AS Address4,
         FACILITY.Userdefine06 AS CONtact1,
         FACILITY.Userdefine07 AS PhONe1,
			CONVERT(NVARCHAR(4000),STORER.Notes2) as Notes, 
         /*CartonCnt = ISNULL(( 
				SELECT COUNT( DISTINCT PD.PickSlipNo +''+ CONVERT(char(10),PD.CartonNo) )
            FROM  PACKDETAIL PD WITH (NOLOCK)  
       	   JOIN  PackHeader PH WITH (NOLOCK) ON ( PH.PickSlipNO  = PD.PickSlipNO )
            JOIN  ORDERS O WITH (NOLOCK) ON ( PH.OrderKey = O.OrderKey AND PH.LoadKey = O.LoadKey )
            WHERE O.Mbolkey  = MBOL.Mbolkey  
 				AND   ISNULL(O.Consigneekey, '') = ISNULL(ORDERS.Consigneekey, '')), 0),*/
          (SELECT SUM(MD.TotalCartons) FROM MBOLDETAIL MD (NOLOCK)
           JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey 
           WHERE MD.Mbolkey = MBOL.Mbolkey 
           AND ISNULL(O.Consigneekey,'') = ISNULL(ORDERS.Consigneekey,'')) AS CartonCnt,
			Item_Type = Left(LTRIM(ORDERDETAIL.SKU), 1),
			CodeLKUP.Short,
			ProdUnit = ISNULL(RTRIM(LTRIM(CodeLKUP.Long)), ''),
			ISNULL(CARRIER.Company, '') as Carrier_Company,
			Right(RTrim(CL2.Short),3) as Principle,
			CASE MBOL.TransMethod WHEN 'R' THEN '0' WHEN 'A' THEN '0' WHEN 'E' THEN '0' ELSE '1' END as TransMethod_0,
			CASE MBOL.TransMethod WHEN 'R' THEN '1' ELSE '0' END as TransMethod_1,
			CASE MBOL.TransMethod WHEN 'A' THEN '1' ELSE '0' END as TransMethod_2,
			CASE MBOL.TransMethod WHEN 'E' THEN '1' ELSE '0' END as TransMethod_3,
			CONVERT(VARCHAR(8),MBOL.EditDate, 112) AS editdate,
         CONVERT(VARCHAR(8),DATEADD(DAY, CONVERT(INT, ISNULL(CL3.SHORT,0)), MBOL.EditDate), 112) as arrivaldate,
			CONVERT(NVARCHAR(4000),MBOL.Remarks) as Remarks,
         FACILITY.Userdefine15 AS CompanyName
        -- CL4.short
   FROM ORDERDETAIL WITH (NOLOCK)   
	JOIN ORDERS WITH (NOLOCK) ON ( ORDERDETAIL.OrderKey = ORDERS.OrderKey )   
	JOIN STORER WITH (NOLOCK) ON ( STORER.StorerKey = ORDERS.StorerKey )   
	JOIN MBOL WITH (NOLOCK)   ON ( ORDERDETAIL.Mbolkey = MBOL.Mbolkey )
	JOIN SKU WITH (NOLOCK)    ON ( SKU.SKU = ORDERDETAIL.SKU AND SKU.Storerkey = ORDERDETAIL.Storerkey )
   JOIN FACILITY WITH (NOLOCK) ON ( FACILITY.Facility = ORDERS.Facility)   
	LEFT OUTER JOIN STORER CARRIER WITH (NOLOCK) 
               ON ( CARRIER.Storerkey = CASE ISNULL(MBOL.Carrierkey,'') WHEN '' THEN STORER.SUSR1 ELSE MBOL.Carrierkey END)
	LEFT OUTER JOIN CodeLKUP WITH (NOLOCK) ON ( CodeLKUP.ListName = 'SKUFLAG' AND CodeLKUP.Code = SKU.SkuGroup	) 
	LEFT OUTER JOIN Codelkup CL2 WITH (NOLOCK) ON (CL2.Listname = 'strdomain' AND CL2.Code = ORDERS.Storerkey)
   LEFT OUTER JOIN CODELKUP CL3 WITH (NOLOCK)
               ON (CL3.Listname = 'CityLdTime' AND CONVERT(VARCHAR,CL3.Notes) = ORDERS.Storerkey
               AND ISNULL(RTRIM(CL3.Description),'') = ISNULL(RTRIM(ORDERS.C_City),'')
               AND ISNULL(RTRIM(CL3.Long),'') = ISNULL(RTRIM(FACILITY.UserDefine03),''))
  --LEFT OUTER JOIN CODELKUP CL4 WITH (NOLOCK) ON CL4.listname = 'CMBSKUCODE' AND CL4.code=sku.busr2              
   WHERE ( MBOL.Mbolkey = @c_Mbolkey ) 
   GROUP BY  MBOL.Mbolkey,
         ORDERS.Storerkey,  
         ORDERS.Consigneekey,   
         ORDERS.C_Company,   
         ORDERS.C_Address1,   
         ORDERS.C_Address2,   
         ORDERS.C_Address3,   
         ORDERS.C_Address4,   
         ORDERS.C_contact1,   
         ORDERS.C_Phone1,  
			RTRIM(ISNULL(ORDERS.C_State,''))+'('+RTRIM(ISNULL(ORDERS.C_City,'')) + ')',
			ORDERS.C_Zip,
			STORER.company,
         FACILITY.Userdefine11,     
         FACILITY.Userdefine12,
         FACILITY.Userdefine13,
         FACILITY.Userdefine14,
         FACILITY.Userdefine06,
         FACILITY.Userdefine07,
			CONVERT(NVARCHAR(4000),STORER.Notes2), 
			Left(LTRIM(ORDERDETAIL.SKU), 1),
			CodeLKUP.Short,
			ISNULL(RTRIM(LTRIM(CodeLKUP.Long)), ''),
			ISNULL(CARRIER.Company, ''),
			Right(RTrim(CL2.Short),3),
			CASE MBOL.TransMethod WHEN 'R' THEN '0' WHEN 'A' THEN '0' WHEN 'E' THEN '0' ELSE '1' END,
			CASE MBOL.TransMethod WHEN 'R' THEN '1' ELSE '0' END,
			CASE MBOL.TransMethod WHEN 'A' THEN '1' ELSE '0' END,
			CASE MBOL.TransMethod WHEN 'E' THEN '1' ELSE '0' END,
			CONVERT(VARCHAR(8),MBOL.EditDate, 112), 
         CONVERT(VARCHAR(8),DATEADD(DAY, CONVERT(INT, ISNULL(CL3.SHORT,0)), MBOL.EditDate), 112),
			CONVERT(NVARCHAR(4000),MBOL.Remarks),
         FACILITY.Userdefine15 
        -- , CL4.short
  ORDER BY MBOL.Mbolkey DESC
  
  
  
  DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT mbolkey,Consigneekey   
   FROM   #TEMPMANIFESTTBL05    
   WHERE mbolkey   = @c_mbolkey
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_getmbolkey, @c_consigneekey   
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN 
  
   SELECT @c_getnotes = REPLACE(COALESCE(@c_getnotes + ', ', ' '),',,','') +  c.short
   FROM ORDERDETAIL WITH (NOLOCK)   
	JOIN ORDERS WITH (NOLOCK) ON ( ORDERDETAIL.OrderKey = ORDERS.OrderKey )   
	JOIN STORER WITH (NOLOCK) ON ( STORER.StorerKey = ORDERS.StorerKey )   
	JOIN MBOL WITH (NOLOCK)   ON ( ORDERDETAIL.Mbolkey = MBOL.Mbolkey )
	JOIN SKU WITH (NOLOCK)    ON ( SKU.SKU = ORDERDETAIL.SKU AND SKU.Storerkey = ORDERDETAIL.Storerkey )
	LEFT OUTER JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CMBSKUCODE' AND C.code=sku.busr2 
  WHERE MBOL.mbolkey = @c_Mbolkey
  GROUP BY c.short
  ORDER BY c.SHort desc
      
   IF @c_getnotes <> ',' 
   BEGIN
   	
   	UPDATE #TEMPMANIFESTTBL05
   	SET Short = @c_getnotes
   	WHERE mbolkey = @c_getmbolkey
   	AND Consigneekey = @c_consigneekey
   	
   	SET @c_getnotes = ','
   	
   END
   
   FETCH NEXT FROM CUR_RESULT INTO @c_getmbolkey, @c_consigneekey   
   END  
  
    CLOSE CUR_RESULT
    DEALLOCATE CUR_RESULT
  
  
   
    SELECT mbolkey,Storerkey,Consigneekey,c_company,    
    c_address1,c_address2,c_address3,c_address4,    
    c_contact1,c_phone1,c_StateCity,c_zip,sum(qty) AS qty,    
    SCompany,Address1,Address2,Address3,Address4,    
    CONtact1,PhONe1,Notes,CartonCnt,Item_Type,    
    Short,ProdUnit,Carrier_Company,Principle,    
    TransMethod_0,TransMethod_1,TransMethod_2,    
    TransMethod_3,editdate,arrivaldate,Remarks,    
    CompanyName
   FROM #TEMPMANIFESTTBL05  
    GROUP BY mbolkey,Storerkey,Consigneekey,c_company,    
    c_address1,c_address2,c_address3,c_address4,    
    c_contact1,c_phone1,c_StateCity,c_zip,    
    SCompany,Address1,Address2,Address3,Address4,    
    CONtact1,PhONe1,Notes,CartonCnt,Item_Type,    
    Short,ProdUnit,Carrier_Company,Principle,    
    TransMethod_0,TransMethod_1,TransMethod_2,    
    TransMethod_3,editdate,arrivaldate,Remarks,    
    CompanyName
   ORDER BY mbolkey,Consigneekey,Item_Type  
               
END



GO