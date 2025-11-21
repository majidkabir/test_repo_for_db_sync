SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_packing_list2_ecco                             */  
/* Creation Date: 18-Dec-2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose:  SOS#295593- QKS packing list                               */  
/*                                                                      */  
/* Called By:  WMS - r_dw_packing_list2_ecco                            */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 28-Jan-2019  TLTING_ext 1.0  enlarge externorderkey field length      */
/************************************************************************/  
CREATE PROC [dbo].[isp_packing_list2_ecco] (  
            @c_OrderKeyStart     NVARCHAR(10)  
          , @c_OrderKeyEnd       NVARCHAR(10)
          , @c_ExternOrderStart  NVARCHAR(30)  
          , @c_ExternOrderEnd    NVARCHAR(30)
          , @c_StorerKeyStart    NVARCHAR(15)  
          , @c_StorerKeyEnd      NVARCHAR(15)
         )  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_WARNINGS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @b_debug INT  
   SET @b_debug = 0  
/*********************************************/  
/* Variables Declaration (Start)             */  
/*********************************************/
   DECLARE @n_StyleColorSizeMeas INT

   DECLARE @c_ReportTitle        NVARCHAR(255)
         , @c_OrderKey           NVARCHAR(10)
         , @c_Storerkey          NVARCHAR(15)
         , @c_Status             NVARCHAR(10)

   -- Variables Initialization 
   SET @n_StyleColorSizeMeas  = 0 
   SET @c_ReportTitle = 'Packing List per Repeat Order'
   SET @c_OrderKey    = ''
   SET @c_Storerkey   = ''
   SET @c_Status      = ''
/*********************************************/  
/* Variables Declaration (End)               */  
/*********************************************/ 

   CREATE TABLE #TMP_PACKLIST
         (  StorerKey         NVARCHAR(15)   NULL
         ,  ExternOrderKey    NVARCHAR(50)   NULL   --tlting_ext
         ,  InvoiceNo         NVARCHAR(20)   NULL
         ,  Orderkey          NVARCHAR(10)   NULL 
         ,  C_Company         NVARCHAR(45)   NULL      
         ,  C_Address1        NVARCHAR(45)   NULL   
         ,  C_Address2        NVARCHAR(45)   NULL 
         ,  Notes             NVARCHAR(100)  NULL   
         ,  Adddate           DATETIME       NULL   
         ,  CartonNo          INT            NULL
         ,  CartonCnt         INT            NULL   
         ,  Price             FLOAT          NULL  
         ,  Descr             NVARCHAR(60)   NULL
         ,  Company           NVARCHAR(45)   NULL 
         ,  Qty               INT            NULL
         ,  Material          NVARCHAR(255)  NULL 
         ,  Quality           NVARCHAR(255)  NULL 
         ,  Size              NVARCHAR(255)  NULL        
         ,  sUser             NVARCHAR(40)   NULL 
         ,  ReportTitle       NVARCHAR(255)  NULL 
         )  

/*********************************************/  
/* Validation (Start)                        */  
/*********************************************/ 
   DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT 
          Orderkey
         ,Storerkey
   FROM ORDERS WITH (NOLOCK)
   WHERE ORDERS.OrderKey     BETWEEN @c_OrderKeyStart    AND @c_OrderKeyEnd
   AND ORDERS.ExternOrderKey BETWEEN @c_ExternOrderStart AND @c_ExternOrderEnd
   AND ORDERS.StorerKey      BETWEEN @c_StorerKeyStart   AND @c_StorerKeyEnd    
   ORDER BY Orderkey

   OPEN CUR_ORD    
  
   FETCH NEXT FROM CUR_ORD INTO  @c_OrderKey   
                              ,  @c_Storerkey 
   WHILE @@FETCH_STATUS <> -1    
   BEGIN
      SELECT @c_ReportTitle = MAX(CASE WHEN Code = 'ReportTitle' 
                                       THEN Convert(NVARCHAR(255), Notes) ELSE '' END)
            ,@n_StyleColorSizeMeas = MAX(CASE WHEN Code = 'StyleColorSizeMeas'
                                       THEN 1 ELSE 0 END)
            ,@c_Status      = MAX(CASE WHEN Code = 'InProcessStatus'
                                       THEN '3' ELSE '' END) 
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = 'REPORTCFG'
      AND   Storerkey= @c_Storerkey
      AND   Long = 'r_dw_packing_list2_ecco' 
      AND   ISNULL(RTRIM(Short), '') <> 'N' 

      IF ISNULL(RTRIM(@c_ReportTitle),'') = ''
      BEGIN
         SET @c_ReportTitle = 'Packing List per Repeat Order'
      END

      IF ISNULL(RTRIM(@c_Status),'') = ''
      BEGIN
         SET @c_Status = ''
      END

      INSERT INTO #TMP_PACKLIST                                                            
         (                                                                               
            StorerKey                                                                    
         ,  ExternOrderKey                                                               
         ,  InvoiceNo                                                                    
         ,  Orderkey                                                                     
         ,  C_Company                                                                    
         ,  C_Address1                                                                   
         ,  C_Address2                                                                   
         ,  Notes                                                                        
         ,  Adddate                                                                      
         ,  CartonNo                                                                     
         ,  CartonCnt                                                                    
         ,  Price                                                                        
         ,  Descr                                                                        
         ,  Company                                                                      
         ,  Qty                                                                          
         ,  Material                                                                     
         ,  Quality                                                                      
         ,  Size                                                                         
         ,  sUser                                                                        
         ,  ReportTitle                                                                  
         )                                                                               
      SELECT ORDERS.StorerKey                                                            
         ,  ORDERS.ExternOrderKey                                                        
         ,  ORDERS.InvoiceNo                                                             
         ,  ORDERS.OrderKey                                                              
         ,  ORDERS.C_Company                                                             
         ,  ORDERS.C_Address1                                                            
         ,  ORDERS.C_Address2                                                            
         ,  ISNULL(CONVERT(NVARCHAR(50), ORDERS.Notes), '') AS Notes                     
         ,  MIN(PACKHEADER.AddDate) AS AddDate                                           
         ,  PACKDETAIL.CartonNo                                                          
         ,  TOTCTN.CartonCnt                                                             
         ,  Sku.Price                                                                    
         ,  Sku.Descr                                                                    
         ,  STORER.company                                                               
         ,  SUM(PACKDETAIL.Qty) AS Qty 
         ,  CASE WHEN @n_StyleColorSizeMeas = 1 AND 
                      LEN(ISNULL(RTRIM(Sku.Style),'') +
                          ISNULL(RTRIM(Sku.Color),'') +
                          ISNULL(RTRIM(Sku.Size),'')  +
                          ISNULL(RTRIM(Sku.Measurement),'')) > 0
                 THEN ISNULL(RTRIM(Sku.Style),'') + '-' +
                      ISNULL(RTRIM(Sku.Color),'') + '-' +
                      ISNULL(RTRIM(Sku.Size),'')  + '-' + 
                      ISNULL(RTRIM(Sku.Measurement),'')  
                 ELSE ISNULL( REPLACE( ltrim(Left(SKU.SKU, 14)), '-', ''), '' ) 
                 END As Material        
         ,  ISNULL( REPLACE( rtrim(Right(Left(SKU.SKU, 15), 1)), '-', ''), '') AS Quality
         ,  ISNULL( REPLACE( rtrim(Right(SKU.SKU,5)), '-', '') ,'') As Size              
         ,  CONVERT(NVARCHAR(20), (user_name())) As sUser                                
         ,  @c_ReportTitle                                                               
      FROM ORDERS WITH (NOLOCK)                                                           
      JOIN PACKHEADER WITH (NOLOCK) ON ORDERS.OrderKey = PACKHEADER.OrderKey                  
      JOIN PACKDETAIL WITH (NOLOCK) ON PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo          
      JOIN SKU        WITH (NOLOCK) ON SKU.SKU = PACKDETAIL.SKU AND SKU.Storerkey = ORDERS.Storerkey 
      JOIN STORER     WITH (NOLOCK) ON STORER.Storerkey = ORDERS.Storerkey                        
      JOIN (SELECT OrderKey, COUNT(DISTINCT CartonNo) as CartonCnt                       
            FROM PACKHEADER PH WITH (NOLOCK)                                                  
            JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNO                 
            WHERE  PH.OrderKey = @c_OrderKey                                             
            GROUP BY PH.OrderKey) AS TOTCTN                                              
      ON PACKHEADER.OrderKey = TOTCTN.OrderKey                                           
      WHERE ORDERS.OrderKey = @c_Orderkey 
      AND ORDERS.Status = CASE WHEN @c_Status = '' THEN ORDERS.Status ELSE @c_Status END                                         
      GROUP BY ORDERS.StorerKey                                                         
             , ORDERS.ExternOrderKey                                                    
             , ORDERS.InvoiceNo                                                        
             , ORDERS.OrderKey                                                         
             , ORDERS.C_Company                                                          
             , ORDERS.C_Address1                                                        
             , ORDERS.C_Address2                                                        
             , ISNULL(CONVERT(NVARCHAR(50), ORDERS.Notes), '')                          
             , PACKDETAIL.CartonNo                                                      
             , TOTCTN.CartonCnt                                                          
             , Sku.Price                                                                 
             , Sku.Descr                                                                
             , STORER.company                                                          
             , CASE WHEN @n_StyleColorSizeMeas = 1 AND 
                     LEN(ISNULL(RTRIM(Sku.Style),'') +
                          ISNULL(RTRIM(Sku.Color),'') +
                          ISNULL(RTRIM(Sku.Size),'')  +
                          ISNULL(RTRIM(Sku.Measurement),'')) > 0
                    THEN ISNULL(RTRIM(Sku.Style),'') + '-' +
                         ISNULL(RTRIM(Sku.Color),'') + '-' +
                         ISNULL(RTRIM(Sku.Size),'')  + '-' + 
                         ISNULL(RTRIM(Sku.Measurement),'')  
                    ELSE ISNULL( REPLACE( ltrim(Left(SKU.SKU, 14)), '-', ''), '' ) 
                    END               
             , ISNULL( REPLACE( rtrim(Right(Left(SKU.SKU, 15), 1)), '-', ''), '')       
             , ISNULL( REPLACE( rtrim(Right(SKU.SKU,5)), '-', '') ,'') 
                  
      FETCH NEXT FROM CUR_ORD INTO  @c_OrderKey   
                                 ,  @c_Storerkey 
   END
   CLOSE CUR_ORD
   DEALLOCATE CUR_ORD


   SELECT   StorerKey                                                                    
         ,  ExternOrderKey                                                               
         ,  InvoiceNo                                                                    
         ,  Orderkey                                                                     
         ,  C_Company                                                                    
         ,  C_Address1                                                                   
         ,  C_Address2                                                                   
         ,  Notes                                                                        
         ,  Adddate                                                                      
         ,  CartonNo                                                                     
         ,  CartonCnt                                                                    
         ,  Price                                                                        
         ,  Descr                                                                        
         ,  Company                                                                      
         ,  Qty                                                                          
         ,  Material                                                                     
         ,  Quality                                                                      
         ,  Size                                                                         
         ,  sUser                                                                        
         ,  ReportTitle
   FROM  #TMP_PACKLIST 
   ORDER BY Orderkey 
         ,  CartonNo
         ,  Material
         ,  Size      
END  
 

GO