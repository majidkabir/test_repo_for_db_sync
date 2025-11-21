SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/  
/* Store Procedure:  isp_GetPickSlipOrders89_1                          */  
/* Creation Date: 01-APR-2019                                           */  
/* Copyright: IDS                                                       */  
/* Written by: WLCHOOI                                                  */  
/*             Copy and change from nsp_GetPickSlipOrders55             */  
/* Purpose:  Create Normal Pickslip for Storer 'LVS'                    */  
/*                                                                      */  
/* Input Parameters:  @c_loadkey  - Loadkey                             */  
/*                                                                      */  
/* Output Parameters:  None                                             */  
/*                                                                      */  
/* Return Status:  None                                                 */  
/*                                                                      */  
/* Usage:  Used for report dw = r_dw_print_pickorder89_1 (ECOM)         */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 2022-08-09   mingle        WMS-20386 add new mappings(ML01)          */
/************************************************************************/  

CREATE PROC [dbo].[isp_GetPickSlipOrders89_1] (@c_loadkey NVARCHAR(10))  
AS  
BEGIN  
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @c_PickheaderKey   NVARCHAR(10)  
         , @c_PickSlipNo      NVARCHAR(10)  
         , @c_PrintedFlag     NVARCHAR(1)   
         , @n_continue        INT   
         , @c_errmsg          NVARCHAR(255)   
         , @b_success         INT   
         , @n_err             INT   

         --ORDERS Table  
         , @c_orderkey        NVARCHAR(10)  = ''
         , @c_Externorderkey  NVARCHAR(30)  = ''
         , @d_DeliveryDate    DATETIME  
         , @c_Contact1        NVARCHAR(30)  = ''

         --ORDERDETAIL Table
         , @c_Notes           NVARCHAR(60)  = ''
         
         --OrderInfo Table         
         , @c_Platform        NVARCHAR(20)  = ''   

         --Pickdetail Table
         , @c_sku             NVARCHAR(20)  = ''     
         , @c_loc             NVARCHAR(10)  = ''   
         , @n_qty             INT           = 0  

         --Sku Table
         , @c_ManufacturerSKU NVARCHAR(20)  = ''
         
         --Codelkup
         , @c_UDF02           NVARCHAR(60)  = ''     
            
         , @c_StorerKey       NVARCHAR(15)  = ''        
         , @c_UOM             NVARCHAR(10)  = ''    
         , @c_ID              NVARCHAR(18)  = ''    
         , @c_Logicalloc      NVARCHAR(18)  = ''  
  
         , @c_firsttime       NVARCHAR(1)   = '' 
         , @c_ECOMFlag        NVARCHAR(10)  = ''
         
         , @n_MaxRec          INT           = 1
         , @n_CurrentRec      INT           = 1
         , @n_MaxLineno       INT           = 10

         , @c_RptLogo         NVARCHAR(255) = ''
		 --START ML01
		 , @c_H01             NVARCHAR(255) = ''
		 , @c_H02             NVARCHAR(255) = ''
		 , @c_D01             NVARCHAR(255) = ''
		 , @c_D02             NVARCHAR(255) = ''
		 , @c_D03             NVARCHAR(255) = ''
		 , @c_D04             NVARCHAR(255) = ''
		 , @c_D05             NVARCHAR(255) = ''
		 , @c_D06             NVARCHAR(255) = ''
		 , @c_D07             NVARCHAR(255) = ''
		 , @c_D08             NVARCHAR(255) = ''
		 , @c_D09             NVARCHAR(255) = ''
		 , @c_D10             NVARCHAR(255) = ''
		 , @c_D11             NVARCHAR(255) = ''
		 , @c_D12             NVARCHAR(255) = ''
		 , @c_D13             NVARCHAR(255) = ''
		 , @c_D14             NVARCHAR(255) = ''
		 , @c_QRCODE          NVARCHAR(255) = ''
		 --END ML01
         
    

   DECLARE @n_PS_required     INT   
         , @c_NextNo          NVARCHAR(10)  
  
   CREATE TABLE #temp_pick  
   (  rowid            INT NOT NULL IDENTITY(1,1) PRIMARY KEY
   ,  OrderKey         NVARCHAR(10)  
   ,  ExternOrderKey   NVARCHAR(50)  
   ,  PickSlipNo       NVARCHAR(10) NULL
   ,  [Platform]       NVARCHAR(20)  
   ,  DeliveryDate     DATETIME   
   ,  C_Contact1       NVARCHAR(30)
   ,  Loc              NVARCHAR(10)
   ,  SKU              NVARCHAR(20)
   ,  ManufacturerSKU  NVARCHAR(20)
   ,  Notes            NVARCHAR(60)   
   ,  Qty              INT
   ,  UDF02            NVARCHAR(60)
   ,  PHBarcode        NVARCHAR(100)
   ,  OSBarcode        NVARCHAR(100)
   ,  EXTORDBarcode    NVARCHAR(100)
   ,  PrintedFlag      NVARCHAR(1)
   ,  Loadkey          NVARCHAR(10)   
 )     
 
      CREATE TABLE #temp_pick1  
   (  rowid            INT NOT NULL IDENTITY(1,1) PRIMARY KEY
   ,  OrderKey         NVARCHAR(10)  
   ,  ExternOrderKey   NVARCHAR(50)  
   ,  PickSlipNo       NVARCHAR(10) NULL
   ,  [Platform]       NVARCHAR(20)  
   ,  DeliveryDate     DATETIME   
   ,  C_Contact1       NVARCHAR(30)
   ,  Loc              NVARCHAR(10)
   ,  SKU              NVARCHAR(20)
   ,  ManufacturerSKU  NVARCHAR(20)
   ,  Notes            NVARCHAR(60)   
   ,  Qty              INT
   ,  UDF02            NVARCHAR(60)
   ,  PHBarcode        NVARCHAR(100)
   ,  OSBarcode        NVARCHAR(100)
   ,  EXTORDBarcode    NVARCHAR(100)
   ,  PrintedFlag      NVARCHAR(1)
   ,  Loadkey          NVARCHAR(10)   
   ,  Recgroup         INT
   ,  ShowNo           NVARCHAR(1)
   )  
         
   SET @n_continue = 1   

   SELECT TOP 1 @c_ecomflag = LTRIM(RTRIM(ISNULL(ORDERS.TYPE,'')))
   FROM ORDERS (NOLOCK)
   WHERE ORDERS.LOADKEY = @c_loadkey

   SELECT @c_RptLogo = CL2.Long    
   FROM CODELKUP CL2 WITH (NOLOCK)    
   WHERE CL2.LISTNAME='RPTLogo' AND CL2.Storerkey=(SELECT TOP 1 STORERKEY FROM ORDERS (NOLOCK) WHERE LOADKEY = @c_loadkey )
   AND CL2.CODE = 'LVSPICK'  

   --START ML01
   SELECT @c_H01 = MAX(CASE WHEN CLR.CODE2 = 'H01' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
		 ,@c_H02 = MAX(CASE WHEN CLR.CODE2 = 'H02' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
		 ,@c_D01 = MAX(CASE WHEN CLR.CODE2 = 'D01' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
		 ,@c_D02 = MAX(CASE WHEN CLR.CODE2 = 'D02' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
		 ,@c_D03 = MAX(CASE WHEN CLR.CODE2 = 'D03' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
		 ,@c_D04 = MAX(CASE WHEN CLR.CODE2 = 'D04' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
		 ,@c_D05 = MAX(CASE WHEN CLR.CODE2 = 'D05' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
		 ,@c_D06 = MAX(CASE WHEN CLR.CODE2 = 'D06' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
		 ,@c_D07 = MAX(CASE WHEN CLR.CODE2 = 'D07' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
		 ,@c_D08 = MAX(CASE WHEN CLR.CODE2 = 'D08' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
		 ,@c_D09 = MAX(CASE WHEN CLR.CODE2 = 'D09' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
		 ,@c_D10 = MAX(CASE WHEN CLR.CODE2 = 'D10' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
		 ,@c_D11 = MAX(CASE WHEN CLR.CODE2 = 'D11' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
		 ,@c_D12 = MAX(CASE WHEN CLR.CODE2 = 'D12' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
		 ,@c_D13 = MAX(CASE WHEN CLR.CODE2 = 'D13' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
		 ,@c_D14 = MAX(CASE WHEN CLR.CODE2 = 'D14' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
		 ,@c_QRCODE = MAX(CASE WHEN CLR.CODE2 = 'QRCODE' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
   FROM CODELKUP CLR WITH (NOLOCK)    
   WHERE CLR.LISTNAME='REPORTCFG' AND CLR.Storerkey=(SELECT TOP 1 STORERKEY FROM ORDERS (NOLOCK) WHERE LOADKEY = @c_loadkey )
   AND CLR.CODE = 'ECOM' 
   --END ML01

   
   IF (@c_ecomflag <> 'ECOM')
     GOTO QUIT_RESULT
      
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order  
   IF EXISTS(SELECT 1 FROM PICKHEADER (NOLOCK)  
   WHERE ExternOrderKey = @c_loadkey  
   AND   Zone = '3')  
   BEGIN  
      SET @c_firsttime = 'N'  
      SET @c_PrintedFlag = 'Y'  
   END  
   ELSE  
   BEGIN  
      SET @c_firsttime = 'Y'  
      SET @c_PrintedFlag = 'N'  
   END -- Record Not Exists  
  
   BEGIN TRAN  
   -- Uses PickType as a Printed Flag  
   UPDATE PICKHEADER WITH (ROWLOCK)  
      SET PickType = '1',  
      TrafficCop = NULL  
   WHERE ExternOrderKey = @c_loadkey  
   AND Zone = '3'  
   AND PickType = '0'  
  
   SET @n_err = @@ERROR  
   IF @n_err <> 0  
   BEGIN  
      SET @n_continue = 3  
      IF @@TRANCOUNT >= 1  
      BEGIN  
         ROLLBACK TRAN  
         GOTO FAILURE  
     END  
   END  
   ELSE  
   BEGIN  
      IF @@TRANCOUNT > 0  
      BEGIN  
         COMMIT TRAN  
      END  
      ELSE  
      BEGIN  
         SET @n_continue = 3  
         ROLLBACK TRAN  
         GOTO FAILURE  
      END  
   END  
  
   DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT PICKDETAIL.OrderKey    
         ,PICKDETAIL.Storerkey  
         ,PICKDETAIL.Sku  
         ,PICKDETAIL.loc  
         ,PICKDETAIL.UOM   
         ,PICKDETAIL.ID  
         ,SUM(PICKDETAIL.qty)  
         ,LOC.LogicalLocation   
   FROM PICKDETAIL WITH (NOLOCK)  
   JOIN LOADPLANDETAIL WITH (NOLOCK)  ON (PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey)  
   JOIN LOC  WITH (NOLOCK) ON ( LOC.Loc = PICKDETAIL.Loc)  
   WHERE  LOADPLANDETAIL.LoadKey = @c_loadkey  
   GROUP BY PICKDETAIL.OrderKey  
         ,  PICKDETAIL.storerkey  
         ,  PICKDETAIL.sku  
         ,  PICKDETAIL.loc  
         ,  PICKDETAIL.UOM  
         ,  PICKDETAIL.ID  
         ,  LOC.LogicalLocation  
  
   ORDER BY PICKDETAIL.ORDERKEY, PICKDETAIL.LOC
         
   OPEN CUR_PICK  
  
     
   FETCH NEXT FROM CUR_PICK INTO @c_Orderkey  
                              ,  @c_Storerkey  
                              ,  @c_Sku  
                              ,  @c_loc  
                              ,  @c_UOM  
                              ,  @c_ID  
                              ,  @n_Qty  
                              ,  @c_Logicalloc  
  
              
   WHILE (@@FETCH_STATUS <> -1)  
   BEGIN  
      IF @c_OrderKey = ''  
      BEGIN  
         SET @c_Externorderkey = ''  
         SET @c_Contact1       = ''   
         SET @c_Notes          = ''
         SET @c_Platform       = ''
         SET @c_UDF02          = ''
      END  
      ELSE  
      BEGIN  
         SELECT  @c_Externorderkey = ORDERS.ExternOrderKey     
               , @d_DeliveryDate   = ORDERS.DeliveryDate   
               , @c_Contact1       = ORDERS.C_contact1
        --       , @c_Notes          = ORDERDETAIL.Notes
               , @c_Platform       = ISNULL(ORDERINFO.[PLATFORM], '')  
               , @c_UDF02          = ISNULL(CL.UDF02,'')
          FROM   ORDERS WITH (NOLOCK)    
   --       JOIN   ORDERDETAIL WITH (NOLOCK) ON ORDERS.ORDERKEY = ORDERDETAIL.ORDERKEY
          JOIN   ORDERINFO   WITH (NOLOCK) ON ORDERINFO.ORDERKEY = ORDERS.OrderKey
          LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.Storerkey = ORDERS.StorerKey AND CL.LISTNAME ='ECDLMODE' AND CL.Code = ORDERS.Shipperkey
          WHERE  ORDERS.OrderKey = @c_OrderKey  
      END -- IF @c_OrderKey = ''  

      SELECT @c_ManufacturerSKU   = ISNULL(SKU.ManufacturerSKU,'')
            ,@c_Sku               = SKU.Sku 
            ,@c_Notes             = ORDERDETAIL.Notes               
      FROM   SKU WITH (NOLOCK)  
      JOIN   ORDERDETAIL (NOLOCK) ON ORDERDETAIL.SKU = SKU.SKU AND SKU.STORERKEY = ORDERDETAIL.STORERKEY
      WHERE  SKU.Storerkey = @c_storerkey     
      AND    SKU.SKU = @c_SKU  AND ORDERDETAIL.ORDERKEY = @c_OrderKey
        
      IF @c_Externorderkey   IS NULL SET @c_Externorderkey = ''  
      IF @c_Contact1         IS NULL SET @c_Contact1       = ''  
      IF @c_Notes            IS NULL SET @c_Notes          = ''  
      IF @c_Platform         IS NULL SET @c_Platform       = ''  
      IF @c_UDF02            IS NULL SET @c_UDF02          = '' 

      SET @c_PickheaderKey = ''  
  
      SELECT @c_PickheaderKey = ISNULL(PickHeaderKey, '')   
      FROM PICKHEADER (NOLOCK)   
      WHERE ExternOrderKey = @c_loadkey  
      AND   OrderKey = @c_OrderKey  
      AND   Zone = '3'  

      INSERT INTO #Temp_Pick  
          (  OrderKey        
          ,  ExternOrderKey  
          ,  PickSlipNo      
          ,  [Platform]      
          ,  DeliveryDate    
          ,  C_Contact1      
          ,  Loc             
          ,  SKU             
          ,  ManufacturerSKU 
          ,  Notes           
          ,  Qty             
          ,  UDF02           
          ,  PHBarcode       
          ,  OSBarcode       
          ,  EXTORDBarcode   
          ,  PrintedFlag
          ,  Loadkey               
         )  
      VALUES  
         (  @c_orderkey  
         ,  @c_Externorderkey  
         ,  @c_PickheaderKey  
         ,  @c_Platform  
         ,  @d_DeliveryDate   
         ,  @c_Contact1  
         ,  @c_loc  
         ,  @c_sku  
         ,  @c_ManufacturerSKU  
         ,  @c_Notes  
         ,  @n_qty  
         ,  @c_UDF02   
         ,  dbo.fn_Encode_IDA_Code128 (@c_PickheaderKey)
         ,  dbo.fn_Encode_IDA_Code128 (@c_orderkey)
         ,  dbo.fn_Encode_IDA_Code128 (@c_ExternOrderKey)
         ,  @c_PrintedFlag
         ,  @c_loadkey   
         )  
                   
      FETCH NEXT FROM CUR_PICK INTO @c_Orderkey  
                                 ,  @c_Storerkey  
                                 ,  @c_Sku  
                                 ,  @c_loc  
                                 ,  @c_UOM  
                                 ,  @c_ID  
                                 ,  @n_Qty  
                                 ,  @c_Logicalloc  
  
               
   END  
         
   CLOSE CUR_PICK     
   DEALLOCATE CUR_PICK     
  
   SELECT @n_PS_required = Count(DISTINCT OrderKey)   
   FROM #TEMP_PICK  
   WHERE PickSlipNo IS NULL OR RTrim(PickSlipNo) = ''  
  
   IF @n_PS_required > 0  
   BEGIN  
      EXECUTE nspg_GetKey 'PICKSLIP'  
                        , 9  
                        , @c_NextNo    OUTPUT  
                        , @b_success   OUTPUT  
                        , @n_err       OUTPUT  
                        , @c_errmsg    OUTPUT  
                        , 0  
                        , @n_PS_required  
      IF @b_success <> 1   
         GOTO FAILURE   
        
        
      SET @c_OrderKey = ''  
      DECLARE CUR_PS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT OrderKey  
      FROM   #TEMP_PICK   
      WHERE  PickSlipNo IS NULL OR RTrim(PickSlipNo) = ''  
   
      ORDER BY OrderKey  
  
      OPEN CUR_PS  
        
      FETCH NEXT FROM CUR_PS INTO @c_Orderkey  
                 
      WHILE (@@FETCH_STATUS <> -1)  
      BEGIN  
         IF @c_OrderKey IS NULL OR RTrim(@c_OrderKey) = ''  
         BEGIN  
            BREAK  
         END   
  
         IF NOT EXISTS(SELECT 1 FROM PICKHEADER (NOLOCK) WHERE OrderKey = @c_OrderKey)  
         BEGIN  
            SET @c_PickheaderKey = 'P' + @c_NextNo   
            SET @c_NextNo = RIGHT ( '000000000' + CONVERT(NVARCHAR(9), CONVERT(INT, @c_NextNo) + 1), 9)  
              
            BEGIN TRAN  
            INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)  
            VALUES (@c_PickheaderKey, @c_OrderKey, @c_LoadKey, '0', '3', '')  
              
            SET @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN  
               IF @@TRANCOUNT >= 1  
               BEGIN  
                  ROLLBACK TRAN  
                  GOTO FAILURE  
               END  
            END  
            ELSE  
            BEGIN  
               IF @@TRANCOUNT > 0  
               BEGIN  
                  COMMIT TRAN  
               END  
               ELSE  
               BEGIN  
                  ROLLBACK TRAN  
                  GOTO FAILURE  
               END  
            END -- @n_err <> 0  
         END -- NOT Exists    
        
         FETCH NEXT FROM CUR_PS INTO @c_Orderkey       
      END   -- WHILE  
      CLOSE CUR_PS  
      DEALLOCATE CUR_PS  
  
      UPDATE #TEMP_PICK   
      SET PickSlipNo = PICKHEADER.PickHeaderKey  
      FROM  PICKHEADER (NOLOCK)  
      WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey  
      AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey  
      AND   PICKHEADER.Zone = '3'  
      AND   (#TEMP_PICK.PickSlipNo IS NULL OR RTRIM(#TEMP_PICK.PickSlipNo) = '')    --(Wan01)  
      --AND   #TEMP_PICK.PickSlipNo IS NULL OR RTrim(#TEMP_PICK.PickSlipNo) = ''  --(Wan01)  
   END  
   GOTO SUCCESS  
  
   FAILURE:  
      DELETE FROM #TEMP_PICK  
  
   SUCCESS:  
      IF ( SELECT COUNT(DISTINCT StorerKey)   
           FROM  ORDERS WITH (NOLOCK)  
           JOIN  LOADPLANDETAIL(NOLOCK) ON (LOADPLANDETAIL.OrderKey = ORDERS.OrderKey)   
           WHERE LOADPLANDETAIL.LoadKey = @c_loadkey ) = 1  
      BEGIN   
         -- Only 1 storer found  
         SET @c_StorerKey = ''  
  
         SELECT TOP 1 @c_StorerKey = ORDERS.StorerKey   
         FROM  ORDERS WITH (NOLOCK)  
         JOIN  LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLANDETAIL.OrderKey = ORDERS.OrderKey)   
         WHERE     LOADPLANDETAIL.LoadKey = @c_loadkey  
        
         IF EXISTS (SELECT 1 FROM STORERCONFIG WITH (NOLOCK) WHERE CONFIGKEY = 'AUTOSCANIN' AND  
                    SValue = '1' AND StorerKey = @c_StorerKey)  
         BEGIN   
            -- Configkey is setup  
            DECLARE CUR_PI CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT PickSlipno  
            FROM   #TEMP_PICK   
            WHERE  PickSlipNo IS NOT NULL OR RTrim(PickSlipNo) <> ''  
         
            ORDER BY OrderKey  
  
            OPEN CUR_PI  
              
            FETCH NEXT FROM CUR_PI INTO @c_PickSlipno  
                       
            WHILE (@@FETCH_STATUS <> -1)  
            BEGIN  
                
               IF NOT EXISTS(SELECT 1 FROM PICKINGINFO WITH(NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)  
               BEGIN  
                  INSERT INTO PICKINGINFO  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)  
                  VALUES (@c_PickSlipNo, GetDate(), sUser_sName(), NULL)  
               END    
               FETCH NEXT FROM CUR_PI INTO @c_PickSlipno          
            END  
         CLOSE CUR_PI  
         DEALLOCATE CUR_PI  
         END -- Configkey is setup  

      END -- Only 1 storer found  

      DECLARE CUR_psno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT PICKSLIPNO,ORDERKEY
      FROM #temp_pick
      WHERE LOADKEY = @c_Loadkey
      
      OPEN CUR_psno
      
      FETCH NEXT FROM CUR_psno INTO @c_Pickslipno, @c_Orderkey
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         INSERT INTO #temp_pick1
		   (OrderKey, ExternOrderKey, PickSlipNo, [Platform], DeliveryDate, C_Contact1, Loc,SKU,ManufacturerSKU,
         Notes,Qty,UDF02,PHBarcode,OSBarcode,EXTORDBarcode,PrintedFlag,Loadkey,Recgroup,ShowNo)
         SELECT OrderKey,ExternOrderKey,PickSlipNo,[Platform],DeliveryDate,C_Contact1,Loc,SKU,ManufacturerSKU,
         Notes,Qty,UDF02,PHBarcode,OSBarcode,EXTORDBarcode,PrintedFlag,Loadkey,(Row_Number() OVER (PARTITION BY PickSlipNo,ORDERKEY  ORDER BY PickSlipNo,Orderkey,Loc Asc)-1)/@n_MaxLineno+1 AS recgroup
          ,'Y'
         FROM #temp_pick WHERE PickSlipNo = @c_Pickslipno AND ORDERKEY =  @c_Orderkey
      
         SELECT @n_MaxRec = COUNT(rowid) from #temp_pick WHERE PickSlipNo = @c_Pickslipno AND ORDERKEY =  @c_Orderkey
      
         SET @n_CurrentRec = @n_MaxRec % @n_MaxLineno
      
         WHILE(@n_MaxRec % @n_MaxLineno <> 0 AND @n_CurrentRec < @n_MaxLineno)
         BEGIN
            INSERT INTO #temp_pick1
		      (OrderKey,ExternOrderKey,PickSlipNo,[Platform],DeliveryDate,C_Contact1,
            UDF02,PHBarcode,OSBarcode,EXTORDBarcode,PrintedFlag,Loadkey,Recgroup,ShowNo)

            SELECT TOP 1 OrderKey,ExternOrderKey,PickSlipNo,[Platform],DeliveryDate,C_Contact1,
            UDF02,PHBarcode,OSBarcode,EXTORDBarcode,PrintedFlag,Loadkey, RECGROUP,'N'
             FROM #temp_pick1 WHERE PickSlipNo = @c_Pickslipno AND ORDERKEY =  @c_Orderkey
             ORDER BY ROWID DESC
       
             SET @n_CurrentRec = @n_CurrentRec + 1
          END

          SET @n_MaxRec = 0
          SET @n_CurrentRec = 0
       
          FETCH NEXT FROM CUR_psno INTO @c_Pickslipno, @c_Orderkey
       END
       CLOSE CUR_psno
       DEALLOCATE CUR_psno

      SELECT    OrderKey        
             ,  ExternOrderKey  
             ,  PickSlipNo      
             ,  [Platform]      
             ,  DeliveryDate    
             ,  C_Contact1      
             ,  Loc             
             ,  SKU             
             ,  ManufacturerSKU 
             ,  Notes           
             ,  Qty             
             ,  UDF02           
             ,  PHBarcode       
             ,  OSBarcode       
             ,  EXTORDBarcode
             ,  @c_RptLogo
             ,  ShowNo   
             ,  PrintedFlag
             ,  Loadkey
			 --START ML01
			 ,  @c_H01
			 ,  @c_H02
			 ,  @c_D01
			 ,  @c_D02
			 ,  @c_D03
			 ,  @c_D04
			 ,  @c_D05
			 ,  @c_D06
			 ,  @c_D07
			 ,  @c_D08
			 ,  @c_D09
			 ,  @c_D10
			 ,  @c_D11
			 ,  @c_D12
			 ,  @c_D13
			 ,  @c_D14
			 ,  @c_QRCODE
			 --END ML01
      FROM #TEMP_PICK1    
      ORDER BY ROWID
            ,  Orderkey  
            ,  Loc   
  
      DROP Table #TEMP_PICK    
 QUIT_RESULT: 
 END  


GO