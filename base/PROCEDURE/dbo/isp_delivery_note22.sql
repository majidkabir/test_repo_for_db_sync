SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Delivery_Note22                                     */
/* Creation Date: 10-JAN-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  WMS-908 - FBR New Delivery Report Format                   */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 14-Apr-2017  CSCHONG   1.1 WMS-1575- Revise field mapping (CS01)     */
/************************************************************************/
CREATE PROC [dbo].[isp_Delivery_Note22] 
           @c_MBOLKey  NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   CREATE TABLE #TEMP_DO
      (  RowRef               INT 
      ,  MBOLKey              NVARCHAR(10)
      ,  ShipDate             DATETIME
      ,  Vessel               NVARCHAR(30)
      ,  BookingReference     NVARCHAR(30)
      ,  OtherReference       NVARCHAR(30)
      ,  DriverName           NVARCHAR(30)
      ,  Facility             NVARCHAR(5)
      ,  Orderkey             NVARCHAR(10)
      ,  OrderDate            DATETIME      
      ,  Status               NVARCHAR(10)
      ,  ExternOrderkey       NVARCHAR(30)
      ,  Consigneekey         NVARCHAR(15)
      ,  C_Company            NVARCHAR(45)
      ,  C_Address1           NVARCHAR(45)
      ,  C_Address2           NVARCHAR(45)
      ,  C_Zip                NVARCHAR(18)    
      ,  C_City               NVARCHAR(45)    
      ,  C_Phone1             NVARCHAR(18) 
      ,  Customer             NVARCHAR(15)
      ,  Company              NVARCHAR(45)
      ,  Address1             NVARCHAR(45)
      ,  Address2             NVARCHAR(45)
      ,  Zip                  NVARCHAR(18)    
      ,  City                 NVARCHAR(45)    
      ,  Phone1               NVARCHAR(18) 
      ,  Notes                NVARCHAR(4000)
      ,  PrintFlag            NVARCHAR(1)
      ,  ST_Storerkey         NVARCHAR(15)
      ,  ST_Company           NVARCHAR(45)
      ,  ST_Address1          NVARCHAR(45)
      ,  ST_Address2          NVARCHAR(45)
      ,  ST_Address4          NVARCHAR(45)
      ,  ST_Zip               NVARCHAR(18)    
      ,  ST_City              NVARCHAR(45)    
      ,  ST_Phone1            NVARCHAR(18)
      ,  ExternConsoOrderkey  NVARCHAR(30)
      ,  ExternPOkey          NVARCHAR(20)
      ,  ExternLineNo         NVARCHAR(10)
      ,  Storerkey            NVARCHAR(15)
      ,  Sku                  NVARCHAR(20)
      ,  SkuDescr             NVARCHAR(60)
      ,  SkuDescr2            NVARCHAR(100)
      ,  OriginalQty          INT
      ,  ShippedQty           INT
      ,  UOM                  NVARCHAR(10)
      ,  [Weight]             FLOAT
      ,  WeightUOM            NVARCHAR(10)
      ,  Volume               FLOAT
      ,  VolumeUOM            NVARCHAR(10)
      ,  ST_Fax1              NVARCHAR(18)              --CS01
      ,  ODUdef08             NVARCHAR(18)              --CS01         
      ,  ComposedBy           NVARCHAR(20)              --CS01
      ,  NetWeight            FLOAT                     --CS01
      ,  IncoTerm             NVARCHAR(10)              --CS01 
      ,  ODExternLineNo       NVARCHAR(10)
      )

   INSERT INTO #TEMP_DO
   (
         RowRef               
      ,  MBOLKey              
      ,  ShipDate             
      ,  Vessel               
      ,  BookingReference     
      ,  OtherReference       
      ,  DriverName           
      ,  Facility             
      ,  Orderkey             
      ,  OrderDate            
      ,  Status               
      ,  ExternOrderkey       
      ,  Consigneekey         
      ,  C_Company            
      ,  C_Address1           
      ,  C_Address2           
      ,  C_Zip                
      ,  C_City               
      ,  C_Phone1             
      ,  Customer             
      ,  Company              
      ,  Address1             
      ,  Address2             
      ,  Zip                  
      ,  City                 
      ,  Phone1               
      ,  Notes                
      ,  PrintFlag            
      ,  ST_Storerkey         
      ,  ST_Company           
      ,  ST_Address1          
      ,  ST_Address2          
      ,  ST_Address4          
      ,  ST_Zip               
      ,  ST_City              
      ,  ST_Phone1            
      ,  ExternConsoOrderkey  
      ,  ExternPOkey          
      ,  ExternLineNo         
      ,  Storerkey            
      ,  Sku                  
      ,  SkuDescr             
      ,  SkuDescr2            
      ,  OriginalQty          
      ,  ShippedQty           
      ,  UOM                  
      ,  [Weight]             
      ,  WeightUOM            
      ,  Volume               
      ,  VolumeUOM       
      ,  ST_Fax1                  --CS01
      ,  ODUdef08                 --CS01
		,  ComposedBy               --CS01
		,  NetWeight                --CS01
		,  IncoTerm                 --CS01
		,  ODExternLineNo           --CS01
   )
   SELECT RowRef = ROW_NUMBER() OVER ( PARTITION BY ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
                                             ,  ISNULL(RTRIM(ORDERDETAIL.ExternConsoOrderkey),'')
                                             ,  ISNULL(RTRIM(ORDERDETAIL.ExternPOkey),'')
                                             --,  ORDERDETAIL.Storerkey 
                                             --,  ORDERDETAIL.Sku
                                       ORDER BY ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
                                             ,  ISNULL(RTRIM(ORDERDETAIL.ExternConsoOrderkey),'')
                                             ,  ISNULL(RTRIM(ORDERDETAIL.ExternPOkey),'')
                                             ,  ISNULL(RTRIM(ORDERDETAIL.ExternLineNo),'')
                                             ,  ORDERDETAIL.Storerkey 
                                             ,  ORDERDETAIL.Sku
                                       )
         ,MBOL.MBOLKey
         ,MBOL.ShipDate
         ,Vessel           = ISNULL(RTRIM(MBOL.Vessel),'')
         ,BookingReference = ISNULL(RTRIM(MBOL.BookingReference),'')
         ,OtherReference   = ISNULL(RTRIM(MBOL.OtherReference),'')
         ,DriverName       = ISNULL(RTRIM(MBOL.DriverName),'')
         ,Facility         = ISNULL(RTRIM(ORDERS.Facility),'')
         ,ORDERS.Orderkey
         ,ORDERS.OrderDate
         ,ORDERS.Status
         ,ExternOrderkey   = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,Consigneekey  = ISNULL(RTRIM(ORDERS.Consigneekey),'') 
         ,C_Company     = ISNULL(RTRIM(ORDERS.C_Company),'')       
         ,C_Address1    = ISNULL(RTRIM(ORDERS.C_Address1),'')      
         ,C_Address2    = ISNULL(RTRIM(ORDERS.C_Address2),'')      
         ,C_Zip         = ISNULL(RTRIM(ORDERS.C_Zip),'')      
         ,C_City        = ISNULL(RTRIM(ORDERS.C_City),'')      
         ,C_Phone1      = ISNULL(RTRIM(ORDERS.C_Phone1),'')  
         ,Customer = CASE WHEN ISNULL(RTRIM(ORDERS.BillToKey),'')  = '' 
                          THEN ISNULL(RTRIM(ORDERS.Consigneekey),'')  
                          ELSE ISNULL(RTRIM(ORDERS.BillToKey),'')  
                          END
         ,Company  = CASE WHEN ISNULL(RTRIM(ORDERS.BillToKey),'')  = '' 
                          THEN ISNULL(RTRIM(ORDERS.C_Company),'')  
                          ELSE ISNULL(RTRIM(ORDERS.B_Company),'')  
                          END
         ,Address1 = CASE WHEN ISNULL(RTRIM(ORDERS.BillToKey),'')  = '' 
                          THEN ISNULL(RTRIM(ORDERS.C_Address1),'')  
                          ELSE ISNULL(RTRIM(ORDERS.B_Address1),'')  
                          END
         ,Address2 = CASE WHEN ISNULL(RTRIM(ORDERS.BillToKey),'')  = '' 
                          THEN ISNULL(RTRIM(ORDERS.C_Address2),'')  
                          ELSE ISNULL(RTRIM(ORDERS.B_Address2),'')  
                          END
         ,Zip      = CASE WHEN ISNULL(RTRIM(ORDERS.BillToKey),'')  = '' 
                          THEN ISNULL(RTRIM(ORDERS.C_Zip),'')  
                          ELSE ISNULL(RTRIM(ORDERS.B_Zip),'')  
                          END
         ,City     = CASE WHEN ISNULL(RTRIM(ORDERS.BillToKey),'')  = '' 
                          THEN ISNULL(RTRIM(ORDERS.C_City),'')  
                          ELSE ISNULL(RTRIM(ORDERS.B_City),'')  
                          END
         ,Phone1   = CASE WHEN ISNULL(RTRIM(ORDERS.BillToKey),'')  = '' 
                          THEN ISNULL(RTRIM(ORDERS.C_Phone1),'')  
                          ELSE ISNULL(RTRIM(ORDERS.B_Phone1),'')  
                          END
         ,Notes          = ISNULL(RTRIM(ORDERS.Notes),'')
         ,PrintFlag      = ISNULL(RTRIM(ORDERS.PrintFlag),'')
         ,ST_Storerkey   = ISNULL(RTRIM(STORER.Storerkey),'')  
         ,ST_Company     = ISNULL(RTRIM(STORER.Company),'')       
         ,ST_Address1    = ISNULL(RTRIM(STORER.Address1),'')      
         ,ST_Address2    = ISNULL(RTRIM(STORER.Address2),'')  
         ,ST_Address4    = ISNULL(RTRIM(STORER.Address4),'')            
         ,ST_Zip         = ISNULL(RTRIM(STORER.Zip),'')      
         ,ST_City        = ISNULL(RTRIM(STORER.City),'')      
         ,ST_Phone1      = ISNULL(RTRIM(STORER.Phone1),'')
         ,ExternConsoOrderkey = ISNULL(RTRIM(ORDERDETAIL.ExternConsoOrderkey),'')     
         ,ExternPOKey         = ISNULL(RTRIM(ORDERDETAIL.ExternPOKey),'')
        -- ,ExternLineNo   = ISNULL(RTRIM(ORDERDETAIL.ExternLineNo),'')       --CS01
         ,ExternLineno     = CASE WHEN ISNULL(ORDERDETAIL.Userdefine04,'') = '' 
                              THEN ORDERDETAIL.externlineno ELSE ORDERDETAIL.userdefine04 END      --CS01	
         ,ORDERDETAIL.Storerkey
         ,ORDERDETAIL.Sku 
         ,SkuDescr       = ISNULL(RTRIM(SKU.Descr),'') 
         ,SkuDescr2      =   CASE WHEN ISNULL(RTRIM(ORDERDETAIL.Notes2),'') ='' THEN
                                  CASE WHEN ISNULL(RTRIM(ORDERDETAIL.UserDefine07),'') = ORDERDETAIL.Sku THEN       --CS01 Start
                                   ISNULL(RTRIM(SKU.Descr),'') 
                                ELSE ''
                                END
                                ELSE  ISNULL(RTRIM(ORDERDETAIL.Notes2),'')   	
                            END                                                                               --CS01 End
         ,OriginalQty    = SUM(ORDERDETAIL.OriginalQty)
         ,ShippedQty     = SUM(ORDERDETAIL.ShippedQty)
         ,UOM            = ISNULL(RTRIM(ORDERDETAIL.UOM ),'')
         ,Weight         = CASE WHEN ISNULL(ORDERDETAIL.Userdefine05,'') = '1' THEN 0 ELSE 
         	               SUM(ORDERDETAIL.ShippedQty) * ISNULL(SKU.StdGrossWgt,0)  END              --CS01
         ,WeightUOM      = 'Kg'
         ,Volume         = CASE WHEN ISNULL(ORDERDETAIL.Userdefine05,'') = '1' THEN 0 ELSE
         	                 SUM(ORDERDETAIL.ShippedQty) * (ISNULL(SKU.StdCube,0)*1000000) END             --CS01
         ,VolumeUOM      = 'CBM'
         ,ST_Fax1        = ISNULL(RTRIM(STORER.Fax1),'')            --CS01
         ,ODUdf08        = ISNULL(RTRIM(ORDERDETAIL.UserDefine08),'')     --CS01
         ,ComposedBy     = CASE WHEN ISNULL(ORDERDETAIL.Userdefine05,'') = '1' 
                              THEN 'Composed By:' ELSE '' END      --CS01	
        ,NetWeight       = CASE WHEN ISNULL(ORDERDETAIL.Userdefine05,'') = '1' THEN 0 ELSE
        	                   SUM(ORDERDETAIL.ShippedQty) * ISNULL(SKU.StdNetWgt,0) END    --CS01   
        ,IncoTerm        = ORDERS.IncoTerm                                           --CS01  
        ,ODExternLineNo  =  ORDERDETAIL.externlineno                                 --CS01            
   FROM MBOL        WITH (NOLOCK)
   JOIN ORDERS      WITH (NOLOCK) ON (MBOL.MBOLKey = ORDERS.MBOLKey)
   JOIN STORER      WITH (NOLOCK) ON (ORDERS.Storerkey = STORER.Storerkey)
   JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
   JOIN SKU         WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
                                  AND(ORDERDETAIL.Sku = SKU.Sku)                             
   WHERE MBOL.MBOLKey = @c_MBOLKey
   AND ORDERS.status = 9                                   --CS01
   GROUP BY MBOL.MBOLKey
      ,  MBOL.ShipDate
      ,  ISNULL(RTRIM(MBOL.Vessel),'')
      ,  ISNULL(RTRIM(MBOL.BookingReference),'')
      ,  ISNULL(RTRIM(MBOL.OtherReference),'')
      ,  ISNULL(RTRIM(MBOL.DriverName),'')
      ,  ISNULL(RTRIM(ORDERS.Facility),'')
      ,  ORDERS.Orderkey
      ,  ORDERS.OrderDate
      ,  ORDERS.Status
      ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
      ,  ISNULL(RTRIM(ORDERS.Consigneekey),'') 
      ,  ISNULL(RTRIM(ORDERS.C_Company),'')       
      ,  ISNULL(RTRIM(ORDERS.C_Address1),'')      
      ,  ISNULL(RTRIM(ORDERS.C_Address2),'')      
      ,  ISNULL(RTRIM(ORDERS.C_Zip),'')      
      ,  ISNULL(RTRIM(ORDERS.C_City),'')      
      ,  ISNULL(RTRIM(ORDERS.C_Phone1),'')  
      ,  CASE WHEN ISNULL(RTRIM(ORDERS.BillToKey),'')  = '' 
               THEN ISNULL(RTRIM(ORDERS.Consigneekey),'')  
               ELSE ISNULL(RTRIM(ORDERS.BillToKey),'')  
               END
      ,  CASE WHEN ISNULL(RTRIM(ORDERS.BillToKey),'')  = '' 
                        THEN ISNULL(RTRIM(ORDERS.C_Company),'')  
                        ELSE ISNULL(RTRIM(ORDERS.B_Company),'')  
                        END
      ,  CASE WHEN ISNULL(RTRIM(ORDERS.BillToKey),'')  = '' 
               THEN ISNULL(RTRIM(ORDERS.C_Address1),'')  
               ELSE ISNULL(RTRIM(ORDERS.B_Address1),'')  
               END
      ,  CASE WHEN ISNULL(RTRIM(ORDERS.BillToKey),'')  = '' 
               THEN ISNULL(RTRIM(ORDERS.C_Address2),'')  
               ELSE ISNULL(RTRIM(ORDERS.B_Address2),'')  
               END
      ,  CASE WHEN ISNULL(RTRIM(ORDERS.BillToKey),'')  = '' 
               THEN ISNULL(RTRIM(ORDERS.C_Zip),'')  
               ELSE ISNULL(RTRIM(ORDERS.B_Zip),'')  
               END
      ,  CASE WHEN ISNULL(RTRIM(ORDERS.BillToKey),'')  = '' 
               THEN ISNULL(RTRIM(ORDERS.C_City),'')  
               ELSE ISNULL(RTRIM(ORDERS.B_City),'')  
               END
      ,  CASE WHEN ISNULL(RTRIM(ORDERS.BillToKey),'')  = '' 
               THEN ISNULL(RTRIM(ORDERS.C_Phone1),'')  
               ELSE ISNULL(RTRIM(ORDERS.B_Phone1),'')  
               END
      ,  ISNULL(RTRIM(ORDERS.Notes),'')
      ,  ISNULL(RTRIM(ORDERS.PrintFlag),'')
      ,  ISNULL(RTRIM(STORER.Storerkey),'')  
      ,  ISNULL(RTRIM(STORER.Company),'')       
      ,  ISNULL(RTRIM(STORER.Address1),'')      
      ,  ISNULL(RTRIM(STORER.Address2),'')  
      ,  ISNULL(RTRIM(STORER.Address4),'')            
      ,  ISNULL(RTRIM(STORER.Zip),'')      
      ,  ISNULL(RTRIM(STORER.City),'')      
      ,  ISNULL(RTRIM(STORER.Phone1),'')
      ,  ISNULL(RTRIM(ORDERDETAIL.ExternConsoOrderkey),'')           
      ,  ISNULL(RTRIM(ORDERDETAIL.ExternPOKey),'')
      ,  ISNULL(RTRIM(ORDERDETAIL.ExternLineNo),'')       
      ,  CASE WHEN ISNULL(ORDERDETAIL.Userdefine04,'') = '' 
                              THEN ORDERDETAIL.externlineno ELSE ORDERDETAIL.userdefine04 END  --CS01
      ,  ORDERDETAIL.Storerkey
      ,  ORDERDETAIL.Sku 
      ,  ISNULL(RTRIM(SKU.Descr),'') 
      ,  ISNULL(RTRIM(ORDERDETAIL.UOM ),'')
      ,  ISNULL(SKU.StdGrossWgt,0)
      ,  ISNULL(SKU.StdCube,0)
      ,  ISNULL(RTRIM(ORDERDETAIL.UserDefine07),'')
      ,  ISNULL(RTRIM(ORDERDETAIL.Notes2),'')
      ,  ISNULL(RTRIM(STORER.Fax1),'')                   --CS01
      ,  ISNULL(RTRIM(ORDERDETAIL.UserDefine08),'')      --CS01
      ,  ISNULL(ORDERDETAIL.Userdefine05,'')             --CS01
      ,  ISNULL(SKU.StdNetWgt,0)                         --CS01
      ,  ORDERS.IncoTerm                                 --CS01
      ,  ORDERDETAIL.externlineno
   --ORDER BY ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
   --      ,  ISNULL(RTRIM(ORDERDETAIL.ExternConsoOrderkey),'')   
   --      ,  ISNULL(RTRIM(ORDERDETAIL.ExternPOKey),'')
   ORDER BY ORDERDETAIL.externlineno

   IF EXISTS ( SELECT 1
               FROM #TEMP_DO
               WHERE Status <> '9'
             )
   BEGIN      
      RAISERROR ('Order not shipped yet.', 16, 1) WITH SETERROR    -- SQL2012
      GOTO QUIT_SP
   END

   UPDATE ORDERS WITH (ROWLOCK)
      SET PrintFlag = 'Y'
         ,Trafficcop = NULL
         ,EditWho = SUSER_NAME()
         ,EditDate= GETDATE()
   FROM ORDERS 
   JOIN #TEMP_DO  ON (ORDERS.Orderkey = #TEMP_DO.Orderkey)
   WHERE ORDERS.Status = '9'
   AND  ORDERS.PrintFlag <> 'Y'

QUIT_SP:
   SELECT PrintedOn = GETDATE()
      ,  MBOLKey
      ,  ShipDate               
      ,  Vessel                 
      ,  BookingReference       
      ,  OtherReference         
      ,  DriverName             
      ,  Facility               
      ,  Orderkey               
      ,  OrderDate              
      ,  Status                 
      ,  ExternOrderkey         
      ,  Consigneekey           
      ,  C_Company              
      ,  C_Address1             
      ,  C_Address2             
      ,  C_Zip                  
      ,  C_City                 
      ,  C_Phone1               
      ,  Customer               
      ,  Company                
      ,  Address1               
      ,  Address2               
      ,  Zip                    
      ,  City                   
      ,  Phone1                 
      ,  Notes                  
      ,  PrintFlag              
      ,  ST_Storerkey           
      ,  ST_Company             
      ,  ST_Address1            
      ,  ST_Address2            
      ,  ST_Address4            
      ,  ST_Zip                 
      ,  ST_City                
      ,  ST_Phone1              
      ,  ExternConsoOrderkey    
      ,  ExternPOkey            
      ,  ExternLineNo           
      ,  Storerkey              
      ,  Sku                    
      ,  SkuDescr               
      ,  SkuDescr2              
      ,  OriginalQty            
      ,  ShippedQty             
      ,  UOM                    
      ,  [Weight]               
      ,  WeightUOM              
      ,  Volume                 
      ,  VolumeUOM
      ,  ST_Fax1          --CS01
      ,  ODUdef08         --CS01
      ,  ComposedBy       --CS01
      ,  NetWeight        --CS01
      ,  IncoTerm         --CS01
      ,  ODExternLineNo   --CS01
   FROM #TEMP_DO
   ORDER BY ExternOrderkey  
         --,  ExternConsoOrderkey    
         --  ,  ExternPOkey            
         ,  ODExternLineNo     --CS01
         ,  Storerkey
         ,  Sku   

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO