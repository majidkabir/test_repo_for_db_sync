SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/              
/* SP: isp1156P_Agile_Rate                                              */              
/* Creation Date: 12 Mar 2012                                           */              
/* Copyright: IDS                                                       */              
/* Written by: Chee Jun Yan                                             */              
/*                                                                      */              
/* Purpose: SOS#237560 - Agile Elite - Rate Request                     */          
/*          SOS#237561 - Agile Elite - Rate Response                    */              
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
/* RDT message range: 75451 - 75500                                     */              
/*                                                                      */              
/* Updates:                                                             */              
/* Date         Author   Ver      Purposes                              */              
/* 29-Mar-2012  Shong    1.5      Set Agile Code = Codelkup.Short       */           
/* 03-Apr-2012  Chee     1.6      Get Agile Web Service Request URL     */          
/*                                from CODELKUP (Chee01)                */          
/* 07-Apr-2012  Shong    1.7      Performance Tuning                    */          
/* 07-Apr-2012  Ung      1.8      If ShipDate Sat,Sun, set as Mon(ung01)*/           
/* 10-Apr-2012  Ung      1.9      Fix data type conversion (ung02)      */          
/*                                Quit if PmtTerm <> PP/PC (ung03)      */          
/* 10-Apr-2012  Shong    2.0      Do not Process if International Order */          
/* 14-Apr-2012  Shong    2.0      User Account No as User Name          */          
/* 16-Apr-2012  Shong    2.1      Added SourceKey, SourceType to Web Log*/      
/* 24-JUL-2012  ChewKP   2.2      Get OrderKey by LabelNo (ChewKP01)    */   
/* 03-Oct-2012  Chee     2.3      Add isp_GenericWebServiceClient_      */  
/*                                Contingency (Chee02)                  */  
/* 27-Jun-2013  Chee     2.4      SOS# 282085 - Add Credentials to      */ 
/*                                AGILE Rate XML request for            */
/*                                Orders.SpecialHandling = 'X' (Chee03) */  
/************************************************************************/              
              
CREATE PROC [dbo].[isp1156P_Agile_Rate](              
    @cPickSlipNo     NVARCHAR(10)              
   ,@nCartonNo       INT              
   ,@cLabelNo        NVARCHAR(20)              
   ,@bSuccess        INT            OUTPUT               
   ,@nErr            INT            OUTPUT              
   ,@cErrMsg         NVARCHAR(215)   OUTPUT               
)              
AS              
BEGIN              
   SET NOCOUNT ON              
   SET ANSI_DEFAULTS OFF              
   SET QUOTED_IDENTIFIER OFF                  
   SET CONCAT_NULL_YIELDS_NULL OFF                 
              
   DECLARE               
       @cCarrier                 NVARCHAR(10)              
      ,@cServiceType             NVARCHAR(18)              
      ,@cShipDate                NVARCHAR(20)              
      ,@cSaturdayDelivery        NVARCHAR(5)              
      ,@cAccountID               NVARCHAR(18)              
      ,@cSender_CompanyName      NVARCHAR(45)            
      ,@cSender_Street           NVARCHAR(25)              
      ,@cSender_Locale           NVARCHAR(45)              
      ,@cSender_Other            NVARCHAR(45)              
      ,@cSender_City             NVARCHAR(30)              
      ,@cSender_Region           NVARCHAR(30)              
      ,@cSender_PostalCode       NVARCHAR(30)              
      ,@cSender_Country          NVARCHAR(2)              
      ,@cReceiver_CompanyName    NVARCHAR(45)          
      ,@cReceiver_Street         NVARCHAR(45)              
      ,@cReceiver_Locale         NVARCHAR(45)              
      ,@cReceiver_Other          NVARCHAR(45)              
      ,@cReceiver_City           NVARCHAR(45)              
      ,@cReceiver_Region         NVARCHAR(45)              
      ,@cReceiver_PostalCode     NVARCHAR(18)              
      ,@cReceiver_Country        NVARCHAR(2)              
      ,@cPackage_PackageType     NVARCHAR(10)              
      ,@cPackage_Weight          NVARCHAR(20)              
      ,@cPackage_Length          NVARCHAR(20)              
      ,@cPackage_Width           NVARCHAR(20)              
      ,@cPackage_Height          NVARCHAR(20)              
      ,@cPackage_Insurance_Type  NVARCHAR(1)              
      ,@cPackage_Insurance_Value NVARCHAR(20)              
      ,@cPackage_DeliveryConfirm NVARCHAR(1)              
      ,@cFacility                NVARCHAR(5)              
      ,@cPackageID               NVARCHAR(10)              
      ,@cBilling_PayerType       NVARCHAR(10)         
              
   DECLARE                 
      @cIniFilePath          NVARCHAR(100),              
      @cWebRequestURL        NVARCHAR(1000),              
      @cWebRequestMethod     NVARCHAR(10),              
      @cContentType          NVARCHAR(100),              
      @cWebRequestEncoding   NVARCHAR(30),              
      @cXMLEncodingString    NVARCHAR(100),          
      @cRequestString        NVARCHAR(MAX),              
      @cResponseString       NVARCHAR(MAX),              
      @cVBErrMsg             NVARCHAR(MAX),              
      @xRequestString        XML,              
      @xReponseString        XML,              
      @dTimeIn               DATETIME,              
      @dTimeOut              DATETIME,              
      @nTotalTime            INT,              
      @cStatus               NVARCHAR(1),              
      @cOrderKey             NVARCHAR(10),              
      @cStorerKey            NVARCHAR(15),              
      @cLoadKey              NVARCHAR(10),              
      @cMbolKey              NVARCHAR(10),              
      @nDebug                INT,              
      @nSeqNo                INT,              
      @cDataStream           NVARCHAR(4),              
      @cBatchNo              NVARCHAR(10),              
      @cUserName             NVARCHAR(30),              
      @cListName             NVARCHAR(10),              
      @cCode_FilePath        NVARCHAR(30),              
      @cPackKey              NVARCHAR(10),              
      @cCartonGroup          NVARCHAR(10),              
      @cCartonType           NVARCHAR(10),              
      @cAgileProcess         NVARCHAR(1),              
      @cBuyerPO              NVARCHAR(20),              
      @cExternOrderKey       NVARCHAR(20),          
      @cCode_AgileURL        NVARCHAR(30),     -- Chee01   
      @cCode_ConnString      NVARCHAR(30),     -- Chee02 
      @cWSClientContingency  NVARCHAR(1),      -- Chee02 
      @cConnectionString     NVARCHAR(250),   -- Chee02
      @cShippingKey          NVARCHAR(60),     -- Chee03
      @cListName_CarrierAcc  NVARCHAR(10)      -- Chee03

   DECLARE               
      @ndoc                   INT,              
      @cTransactionIdentifier NVARCHAR(10),              
      @fShippingCharge        FLOAT,              
      @fAccessorialCharge     FLOAT,              
      @nStatus_Code           INT,              
      @cStatus_Desc           NVARCHAR(215)              

   DECLARE @StoreSeqNoTempTable TABLE              
   (SeqNo INT);              

   DECLARE               
      @nLogAttachmentID    INT              
     ,@cFilename           NVARCHAR(60)              
     ,@nLogFilekey         INT              
     ,@cLineText           NVARCHAR(4000)              

   SET @nDebug      = 0              

   SET @bSuccess    = 1              
   SET @nErr        = 0              
   SET @cErrmsg     = ''              

   SET @cStatus     = '9'              

   SET @cDataStream          = '1156'
   SET @cUserName            = 'Administrator'
   SET @cListName            = 'WebService'
   SET @cCode_FilePath       = 'FilePath'
   SET @cCode_AgileURL       = 'AgileURL'     -- Chee01
   SET @cCode_ConnString     = 'ConnString'   -- Chee02
   SET @cListName_CarrierAcc = 'CARRIERACC'   -- Chee03
              
   -- Log file Name              
   SET @cFileName = 'AGILE_Rate_' + @cLabelNo + '_' + REPLACE(REPLACE(REPLACE(convert(varchar, getdate(), 120),'-',''),':',''),' ','') + '.log'        
              
   --SET @cWebRequestURL      = 'http://LFUSAAE15.lfusa.com/AgileElite Shipping/Services/XmlService.aspx'  -- Chee01             
   SET @cWebRequestMethod   = 'POST'              
   SET @cContentType        = 'application/x-www-form-urlencoded'              
   SET @cWebRequestEncoding = 'utf-8'              
   SET @cXMLEncodingString  = '<?xml version="1.0" encoding="' + @cWebRequestEncoding + '"?>'              
          
   DECLARE @cConsoOrderKey NVARCHAR(30)          

   SET @cConsoOrderKey = ''          
   SET @cOrderKey = ''          
   SET @cLoadKey = ''          

   -- Get OrderKey                 
   SELECT @cOrderKey = ISNULL(ph.OrderKey,''),          
          @cLoadKey  = ISNULL(ph.LoadKey,''),          
          @cConsoOrderKey = ISNULL(ph.ConsoOrderKey,'')           
   FROM PackHeader ph (NOLOCK)          
   WHERE ph.PickSlipNo = @cPickSlipNo          

   IF @cOrderKey = '' AND @cConsoOrderKey <> ''          
   BEGIN          
--      SELECT TOP 1               
--         @cOrderKey  = od.OrderKey              
--      FROM ORDERDETAIL  od WITH (NOLOCK)                
--      WHERE od.ConsoOrderKey = @cConsoOrderKey          

      -- (ChewKP01)  
      SELECT TOP 1   
         @cOrderKey  = PD.OrderKey       
      FROM PICKDETAIL PD WITH (NOLOCK)  
      INNER JOIN PACKHEADER PH WITH (NOLOCK) ON PH.PICKSLIPNO = PD.PICKSLIPNO   
      INNER JOIN PACKDETAIL PACKD WITH (NOLOCK) ON PD.DropID = PACKD.DropID AND PD.PICKSLIPNO = PACKD.PICKSLIPNO   
      WHERE PACKD.LABELNO = @cLabelNo             

   END          
   ELSE IF @cOrderKey = '' AND @cLoadKey <> ''          
   BEGIN          
      SELECT TOP 1           
         @cOrderKey =  lpd.OrderKey           
      FROM LoadPlanDetail lpd (NOLOCK)            
      WHERE lpd.LoadKey = @cLoadKey          
   END          
 
   DECLARE @cShipToCountry NVARCHAR(30)          
   SET @cShipToCountry = ''          

   SELECT @cShipToCountry = ISNULL(oi.OrderInfo07,'')           
   FROM OrderInfo oi WITH (NOLOCK)          
   WHERE oi.OrderKey = @cOrderKey          

   IF @cShipToCountry <> 'USA' AND @cShipToCountry <> ''          
   BEGIN          
      GOTO Quit           
   END          

   DECLARE @t_ServiceType TABLE (            
   SpecialHandling  NVARCHAR(10),            
   Code             NVARCHAR(30),            
   AgileCode        NVARCHAR(30))            

   INSERT INTO @t_ServiceType            
   SELECT 'X', Code, Short             
   FROM CODELKUP c WITH (NOLOCK)            
   WHERE c.LISTNAME = 'FEDEX_EDI'              
   AND c.Short IS NOT NULL             
   AND c.Short <> ''            

   INSERT INTO @t_ServiceType            
   SELECT 'U', Code, Short             
   FROM CODELKUP c WITH (NOLOCK)            
   WHERE c.LISTNAME = 'UPS_EDI'                 
   AND c.Short IS NOT NULL             
   AND c.Short <> ''            

   INSERT INTO @t_ServiceType            
   SELECT 'D', Code, Short             
   FROM CODELKUP c WITH (NOLOCK)            
   WHERE c.LISTNAME = 'DHL_EDI'             
   AND c.Short IS NOT NULL             
   AND c.Short <> ''            

   IF @nDebug = 1              
   BEGIN              
      SELECT @cOrderKey AS 'OrderKey'              
   END              
              
   SELECT               
      @cCarrier = CASE O.SpecialHandling               
                      WHEN 'U' THEN '12'              
                      WHEN 'X' THEN '17'              
                      WHEN 'N' THEN 'N'              
                      ELSE ''              
                  END,              
      @cServiceType            = CASE WHEN O.SpecialHandling IN ('U','X','D')             
                                      THEN RTRIM(ST.AgileCode)             
                                 ELSE RTRIM(O.M_Phone2)            
                                 END,              
      @cSaturdayDelivery       = CASE LEFT(O.B_Fax1,1) WHEN 'Y' THEN 'True' ELSE NULL END,              
      @cShipDate               = CASE DATEPART( dw, GETDATE()) -- (ung01)            
            WHEN 1 THEN CONVERT(char(10), GETDATE() + 1, 126) -- if Sun, set to Mon            
                                    WHEN 7 THEN CONVERT(char(10), GETDATE() + 2, 126) -- if Sat, set to Mon            
                                    ELSE CONVERT(char(10), GETDATE(), 126)            
                                 END,             
      @cAccountID              = RTRIM(O.M_Fax1),              
      @cReceiver_CompanyName   = RTRIM(O.C_Company),              
      @cReceiver_Street        = RTRIM(O.C_Address1),              
      @cReceiver_Locale        = RTRIM(O.C_Address2),              
      @cReceiver_Other         = RTRIM(O.C_Address3),              
      @cReceiver_City          = RTRIM(O.C_City),              
      @cReceiver_Region        = RTRIM(o.C_State),              
      @cReceiver_PostalCode    = RTRIM(O.C_Zip),               
      @cReceiver_Country       = LEFT(O.C_Country,2),              
      @cBilling_PayerType      = CASE O.PmtTerm               
                                    WHEN 'PP' THEN  1 --Sender               
                                    WHEN 'PC' THEN  1 --Sender               
                                    WHEN 'BP' THEN  2 --Recipient               
                                    WHEN 'TP' THEN  3 --Third Party              
                                    WHEN 'CC' THEN  4 --Consignee               
                                    ELSE  5 -- Invoice               
                                 END,              
      --@cPackage_PackageType     = '27',                  
      @cPackage_PackageType     = CASE O.SpecialHandling           
                                     WHEN 'U' THEN '27'                  
                                     WHEN 'X' THEN '43'                  
                                     ELSE ''                  
                                  END,              
      @cPackage_Insurance_Type  = CASE WHEN SUBSTRING(O.B_Fax1,2,1) = 'Y' THEN '1' ELSE '0' END,               
      @cSender_CompanyName      = RTRIM(s.Company),              
      @cExternOrderKey          = RTRIM(O.ExternOrderKey),              
      @cLoadKey                 = O.LoadKey,              
      @cMbolKey                 = O.MbolKey,              
      @cFacility                = O.Facility,              
      @cBuyerPO                 = O.BuyerPO,              
      @cStorerKey               = O.StorerKey,              
      @cCartonGroup             = s.CartonGroup,              
      @cPackage_DeliveryConfirm = CASE O.M_Phone1 WHEN 'Y' THEN '2' ELSE NULL END
      FROM ORDERS O WITH (NOLOCK)              
      JOIN STORER s WITH (NOLOCK) ON s.StorerKey = O.StorerKey              
      LEFT OUTER JOIN @t_ServiceType ST ON ST.SpecialHandling = O.SpecialHandling             
                                            AND ST.Code = O.M_Phone2                  
      WHERE O.OrderKey = @cOrderKey               

   IF @cCarrier = 'N'              
   BEGIN              
      GOTO Quit              
   END              
              
   EXEC dbo.nspGetRight              
      @cFacility,              
      @cStorerKey,              
      NULL,              
      'AgileProcess',              
      @bSuccess        OUTPUT,              
      @cAgileProcess   OUTPUT,               
      @nErr            OUTPUT,               
      @cErrMsg         OUTPUT              
              
   IF NOT @bSuccess = 1              
   BEGIN              
      SET @bSuccess = 0               
      SET @nErr = 75474              
      SET @cErrmsg = 'nspGetRight AgileProcess Failed. (isp1156P_Agile_Rate)'                
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
      GOTO Quit              
   END              
              
   IF @cAgileProcess <> '1'              
   BEGIN              
      GOTO Quit              
   END              
                       
   -- Get WSConfig.ini File Path from CODELKUP              
   SELECT @cIniFilePath = Long               
   FROM CODELKUP WITH (NOLOCK)              
   WHERE ListName = @cListName              
     AND Code = @cCode_FilePath              
              
   IF ISNULL(@cIniFilePath,'') = ''              
   BEGIN              
      SET @bSuccess = 0               
      SET @nErr = 75451              
      SET @cErrmsg = 'WSConfig.ini File Path is empty. (isp1156P_Agile_Rate)'                
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
      GOTO Quit              
   END              
     
   -- Get Agile Web Service Request URL from CODELKUP (Chee01)          
   SELECT @cWebRequestURL = Long               
   FROM CODELKUP WITH (NOLOCK)              
   WHERE ListName = @cListName              
     AND Code = @cCode_AgileURL              
              
   IF ISNULL(@cWebRequestURL,'') = ''              
   BEGIN              
      SET @bSuccess = 0               
      SET @nErr = 75477              
      SET @cErrmsg = 'Agile Web Service Request URL is empty. (isp1156P_Agile_Rate)'                
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
      GOTO Quit              
   END              
          
   IF @nDebug = 1              
   BEGIN              
      SELECT @cIniFilePath AS 'WSConfig.ini File Path',          
             @cWebRequestURL AS 'Agile Web Service Request URL'              
   END              
              
   -- Only provide insurance value when insurance type = 1, else Agile will return error              
   IF @cPackage_Insurance_Type = '1'              
   BEGIN              
      SELECT @cPackage_Insurance_Value = CAST(SUM(ISNULL(O.UnitPrice,0)) AS NVARCHAR(10))              
      FROM ORDERDETAIL o WITH (NOLOCK)              
      WHERE o.OrderKey = @cOrderKey              
   END              
              
   -- Get Package Weight              
   SET @cPackage_Weight = '' -- (ung02)          
   SELECT               
      @cPackage_Weight = p.Weight,              
      @cCartonType = p.CartonType                 
   FROM   PackInfo p WITH (NOLOCK)               
   WHERE  p.PickSlipNo = @cPickSlipNo               
   AND    p.CartonNo = @nCartonNo              
              
   -- Get package Length, Width & Height             
   SET @cPackage_Length = '0' -- (ung02)          
   SET @cPackage_Width  = '0' -- (ung02)          
   SET @cPackage_Height = '0' -- (ung02)          
             
   SELECT @cPackage_Length = ISNULL(C.CartonLength, '0')    -- (ung02)          
         ,@cPackage_Width  = ISNULL(C.CartonWidth, '0')     -- (ung02)          
         ,@cPackage_Height = ISNULL(C.CartonHeight, '0')    -- (ung02)          
   FROM Cartonization C WITH (NOLOCK)              
   WHERE C.CartonizationGroup = @cCartonGroup              
     AND C.CartonType = @cCartonType              
             
   IF @cPackage_Length = '0' -- (ung02)          
   BEGIN          
      SELECT @cPackage_Length = ISNULL(C.CartonLength, '0') -- (ung02)          
            ,@cPackage_Width  = ISNULL(C.CartonWidth, '0')  -- (ung02)           
            ,@cPackage_Height = ISNULL(C.CartonHeight, '0') -- (ung02)            
      FROM Cartonization C WITH (NOLOCK)              
      WHERE C.CartonizationGroup = @cCartonGroup              
        AND C.CartonType = 'DEFAULT'               
   END           
             
   -- Get PackageID              
   SELECT @cPackageID = CSD.PackageID              
   FROM CartonShipmentDetail CSD WITH (NOLOCK)              
   WHERE CSD.UCCLabelNo = @cLabelNo              
              
   IF @nDebug = 1              
   BEGIN              
      SELECT @cPackage_Length AS 'Package_Length',              
             @cPackage_Width AS 'Package_Width',              
             @cPackage_Height AS 'Package_Height',              
             @cPackageID AS 'PackageID',              
             @cCartonGroup AS 'CartonGroup',              
             @cCartonType AS 'CartonType'              
   END              
              
   SELECT                
      @cSender_Street     = LEFT(F.Descr,25),              
      @cSender_Locale     = CASE WHEN LEN(F.Descr) > 25 THEN SUBSTRING(F.Descr, 26, LEN(F.Descr) -1) ELSE '' END,              
      @cSender_Other      = '',           
      @cSender_City       = F.UserDefine01,              
      @cSender_Region     = F.UserDefine03,              
      @cSender_PostalCode = F.UserDefine04,              
      @cSender_Country    = 'US'              
   FROM FACILITY F WITH (NOLOCK)              
   WHERE F.Facility = @cFacility              
              
   -- Rate Request is only required, if the orders.PmtTerm (payment term) is ΓÇ£ΓÇ¥PPΓÇ¥ or ΓÇ£PCΓÇ¥               
   IF @cBilling_PayerType <> '1'              
   BEGIN              
      -- (ung03)          
      --SET @bSuccess = 0               
      --SET @nErr = 75454              
      --SET @cErrmsg = 'Rate Request is only required when Payment Term is PP or PC. (isp1156P_Agile_Rate)'                
      --           + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
      GOTO Quit              
   END              
              
   IF ISNULL(@cCarrier,'') = ''              
   BEGIN              
      SET @bSuccess = 0               
      SET @nErr = 75455              
      SET @cErrmsg = 'Carrier Code is empty. (isp1156P_Agile_Rate)'                
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
      GOTO Quit              
   END              
              
   IF ISNULL(@cServiceType,'') = ''              
   BEGIN              
      SET @bSuccess = 0               
      SET @nErr = 75456              
      SET @cErrmsg = 'Service Type is empty. (isp1156P_Agile_Rate)'                
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
      GOTO Quit              
   END              
              
   IF ISNULL(@cReceiver_Street,'') = ''              
   BEGIN              
      SET @bSuccess = 0               
      SET @nErr = 75457              
      SET @cErrmsg = 'Receive Street is empty. (isp1156P_Agile_Rate)'                
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
      GOTO Quit              
   END              
              
   IF ISNULL(@cReceiver_City,'') = ''              
   BEGIN              
      SET @bSuccess = 0               
      SET @nErr = 75458              
      SET @cErrmsg = 'Receive City is empty. (isp1156P_Agile_Rate)'                
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
      GOTO Quit              
   END              
              
   IF ISNULL(@cReceiver_Region,'') = ''              
   BEGIN              
      SET @bSuccess = 0               
      SET @nErr = 75459              
      SET @cErrmsg = 'Receive Region is empty. (isp1156P_Agile_Rate)'                
              + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
      GOTO Quit              
   END              
              
   IF ISNULL(@cReceiver_PostalCode,'') = ''              
   BEGIN              
      SET @bSuccess = 0               
      SET @nErr = 75460              
      SET @cErrmsg = 'Receive Postal Code is empty. (isp1156P_Agile_Rate)'                
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
      GOTO Quit              
   END              
              
   IF ISNULL(@cReceiver_Country,'') = ''              
   BEGIN              
      SET @bSuccess = 0               
      SET @nErr = 75461              
      SET @cErrmsg = 'Receive Country is empty. (isp1156P_Agile_Rate)'                
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
      GOTO Quit              
   END              
              
   IF ISNULL(@cPackage_Weight,'') = ''              
   BEGIN              
      SET @bSuccess = 0               
      SET @nErr = 75462              
      SET @cErrmsg = 'Package Weight is empty. (isp1156P_Agile_Rate)'                
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
      GOTO Quit              
   END

   IF ISNULL(@cPackage_PackageType,'') = ''                  
   BEGIN                  
      SET @bSuccess = 0                   
      SET @nErr = 75476                  
      SET @cErrmsg = 'Package Type is empty. (isp1156P_Agile_Rate)'                    
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                    
      GOTO Quit                  
   END

   -- Get Credentials/ShippingKey for Orders.SpecialHandling = 'X' (Chee03)
   IF @cCarrier = '17'
   BEGIN
      IF ISNULL(@cAccountID,'') = ''  
      BEGIN  
         SET @bSuccess = 0  
         SET @nErr = 75480  
         SET @cErrmsg = 'Account Number is empty. (isp1156P_Agile_Rate)'  
                    + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
         GOTO Quit  
      END  

      SELECT @cShippingKey = RTRIM(UDF03)
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = @cListName_CarrierAcc
        AND Code = @cAccountID

      IF ISNULL(@cShippingKey,'') = ''  
      BEGIN  
         SET @bSuccess = 0  
         SET @nErr = 75481  
         SET @cErrmsg = 'Shipping Key is empty. (isp1156P_Agile_Rate)'  
                    + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
         GOTO Quit  
      END  
   END
              
   -- Create XML Request String              
   SET @xRequestString =              
   (              
      SELECT               
         @cPackageID        "TransactionIdentifier",              
         @cCarrier          "Carrier",              
         @cServiceType      "ServiceType",              
         @cShipDate         "ShipDate",              
         @cSaturdayDelivery "SaturdayDelivery",              
         @cAccountID        "AccountID",              
         (              
            SELECT                  
               @cSender_CompanyName "CompanyName",              
               @cSender_Street      "Street",              
               @cSender_Locale      "Locale",              
               @cSender_Other       "Other",              
               @cSender_City        "City",              
               @cSender_Region      "Region",              
               @cSender_PostalCode  "PostalCode",              
               @cSender_Country     "Country"              
            FOR XML PATH('Sender'), TYPE -- PierbridgeRateRequest/Sender              
         ),              
         (              
            SELECT               
               @cReceiver_CompanyName "CompanyName",              
               @cReceiver_Street      "Street",              
               @cReceiver_Locale      "Locale",              
               @cReceiver_Other       "Other",              
               @cReceiver_City        "City",              
               @cReceiver_Region      "Region",              
               @cReceiver_PostalCode  "PostalCode",              
               @cReceiver_Country     "Country"              
            FOR XML PATH('Receiver'), TYPE -- PierbridgeRateRequest/Receiver              
         ),              
         (              
            SELECT               
               @cBilling_PayerType     "PayerType"              
            FOR XML PATH('Billing'), TYPE -- PierbridgeRateRequest/Billing              
         ),              
         (              
            SELECT                  
               (              
                  SELECT              
                     @cPackage_PackageType     "PackageType",   
                     @cPackage_Weight          "Weight",              
                     @cPackage_Length          "Length",              
                     @cPackage_Width           "Width",              
                     @cPackage_Height          "Height",              
                     @cPackage_DeliveryConfirm "DeliveryConfirmation",              
                     (              
                        SELECT              
                           @cPackage_Insurance_Type  "Type",              
                           @cPackage_Insurance_Value "Value"              
                        FOR XML PATH('Insurance'), TYPE -- PierbridgeRateRequest/Packages/Package/Insurance              
                     )              
                  FOR XML PATH ('Package'), TYPE -- PierbridgeRateRequest/Packages/Package              
               )              
            FOR XML PATH('Packages'), TYPE -- PierbridgeRateRequest/Packages              
         ),              
         (
            -- PierbridgeRateRequest/Credentials only required if Orders.SpecialHandling = 'X' (Chee03)
            SELECT CASE @cCarrier WHEN '17' THEN
            (
               SELECT  
                  @cAccountID      "AccountNumber",  
                  @cShippingKey    "ShippingKey"  
               FOR XML PATH('Credentials'), TYPE -- PierbridgeRateRequest/Credentials
            ) ELSE NULL END
         ),
         @cAccountID "UserName"             
      FOR XML PATH(''),              
      ROOT('PierbridgeRateRequest')              
   )              
              
   -- Create Request String             
   SET @cRequestString = @cXMLEncodingString + CAST(@xRequestString AS NVARCHAR(MAX))              
              
   IF @nDebug = 1              
   BEGIN              
      SELECT @xRequestString AS 'XML Request String'              
      SELECT @cRequestString AS 'Request String'              
   END              
              
   -- Get BatchNo using [DTSITF].[dbo].[WebService_Log]              
   EXECUTE [DTSITF].[dbo].[nspg_getkey]              
   'WSDT_BatchNo'                          
   , 10              
   , @cBatchNo output              
   , @bSuccess output              
   , @nErr output              
   , @cErrMsg output              
              
   IF @bSuccess = 0              
   BEGIN              
      SET @nErr = 75463              
      SET @cErrmsg = 'Failed to obtain BatchNo. (isp1156P_Agile_Rate)'                
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
      GOTO Quit              
   END              
              
   IF @nDebug = 1              
   BEGIN              
      SELECT               
         @cBatchNo AS 'BatchNo'              
   END              
              
   BEGIN TRAN               
              
   -- Insert Request String into [DTSITF].[dbo].[WebService_Log]              
   INSERT INTO [DTSITF].[dbo].[WebService_Log](              
      [DataStream],              
      [StorerKey],              
      [Type],               
      [BatchNo],               
      [WebRequestURL],               
      [WebRequestMethod],               
      [ContentType],               
      [RequestString],               
      [Status],              
      [ClientHost],               
      [WSIndicator],       
      [SourceKey],           
      [SourceType]           
   )              
   OUTPUT INSERTED.SeqNo INTO @StoreSeqNoTempTable              
   VALUES(              
      @cDataStream,               
      @cStorerKey,              
      'O',           -- Output              
      @cBatchNo,              
      @cWebRequestURL,               
      @cWebRequestMethod,               
      @cContentType,               
      @cRequestString,               
      @cStatus,              
      'C',           -- Client              
      'R',           -- RealTime              
      @cLabelNo,           
      'isp1156P_Agile_Rate'          
   )              
                         
   IF @@ERROR <> 0               
   BEGIN                  
      SET @bSuccess = 0               
      SET @nErr = 75464              
      SET @cErrmsg = 'Error inserting into [DTSITF].[dbo].[WebService_Log] Table. (isp1156P_Agile_Rate)'                
          + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'              
           
      ROLLBACK TRAN                
      GOTO Quit              
   END              
   ELSE              
   BEGIN              
      COMMIT TRAN              
   END               
              
   -- Get SeqNo              
   SELECT @nSeqNo = SeqNo               
   FROM @StoreSeqNoTempTable 

   -- Chee02  
   EXEC dbo.nspGetRight        
      NULL,        
      NULL,        
      NULL,        
      'WebServiceClientContingency',        
      @bSuccess               OUTPUT,        
      @cWSClientContingency   OUTPUT,         
      @nErr                   OUTPUT,         
      @cErrMsg                OUTPUT    
        
   IF NOT @bSuccess = 1        
   BEGIN        
      SET @bSuccess = 0         
      SET @nErr = 75478        
      SET @cErrmsg = 'nspGetRight WebServiceClientContingency Failed. (isp1156P_Agile_Rate)'          
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'          
      GOTO Quit        
   END               

   IF @nDebug = 1        
   BEGIN        
      SELECT @cWSClientContingency AS '@cWSClientContingency'      
   END
              
   SET @dTimeIn = GETDATE()              
              
   IF @cWSClientContingency <> '1'  
   BEGIN  
      -- Send RequestString and Receive ResponseString               
      EXEC [master].[dbo].[isp_GenericWebServiceClient]              
         @cIniFilePath,              
         @cWebRequestURL,              
         @cWebRequestMethod,              
         @cContentType,              
         @cWebRequestEncoding,              
         @cRequestString,              
         @cResponseString   OUTPUT,              
         @cVBErrMsg         OUTPUT              
                           
      IF @@ERROR <> 0 OR ISNULL(@cVBErrMsg,'') <> ''               
      BEGIN                  
         SET @cStatus = '5'                
         SET @bSuccess = 0               
         SET @nErr = 75465                
                       
         -- SET @cErrmsg                  
         IF ISNULL(@cVBErrMsg,'') <> ''                  
         BEGIN                  
            SET @cErrmsg = CAST(@cVBErrMsg AS NVARCHAR(250))                  
         END                  
         ELSE                  
         BEGIN                  
            SET @cErrmsg = 'Error executing [master].[dbo].[isp_GenericWebServiceClient]. (isp1156P_Agile_Rate)'                
                          + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
         END              
      END              
   END  
   ELSE  
   BEGIN  
      SELECT @cConnectionString = 'Data Source=' + UDF01 + ';uid=' + UDF02 + ';pwd=' + dbo.fnc_DecryptPWD(UDF03) 
                                  + ';Application Name=' + UDF04 + ';Enlist=false'
      FROM CODELKUP WITH (NOLOCK)  
      WHERE LISTNAME = @cListName  
        AND Code = @cCode_ConnString  
  
      EXEC [master].[dbo].[isp_GenericWebServiceClient_Contingency]       
         @cConnectionString,  
         @cIniFilePath,  
         @cWebRequestURL,  
         @cWebRequestMethod,  
         @cContentType,  
         @cWebRequestEncoding,  
         @cRequestString,  
         @cResponseString   OUTPUT,  
         @cvbErrMsg         OUTPUT    
      
      IF @@ERROR <> 0 OR ISNULL(@cVBErrMsg,'') <> ''        
      BEGIN        
         SET @cStatus = '5'        
         SET @bSuccess = 0        
         SET @nErr = 75479      
           
         -- SET @cErrmsg        
         IF ISNULL(@cVBErrMsg,'') <> ''        
         BEGIN        
            SET @cErrmsg = CAST(@cVBErrMsg AS NVARCHAR(250))        
         END        
         ELSE        
         BEGIN        
            SET @cErrmsg = 'Error executing [master].[dbo].[isp_GenericWebServiceClient_Contingency]. (isp1156P_Agile_Rate)'        
                          + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'        
         END        
      END    
   END -- IF @cWSClientContingency <> '1'  
              
   SET @dTimeOut = GETDATE()              
   SET @nTotalTime = DATEDIFF(ms, @dTimeIn, @dTimeOut)              
              
   BEGIN TRAN              
              
   UPDATE [DTSITF].[dbo].[WebService_Log] WITH (ROWLOCK)              
   SET Status = @cStatus, ErrMsg = @cErrmsg, TimeIn = @dTimeIn--, [Try] = [Try] + 1              
   WHERE SeqNo = @nSeqNo              
                        
   IF @@ERROR <> 0               
   BEGIN                  
      SET @bSuccess = 0               
      SET @nErr = 75466              
      SET @cErrmsg = 'Error updating [DTSITF].[dbo].[WebService_Log] Table. (isp1156P_Agile_Rate)'                
                    + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
              
     ROLLBACK TRAN                
     GOTO Quit              
   END              
   ELSE              
   BEGIN              
      COMMIT TRAN              
   END               
              
   -- Quit for [master].[dbo].[isp_GenericWebServiceClient] error              
   IF @cStatus = '5'              
   BEGIN              
      GOTO Quit              
   END              
              
   -- Get rid of the encoding part in the root tag to prevent error: unable to switch the encoding              
   SET @xReponseString = CAST(REPLACE(@cResponseString, 'encoding="' + @cWebRequestEncoding + '"', '') AS XML)              
              
   IF @nDebug = 1              
   BEGIN              
      SELECT @xReponseString AS 'XML Response String'              
      SELECT @cResponseString AS 'Response String'              
   END              
              
   BEGIN TRAN              
              
   -- Insert Response String into [DTSITF].[dbo].[WebService_Log]              
   INSERT INTO [DTSITF].[dbo].[WebService_Log](              
      [DataStream],              
      [StorerKey],              
      [Type],               
      [BatchNo],               
      [WebRequestURL],               
      [WebRequestMethod],               
      [ContentType],               
      [ResponseString],               
      [TimeOut],               
      [TotalTime],               
      [Status],              
      [ClientHost],               
      [WSIndicator],           
      [SourceKey],           
      [SourceType]               
   )               
 VALUES(              
      @cDataStream,               
      @cStorerKey,              
      'I',           -- Input              
      @cBatchNo,              
      @cWebRequestURL,               
      @cWebRequestMethod,               
      @cContentType,               
      @cResponseString,               
      @dTimeOut,               
      @nTotalTime,               
      @cStatus,              
      'C',           -- Client              
      'R',           -- RealTime              
      @cLabelNo,           
      'isp1156P_Agile_Rate'          
   )              
         
   IF @@ERROR <> 0               
   BEGIN                  
      SET @bSuccess = 0               
      SET @nErr = 75467              
      SET @cErrmsg = 'Error inserting into [DTSITF].[dbo].[WebService_Log] Table. (isp1156P_Agile_Rate)'                
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
              
      ROLLBACK TRAN                
      GOTO Quit              
   END              
   ELSE              
   BEGIN              
      COMMIT TRAN              
   END               
              
   -- Extract ResponseString Data              
   EXEC sp_xml_preparedocument @ndoc OUTPUT, @xReponseString              
              
   -- SELECT statement that uses the OPENXML rowset provider.              
   SELECT                
      @cTransactionIdentifier             =   TransactionIdentifier,              
      @fShippingCharge                    =   ShippingCharge,              
      @fAccessorialCharge                 =   AccessorialCharge,              
      @nStatus_Code                       =   Status_Code,              
      @cStatus_Desc                       =   Status_Desc              
   FROM OPENXML (@ndoc, '/PierbridgeRateResponse/Packages/Package', 2)              
   WITH(              
      TransactionIdentifier            NVARCHAR(10)   '../../TransactionIdentifier',              
      ShippingCharge                   FLOAT         '../../ShippingCharge',              
    AccessorialCharge                FLOAT         '../../AccessorialCharge',              
      Status_Code                      INT           'Status/Code',              
      Status_Desc                      NVARCHAR(215)  'Status/Description'              
   )              
              
   EXEC sp_xml_removedocument @ndoc              
              
   IF @nDebug = 1              
   BEGIN              
   SELECT                
      @cTransactionIdentifier AS 'TransactionIdentifier',              
      @fShippingCharge AS 'ShippingCharge',              
      @fAccessorialCharge AS 'AccessorialCharge',                    
      @nStatus_Code AS 'Status_Code',              
      @cStatus_Desc AS 'Status_Desc'              
   END              
              
   -- Response Failed              
   IF @nStatus_Code = 0              
   BEGIN              
      SET @bSuccess = 0               
      SET @nErr = 75469               
      SET @cErrmsg = @cStatus_Desc + ' (isp1156P_Agile_Rate)'                
                    + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'
      GOTO Quit              
   END
   -- Response Success
   ELSE IF @nStatus_Code = 1
   BEGIN
      IF @nDebug = 1              
      BEGIN              
         SELECT @cStatus_Desc AS 'Response Status Description'              
      END              

      IF @cTransactionIdentifier <> ISNULL(@cPackageID,'')              
      BEGIN              
         SET @bSuccess = 0               
         SET @nErr = 75468              
         SET @cErrmsg = 'Incorrect Transaction Identifier returned. (isp1156P_Agile_Rate)'                
           + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
         GOTO Quit              
      END              

      IF @fShippingCharge IS NULL              
      BEGIN              
         SET @bSuccess = 0               
         SET @nErr = 75470               
       SET @cErrmsg = 'Shipping Charge is empty. (isp1156P_Agile_Rate)'                
                       + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
         GOTO Quit              
      END              

      IF @fAccessorialCharge IS NULL               
      BEGIN              
         SET @bSuccess = 0               
         SET @nErr = 75471               
         SET @cErrmsg = 'Accessorial Charge is empty. (isp1156P_Agile_Rate)'                
                       + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
         GOTO Quit              
      END              

      IF EXISTS (SELECT 1 FROM CartonShipmentDetail WITH (NOLOCK)              
                 WHERE UCCLabelNo = @cLabelNo)              
      BEGIN              
              
      BEGIN TRAN              
              
      -- Insert/Update into Table              
      UPDATE CartonShipmentDetail WITH (ROWLOCK)                  
      SET FreightCharge = @fShippingCharge,               
          InsCharge = @fAccessorialCharge,              
          CartonWeight = @cPackage_Weight              
      WHERE UCCLabelNo = @cLabelNo              
                        
      IF @@ERROR <> 0               
      BEGIN                  
         SET @bSuccess = 0               
         SET @nErr = 75472              
         SET @cErrmsg = 'Error updating [dbo].[CartonShipmentDetail] Table. (isp1156P_Agile_Rate)'                
                      + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'               
                 
         ROLLBACK TRAN                
         GOTO Quit              
      END              
      ELSE              
      BEGIN              
         COMMIT TRAN              
      END               
      END              
      ELSE              
      BEGIN              
         BEGIN TRAN              
                      
      -- INSERT INTO CartonShipmentDetail                  
      INSERT INTO CartonShipmentDetail (              
         Storerkey,               
         Orderkey,         
         Loadkey,               
         Mbolkey,               
         Externorderkey,               
         Buyerpo,               
         UCCLabelNo,               
         CartonWeight,               
         DestinationZipCode,              
         FreightCharge,              
         InsCharge              
      )                 
      VALUES (              
         @cStorerKey,               
         @cOrderKey,               
         @cLoadKey,               
         @cMbolKey,               
         @cExternOrderKey,               
         @cBuyerPO,               
         @cLabelNo,               
         @cPackage_Weight,               
         @cReceiver_PostalCode,              
         @fShippingCharge,              
         @fAccessorialCharge              
      )               
                       
      IF @@ERROR <> 0               
      BEGIN                  
         SET @bSuccess = 0               
         SET @nErr = 75475              
         SET @cErrmsg = 'Error inserting into [dbo].[CartonShipmentDetail] Table. (isp1156P_Agile_Rate)'                
                      + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
              
         ROLLBACK TRAN                
      END              
      ELSE              
      BEGIN              
         COMMIT TRAN              
      END               
      END              
   END              
   ELSE              
   BEGIN              
      SET @bSuccess = 0               
      SET @nErr = 75473              
    SET @cErrmsg = 'Invalid Status Code. (isp1156P_Agile_Rate)'                
              + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
      GOTO Quit              
   END              
              
Quit:              
   -- Send Email Alert              
   IF NOT @bSuccess = 1              
   BEGIN              
      -- Get InterfaceLogID using [DTSITF].[dbo].[WebService_Log]          
      EXECUTE [DTSITF].[dbo].[nspg_getkey]              
         'InterfaceLogID'              
        , 10              
        , @nLogAttachmentID OUTPUT              
        , @bSuccess         OUTPUT              
        , @nErr                           
        , @cErrmsg                        
              
      IF NOT @bSuccess = 1              
      BEGIN              
         SET @bSuccess = 0               
         SET @nErr = 75452              
         SET @cErrmsg = 'Failed to obtain InterfaceLogID. (isp1156P_Agile_Rate)'                
                    + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
         GOTO Outlog              
      END              
              
      -- Get File Key using [DTSITF].[dbo].[WebService_Log]              
      EXECUTE nspg_getkey              
         'Filekey'              
        , 10              
        , @nLogFilekey OUTPUT              
        , @bSuccess    OUTPUT              
        , @nErr                      
        , @cErrmsg                   
              
      IF NOT @bSuccess = 1              
      BEGIN              
         SET @bSuccess = 0               
         SET @nErr = 75453              
         SET @cErrmsg = 'Failed to obtain FileKey. (isp1156P_Agile_Rate)'                
                    + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'                
         GOTO Outlog              
      END              
              
Outlog:              
      SET @cLineText = 'AGILE Web Service Rate Failed. Error: ' + RTRIM(@cErrmsg)              
                     + ', PickSlipNo: ' + RTRIM(@cPickSlipNo)              
                     + ', CartonNo: ' + CAST(@nCartonNo AS NVARCHAR(10))               
                     + ', LabelNo: ' + RTRIM(@cLabelNo)              
              
      IF @nDebug = 1              
      BEGIN              
         SELECT @nLogFilekey AS 'Log File Key'              
               ,@cDataStream AS 'DataStream'              
               ,@cFileName AS 'FileName'              
               ,@nLogAttachmentID AS 'LogAttachmentID'              
               ,@cLineText AS 'LineText'              
      END            
      ELSE              
      BEGIN              
         INSERT INTO [DTSITF].[dbo].[Out_log] (File_key, DataStream, [FileName], AttachmentID, LineText)              
         VALUES (@nLogFilekey, @cDataStream, @cFileName, @nLogAttachmentID, @cLineText)              
      END     
      SET @bSuccess = 0           
   END              
              
   /***********************************************/                    
   /* Std - Send Email Alert (Start)              */                    
   /***********************************************/                   
              
   IF EXISTS (SELECT 1 FROM [DTSITF].[dbo].[Out_log]               
              WHERE File_key = @nLogFilekey               
              AND DataStream = @cDataStream)              
   BEGIN              
      EXEC [DTSITF].[dbo].[ispEmailAlert] @nLogAttachmentID, @cDataStream, 'I',               
                          'Error Log File for US AGILE Rate' ,              
                          'Please refer to the attached file..',               
                          @bSuccess  OUTPUT              
   END              
   /***********************************************/                    
   /* Std - Send Email Alert (End)                */                    
   /***********************************************/                 
              
END  -- Procedure

GO