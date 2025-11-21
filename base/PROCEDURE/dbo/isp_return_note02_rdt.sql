SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Function:   isp_Return_Note02_rdt                                    */
/* Creation Date: 01-FEB-2021                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:                                                             */
/*        : WMS-16030 - KR_iiCombined_Invoice Report_KR_Data Window     */
/*                                                                      */
/* Called By:  r_dw_Return_Note02_rdt                                   */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[isp_Return_Note02_rdt]  (
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

 

   CREATE TABLE #TMP_RDTNOTE02RDT 
            (  SeqNo                INT IDENTITY (1,1)
            ,  RecGroup             INT 
            ,  Orderkey             NVARCHAR(10)
            ,  Sku                  NVARCHAR(20)
            ,  Descr                NVARCHAR(250)
            ,  ExtOrderkey          NVARCHAR(50)
            ,  Company              NVARCHAR(45)
            ,  OrderDate            DATETIME
            --,  ODUDF02              NVARCHAR(20)
            --,  ODUDF03              NVARCHAR(20)
            --,  Salesman             NVARCHAR(45) 
            ,  A2                   NVARCHAR(250)    
            ,  A3                   NVARCHAR(250)    
            ,  A4                   NVARCHAR(250) 
            ,  A5                   NVARCHAR(250)                
            ,  A6                   NVARCHAR(250)     
            ,  A7                   NVARCHAR(250)    
            ,  A8                   NVARCHAR(250)                
            ,  A9                   NVARCHAR(250)     
            --,  A10                  NVARCHAR(250)     
            --,  A11                  NVARCHAR(250)    
            --,  A12                  NVARCHAR(250)    
            --,  A13                  NVARCHAR(250) 
            --,  A16                  NVARCHAR(250)
            ,  Qty                  INT            
            ,  QtyUnit              NVARCHAR(5)  
            )

      INSERT INTO  #TMP_RDTNOTE02RDT 
            (  recgroup
            ,  Orderkey              
            ,  Sku                   
            ,  Descr             
            ,  ExtOrderkey                 
            ,  Company                  
            ,  OrderDate             
            --,  ODUDF02           
            --,  ODUDF03                   
            --,  Salesman                                      
            ,  A2                   
            ,  A3                    
            ,  A4                   
            ,  A5                   
            ,  A6 
            ,  A7            
            ,  A8                   
            ,  A9                   
            --,  A10                   
            --,  A11 
            --,  A12            
            --,  A13
            --,  A16
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
            --,ISNULL(OD.userdefine02,'')
            --,ISNULL(OD.userdefine03,'')
            --,OH.Salesman
            ,A2=ISNULL(MAX(CASE WHEN C.Code ='A2' THEN RTRIM(C.long) ELSE '' END),'')
            ,A3=ISNULL(MAX(CASE WHEN C.Code ='A3' THEN RTRIM(C.long) ELSE '' END),'')
            ,A4=ISNULL(MAX(CASE WHEN C.Code ='A4' THEN RTRIM(C.long) ELSE '' END),'')
            ,A5=ISNULL(MAX(CASE WHEN C.Code ='A5' THEN RTRIM(C.long) ELSE '' END),'')
            ,A6=ISNULL(MAX(CASE WHEN C.Code ='A6' THEN RTRIM(C.long) ELSE '' END),'')                  
            ,A7=ISNULL(MAX(CASE WHEN C.Code ='A7' THEN RTRIM(C.long) ELSE '' END),'')               
            ,A8=ISNULL(MAX(CASE WHEN C.Code ='A8' THEN RTRIM(C.long) ELSE '' END),'')
            ,A9=ISNULL(MAX(CASE WHEN C.Code ='A9' THEN RTRIM(C.long) ELSE '' END),'')
            --,A10=ISNULL(MAX(CASE WHEN C.Code ='A10' THEN RTRIM(C.long) ELSE '' END),'') 
            --,A11=ISNULL(MAX(CASE WHEN C.Code ='A11' THEN RTRIM(C.long) ELSE '' END),'')  
            --,A12=ISNULL(MAX(CASE WHEN C.Code ='A12' THEN RTRIM(C.long) ELSE '' END),'')  
            --,A13=ISNULL(MAX(CASE WHEN C.Code ='A13' THEN RTRIM(C.long) ELSE '' END),'')  
            --,A10=ISNULL(MAX(CASE WHEN C.Code ='A16' THEN RTRIM(C.long) ELSE '' END),'')    
            , (PD.Qty)        
            ,' X' 
      FROM ORDERDETAIL OD  WITH (NOLOCK)
      JOIN ORDERS      OH  WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey)
      JOIN SKU S WITH (NOLOCK) ON s.storerkey = OD.storerkey AND S.sku = OD.sku
      JOIN PICKDETAIL PD (NOLOCK) ON (PD.ORDERKEY = OD.ORDERKEY AND PD.SKU = OD.SKU AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER) 
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'RTNKRCONST' AND C.UDF01 = @c_C_ISOCntryCode AND C.UDF02 = @c_Facility AND C.storerkey = OH.Storerkey
      WHERE OH.Orderkey = @c_Orderkey 
      AND OH.C_ISOCntryCode = @c_C_ISOCntryCode
      AND OH.Facility = @c_Facility
      GROUP BY OD.Orderkey
            ,OD.Sku
            --,ISNULL(OD.userdefine02,'') 
            --,ISNULL(OD.userdefine03,'')
            ,ISNULL(S.descr,'')
            ,OH.Externorderkey
            ,left(OH.C_Company,1)+'*'+right(OH.C_Company,1)
            ,OH.OrderDate
          --  ,OH.Salesman
            , (PD.Qty) 
      ORDER BY OD.SKU

  
      SELECT   recgroup
            ,  Orderkey              
            ,  Sku                   
            ,  Descr             
            ,  ExtOrderkey                 
            ,  Company                  
            ,  OrderDate             
            --,  ODUDF02           
            --,  ODUDF03                   
            --,  Salesman                                      
            ,  A2                   
            ,  A3                    
            ,  A4                   
            ,  A5                   
            ,  A6 
            ,  A7            
            ,  A8                   
            ,  A9                   
            --,  A10                   
            --,  A11 
            --,  A12            
            --,  A13
            --,  A16
            ,  Qty
            ,  QtyUnit
            ,  CAST(Qty as NVARCHAR(5)) + QtyUnit AS QtyWithPF                                                                                                                                              
      FROM #TMP_RDTNOTE02RDT T_INV
      Order BY SKU
  
      DROP TABLE #TMP_RDTNOTE02RDT

    

      GOTO QUIT
  
   QUIT:
END

GO