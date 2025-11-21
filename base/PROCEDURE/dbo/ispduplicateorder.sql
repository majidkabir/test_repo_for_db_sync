SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispDuplicateOrder                                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
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
/* 20-May-2014  TKLIM      1.1   Added Lottables 06-15                  */
/* 28-Jul-2015  SHONG      1.2   Added Number Of Orders to duplicate    */
/* 27-Feb-2017  TLTING     1.3   Variable Nvarchar                      */
/* 13-May-2020  SHONG      1.4   Adding missing columns                 */
/************************************************************************/
CREATE PROC [dbo].[ispDuplicateOrder]   
 (   
     @cFromOrdKey    Nvarchar(10), 
     @nNo2Duplicate  INT,  
     @bSuccess    int OUTPUT,    
     @nErrNo      int OUTPUT,  
     @cErrMsg     Nvarchar(215) OUTPUT   
 )  
AS  
   SET NOCOUNT ON  
  
   DECLARE @nStartTCnt int  
  
   SELECT @nStartTCnt=@@TRANCOUNT  
  
   IF NOT EXISTS(SELECT 1 FROM ORDERS (NOLOCK) WHERE ORDERKEY = @cFromOrdKey)  
   BEGIN  
      SET @nErrNo = 62999  
      SET @cErrMsg = 'Order Key Not Found!'  
      GOTO SP_EXIT  
   END   
  
   BEGIN TRANSACTION   
  
   DECLARE @cOrderKey NVarchar(10), 
           @nCounter  INT  
  
   SELECT @bSuccess = 1
   SET @nCounter = 0  

   WHILE @nCounter < @nNo2Duplicate
   BEGIN
       EXECUTE nspg_GetKey  
         'ORDER',  
         10,  
         @cOrderKey    OUTPUT,  
         @bSuccess     OUTPUT,  
         @nErrNo       OUTPUT,  
         @cErrMsg      OUTPUT  
      IF NOT @bSuccess = 1  
      BEGIN  
        GOTO SP_EXIT  
      END  
  
     PRINT 'Inserted @cOrderKey: ' + @cOrderKey   
  
     INSERT INTO ORDERS
     (
        OrderKey,          StorerKey,        ExternOrderKey,
        OrderDate,         DeliveryDate,     Priority,
        ConsigneeKey,      C_contact1,       C_Contact2,
        C_Company,         C_Address1,       C_Address2,
        C_Address3,        C_Address4,       C_City,
        C_State,           C_Zip,            C_Country,
        C_ISOCntryCode,    C_Phone1,         C_Phone2,
        C_Fax1,            C_Fax2,           C_vat,
        BuyerPO,           BillToKey,        B_contact1,
        B_Contact2,        B_Company,        B_Address1,
        B_Address2,        B_Address3,       B_Address4,
        B_City,            B_State,          B_Zip,
        B_Country,         B_ISOCntryCode,   B_Phone1,
        B_Phone2,          B_Fax1,           B_Fax2,
        B_Vat,             IncoTerm,         PmtTerm,
        OpenQty,           [Status],         DischargePlace,
        DeliveryPlace,     IntermodalVehicle,CountryOfOrigin,
        CountryDestination,UpdateSource,     [Type],
        OrderGroup,        Door,             [Route],
        [Stop],            Notes,            EffectiveDate,
        ContainerType,     ContainerQty,     BilledContainerQty,
        SOStatus,          MBOLKey,          InvoiceNo,
        InvoiceAmount,     Salesman,         GrossWeight,
        Capacity,          PrintFlag,        LoadKey,
        Rdd,               Notes2,           SequenceNo,     
        Rds,               SectionKey,       Facility,     
        PrintDocDate,      LabelPrice,       POKey,     
        ExternPOKey,       XDockFlag,        UserDefine01,     
        UserDefine02,      UserDefine03,     UserDefine04,     
        UserDefine05,      UserDefine06,     UserDefine07,     
        UserDefine08,      UserDefine09,     UserDefine10,     
        Issued,            DeliveryNote,     PODCust,     
        PODArrive,         PODReject,        PODUser,     
        xdockpokey,        SpecialHandling,  RoutingTool,     
        MarkforKey,        M_Contact1,       M_Contact2,     
        M_Company,         M_Address1,       M_Address2,     
        M_Address3,        M_Address4,       M_City,     
        M_State,           M_Zip,            M_Country,     
        M_ISOCntryCode,    M_Phone1,         M_Phone2,     
        M_Fax1,            M_Fax2,           M_vat,     
        ShipperKey,        DocType,          TrackingNo,     
        ECOM_PRESALE_FLAG, ECOM_SINGLE_Flag, CurrencyCode,     
        RTNTrackingNo,     BizUnit  )
      SELECT @cOrderKey,   StorerKey,        ExternOrderKey,
        OrderDate,         DeliveryDate,     Priority,
        ConsigneeKey,      C_contact1,       C_Contact2,
        C_Company,         C_Address1,       C_Address2,
        C_Address3,        C_Address4,       C_City,
        C_State,           C_Zip,            C_Country,
        C_ISOCntryCode,    C_Phone1,         C_Phone2,
        C_Fax1,            C_Fax2,           C_vat,
        BuyerPO,           BillToKey,        B_contact1,
        B_Contact2,        B_Company,        B_Address1,
        B_Address2,        B_Address3,       B_Address4,
        B_City,            B_State,          B_Zip,
        B_Country,         B_ISOCntryCode,   B_Phone1,
        B_Phone2,          B_Fax1,           B_Fax2,
        B_Vat,             IncoTerm,         PmtTerm,
        OpenQty,           '0' as [Status],  DischargePlace,
        DeliveryPlace,     IntermodalVehicle,CountryOfOrigin,
        CountryDestination,UpdateSource,     [Type],
        OrderGroup,        Door,             [Route],
        [Stop],            Notes,            EffectiveDate,
        ContainerType,     ContainerQty,     BilledContainerQty,
        '0' as SOStatus,   '' as MBOLKey,    InvoiceNo,
        InvoiceAmount,     Salesman,         GrossWeight,
        Capacity,          'N' as PrintFlag, '' as LoadKey,
        Rdd,               Notes2,           SequenceNo,     
        Rds,               SectionKey,       Facility,     
        PrintDocDate,      LabelPrice,       POKey,     
        ExternPOKey,       XDockFlag,        UserDefine01,     
        UserDefine02,      UserDefine03,     UserDefine04,     
        UserDefine05,      UserDefine06,     UserDefine07,     
        UserDefine08,      UserDefine09,     UserDefine10,     
        '' as Issued,      DeliveryNote,     PODCust,     
        PODArrive,         PODReject,        PODUser,     
        XDockPOKey,        SpecialHandling,  RoutingTool,     
        MarkforKey,        M_Contact1,       M_Contact2,     
        M_Company,         M_Address1,       M_Address2,     
        M_Address3,        M_Address4,       M_City,     
        M_State,           M_Zip,            M_Country,     
        M_ISOCntryCode,    M_Phone1,         M_Phone2,     
        M_Fax1,            M_Fax2,           M_vat,     
        ShipperKey,        DocType,          '' AS TrackingNo,     
        ECOM_PRESALE_FLAG, ECOM_SINGLE_Flag, CurrencyCode,     
        RTNTrackingNo,     BizUnit  
      FROM  ORDERS (NOLOCK)  
      WHERE ORDERKEY = @cFromOrdKey  
  
      SELECT @nErrNo = @@ERROR  
      IF @nErrNo = 0   
      BEGIN  
         INSERT INTO ORDERDETAIL(  
                     OrderKey,       OrderLineNumber,    OrderDetailSysId,   
                     ExternOrderKey, ExternLineNo,       Sku,   
                     StorerKey,      ManufacturerSku,    RetailSku,   
                     AltSku,         OriginalQty,        OpenQty,   
                     ShippedQty,     AdjustedQty,        QtyPreAllocated,   
                     QtyAllocated,   QtyPicked,          UOM,   
                     PackKey,        PickCode,           CartonGroup,   
                     Lot,            ID,                 Facility,   
                     Status,         UnitPrice,          Tax01,   
                     Tax02,          ExtendedPrice,      UpdateSource,   
                     Lottable01,     Lottable02,         Lottable03,    Lottable04, Lottable05,
                     Lottable06,     Lottable07,         Lottable08,    Lottable09, Lottable10, 
                     Lottable11,     Lottable12,         Lottable13,    Lottable14, Lottable15,
                     FreeGoodQty,    GrossWeight,        Capacity,      LoadKey,   
                     MBOLKey,        QtyToProcess,       MinShelfLife,   
                     UserDefine01,   UserDefine02,       UserDefine03,   
                     UserDefine04,   UserDefine05,       UserDefine06,   
                     UserDefine07,   UserDefine08,       UserDefine09,   
                     POkey, ExternPOKey)  
         SELECT @cOrderKey,      OrderLineNumber,   OrderDetailSysId,   
                     ExternOrderKey,      ExternLineNo,       Sku,   
                     StorerKey,           ManufacturerSku,    RetailSku,   
                     AltSku,              OriginalQty,        OpenQty,  
                     0 as ShippedQty,     0 as AdjustedQty,   0 as QtyPreAllocated,   
                     0 As QtyAllocated,   0 as QtyPicked,     UOM,   
                     PackKey,             PickCode,           CartonGroup,   
                     Lot,                 ID,                 Facility,   
                     '0' as Status,       UnitPrice,          Tax01,   
                     Tax02,               ExtendedPrice,      UpdateSource,   
                     Lottable01,          Lottable02,         Lottable03,  Lottable04, Lottable05,
                     Lottable06,          Lottable07,         Lottable08,  Lottable09, Lottable10, 
                     Lottable11,          Lottable12,         Lottable13,  Lottable14, Lottable15,
                     FreeGoodQty,         GrossWeight,        Capacity,    '' as LoadKey,   
                     '' as MBOLKey,       QtyToProcess,       MinShelfLife,   
                     UserDefine01,        UserDefine02,       UserDefine03,   
                     UserDefine04,        UserDefine05,       UserDefine06,   
                     UserDefine07,        UserDefine08,       UserDefine09,   
                     POkey,               ExternPOKey  
         FROM  ORDERDETAIL (NOLOCK)  
         WHERE ORDERKEY = @cFromOrdKey  
         AND   ShippedQty = 0   
  
         SELECT @nErrNo = @@ERROR      
         IF @nErrNo <> 0   
         BEGIN  
            SET @cErrMsg = 'INSERT ORDERDETAIL Failed!'   
            GOTO SP_EXIT  
         END     
      END -- Error = 0  
      ELSE  
      BEGIN  
         SET @cErrMsg = 'INSERT ORDER Failed!'
         GOTO SP_EXIT    
      END
      SET @nCounter = @nCounter + 1          
   END  

  
   SP_EXIT:  
  
   IF @nErrNo <> 0  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @bSuccess = 0       
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @nStartTCnt   
         BEGIN  
            ROLLBACK TRAN  
         END  
         ELSE BEGIN  
            WHILE @@TRANCOUNT > @nStartTCnt   
            BEGIN  
               COMMIT TRAN  
            END            
         END  
         EXECUTE nsp_logerror @nErrNo, @cErrMsg, "nspg_getkey"  
         RAISERROR (@cErrMsg, 16, 1) WITH SETERROR    -- SQL2012  
         RETURN  
      END  
      ELSE BEGIN  
      SELECT @bSuccess = 1  
      WHILE @@TRANCOUNT > @nStartTCnt   
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END

GO