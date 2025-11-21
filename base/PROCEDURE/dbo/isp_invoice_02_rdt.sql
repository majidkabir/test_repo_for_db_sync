SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/************************************************************************/  
/* Stored Procedure: isp_invoice_02                                     */  
/* Creation Date: 2015-09-28                                            */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: SOS#353027 - HK Ecom Invoice Report                         */  
/*                                                                      */  
/* Called By: r_dw_invoice_02_rdt                                       */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver   Purposes                                  */  
/* 27-Nov-2015  CSCHONG 1.0   Add in link to storerkey for sku (CS01)   */
/* 19-Feb-2016  CSCHONG 1.1   SOS#363721 - Add new field (CS02)         */
/* 15-Aug-2016  CSCHONg 1.2   SOS#375079 - Add report config (CS03)     */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_invoice_02_rdt]
         (  @c_Orderkey    NVARCHAR(10) = ''     
         ,  @c_labelno     NVARCHAR(20) = ''  
         )             
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_NoOfLine  INT  
         , @n_TotDetail INT  
         , @n_LineNeed  INT  
         , @n_SerialNo  INT  
         , @b_debug     INT  
  
  DECLARE @c_ordkey NVARCHAR(10)  
        ,@c_GPickslipno NVARCHAR(10)  
        ,@n_GetCartonno INT  
        ,@n_CartonNo1 INT  
        ,@n_cartonqty INT  
        ,@n_MaxRecGrp INT  
        ,@n_CntRec    INT  
        ,@n_CarrierCharges Float
        ,@n_OtherCharges   Float
        ,@n_InvoiceAmt     Float
  
     
   SET @n_NoOfLine = 30  
   SET @n_TotDetail= 0  
   SET @n_LineNeed = 0  
   SET @n_SerialNo = 0  
   SET @b_debug    = 0  
   SET @n_CntRec   = 1  
   SET @n_MaxRecGrp =1 
   SET @n_CarrierCharges = 0
   SET @n_OtherCharges   = 0
   SET @n_InvoiceAmt     = 0  
  
  
   SET @n_cartonqty=0  
       
      CREATE TABLE #TMP_PICKHDR  
            (  SeqNo         INT  IDENTITY(1,1) NOT NULL     
            ,  OrderKey      NVARCHAR(10)       
            ,  Orderdate     NVARCHAR(10)  
            ,  EcomORDID     NVARCHAR(45)  
            ,  C_Company     NVARCHAR(45)  
            ,  C_Address1    NVARCHAR(45)     
            ,  C_Address2    NVARCHAR(45)  
            ,  C_Address3    NVARCHAR(45)  
            ,  L1            NVARCHAR(4000)       
            ,  L2            NVARCHAR(4000)      
            ,  L3            NVARCHAR(4000)      
            ,  L4            NVARCHAR(4000)      
            ,  L5            NVARCHAR(4000)      
            ,  L6            NVARCHAR(4000)   
            ,  ItemDescr     NVARCHAR(400)  
            ,  AltSku        NVARCHAR(20)  
            ,  ORDFacility   NVARCHAR(5)  
            ,  PQTY          INT  
            ,  PriceUnit     FLOAT      
            ,  RecGroup      INT  
            ,  Show          CHAR(1)  
            ,  CarrierCharges Float              --(CS02)
            ,  OtherCharges   Float              --(CS02)
            ,  InvoiceAmount  Float              --(CS02)
            ,  ShowField      CHAR(1)            --(CS03)
            )  
  
      INSERT INTO #TMP_PICKHDR  
            (  OrderKey           
            ,  Orderdate       
            ,  EcomORDID       
            ,  C_Company       
            ,  C_Address1      
            ,  C_Address2      
            ,  C_Address3      
            ,  L1                 
            ,  L2                  
            ,  L3                 
            ,  L4                  
            ,  L5                 
            ,  L6     
            ,  ItemDescr           
            ,  AltSku             
            ,  ORDFacility        
            ,  PQTY               
            ,  PriceUnit                       
            ,  RecGroup   
            ,  show  
            ,  CarrierCharges                    --(CS02)
            ,  OtherCharges                      --(CS02)
            ,  InvoiceAmount                     --(CS02)
            ,  ShowField                         --(CS03)
            )  
      SELECT DISTINCT @c_orderkey,CONVERT(NVARCHAR(10),orderdate,112) AS OrderDate,ISNULL(OI.EcomOrderID,''),  
               ISNULL(C_Company,''),RTRIM(ISNULL(ORD.C_Address1,'')),RTRIM(ISNULL(ORD.C_Address2,'')),RTRIM(ISNULL(ORD.C_Address3,'')),  
               C.long,ISNULL(c.UDF01,''),ISNULL(c.UDF02,''),ISNULL(c.UDF03,''),ISNULL(c.UDF04,''),  
               ISNULL(c.UDF05,''),CASE WHEN IsNull(S.Notes1,'') = '' THEN S.Descr ELSE S.Notes1 END AS ItemDescr,  
               S.SKU,ORD.Facility  
               ,Sum(PICKDET.Qty) as PQty,ORDDET.Unitprice,  
              (Row_Number() OVER (PARTITION BY ORD.Orderkey ORDER BY ORD.Orderkey Asc))/@n_NoOfLine + 1,'Y'  
               ,0,0,0--,ISNULL(CarrierCharges,0),ISNULL(OtherCharges,0),ISNULL(InvoiceAmount,0)                                        --(CS02)
               ,CASE WHEN ISNULL(CLR.Code,'') = '' THEN 'Y' ELSE 'N' END AS ShowField                                                --(CS03)
               FROM ORDERS ORD WITH (NOLOCK)  
               JOIN OrderDetail ORDDET WITH (NOLOCK) ON ORDDET.Orderkey=ORD.Orderkey  
               FULL OUTER JOIN ORDERINFO OI WITH (NOLOCK) ON OI.Orderkey=ORD.Orderkey   
               JOIN PICKDETAIL PICKDET WITH (NOLOCK) ON PICKDET.Orderkey=ORD.Orderkey   
                        AND ORDDET.OrderLineNumber = PICKDET.OrderLineNumber  
               JOIN SKU S WITH (NOLOCK) ON S.SKU = ORDDET.SKU AND S.Storerkey =ORDDET.Storerkey      --(CS01) 
               FULL OUTER JOIN Codelkup C WITH (NOLOCK) ON C.listname = 'EGL_INV' AND c.code = 'SALESMSG'  
               LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (Ord.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'                          --(CS03)
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_invoice_02_rdt' AND ISNULL(CLR.Short,'') <> 'Y')   --(CS03)  
               WHERE ORD.Orderkey = @c_Orderkey  
               AND ORD.status >='2'   
               GROUP BY CONVERT(NVARCHAR(10),orderdate,112),OI.EcomOrderID,  
               ISNULL(C_Company,''),RTRIM(ISNULL(ORD.C_Address1,'')),RTRIM(ISNULL(ORD.C_Address2,'')),RTRIM(ISNULL(ORD.C_Address3,'')),  
               C.long,ISNULL(c.UDF01,''),ISNULL(c.UDF02,''),ISNULL(c.UDF03,''),ISNULL(c.UDF04,''),  
               ISNULL(c.UDF05,''),ORD.Orderkey,CASE WHEN IsNull(S.Notes1,'') = '' THEN S.Descr ELSE S.Notes1 END  
              ,S.SKU,ORD.Facility,ORDDET.Unitprice ,CASE WHEN ISNULL(CLR.Code,'') = '' THEN 'Y' ELSE 'N' END     --(CS03)
--              ,  CarrierCharges                    --(CS02)
--              ,  OtherCharges                      --(CS02) 
--              ,  InvoiceAmount                     --(CS02)
                 
  
  
  
IF @b_debug = 1  
BEGIN  
   INSERT INTO TRACEINFO (TraceName, timeIn, Step1, Step2, step3, step4, step5)  
   VALUES ('isp_invoice_02', getdate(), @c_orderkey, '', '', '', suser_name())  
END  


      SELECT     @n_CarrierCharges = OI.CarrierCharges
                ,@n_OtherCharges   = OI.OtherCharges
                ,@n_InvoiceAmt     = ORD.InvoiceAmount
      FROM ORDERS ORD WITH (NOLOCK)
      JOIN ORDERINFO OI WITH (NOLOCK) ON OI.Orderkey = ORD.Orderkey
      WHERE ORD.ORDERKEY = @c_Orderkey 

      UPDATE #TMP_PICKHDR
      SET CarrierCharges = @n_CarrierCharges
          ,OtherCharges=@n_OtherCharges
          ,InvoiceAmount=@n_InvoiceAmt
      Where orderkey = @c_Orderkey
      AND seqno =1


      SELECT @n_MaxRecGrp= MAX(recGroup)  
      FROM #TMP_PICKHDR  
        
  
      SELECT @n_CntRec = COUNT(1)  
      FROM #TMP_PICKHDR  
      WHERE RECGroup = @n_MaxRecGrp  
  
      WHILE @n_CntRec < @n_NoOfLine  
      BEGIN  
         INSERT INTO #TMP_PICKHDR  
            (  OrderKey           
            ,  Orderdate       
            ,  EcomORDID       
            ,  C_Company       
            ,  C_Address1      
            ,  C_Address2      
            ,  C_Address3      
            ,  L1                 
            ,  L2                  
            ,  L3                 
            ,  L4                  
            ,  L5                 
            ,  L6     
            ,  ItemDescr           
            ,  AltSku             
            ,  ORDFacility        
            ,  PQTY               
            ,  PriceUnit                       
            ,  RecGroup   
            ,  Show 
            ,  CarrierCharges                    --(CS02)
            ,  OtherCharges                      --(CS02)  
            ,  InvoiceAmount                     --(CS02)     
            ,  ShowField                         --(CS03)                                                            
            )  
          SELECT OrderKey           
            ,  ''       
            ,  ''       
            ,  ''       
            ,  ''      
            ,  ''      
            ,  ''      
            ,  L1                 
            ,  L2                  
            ,  L3                 
            ,  L4                  
            ,  L5                 
            ,  L6     
            ,  ''           
            ,  ''             
            ,  ''        
            ,  ''               
            ,  ''                       
            , @n_MaxRecGrp   
            , 'N'  
            ,  0                    --(CS02)
            ,  0                    --(CS02)
            ,  0                    --(CS02)
            , ShowField             --(CS03)
        FROM #TMP_PICKHDR  
        WHERE SeqNo = @n_CntRec  
  
      SET @n_CntRec = @n_CntRec + 1  
  
      END  
  
      SELECT OrderKey           
            ,  Orderdate       
            ,  EcomORDID       
            ,  C_Company       
            ,  C_Address1      
            ,  C_Address2      
            ,  C_Address3      
            ,  L1                 
            ,  L2                  
            ,  L3                 
            ,  L4                  
            ,  L5           
            ,  L6   
            ,  ItemDescr           
            ,  AltSku             
            ,  ORDFacility        
            ,  PQTY             
            ,  PriceUnit                      
            ,  RecGroup    
            ,  Show  
            ,  seqno  
            ,  CarrierCharges                    --(CS02)
            ,  OtherCharges                      --(CS02)
            ,  InvoiceAmount                     --(CS02)
            ,  ShowField                         --(CS03)      
      FROM #TMP_PICKHDR  
      ORDER BY SeqNo    
        
      DROP TABLE #TMP_PICKHDR  
      GOTO QUIT_SP  
       
   QUIT_SP:  
END         
   

GO