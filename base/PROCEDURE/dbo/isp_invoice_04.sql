SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Function:   isp_invoice_04                                           */
/* Creation Date: 13-Jul-2017                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:                                                             */
/*        : WMS-2338 - New Customer Invoice (ANF TMALL) - CN            */
/*                                                                      */
/* Called By:  r_dw_invoice_04                                          */
/*                                                                      */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 15-May-2018  SPChin    1.1   INC0232078 - Bug Fixed                  */
/* 22-May-2018  SPChin    1.1   INC0236498 - Bug Fixed                  */
/* 18-Sep-2019  WLChooi   1.3   WMS-10586 - Add new column, revised     */
/*                              TotalQty - Only for CN (WL01)           */
/* 31-Oct-2019  WLChooi   1.4   Fixed TotalUnitPrice bug (WL02)         */
/* 10-Feb-2020  CSCHONG   1.5   WMS-11893 add new field (CS01)          */
/* 07-Aug-2023  WLChooi   1.6   WMS-23330 - Add new field (WL03)        */
/************************************************************************/

CREATE   PROC [dbo].[isp_invoice_04]  (
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

   CREATE TABLE #TMP_INVDET04 
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
            ,  C9_1                 NVARCHAR(4000)
            ,  C10_2                NVARCHAR(4000)
            ,  RecGroup             INT
            ,  Qty                  INT             --WL01
            ,  C11                  NVARCHAR(4000)  --WL01
            )

      INSERT INTO  #TMP_INVDET04 
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
            ,  C9_1                   
            ,  C10_2                   
            ,  RecGroup 
            ,  Qty            --WL01
            ,  C11            --WL01              
            )
      SELECT OD.Orderkey
            ,OD.Sku
            ,Descr = ISNULL(OD.userdefine01,'') + ISNULL(OD.userdefine02,'')-- ,Descr    = ISNULL(SUBSTRING(ODR.Note1,301,250),'')
            ,Color     = ISNULL(S.color,'')--ISNULL(SUBSTRING(ODR.Note1,551,120),'')
            ,Size      = ISNULL(S.size,'')--ISNULL(SUBSTRING(ODR.Note1,671,300),'')

            ,UnitPrice = CONVERT(NVARCHAR(10),CONVERT(DECIMAL(8,2),OD.UnitPrice))
            ,OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty
            ,LBL.C1
            ,LBL.C3
            ,LBL.C5
            ,LBL.C7
            ,LBL.C9
            ,LBL.C9_1                   
            ,LBL.C10_2                   
            ,RecGroup   =(ROW_NUMBER() OVER (PARTITION BY OH.Orderkey ORDER BY OH.Orderkey,  OD.OrderLineNumber ASC)-1)/@n_NoOfLine
           -- ,'(' + OH.incoterm + ')'
            ,CASE WHEN @c_Country = 'CN' THEN SUM(PD.Qty) ELSE 0 END       --WL01
            ,CASE WHEN @c_Country = 'CN' THEN LBL.C11 ELSE '' END          --WL01
      FROM ORDERDETAIL OD  WITH (NOLOCK)
      JOIN ORDERS      OH  WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey)
      JOIN SKU S WITH (NOLOCK) ON s.storerkey = OD.storerkey AND S.sku = OD.sku
      JOIN fnc_GetInv04Label ( @c_Orderkey ) LBL ON (OD.Orderkey = LBL.Orderkey)
      JOIN PICKDETAIL PD (NOLOCK) ON (PD.ORDERKEY = OD.ORDERKEY AND PD.SKU = OD.SKU AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER) --WL01
      WHERE OD.Orderkey = @c_Orderkey 
      AND OD.UserDefine01 <> 'Backordered'
      --WL01 Start
      GROUP BY OD.Orderkey
            ,OD.Sku
            ,ISNULL(OD.userdefine01,'') + ISNULL(OD.userdefine02,'')
            ,ISNULL(S.color,'')
            ,ISNULL(S.size,'')
            ,CONVERT(NVARCHAR(10),CONVERT(DECIMAL(8,2),OD.UnitPrice))
            ,OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty
            ,LBL.C1
            ,LBL.C3
            ,LBL.C5
            ,LBL.C7
            ,LBL.C9
            ,LBL.C9_1                   
            ,LBL.C10_2                   
            ,OH.Orderkey, OD.OrderLineNumber
            ,CASE WHEN @c_Country = 'CN' THEN LBL.C11 ELSE '' END          --WL01
            --WL01 End
      ORDER BY OD.OrderLineNumber

   IF @c_type = 'D_NML' GOTO TYPE_D_NML
   --IF @c_type = 'D_RET' GOTO TYPE_D_RET

   TYPE_H1:
      CREATE TABLE #TMP_INVHDR04 
            (  Orderkey             NVARCHAR(10)
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
            ,  ORDDate              DATETIME
            ,  TotalUnitPrice       FLOAT
            ,  TotalShipHandling    FLOAT
            ,  SalesTax             FLOAT  
            ,  TTLSKU               INT  
            ,  B19                  NVARCHAR(4000)  
            ,  B8                   NVARCHAR(4000)  
            ,  B15_1                NVARCHAR(4000)  
            ,  B15_2                NVARCHAR(4000)  
            ,  B17                  NVARCHAR(4000)  
            ,  D1_2                 NVARCHAR(4000)  
            ,  D4                   NVARCHAR(4000)  
            ,  D3                   NVARCHAR(4000)  
            ,  D10                  NVARCHAR(4000)   
            ,  D12                  NVARCHAR(4000)  
            ,  D6                   NVARCHAR(4000) 
            ,  D9                   NVARCHAR(4000)  
            ,  E2                   NVARCHAR(4000)  
            ,  E3                   NVARCHAR(4000)   
            ,  E4                   NVARCHAR(4000)  
            ,  E5                   NVARCHAR(4000)  
            ,  E8                   NVARCHAR(4000)   
            ,  E9                   NVARCHAR(4000)  
            ,  E10                  NVARCHAR(4000) 
            ,  E11                  NVARCHAR(4000)          
            ,  TotalCOD             FLOAT                
            ,  E12                  NVARCHAR(4000)             
            ,  E14                  NVARCHAR(4000)          
            ,  ExtOrdKey            NVARCHAR(20)    
            ,  DCBarCode            NVARCHAR(80)  
            ,  E13                  NVARCHAR(4000) 
            ,  E1                   NVARCHAR(4000)     
            ,  E7                   NVARCHAR(4000)  
            ,  D7                   NVARCHAR(4000)
            ,  D17                  NVARCHAR(4000)
            ,  D19                  NVARCHAR(4000) 
            ,  E15                  NVARCHAR(4000)          --CS01   
            ,  E16                  NVARCHAR(4000)          --CS01
            ,  E6                   NVARCHAR(4000)   --WL03
            ,  E11_1                NVARCHAR(4000)   --WL03
            ,  E11_2                NVARCHAR(4000)   --WL03
            ,  E11_3                NVARCHAR(4000)   --WL03
            ,  E11_4                NVARCHAR(4000)   --WL03
            ,  E11_5                NVARCHAR(4000)   --WL03
            ,  E11_6                NVARCHAR(4000)   --WL03
            )   
              

      CREATE TABLE #TMP_RECGRP04
            (  RecGroup             INT
            ,  Orderkey             NVARCHAR(10)
            )

      INSERT INTO #TMP_RECGRP04
            (  RecGroup             
            ,  Orderkey
            )                        
      SELECT DISTINCT RecGroup   =(ROW_NUMBER() OVER (PARTITION BY OH.Orderkey ORDER BY OH.Orderkey,  (OD.OrderLineNumber) ASC)-1)/ @n_NoOfLine
         , OH.Orderkey
      FROM ORDERS OH WITH (NOLOCK)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
      WHERE OH.Orderkey = @c_Orderkey
      AND OD.UserDefine01 <> 'Backordered'

                                                                
      INSERT INTO #TMP_INVHDR04
            (  Orderkey                             
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
            ,  ORDDate         
            ,  TotalUnitPrice       
            ,  TotalShipHandling    
            ,  SalesTax                     
            ,  TTLSKU                             
            ,  B19                   
            ,  B8                   
            ,  B15_1
            ,  B15_2                  
            ,  B17                                    
            ,  D1_2                   
            ,  D4                   
            ,  D3                   
            ,  D10                                  
            ,  D12                  
            ,  D6                
            ,  D9                 
         --   ,  E1                 
            ,  E2                 
            ,  E3                                
            ,  E4                 
            ,  E5                   
            ,  E8                                  
            ,  E9                   
            ,  E10
            ,  E11            
            ,  TotalCOD           
            ,  E12          
            ,  E13 
            ,  E14                   
            ,  ExtOrdKey
            ,  DCBarCode   
            ,  E1                
            ,  E7     
            ,  D7   
            ,  D17, D19  
            ,  E15,E16       --CS01   
            ,  E6      --WL03
            ,  E11_1   --WL03
            ,  E11_2   --WL03
            ,  E11_3   --WL03
            ,  E11_4   --WL03
            ,  E11_5   --WL03
            ,  E11_6   --WL03
            ) 
                                                                                      
      SELECT DISTINCT 
             OH.Orderkey
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
            ,OrdDate   = ISNULL(RTRIM(OH.OrderDate),'1900-01-01') 
            --,TotalUnitPrice = ISNULL(SUM(CASE WHEN Qty > 0 THEN PD.Qty * OD.UnitPrice ELSE 0.00 END),0.00)   --INC0236498 
            ,TotalUnitPrice = ISNULL(SUM(OD.UnitPrice), 0.00)                                                  --INC0236498 
            --,TotalShipHandling=ISNULL( SUM(CASE WHEN Qty > 0                                     --INC0232078, INC0236498
            --                                    THEN CASE WHEN ISNUMERIC( OH.UserDefine01 ) = 1   
            --                                              THEN CONVERT(FLOAT,OH.UserDefine01)    
            --                                              ELSE 0.00 END --+ OD.ExtendedPrice     
            --                                    ELSE 0.00 END),0.00 )                            
            ,TotalShipHandling=ISNULL( SUM(CASE WHEN ISNUMERIC( OH.UserDefine01 ) = 1              --INC0232078, INC0236498 
                                                THEN CONVERT(FLOAT,OH.UserDefine01)                
                                                ELSE 0.00 END),0.00 )                                                 
            ,SalesTax       = ISNULL( SUM(OD.Tax01), 0.00 )
            ,TTLSKU     = CASE WHEN @c_Country = 'CN' THEN SUM(PD.Qty) ELSE COUNT (DISTINCT OD.sku) END --COUNT (DISTINCT OD.sku)      --WL01       
            ,LBL.B19             
            ,LBL.B8              
            ,LBL.B15_1              
            ,LBL.B15_2           
            ,LBL.B17                      
            ,LBL.D1_2               
            ,LBL.D4              
            ,LBL.D3              
            ,LBL.D10                         
            ,LBL.D12             
            ,LBL.D6           
            ,LBL.D9           
            --,LBL.E1            
            ,LBL.E2           
            ,LBL.E3                       
            ,LBL.E4                       
            ,LBL.E5              
            ,LBL.E8                          
            ,LBL.E9              
            ,LBL.E10
            ,LBL.E11        
            --,TotalCOD    = ISNULL( SUM(CASE WHEN (ISNUMERIC(OD.UserDefine06) = 1 AND Qty > 0) --INC0236498
            --               THEN (CONVERT(FLOAT,OD.UserDefine06)) ELSE 0.00                    
            --                                   END),0.00 )                                    
            ,TotalCOD    = ISNULL( SUM(CASE WHEN (ISNUMERIC(OD.UserDefine06) = 1)               --INC0236498
                                            THEN (CONVERT(FLOAT,OD.UserDefine06)) ELSE 0.00     
                                            END),0.00 )                                                                         
            ,LBL.E12                                                 
            ,LBL.E13                                                 
            ,LBL.E14                                                                
            ,ExtOrdKey = ISNULL(OH.ExternOrderKey,'')
            ,DCBarCode = ISNULL(RTRIM(OH.M_Company),'')--ISNULL(RTRIM(CL.short), '') 
            ,LBL.E1 
            ,LBL.E7
            ,LBL.D7
            ,LBL.D17
            ,LBL.D19
            ,LBL.E15              --CS01                                                
            ,LBL.E16              --CS01
            --WL03 S
            ,LBL.E6
            ,LBL.E11_1
            ,LBL.E11_2
            ,LBL.E11_3
            ,LBL.E11_4
            ,LBL.E11_5
            ,LBL.E11_6
            --WL03 E
      FROM ORDERS OH WITH (NOLOCK)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
      --JOIN PICKDETAIL  PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)                        --INC0236498
      --                                  AND(OD.OrderLineNumber = PD.OrderLineNumber)          --INC0236498
      JOIN dbo.fnc_GetInv04Label (@c_orderkey) lbl ON (lbl.Orderkey = OH.Orderkey)
      LEFT JOIN CODELKUP    CL WITH (NOLOCK) ON (CL.ListName = 'anffac' AND CL.Code = OH.facility )
      --LEFT JOIN ORDERINFO OI WITH (NOLOCK) ON (OH.Orderkey = OI.Orderkey)
      --JOIN PICKDETAIL PD (NOLOCK) ON (PD.ORDERKEY = OD.ORDERKEY AND PD.SKU = OD.SKU AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER) --WL01
      CROSS APPLY (SELECT SUM(Qty) AS Qty FROM PICKDETAIL PD (NOLOCK) WHERE PD.ORDERKEY = OD.ORDERKEY AND PD.SKU = OD.SKU) AS PD --WL02
      WHERE OH.Orderkey = @c_orderkey
      --AND (OD.ShippedQty + OD.QtyPicked) > 0
      AND OD.UserDefine01 <> 'Backordered'
      GROUP BY OH.Orderkey
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
            ,  ISNULL(RTRIM(OH.OrderDate),'1900-01-01') 
            ,  ISNULL( RTRIM(CL.short), '')            
            ,LBL.B19             
            ,LBL.B8              
            ,LBL.B15_1              
            ,LBL.B15_2              
            ,LBL.B17                         
            ,LBL.D1_2               
            ,LBL.D4              
            ,LBL.D3              
            ,LBL.D10             
            ,LBL.D12                         
            ,LBL.D6           
            ,LBL.D9                    
            ,LBL.E2           
            ,LBL.E3                       
            ,LBL.E4           
            ,LBL.E5              
            ,LBL.E8                       
            ,LBL.E9              
            ,LBL.E10
            ,LBL.E11
            ,LBL.E1           
            ,LBL.E12              
            ,LBL.E13             
            ,LBL.E14                      
            ,ISNULL(OH.ExternOrderKey,'')             
            ,LBL.E7  
            ,LBL.D7
            ,LBL.D17
            ,LBL.D19 
            ,LBL.E15              --CS01                                                
            ,LBL.E16              --CS01
            --WL03 S
            ,LBL.E6
            ,LBL.E11_1
            ,LBL.E11_2
            ,LBL.E11_3
            ,LBL.E11_4
            ,LBL.E11_5
            ,LBL.E11_6
            --WL03 E

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
         FROM #TMP_INVHDR04

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
            ,  OrdDate = CONVERT(NVARCHAR(10), T_INV.OrdDate, 111)        
            ,  T_INV.TotalUnitPrice       
            ,  T_INV.TotalShipHandling   
            ,  SalesTax = CASE WHEN T_INV.SalesTax > 0.00
                               THEN CONVERT(NVARCHAR(10), CONVERT(DECIMAL(8,2),T_INV.SalesTax))   
                               ELSE '' END   
            ,  T_INV.TotalUnitPrice +  T_INV.TotalShipHandling + T_INV.SalesTax   AS totalorder     
            ,  T_INV.TTLSKU                          
            ,  B19 = T_INV.B19--  + ': '                   
            ,  B8  = T_INV.B8  --+ ': '                   
            ,  B15_1 = T_INV.B15_1 + ': '                   
            ,  B15_2 = T_INV.B15_2 + ': '                   
            ,  B17 = T_INV.B17 + ': '                                      
            ,  T_INV.D1_2                   
            ,  T_INV.D4                     
            ,  T_INV.D3                  
            ,  T_INV.D10                   
           -- ,  D13 = CASE WHEN  T_INV.VATRate > 0.00 AND T_INV.VATAmt > 0.00 THEN T_INV.D13  ELSE '' END               
            ,  T_INV.D12                 
            ,  T_INV.D6                   
            ,  T_INV.D9                                   
            ,  T_INV.E2              
            ,  T_INV.E3                                    
            ,  T_INV.E4                    
            ,  T_INV.E5                       
            ,  T_INV.E8                                       
            ,  E9 = T_INV.E9  --+ ': '                       
            ,  E10 = T_INV.E10 --+ ': ' 
            ,  T_INV.E11                      
            ,  TotalCOD = CASE WHEN T_INV.TotalCOD > 0.00                                       
                               THEN CONVERT(NVARCHAR(10), CONVERT(DECIMAL(8,2),T_INV.TotalCOD))   
                               ELSE '' END    
            ,E12                                                                                                                                                               
            ,E14                                                                                 
            ,T_INV.ExtOrdkey
            ,T_INV.DCBarCode  
            ,E13  
            ,E1 
            ,E7    
        --    ,D7
        --    ,D17
        --    ,D19    
            ,E15        --CS01
            ,E16        --CS01     
            --WL03 S
            ,E6
            ,E11_1
            ,E11_2
            ,E11_3
            ,E11_4
            ,E11_5
            ,E11_6
            --WL03 E
      FROM #TMP_INVHDR04 T_INV
      JOIN #TMP_RECGRP04 T_GRP ON (T_INV.Orderkey = T_GRP.Orderkey)

      DROP TABLE #TMP_INVHDR04

      DROP TABLE #TMP_RECGRP04

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
            ,C9_1
            ,C10_2
            ,Qty     --WL01
            ,C11     --WL01
      FROM #TMP_INVDET04
      WHERE RecGroup = @n_RecGroup
      ORDER BY SeqNo

      DROP TABLE #TMP_INVDET04
      GOTO QUIT

   /*TYPE_D_RET:

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
            ,C9_1
            ,C10_2
      FROM #TMP_INVDET04
      WHERE RecGroup = @n_RecGroup
      --AND QtyShipped > 0
      ORDER BY SeqNo

      DROP TABLE #TMP_INVDET04
      GOTO QUIT */
   QUIT:
END

GO