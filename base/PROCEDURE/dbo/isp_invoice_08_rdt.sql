SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Function:   isp_invoice_08_rdt                                       */  
/* Creation Date: 29-Jan-2021                                           */  
/* Copyright: IDS                                                       */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:                                                             */  
/*        : WMS-16030 - KR_iiCombined_Invoice Report_KR_Data Window     */  
/*                                                                      */  
/* Called By:  r_dw_invoice_08_rdt                                      */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 10-Mar-2021   WLChooi   1.1   WMS-16030 - Modify Logic (WL01)        */
/* 10-Mar-2021   WLChooi   1.1   DevOps Combine Script                  */
/************************************************************************/  
  
CREATE   PROC [dbo].[isp_invoice_08_rdt] (  
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
         , @c_Country            NVARCHAR(10)
         , @c_Storerkey          NVARCHAR(15)  
         
   DECLARE  @n_MaxLineno       INT
          , @n_MaxId           INT
			 , @n_MaxRec          INT
          , @n_CurrentRec      INT
  
   SET @n_MaxLineno = 25
   
   SELECT @c_Storerkey = Storerkey
   FROM ORDERS (NOLOCK)
   WHERE OrderKey = @c_Orderkey
  
   DECLARE @c_A2  NVARCHAR(250) = ''
         , @c_A3  NVARCHAR(250) = ''
         , @c_A4  NVARCHAR(250) = ''
         , @c_A5  NVARCHAR(250) = ''
         , @c_A6  NVARCHAR(250) = ''
         , @c_A7  NVARCHAR(250) = ''
         , @c_A8  NVARCHAR(250) = ''
         , @c_A9  NVARCHAR(250) = ''
         , @c_A10 NVARCHAR(250) = ''
         , @c_A11 NVARCHAR(250) = ''
         , @c_A12 NVARCHAR(250) = ''
         , @c_A13 NVARCHAR(250) = ''
         , @c_A16 NVARCHAR(250) = ''
   
   SELECT @c_A2  = ISNULL(MAX(CASE WHEN C.Code ='A2'  THEN RTRIM(C.long) ELSE '' END),'') 
        , @c_A3  = ISNULL(MAX(CASE WHEN C.Code ='A3'  THEN RTRIM(C.long) ELSE '' END),'') 
        , @c_A4  = ISNULL(MAX(CASE WHEN C.Code ='A4'  THEN RTRIM(C.long) ELSE '' END),'') 
        , @c_A5  = ISNULL(MAX(CASE WHEN C.Code ='A5'  THEN RTRIM(C.long) ELSE '' END),'') 
        , @c_A6  = ISNULL(MAX(CASE WHEN C.Code ='A6'  THEN RTRIM(C.long) ELSE '' END),'')  
        , @c_A7  = ISNULL(MAX(CASE WHEN C.Code ='A7'  THEN RTRIM(C.long) ELSE '' END),'')  
        , @c_A8  = ISNULL(MAX(CASE WHEN C.Code ='A8'  THEN RTRIM(C.long) ELSE '' END),'') 
        , @c_A9  = ISNULL(MAX(CASE WHEN C.Code ='A9'  THEN RTRIM(C.long) ELSE '' END),'') 
        , @c_A10 = ISNULL(MAX(CASE WHEN C.Code ='A10' THEN RTRIM(C.long) ELSE '' END),'')
        , @c_A11 = ISNULL(MAX(CASE WHEN C.Code ='A11' THEN RTRIM(C.long) ELSE '' END),'')
        , @c_A12 = ISNULL(MAX(CASE WHEN C.Code ='A12' THEN RTRIM(C.long) ELSE '' END),'')
        , @c_A13 = ISNULL(MAX(CASE WHEN C.Code ='A13' THEN RTRIM(C.long) ELSE '' END),'')
        , @c_A16 = ISNULL(MAX(CASE WHEN C.Code ='A16' THEN RTRIM(C.long) ELSE '' END),'')
   FROM CODELKUP C WITH (NOLOCK) 
   WHERE C.listname = 'DNKRCONST' 
   AND C.UDF01 = @c_C_ISOCntryCode 
   AND C.UDF02 = @c_Facility 
   AND C.storerkey = @c_Storerkey 
  
   CREATE TABLE #TMP_INVDET08RDT   
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
            ,  A16                  NVARCHAR(250)  
            ,  Qty                  INT              
            ,  QtyUnit              NVARCHAR(5)    
            )  
  
      INSERT INTO  #TMP_INVDET08RDT   
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
            ,  A16  
            ,  Qty  
            ,  QtyUnit                       
            )  
      SELECT 1 as recgroup  
            ,OD.Orderkey  
            ,OD.Sku  
            ,Descr =  ISNULL(S.descr,'')  
            ,ExtOrderkey     = OH.Externorderkey  
            ,Company         = left(OH.C_Company,1)+'*'+right(OH.C_Company,1)  
  
            ,OH.OrderDate  
            --WL01 S
            --,ISNULL(OD.userdefine02,'')   
            ,CASE WHEN LEFT(LTRIM(RTRIM(ISNULL(OD.userdefine02,''))), 1) = '\' 
                  THEN N'₩' + SUBSTRING(ISNULL(OD.userdefine02,''), 2, LEN(ISNULL(OD.userdefine02,'')) - 1)
                  ELSE ISNULL(OD.userdefine02,'') END
            --,ISNULL(OD.userdefine03,'')  
            ,CASE WHEN LEFT(LTRIM(RTRIM(ISNULL(OD.userdefine03,''))), 1) = '\' 
                  THEN N'₩' + SUBSTRING(ISNULL(OD.userdefine03,''), 2, LEN(ISNULL(OD.userdefine03,'')) - 1)
                  ELSE ISNULL(OD.userdefine03,'') END
            --,OH.Salesman  
            ,CASE WHEN LEFT(LTRIM(RTRIM(ISNULL(OH.Salesman,''))), 1) = '\' 
                  THEN N'₩' + SUBSTRING(ISNULL(OH.Salesman,''), 2, LEN(ISNULL(OH.Salesman,'')) - 1)
                  ELSE ISNULL(OH.Salesman,'') END
            --WL01 E
            ,A2 =  @c_A2 
            ,A3 =  @c_A3 
            ,A4 =  @c_A4 
            ,A5 =  @c_A5 
            ,A6 =  @c_A6                   
            ,A7 =  @c_A7                
            ,A8 =  @c_A8 
            ,A9 =  @c_A9 
            ,A10 = @c_A10  
            ,A11 = @c_A11   
            ,A12 = @c_A12   
            ,A13 = @c_A13   
            ,A16 = @c_A16     
            ,SUM(PD.Qty)          
            ,' X'   
      FROM ORDERDETAIL OD  WITH (NOLOCK)  
      JOIN ORDERS      OH  WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey)  
      JOIN SKU S WITH (NOLOCK) ON s.storerkey = OD.storerkey AND S.sku = OD.sku  
      JOIN PICKDETAIL PD (NOLOCK) ON (PD.ORDERKEY = OD.ORDERKEY AND PD.SKU = OD.SKU AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER)   
      --LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'DNKRCONST' AND C.UDF01 = @c_C_ISOCntryCode AND C.UDF02 = @c_Facility AND C.storerkey = OH.Storerkey  
      WHERE OH.Orderkey = @c_Orderkey   
      AND OH.C_ISOCntryCode = @c_C_ISOCntryCode  
      AND OH.Facility = @c_Facility  
      GROUP BY OD.Orderkey  
            ,OD.Sku  
            ,ISNULL(OD.userdefine02,'')   
            ,ISNULL(OD.userdefine03,'')  
            ,ISNULL(S.descr,'')  
            ,OH.Externorderkey  
            ,left(OH.C_Company,1)+'*'+right(OH.C_Company,1)  
            ,OH.OrderDate  
            ,ISNULL(OH.Salesman,'')   --WL01
            , (PD.Qty)        
      ORDER BY OD.SKU  

   --WL01 Comment - S
   --SELECT @n_MaxRec = COUNT(1) FROM #TMP_INVDET08RDT

   --SET @n_CurrentRec = @n_MaxRec % @n_MaxLineno

   --WHILE(@n_MaxRec % @n_MaxLineno <> 0 AND @n_CurrentRec < @n_MaxLineno)
   --BEGIN
   --	INSERT INTO  #TMP_INVDET08RDT   
   --         (  recgroup  
   --         ,  Orderkey                
   --         ,  Sku                     
   --         ,  Descr               
   --         ,  ExtOrderkey                   
   --         ,  Company                    
   --         ,  OrderDate               
   --         ,  ODUDF02             
   --         ,  ODUDF03                     
   --         ,  Salesman                                        
   --         ,  A2                     
   --         ,  A3                      
   --         ,  A4                     
   --         ,  A5                     
   --         ,  A6   
   --         ,  A7              
   --         ,  A8                     
   --         ,  A9                     
   --         ,  A10                     
   --         ,  A11   
   --         ,  A12              
   --         ,  A13  
   --         ,  A16  
   --         ,  Qty  
   --         ,  QtyUnit                       
   --         ) 
   --   SELECT TOP 1 recgroup  
   --         ,  Orderkey                
   --         ,  NULL                     
   --         ,  NULL               
   --         ,  ExtOrderkey                   
   --         ,  Company                    
   --         ,  OrderDate               
   --         ,  NULL             
   --         ,  NULL                     
   --         ,  Salesman                                        
   --         ,  A2                     
   --         ,  A3                      
   --         ,  A4                     
   --         ,  A5                     
   --         ,  A6   
   --         ,  A7              
   --         ,  A8                     
   --         ,  A9                     
   --         ,  A10                     
   --         ,  A11   
   --         ,  A12              
   --         ,  A13  
   --         ,  A16  
   --         ,  NULL  
   --         ,  NULL                                                                                                          
   --   FROM #TMP_INVDET08RDT T_INV  
   --   Order BY SKU  
    
   --   SET @n_CurrentRec = @n_CurrentRec + 1
   --END
   --WL01 Comment - E
    
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
         ,  A16  
         ,  Qty  
         ,  QtyUnit  
         ,  CAST(Qty as NVARCHAR(5)) + QtyUnit AS QtyWithPF                                                                                                             
   FROM #TMP_INVDET08RDT T_INV  
   Order BY CASE WHEN SKU <> '' THEN 1 ELSE 2 END
    
   DROP TABLE #TMP_INVDET08RDT  
  
      
  
      GOTO QUIT  
    
   QUIT:  
END  

GO