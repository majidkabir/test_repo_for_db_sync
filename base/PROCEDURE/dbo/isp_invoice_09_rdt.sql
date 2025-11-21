SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Function:   isp_invoice_09_rdt                                       */
/* Creation Date: 26-Jan-2021                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:                                                             */
/*        : WMS-16044 - [KR] - iiCombined - Invoice in English          */
/*                                                                      */
/* Called By:  r_dw_invoice_09_rdt                                      */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 12-MAR-2021  CSCHONG   1.1   WMS-16044 revised company field (CS01)  */
/* 03-JAN-2023  CSCHONG   1.2   Devops Scripts Combine & WMS-21391 (CS02)*/
/* 18-APR-2023  WZPang    1.3   Modify Columns (WZ01)                   */
/************************************************************************/

CREATE   PROC [dbo].[isp_invoice_09_rdt]  (
      @c_Orderkey           NVARCHAR(10)
     ,@c_C_ISOCntryCode     NVARCHAR(20) = ''
     ,@c_Facility           NVARCHAR(10) = ''
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

 

   CREATE TABLE #TMP_INVDET09RDT 
            (  SeqNo                INT IDENTITY (1,1)
            ,  RecGroup             INT 
            ,  Orderkey             NVARCHAR(10)
            ,  Sku                  NVARCHAR(20)
            ,  Descr                NVARCHAR(250)
            ,  ExtOrderkey          NVARCHAR(50)
            ,  Company              NVARCHAR(45)
            ,  OrderDate            DATETIME
            ,  ODUDF02              NVARCHAR(20)
            ,  ODUDF03              NVARCHAR(20)
            ,  Salesman             NVARCHAR(45) 
            ,  A2                   NVARCHAR(250)    
            ,  A3                   NVARCHAR(250)    
            ,  A4                   NVARCHAR(250) 
            ,  A5                   NVARCHAR(250)                
            ,  A6                   NVARCHAR(250)     
            ,  A7                   NVARCHAR(250)    
            ,  A8                   NVARCHAR(250)                
            ,  A9                   NVARCHAR(250)     
            ,  A10                  NVARCHAR(250)     
            ,  A11                  NVARCHAR(250)    
            ,  A12                  NVARCHAR(250)    
            ,  A13                  NVARCHAR(250) 
            ,  A14                  NVARCHAR(250)
            ,  Qty                  INT            
            ,  QtyUnit              NVARCHAR(5)  
            ,  A15                  NVARCHAR(250)
            ,  A17                  NVARCHAR(250) 
            ,  A18                  NVARCHAR(250) 
            ,  A19                  NVARCHAR(250)  
            ,  A20                  NVARCHAR(250)
            ,  C_Address1           NVARCHAR(200) 
            --,  C_Address2           NVARCHAR(45)                   --CS02
            ,  C_Address2           NVARCHAR(200)                    --WZ01
            ,  C_Address3           NVARCHAR(45)
            ,  C_Address4           NVARCHAR(45)
            ,  C_Zip                NVARCHAR(45)
            ,  OHUDF02              NVARCHAR(45) 
            ,  OHUDF05              NVARCHAR(45) 
            ,  ODUDF01              NVARCHAR(20) 
            ,  OHUDF10              NVARCHAR(45) 
            --,  CurSymbol            NVARCHAR(5)                     --CS02  
            ,  CurSymbol            NVARCHAR(20)                     --WZ01
            ,  A211                 NVARCHAR(250)                   --CS02
            ,  A212                 NVARCHAR(250)                   --CS02
            ,  A241                 NVARCHAR(250)                   --CS02
            ,  A242                 NVARCHAR(250)                   --CS02
            ,  A243                 NVARCHAR(250)                   --CS02
            ,  A213                 NVARCHAR(250)                   --CS02
            ,  A214                 NVARCHAR(250)                   --CS02
            ,  A244                 NVARCHAR(250)                   --CS02
            ,  A22                  NVARCHAR(250)                   --CS02
            ,  A25                  NVARCHAR(250)                   --CS02
            )

      INSERT INTO  #TMP_INVDET09RDT 
            (  recgroup
            ,  Orderkey              
            ,  Sku                   
            ,  Descr             
            ,  ExtOrderkey                 
            ,  Company                  
            ,  OrderDate             
            ,  ODUDF02           
            ,  ODUDF03                   
            ,  Salesman                                      
            ,  A2                   
            ,  A3                    
            ,  A4                   
            ,  A5                   
            ,  A6 
            ,  A7            
            ,  A8                   
            ,  A9                   
            ,  A10                   
            ,  A11 
            ,  A12            
            ,  A13
            ,  A14
            ,  Qty
            ,  QtyUnit 
            ,  A15
            ,  A17
            ,  A18
            ,  A19  
            ,  A20
            ,  C_Address1
            ,  C_Address2
            ,  c_address3
            ,  C_Address4
            ,  C_zip    
            ,  OHUDF02              
            ,  OHUDF05             
            ,  ODUDF01            
            ,  OHUDF10      
            ,  CurSymbol     --CS02    
            ,  A211          --CS02                             
            ,  A212          --CS02    
            ,  A241          --CS02    
            ,  A242          --CS02   
            ,  A243          --CS02     
            ,  A213          --CS02    
            ,  A214          --CS02    
            ,  A244          --CS02 
            ,  A22           --CS02 
            ,  A25           --CS02                
            )
      SELECT 1 as recgroup
            ,OD.Orderkey
            ,OD.Sku
            ,Descr =  ISNULL(S.descr,'')
            ,ExtOrderkey     = OH.Externorderkey
            --,Company         = left(OH.C_Company,1)+'*'+right(OH.C_Company,1)   --CS01
             ,Company         = OH.C_Company
            ,OH.OrderDate
            ,ISNULL(C1.Long,'') +SPACE(1) + FORMAT(OD.UnitPrice, '#,###,##0.00')--ISNULL(OD.userdefine02,'')   --CS02
            ,ISNULL(C1.Long,'') +SPACE(1) + FORMAT((OD.originalqty * OD.UnitPrice), '#,###,##0.00')--ISNULL(OD.userdefine03,'')
            ,ISNULL(C1.Long,'') +SPACE(1) + FORMAT(OIF.InsuredAmount, '#,###,##0.00')--OH.Salesman
            ,A2=ISNULL(MAX(CASE WHEN C.Code ='A2' THEN RTRIM(C.long) ELSE '' END),'')
            ,A3=ISNULL(MAX(CASE WHEN C.Code ='A3' THEN RTRIM(C.long) ELSE '' END),'')
            ,A4=ISNULL(MAX(CASE WHEN C.Code ='A4' THEN RTRIM(C.long) ELSE '' END),'')
            ,A5=ISNULL(MAX(CASE WHEN C.Code ='A5' THEN RTRIM(C.long) ELSE '' END),'')
            ,A6=ISNULL(MAX(CASE WHEN C.Code ='A6' THEN RTRIM(C.long) ELSE '' END),'')                  
            ,A7=ISNULL(MAX(CASE WHEN C.Code ='A7' THEN RTRIM(C.long) ELSE '' END),'')               
            ,A8=ISNULL(MAX(CASE WHEN C.Code ='A8' THEN RTRIM(C.long) ELSE '' END),'')
            ,A9=ISNULL(MAX(CASE WHEN C.Code ='A9' THEN RTRIM(C.long) ELSE '' END),'')
            ,A10=ISNULL(MAX(CASE WHEN C.Code ='A10' THEN RTRIM(C.long) ELSE '' END),'') 
            ,A11=ISNULL(MAX(CASE WHEN C.Code ='A11' THEN RTRIM(C.long) ELSE '' END),'')  
            ,A12=ISNULL(MAX(CASE WHEN C.Code ='A12' THEN RTRIM(C.long) ELSE '' END),'')  
            ,A13=ISNULL(MAX(CASE WHEN C.Code ='A13' THEN RTRIM(C.long) ELSE '' END),'')  
            ,A14=ISNULL(MAX(CASE WHEN C.Code ='A14' THEN RTRIM(C.long) ELSE '' END),'')    
            , (PD.Qty)        
            ,' X' 
            ,A15=ISNULL(MAX(CASE WHEN C.Code ='A15' THEN RTRIM(C.long) ELSE '' END),'')  
            ,A17=ISNULL(MAX(CASE WHEN C.Code ='A17' THEN RTRIM(C.long) ELSE '' END),'')  
            ,A18=ISNULL(MAX(CASE WHEN C.Code ='A18' THEN RTRIM(C.long) ELSE '' END),'')  
            ,A19=ISNULL(MAX(CASE WHEN C.Code ='A19' THEN RTRIM(C.long) ELSE '' END),'')  
            ,A20=ISNULL(MAX(CASE WHEN C.Code ='A20' THEN RTRIM(C.long) ELSE '' END),'')  
            ,ISNULL(OH.C_address1,'') + ISNULL(OH.C_address2,'') + ISNULL(OH.C_address3,'') + ISNULL(OH.C_address4,'') + ','   --CS02
            ,ISNULL(OH.C_Country,'') + ',' + ISNULL(OH.C_State,'') + ',' + ISNULL(OH.C_Zip,'')   --CS02
            ,ISNULL(OH.CountryOfOrigin,'')   --CS02
            ,'' --ISNULL(OH.C_address4,'')  --CS02
            ,''--,ISNULL(OH.C_Zip,'')  --CS01
            ,ISNULL(OH.userdefine02,'')
            ,''--ISNULL(OH.userdefine05,'')    --CS05
            ,ISNULL(S.susr4,'')--ISNULL(OD.userdefine01,'')      --CS02
            ,ISNULL(C1.Long,'') +SPACE(1) + FORMAT(OH.InvoiceAmount, '#,###,##0.00')--ISNULL(OH.userdefine10,'')   --CS01
            ,ISNULL(C1.Long,'')         --CS02  S
            ,A211=ISNULL(MAX(CASE WHEN C.Code ='A211' THEN RTRIM(C.long) ELSE '' END),'')  
            ,A212=ISNULL(MAX(CASE WHEN C.Code ='A212' THEN RTRIM(C.long) ELSE '' END),'')  
            ,A241=ISNULL(MAX(CASE WHEN C.Code ='A241' THEN RTRIM(C.long) ELSE '' END),'')  
            ,A242=ISNULL(MAX(CASE WHEN C.Code ='A242' THEN RTRIM(C.long) ELSE '' END),'')  
            ,A243=ISNULL(MAX(CASE WHEN C.Code ='A243' THEN RTRIM(C.long) ELSE '' END),'') 
            ,A213=ISNULL(MAX(CASE WHEN C.Code ='A213' THEN RTRIM(C.long) ELSE '' END),'')  
            ,A214=ISNULL(MAX(CASE WHEN C.Code ='A214' THEN RTRIM(C.long) ELSE '' END),'')  
            ,A244=ISNULL(MAX(CASE WHEN C.Code ='A244' THEN RTRIM(C.long) ELSE '' END),'')  
            ,A22 =ISNULL(MAX(CASE WHEN C.Code ='A22' THEN RTRIM(C.long) ELSE '' END),'')  
            ,A25 =ISNULL(MAX(CASE WHEN C.Code ='A25' THEN RTRIM(C.long) ELSE '' END),'')  --CS01 E
      FROM ORDERDETAIL OD  WITH (NOLOCK)
      JOIN ORDERS      OH  WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey)
      JOIN SKU S WITH (NOLOCK) ON s.storerkey = OD.storerkey AND S.sku = OD.sku
      --JOIN PICKDETAIL PD (NOLOCK) ON (PD.ORDERKEY = OD.ORDERKEY AND PD.SKU = OD.SKU AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER)     --WZ01
      JOIN (SELECT PD.ORDERKEY AS ORDERKEY , PD.SKU AS SKU , SUM(PD.QTY) AS QTY  
            FROM DBO.PICKDETAIL AS PD WITH(NOLOCK)  
            GROUP BY PD.ORDERKEY , PD.SKU) AS PD ON PD.ORDERKEY = OD.ORDERKEY AND PD.SKU = OD.SKU                                      --WZ01
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'DNENCONST' --AND C.UDF01 = @c_C_ISOCntryCode 
     AND C.UDF02 = @c_Facility AND C.storerkey = OH.Storerkey
      --CS02 S
      LEFT JOIN OrderInfo OIF WITH (NOLOCK) ON OIF.OrderKey = OH.OrderKey
     LEFT JOIN  CODELKUP C1 WITH (NOLOCK) ON C1.listname = 'CurrencyCD' AND C1.code = OIF.OrderInfo03 AND C1.storerkey = OH.Storerkey
     --CS02 E
      WHERE OH.Orderkey = @c_Orderkey 
      AND OH.C_ISOCntryCode = @c_C_ISOCntryCode
      AND OH.Facility = @c_Facility
      GROUP BY OD.Orderkey
            ,OD.Sku
            ,OD.UnitPrice--ISNULL(OD.userdefine02,'')  --CS02
            ,(OD.originalqty * OD.UnitPrice)--ISNULL(OD.userdefine03,'')
            ,ISNULL(S.descr,'')
            ,OH.Externorderkey
           -- ,left(OH.C_Company,1)+'*'+right(OH.C_Company,1)   --CS01
            , OH.C_Company
            ,OH.OrderDate
          --  ,OH.Salesman       --CS02
           ,OIF.InsuredAmount    --CS02
            ,ISNULL(OH.C_address1,'')
            ,ISNULL(OH.C_address2,'')
            ,ISNULL(OH.C_address3,'')  
            ,ISNULL(OH.C_address4,'')  
            ,ISNULL(OH.C_Country,'') + ',' + ISNULL(OH.C_State,'') + ',' + ISNULL(OH.C_Zip,'') --ISNULL(OH.C_address4,'')   --CS02
            ,ISNULL(OH.CountryOfOrigin,'')   --CS02
          --  ,ISNULL(OH.C_Zip,'')                    --CS01
            ,ISNULL(OH.userdefine02,'')
         --   ,ISNULL(OH.userdefine05,'')    --CS02
            ,ISNULL(S.susr4,'')--ISNULL(OD.userdefine01,'')   --CS02
            ,OH.InvoiceAmount --ISNULL(OH.userdefine10,'')   --CS02
            , (PD.Qty)  
            , ISNULL(C1.Long,'')         --CS02 S
            --,ISNULL(MAX(CASE WHEN C.Code ='A211' THEN RTRIM(C.long) ELSE '' END),'')  
            --,ISNULL(MAX(CASE WHEN C.Code ='A212' THEN RTRIM(C.long) ELSE '' END),'')  
            --,ISNULL(MAX(CASE WHEN C.Code ='A241' THEN RTRIM(C.long) ELSE '' END),'')  
            --,ISNULL(MAX(CASE WHEN C.Code ='A242' THEN RTRIM(C.long) ELSE '' END),'')  
            --,ISNULL(MAX(CASE WHEN C.Code ='A243' THEN RTRIM(C.long) ELSE '' END),'') 
            --,ISNULL(MAX(CASE WHEN C.Code ='A213' THEN RTRIM(C.long) ELSE '' END),'')  
            --,ISNULL(MAX(CASE WHEN C.Code ='A214' THEN RTRIM(C.long) ELSE '' END),'')  
            --,ISNULL(MAX(CASE WHEN C.Code ='A244' THEN RTRIM(C.long) ELSE '' END),'')    --CS01 E
      ORDER BY OD.SKU

  
      SELECT   recgroup
            ,  Orderkey              
            ,  Sku                   
            ,  Descr             
            ,  ExtOrderkey                 
            ,  Company                  
            ,  OrderDate             
            ,  ODUDF02           
            ,  ODUDF03                   
            ,  Salesman                                      
            ,  A2                   
            ,  A3                    
            ,  A4                   
            ,  A5                   
            ,  A6 
            ,  A7            
            ,  A8                   
            ,  A9                   
            ,  A10                   
            ,  A11 
            ,  A12            
            ,  A13
            ,  A14
            ,  Qty
            ,  QtyUnit
            ,  CAST(Qty as NVARCHAR(5)) + QtyUnit AS QtyWithPF    
            ,  A15
            ,  A17
            ,  A18
            ,  A19  
            ,  A20
            ,  C_Address1
            ,  C_Address2
            ,  c_address3
            ,  C_Address4
            ,  C_zip    
            ,  OHUDF02              
            ,  OHUDF05             
            ,  ODUDF01            
            ,  OHUDF10  
            ,  CurSymbol                       --CS02 S       
            ,  A211
            ,  A212
            ,  A241
            ,  A242
            ,  A243
            ,  A213 
            ,  A214 
            ,  A244    
            ,  A22
            ,  A25 --CS01 E                                                                                                                                
      FROM #TMP_INVDET09RDT T_INV
      Order BY SKU
  
      --DROP TABLE #TMP_INVDET09RDT       --WZ01

    

      GOTO QUIT
  
   QUIT:
   IF OBJECT_ID('tempdb..#TMP_INVDET09RDT') IS NOT NULL    
      DROP TABLE #TMP_RDTNOTE09RDT                             --WZ01

END

GO