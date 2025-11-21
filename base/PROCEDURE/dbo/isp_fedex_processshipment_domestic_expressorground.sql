SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* SP: isp_FedEx_ProcessShipment_Domestic_ExpressOrGround               */
/* Creation Date: 01 Nov 2011                                           */
/* Copyright: IDS                                                       */
/* Written by: Chee Jun Yan                                             */
/*                                                                      */
/* Purpose: Send Express/Domestic ProcessShipment Web Service Request to*/
/*          FedEx (SOS#226262)                                          */  
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver      Purposes                              */
/* 10-Jan-2012  James    1.1      Bug fix (james01)                     */
/* 12-Jan-2012  Chee     1.2      Insert new fields into                */
/*                                CartonShipmentDetail table (Chee01)   */
/* 12-Jan-2012  Chee     1.3      Concatenate Recipient's Address2      */
/*                                and Address3 (Chee02)                 */
/* 20-Jan-2012  Chee     1.4      Break main SELECT statement to        */
/*                                improve performance (Chee03)          */
/* 26-Jan-2012  Chee     1.5      Include package level detail (PLD)    */
/*                                information (Chee04)                  */
/* 09-Feb-2012  Chee     1.6      Set Residential Flag to False when    */
/*                                Orders.B_Vat is empty (Chee05)        */
/* 09-Feb-2012  Chee     1.7      Add debug and FilePath parameter in   */
/*                                isp_CreateShipment_Domestic_          */
/*                                ExpressOrGround (Chee06)              */
/************************************************************************/


CREATE PROC [dbo].[isp_FedEx_ProcessShipment_Domestic_ExpressOrGround]
(    
     @c_UserCrendentialKey       NVARCHAR(30)    
   , @c_UserCredentialPassword   NVARCHAR(30)    
   , @c_ClientAccountNumber      NVARCHAR(18)    
   , @c_ClientMeterNumber        NVARCHAR(18)    
   , @c_PickSlipNo               NVARCHAR(10)    
   , @n_CartonNo                 INT    
   , @c_LabelNo                  NVARCHAR(20)    
   , @b_Success                  INT            OUTPUT    
   , @n_err                      INT            OUTPUT    
   , @c_errmsg                   NVARCHAR(250)   OUTPUT    
   --, @c_Label                  NVARCHAR(MAX)   OUTPUT    
)    
AS    
BEGIN    

   SET ANSI_PADDING ON
   SET ANSI_WARNINGS ON
   SET CONCAT_NULL_YIELDS_NULL ON
   SET ARITHABORT ON

   DECLARE   
      @c_ShipperCompanyName            NVARCHAR(45)
      ,@c_ShipperPhoneNumber           NVARCHAR(30)
      ,@c_ShipperStreetLines           NVARCHAR(50)
      ,@c_ShipperCity                  NVARCHAR(30)
      ,@c_ShipperStateOrProvinceCode   NVARCHAR(30)
      ,@c_ShipperPostalCode            NVARCHAR(30)
      ,@c_RecipientPersonName          NVARCHAR(30)
      ,@c_RecipientCompanyName         NVARCHAR(45)
      ,@c_RecipientStreetLines1        NVARCHAR(45)
      ,@c_RecipientStreetLines2        NVARCHAR(100) --NVARCHAR(45)  --Chee02
      --,@c_RecipientStreetLines3      NVARCHAR(45)                  --Chee02
      ,@c_RecipientCity                NVARCHAR(45)
      ,@c_RecipientStateOrProvinceCode NVARCHAR(45)
      ,@c_RecipientPostalCode          NVARCHAR(18)
      ,@c_RecipientUrbanizationCode    NVARCHAR(45)
      ,@c_RecipientCountryCode         NVARCHAR(2)
      ,@ResidentialFlag                BIT
      ,@c_ResidentialFlag              NVARCHAR(1)
      ,@n_PaymentType                  INT
      ,@c_PmtTerm                      NVARCHAR(2)
      ,@c_PayorAccountNumber           NVARCHAR(18)
      ,@InsuredFlag                    BIT
      ,@c_InsuredFlag                  NVARCHAR(1)
      ,@f_InsuredAmount                FLOAT
      ,@f_WeightValue                  FLOAT
      ,@c_EdiCode                      NVARCHAR(10)
      ,@n_ServiceType                  INT
      ,@c_ServiceType                  NVARCHAR(30)
      ,@n_SpecialServiceTypes          INT
      ,@c_SpecialServiceTypes          NVARCHAR(20)
      ,@c_OptionType                   NVARCHAR(25)
      ,@n_OptionType                   INT    
      --,@c_result                     NVARCHAR(MAX)     -- Chee06
      ,@c_Request                      NVARCHAR(MAX)     -- Chee06    
      ,@c_Reply                        NVARCHAR(MAX)     -- Chee06
      ,@c_vbErrMsg                     NVARCHAR(MAX)
      ,@x_Message                      XML    
      ,@c_TrackingNumber               NVARCHAR(15)
      ,@c_NotificationHighestSeverity  NVARCHAR(10)
      --,@c_NetChargeAmount            NVARCHAR(10)   -- Chee01
      ,@c_OrderKey                     NVARCHAR(10) 
      ,@c_CarrierCode                  NVARCHAR(10)
      ,@c_GroundServiceCode            NVARCHAR(10)
      ,@c_TrackingIdType               NVARCHAR(10)
      ,@c_GroundBarcodeString          NVARCHAR(30)
      ,@c_ServiceCode                  NVARCHAR(5)
      ,@c_FormCode                     NVARCHAR(10)
      ,@c_RoutingCode                  NVARCHAR(10)
      ,@c_ASTRA_Barcode                NVARCHAR(45)
      ,@c_PlannedServiceLevel          NVARCHAR(30)
      ,@c_ServiceTypeDescription       NVARCHAR(45)
      ,@c_SpecialHandlingIndicators    NVARCHAR(30)
      ,@c_DestinationAirportID         NVARCHAR(5)
      ,@c_StorerKey                    NVARCHAR(15)
      ,@c_LoadKey                      NVARCHAR(10)
      ,@c_MbolKey                      NVARCHAR(10)
      ,@c_ExternOrderKey               NVARCHAR(30)
      ,@c_BuyerPO                      NVARCHAR(20)
      ,@c_Common2DBarcode              NVARCHAR(1000)
      ,@f_CartonCube                   FLOAT          -- Chee01
      ,@f_TotalNetCharge               FLOAT          -- Chee01
      ,@f_InsuredValue                 FLOAT          -- Chee01
      ,@c_Facility                     NVARCHAR(5)        -- Chee03
      ,@c_OrderInfo01                  NVARCHAR(30)    -- Chee04
      ,@c_OrderInfo02                  NVARCHAR(30)    -- Chee04
      ,@c_OrderInfo03                  NVARCHAR(30)    -- Chee04
      ,@c_CustomerReferenceValue       NVARCHAR(30)   -- Chee04
      ,@c_PONumberValue                NVARCHAR(30)   -- Chee04
      ,@c_InvoiceNumberValue           NVARCHAR(30)   -- Chee04
      ,@c_UserDefine03                 NVARCHAR(20)    -- Chee04
      ,@c_ConsigneeKey                 NVARCHAR(15)    -- Chee04
      ,@n_debug                        INT            -- Chee06
      ,@c_IniFileDirectory             NVARCHAR(100)  -- Chee06

   -- Chee06
   SELECT @c_IniFileDirectory = LONG
   FROM CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'FEDEX'
     AND Code = 'FilePath'
   
   SET @n_debug = 1

   SET @b_Success = 1     

   SET @f_InsuredAmount  = 0   
   SET @f_WeightValue = 0  
   
   SELECT @c_TrackingNumber = UPC    
   FROM   [dbo].[PackDetail] WITH (NOLOCK)    
   WHERE  [PickSlipNo] = @c_PickSlipNo    
     AND  [CartonNo]   = @n_CartonNo    
     AND  [LabelNo]    = @c_LabelNo    
      
   -- IF already have tracking number, then quit. Else, send request to FedEx.    
   IF ISNULL(@c_TrackingNumber,'') <> ''    
   BEGIN    
      GOTO QUIT    
   END    
   ELSE    
   BEGIN    

/*                                                                         -- Chee03
      SELECT  @c_EdiCode                      = RTRIM(O.M_Phone2)      
            , @c_ShipperCompanyName           = RTRIM(ST.Company)      
            , @c_ShipperPhoneNumber           = RTRIM(F.UserDefine05)      
            , @c_ShipperStreetLines           = RTRIM(F.Descr)      
            , @c_ShipperCity                  = RTRIM(F.UserDefine01)      
            , @c_ShipperStateOrProvinceCode   = RTRIM(F.UserDefine03)      
            , @c_ShipperPostalCode            = RTRIM(F.UserDefine04)      
            , @c_RecipientPersonName          = RTRIM(O.M_Contact1)      
            , @c_RecipientCompanyName         = RTRIM(O.M_Company)      
            , @c_RecipientStreetLines1        = RTRIM(O.M_Address1)      
            , @c_RecipientStreetLines2        = RTRIM(O.M_Address2) + ' ' + RTRIM(O.M_Address3)   -- Chee02   
          --, @c_RecipientStreetLines3        = RTRIM(O.M_Address3)                               -- Chee02
            , @c_RecipientUrbanizationCode    = RTRIM(O.M_Address4)      
            , @c_RecipientCity                = RTRIM(O.M_City)      
            , @c_RecipientStateOrProvinceCode = RTRIM(O.M_State)      
            , @c_RecipientPostalCode          = RTRIM(O.M_Zip)      
            , @c_RecipientCountryCode         = LEFT(RTRIM(O.M_Country),2)      
            , @c_PmtTerm                      = RTRIM(O.PmtTerm)      
            , @c_PayorAccountNumber           = RTRIM(O.B_Fax2)      
            , @c_InsuredFlag                  = SUBSTRING(O.B_Fax1,2,1)   -- 'Y', 'N'      
            , @c_ResidentialFlag              = RTRIM(O.B_Vat)     -- 'Y', 'N'      
            , @c_OrderKey                     = RTRIM(O.OrderKey)  --, @c_OrderKey = RTRIM(PAH.OrderKey)  
            , @c_StorerKey                    = RTRIM(O.StorerKey)  
            , @c_LoadKey                      = RTRIM(O.LoadKey)  
            , @c_MbolKey                      = RTRIM(O.MbolKey)  
            , @c_ExternOrderKey               = RTRIM(O.ExternOrderKey)  
            , @c_BuyerPO                      = RTRIM(O.BuyerPO)  
      FROM [dbo].[PACKDETAIL]   PAD WITH (NOLOCK)      
      JOIN [dbo].[PACKHEADER]   PAH WITH (NOLOCK) ON (PAD.PickSlipNO = PAH.PickSlipNO)      
    --JOIN [dbo].[ORDERS]        O  WITH (NOLOCK) ON (PAH.OrderKey = O.OrderKey)      
    --JOIN [dbo].[ORDERDETAIL]   OD WITH (NOLOCK) ON ((PAH.Consigneekey = OD.consoorderkey AND ISNULL(OD.Consoorderkey,'')<>'') OR PAH.Orderkey = OD.Orderkey )      
      JOIN [dbo].[ORDERDETAIL]   OD WITH (NOLOCK) ON ((PAH.consoorderkey = OD.consoorderkey AND ISNULL(OD.Consoorderkey,'')<>'') OR PAH.Orderkey = OD.Orderkey )      --james01
      JOIN [dbo].[ORDERS]        O  WITH (NOLOCK) ON (O.Orderkey = OD.OrderKey)
      JOIN [dbo].[FACILITY]      F  WITH (NOLOCK) ON (O.Facility = F.Facility)      
      JOIN [dbo].[STORER]       ST  WITH (NOLOCK) ON (PAD.StorerKey = ST.StorerKey)      
      JOIN [dbo].[SKU]          SK  WITH (NOLOCK) ON (SK.StorerKey = PAD.StorerKey AND SK.SKU = PAD.SKU)      
      WHERE  PAD.PickSlipNo = @c_PickSlipNo       
         AND PAD.CartonNo   = @n_CartonNo       
         AND PAD.LabelNo    = @c_LabelNo      
      GROUP BY O.M_Phone2, ST.Company, F.UserDefine05, F.Descr, F.UserDefine01, F.UserDefine03, F.UserDefine04,   
      O.M_Contact1, O.M_Company, O.M_Address1 , O.M_Address2, O.M_Address3, O.M_Address4, O.M_City, O.M_State, O.M_Zip, O.M_Country,   
      O.PmtTerm, O.B_Fax2, O.B_FAX1, O.B_Vat, O.OrderKey, O.StorerKey, O.LoadKey, O.MbolKey, O.ExternOrderKey, O.BuyerPO 
*/

      -- Chee03
      SELECT TOP 1 @c_StorerKey = PAD.StorerKey                        
            , @c_OrderKey  = OD.OrderKey  
      FROM [dbo].[PACKDETAIL]   PAD WITH (NOLOCK)      
      JOIN [dbo].[PACKHEADER]   PAH WITH (NOLOCK) ON (PAD.PickSlipNO = PAH.PickSlipNO)    
      JOIN [dbo].[ORDERDETAIL]   OD WITH (NOLOCK) ON ((PAH.consoorderkey = OD.consoorderkey AND ISNULL(OD.Consoorderkey,'')<>'') OR PAH.Orderkey = OD.Orderkey )      --james01
      WHERE  PAD.PickSlipNo = @c_PickSlipNo       
         AND PAD.CartonNo   = @n_CartonNo       
         AND PAD.LabelNo    = @c_LabelNo   

      -- Chee03
      SELECT @c_ShipperCompanyName = RTRIM(ST.Company)
      FROM [dbo].[STORER] ST WITH (NOLOCK) 
      WHERE ST.Storerkey = @c_StorerKey

      -- Chee03
      SELECT  @c_EdiCode                      = RTRIM(O.M_Phone2)         
            , @c_RecipientPersonName          = RTRIM(O.M_Contact1)      
            , @c_RecipientCompanyName         = RTRIM(O.M_Company)      
            , @c_RecipientStreetLines1        = RTRIM(O.M_Address1)      
            , @c_RecipientStreetLines2        = RTRIM(O.M_Address2) + ' ' + RTRIM(O.M_Address3)   -- Chee02   
            , @c_RecipientUrbanizationCode    = RTRIM(O.M_Address4)      
            , @c_RecipientCity                = RTRIM(O.M_City)      
            , @c_RecipientStateOrProvinceCode = RTRIM(O.M_State)      
            , @c_RecipientPostalCode          = RTRIM(O.M_Zip)      
            , @c_RecipientCountryCode         = LEFT(RTRIM(O.M_Country),2)      
            , @c_PmtTerm                      = RTRIM(O.PmtTerm)      
            , @c_PayorAccountNumber           = RTRIM(O.B_Fax2)      
            , @c_InsuredFlag                  = SUBSTRING(O.B_Fax1,2,1)   -- 'Y', 'N'      
            , @c_ResidentialFlag              = RTRIM(O.B_Vat)     -- 'Y', 'N'      
            , @c_OrderKey                     = RTRIM(O.OrderKey)  --, @c_OrderKey = RTRIM(PAH.OrderKey)  
            , @c_StorerKey                    = RTRIM(O.StorerKey)  
            , @c_LoadKey                      = RTRIM(O.LoadKey)  
            , @c_MbolKey                      = RTRIM(O.MbolKey)  
            , @c_ExternOrderKey               = RTRIM(O.ExternOrderKey)  
            , @c_BuyerPO                      = RTRIM(O.BuyerPO)  
            , @c_Facility                     = O.Facility
            , @c_UserDefine03                 = RTRIM(O.UserDefine03)   -- Chee04
            , @c_ConsigneeKey                 = RTRIM(O.ConsigneeKey)   -- Chee04
      FROM [dbo].[ORDERS] O WITH (NOLOCK)
      WHERE O.OrderKey = @c_OrderKey

      -- Chee03
      SELECT  @c_ShipperPhoneNumber           = RTRIM(F.UserDefine05)      
            , @c_ShipperStreetLines           = RTRIM(F.Descr)      
            , @c_ShipperCity                  = RTRIM(F.UserDefine01)      
            , @c_ShipperStateOrProvinceCode   = RTRIM(F.UserDefine03)      
            , @c_ShipperPostalCode            = RTRIM(F.UserDefine04)   
      FROM [dbo].[FACILITY] F WITH (NOLOCK) 
      WHERE F.Facility = @c_Facility
        
      -- If M recipient info(O.M_Address1, O.M_City, O.M_State & O.Zip) is NULL, use C recipient info
      IF ISNULL(@c_RecipientStreetLines1,'') = '' AND ISNULL(@c_RecipientCity,'') = '' AND
         ISNULL(@c_RecipientStateOrProvinceCode,'') = '' AND ISNULL(@c_RecipientPostalCode,'') = ''
      BEGIN
         SELECT  @c_RecipientPersonName          = RTRIM(O.C_Contact1)    
               , @c_RecipientCompanyName         = RTRIM(O.C_Company)    
               , @c_RecipientStreetLines1        = RTRIM(O.C_Address1)    
               , @c_RecipientStreetLines2        = RTRIM(O.C_Address2) + ' ' + RTRIM(O.C_Address3) -- Chee02
             --, @c_RecipientStreetLines3        = RTRIM(O.C_Address3)                             -- Chee02
               , @c_RecipientUrbanizationCode    = RTRIM(O.C_Address4)    
               , @c_RecipientCity                = RTRIM(O.C_City)    
               , @c_RecipientStateOrProvinceCode = RTRIM(O.C_State)    
               , @c_RecipientPostalCode          = RTRIM(O.C_Zip)  
               , @c_RecipientCountryCode         = LEFT(RTRIM(O.C_Country),2)    
         FROM ORDERS O WITH (NOLOCK)
         WHERE OrderKey = @c_OrderKey
      END

      SELECT @f_CartonCube = SUM(SK.StdCube * PD.Qty)        -- Chee01
           , @f_WeightValue = SUM(PD.Qty * SK.StdGrossWgt)  -- Old Formula: SK.StdGrossWgt * OD.QtyPicked   -- Chee03
      FROM   [dbo].[PackDetail] PD WITH (NOLOCK) 
      JOIN   [dbo].[SKU]        SK WITH (NOLOCK) ON (SK.SKU = PD.SKU)
      WHERE  [PickSlipNo]  = @c_PickSlipNo    
         AND [CartonNo]    = @n_CartonNo    
         AND [LabelNo]     = @c_LabelNo    

      -- Chee04
      SELECT  @c_OrderInfo01 = RTRIM(OrderInfo01)         
            , @c_OrderInfo02 = RTRIM(OrderInfo02)   
            , @c_OrderInfo03 = RTRIM(OrderInfo03)
      FROM  [dbo].[OrderInfo] WITH (NOLOCK)
      WHERE OrderKey = @c_OrderKey

      -- CUSTOMER_REFERENCE (Chee04)
      IF @c_OrderInfo01 = 'DEPT'
      BEGIN
         SET @c_CustomerReferenceValue = @c_UserDefine03
      END
      ELSE IF @c_OrderInfo01 = 'INV'
      BEGIN
         SET @c_CustomerReferenceValue = @c_BuyerPO
      END
      ELSE IF @c_OrderInfo01 = 'PO'
      BEGIN
         SET @c_CustomerReferenceValue = @c_ExternOrderKey
      END
      ELSE IF @c_OrderInfo01 = 'ST'
      BEGIN
         SET @c_CustomerReferenceValue = @c_ConsigneeKey
      END
      ELSE IF @c_OrderInfo01 = 'UCC'
      BEGIN
         SET @c_CustomerReferenceValue = @c_LabelNo
      END

      -- P_O_NUMBER (Chee04)
      IF @c_OrderInfo02 = 'DEPT'
      BEGIN
         SET @c_PONumberValue = @c_UserDefine03
      END
      ELSE IF @c_OrderInfo02 = 'INV'
      BEGIN
         SET @c_PONumberValue = @c_BuyerPO
      END
      ELSE IF @c_OrderInfo02 = 'PO'
      BEGIN
         SET @c_PONumberValue = @c_ExternOrderKey
      END
      ELSE IF @c_OrderInfo02 = 'ST'
      BEGIN
         SET @c_PONumberValue = @c_ConsigneeKey
      END
      ELSE IF @c_OrderInfo02 = 'UCC'
      BEGIN
         SET @c_PONumberValue = @c_LabelNo
      END

      -- INVOICE_NUMBER (Chee04)
      IF @c_OrderInfo03 = 'DEPT'
      BEGIN
         SET @c_InvoiceNumberValue = @c_UserDefine03
      END
      ELSE IF @c_OrderInfo03 = 'INV'
      BEGIN
         SET @c_InvoiceNumberValue = @c_BuyerPO
      END
      ELSE IF @c_OrderInfo03 = 'PO'
      BEGIN
         SET @c_InvoiceNumberValue = @c_ExternOrderKey
      END
      ELSE IF @c_OrderInfo03 = 'ST'
      BEGIN
         SET @c_InvoiceNumberValue = @c_ConsigneeKey
      END
      ELSE IF @c_OrderInfo03 = 'UCC'
      BEGIN
         SET @c_InvoiceNumberValue = @c_LabelNo
      END

      -- EDI CODE    
      IF ISNULL(@c_EdiCode,'') = ''    
      BEGIN    
         SET @b_Success = 0    
         SET @n_err = 75151    
         SET @c_errmsg = 'Orders.M_Phone2 is empty.'    
         GOTO QUIT    
      END    
      ELSE    
      BEGIN    
         -- Add 'FE' infront if not provided    
         --      SET @c_EdiCode = CASE WHEN @c_EdiCode LIKE 'FE%' THEN @c_EdiCode     
         --      ELSE 'FE' + @c_EdiCode END    
         
         -- GET ServiceType, SpecialServiceType, OptionType FROM Codelkup    
         SELECT @c_ServiceType         = Long    
               ,@c_SpecialServiceTypes = Notes    
               ,@c_OptionType          = Notes2    
         FROM Codelkup WITH (NOLOCK)    
         WHERE  LISTNAME = 'FEDEX_EDI'     
            AND Code     = @c_EdiCode    
         
         IF ISNULL(@c_ServiceType,'') = ''    
         BEGIN    
            SET @b_Success = 0    
            SET @n_err = 75152    
            SET @c_errmsg = 'Invalid EDI Code.'    
            GOTO QUIT    
         END    
      END    
      
       /*    
       --------------------------------------------    
             --    Service Type     --    
       --------------------------------------------    
       FEDEX_1_DAY_FREIGHT            = 1      
       FEDEX_2_DAY                    = 2      
       FEDEX_2_DAY_FREIGHT            = 4    
       FEDEX_3_DAY_FREIGHT            = 5    
       FEDEX_EXPRESS_SAVER            = 6    
       FEDEX_GROUND                   = 10    
       FIRST_OVERNIGHT                = 11     
       GROUND_HOME_DELIVERY           = 12    
       INTERNATIONAL_ECONOMY          = 13    
       INTERNATIONAL_ECONOMY_FREIGHT  = 14    
       INTERNATIONAL_FIRST            = 15    
       "INTERNATIONAL_GROUND"         = ??     
       INTERNATIONAL_PRIORITY         = 16    
       INTERNATIONAL_PRIORITY_FREIGHT = 17    
       PRIORITY_OVERNIGHT             = 18    
       SMART_POST                     = 19    
       STANDARD_OVERNIGHT             = 20    
       */    
         
      IF @c_ServiceType = 'FEDEX_1_DAY_FREIGHT'    
      BEGIN     
         SET @n_ServiceType = 1    
      END    
      ELSE IF @c_ServiceType = 'FEDEX_2_DAY'    
      BEGIN     
         SET @n_ServiceType = 2    
      END    
      ELSE IF @c_ServiceType = 'FEDEX_2_DAY_FREIGHT'    
      BEGIN     
         SET @n_ServiceType = 4    
      END    
      ELSE IF @c_ServiceType = 'FEDEX_3_DAY_FREIGHT'    
      BEGIN     
         SET @n_ServiceType = 5    
      END     
      ELSE IF @c_ServiceType = 'FEDEX_EXPRESS_SAVER'    
      BEGIN     
         SET @n_ServiceType = 6    
      END    
      ELSE IF @c_ServiceType = 'FEDEX_GROUND'    
      BEGIN     
         SET @n_ServiceType = 10    
      END    
      ELSE IF @c_ServiceType = 'FIRST_OVERNIGHT'    
      BEGIN     
         SET @n_ServiceType = 11    
      END    
      ELSE IF @c_ServiceType = 'GROUND_HOME_DELIVERY'    
      BEGIN     
         SET @n_ServiceType = 12    
      END    
      ELSE IF @c_ServiceType = 'INTERNATIONAL_ECONOMY'    
      BEGIN     
         SET @n_ServiceType = 13    
      END    
      ELSE IF @c_ServiceType = 'INTERNATIONAL_ECONOMY_FREIGHT'    
      BEGIN     
         SET @n_ServiceType = 14    
      END    
      ELSE IF @c_ServiceType = 'INTERNATIONAL_FIRST'    
      BEGIN    
         SET @n_ServiceType = 15    
      END    
      ELSE IF @c_ServiceType = 'INTERNATIONAL_PRIORITY'    
      BEGIN     
         SET @n_ServiceType = 16    
      END    
      ELSE IF @c_ServiceType = 'INTERNATIONAL_PRIORITY_FREIGHT'    
      BEGIN     
         SET @n_ServiceType = 17    
      END    
      ELSE IF @c_ServiceType = 'PRIORITY_OVERNIGHT'    
      BEGIN     
         SET @n_ServiceType = 18   
      END    
      ELSE IF @c_ServiceType = 'SMART_POST'    
      BEGIN     
         SET @n_ServiceType = 19    
      END    
      ELSE IF @c_ServiceType = 'STANDARD_OVERNIGHT'    
      BEGIN     
         SET @n_ServiceType = 20    
      END    
      ELSE    
      BEGIN    
         SET @b_Success = 0    
         SET @n_err = 75153    
         SET @c_errmsg = 'Invalid Service Type.'    
         GOTO QUIT    
      END    
      
       /*    
       --------------------------------------------    
           --   Special Service Type    --    
       --------------------------------------------    
       ALCOHOL                = 0    
       APPOINTMENT_DELIVERY   = 1    
       COD                    = 2    
       DANGEROUS_GOODS        = 3    
       DRY_ICE                = 4    
       NON_STANDARD_CONTAINER = 5    
       PRIORITY_ALERT         = 6    
       SIGNATURE_OPTION       = 7    
       */    
      
      IF @c_SpecialServiceTypes = 'SIGNATURE_OPTION'     
      BEGIN    
         SET @n_SpecialServiceTypes = 7  
            
         /*    
         --------------------------------------------    
            --    Option Type      --    
         --------------------------------------------    
         ADULT                 = 0    
         DIRECT                = 1    
         INDIRECT              = 2    
         NO_SIGNATURE_REQUIRED = 3    
         SERVICE_DEFAULT       = 4    
         */   
          
         IF @c_OptionType = 'ADULT'    
         BEGIN     
            SET @n_OptionType = 0    
         END    
         ELSE IF @c_OptionType = 'DIRECT'     
         BEGIN    
            SET @n_OptionType = 1    
         END    
         ELSE IF @c_OptionType = 'INDIRECT'     
         BEGIN    
            SET @n_OptionType = 2    
         END    
         ELSE IF @c_OptionType = 'NO_SIGNATURE_REQUIRED'     
         BEGIN    
            SET @n_OptionType = 3     
         END    
         ELSE IF @c_OptionType = 'SERVICE_DEFAULT'     
         BEGIN    
            SET @n_OptionType = 4    
         END    
         ELSE    
         BEGIN    
            SET @b_Success = 0    
            SET @n_err = 75154    
            SET @c_errmsg = 'Invalid Option Type.'    
            GOTO QUIT    
         END    
      END    
      ELSE IF ISNULL(@c_SpecialServiceTypes,'') = ''    
      BEGIN    
         SET @n_SpecialServiceTypes = -1    
         SET @n_OptionType = -1    
      END    
      ELSE    
      BEGIN    
         SET @b_Success = 0    
         SET @n_err = 75155    
         SET @c_errmsg = 'Invalid Special Service Type.'    
         GOTO QUIT    
      END     
      
      -- If PayorAccountNumber IS NULL AND PmtTerm = 'PP' OR 'PC', THEN SET PayotAccountNumber to ClientAccountNumber    
      IF ISNULL(@c_PayorAccountNumber,'') = ''    
      BEGIN    
         IF @c_PmtTerm = 'PP' OR @c_PmtTerm = 'PC'    
         BEGIN    
            SET @c_PayorAccountNumber = @c_ClientAccountNumber    
         END    
         -- PmtTerm = 'CC' do not need a Payor Account
         ELSE IF @c_PmtTerm <> 'CC'
         BEGIN    
            SET @b_Success = 0    
            SET @n_err = 75156    
            SET @c_errmsg = 'Payor Account is empty.'    
            GOTO QUIT    
         END    
      END    
      
      /*    
      --------------------------------------------    
          --    Payment Type     --    
      --------------------------------------------    
      ACCOUNT     = 0    
      COLLECT     = 1    
      RECIPIENT   = 2    
      SENDER      = 3    
      THIRD_PARTY = 4    
      */    
      
      IF ISNULL(@c_PmtTerm,'') = ''    
      BEGIN    
         SET @b_Success = 0    
         SET @n_err = 75157    
         SET @c_errmsg = 'Payment Type is empty.'    
         GOTO QUIT    
      END    
      ELSE    
      BEGIN    
         -- SET Payment Type    
         IF @c_PmtTerm = 'CC'    
         BEGIN    
            IF @c_ServiceType = 'FEDEX_GROUND'    
            BEGIN    
               SET @n_PaymentType = 1     
            END    
            ELSE    
            BEGIN    
               SET @b_Success = 0    
               SET @n_err = 75158    
               SET @c_errmsg = 'FedEx only allows shipment with PaymentType: COLLECT to be sent for ServiceType: FEDEX_GROUND.'    
               GOTO QUIT    
            END    
         END     
         ELSE IF @c_PmtTerm = 'BP'    
         BEGIN    
            SET @n_PaymentType = 2     
         END     
         ELSE IF @c_PmtTerm = 'PP' OR @c_PmtTerm = 'PC'    
         BEGIN    
            SET @n_PaymentType = 3     
            --SET @c_PayorAccountNumber = @c_ClientAccountNumber    
         END    
         ELSE IF @c_PmtTerm = 'TP'    
         BEGIN    
            SET @n_PaymentType = 4     
         END    
         ELSE     
         BEGIN    
            SET @b_Success = 0    
            SET @n_err = 75159    
            SET @c_errmsg = 'Invalid Payment Type.'    
            GOTO QUIT    
         END    
      END    
      
      -- CHECK InsuredFlag Value    
      IF ISNULL(@c_InsuredFlag,'') = ''    
      BEGIN    
         SET @b_Success = 0    
         SET @n_err = 75160    
         SET @c_errmsg = 'InsuredFlag is empty.'    
         GOTO QUIT    
      END    
      ELSE IF @c_InsuredFlag = 'Y' OR @c_InsuredFlag = '1'    
      BEGIN    
         SET @InsuredFlag = 1    
         
         -- Calculate Insure Amount
         DECLARE 
              @n_Qty AS INT
            , @c_SKU AS NVARCHAR(20)
      
         DECLARE cur_CalculateInsuredAmount CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Qty, SKU
         FROM PACKDETAIL PAD WITH (NOLOCK)
         WHERE   PickSlipNo = @c_PickSlipNo     
            AND  CartonNo   = @n_CartonNo     
            AND  LabelNo    = @c_LabelNo    
         
         OPEN cur_CalculateInsuredAmount 
         
         FETCH NEXT FROM cur_CalculateInsuredAmount INTO @n_Qty, @c_SKU
         
         WHILE @@FETCH_STATUS <> -1
         BEGIN
      
            SELECT TOP(1) @f_InsuredAmount = @f_InsuredAmount + (UnitPrice * @n_Qty)
            FROM ORDERDETAIL WITH (NOLOCK)
            WHERE  OrderKey  = @c_OrderKey 
               AND StorerKey = @c_StorerKey
               AND SKU       = @c_SKU
            
            FETCH NEXT FROM cur_CalculateInsuredAmount INTO @n_Qty, @c_SKU
         END
         CLOSE cur_CalculateInsuredAmount 
         DEALLOCATE cur_CalculateInsuredAmount
      END     
      ELSE IF @c_InsuredFlag = 'N' OR @c_InsuredFlag = '0'    
      BEGIN    
         SET @InsuredFlag = 0    
      END    
      ELSE     
      BEGIN    
         SET @b_Success = 0    
         SET @n_err = 75161    
         SET @c_errmsg = 'Invalid InsuredFlag value.'    
         GOTO QUIT    
      END    
      
      -- CHECK ResidentialFlag Value    
      IF ISNULL(@c_ResidentialFlag,'') = ''    
      BEGIN    
			-- Chee05   
--       SET @b_Success = 0    
--       SET @n_err = 70011    
--       SET @c_errmsg = 'ResidentialFlag is empty.'    
--       GOTO QUIT    

         SET @ResidentialFlag = 0  
      END    
      ELSE IF @c_ResidentialFlag = 'Y' OR @c_ResidentialFlag = '1'    
      BEGIN    
         SET @ResidentialFlag = 1    
      END     
      ELSE IF @c_ResidentialFlag = 'N' OR @c_ResidentialFlag = '0'    
      BEGIN    
         SET @ResidentialFlag = 0    
      END    
      ELSE     
      BEGIN    
         SET @b_Success = 0    
         SET @n_err = 75162    
         SET @c_errmsg = 'Invalid ResidentialFlag value.'    
         GOTO QUIT    
      END    

      -- CHECK IniFileDirectory         -- Chee06
      IF ISNULL(@c_IniFileDirectory,'') = ''
		BEGIN
         SET @b_Success = 0    
         SET @n_err = 75163    
         SET @c_errmsg = 'Config.ini File Path is empty.'    
         GOTO QUIT    
		END
       
--      IF @n_debug = 1    
--      BEGIN      
				-- Chee06 
--         DECLARE 
--             @d_starttime    DATETIME    
--            ,@d_endtime      DATETIME    
--            ,@d_step1        DATETIME    
--            ,@d_step2        DATETIME    
--            ,@d_step3        DATETIME    
--            ,@d_step4        DATETIME    
--            ,@d_step5        DATETIME    
--            ,@c_col1         NVARCHAR(20)    
--            ,@c_col2         NVARCHAR(20)    
--            ,@c_col3         NVARCHAR(20)    
--            ,@c_col4         NVARCHAR(20)    
--            ,@c_col5         NVARCHAR(20)    
--            ,@c_TraceName    NVARCHAR(80)    
--         
--         SET @d_starttime = getdate()    
--         
--         SET @c_TraceName = 'FedExWebService'    
--         
--         SET @d_step1 = GETDATE()
    
--         DECLARE   
--           @d_starttime    datetime      
--         , @d_endtime      datetime    
      
--         SET @d_starttime = getdate() 

--      END    

      EXEC [master].[dbo].[isp_CreateShipment_Domestic_ExpressOrGround]
          @c_IniFileDirectory                -- Chee06
         ,@n_debug                           -- Chee06
         ,@c_UserCrendentialKey         
         ,@c_UserCredentialPassword       
         ,@c_ClientAccountNumber        
         ,@c_ClientMeterNumber        
         ,@n_ServiceType         
         ,@c_ShipperCompanyName        
         ,@c_ShipperPhoneNumber        
         ,@c_ShipperStreetLines        
         ,@c_ShipperCity           
         ,@c_ShipperStateOrProvinceCode    
         ,@c_ShipperPostalCode       
         ,@c_RecipientPersonName       
         ,@c_RecipientCompanyName        
         ,@c_RecipientStreetLines1     
         ,@c_RecipientStreetLines2     
       --,@c_RecipientStreetLines3        -- Chee02     
         ,@c_RecipientCity         
         ,@c_RecipientStateOrProvinceCode    
         ,@c_RecipientPostalCode       
         ,@c_RecipientUrbanizationCode   
         ,@c_RecipientCountryCode        
         ,@ResidentialFlag       
         ,@n_PaymentType           
         ,@c_PayorAccountNumber        
         ,@InsuredFlag             
         ,@f_InsuredAmount         
         ,@f_WeightValue           
         ,@n_SpecialServiceTypes 
         ,@n_OptionType            
         ,@c_CustomerReferenceValue          -- Chee04
         ,@c_PONumberValue                   -- Chee04
         ,@c_InvoiceNumberValue              -- Chee04
         --,@c_result                 OUTPUT -- Chee06
         ,@c_Request                OUTPUT   -- Chee06   
         ,@c_Reply                  OUTPUT   -- Chee06
         ,@c_vbErrMsg               OUTPUT

      IF @@ERROR <> 0 OR ISNULL(@c_vbErrMsg,'') <> '' 
      BEGIN    
         -- SET @b_Success    
         SET @b_Success = 0    
         
         -- SET @n_err    
         IF @@ERROR <> 0    
         BEGIN    
            SET @n_err = @@ERROR    
         END    
         ELSE    
         BEGIN    
            SET @n_err = 75164    
         END    
         
         -- SET @c_errmsg    
         IF ISNULL(@c_vbErrMsg,'') <> ''    
         BEGIN    
            SET @c_errmsg = CAST(@c_vbErrMsg AS NVARCHAR(250))    
         END    
         ELSE    
         BEGIN    
            SET @c_errmsg = 'Error: '+ CAST(@n_err AS NVARCHAR(11)) + ' occurred while executing [master].[dbo].[isp_CreateShipment_Domestic_ExpressOrGround].'     
         END     
         
         GOTO QUIT    
      END
      
--      IF @n_debug = 1    
--      BEGIN       
           -- Chee06
--         SET @d_step1 = GETDATE() - @d_step1    
--         SET @d_endtime = GETDATE()    
--         SET @c_Col1 = @c_LabelNo   
--         INSERT INTO TraceInfo VALUES    
--         (RTRIM(@c_TraceName), @d_starttime, @d_endtime    
--         ,CONVERT(CHAR(12),@d_endtime - @d_starttime ,114)    
--         ,CONVERT(CHAR(12),@d_step1,114)    
--         ,CONVERT(CHAR(12),@d_step2,114)    
--         ,CONVERT(CHAR(12),@d_step3,114)    
--         ,CONVERT(CHAR(12),@d_step4,114)    
--         ,CONVERT(CHAR(12),@d_step5,114)    
--         --,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)    
--         ,@c_Col1    
--         ,@c_col2         
--         ,@c_col3           
--         ,@c_col4         
--         ,@c_Col5)    
--         
--         SET @d_step1 = NULL    
--         SET @d_step2 = NULL    
--         SET @d_step3 = NULL    
--         SET @d_step4 = NULL    
--         SET @d_step5 = NULL    

--         SET @d_endtime = GETDATE() 
--         INSERT INTO [TempFedExProcessShipmentLog] --(LabelNo,[TimeIn],[TimeOut],[TotalTime],[RequestXML],[ReplyXML]) 
--		   VALUES (@c_LabelNo, @d_starttime, @d_endtime, CONVERT(CHAR(12),@d_endtime - @d_starttime ,114), CAST(@c_Request AS XML), CAST(@c_Reply AS XML))
--      END    
      
      -- Chee06
      --SET @x_Message = CAST(@c_result AS XML)    
      SET @x_Message = CAST(@c_Reply AS XML)    

      --SELECT @x_Message     

      -- HIGHEST SEVERITY    
      ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
      SELECT @c_NotificationHighestSeverity = nref.value('ns:HighestSeverity[1]', 'VARCHAR(10)')    
      FROM @X_Message.nodes('/ProcessShipmentReply') AS R(nref)    
      
      IF @c_NotificationHighestSeverity = 'ERROR' OR @c_NotificationHighestSeverity = 'FAILURE'    
      BEGIN    
         -- SET @b_Success, @n_err & @c_errmsg    
         SET @b_Success = 0    
         SET @n_err = 75165    
         SET @c_errmsg = ''    
         
         ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
         SELECT @c_errmsg =     
         --@c_errmsg + 'Severity: ' + nref.value('ns:Severity[1]', 'VARCHAR(10)') +    
         --', ErrMsg: ' + nref.value('ns:Message[1]', 'VARCHAR(100)') + '; '    
         nref.value('ns:Message[1]', 'VARCHAR(100)') + '; '    
         FROM @x_Message.nodes('/ProcessShipmentReply/ns:Notifications') AS R(nref)    
         WHERE nref.value('ns:Severity[1]', 'VARCHAR(10)') = 'ERROR'     
         OR nref.value('ns:Severity[1]', 'VARCHAR(10)') ='FAILURE'    
         
         GOTO QUIT    
      END    
      ELSE    
      BEGIN    
      
         -- IF Datasource Option 1 is empty/null, get from datasource option 2
         IF ISNULL(@f_WeightValue,'') = ''
         BEGIN
            -- get Carton Weight (Datasource Option 2)
            ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
            SELECT @f_WeightValue = nref.value('ns:Value[1]','FLOAT')  
            FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:ShipmentRating/ns:ShipmentRateDetails/ns:TotalBillingWeight') AS n(nref)  
            WHERE nref.value('../ns:RateType[1]','VARCHAR(30)') = 'PAYOR_ACCOUNT_PACKAGE'  
         END
         
         -- IF ISNULL(@f_CartonWeight,'')  = ''
         -- BEGIN
         
         -- IF Carton In/ Carton Out
         -- SELECT @f_CartonWeight = (OD.QtyAllocated + OD.QtyPicked) * SKU.StdGrossWgt * ISNULL(BOM.Qty, 1) * PK.CaseCnt
         -- FROM [dbo].[ORDERDETAIL]    OD    WITH (NOLOCK)
         -- JOIN [dbo].[SKU]          SKU WITH (NOLOCK) ON  (PAD.PickSlipNO = PAH.PickSlipNO) 
         -- JOIN [dbo].[BillOfMaterial] BOM WITH (NOLOCK) ON  (PAD.PickSlipNO = PAH.PickSlipNO) 
         -- JOIN [dbo].[Packkey]        PK    WITH (NOLOCK) ON  (PAD.PickSlipNO = PAH.PickSlipNO) 
         --
         
         -- IF Cluster Pick
         -- SELECT @f_CartonWeight = PD.Qty * SKU.StdGrossWgt * ISNULL(BOM.Qty, 1) * PK.CaseCnt
         -- FROM [dbo].[ORDERDETAIL]    OD    WITH (NOLOCK)
         -- JOIN [dbo].[PACKDETAIL]     PD    WITH (NOLOCK) ON  (OD.SKU = PD.SKU) 
         -- JOIN [dbo].[SKU]          SKU WITH (NOLOCK) ON  (OD.SKU = SKU.SKU) 
         -- JOIN [dbo].[BillOfMaterial] BOM WITH (NOLOCK) ON  (PAD.PickSlipNO = PAH.PickSlipNO) 
         -- JOIN [dbo].[Packkey]        PK    WITH (NOLOCK) ON  (PAD.PickSlipNO = PAH.PickSlipNO) 
         
         -- END

         -- Ground Shipment
         IF @c_ServiceType = 'FEDEX_GROUND' OR @c_ServiceType = 'GROUND_HOME_DELIVERY'
         BEGIN
            
            ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
            SELECT @c_CarrierCode = nref.value('../ns:CarrierCode[1]','VARCHAR(10)') ,
                   @c_ServiceCode = nref.value('ns:ServiceCode[1]','VARCHAR(5)')
            FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:OperationalDetail') AS n(nref)   
            
            ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
            SELECT @c_GroundServiceCode = nref.value('ns:GroundServiceCode[1]','VARCHAR(10)') 
            FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:CompletedPackageDetails/ns:OperationalDetail') AS n(nref)   
            
            ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
            SELECT @c_GroundBarcodeString = nref.value('ns:Value[1]','VARCHAR(30)')
            FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:CompletedPackageDetails/ns:OperationalDetail/ns:Barcodes/ns:StringBarcodes') AS n(nref)   
            WHERE  nref.value('ns:Type[1]','VARCHAR(10)') = 'GROUND'
            
            ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
            SELECT @c_TrackingNumber = nref.value('ns:TrackingNumber[1]','VARCHAR(15)')   ,
                   @c_TrackingIdType = nref.value('ns:TrackingIdType[1]','VARCHAR(10)')   
            FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:CompletedPackageDetails/ns:TrackingIds') AS n(nref)  
            WHERE   nref.value('ns:TrackingIdType[1]','VARCHAR(20)') = 'GROUND'   
            
         END
         -- Express (FEDEX) Shipment 
         ELSE IF @c_ServiceType = 'FIRST_OVERNIGHT' OR @c_ServiceType = 'PRIORITY_OVERNIGHT' OR @c_ServiceType = 'STANDARD_OVERNIGHT' 
         OR @c_ServiceType = 'FEDEX_2_DAY' OR @c_ServiceType = 'FEDEX_EXPRESS_SAVER' 
         BEGIN
         
            ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
            SELECT @c_TrackingNumber = nref.value('ns:TrackingNumber[1]','VARCHAR(15)')   ,
                   @c_TrackingIdType = nref.value('ns:TrackingIdType[1]','VARCHAR(10)')  ,
                   @c_FormCode       = nref.value('ns:FormId[1]','VARCHAR(10)') 
            FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:CompletedPackageDetails/ns:TrackingIds') AS n(nref)  
            WHERE   nref.value('ns:TrackingIdType[1]','VARCHAR(20)') = 'FEDEX'  
            
            ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
            SELECT @c_RoutingCode            = nref.value('ns:UrsaPrefixCode[1]','VARCHAR(4)') + ' ' + nref.value('ns:UrsaSuffixCode[1]','VARCHAR(5)'),
                   @c_PlannedServiceLevel    = nref.value('ns:AstraPlannedServiceLevel[1]','VARCHAR(30)'),
                   @c_ServiceTypeDescription = nref.value('../ns:ServiceTypeDescription[1]','VARCHAR(45)'),
                   @c_DestinationAirportID   = nref.value('ns:AirportId[1]','VARCHAR(5)'),
                   @c_ServiceCode            = nref.value('ns:ServiceCode[1]','VARCHAR(5)')
            FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:OperationalDetail') AS n(nref) 
            
            ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
            SELECT @c_SpecialHandlingIndicators = nref.value('ns:AstraHandlingText[1]','VARCHAR(30)')
            FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:CompletedPackageDetails/ns:OperationalDetail') AS n(nref) 
            
            ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
            SELECT @c_ASTRA_Barcode = nref.value('ns:Value[1]','VARCHAR(45)')
            FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:CompletedPackageDetails/ns:OperationalDetail/ns:Barcodes/ns:StringBarcodes') AS n(nref)  
            WHERE nref.value('ns:Type[1]','VARCHAR(10)') = 'FEDEX_1D'
            
            
            -- IF DataSource Option 1 is empty/null, get from datasource option 2
            
            -- Tracking Number
            IF ISNULL(@c_TrackingNumber,'') =''
            BEGIN
               ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
               SELECT @c_TrackingNumber = REPLACE(nref.value('ns:Content[1]','VARCHAR(15)'), ' ', '')
               FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:CompletedPackageDetails/ns:OperationalDetail/ns:OperationalInstructions') AS n(nref)  
               WHERE nref.value('ns:Number[1]','VARCHAR(5)') = '10'  
            END
            
            -- Form Code
            IF ISNULL(@c_FormCode,'') =''
            BEGIN
               ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
               SELECT @c_FormCode = nref.value('ns:Content[1]','VARCHAR(10)') 
               FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:CompletedPackageDetails/ns:OperationalDetail/ns:OperationalInstructions') AS n(nref)  
               WHERE nref.value('ns:Number[1]','VARCHAR(5)') = '3'   
            END
            
            -- Routing Code
            IF ISNULL(@c_RoutingCode,'') =''
            BEGIN
               ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
               SELECT @c_RoutingCode = nref.value('ns:Content[1]','VARCHAR(10)')  
               FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:CompletedPackageDetails/ns:OperationalDetail/ns:OperationalInstructions') AS n(nref)  
               WHERE nref.value('ns:Number[1]','VARCHAR(5)') = '5'   
            END
            
            -- ASTRA Barcode
            IF ISNULL(@c_ASTRA_Barcode,'') =''
            BEGIN
               ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
               SELECT @c_ASTRA_Barcode = nref.value('ns:Content[1]','VARCHAR(45)') 
               FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:CompletedPackageDetails/ns:OperationalDetail/ns:OperationalInstructions') AS n(nref)  
               WHERE nref.value('ns:Number[1]','VARCHAR(5)') = '7'   
            END
            
            -- Planned Service Level
            IF ISNULL(@c_PlannedServiceLevel,'') =''
            BEGIN
               ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
               SELECT @c_PlannedServiceLevel = nref.value('ns:Content[1]','VARCHAR(30)')  
               FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:CompletedPackageDetails/ns:OperationalDetail/ns:OperationalInstructions') AS n(nref)  
               WHERE nref.value('ns:Number[1]','VARCHAR(5)') = '12' 
            END
            
            -- Service Type Description
            IF ISNULL(@c_ServiceTypeDescription,'') =''
            BEGIN
               ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
               SELECT @c_ServiceTypeDescription = nref.value('ns:Content[1]','VARCHAR(45)')  
               FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:CompletedPackageDetails/ns:OperationalDetail/ns:OperationalInstructions') AS n(nref)  
               WHERE nref.value('ns:Number[1]','VARCHAR(5)') = '13'   
            END
            
            -- Special Handling Indicators
            IF ISNULL(@c_SpecialHandlingIndicators,'') =''
            BEGIN
               ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
               SELECT @c_SpecialHandlingIndicators = nref.value('ns:Content[1]','VARCHAR(30)')  
               FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:CompletedPackageDetails/ns:OperationalDetail/ns:OperationalInstructions') AS n(nref)  
               WHERE nref.value('ns:Number[1]','VARCHAR(5)') = '14' 
            END
            
            -- Destination Airport ID
            IF ISNULL(@c_DestinationAirportID,'') =''
            BEGIN
               ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
               SELECT @c_DestinationAirportID = nref.value('ns:Content[1]','VARCHAR(5)')  
               FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:CompletedPackageDetails/ns:OperationalDetail/ns:OperationalInstructions') AS n(nref)  
               WHERE nref.value('ns:Number[1]','VARCHAR(5)') = '17'   
            END
         END
         -- Others
         -- ELSE
         -- BEGIN 
         --
         -- END

         -- GET common_2D barcode
         ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
         SELECT @c_Common2DBarcode = nref.value('ns:Value[1]','VARCHAR(1000)')
         FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:CompletedPackageDetails/ns:OperationalDetail/ns:Barcodes/ns:BinaryBarcodes') AS n(nref)   
         WHERE  nref.value('ns:Type[1]','VARCHAR(10)') = 'COMMON_2D'
         
         -- Base64 Decode the common2D barcode from FedEx
         EXEC [master].[dbo].[isp_Base64Decode] 
              @c_Common2DBarcode
            , @c_Common2DBarcode OUTPUT
            , @c_vbErrMsg        OUTPUT

         IF @@ERROR <> 0 OR ISNULL(@c_vbErrMsg,'') <> '' 
         BEGIN    
            -- SET @b_Success    
            SET @b_Success = 0    
         
            -- SET @n_err    
            IF @@ERROR <> 0    
            BEGIN    
               SET @n_err = @@ERROR    
            END    
            ELSE    
            BEGIN    
               SET @n_err = 75166    
            END    
         
            -- SET @c_errmsg    
            IF ISNULL(@c_vbErrMsg,'') <> ''    
            BEGIN    
               SET @c_errmsg = CAST(@c_vbErrMsg AS NVARCHAR(250))    
            END    
            ELSE    
            BEGIN    
               SET @c_errmsg = 'Error: '+ CAST(@n_err AS NVARCHAR(11)) + ' occurred while executing [master].[dbo].[isp_Base64Decode].'     
            END     
         
            GOTO QUIT    
         END
        
         -- GET Net Charge Amount
         ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
         SELECT @f_TotalNetCharge = nref.value('ns:Amount[1]','FLOAT')
         FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:ShipmentRating/ns:ShipmentRateDetails/ns:TotalNetCharge') AS n(nref)    
         WHERE nref.value('../ns:RateType[1]','VARCHAR(30)') = 'PAYOR_ACCOUNT_PACKAGE'    
         
         -- GET Insured Value
         ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
         SELECT @f_InsuredValue = nref.value('ns:Amount[1]/ns:Amount[1]','FLOAT')
         FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:ShipmentRating/ns:ShipmentRateDetails/ns:Surcharges') AS n(nref)    
         WHERE nref.value('../ns:RateType[1]','VARCHAR(30)') = 'PAYOR_ACCOUNT_PACKAGE' 
           AND nref.value('ns:SurchargeType[1]','VARCHAR(20)') = 'INSURED_VALUE'  
         
         -- CartonShipmentDetail.FreightCharge = TotalNetCharge -  InsuredValue  -- Chee01
         SET @f_InsuredValue = ISNULL(@f_InsuredValue,0)
         SET @f_TotalNetCharge = ISNULL(@f_TotalNetCharge,0) - @f_InsuredValue
         
         --  ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)    
         --  SELECT @c_Label = nref.value('ns:Image[1]','VARCHAR(MAX)')     
         --  FROM @x_Message.nodes('/ProcessShipmentReply/ns:CompletedShipmentDetail/ns:CompletedPackageDetails/ns:Label/ns:Parts') AS n(nref)    

         BEGIN TRAN    
         
         -- Update freight charge in orders.userderfine10  -- Chee01   
         -- UPDATE [dbo].[Orders] WITH (ROWLOCK)    
         -- SET [UserDefine10] = @c_NetChargeAmount    
         -- ,[UserDefine04] = @c_TrackingNumber    
         -- WHERE OrderKey = @c_OrderKey    
         
         -- Update Tracking number
         UPDATE [dbo].[PackDetail] WITH (ROWLOCK)    
         SET    [UPC] = @c_TrackingNumber    
         WHERE  [PickSlipNo] = @c_PickSlipNo    
           AND  [CartonNo]   = @n_CartonNo    
           AND  [LabelNo]    = @c_LabelNo    

         -- Check row is in packInfo or not     
         --   SELECT @n_Count = COUNT(1)    
         --   FROM  [dbo].[PackInfo] WITH (NOLOCK)    
         --   WHERE [PickSlipNo] = @c_PickSlipNo    
         --   AND   [CartonNo] = @n_CartonNo    
         
         -- If yes, Update tracking number to packinfo.refno. Else, Insert new row    
         --   IF @n_Count > 0    
         --   BEGIN    
         --    UPDATE [dbo].[PackInfo] WITH (ROWLOCK)    
         --    SET    [RefNo] = @c_TrackingNumber    
         --    WHERE  [PickSlipNo] = @c_PickSlipNo    
         --    AND    [CartonNo] = @n_CartonNo    
         --   END    
         --   ELSE    
         --   BEGIN    
         --    INSERT INTO [dbo].[PackInfo] (PickSlipNo, CartonNo, RefNo)     
         --    VALUES (@c_PickSlipNo, @n_CartonNo, @c_TrackingNumber)    
         --   END    

         IF @@TRANCOUNT > 0    
         BEGIN     
            COMMIT TRAN;    
         END    
         ELSE    
         BEGIN     
            ROLLBACK TRAN    
         END    

         -- INSERT INTO FedExTracking    
         -- If Ground OR SmartPost Shipment    
         IF @c_ServiceType = 'FEDEX_GROUND' OR @c_ServiceType = 'GROUND_HOME_DELIVERY' OR @c_ServiceType = 'SMART_POST'    
         BEGIN    
            INSERT INTO FedExTracking (OrderKey, PickSlipNo, CartonNo, Status, TrackingNumber, UpdateSource, SendFlag, ServiceType)    
            VALUES (@c_OrderKey, @c_PickSlipNo, @n_CartonNo, '0', @c_TrackingNumber, NULL, 'N', @c_ServiceType)     
         END    
         -- Others    
         ELSE    
         BEGIN    
            INSERT INTO FedExTracking (OrderKey, PickSlipNo, CartonNo, Status, TrackingNumber, UpdateSource, SendFlag, ServiceType)    
            VALUES (@c_OrderKey, @c_PickSlipNo, @n_CartonNo, '9', @c_TrackingNumber, NULL, 'N', @c_ServiceType)     
         END    

         IF @@ERROR <> 0    
         BEGIN    
            -- SET @b_Success    
            SET @b_Success = 0    
            SET @n_err = @@ERROR    
            SET @c_errmsg = 'Error: '+ CAST(@n_err AS NVARCHAR(11)) + ' occurred while inserting into FedexTracking Table.'    
            GOTO QUIT  
         END    

         -- INSERT INTO CartonShipmentDetail    
         INSERT INTO CartonShipmentDetail (Storerkey, Orderkey, Loadkey, Mbolkey, Externorderkey, Buyerpo, UCCLabelNo, CartonWeight, 
         DestinationZipCode, CarrierCode, ClassOfService, TrackingIdType, FormCode, TrackingNumber, GroundBarcodeString, RoutingCode,
         ASTRA_Barcode, PlannedServiceLevel, ServiceTypeDescription, SpecialHandlingIndicators, DestinationAirportID, ServiceCode, 
         [2dBarcode], CartonCube, FreightCharge, InsCharge)   -- Chee01
         VALUES (@c_StorerKey, @c_OrderKey, @c_LoadKey, @c_MbolKey, @c_ExternOrderKey, @c_BuyerPO, @c_LabelNo, @f_WeightValue, 
         @c_RecipientPostalCode, @c_CarrierCode, @c_GroundServiceCode, @c_TrackingIdType, @c_FormCode, @c_TrackingNumber, 
         @c_GroundBarcodeString, @c_RoutingCode, @c_ASTRA_Barcode, @c_PlannedServiceLevel, @c_ServiceTypeDescription, 
         @c_SpecialHandlingIndicators, @c_DestinationAirportID, @c_ServiceCode, @c_Common2DBarcode, @f_CartonCube, 
         @f_TotalNetCharge, @f_InsuredValue) -- Chee01

         IF @@ERROR <> 0    
         BEGIN    
            -- SET @b_Success    
            SET @b_Success = 0    
            SET @n_err = @@ERROR    
            SET @c_errmsg = 'Error: '+ CAST(@n_err AS NVARCHAR(11)) + ' occurred while inserting into CartonShipmentDetail Table.'  
            GOTO QUIT    
         END    
      END   
   END    

   QUIT:    
   RETURN;    

END

GO