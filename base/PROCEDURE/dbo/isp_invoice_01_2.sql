SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Function:  isp_invoice_01_2                                          */
/* Creation Date: 23-Jul-2014                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:                                                             */
/*        : SOS#315902 - ANF DTC Customer Invoice Report                */
/*                                                                      */
/* Called By:  r_dw_invoice_01_2                                        */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 2015-Aug-14  CSCHONG   1.0   SOS#349820 (CS01)                       */
/* 2016-AUG-24  CSCHONG   2.0   WMS-245 - Add QR code (CS02)            */
/* 2017-Feb-20  CSCHONG   2.1   WMS-1102-change field mapping (CS03)    */
/************************************************************************/

CREATE PROC [dbo].[isp_invoice_01_2]  (
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

   SET @n_NoOfLine = 10


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
			   ,  F1                   NVARCHAR(4000)
			   ,  F3                   NVARCHAR(4000)
			   ,  F5                   NVARCHAR(4000)
			   ,  F7                   NVARCHAR(4000)
			   ,  F9                   NVARCHAR(4000)
			   ,  F11                  NVARCHAR(4000)
            ,  RecGroup             INT
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
			   ,  F1                    
			   ,  F3                   
			   ,  F5                    
			   ,  F7                    
			   ,  F9                    
			   ,  F11  
            ,  RecGroup                
            )
      SELECT OD.Orderkey
            ,OD.Sku
			   ,Descr 	  = ISNULL(SUBSTRING(ODR.Note1,301,250),'')
			   ,Color	  = ISNULL(SUBSTRING(ODR.Note1,551,120),'')
			   ,Size	     = ISNULL(SUBSTRING(ODR.Note1,671,300),'')

			   ,UnitPrice = CASE WHEN OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty <= 0 
                              AND  OD.Userdefine01 <> 'GiftWrapService'
									   THEN 'Backordered' 
									   ELSE CONVERT(NVARCHAR(10),CONVERT(DECIMAL(8,2),OD.UnitPrice))
									   END
            ,OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty
			   ,LBL.C1
			   ,LBL.C3
			   ,LBL.C5
			   ,LBL.C7
			   ,LBL.C9
			   ,LBL.F1                    
			   ,LBL.F3                   
			   ,LBL.F5                    
			   ,LBL.F7                    
			   ,LBL.F9                    
			   ,LBL.F11 
            ,RecGroup   =(Row_Number() OVER (PARTITION BY OH.Orderkey ORDER BY OH.Orderkey,  OD.OrderLineNumber Asc)-1)/@n_NoOfLine
 
	   FROM ORDERDETAIL OD  WITH (NOLOCK)
	   JOIN ORDERS      OH  WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey)
	   JOIN ORDERDETAILREF ODR WITH (NOLOCK) ON (OD.Orderkey= ODR.Orderkey)
											           AND(OD.OrderLineNumber = ODR.OrderLineNumber)
	   JOIN fnc_GetInv01Label ( @c_Orderkey ) LBL ON (OD.Orderkey = LBL.Orderkey)
	   WHERE OD.Orderkey = @c_Orderkey 
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
			   ,  M_Fax1               NVARCHAR(18)
			   ,  M_Fax2               NVARCHAR(18)
			   ,  M_Phone1             NVARCHAR(18)
			   ,  M_Phone2             NVARCHAR(18)
            ,  UserDefine03         NVARCHAR(20)
            ,  UserDefine07         DATETIME
            ,  IntermodalVehicle    NVARCHAR(30)
            ,  Cur_UnitPrice        NVARCHAR(30)
            ,  Cur_ShipHandling     NVARCHAR(30)
            ,  Cur_SalesTax         NVARCHAR(30)
            ,  Cur_Order            NVARCHAR(30)
            ,  Cur_Vat              NVARCHAR(30)
            ,  Cur_Discount         NVARCHAR(30)
            ,  Notes                NVARCHAR(4000)
            ,  TotalUnitPrice       FLOAT
            ,  TotalShipHandling    FLOAT
            ,  SalesTax             FLOAT
            ,  VATRate              FLOAT
            ,  VATAmt               FLOAT                                                                                        
            ,  TotalDiscount        FLOAT   
            ,  OrderBrand           NVARCHAR(250)  
            ,  A2                   NVARCHAR(4000)   
            ,  B1                   NVARCHAR(4000)  
            ,  B8                   NVARCHAR(4000)  
            ,  B15                  NVARCHAR(4000)  
            ,  B17                  NVARCHAR(4000)  
            ,  B19                  NVARCHAR(4000)  
   --         ,  C1                   NVARCHAR(4000)  
   --         ,  C3                   NVARCHAR(4000)  
   --         ,  C5                   NVARCHAR(4000)  
   --         ,  C7                   NVARCHAR(4000)  
   --         ,  C9                   NVARCHAR(4000)  
            ,  C12                  NVARCHAR(4000)
            ,  D1                   NVARCHAR(4000)  
            ,  D4                   NVARCHAR(4000)  
            ,  D7                   NVARCHAR(4000)  
            ,  D10                  NVARCHAR(4000)  
            ,  D13                  NVARCHAR(4000)  
            ,  D17                  NVARCHAR(4000)  
            ,  E1_1                 NVARCHAR(4000) 
            ,  E1_2                 NVARCHAR(4000)  
            ,  E2_1                 NVARCHAR(4000)  
            ,  E2_2                 NVARCHAR(4000)  
            ,  E3_1                 NVARCHAR(4000)  
            ,  E3_2                 NVARCHAR(4000)  
            ,  E4_1                 NVARCHAR(4000)  
            ,  E4_2                 NVARCHAR(4000)  
            ,  E4_3                 NVARCHAR(4000)  
            ,  E5                   NVARCHAR(4000)  
            ,  E7                   NVARCHAR(4000)  
            ,  E8_1                 NVARCHAR(4000)  
            ,  E8_2                 NVARCHAR(4000)  
            ,  E8_3                 NVARCHAR(4000)  
            ,  E9                   NVARCHAR(4000)  
            ,  E11                  NVARCHAR(4000) 
            ,  D20                  NVARCHAR(4000)        --(CS01)
            ,  Cur_COD              NVARCHAR(30)          --(CS01)
            ,  TotalCOD             FLOAT                 --(CS01)
            ,  E13                  NVARCHAR(4000)        --(CS02)
            ,  G1                   NVARCHAR(4000)        --(CS03)
            ,  G2                   NVARCHAR(4000)        --(CS03)
            ,  G3                   NVARCHAR(4000)        --(CS03)
            ,  E3_3                 NVARCHAR(4000)        --(CS03)
            ,  E3_4                 NVARCHAR(4000)        --(CS03)
            ,  E3_5                 NVARCHAR(4000)        --(CS03)
            
                        
   --         ,  F1                   NVARCHAR(4000)  
   --         ,  F3                   NVARCHAR(4000)  
   --         ,  F5                   NVARCHAR(4000)  
   --         ,  F7                   NVARCHAR(4000)  
   --         ,  F9                   NVARCHAR(4000)  
   --         ,  F11                  NVARCHAR(4000)  
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
      AND   OH.Type = 'DTC'

                                                                
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
			   ,  M_Fax1          
			   ,  M_Fax2          
			   ,  M_Phone1        
			   ,  M_Phone2                
            ,  UserDefine03         
            ,  UserDefine07         
            ,  IntermodalVehicle    
            ,  Cur_UnitPrice 
            ,  Cur_ShipHandling 
            ,  Cur_SalesTax 
            ,  Cur_Order
            ,  Cur_Vat 
            ,  Cur_Discount 
            ,  Notes
            ,  TotalUnitPrice       
            ,  TotalShipHandling    
            ,  SalesTax              
            ,  VATRate              
            ,  VATAmt                                                                                       
            ,  TotalDiscount        
            ,  OrderBrand           
            ,  A2                   
            ,  B1                   
            ,  B8                   
            ,  B15                  
            ,  B17                  
            ,  B19                  
   --         ,  C1                   
   --         ,  C3                   
   --         ,  C5                   
   --         ,  C7                   
   --         ,  C9                   
            ,  C12                  
            ,  D1                   
            ,  D4                   
            ,  D7                   
            ,  D10                  
            ,  D13                  
            ,  D17                  
            ,  E1_1                 
            ,  E1_2                 
            ,  E2_1                 
            ,  E2_2                 
            ,  E3_1                 
            ,  E3_2                 
            ,  E4_1                 
            ,  E4_2                 
            ,  E4_3                 
            ,  E5                   
            ,  E7                   
            ,  E8_1                 
            ,  E8_2                 
            ,  E8_3                 
            ,  E9                   
            ,  E11
            ,  D20                --(CS01)
            ,  Cur_COD            --(CS01)
            ,  TotalCOD           --(CS01)  
            ,  E13                --(CS02)   
            ,  G1                 --(CS03)  
            ,  G2                 --(CS03) 
            ,  G3                 --(CS03) 
            ,  E3_3               --(CS03)
            ,  E3_4               --(CS03)
            ,  E3_5               --(CS03)
   --         ,  F1                   
   --         ,  F3                   
   --         ,  F5                   
   --         ,  F7                   
   --         ,  F9                   
   --         ,  F11                  
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
			   ,M_Fax1         = ISNULL(RTRIM(OH.M_Fax1),'') 
			   ,M_Fax2         = ISNULL(RTRIM(OH.M_Fax2),'') 
			   ,M_Phone1       = ISNULL(RTRIM(OH.M_Phone1),'') 
			   ,M_Phone2       = ISNULL(RTRIM(OH.M_Phone2),'') 
            ,UserDefine03   = ISNULL(RTRIM(OH.UserDefine03),'') 
            ,UserDefine07   = ISNULL(RTRIM(OH.UserDefine07),'1900-01-01') 
            ,IntermodalVehicle= ISNULL(RTRIM(OH.BuyerPO),'')                  --12-AUG-2014
            ,Cur_UnitPrice    = ISNULL(RTRIM(OH.IncoTerm),'') 
            ,Cur_Shiphandling = ISNULL(RTRIM(OH.IncoTerm),'') 
            ,Cur_SalesTax     = ISNULL(RTRIM(OH.IncoTerm),'') 
            ,Cur_Order        = ISNULL(RTRIM(OH.IncoTerm),'') 
            ,Cur_Vat          = ISNULL(RTRIM(OH.IncoTerm),'') 
            ,Cur_Discount     = ISNULL(RTRIM(OH.IncoTerm),'')
            ,Notes          = ISNULL(RTRIM(OH.Notes),'')
             -- Qty > 0 mean not backordered
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
            ,OrderBrand     = ISNULL( RTRIM(CL.Long), '')
            ,LBL.A2             
            ,LBL.B1            	
            ,LBL.B8            	
            ,LBL.B15           	
            ,LBL.B17           	
            ,LBL.B19           	
   --         ,LBL.C1            	
   --         ,LBL.C3            	
   --         ,LBL.C5            	
   --         ,LBL.C7            	
   --         ,LBL.C9
            ,LBL.C12            	
            ,LBL.D1            	
            ,LBL.D4            	
            ,LBL.D7            	
            ,LBL.D10           	
            ,LBL.D13           	
            ,LBL.D17           	
            ,LBL.E1_1            	
            ,LBL.E1_2          	
            ,LBL.E2_1          	
            ,LBL.E2_2          	
            ,LBL.E3_1          	
            ,LBL.E3_2            	
            ,LBL.E4_1          	
            ,LBL.E4_2          	
            ,LBL.E4_3          	
            ,LBL.E5            	
            ,LBL.E7            	
            ,LBL.E8_1          	
            ,LBL.E8_2          	
            ,LBL.E8_3          	
            ,LBL.E9            	
            ,LBL.E11 
            ,LBL.D20                                             --(CS01)
            ,Cur_COD     = ISNULL(RTRIM(OH.IncoTerm),'')         --(CS01) 
            ,TotalCOD    = ISNULL( SUM(CASE WHEN (ISNUMERIC(OD.UserDefine06) = 1 AND Qty > 0)
                                               THEN (CONVERT(FLOAT,OD.UserDefine06)) ELSE 0.00
                                               END),0.00 )  
            ,LBL.E13                                                --(CS02)   
            ,LBL.G1                                                 --(CS03)  
            ,LBL.G2                                                 --(CS03)  
            ,LBL.G3                                                 --(CS03)     
            ,LBL.E3_3                                               --(CS03)   
            ,LBL.E3_4                                               --(CS03)      
            ,LBL.E3_5                                               --(CS03)                                                                                                                                                                         	
   --         ,LBL.F1            	
   --         ,LBL.F3            	
   --         ,LBL.F5            	
   --         ,LBL.F7            	
   --         ,LBL.F9            	
   --         ,LBL.F11   
	   FROM ORDERS OH WITH (NOLOCK)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
      JOIN PICKDETAIL  PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)
                                        AND(OD.OrderLineNumber = PD.OrderLineNumber)
      JOIN dbo.fnc_GetInv01Label (@c_orderkey) lbl ON (lbl.Orderkey = OH.Orderkey)
      LEFT JOIN CODELKUP    CL WITH (NOLOCK) ON (CL.ListName = 'ANFBrand' AND CL.Code = OH.Sectionkey)
      LEFT JOIN ORDERINFO OI WITH (NOLOCK) ON (OH.Orderkey = OI.Orderkey)
	   WHERE OH.Orderkey = @c_orderkey
      AND   OH.Type = 'DTC'
      GROUP BY OH.Orderkey
            ,  ISNULL(RTRIM(OH.B_Contact1),'')
	         ,	ISNULL(RTRIM(OH.B_Contact2),'')
	         ,	ISNULL(RTRIM(OH.B_Address1),'')
	         ,	ISNULL(RTRIM(OH.B_Address2),'')
	         ,	ISNULL(RTRIM(OH.B_Address3),'')
	         ,	ISNULL(RTRIM(OH.B_Address4),'') 
			   ,  ISNULL(RTRIM(OH.B_City),'')
			   ,  ISNULL(RTRIM(OH.B_Zip),'')
			   ,  ISNULL(RTRIM(OH.B_State),'')
			   ,  ISNULL(RTRIM(OH.B_Country),'')  
	         ,	ISNULL(RTRIM(OH.C_Contact1),'')
	         ,	ISNULL(RTRIM(OH.C_Contact2),'')
	         ,	ISNULL(RTRIM(OH.C_Address1),'')
	         ,	ISNULL(RTRIM(OH.C_Address2),'')
	         ,	ISNULL(RTRIM(OH.C_Address3),'')
	         ,	ISNULL(RTRIM(OH.C_Address4),'') 
			   ,  ISNULL(RTRIM(OH.C_City),'')
			   ,  ISNULL(RTRIM(OH.C_Zip),'')
			   ,  ISNULL(RTRIM(OH.C_State),'')
			   ,  ISNULL(RTRIM(OH.C_Country),'')  
	         ,	ISNULL(RTRIM(OH.M_Company),'') 
			   ,  ISNULL(RTRIM(OH.M_Fax1),'')    
            ,  ISNULL(RTRIM(OH.M_Fax2),'')    
            ,  ISNULL(RTRIM(OH.M_Phone1),'')  
            ,  ISNULL(RTRIM(OH.M_Phone2),'')  
            ,  ISNULL(RTRIM(OH.UserDefine03),'') 
            ,  ISNULL(RTRIM(OH.UserDefine07),'1900-01-01') 
            ,  ISNULL(RTRIM(OH.BuyerPO),'')          --12-AUG-2014
            ,  ISNULL(RTRIM(OH.IncoTerm),'') 
            ,  ISNULL(RTRIM(OH.Notes),'')
            ,  ISNULL( RTRIM(CL.Long), '')
            ,  CASE WHEN ISNUMERIC(OI.OrderInfo05) = 1 THEN CONVERT(FLOAT,OI.OrderInfo05) ELSE 0.00 END
            ,LBL.A2             
            ,LBL.B1            	
            ,LBL.B8            	
            ,LBL.B15           	
            ,LBL.B17           	
            ,LBL.B19           	
   --         ,LBL.C1            	
   --         ,LBL.C3            	
   --         ,LBL.C5            	
   --         ,LBL.C7            	
   --         ,LBL.C9
            ,LBL.C12            	
            ,LBL.D1            	
            ,LBL.D4            	
            ,LBL.D7            	
            ,LBL.D10           	
            ,LBL.D13           	
            ,LBL.D17           	
            ,LBL.E1_1            	
            ,LBL.E1_2          	
            ,LBL.E2_1          	
            ,LBL.E2_2          	
            ,LBL.E3_1          	
            ,LBL.E3_2            	
            ,LBL.E4_1          	
            ,LBL.E4_2          	
            ,LBL.E4_3          	
            ,LBL.E5            	
            ,LBL.E7            	
            ,LBL.E8_1          	
            ,LBL.E8_2          	
            ,LBL.E8_3          	
            ,LBL.E9            	
            ,LBL.E11
            ,LBL.D20            --(CS01)    
            ,LBL.E13            --(CS02)     
            ,LBL.G1             --(CS03) 	
            ,LBL.G2             --(CS03) 
            ,LBL.G3             --(CS03) 
            ,LBL.E3_3           --(CS03)   
            ,LBL.E3_4           --(CS03)      
            ,LBL.E3_5           --(CS03) 
   --         ,LBL.F1            	
   --         ,LBL.F3            	
   --         ,LBL.F5            	
   --         ,LBL.F7            	
   --         ,LBL.F9            	
   --         ,LBL.F11   
      
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
			   ,  T_INV.M_Fax1 + T_INV.M_Fax2 
            ,  T_INV.M_Fax2        
			   ,  T_INV.M_Phone1 + T_INV.M_Phone2  
            ,  T_INV.M_Phone2     
            ,  UserDefine07 = CONVERT(NVARCHAR(10), T_INV.UserDefine07, 111)     
            ,  T_INV.IntermodalVehicle    
            ,  T_INV.Cur_UnitPrice      
            ,  T_INV.Cur_ShipHandling   
            ,  T_INV.Cur_Order
            ,  Cur_SalesTax      = CASE WHEN T_INV.SalesTax > 0.00 THEN T_INV.Cur_SalesTax ELSE '' END
            ,  Cur_Vat           = CASE WHEN T_INV.VATRate > 0.00 AND T_INV.VATAmt > 0.00  THEN T_INV.Cur_Vat ELSE '' END 
            ,  Cur_Discount      = CASE WHEN T_INV.TotalDiscount > 0.00 THEN T_INV.Cur_Discount ELSE '' END     
            ,  T_INV.Notes     
            ,  T_INV.TotalUnitPrice       
            ,  T_INV.TotalShipHandling   
            ,  SalesTax = CASE WHEN T_INV.SalesTax > 0.00
                               THEN CONVERT(NVARCHAR(10), CONVERT(DECIMAL(8,2),T_INV.SalesTax))   
                               ELSE '' END   
            ,  T_INV.TotalUnitPrice +  T_INV.TotalShipHandling + T_INV.SalesTax + T_INV.TotalCOD    --(CS01)      
            ,  VATRate  = CASE WHEN T_INV.VATRate > 0.00 AND T_INV.VATAmt > 0.00 
                               THEN CONVERT(NVARCHAR(10), CONVERT(DECIMAL(8,2),T_INV.VATRate)) + '%'  
                               ELSE '' END            
            ,  VATAmt   = CASE WHEN T_INV.VATRate > 0.00 AND T_INV.VATAmt > 0.00 
                               THEN CONVERT(NVARCHAR(10), CONVERT(DECIMAL(8,2),T_INV.VATAmt))   
                               ELSE '' END                                                                                      
            ,  TotalDiscount = CASE WHEN T_INV.TotalDiscount > 0.00 
                               THEN CONVERT(NVARCHAR(10), CONVERT(DECIMAL(8,2),T_INV.TotalDiscount))   
                               ELSE '' END  
            ,  T_INV.OrderBrand           
            ,  T_INV.A2  + ': '                 
            ,  T_INV.B1  + ': '                   
            ,  T_INV.B8  + ': '                   
            ,  T_INV.B15 + ': '                   
            ,  T_INV.B17 + ': '                   
            ,  T_INV.B19 + ': '                   
            ,  T_INV.C12                    
            ,  T_INV.D1                   
            ,  T_INV.D4                     
            ,  D7  = CASE WHEN T_INV.SalesTax > 0.00 THEN T_INV.D7 ELSE '' END                  
            ,  T_INV.D10                   
            ,  D13 = CASE WHEN  T_INV.VATRate > 0.00 AND T_INV.VATAmt > 0.00 THEN T_INV.D13  ELSE '' END               
            ,  D17 = CASE WHEN T_INV.TotalDiscount > 0.00 THEN T_INV.D17 ELSE '' END                 
            ,  T_INV.E1_1                   
            ,  T_INV.E1_2                   
            ,  T_INV.E2_1                
            ,  T_INV.E2_2              
            ,  T_INV.E3_1                   
            ,  T_INV.E3_2                    
            ,  T_INV.E4_1                   
            ,  T_INV.E4_2                  
            ,  T_INV.E4_3                    
            ,  T_INV.E5                       
            ,  T_INV.E7                      
            ,  T_INV.E8_1                    
            ,  T_INV.E8_2                 
            ,  T_INV.E8_3                 
            ,  T_INV.E9  + ': '                       
            ,  T_INV.E11 + ': ' 
            ,  D20 = CASE WHEN T_INV.TotalCOD > 0.00 THEN T_INV.D20  ELSE '' END                                                                      --(CS01)   
            ,  Cur_COD      = CASE WHEN T_INV.TotalCOD > 0.00 THEN T_INV.Cur_COD ELSE '' END    --(CS01)
            ,  TotalCOD = CASE WHEN T_INV.TotalCOD > 0.00                                       --(CS01)
                               THEN CONVERT(NVARCHAR(10), CONVERT(DECIMAL(8,2),T_INV.TotalCOD)) --(CS01)   
                               ELSE '' END    
            ,E13                                                                                --(CS02)     
            ,G1                                                                                 --(CS03)   
            ,G2                                                                                 --(CS03)   
            ,G3                                                                                 --(CS03)  
            ,E3_3                                                                                --(CS03)   
            ,E3_4                                                                               --(CS03)      
            ,E3_5                                                                               --(CS03)                                                                                     
      FROM #TMP_INVHDR T_INV
      JOIN #TMP_RECGRP T_GRP ON (T_INV.Orderkey = T_GRP.Orderkey)

      DROP TABLE #TMP_INVHDR

      DROP TABLE #TMP_RECGRP

      GOTO QUIT
   TYPE_D_NML:

      SELECT Sku
			   ,Descr 	 
			   ,Color	 
			   ,Size	     
			   ,UnitPrice
			   ,C1
			   ,C3
			   ,C5
			   ,C7
			   ,C9
	   FROM #TMP_INVDET
      WHERE RecGroup = @n_RecGroup
      ORDER BY SeqNo

      DROP TABLE #TMP_INVDET
      GOTO QUIT

   TYPE_D_RET:

	   SELECT Sku
			   ,Descr 	   
			   ,Color	   
			   ,Size	      
			   ,UnitPrice  
			   ,F1
			   ,F3
			   ,F5
			   ,F7
			   ,F9
			   ,F11
	   FROM #TMP_INVDET
      WHERE RecGroup = @n_RecGroup
      AND QtyShipped > 0
      ORDER BY SeqNo

      DROP TABLE #TMP_INVDET
      GOTO QUIT
   QUIT:
END

GO