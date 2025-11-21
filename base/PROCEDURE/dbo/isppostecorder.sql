SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store Procedure:  ispPostECOrder                                     */    
/* Creation Date:  01-Aug-2008                                          */    
/* Copyright: IDS                                                       */    
/* Written by:  Shong                                                   */    
/*                                                                      */    
/* Purpose:  Post EC Orders to WMS Orders Table                         */    
/*                                                                      */    
/* Input Parameters:  @n_ECOrderNo                                      */    
/*                                                                      */    
/* Output Parameters:  None                                             */    
/*                                                                      */    
/* Return Status:  None                                                 */    
/*                                                                      */    
/* Usage:                                                               */    
/*                                                                      */    
/* Local Variables:                                                     */    
/*                                                                      */    
/* Called By: EWMS                                                      */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Purposes                                      */    
/************************************************************************/    
CREATE PROC [dbo].[ispPostECOrder] (    
   @n_ECOrderNo int,     
   @c_OrderKey   nvarchar(10) OUTPUT,    
   @b_Success    int OUTPUT,    
   @n_err        int OUTPUT,    
   @c_errmsg     nvarchar(215) OUTPUT)    
AS     
BEGIN    
   SET NOCOUNT ON    
    
   DECLARE @c_rdsOrderLineNo  nvarchar(10),     
           @c_PackIndicator   nvarchar(18),     
           @c_ExternLineNo    nvarchar(10),     
           @n_UOMQty          int,     
           @c_UOM             nvarchar(10),    
           @c_ExternOrderKey  nvarchar(20),    
           @c_StorerKey       nvarchar(15),    
           @c_Status          nvarchar(10),    
           @c_LoadKey         nvarchar(10),    
           @c_SKU             nvarchar(20),    
           @n_Qty             int,    
           @n_CaseCnt         int,  
           @n_InnerPack       int,  
           @n_UnitPrice       float,  
           @n_ExtendedPrice   float,  
           @n_OrderLineNumber int,    
           @c_OrderLineNumber nvarchar(5),    
           @c_PackUOM3        char(10),    
           @c_PackUOM1        char(10),    
           @c_PackUOM2        char(10),    
           @c_PackUOM         char(10),    
           @c_PackKey         char(10),    
           @n_Continue        int,     
           @n_StartTCnt       int,                
           @c_BuyerPO         nvarchar(20),     
           @c_SectionKey      nvarchar(10)     
    
   SET @n_StartTCnt=@@TRANCOUNT     
   SET @n_Continue=1     
   SET @b_success = 1  
  
   BEGIN TRAN     
    
   SET @c_OrderKey = ''    
   SELECT @c_OrderKey       = OrderKey,     
          @c_ExternOrderKey = ExternOrderKey,    
          @c_StorerKey      = StorerKey,     
          @c_BuyerPO        = BuyerPO  
   FROM EC_Orders WITH (NOLOCK)     
 WHERE EC_OrderNo = @n_ECOrderNo     
    
   IF ISNULL( RTRIM(@c_OrderKey), '') = ''    
   BEGIN    
      SELECT @c_OrderKey  = OrderKey    
      FROM   ORDERS WITH (NOLOCK)    
      WHERE  StorerKey = @c_StorerKey    
      AND    ExternOrderKey = @c_ExternOrderKey     
      AND    BuyerPO        = @c_BuyerPO     
      AND    STATUS NOT IN ('9','CANC')  -- To skip the Shipped or Cancel orders added by Ricky July 1st, 2008    
   END    
     
   IF ISNULL( RTRIM(@c_OrderKey), '') <> ''    
   BEGIN     
      IF EXISTS(SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE OrderKey = @c_OrderKey )    
      BEGIN    
         SELECT @c_Status  = ORDERS.Status,    
                @c_LoadKey = ISNULL(LPD.LoadKey, ''),    
                @c_ExternOrderKey = ISNULL(ORDERS.ExternOrderKey, '')     
         FROM ORDERS WITH (NOLOCK)     
         LEFT OUTER JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON LPD.OrderKey = ORDERS.OrderKey     
         WHERE ORDERS.OrderKey = @c_OrderKey     
             
         IF (@c_Status BETWEEN '1' AND '9') OR (@c_Status = 'CANC')    
         BEGIN    
            SET @b_success = 0    
            SET @n_err = 60001    
            SET @c_errmsg = 'PO # :' + RTRIM(@c_ExternOrderKey) + ' Already Processed/Cancel. No Update Allow'    
            GOTO QUIT     
         END     
    
         DELETE ORDERS     
         WHERE  OrderKey = @c_OrderKey    
         SET @n_Err = @@ERROR    
         IF @n_Err <> 0     
         BEGIN    
            SET @n_Continue = 3    
            SET @b_success = 0    
            SET @n_err = 60002   
            SET @c_ErrMsg = 'Delete ORDERS Failed!'    
            GOTO QUIT    
         END    
      END     
   END     
    
   IF ISNULL( RTRIM(@c_OrderKey), '') = ''     
   BEGIN    
      -- get Next Order Number from nCounter    
      SET @b_success = 1    
    
      EXECUTE dbo.nspg_getkey     
          'ORDER' ,     
           10 ,     
           @c_Orderkey OUTPUT ,     
           @b_success  OUTPUT,     
           @n_err      OUTPUT,     
           @c_errmsg   OUTPUT     
    
   END    
    
   IF NOT EXISTS(SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE OrderKey = @c_OrderKey)    
   BEGIN     
      -- This is New Orders    
      INSERT INTO [ORDERS]    
           ([OrderKey]           ,[StorerKey]           ,[ExternOrderKey]    
           ,[Facility]           ,[OrderDate]           ,[DeliveryDate]    
           ,[Priority]           ,[ConsigneeKey]        ,[C_Contact1]    
           ,[C_Contact2]         ,[C_Company]           ,[C_Address1]    
           ,[C_Address2]         ,[C_Address3]          ,[C_Address4]    
           ,[C_City]             ,[C_State]             ,[C_Zip]    
           ,[C_Country]          ,[C_ISOCntryCode]      ,[C_Phone1]    
           ,[C_Phone2]           ,[C_Fax1]              ,[C_Fax2]    
           ,[C_vat]              ,[BuyerPO]             ,[BillToKey]    
           ,[B_contact1]         ,[B_Contact2]          ,[B_Company]    
           ,[B_Address1]         ,[B_Address2]          ,[B_Address3]    
           ,[B_Address4]         ,[B_City]              ,[B_State]    
           ,[B_Zip]              ,[B_Country]           ,[B_ISOCntryCode]    
           ,[B_Phone1]           ,[B_Phone2]            ,[B_Fax1]    
           ,[B_Fax2]             ,[B_Vat]               ,[MarkforKey]    
           ,[M_Contact1]         ,[M_Contact2]          ,[M_Company]    
           ,[M_Address1]         ,[M_Address2]          ,[M_Address3]    
           ,[M_Address4]         ,[M_City]              ,[M_State]    
           ,[M_Zip]              ,[M_Country]           ,[M_ISOCntryCode]    
           ,[M_Phone1]           ,[M_Phone2]            ,[M_Fax1]    
           ,[M_Fax2]             ,[M_vat]               ,[IncoTerm]    
           ,[PmtTerm]            ,[OpenQty]                 
           ,[Status]             ,[DischargePlace]      ,[DeliveryPlace]    
           ,[IntermodalVehicle]  ,[CountryOfOrigin]     ,[CountryDestination]    
           ,[UpdateSource]       ,[Type]                ,[OrderGroup]    
           ,[Door]               ,[Route]               ,[Stop]    
           ,[Notes]              ,[Notes2]              ,[ContainerType]    
           ,[ContainerQty]       ,[BilledContainerQty]  ,[SOStatus]    
           ,[InvoiceNo]          ,[InvoiceAmount]       ,[Salesman]    
           ,[GrossWeight]        ,[Capacity]            ,[PrintFlag]    
           ,[Rdd]                ,[SequenceNo]          ,[Rds]    
           ,[SectionKey]         ,[PrintDocDate]        ,[LabelPrice]    
           ,[POKey]              ,[ExternPOKey]         ,[XDockFlag]    
           ,[UserDefine01]       ,[UserDefine02]        ,[UserDefine03]    
           ,[UserDefine04]       ,[UserDefine05]        ,[UserDefine06]    
           ,[UserDefine07]       ,[UserDefine08]        ,[UserDefine09]    
           ,[UserDefine10]       ,[Issued]              ,[DeliveryNote]    
           ,[PODCust]            ,[PODArrive]           ,[PODReject]    
           ,[PODUser]            ,[XDockPOKey]          ,[SpecialHandling]    
           ,[RoutingTool]        )    
      SELECT @c_OrderKey         ,[StorerKey]           ,[ExternOrderKey]    
           ,[Facility]           ,[OrderDate]           ,[DeliveryDate]   
           ,[Priority]           ,[ConsigneeKey]        ,[C_Contact1]    
           ,'' 'C_Contact2'      ,[C_Company]           ,[C_Address1]    
           ,[C_Address2]         ,[C_Address3]          ,[C_Address4]    
           ,[C_City]             ,[C_State]             ,[C_Zip]    
           ,[C_Country]          ,[C_ISOCntryCode]      ,[C_Phone1]    
           ,'' 'C_Phone2'        ,[C_Fax1]              ,'' 'C_Fax2'  
           ,'' AS [C_vat]        ,'' AS [BuyerPO]       ,'' AS [BillToKey]    
           ,'' AS [B_contact1]   ,'' AS [B_Contact2]    ,'' AS [B_Company]    
           ,'' AS [B_Address1]   ,'' AS [B_Address2]    ,'' AS [B_Address3]    
           ,'' AS [B_Address4]   ,'' AS [B_City]        ,'' AS [B_State]    
           ,'' AS [B_Zip]        ,'' AS [B_Country]     ,'' AS [B_ISOCntryCode]    
           ,'' AS [B_Phone1]     ,'' AS [B_Phone2]      ,'' AS [B_Fax1]    
           ,'' AS [B_Fax2]       ,'' AS [B_Vat]         ,'' AS [MarkforKey]    
           ,'' AS [M_Contact1]   ,'' AS [M_Contact2]    ,'' AS [M_Company]    
           ,'' AS [M_Address1]   ,'' AS [M_Address2]    ,'' AS [M_Address3]    
           ,'' AS [M_Address4]   ,'' AS [M_City]        ,'' AS [M_State]    
           ,'' AS [M_Zip]        ,'' AS [M_Country]     ,'' AS [M_ISOCntryCode]    
           ,'' AS [M_Phone1]     ,'' AS [M_Phone2]      ,'' AS [M_Fax1]    
           ,'' AS [M_Fax2]       ,'' AS [M_vat]         ,'' AS [IncoTerm]    
           ,[PmtTerm]            ,0 AS [OpenQty]                 
           ,[Status]             ,[DischargePlace]      ,[DeliveryPlace]    
           ,[IntermodalVehicle]  ,[CountryOfOrigin]     ,[CountryDestination]    
           ,'' AS [UpdateSource] ,[Type]                ,'' AS [OrderGroup]    
           ,'' AS [Door]         ,'' AS [Route]               ,'' AS [Stop]    
           ,[Notes]              ,'' AS [Notes2]              ,'' AS [ContainerType]    
           ,'' AS [ContainerQty] ,'' AS [BilledContainerQty]  ,'' AS [SOStatus]    
           ,'' AS [InvoiceNo]    ,'' AS [InvoiceAmount]       ,'' AS [Salesman]    
           ,'' AS [GrossWeight]  ,'' AS [Capacity]            ,'' AS [PrintFlag]    
           ,'' AS [Rdd]          ,'' AS [SequenceNo]          ,'' AS [Rds]    
           ,'' AS [SectionKey]   ,NULL AS [PrintDocDate]      ,'' AS [LabelPrice]    
           ,'' AS [POKey]        ,'' AS [ExternPOKey]         ,'' AS [XDockFlag]    
           ,'' AS [UserDefine01] ,'' AS [UserDefine02]        ,'' AS [UserDefine03]    
           ,'' AS [UserDefine04] ,'' AS [UserDefine05]        ,'' AS [UserDefine06]    
           ,'' AS [UserDefine07] ,'' AS [UserDefine08]        ,'' AS [UserDefine09]    
           ,'' AS [UserDefine10] ,'' AS [Issued]              ,'' AS [DeliveryNote]    
           ,'' AS [PODCust]      ,'' AS [PODArrive]           ,'' AS [PODReject]    
           ,'' AS [PODUser]      ,'' AS [XDockPOKey]          ,'' AS [SpecialHandling]    
           ,'' AS [RoutingTool]    
      FROM dbo.EC_Orders WITH (NOLOCK)    
      WHERE EC_OrderNo = @n_ECOrderNo     
    
      SET @n_Err = @@ERROR    
      IF @n_Err <> 0     
      BEGIN    
         SET @n_Continue = 3    
         SET @b_success = 0    
         SET @c_ErrMsg = 'Insert ORDERS Failed!'    
         GOTO QUIT    
      END    
      ELSE    
      BEGIN    
         UPDATE EC_Orders    
            SET ORDERKEY = @c_OrderKey, Status='P'   
         WHERE EC_OrderNo = @n_ECOrderNo     
         SET @n_Err = @@ERROR    
         IF @n_Err <> 0     
         BEGIN    
            SET @n_Continue = 3    
            SET @b_success = 0    
            SET @c_ErrMsg = 'UPDATE EC_Orders Failed!'    
            GOTO QUIT    
         END    
      END     
          
      SET @n_OrderLineNumber = 0     
    
      DECLARE Csr_InsertOrderDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT EC_OrderDetNo, ExternLineNo, Sku, OpenQty, UOM, UnitPrice, UnitPrice  
         FROM EC_OrderDet WITH (NOLOCK)    
         WHERE EC_OrderNo = @n_ECOrderNo     
    
      OPEN Csr_InsertOrderDetail     
          
      FETCH NEXT FROM Csr_InsertOrderDetail INTO     
         @c_rdsOrderLineNo, @c_ExternLineNo, @c_SKU, @n_Qty, @c_UOM, @n_UnitPrice, @n_ExtendedPrice   
    
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         SELECT @n_OrderLineNumber = @n_OrderLineNumber + 1    
         SELECT @c_OrderLineNumber = RIGHT(REPLICATE ('0', 5) + RTRIM(Convert(char(5), @n_OrderLineNumber ) ) , 5)    
    
         SELECT @c_PackUOM3 = PACK.PackUOM3,    
                @c_PackUOM1 = PACK.PackUOM1,  
                @c_PackUOM2 = PACK.PackUOM2,   
                @c_PackKey  = PACK.PackKey,  
                @n_CaseCnt  = PACK.CaseCnt,  
                @n_InnerPack = PACK.InnerPack      
         FROM   SKU WITH (NOLOCK)    
         JOIN   PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey     
         WHERE  SKU.StorerKey = @c_StorerKey    
         AND    SKU.SKU = @c_SKU     
  
         SELECT @n_UOMQty = CASE @c_UOM  
                           WHEN 'CS' THEN @n_Qty * @n_CaseCnt   
                           WHEN 'IP' THEN @n_Qty * @n_InnerPack  
                           ELSE @n_Qty  
                         END,   
                @c_PACKUOM = CASE @c_UOM   
                           WHEN 'CS' THEN @c_PackUOM1  
                           WHEN 'IP' THEN @c_PackUOM2  
                           ELSE @c_PackUOM3  
                         END  
    
         INSERT INTO ORDERDETAIL     
               ( OrderKey,     OrderLineNumber,  ExternOrderKey, ExternLineNo,       
                 Sku,          StorerKey,        OpenQty,        UOM,     
                 PackKey,      UnitPrice,        ExtendedPrice)      
         VALUES (    
                 @c_OrderKey,   @c_OrderLineNumber, @c_ExternOrderkey,   @c_rdsOrderLineNo,     
                 @c_SKU,        @c_Storerkey,       @n_UOMQty,           @c_PACKUOM,    
                 @c_PackKey,    @n_UnitPrice,       @n_ExtendedPrice )    
         SET @n_Err = @@ERROR    
         IF @n_Err <> 0     
         BEGIN    
            SET @n_Continue = 3    
            SET @b_success = 0    
            SET @c_ErrMsg = 'Insert ORDERDETAIL Failed!'    
            GOTO QUIT    
         END    
      
         FETCH NEXT FROM Csr_InsertOrderDetail INTO     
            @c_rdsOrderLineNo, @c_ExternLineNo, @c_SKU, @n_Qty, @c_UOM, @n_UnitPrice, @n_ExtendedPrice   
      END -- While Csr_InsertOrderDetail cursor loop    
      CLOSE Csr_InsertOrderDetail    
      DEALLOCATE Csr_InsertOrderDetail    
   END -- If b_success = 1      
    
QUIT:    
   IF @n_continue = 3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_success = 0    
    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPostECOrder'    
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    
      --RAISERROR @n_err @c_errmsg    
      RETURN    
   END    
   ELSE    
   BEGIN    
      WHILE @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN    
   END       
    
END -- Procedure     

GO