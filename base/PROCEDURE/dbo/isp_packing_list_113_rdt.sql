SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/                    
/* Store Procedure: isp_Packing_List_113_rdt                                  */                    
/* Creation Date: 03-Sep-2021                                                 */                    
/* Copyright: IDS                                                             */                    
/* Written by: MINGLE                                                         */                    
/*                                                                            */                    
/* Purpose: WMS-17816 [CN] UA_ECOM PACKING LIST_CR                            */        
/*                                                                            */                    
/*                                                                            */                    
/* Called By:  r_dw_packing_list_113_rdt                                      */                    
/*                                                                            */                    
/* PVCS Version:                                                              */                    
/*                                                                            */                    
/* Version:                                                                   */                    
/*                                                                            */                    
/* Data Modifications:                                                        */                    
/*                                                                            */                    
/* Updates:                                                                   */                    
/* Date         Author    Ver.  Purposes                                      */ 
/* 07-Dec-2021  WLChooi   1.1   DevOps Combine Script                         */  
/* 07-Dec-2021  WLChooi   1.1   WMS-18534 - Remove Hardcoded Storerkey (WL01) */    
/******************************************************************************/           
        
CREATE PROC [dbo].[isp_Packing_List_113_rdt]                   
       (@c_Orderkey NVARCHAR(10),      
        @c_labelno  NVARCHAR(20))                    
AS                  
BEGIN                  
   SET NOCOUNT ON                  
   SET ANSI_WARNINGS OFF                  
   SET QUOTED_IDENTIFIER OFF                  
   SET CONCAT_NULL_YIELDS_NULL OFF          
        
   DECLARE @c_MCompany        NVARCHAR(45)        
         , @c_Externorderkey  NVARCHAR(50)       
         , @c_C_Addresses     NVARCHAR(200)         
         , @c_loadkey         NVARCHAR(10)        
         , @c_Userdef03       NVARCHAR(20)        
         , @c_salesman        NVARCHAR(30)        
         , @c_phone1          NVARCHAR(18)      
         , @c_contact1        NVARCHAR(30)        
        
         , @n_TTLQty          INT         
         , @c_shippername     NVARCHAR(45)        
         , @c_Sku             NVARCHAR(20)        
         , @c_Size            NVARCHAR(5)        
         , @c_PickLoc         NVARCHAR(10)       
         , @c_getOrdKey       NVARCHAR(10)       
         
         --For 2D barcode      
         ,@c_QRSTRING NVARCHAR(4000)      
         ,@C_APPKEY NVARCHAR(45)      
         ,@c_SignatureOut VARCHAR(4000)      
         ,@c_VB_ErrMsg NVARCHAR(4000)      
         ,@c_UrlOut NVARCHAR(4000)      
         ,@c_OHINVAmt NVARCHAR(100)      
         ,@c_OrdDate NVARCHAR(100)      
         ,@c_Cudf05 NVARCHAR(45)      
            
         --For BASE64 encoding      
         ,@c_OutputString NVARCHAR(4000)      
         ,@c_vbErrMsg   NVARCHAR(4000)      
         ,@c_UrlPrefix   NVARCHAR(4000)      
          
  
   DECLARE @c_UDF02          NVARCHAR(500) = ''  
         , @c_UDF01          NVARCHAR(500) = ''  
         , @c_Storerkey      NVARCHAR(15)  = ''  
         , @c_UserDefine03   NVARCHAR(50)  = ''  
          
   SET @c_getOrdKey = ''       
         
   IF LEFT(@c_Orderkey,1) = 'P'      
   BEGIN      
      /*SELECT @c_Orderkey = OrderKey         
      FROM PICKHEADER WITH (NOLOCK)         
WHERE PickHeaderKey = @c_Orderkey       
      */    
    
      IF EXISTS(    
         SELECT 1         
         FROM PACKHEADER WITH (NOLOCK)         
         WHERE Pickslipno = @c_Orderkey    
         )    
      BEGIN    
         SELECT @c_Orderkey = OrderKey         
         FROM PACKHEADER WITH (NOLOCK)         
         WHERE Pickslipno = @c_Orderkey    
      END                
      ELSE    
      BEGIN    
        INSERT INTO ERRLOG (Logdate, userid, errorid, module, errortext)    
        VALUES (GETDATE(), SUSER_SNAME(), 66666, 'PACKLIST20', RTRIM(@c_orderkey) + ' - Packheader not found when printing')    
        SET @c_Orderkey = ''           
      END      
   END              
        
   CREATE TABLE #PACKLIST20        
         ( c_company       NVARCHAR(45) NULL      
         , c_Contact1      NVARCHAR(30) NULL       
         , C_Addresses     NVARCHAR(200) NULL      
         , c_Phone1        NVARCHAR(18) NULL      
         , c_Phone2        NVARCHAR(18) NULL      
         , c_zip           NVARCHAR(18) NULL      
         , MCompany        NVARCHAR(45) NULL       
         , Externorderkey  NVARCHAR(50) NULL      
         , PickLOC         NVARCHAR(10)  NULL      
         , Style           NVARCHAR(20) NULL      
         , SKUColor        NVARCHAR(10) NULL       
         , SKUSize         NVARCHAR(10) NULL         
         , ORDUdef01       NVARCHAR(120) NULL                
         , ORDDETUDef01    NVARCHAR(50) NULL                 
         , SKU             NVARCHAR(20)  NULL      
         , Openqty         INT                 
         , UnitPrice       Float      
         , storename       NVARCHAR(60) NULL      
         , UPC             NVARCHAR(20) NULL       
         , CUdf02          NVARCHAR(400) NULL       
         , ReturnAddress   NVARCHAR(400) NULL                
         , OrderKey        NVARCHAR(10)  NULL                
         , OHNotes2        NVARCHAR(80)  NULL                
         , PQty            INT   DEFAULT(0)                 
         , OHINVAmt        FLOAT                            
--         , SAddress1       NVARCHAR(45)  NULL              
--         , SZip            NVARCHAR(45)  NULL              
--         , SContact1       NVARCHAR(30)  NULL               
--         , SPhone1         NVARCHAR(18)  NULL              
         , OrdDate   DATETIME       
         , Cudf05   NVARCHAR(400) NULL       
         , OriString  NVARCHAR(4000) NULL       
         , QRCODE   NVARCHAR(4000) NULL       
   )        
      
   CREATE TABLE #TEMP_ORDERKEY      
   (       
      ORDERKEY NVARCHAR(10) NOT NULL      
   )      
      
   IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)      
              WHERE Orderkey = @c_Orderkey)      
   BEGIN      
      INSERT INTO #TEMP_ORDERKEY (ORDERKEY)      
      VALUES( @c_Orderkey)      
   END                 
   ELSE IF EXISTS (SELECT 1 FROM PickDetail WITH (NOLOCK)      
                   WHERE PickDetail.PickSlipNo = @c_Orderkey)      
   BEGIN      
      INSERT INTO #TEMP_ORDERKEY (ORDERKEY)                 
      SELECT DISTINCT OrderKey      
      FROM PickDetail AS PD WITH (NOLOCK)      
      WHERE PD.PickSlipNo=@c_Orderkey      
   END        
      
      
   DECLARE CUR_ORDKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT Orderkey      
      FROM #TEMP_ORDERKEY      
      ORDER BY Orderkey      
      
   OPEN CUR_ORDKEY      
      
   FETCH NEXT FROM CUR_ORDKEY INTO @c_getOrdKey      
   WHILE @@FETCH_STATUS = 0      
   BEGIN      
      INSERT INTO #PACKLIST20 (c_company             
                             , c_Contact1              
                             , C_Addresses            
                             , c_Phone1        
                             , c_phone2           
                             , c_zip              
                             , MCompany       
                             , Externorderkey            
                             , PickLOC                       
                             , Style       
                             , SKUColor                
                             , SKUSize                            
                             , ORDUdef01            
                             , ORDDETUDef01           
                             , SKU                  
                             , openqty                        
                             , UnitPrice            
                             , storename            
                             , UPC          
                             , CUdf02      
                             , ReturnAddress                 
                             , OrderKey                     
                             , OHNotes2                     
                             , PQty                          
                             , OHINVAmt                      
                             , OrdDate      
                             , Cudf05      
                             , OriString      
      )                        
--                        , SAddress1                    
--                        , SZip                        
--                        , SContact1                    
--                        , SPhone1 )                   
      SELECT ISNULL(OH.C_company,''),ISNULL(OH.c_Contact1,''),(OH.C_address1 + OH.C_address2 + OH.C_address3),  --IN00467807      
             ISNULL(OH.C_Phone1,''),ISNULL(OH.C_Phone2,''),ISNULL(OH.c_zip,''),--ISNULL(OH.M_Company,''),      
             CASE WHEN OH.ordergroup = 'COM_ORDER' THEN ORDDET.userdefine07 ELSE OH.m_company END ,        
             OH.Externorderkey,PD.LOC,S.Style,s.color,s.size,      
             ISNULL(OH.Userdefine01,''),  
             ISNULL(S.descr,''),                       
             --   CASE WHEN ISNULL(ORDDET.Userdefine01 + ORDDET.Userdefine02,'') = '' THEN      
             --            S.descr ELSE      
             --           (ISNULL(ORDDET.Userdefine01,'')+ ISNULL(ORDDET.Userdefine02,'')) END ,            
             PD.SKU,PD.qty,ORDDET.UnitPrice,      
--                   CASE WHEN OH.UserDefine03 = N'UA官方商城' THEN C1.Udf01      
--                        WHEN OH.Userdefine03=N'UA天猫官方旗舰店' THEN C2.Udf01 ELSE '' END,              
--                     C2.UDF01,                                                                                 
             CASE WHEN (ISNULL(OH.c_company,'') = '' OR ISNULL(OH.BuyerPO,'') ='' ) THEN C2.UDF01 ELSE                           
             C3.UDF01 END,      
             COALESCE(S.AltSku,S.RetailSku,S.ManufacturerSku,U.UPC),      
--                   ,CASE WHEN OH.UserDefine03 = N'UA官方商城' THEN C1.Udf02      
--                        WHEN OH.Userdefine03=N'UA天猫官方旗舰店' THEN C2.Udf02 ELSE '' END                            
                     -- C2.notes,C2.Notes2,            --CS05      
            CASE WHEN (ISNULL(OH.c_company,'') = '' OR ISNULL(OH.BuyerPO,'') ='' ) THEN C2.notes ELSE                           
            C3.notes END,      
            CASE WHEN (ISNULL(OH.c_company,'') = '' OR ISNULL(OH.BuyerPO,'') ='' ) THEN C2.Notes2 ELSE                           
            C3.Notes2 END,      
            OH.OrderKey--STO.Address1,STO.Zip,STO.Contact1,STO.Phone1                            
            , CASE WHEN OH.ordergroup = 'COM_ORDER' THEN OH.notes2 ELSE OH.m_company END                     
            , ISNULL(PD.qty,0) ,OH.InvoiceAmount             
            , OH.OrderDate, ISNULL(C2.UDF05,'')   --WL01       
            , OriString = 'billNo' + OH.M_COMPANY + 'totalAmount' + CONVERT(NVARCHAR(100),OH.InvoiceAmount,112) + 'billDate' +         
              CONVERT(VARCHAR(100), OH.OrderDate, 112) + 'orderSource' +  ISNULL(C2.UDF05,'')   --WL01                                                                                                                                                                 
       
      FROM ORDERS OH WITH (NOLOCK)      
      JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = OH.Orderkey      
      JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey AND PD.SKU = ORDDET.SKU AND pd.OrderLineNumber=ORDDET.OrderLineNumber      
      JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.Storerkey=PD.Storerkey      
      JOIN STORER STO WITH (NOLOCK) ON OH.Storerkey = STO.Storerkey                                 
      LEFT JOIN UPC U WITH (NOLOCK) ON U.Storerkey = PD.storerkey and u.sku=PD.sku      
      LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.Listname = 'UAEPLOCN' AND C1.Storerkey = OH.Storerkey --AND C1.Storerkey='UA'   --WL01      
      LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON C2.Listname = 'UAEPLCN' AND C2.Storerkey = OH.Storerkey --AND C2.Storerkey='UA'   --WL01        
                                          AND C2.long = OH.UserDefine03          
      LEFT JOIN CODELKUP C3 WITH (NOLOCK) ON C3.Listname = 'UASUBPLAT' AND C3.Storerkey = OH.Storerkey --AND C3.Storerkey='UA'   --WL01        
                                          AND C3.long = OH.UserDefine03 AND C3.UDF02 = OH.C_Company        
      --LEFT JOIN CODELKUP CLR (NOLOCK) ON CLR.LISTNAME = 'UAEPLCN' AND CLR.LONG = OH.UserDefine03   --WL01                                                                          
      WHERE PD.Orderkey = @c_getOrdKey      
   --AND PD.Caseid = CASE WHEN ISNULL(@c_labelno,'') <> '' THEN  @c_labelno ELSE PD.Caseid END      
      FETCH NEXT FROM CUR_ORDKEY INTO @c_getOrdKey      
   END      
   CLOSE CUR_ORDKEY      
   DEALLOCATE CUR_ORDKEY      
      
   DECLARE BARCODE_INFO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT DISTINCT ORDERKEY,      
                      ORISTRING,      
                      MCompany,      
                      CONVERT(NVARCHAR(100),OHINVAmt,112),      
                      CONVERT(VARCHAR(100), OrdDate, 112),      
                      Cudf05        
      FROM #PACKLIST20      
      ORDER BY ORISTRING      
     
   --SET @C_APPKEY = (SELECT UDF02 FROM CODELKUP where LISTNAME = 'UAINVOICE') + '&'      
   --SET @c_UrlPrefix = (SELECT UDF01 FROM CODELKUP WHERE LISTNAME = 'UAINVOICE')     
   -- SET @c_Cudf05 =''      
      
   OPEN BARCODE_INFO      
      
   FETCH NEXT FROM BARCODE_INFO INTO @c_getOrdKey,@c_QRSTRING,@c_MCompany,@c_OHINVAmt,@c_OrdDate,@c_Cudf05      
   WHILE @@FETCH_STATUS = 0      
   BEGIN           
      SELECT @c_Storerkey    = Storerkey  
           , @c_UserDefine03 = ISNULL(UserDefine03,'')  
      FROM ORDERS (NOLOCK)  
      WHERE Orderkey = @c_Orderkey  
        
      IF ISNULL(@c_UserDefine03,'') <> ''  
      BEGIN  
         SELECT @c_UDF02 = ISNULL(CL.UDF02,'')  
              , @c_UDF01 = ISNULL(CL.UDF01,'')  
         FROM CODELKUP CL (NOLOCK)  
         WHERE CL.LISTNAME = 'UAINVOICE'   
         AND CL.Storerkey = @c_Storerkey  
         AND CL.Code = @c_UserDefine03  
        
         IF ISNULL(@c_UDF02,'') = '' AND ISNULL(@c_UDF01,'') = '' --Use default value (Code = 001)  
         BEGIN  
            SELECT @c_UDF02 = ISNULL(CL.UDF02,'')  
                 , @c_UDF01 = ISNULL(CL.UDF01,'')  
            FROM CODELKUP CL (NOLOCK)  
            WHERE CL.LISTNAME = 'UAINVOICE'   
            AND CL.Storerkey = @c_Storerkey  
            AND CL.Code = '001'  
         END  
      END  
      ELSE   --@c_UserDefine03 = ''  
      BEGIN  
         SELECT @c_UDF02 = ISNULL(CL.UDF02,'')  
              , @c_UDF01 = ISNULL(CL.UDF01,'')  
         FROM CODELKUP CL (NOLOCK)  
         WHERE CL.LISTNAME = 'UAINVOICE'   
         AND CL.Storerkey = @c_Storerkey  
         AND CL.Code = '001'  
      END  
  
      SET @C_APPKEY    = LTRIM(RTRIM(@c_UDF02)) + '&'  
      SET @c_UrlPrefix = LTRIM(RTRIM(@c_UDF01))  
  
      EXEC MASTER.[dbo].[isp_HMACSHA1Encrypt]         
            @c_QRSTRING,         
            @c_APPKEY,         
            @c_SignatureOut OUTPUT,         
            @c_VB_ErrMsg    OUTPUT      
          
      IF ISNULL(RTRIM(@c_VB_ErrMsg),'') = ''       
      BEGIN      
         SET @c_SignatureOut = LOWER(@c_SignatureOut)      
         EXEC MASTER.[dbo].[isp_Base64Encode]      
               'UTF-8' ,      
               @c_SignatureOut,      
               @c_OutputString OUTPUT,         
               @c_vbErrMsg    OUTPUT       
      
         IF ISNULL(RTRIM(@c_vbErrMsg),'') = ''      
         BEGIN      
            SET @c_UrlOut = @c_UrlPrefix + 'billNo=' + @c_MCompany + '&totalAmount=' + @c_OHINVAmt +      
                            '&billDate=' + @c_OrdDate + '&orderSource=' + @c_Cudf05 + '&sign=' + @c_OutputString      
            UPDATE #PACKLIST20      
            SET QRCODE = @c_UrlOut      
            WHERE ORDERKEY = @c_getOrdKey      
         END      
      END      
      
      FETCH NEXT FROM BARCODE_INFO INTO @c_getOrdKey,@c_QRSTRING,@c_MCompany,@c_OHINVAmt,@c_OrdDate,@c_Cudf05      
   END      
   CLOSE BARCODE_INFO      
   DEALLOCATE BARCODE_INFO      
      
   SELECT DISTINCT c_company             
                 , c_Contact1              
                 , C_Addresses            
                 , c_Phone1        
                 , c_phone2           
                 , c_zip              
                 , MCompany       
                 , Externorderkey             
                 , ISNULL(PickLOC,'')  as   PickLOC                   
                 , ISNULL(Style,'') AS Style      
                 , ISNULL(SKUColor,'')  AS SKUColor               
                 , ISNULL(SKUSize,'') AS skusize                            
                 , ORDUdef01            
                 , ORDDETUDef01           
                 , ISNULL(SKU,'')  AS SKU                
                 , sum(openqty) AS openqty                        
                 , UnitPrice            
                 , ISNULL(storename,'') AS storename           
                 , ISNULL(UPC,'')  AS upc        
                 , ISNULL(CUdf02,'') AS cudf02      
                 , ISNULL(ReturnAddress,'')  AS ReturnAddress        
                 , OrderKey                                          
                 --,SAddress1,SZip,SContact1,SPhone1                   
                 ,OHNotes2,SUM(PQty) AS PQTY                        
                 ,OHINVAmt                                         
                 ,Cudf05      
                 ,QRCODE      
                 -- ,OriString      
   FROM #PACKLIST20        
   GROUP BY c_company             
          , c_Contact1              
          , C_Addresses            
          , c_Phone1        
          , c_phone2           
          , c_zip              
          , MCompany       
          , Externorderkey             
          , ISNULL(PickLOC,'')                  
          , ISNULL(Style,'')       
          , ISNULL(SKUColor,'')               
          , ISNULL(SKUSize,'')                            
          , ORDUdef01            
          , ORDDETUDef01           
          , ISNULL(SKU,'')                 
          -- , openqty                        
          , UnitPrice            
          , ISNULL(storename,'')            
          , ISNULL(UPC,'')          
          , ISNULL(CUdf02,'')       
          , ISNULL(ReturnAddress,'')                          
          , OrderKey                                          
          --,SAddress1,SZip,SContact1,SPhone1                   
          ,OHNotes2      
          ,OHINVAmt               
          ,Cudf05      
          ,QRCODE      
          --  ,OriString      
   ORDER BY PickLoc        
                     
END  


GO