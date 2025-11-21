SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Function:   isp_invoice_03                                           */
/* Creation Date: 04-Jul-2017                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:                                                             */
/*        : WMS-2187 - New CSE Invoice (A&F DTC Order) (HK&CN)          */
/*                                                                      */
/* Called By:  r_dw_invoice_03                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 2018-Apr-16  CSCHONG   1.0   Revised field mapping (CS01)            */
/* 2019-Sep-18  WLChooi   1.1   WMS-10586 - Add new column, revised     */
/*                              TotalQty - Only for CN (WL01)           */
/************************************************************************/

CREATE PROC [dbo].[isp_invoice_03]  (
      @c_Orderkey NVARCHAR(10)
     ,@c_type     NVARCHAR(5) = 'H1'
     ,@n_RecGroup INT         = 0
)
AS                                  
BEGIN  
   SET NOCOUNT ON
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_InvAmt             FLOAT
         , @n_ShippingHandling   FLOAT
         , @n_NoOfLine           INT
         , @c_Country            NVARCHAR(10)  --WL01

   SET @n_NoOfLine = 10

   --WL01 Start
   SELECT @c_Country = LTRIM(RTRIM(NSQLValue))
   FROM NSQLCONFIG (NOLOCK)
   WHERE ConfigKey = 'Country'
   --WL01 End

   IF @c_type = 'H1' GOTO TYPE_H1

   CREATE TABLE #TMP_INVDET 
            (  SeqNo                INT IDENTITY (1,1)
            ,  Orderkey             NVARCHAR(10)
            ,  Sku                  NVARCHAR(20)
            ,  Descr                NVARCHAR(250)
            ,  Color                NVARCHAR(120)
            ,  Size                 NVARCHAR(300)
            ,  UnitPrice            NVARCHAR(15)
            ,  QtyShipped           FLOAT
            ,  C1                   NVARCHAR(4000)
            ,  C3                   NVARCHAR(4000)
            ,  C5                   NVARCHAR(4000)
            ,  C7                   NVARCHAR(4000)
            ,  C9                   NVARCHAR(4000)
            ,  F13                  NVARCHAR(4000)
            ,  RecGroup             INT
            ,  OHIncoTerm           NVARCHAR(20)
            ,  C11                  NVARCHAR(4000)  --WL01
            ,  Qty                  INT             --WL01
            )

      INSERT INTO  #TMP_INVDET 
            (  Orderkey              
            ,  Sku                   
            ,  Descr             
            ,  Color                 
            ,  Size                  
            ,  UnitPrice             
            ,  QtyShipped           
            ,  C1                   
            ,  C3                    
            ,  C5                   
            ,  C7                   
            ,  C9                                       
            ,  F13  
            ,  RecGroup 
            ,  OHIncoTerm    
            ,  C11         --WL01    
            ,  Qty         --WL01    
            )
      SELECT OD.Orderkey
            ,OD.Sku
			   ,Descr 	  = ISNULL(SUBSTRING(ODR.Note1,301,250),'')
			   ,Color	  = ISNULL(SUBSTRING(ODR.Note1,551,120),'')
			   ,Size	     = ISNULL(SUBSTRING(ODR.Note1,671,300),'')

			   ,UnitPrice = CASE WHEN OH.Userdefine03 = 'TRUE'
									   THEN '--' 
									   ELSE ISNULL(OH.CountryOfOrigin,'') + CONVERT(NVARCHAR(10),CONVERT(DECIMAL(8,2),OD.UnitPrice))
									   END
            ,OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty
			   ,LBL.C1
			   ,LBL.C3
			   ,LBL.C5
			   ,LBL.C7
			   ,LBL.C9                  
			   ,LBL.F13 
            ,RecGroup   =(Row_Number() OVER (PARTITION BY OH.Orderkey ORDER BY OH.Orderkey,  OD.OrderLineNumber Asc)-1)/@n_NoOfLine
            ,'(' + OH.incoterm + ')'
            ,CASE WHEN @c_Country = 'CN' THEN LBL.C11 ELSE '' END          --WL01
            ,CASE WHEN @c_Country = 'CN' THEN SUM(PD.Qty) ELSE 0 END       --WL01
	   FROM ORDERDETAIL OD  WITH (NOLOCK)
	   JOIN ORDERS      OH  WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey)
	   JOIN ORDERDETAILREF ODR WITH (NOLOCK) ON (OD.Orderkey= ODR.Orderkey)
											           AND(OD.OrderLineNumber = ODR.OrderLineNumber)
	   JOIN fnc_GetInv03Label ( @c_Orderkey ) LBL ON (OD.Orderkey = LBL.Orderkey)
      JOIN PICKDETAIL PD (NOLOCK) ON (PD.ORDERKEY = OD.ORDERKEY AND PD.SKU = OD.SKU AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER) --WL01
	   WHERE OD.Orderkey = @c_Orderkey 
	    AND (QtyAllocated + OD.ShippedQty + OD.QtyPicked) > 0    --CS01
      AND OD.UserDefine01 <> 'Backordered'
      GROUP BY OD.Orderkey
              ,OD.Sku
              ,ISNULL(SUBSTRING(ODR.Note1,301,250),'')
              ,ISNULL(SUBSTRING(ODR.Note1,551,120),'')
              ,ISNULL(SUBSTRING(ODR.Note1,671,300),'')
              ,CASE WHEN OH.Userdefine03 = 'TRUE'
              					   THEN '--' 
              					   ELSE ISNULL(OH.CountryOfOrigin,'') + CONVERT(NVARCHAR(10),CONVERT(DECIMAL(8,2),OD.UnitPrice))
              					   END
              ,OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty
              ,LBL.C1
              ,LBL.C3
              ,LBL.C5
              ,LBL.C7
              ,LBL.C9                  
              ,LBL.F13 
              ,OH.Orderkey,  OD.OrderLineNumber
              ,'(' + OH.incoterm + ')'
              ,CASE WHEN @c_Country = 'CN' THEN LBL.C11 ELSE '' END          --WL01
	   ORDER BY OD.OrderLineNumber


   IF @c_type = 'D_NML' GOTO TYPE_D_NML
   IF @c_type = 'D_RET' GOTO TYPE_D_RET

   TYPE_H1:
      CREATE TABLE #TMP_INVHDR 
            (  Orderkey             NVARCHAR(10)
            ,  B_Contact1           NVARCHAR(30)
            ,  B_Contact2           NVARCHAR(30)
            ,  B_Address1           NVARCHAR(45)
            ,  B_Address2           NVARCHAR(45)
            ,  B_Address3           NVARCHAR(45)
            ,  B_Address4           NVARCHAR(45)
            ,  B_City               NVARCHAR(45)
            ,  B_Zip                NVARCHAR(18)
            ,  B_State              NVARCHAR(45)
            ,  B_Country            NVARCHAR(30)
            ,  C_Contact1           NVARCHAR(30)
            ,  C_Contact2           NVARCHAR(30)
            ,  C_Address1           NVARCHAR(45)
            ,  C_Address2           NVARCHAR(45)
            ,  C_Address3           NVARCHAR(45)
            ,  C_Address4           NVARCHAR(45)
            ,  C_City               NVARCHAR(45)
            ,  C_Zip                NVARCHAR(18)
            ,  C_State              NVARCHAR(45)
            ,  C_Country            NVARCHAR(30)
            ,  M_Company            NVARCHAR(45)
            ,  UserDefine07         DATETIME
            ,  TotalUnitPrice       FLOAT
            ,  TotalShipHandling    FLOAT
            ,  SalesTax             FLOAT
            ,  VATRate              FLOAT
            ,  VATAmt               FLOAT                                                                                        
            ,  TotalDiscount        FLOAT   
            ,  TTLSKU               INT    
            ,  B1                   NVARCHAR(4000)  
            ,  B8                   NVARCHAR(4000)  
            ,  B15_1                NVARCHAR(4000)  
            ,  B15_2                NVARCHAR(4000)  
            ,  B17                  NVARCHAR(4000)  
            ,  D1                   NVARCHAR(4000)  
            ,  D4                   NVARCHAR(4000)  
            ,  D7                   NVARCHAR(4000)  
            ,  D10                  NVARCHAR(4000)  
            ,  D17                  NVARCHAR(4000)  
            ,  D23                  NVARCHAR(4000) 
            ,  D24                  NVARCHAR(4000)  
            ,  E1                   NVARCHAR(4000)  
            ,  E2                   NVARCHAR(4000)  
            ,  E3                   NVARCHAR(4000)    
            ,  E4                   NVARCHAR(4000)  
            ,  E5                   NVARCHAR(4000)  
            ,  E6                   NVARCHAR(4000)   
            ,  E9                   NVARCHAR(4000)  
            ,  E10                  NVARCHAR(4000) 
            ,  E11_1                NVARCHAR(4000) 
            ,  E11_2                NVARCHAR(4000) 
            ,  D20                  NVARCHAR(4000)                
            ,  TotalCOD             FLOAT                
            ,  E12                  NVARCHAR(4000)        
            ,  E13                  NVARCHAR(4000)        
            ,  E14                  NVARCHAR(4000)        
            ,  F11                  NVARCHAR(4000)        
            ,  F12                  NVARCHAR(4000)        
            ,  A2                   NVARCHAR(4000)        
            ,  A3_1                 NVARCHAR(4000)   
            ,  A3_2                 NVARCHAR(4000)   
            ,  COUNTRYORI           NVARCHAR(30)    
            ,  COUNTRYDEST          NVARCHAR(30) 
            ,  E17                  NVARCHAR(4000)        
            ,  E18                  NVARCHAR(4000) 
            )   
              

      CREATE TABLE #TMP_RECGRP
            (  RecGroup             INT
            ,  Orderkey             NVARCHAR(10)
            )

      INSERT INTO #TMP_RECGRP
            (  RecGroup             
            ,  Orderkey
            )                        
	   SELECT DISTINCT RecGroup   =(Row_Number() OVER (PARTITION BY OH.Orderkey ORDER BY OH.Orderkey,  (OD.OrderLineNumber) Asc)-1)/ @n_NoOfLine
         , OH.Orderkey
	   FROM ORDERS OH WITH (NOLOCK)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
	   WHERE OH.Orderkey = @c_Orderkey
      AND (QtyAllocated + OD.ShippedQty + OD.QtyPicked) > 0
      AND OD.UserDefine01 <> 'Backordered'

                                                                
      INSERT INTO #TMP_INVHDR
            (  Orderkey             
            ,  B_Contact1           
            ,  B_Contact2           
            ,  B_Address1           
            ,  B_Address2           
            ,  B_Address3           
            ,  B_Address4  
            ,  B_City               
            ,  B_Zip                
            ,  B_State              
            ,  B_Country                  
            ,  C_Contact1           
            ,  C_Contact2           
            ,  C_Address1           
            ,  C_Address2           
            ,  C_Address3           
            ,  C_Address4 
            ,  C_City          
            ,  C_Zip             
            ,  C_State              
            ,  C_Country            
            ,  M_Company         
            ,  UserDefine07         
            ,  TotalUnitPrice       
            ,  TotalShipHandling    
            ,  SalesTax              
            ,  VATRate              
            ,  VATAmt                                                                                       
            ,  TotalDiscount        
            ,  TTLSKU                             
            ,  B1                   
            ,  B8                   
            ,  B15_1
            ,  B15_2                  
            ,  B17                                  
            ,  D1                   
            ,  D4                   
            ,  D7                   
            ,  D10                                   
            ,  D17                  
            ,  D23                
            ,  D24                 
            ,  E1                 
            ,  E2                 
            ,  E3                                
            ,  E4                 
            ,  E5                   
            ,  E6                                   
            ,  E9                   
            ,  E10
            ,  E11_1 
            ,  E11_2
            ,  D20                           
            ,  TotalCOD           
            ,  E12          
            ,  E13 
            ,  E14 
            ,  F11                 
            ,  F12               
            ,  A2              
            ,  A3_1             
            ,  A3_2                   
            , COUNTRYORI
            , COUNTRYDEST  
            , E17 
            , E18                 
                 
            ) 
                                                                                      
	   SELECT DISTINCT 
          OH.Orderkey
         ,B_Contact1     = ISNULL(RTRIM(OH.B_Contact1),'')
			   ,B_Contact2     = ISNULL(RTRIM(OH.B_Contact2),'')
			   ,B_Address1     = ISNULL(RTRIM(OH.B_Address1),'')
			   ,B_Address2     = ISNULL(RTRIM(OH.B_Address2),'')
			   ,B_Address3     = ISNULL(RTRIM(OH.B_Address3),'')
			   ,B_Address4     = ISNULL(RTRIM(OH.B_Address4),'')  
			   ,B_City         = ISNULL(RTRIM(OH.B_City),'')
			   ,B_Zip          = ISNULL(RTRIM(OH.B_Zip),'')
			   ,B_State        = ISNULL(RTRIM(OH.B_State),'')
			   ,B_Country      = ISNULL(RTRIM(OH.B_Country),'')  
			   ,C_Contact1     = ISNULL(RTRIM(OH.C_Contact1),'')
			   ,C_Contact2     = ISNULL(RTRIM(OH.C_Contact2),'')
			   ,C_Address1     = ISNULL(RTRIM(OH.C_Address1),'')
			   ,C_Address2     = ISNULL(RTRIM(OH.C_Address2),'')
			   ,C_Address3     = ISNULL(RTRIM(OH.C_Address3),'')
			   ,C_Address4     = ISNULL(RTRIM(OH.C_Address4),'')  
			   ,C_City         = ISNULL(RTRIM(OH.C_City),'')
			   ,C_Zip          = ISNULL(RTRIM(OH.C_Zip),'')
			   ,C_State        = ISNULL(RTRIM(OH.C_State),'')
			   ,C_Country      = ISNULL(RTRIM(OH.C_Country),'')  
			   ,M_Company      = ISNULL(RTRIM(OH.M_Company),'') 
         ,UserDefine07   = ISNULL(RTRIM(OH.UserDefine07),'1900-01-01') 
         ,TotalUnitPrice = ISNULL(SUM(CASE WHEN Qty > 0 THEN PD.Qty * OD.UnitPrice ELSE 0.00 END),0.00) 
         ,TotalShipHandling=ISNULL( SUM(CASE WHEN Qty > 0  
                                                THEN CASE WHEN ISNUMERIC( OD.UserDefine05 ) = 1 
                                                          THEN CONVERT(FLOAT,OD.UserDefine05)
                                                          ELSE 0.00
                                                          END + OD.ExtendedPrice
                                                ELSE 0.00 END),0.00 )
            ,SalesTax       = ISNULL( SUM(OD.Tax01), 0.00 )
            ,VATRate        = CASE WHEN ISNUMERIC(OI.OrderInfo05) = 1 THEN CONVERT(FLOAT,OI.OrderInfo05) ELSE 0.00 END
            ,VATAmt         = ISNULL( SUM(OD.Tax02 +  CASE WHEN ISNUMERIC( OD.UserDefine05 ) = 1 
                                                           THEN CONVERT(FLOAT,OD.UserDefine05)
                                                           ELSE 0.00
                                                           END),0.00 )
			   ,TotalDiscount  = ISNULL( SUM(CASE WHEN ISNUMERIC(OD.UserDefine08) = 1 
                                               THEN CONVERT(FLOAT,OD.UserDefine08) ELSE 0.00
                                               END),0.00 )
            ,TTLSKU     = CASE WHEN @c_Country = 'CN' THEN SUM(PD.Qty) ELSE SUM(od.QtyPicked+od.ShippedQty) END --COUNT (DISTINCT OD.sku)             --WL01
            ,LBL.B1            	
            ,LBL.B8            	
            ,LBL.B15_1           	
            ,LBL.B15_2          	
            ,LBL.B17           	           	
            ,LBL.D1            	
            ,LBL.D4            	
            ,LBL.D7            	
            ,LBL.D10           	          
           ,''	
            ,LBL.D23         	
            ,LBL.D24          	
            ,LBL.E1          	
            ,LBL.E2          	
            ,LBL.E3          	            	
            ,LBL.E4          	          	
            ,LBL.E5            	
            ,LBL.E6            	         	
            ,LBL.E9            	
            ,LBL.E10
            ,LBL.E11_1 
            ,LBL.E11_2  
            ,LBL.D20                                                    
            ,TotalCOD    = ISNULL( SUM(CASE WHEN (ISNUMERIC(OD.UserDefine06) = 1 AND Qty > 0)
                           THEN (CONVERT(FLOAT,OD.UserDefine06)) ELSE 0.00
             END),0.00 )  
            ,LBL.E12                                                 
            ,LBL.E13                                                 
            ,LBL.E14                                                  
            ,LBL.F11                                                  
            ,LBL.F12                                               
            ,LBL.A2                                              
            ,LBL.A3_1                                                                                                                                                                                                                    	
            ,LBL.A3_2            	
            ,COUNTRYORI = ISNULL(OH.CountryOfOrigin,'')
            ,COUNTRYDEST = ISNULL(OH.CountryDestination,'')  
            ,LBL.E17                                                 
            ,LBL.E18  
	   FROM ORDERS OH WITH (NOLOCK)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
      JOIN PICKDETAIL  PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)
                                        AND(OD.OrderLineNumber = PD.OrderLineNumber)
      JOIN dbo.fnc_GetInv03Label (@c_orderkey) lbl ON (lbl.Orderkey = OH.Orderkey)
      LEFT JOIN CODELKUP    CL WITH (NOLOCK) ON (CL.ListName = 'ANFBrand' AND CL.Code = OH.Sectionkey)
      LEFT JOIN ORDERINFO OI WITH (NOLOCK) ON (OH.Orderkey = OI.Orderkey)
	   WHERE OH.Orderkey = @c_orderkey
      AND (QtyAllocated+OD.ShippedQty + OD.QtyPicked) > 0      --CS01
      AND OD.UserDefine01 <> 'Backordered'
      GROUP BY OH.Orderkey
           ,  ISNULL(RTRIM(OH.B_Contact1),'')
	        ,  ISNULL(RTRIM(OH.B_Contact2),'')
	        ,  ISNULL(RTRIM(OH.B_Address1),'')
	        ,  ISNULL(RTRIM(OH.B_Address2),'')
	        ,  ISNULL(RTRIM(OH.B_Address3),'')
	        ,  ISNULL(RTRIM(OH.B_Address4),'') 
			  ,  ISNULL(RTRIM(OH.B_City),'')
			  ,  ISNULL(RTRIM(OH.B_Zip),'')
			  ,  ISNULL(RTRIM(OH.B_State),'')
			  ,  ISNULL(RTRIM(OH.B_Country),'')  
	        ,  ISNULL(RTRIM(OH.C_Contact1),'')
	        ,  ISNULL(RTRIM(OH.C_Contact2),'')
	        ,  ISNULL(RTRIM(OH.C_Address1),'')
	        ,  ISNULL(RTRIM(OH.C_Address2),'')
	        ,  ISNULL(RTRIM(OH.C_Address3),'')
	        ,  ISNULL(RTRIM(OH.C_Address4),'') 
			  ,  ISNULL(RTRIM(OH.C_City),'')
			  ,  ISNULL(RTRIM(OH.C_Zip),'')
			  ,  ISNULL(RTRIM(OH.C_State),'')
			  ,  ISNULL(RTRIM(OH.C_Country),'')  
	        ,  ISNULL(RTRIM(OH.M_Company),'') 
           ,  ISNULL(RTRIM(OH.UserDefine07),'1900-01-01') 
           ,  CASE WHEN ISNUMERIC(OI.OrderInfo05) = 1 THEN CONVERT(FLOAT,OI.OrderInfo05) ELSE 0.00 END           
           ,  LBL.B1            	
           ,  LBL.B8            	
           ,  LBL.B15_1           	
           ,  LBL.B15_2           	
           ,  LBL.B17           	           	
           ,  LBL.D1            	
           ,  LBL.D4            	
           ,  LBL.D7            	
           ,  LBL.D10           	          	
           ,  LBL.D17           	
           ,  LBL.D23          	
           ,  LBL.D24          	
           ,  LBL.E1          	
           ,  LBL.E2          	
           ,  LBL.E3          	        	
           ,  LBL.E4          	
           ,  LBL.E5     	
           ,  LBL.E6            	         	
           ,  LBL.E9            	
           ,  LBL.E10
           ,  LBL.E11_1 
           ,  LBL.E11_2 
           ,  LBL.D20             
           ,  LBL.E12              
           ,  LBL.E13             
           ,  LBL.E14             
           ,  LBL.F11             
           ,  LBL.F12          
           ,  LBL.A2                                               
           ,  LBL.A3_1                                                                                                                                                                                                                    	
           ,  LBL.A3_2         	
           ,  ISNULL(OH.CountryOfOrigin,'')
           ,  ISNULL(OH.CountryDestination,'')  
           ,  LBL.E17                                                 
           ,  LBL.E18            	
  
      
      IF EXISTS ( SELECT 1
                  FROM ORDERDETAIL WITH (NOLOCK)
                  WHERE Orderkey = @c_Orderkey
                  AND OriginalQty > QtyAllocated + QtyAllocated + ShippedQty
                 )
      BEGIN
         SET @n_InvAmt = 0.00
         SET @n_ShippingHandling = 0.00
         SELECT @n_InvAmt           = TotalUnitPrice + TotalShipHandling + SalesTax
               ,@n_ShippingHandling = TotalShipHandling
         FROM #TMP_INVHDR

         UPDATE ORDERS WITH (ROWLOCK)
         SET InvoiceAmount = @n_InvAmt
            ,Capacity      = @n_ShippingHandling
            ,Trafficcop = NULL
            ,EditDate   = GETDATE()
            ,EditWho    = SUSER_NAME()
         WHERE Orderkey = @c_Orderkey
      END

      SELECT   T_GRP.RecGroup
            ,  T_INV.Orderkey             
            ,  T_INV.B_Contact1           
            ,  T_INV.B_Contact2           
            ,  T_INV.B_Address1           
            ,  T_INV.B_Address2           
            ,  T_INV.B_Address3           
            ,  T_INV.B_Address4  
            ,  T_INV.B_City
            ,  T_INV.B_Zip       
            ,  T_INV.B_State           
            ,  T_INV.B_Country         
            ,  T_INV.C_Contact1           
            ,  T_INV.C_Contact2           
            ,  T_INV.C_Address1           
            ,  T_INV.C_Address2           
            ,  T_INV.C_Address3           
            ,  T_INV.C_Address4 
            ,  T_INV.C_City
            ,  T_INV.C_Zip       
            ,  T_INV.C_State           
            ,  T_INV.C_Country           
            ,  T_INV.M_Company      
            ,  UserDefine07 = CONVERT(NVARCHAR(10), T_INV.UserDefine07, 111)       
            ,  T_INV.TotalUnitPrice       
            ,  T_INV.TotalShipHandling   
            ,  SalesTax = CASE WHEN T_INV.SalesTax > 0.00
                  THEN CONVERT(NVARCHAR(10), CONVERT(DECIMAL(8,2),T_INV.SalesTax))   
                               ELSE '' END   
            ,  T_INV.TotalUnitPrice +  T_INV.TotalShipHandling + T_INV.SalesTax + T_INV.TotalCOD   AS totalorder--(CS01)      
            ,  VATRate  = CASE WHEN T_INV.VATRate > 0.00 AND T_INV.VATAmt > 0.00 
                         THEN CONVERT(NVARCHAR(10), CONVERT(DECIMAL(8,0),T_INV.VATRate)) + '%'  
                               ELSE '' END            
            ,  VATAmt   = CASE WHEN T_INV.VATRate > 0.00 AND T_INV.VATAmt > 0.00 
                               THEN CONVERT(NVARCHAR(10), CONVERT(DECIMAL(8,2),T_INV.VATAmt))   
                               ELSE '' END                                                                                      
            ,  TotalDiscount = CASE WHEN T_INV.TotalDiscount > 0.00 
                               THEN CONVERT(NVARCHAR(10), CONVERT(DECIMAL(8,2),T_INV.TotalDiscount))   
                               ELSE '' END  
            ,  T_INV.TTLSKU                           
            ,  B1 = T_INV.B1  + ': '                   
            ,  B8 = T_INV.B8  + ': '                   
            ,  B15_1 = T_INV.B15_1 + ': '                   
            ,  B15_2 = T_INV.B15_2 + ': '                   
            ,  B17 = T_INV.B17 + ': '                                       
            ,  T_INV.D1                   
            ,  D4 = CASE WHEN T_INV.TotalShipHandling >= 1 THEN T_INV.D4 ELSE '' END                    
            ,  D7  = T_INV.D7                   
            ,  T_INV.D10                               
            ,  D17 = CASE WHEN T_INV.TotalDiscount > 0.00 THEN T_INV.D17 ELSE '' END                 
            ,  T_INV.D23                   
            ,  T_INV.D24                   
            ,  T_INV.E1                
            ,  T_INV.E2              
            ,  T_INV.E3                                     
            ,  T_INV.E4                    
            ,  T_INV.E5                       
            ,  T_INV.E6                                    
            ,  E9 = T_INV.E9  --+ ': '                       
            ,  E10 = T_INV.E10 --+ ': ' 
            ,  T_INV.E11_1                    
            ,  T_INV.E11_2  
            ,  D20 = CASE WHEN T_INV.TotalCOD > 0.00 THEN T_INV.D20  ELSE '' END                             --(CS01)      
            ,  TotalCOD = CASE WHEN T_INV.TotalCOD > 0.00                                       
                               THEN CONVERT(NVARCHAR(10), CONVERT(DECIMAL(8,2),T_INV.TotalCOD))   
                               ELSE '0.00' END    
            ,E12                                                                                  
            ,E13                                                                                
            ,E14                                                                                 
            ,F11                                                                                 
            ,F12                                                                                  
            ,A2                                               
            ,A3_1                                                    	
            ,A3_2 
            ,T_INV.COUNTRYORI
            ,T_INV.COUNTRYDEST   
            ,E17
            ,E18                                                                                                                                                               
      FROM #TMP_INVHDR T_INV
      JOIN #TMP_RECGRP T_GRP ON (T_INV.Orderkey = T_GRP.Orderkey)

      DROP TABLE #TMP_INVHDR

      DROP TABLE #TMP_RECGRP

      GOTO QUIT
   TYPE_D_NML:

      SELECT Sku
			   ,CASE WHEN LEN(Descr)>40 THEN SUBSTRING(Descr,1,40) + '...' ELSE RTRIM(Descr) END AS Descr 	 
			   ,CASE WHEN LEN(Color)>20 THEN SUBSTRING(Color,1,20) + '...' ELSE RTRIM(Color) END AS Color	 
			   ,Size	     
			   ,UnitPrice
			   ,C1
			   ,C3
			   ,C5
			   ,C7
			   ,C9
			   ,F13
			   ,OHIncoTerm
            ,C11   --WL01
            ,Qty   --WL01
	   FROM #TMP_INVDET
      WHERE RecGroup = @n_RecGroup
      ORDER BY SeqNo

      DROP TABLE #TMP_INVDET
      GOTO QUIT

   TYPE_D_RET:

	   SELECT Sku
			   ,CASE WHEN LEN(Descr)>40 THEN SUBSTRING(Descr,1,40) + '...' ELSE RTRIM(Descr) END AS Descr    
			   ,CASE WHEN LEN(Color)>20 THEN SUBSTRING(Color,1,20) + '...' ELSE RTRIM(Color) END AS Color	 	   
			   ,Size	      
			   ,UnitPrice  
			   ,C1
			   ,C3
			   ,C5
			   ,C7
			   ,C9
			   ,F13
			   ,OHIncoTerm
            ,C11   --WL01
            ,Qty   --WL01
	   FROM #TMP_INVDET
      WHERE RecGroup = @n_RecGroup
      --AND QtyShipped > 0
      ORDER BY SeqNo

      DROP TABLE #TMP_INVDET
      GOTO QUIT
   QUIT:
END

GO