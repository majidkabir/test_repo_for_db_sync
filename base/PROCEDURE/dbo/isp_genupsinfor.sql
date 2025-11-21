SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: isp_GenUPSInfor                                     */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Trigger when Close Carton, Insert into UPSTracking_Out      */  
/*          UPS Apps accessing this table when user scan carton id from */  
/*          UPS Application. CartonID is the Unique ID for retrieving   */  
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author      Purposes                                */    
/* 2011-12-28  1.0  SHONG       Created                                 */    
/************************************************************************/    
    
CREATE PROC [dbo].[isp_GenUPSInfor] (    
   @cDropID     NVARCHAR( 20) = '',  
   @cLabelNo    NVARCHAR(30)  = '',        
   @cStorerKey  NVARCHAR( 15),    
   @nErrNo      INT          OUTPUT,    
   @cErrMsg     NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max    
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
SET @nErrNo = 0  
SET @cErrMsg = ''  
    
-- Misc variable      
DECLARE      
   @cOrderKey   NVARCHAR( 10),       
   @cLoadKey    NVARCHAR( 10),       
   @cOption     NVARCHAR( 1)      
    
-- RDT.RDTMobRec variable      
DECLARE      
   @cPickSlipNo         NVARCHAR( 10),       
 @cCartonID           NVARCHAR(20),  
 @cWMS_RefKey         NVARCHAR(30),  
 @cWMS_RefType        NVARCHAR(2),  
 @cShipToName         NVARCHAR(30),  
 @cShipToCompany      NVARCHAR(30),  
 @cShipToAddress1     NVARCHAR(45),  
 @cShipToAddress2     NVARCHAR(45),  
 @cShipToAddress3     NVARCHAR(45),  
 @cCity               NVARCHAR(45),  
 @cState              NVARCHAR(2),  
 @cZip                NVARCHAR(18),  
 @cCountry            NVARCHAR(30),  
 @cPhone              NVARCHAR(18),  
 @cServiceIndicator   NVARCHAR(18),  
 @cPaymentType        NVARCHAR(10),  
 @cPriAcctNo          NVARCHAR(18),  
 @cScdAcctNo          NVARCHAR(18),  
 @cBillToCompany      NVARCHAR(45),  
 @cBillToAddress1     NVARCHAR(45),  
 @cBillToAddress2     NVARCHAR(45),  
 @cBillToAddress3     NVARCHAR(45),  
 @cBillToCity         NVARCHAR(45),  
 @cBillToState        NVARCHAR(45),  
 @cBillToZip          NVARCHAR(18),  
 @cBillToCountry      NVARCHAR(30),  
 @cInsuranceFlag      NVARCHAR(18),  
 @cRetailPrice        MONEY,  
 @cPLD_RefNo1         NVARCHAR(30),  
 @cPLD_RefNo2         NVARCHAR(30),  
 @cPLD_RefNo3         NVARCHAR(30),  
 @cPLD_RefNo4         NVARCHAR(30),   
 @cPLD_RefNoValue1    NVARCHAR(30),  
 @cPLD_RefNoValue2    NVARCHAR(30),  
 @cPLD_RefNoValue3    NVARCHAR(30),  
 @cPLD_RefNoValue4    NVARCHAR(30),    
 @nCartonNo           INT,   
 @cCartonType         NVARCHAR(1),  
 @cUserDefine03       NVARCHAR(30),  
 @cExternOrderKey     NVARCHAR(20),  
 @cConsigneeKey       NVARCHAR(15),  
 @cBuyerPO            NVARCHAR(20),  
 @cCarrierService     NVARCHAR(30)  
    
DECLARE @cConsoOrderKey       NVARCHAR( 30)      
DECLARE @cPackStatus          NVARCHAR( 1)      
DECLARE @cSpecialHandling     NVARCHAR(10)      
DECLARE @cKeyType             NVARCHAR(1)  
  
SET @cKeyType = ''  
SET @cRetailPrice = 0     
SET @cCartonType = ''  
-- Get PickSlipNo by DropID      
SET @cPickSlipNo = ''   
SET @nCartonNo = 0      
IF ISNULL(RTRIM(@cDropID),'') <> ''  
BEGIN  
   SELECT TOP 1       
      @cPickSlipNo = ISNULL(PickSlipNo,''),   
      @nCartonNo   = ISNULL(CartonNo,0),
      @cLabelNo    = ISNULL(LabelNo,'')     
   FROM dbo.PackDetail WITH (NOLOCK)       
   WHERE StorerKey = @cStorerKey       
     AND DropID   = @cDropID         
       
   SET @cCartonID = @cLabelNo  
   SET @cCartonType = 'L'  
END  
ELSE IF ISNULL(RTRIM(@cLabelNo),'') <> ''  
BEGIN  
   SELECT TOP 1       
      @cPickSlipNo = ISNULL(PickSlipNo,''),   
      @nCartonNo   = ISNULL(CartonNo,0)        
   FROM dbo.PackDetail WITH (NOLOCK)       
   WHERE StorerKey = @cStorerKey       
     AND LabelNo   = @cLabelNo         
       
   SET @cCartonID = @cLabelNo  
   SET @cCartonType = 'L'     
END  
IF ISNULL(RTRIM(@cPickSlipNo),'') = ''       
BEGIN      
   GOTO QUIT    
END      
  
      
-- Get PackHeader info   
SET   @cConsoOrderKey = ''  
SET   @cOrderKey = ''  
SET   @cLoadKey  = ''   
SELECT     
   @cPackStatus = Status,       
   @cConsoOrderKey = ISNULL(ConsoOrderKey,''),   
   @cOrderKey      = ISNULL(OrderKey,''),   
   @cLoadKey       = ISNULL(LoadKey,'')   
FROM dbo.PackHeader WITH (NOLOCK)      
WHERE PickSlipNo = @cPickSlipNo      
    
-- Check if packing list printed      
IF ISNULL(RTRIM(@cConsoOrderKey),'') <> ''     
BEGIN      
   SELECT TOP 1   
      @cOrderKey = OrderKey   
   FROM OrderDetail WITH (NOLOCK)   
   WHERE ConsoOrderKey = @cConsoOrderKey   
     
   SET @cWMS_RefKey  = @cConsoOrderKey  
   SET @cWMS_RefType = 'C'  
END      
ELSE IF ISNULL(RTRIM(@cLoadKey),'') <> '' AND ISNULL(RTRIM(@cOrderKey),'') = ''     
BEGIN      
   SELECT TOP 1   
      @cOrderKey = OrderKey   
   FROM LoadplanDetail WITH (NOLOCK)   
   WHERE LoadKey = @cLoadKey  
     
   SET @cWMS_RefKey  = @cLoadKey  
   SET @cWMS_RefType = 'L'  
END  
ELSE  
BEGIN  
   SET @cWMS_RefKey  = @cOrderKey  
   SET @cWMS_RefType = 'O'       
END  
          
-- If Get Order Info Failed, Quit  
IF ISNULL(RTRIM(@cOrderKey),'') = ''       
BEGIN      
   GOTO QUIT    
END      
  
SELECT   
   @cShipToName     = o.C_contact1,  
   @cShipToCompany  = o.C_Company,  
   @cShipToAddress1 = o.C_Address1,  
   @cShipToAddress2 = o.C_Address2,  
   @cShipToAddress3 = o.C_Address3,  
   @cCity      = o.C_City,  
   @cState     = o.C_State,  
   @cZip       = o.C_Zip,  
   @cCountry   = o.C_Country,  
   @cPhone     = o.C_Phone1,  
   @cServiceIndicator = o.M_Phone2,  
   @cPaymentType     = o.PmtTerm,  
   @cPriAcctNo       = o.M_Fax1,  
   @cScdAcctNo       = o.B_Fax2,  
   @cBillToCompany   = o.B_Company,  
   @cBillToAddress1  = o.B_Address1,  
   @cBillToAddress2  = o.B_Address2,  
   @cBillToAddress3  = o.B_Address3,  
   @cBillToCity      = o.B_City,  
   @cBillToState     = o.B_State,  
   @cBillToZip       = o.B_Zip,  
   @cBillToCountry   = o.B_Country,  
   @cInsuranceFlag   = SUBSTRING(o.B_Fax1, 2, 1),   
   @cSpecialHandling = o.SpecialHandling,   
   @cUserDefine03    = o.UserDefine03,  
   @cBuyerPO         = o.BuyerPO,  
   @cExternOrderKey  = o.ExternOrderKey,  
   @cConsigneeKey    = o.ConsigneeKey,   
   @cCarrierService  = o.UserDefine02     
FROM ORDERS o WITH (NOLOCK)  
WHERE o.OrderKey = @cOrderKey   
  
IF @cCarrierService <> 'UPSN'  
BEGIN  
 GOTO QUIT  
END  
  
IF NOT EXISTS(SELECT 1 FROM UPSTracking_Out uo WITH (NOLOCK)  
              WHERE uo.CartonID = @cCartonID   
              AND   uo.WMS_RefKey = @cWMS_RefKey   
              AND   uo.WMS_RefType = @cWMS_RefType)  
BEGIN  
   SELECT   
      @cPLD_RefNo1 = oi.OrderInfo01,  
      @cPLD_RefNo2 = oi.OrderInfo02,  
      @cPLD_RefNo3 = oi.OrderInfo03,  
      @cPLD_RefNo4 = oi.OrderInfo04  
   FROM OrderInfo oi (NOLOCK)  
   WHERE oi.OrderKey = @cOrderKey   
     
   SET @cPLD_RefNoValue1 = ''  
   SET @cPLD_RefNoValue2 = ''  
   SET @cPLD_RefNoValue3 = ''  
   SET @cPLD_RefNoValue4 = ''  
     
   SET @cPLD_RefNoValue1 =   
       CASE @cPLD_RefNo1   
         WHEN 'DEPT' THEN @cUserDefine03  
         WHEN 'PO'   THEN @cExternOrderKey   
         WHEN 'INV'  THEN @cBuyerPO   
         WHEN 'ST'   THEN @cConsigneeKey   
         WHEN 'UCC'  THEN @cLabelNo   
         ELSE ''  
       END  
          
   SET @cPLD_RefNoValue2 =   
       CASE @cPLD_RefNo2   
         WHEN 'DEPT' THEN @cUserDefine03  
         WHEN 'PO'   THEN @cExternOrderKey   
         WHEN 'INV'  THEN @cBuyerPO   
         WHEN 'ST'   THEN @cConsigneeKey   
         WHEN 'UCC'  THEN @cLabelNo   
         ELSE ''  
       END   
            
   SET @cPLD_RefNoValue3 =   
       CASE @cPLD_RefNo3   
         WHEN 'DEPT' THEN @cUserDefine03  
         WHEN 'PO'   THEN @cExternOrderKey   
         WHEN 'INV'  THEN @cBuyerPO   
         WHEN 'ST'   THEN @cConsigneeKey   
         WHEN 'UCC'  THEN @cLabelNo   
         ELSE ''  
       END   
   SET @cPLD_RefNoValue4 =   
       CASE @cPLD_RefNo4   
         WHEN 'DEPT' THEN @cUserDefine03  
         WHEN 'PO'   THEN @cExternOrderKey   
         WHEN 'INV'  THEN @cBuyerPO   
         WHEN 'ST'   THEN @cConsigneeKey   
         WHEN 'UCC'  THEN @cLabelNo   
         ELSE ''  
       END   
        
   IF @cInsuranceFlag = 'Y'  
   BEGIN  
      SELECT @cRetailPrice = SUM(ISNULL(s.Price,0) * pd.Qty)  
      FROM PackDetail pd WITH (NOLOCK)  
      JOIN SKU s WITH (NOLOCK) ON pd.StorerKey = s.StorerKey AND pd.SKU = s.Sku   
      WHERE pd.PickSlipNo = @cPickSlipNo   
      AND   pd.CartonNo = @nCartonNo   
   END  
                  
   INSERT INTO UPSTracking_Out  
   (  
    CartonID,  
    CartonType,   
    WMS_RefKey,  
    WMS_RefType,  
    ShipToName,  
    ShipToCompany,  
    ShipToAddress1,  
    ShipToAddress2,  
    ShipToAddress3,  
    City,  
    [State],  
    Zip,  
    Country,  
    Phone,  
    ServiceIndicator,  
    PaymentType,  
    PriAcctNo,  
    ScdAcctNo,  
    BillToCompany,  
    BillToAddress1,  
    BillToAddress2,  
    BillToAddress3,  
    BillToCity,  
    BillToState,  
    BillToZip,  
    BillToCountry,  
    InsuranceFlag,  
    RetailPrice,  
    PLD_RefNo1,  
    PLD_RefNo2,  
    PLD_RefNo3,  
    PLD_RefNo4,  
    AddDate  
   )  
   VALUES  
   (  
    @cCartonID,  
    @cCartonType,   
    @cWMS_RefKey,  
    @cWMS_RefType,  
    @cShipToName,  
    @cShipToCompany,  
    @cShipToAddress1,  
    @cShipToAddress2,  
    @cShipToAddress3,  
    @cCity,  
    @cState,  
    @cZip,  
    @cCountry,  
    @cPhone,  
    @cServiceIndicator,  
    @cPaymentType,  
    @cPriAcctNo,  
    @cScdAcctNo,  
    @cBillToCompany,  
    @cBillToAddress1,  
    @cBillToAddress2,  
    @cBillToAddress3,  
    @cBillToCity,  
    @cBillToState,  
    @cBillToZip,  
    @cBillToCountry,  
    @cInsuranceFlag,  
    @cRetailPrice,  
    @cPLD_RefNoValue1,  
    @cPLD_RefNoValue2,  
    @cPLD_RefNoValue3,  
    @cPLD_RefNoValue4,  
    GETDATE() /* AddDate */  
   )   
END                
  
    
QUIT:    
    
END -- Procedure 

GO