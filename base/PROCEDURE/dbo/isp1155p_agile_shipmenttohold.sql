SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* SP: isp1155P_Agile_ShipmentToHold                                    */  
/* Creation Date: 08 Mar 2012                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Chee Jun Yan                                             */  
/*                                                                      */  
/* Purpose: SOS#237558 - Agile Elite - Shipment to Hold Request         */  
/*          SOS#237559 - Agile Elite - Shipment to Hold Response        */  
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
/* RDT message range: 75651 - 75700                                     */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver      Purposes                              */  
/* 23-Mar-2012  James    1.1      Revamp re-triggering of AGILE         */  
/*                                process (james01)                     */  
/* 23-Mar-2012  James    1.2      Bug fix (james02)                     */  
/* 26-Mar-2012  James    1.3      Bug fix (james03)                     */  
/* 28-Mar-2012  James    1.4      AGILE require date to be blank        */  
/*                                if it is null (james04)               */  
/* 29-Mar-2012  Shong    1.5      Set Agile Code = Codelkup.Short       */  
/* 03-Apr-2012  Chee     1.6      Get Agile Web Service Request URL     */  
/*                                from CODELKUP (Chee01)                */  
/* 07-Apr-2012  Ung      1.7      If ShipDate Sat,Sun, set as Mon(ung01)*/  
/* 10-Apr-2012  Shong    1.8      Do not Process if International Order */  
/* 13-Apr-2012  Shong    1.9      Performance Tuning                    */  
/* 14-Apr-2012  Shong    2.0      User Account No as User Name          */  
/* 16-Apr-2012  Shong    2.1      Added SourceKey, SourceType to Web Log*/  
/* 21-Apr-2012  Shong    2.2      Update Multiple Orders for ConsoKey   */  
/* 22-Apr-2012  Shong    2.3      Get New Traking# when Service Type    */  
/*                                Changed SOS#242341                    */  
/* 27-Apr-2012  Shong    2.4      Agile UPS Do not allow to ship Carton */  
/*                                with Weight less then 1 lbs. Default  */  
/*                                to 1 if Cacl Weight less then 1       */  
/* 29-Apr-2012  Shong    2.5      Still Allow to Call Agile If  Tracking*/  
/*                                Number is Blank                       */  
/* 01-May-2012  Ung      2.6      Limit weight calculation to range     */  
/* 02-May-2012  Shong    2.7      Add 90 Days to Ship Date for Serv Type*/  
/*                                117 & 118                             */  
/* 07-May-2012  James    2.8      Change set shipdate = 85 days for     */  
/*                                Serv Type 117 & 118                   */  
/* 24-JUL-2012  ChewKP   2.9      Get OrderKey by LabelNo (ChewKP01)    */  
/* 28-May-2012  Ung    3.0      SOS245083 chg master and child carton */  
/*                                on get tracking no, print GS1 (ung02) */  
/* 11-Sep-2012  Chee     3.1      Map LEFT(B_Country,2) to              */  
/*                                PierbridgeShipRequest/Billing/Country */  
/*                                #254993 (Chee02)                      */  
/* 20-Sep-2012  Chee     3.2      Add isp_GenericWebServiceClient_      */  
/*                                Contingency (Chee03)                  */  
/* 21-Dec-2012  Leong             SOS# 264909 - Add TraceInfo           */  
/* 18-Feb-2013  Chee     3.3      SOS# 269328 - Get ShipmentID instead  */
/*                                of PackageID from AGILE ShipmentToHold*/
/*                                XML response (Chee04)                 */
/* 27-Jun-2013  Chee     3.4      SOS# 281445 - Add Credentials to      */ 
/*                                AGILE ShipmentToHold XML request for  */
/*                                Orders.SpecialHandling = 'X' (Chee05) */
/* 20-Jul-2016	 KTLow	 3.5		 Add WebService Client Parameter (KT01)*/
/* 28-Jan-2019  TLTING_ext 3.6    enlarge externorderkey field length   */
/************************************************************************/  
  
CREATE PROC [dbo].[isp1155P_Agile_ShipmentToHold](  
    @cPickSlipNo     NVARCHAR(10)  
   ,@nCartonNo       INT  
   ,@cLabelNo        NVARCHAR(20)  
   ,@bSuccess        INT            OUTPUT  
   ,@nErr            INT            OUTPUT  
   ,@cErrMsg         NVARCHAR(215)   OUTPUT  
   ,@cCartonType     NVARCHAR(10) = ''  
)  
AS  
BEGIN  
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
  
   DECLARE  
       @cShipToHold              NVARCHAR(1)  
      ,@cCarrier                 NVARCHAR(10)  
      ,@cServiceType             NVARCHAR(10)  
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
      ,@cBilling_PayerType       NVARCHAR(10)  
      ,@cBilling_AccountNumber   NVARCHAR(18)  
      ,@cBilling_CompanyName     NVARCHAR(45)  
      ,@cBilling_Street          NVARCHAR(45)  
      ,@cBilling_Locale          NVARCHAR(45)  
      ,@cBilling_Other           NVARCHAR(45)  
      ,@cBilling_City            NVARCHAR(45)  
      ,@cBilling_Region          NVARCHAR(45)  
      ,@cBilling_PostalCode      NVARCHAR(18)  
      ,@cPackage_ReceiverName    NVARCHAR(30)  
      ,@cPackage_ReceiverPhone   NVARCHAR(18)  
      ,@cPackage_PackageType     NVARCHAR(10)  
      ,@cPackage_Weight          NVARCHAR(20)  
      ,@cPackage_Insurance_Type  NVARCHAR(1)  
      ,@cPackage_Insurance_Value NVARCHAR(20)  
      ,@cPackage_DeliveryConfirm NVARCHAR(1)  
      ,@cUserDefine03            NVARCHAR(20)  
      ,@cExternOrderKey          NVARCHAR(50)  --tlting_ext
      ,@cBuyerPO                 NVARCHAR(20)  
      ,@cConsigneeKey            NVARCHAR(15)  
      ,@cFacility                NVARCHAR(5)  
      ,@cPH_OrderKey             NVARCHAR(10)  
      ,@cPH_ConsoOrderKey        NVARCHAR(30)  
      ,@cPH_LoadKey              NVARCHAR(10)  
      ,@cBilling_Country         NVARCHAR(2)   -- Chee02  
  
   DECLARE  
      @cPLD_RefNo1         NVARCHAR(30),  
      @cPLD_RefNo2         NVARCHAR(30),  
      @cPLD_RefNo3         NVARCHAR(30),  
      @cPLD_RefNo4         NVARCHAR(30),  
      @cPLD_RefNo5         NVARCHAR(30),  
      @cPLD_RefNoValue1    NVARCHAR(30),  
      @cPLD_RefNoValue2    NVARCHAR(30),  
      @cPLD_RefNoValue3    NVARCHAR(30),  
      @cPLD_RefNoValue4    NVARCHAR(30),  
      @cPLD_RefNoValue5    NVARCHAR(30)  
  
   DECLARE  
      @cIniFilePath           NVARCHAR(100),  
      @cWebRequestURL         NVARCHAR(1000),  
      @cWebRequestMethod      NVARCHAR(10),  
      @cContentType           NVARCHAR(100),  
      @cWebRequestEncoding    NVARCHAR(30),  
      @cXMLEncodingString     NVARCHAR(100),  
      @cRequestString         NVARCHAR(MAX),  
      @cResponseString        NVARCHAR(MAX),  
      @cVBErrMsg              NVARCHAR(MAX),  
      @xRequestString         XML,  
      @xReponseString         XML,  
      @dTimeIn                DATETIME,  
      @dTimeOut               DATETIME,  
      @nTotalTime             INT,  
      @cStatus                NVARCHAR(1),  
      @cOrderKey              NVARCHAR(10),  
      @cStorerKey             NVARCHAR(15),  
      @cLoadKey               NVARCHAR(10),  
      @cMbolKey               NVARCHAR(10),  
      @nDebug                 INT,  
      @nSeqNo                 INT,  
      @cDataStream            NVARCHAR(4),  
      @cBatchNo               NVARCHAR(10),  
      @cUserName              NVARCHAR(30),  
      @cListName              NVARCHAR(10),  
      @cCode_FilePath         NVARCHAR(30),  
      @cPreviousCarrier       NVARCHAR(5),  
      @cPreviousServTyp       NVARCHAR(4),  
      @cLabelPrinted          NVARCHAR(10),  
      @cCode_AgileURL         NVARCHAR(30),    -- Chee01  
      @cM_Phone2              NVARCHAR(18),  
      @nTrancount             INT,  
      @cCode_ConnString       NVARCHAR(30),    -- Chee03  
      @cWSClientContingency   NVARCHAR(1),     -- Chee03  
      @cConnectionString      NVARCHAR(250),  -- Chee03  
      @cShippingKey           NVARCHAR(60),    -- Chee05
      @cListName_CarrierAcc   NVARCHAR(10)     -- Chee05

   DECLARE  
      @ndoc                               INT,  
      @cTransactionIdentifier             NVARCHAR(20),  
      @nStatus_Code                       INT,  
      @cStatus_Desc                       NVARCHAR(215),  
      @cTrackingNumber                    NVARCHAR(30),  
      @cPackageID                         NVARCHAR(30),  
      @cUPS_ServiceName                   NVARCHAR(18),  
      @cUPS_ServiceIcon                   NVARCHAR(18),  
      @cUPS_Maxicode                      NVARCHAR(30),  
      @cUPS_RoutingCode                   NVARCHAR(20),  
      @cUPS_URCVersion                    NVARCHAR(30),  
      @cFEG_96Barcode                     NVARCHAR(30),  
      @cFEE_UrsaCode                      NVARCHAR(10),  
      @cFEE_FormCode                      NVARCHAR(10),  
      @cFEE_AstraBarCode                  NVARCHAR(45),  
      @cFEE_PlannedServiceLevel           NVARCHAR(30),  
      @cFEE_ProductName                   NVARCHAR(45),  
      @cFEE_SpecialHandlingAcronyms       NVARCHAR(30),  
      @cFEE_DestinationAirportIdentifier  NVARCHAR(5)  
  
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
  
   SET @cDataStream          = '1155'  
   SET @cListName            = 'WebService'  
   SET @cCode_FilePath       = 'FilePath'  
   SET @cUserName            = 'Administrator'  
   SET @cCode_AgileURL       = 'AgileURL'      -- Chee01  
   SET @cCode_ConnString     = 'ConnString'    -- Chee03  
   SET @cListName_CarrierAcc = 'CARRIERACC'    -- Chee05
  
   -- Log file Name  
   SET @cFileName = 'AGILE_ShipToHold_' + @cLabelNo + '_' + REPLACE(REPLACE(REPLACE(convert(varchar, getdate(), 120),'-',''),':',''),' ','') + '.log'  
  
 --SET @cWebRequestURL      = 'http://LFUSAAE15.lfusa.com/AgileElite Shipping/Services/XmlService.aspx'  -- Chee01  
   SET @cWebRequestMethod   = 'POST'  
   SET @cContentType        = 'application/x-www-form-urlencoded'  
   SET @cWebRequestEncoding = 'utf-8'  
   SET @cXMLEncodingString  = '<?xml version="1.0" encoding="' + @cWebRequestEncoding + '"?>'  
  
   -- Get OrderKey  
   SET @cPH_OrderKey = ''  
   SET @cPH_ConsoOrderKey = ''  
   SET @cPH_LoadKey = ''  
  
   DECLARE @tOrders TABLE (OrderKey NVARCHAR(10))  
  
   SELECT @cPH_ConsoOrderKey = ISNULL(PH.ConsoOrderKey, ''),  
          @cPH_OrderKey      = ISNULL(PH.OrderKey,''),  
          @cPH_LoadKey       = ISNULL(PH.LoadKey, '')  
   FROM PackHeader ph WITH (NOLOCK)  
   WHERE ph.PickSlipNo = @cPickSlipNo  
  
   SET @cTrackingNumber = ''  
   SELECT TOP 1  
      @cTrackingNumber = ISNULL(RTRIM(pd.UPC),'')  
   FROM PACKDETAIL  pd WITH (NOLOCK)  
   WHERE pd.PickSlipNo = @cPickSlipNo  
     AND pd.CartonNo   = @nCartonNo  
     AND pd.LabelNo    = @cLabelNo  
  
   IF ISNULL(RTRIM(@cPH_OrderKey),'') <> ''  
   BEGIN  
      SET @cOrderKey = @cPH_OrderKey  
      INSERT INTO @tOrders(OrderKey) VALUES (@cOrderKey)  
   END  

   IF ISNULL(RTRIM(@cOrderKey),'') = '' AND  ISNULL(RTRIM(@cPH_ConsoOrderKey),'') <> ''  
   BEGIN  
      SET @cOrderKey = ''  
  
-- (ChewKP01)  
--    INSERT INTO @tOrders(OrderKey)  
--    SELECT DISTINCT ISNULL(RTRIM(OD.OrderKey),'')  
--    FROM ORDERDETAIL od WITH (NOLOCK, INDEX(IX_ORDERDETAIL_ConsoOrderKey))  
--    WHERE od.ConsoOrderKey = @cPH_ConsoOrderKey  
  
-- (ChewKP01)  
      INSERT INTO @tOrders(OrderKey)  
      SELECT DISTINCT ISNULL(RTRIM(PD.OrderKey),'')  
      FROM PICKDETAIL PD WITH (NOLOCK)  
      INNER JOIN PACKHEADER PH WITH (NOLOCK) ON PH.PICKSLIPNO = PD.PICKSLIPNO  
      INNER JOIN PACKDETAIL PACKD WITH (NOLOCK) ON PD.DropID = PACKD.DropID AND PD.PICKSLIPNO = PACKD.PICKSLIPNO  
      WHERE PACKD.LABELNO = @cLabelNo  
  
      IF EXISTS(SELECT 1 FROM @tOrders)  
      BEGIN  
         SELECT TOP 1  
            @cOrderKey = OrderKey  
         FROM @tOrders 
      END  
   END  
  
   IF @nDebug = 1  
   BEGIN  
      SELECT @cOrderKey AS 'OrderKey'  
            ,@cTrackingNumber AS 'Tracking Number'  
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
  
   SET @cM_Phone2 = ''  
   SELECT  
      @cShipToHold              = '1',  -- Set to 1 to indicate that the shipment should be rated  
      @cCarrier                 = CASE O.SpecialHandling  
                                     WHEN 'U' THEN '12'  
                                     WHEN 'X' THEN '17'  
                                     ELSE ''  
                                  END,  
      @cServiceType             = CASE WHEN O.SpecialHandling IN ('U','X','D')  
                                       THEN RTRIM(ST.AgileCode)  
                                  ELSE RTRIM(O.M_Phone2)  
                                  END,  
      @cM_Phone2                = ISNULL(O.M_Phone2,''),  
      @cSaturdayDelivery        = CASE LEFT(O.B_Fax1,1) WHEN 'Y' THEN 'True' ELSE NULL END,  
    --@cShipDate                = '', -- Default to current date if left blank  
      @cAccountID               = RTRIM(O.M_Fax1),
      @cReceiver_CompanyName    = RTRIM(O.C_Company),  
      @cReceiver_Street         = RTRIM(O.C_Address1),  
      @cReceiver_Locale         = RTRIM(O.C_Address2),  
      @cReceiver_Other          = RTRIM(O.C_Address3),  
      @cReceiver_City           = RTRIM(O.C_City),  
      @cReceiver_Region         = RTRIM(o.C_State),  
      @cReceiver_PostalCode     = RTRIM(O.C_Zip),  
      @cReceiver_Country        = LEFT(O.C_Country,2),  
      @cBilling_PayerType       = CASE O.PmtTerm  
                                     WHEN 'PP' THEN  1 --Sender  
                                     WHEN 'PC' THEN  1 --Sender  
                                     WHEN 'BP' THEN  2 --Recipient  
                                     WHEN 'TP' THEN  3 --Third Party  
                                     WHEN 'CC' THEN  4 --Consignee  
                                     ELSE  5 -- Invoice  
                                  END,  
      @cBilling_AccountNumber   = RTRIM(O.B_Fax2),  
      @cBilling_CompanyName     = RTRIM(O.B_Company),  
      @cBilling_Street          = RTRIM(O.B_Address1),  
      @cBilling_Locale          = RTRIM(O.B_Address2),  
      @cBilling_Other           = RTRIM(O.B_Address3),  
      @cBilling_City            = RTRIM(O.B_City),  
      @cBilling_Region          = RTRIM(O.B_State),  
      @cBilling_PostalCode      = RTRIM(O.B_Zip),  
      @cUserDefine03            = RTRIM(O.UserDefine03),  
      @cExternOrderKey          = RTRIM(O.ExternOrderKey),  
      @cPackage_ReceiverName    = RTRIM(O.C_Contact1),  
      @cPackage_ReceiverPhone   = RTRIM(O.C_Phone1),  
      --@cPackage_PackageType     = '27',  
      @cPackage_PackageType     = CASE O.SpecialHandling  
                                     WHEN 'U' THEN '27'  
                                     WHEN 'X' THEN '43'  
                                     ELSE ''  
                                  END,  
      @cPackage_Insurance_Type  = CASE WHEN SUBSTRING(O.B_Fax1,2,1) = 'Y' THEN '1' ELSE '0' END,  
      @cSender_CompanyName      = RTRIM(s.Company),  
      @cStorerKey               = O.StorerKey,  
      @cLoadKey                 = O.LoadKey,  
      @cMbolKey                 = O.MbolKey,  
      @cFacility                = O.Facility,  
      @cBuyerPO                 = O.BuyerPO,  
      @cConsigneeKey            = O.ConsigneeKey,  
      @cPackage_DeliveryConfirm = CASE O.M_Phone1 WHEN 'Y' THEN '2' ELSE NULL END,  
      @cBilling_Country         = LEFT(O.B_Country, 2)   -- Chee02
      FROM ORDERS O WITH (NOLOCK)  
      JOIN STORER s WITH (NOLOCK) ON s.StorerKey = O.StorerKey  
      LEFT OUTER JOIN @t_ServiceType ST ON ST.SpecialHandling = O.SpecialHandling  
                                            AND ST.Code = O.M_Phone2  
      WHERE O.OrderKey = @cOrderKey  
  
   -- Set ship date (ung01)  
   IF @cServiceType = '117' OR @cServiceType = '118'  
   BEGIN  
   /*  
      SET @cShipDate =  
         CASE DATEPART( dw, DATEADD(day, 90, GETDATE()))  
            WHEN 1 THEN CONVERT(char(10), DATEADD(day, 90, GETDATE()) + 1, 126) -- if Sun, set to Mon  
            WHEN 7 THEN CONVERT(char(10), DATEADD(day, 90, GETDATE()) + 2, 126) -- if Sat, set to Mon  
            ELSE CONVERT(char(10), DATEADD(day, 90, GETDATE()), 126)  
         END  
   */  
      SET @cShipDate = CONVERT(char(10), DATEADD(day, 85, GETDATE()), 126)    -- (jamesxxx)  
   END  
   ELSE  
   BEGIN  
      SET @cShipDate =  
         CASE DATEPART( dw, GETDATE())  
            WHEN 1 THEN CONVERT(char(10), GETDATE() + 1, 126) -- if Sun, set to Mon  
            WHEN 7 THEN CONVERT(char(10), GETDATE() + 2, 126) -- if Sat, set to Mon  
            ELSE CONVERT(char(10), GETDATE(), 126)  
         END  
   END  
  
   SELECT  
      @cLabelPrinted = d.LabelPrinted  
   FROM DropIDDetail d WITH (NOLOCK)  
   WHERE d.ChildID = @cLabelNo  
  
   IF @cLabelPrinted = 'Y' AND ISNULL(@cTrackingNumber,'') <> ''  
   BEGIN  
      GOTO Quit  
   END  
  
   -- (james01)  
   -- If Packdetail.UPC is not blank, compare previous and current carrier  
   IF ISNULL(@cTrackingNumber,'') <> ''  
   BEGIN  
--      -- Check if carrier changed before  
--      IF EXISTS (SELECT 1 FROM dbo.Transmitlog3 WITH (NOLOCK)  
--         WHERE Tablename = 'CHANGE_CARRIER_LOG'  
--         AND Transmitflag <> '9'  
--         AND Key1 = @cOrderKey  
--         AND Key3 = @cStorerKey  )  
--      BEGIN  
      -- Get most recent Previous Carrier from transmitlog table  
      SET @cPreviousCarrier = ''  
      SET @cPreviousServTyp = ''  
      SELECT TOP 1  
         @cPreviousCarrier = CASE SUBSTRING(t.key2,1,1)  
                                WHEN 'U' THEN '12'  
                                WHEN 'X' THEN '17'  
                                ELSE ''  
                             END,  
         @cPreviousServTyp = SUBSTRING(ISNULL(t.key2,''),2,4)  
      FROM transmitlog3 t WITH (NOLOCK)  
      JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = t.key1)  
      WHERE tablename = 'CHANGE_CARRIER_LOG'  
         AND t.transmitflag <> '9'  
         AND t.key1 = @cOrderKey  
         AND t.key3 = @cStorerKey  
         AND O.Status <> '9'  
      ORDER BY transmitlogkey DESC  

      IF ISNULL(@cPreviousCarrier,'') = ''  
      BEGIN  
         GOTO Quit  
      END  

      -- IF Previous and Current Carrier is equal, exit SP  
      IF @cCarrier = @cPreviousCarrier AND @cM_Phone2 = @cPreviousServTyp  
      BEGIN  
         GOTO Quit  
      END  
      ELSE  
      BEGIN  
         -- Reset @cTrackingNumber variable  
         SET @cTrackingNumber = NULL  
      END  
   END -- IF ISNULL(@cTrackingNumber,'') <> ''  
  
   -- Get WSConfig.ini File Path from CODELKUP  
   SELECT @cIniFilePath = Long  
   FROM CODELKUP WITH (NOLOCK)  
   WHERE ListName = @cListName  
     AND Code = @cCode_FilePath  
  
   IF ISNULL(@cIniFilePath,'') = ''  
   BEGIN  
      SET @bSuccess = 0  
      SET @nErr = 75651  
      SET @cErrmsg = 'WSConfig.ini File Path is empty. (isp1155P_Agile_ShipmentToHold)'  
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
      SET @nErr = 75678  
      SET @cErrmsg = 'Agile Web Service Request URL is empty. (isp1155P_Agile_ShipmentToHold)'  
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
  
   SET @cPackage_Weight = '1'  
/* 
   SELECT @cPackage_Weight = ISNULL(SUM(SKU.STDGROSSWGT * PD.Qty),0)  
   FROM   PackDetail pd WITH (NOLOCK)  
   JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = pd.StorerKey AND SKU.Sku = pd.SKU  
   WHERE  pd.PickSlipNo = @cPickSlipNo  
   AND    pd.CartonNo = @nCartonNo  
   -- Agile UPS Do not allow to ship Carton with Weight less then 1 lbs  
   IF CAST(@cPackage_Weight AS REAL) < 1 OR  
      CAST(@cPackage_Weight AS REAL) > 180  
   BEGIN  
      SET @cPackage_Weight = '1'  
   END  
*/  
  
   SELECT  
      @cPLD_RefNo1 = oi.OrderInfo01,  
      @cPLD_RefNo2 = oi.OrderInfo02,  
      @cPLD_RefNo3 = oi.OrderInfo03,  
      @cPLD_RefNo4 = oi.OrderInfo04,  
      @cPLD_RefNo5 = oi.OrderInfo05  
   FROM OrderInfo oi (NOLOCK)  
   WHERE oi.OrderKey = @cOrderKey  
  
   SET @cPLD_RefNoValue1 = ''  
   SET @cPLD_RefNoValue2 = ''  
   SET @cPLD_RefNoValue3 = ''  
   SET @cPLD_RefNoValue4 = ''  
   SET @cPLD_RefNoValue5 = ''  
  
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
  
   SET @cPLD_RefNoValue5 =  
       CASE @cPLD_RefNo5  
          WHEN 'DEPT' THEN @cUserDefine03  
          WHEN 'PO'   THEN @cExternOrderKey  
          WHEN 'INV'  THEN @cBuyerPO  
          WHEN 'ST'   THEN @cConsigneeKey  
          WHEN 'UCC'  THEN @cLabelNo  
          ELSE ''  
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
  
   IF ISNULL(@cCarrier,'') = ''  
   BEGIN  
      SET @bSuccess = 0  
      SET @nErr = 75652  
      SET @cErrmsg = 'Carrier Code is empty. (isp1155P_Agile_ShipmentToHold)'  
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
      GOTO UpdateDB  
   END  
  
   IF ISNULL(@cServiceType,'') = ''  
   BEGIN  
      SET @bSuccess = 0  
      SET @nErr = 75653  
      SET @cErrmsg = 'Service Type is empty. (isp1155P_Agile_ShipmentToHold)'  
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
      GOTO UpdateDB  
   END  
  
   IF ISNULL(@cReceiver_Street,'') = ''  
   BEGIN  
      SET @bSuccess = 0  
      SET @nErr = 75654  
      SET @cErrmsg = 'Receive Street is empty. (isp1155P_Agile_ShipmentToHold)'  
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
      GOTO UpdateDB  
   END  
  
   IF ISNULL(@cReceiver_City,'') = ''  
   BEGIN  
      SET @bSuccess = 0  
      SET @nErr = 75655  
      SET @cErrmsg = 'Receive City is empty. (isp1155P_Agile_ShipmentToHold)'  
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
      GOTO UpdateDB  
   END  
  
   IF ISNULL(@cReceiver_Region,'') = ''  
   BEGIN  
      SET @bSuccess = 0  
      SET @nErr = 75656  
      SET @cErrmsg = 'Receive Region is empty. (isp1155P_Agile_ShipmentToHold)'  
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
      GOTO UpdateDB  
   END  
  
   IF ISNULL(@cReceiver_PostalCode,'') = ''  
   BEGIN  
      SET @bSuccess = 0  
      SET @nErr = 75657  
      SET @cErrmsg = 'Receive Postal Code is empty. (isp1155P_Agile_ShipmentToHold)'  
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
      GOTO UpdateDB  
   END  
  
   IF ISNULL(@cReceiver_Country,'') = ''  
   BEGIN  
      SET @bSuccess = 0  
      SET @nErr = 75658  
      SET @cErrmsg = 'Receive Country is empty. (isp1155P_Agile_ShipmentToHold)'  
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
      GOTO UpdateDB  
   END  
  
   IF ISNULL(@cPackage_ReceiverName,'') = ''  
   BEGIN  
      SET @bSuccess = 0  
      SET @nErr = 75659  
      SET @cErrmsg = 'Package Receiver Name is empty. (isp1155P_Agile_ShipmentToHold)'  
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
      GOTO UpdateDB  
   END  
  
   IF ISNULL(@cPackage_ReceiverPhone,'') = ''  
   BEGIN  
      SET @bSuccess = 0  
      SET @nErr = 75660  
      SET @cErrmsg = 'Package Receive Phone is empty. (isp1155P_Agile_ShipmentToHold)'  
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
      GOTO UpdateDB  
   END  
  
   IF ISNULL(@cPackage_PackageType,'') = ''  
   BEGIN  
      SET @bSuccess = 0  
      SET @nErr = 75661  
      SET @cErrmsg = 'Package Type is empty. (isp1155P_Agile_ShipmentToHold)'  
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
      GOTO UpdateDB  
   END  
  
   IF CAST(ISNULL(@cPackage_Weight,'0') AS REAL) = ''  
   BEGIN  
      SET @bSuccess = 0  
      SET @nErr = 75662  
      SET @cErrmsg = 'Package Weight is empty. (isp1155P_Agile_ShipmentToHold)'  
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
      GOTO UpdateDB  
   END

   -- Get Credentials/ShippingKey for Orders.SpecialHandling = 'X' (Chee05)
   IF @cCarrier = '17'
   BEGIN
      IF ISNULL(@cAccountID, '') = ''  
      BEGIN  
         SET @bSuccess = 0  
         SET @nErr = 75681  
         SET @cErrmsg = 'Account Number is empty. (isp1155P_Agile_ShipmentToHold)'  
                    + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
         GOTO UpdateDB  
      END  

      SELECT @cShippingKey = RTRIM(UDF03)
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = @cListName_CarrierAcc
        AND Code = @cAccountID

      IF ISNULL(@cShippingKey,'') = ''  
      BEGIN  
         SET @bSuccess = 0  
         SET @nErr = 75682  
         SET @cErrmsg = 'Shipping Key is empty. (isp1155P_Agile_ShipmentToHold)'  
                    + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
         GOTO UpdateDB  
      END  
   END
  
   -- Create XML Request String  
   SET @xRequestString =  
   (  
      SELECT  
         @cLabelNo          "TransactionIdentifier",  
         @cShipToHold       "ShipToHold",  
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
            FOR XML PATH('Sender'), TYPE -- PierbridgeShipRequest/Sender  
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
            FOR XML PATH('Receiver'), TYPE -- PierbridgeShipRequest/Receiver  
         ),  
         (  
            SELECT  
               @cBilling_PayerType     "PayerType",  
               @cBilling_AccountNumber "AccountNumber",  
               @cBilling_CompanyName   "CompanyName",  
               @cBilling_Street        "Street",  
               @cBilling_Locale        "Locale",  
               @cBilling_Other         "Other",  
               @cBilling_City          "City",  
               @cBilling_Region        "Region",  
               @cBilling_PostalCode    "PostalCode",  
               @cBilling_Country       "Country"      -- Chee02  
            FOR XML PATH('Billing'), TYPE -- PierbridgeShipRequest/Billing  
         ),  
         (  
            SELECT  
               (  
                  SELECT  
                     @cPLD_RefNoValue1         "ReferenceOne",  
                     @cPLD_RefNoValue2         "ReferenceTwo",  
                     @cPLD_RefNoValue3         "ReferenceThree",  
                     @cPLD_RefNoValue4         "ReferenceFour",  
                     @cPLD_RefNoValue5         "ReferenceFive",  
                     @cPackage_ReceiverName    "ReceiverName",  
                     @cPackage_ReceiverPhone   "ReceiverPhone",  
                     @cPackage_PackageType     "PackageType",  
                     @cPackage_Weight          "Weight",  
                     @cPackage_DeliveryConfirm "DeliveryConfirmation",  
                     (  
                        SELECT  
                           @cPackage_Insurance_Type  "Type",  
                           @cPackage_Insurance_Value "Value"  
                        FOR XML PATH('Insurance'), TYPE -- PierbridgeShipRequest/Packages/Package/Insurance  
                     )  
                  FOR XML PATH ('Package'), TYPE -- PierbridgeShipRequest/Packages/Package  
               )  
            FOR XML PATH('Packages'), TYPE -- PierbridgeShipRequest/Packages  
         ),
         (
            -- PierbridgeShipRequest/Credentials only required if Orders.SpecialHandling = 'X' (Chee05)
            SELECT CASE @cCarrier WHEN '17' THEN
            (
               SELECT  
                  @cAccountID      "AccountNumber",  
                  @cShippingKey    "ShippingKey"  
               FOR XML PATH('Credentials'), TYPE -- PierbridgeShipRequest/Credentials
            ) ELSE NULL END
         ),
         @cAccountID "UserName"  
      FOR XML PATH(''),  
      ROOT('PierbridgeShipRequest')  
   )  
  
   -- Create Request String  
   SET @cRequestString = @cXMLEncodingString + CAST(@xRequestString AS NVARCHAR(MAX))  
  
   IF @nDebug = 1  
   BEGIN  
      SELECT @xRequestString AS 'XML Request String'  
      SELECT @cRequestString AS 'Request String'  
   END  
  
   -- Get BatchNo in [CNDTSITFSKE].[dbo].[WebService_Log]  
   EXECUTE [CNDTSITFSKE].[dbo].[nspg_getkey]  
   'WSDT_BatchNo'  
   , 10  
   , @cBatchNo OUTPUT  
   , @bSuccess OUTPUT  
   , @nErr     OUTPUT  
   , @cErrMsg  OUTPUT  
  
   IF @bSuccess = 0  
   BEGIN  
      SET @nErr = 75663  
      SET @cErrmsg = 'Failed to obtain BatchNo. (isp1155P_Agile_ShipmentToHold)'  
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
      GOTO Quit  
   END  
  
   IF @nDebug = 1  
   BEGIN  
      SELECT  
         @cBatchNo AS 'BatchNo',  
         @cDataStream AS 'DataStream'  
   END  
  
   -- Insert Request String into [CNDTSITFSKE].[dbo].[WebService_Log]  
   INSERT INTO [CNDTSITFSKE].[dbo].[WebService_Log](  
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
      'isp1155P_Agile_ShipmentToHold'  
   )  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @bSuccess = 0  
      SET @nErr = 75664  
      SET @cErrmsg = 'Error inserting into [CNDTSITFSKE].[dbo].[WebService_Log] Table. (isp1155P_Agile_ShipmentToHold)'  
                   + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
      GOTO Quit  
   END  
  
   -- Get SeqNo  
   SELECT @nSeqNo = SeqNo  
   FROM @StoreSeqNoTempTable  
  
   -- Chee03  
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
      SET @nErr = 75679  
      SET @cErrmsg = 'nspGetRight WebServiceClientContingency Failed. (isp1155P_Agile_ShipmentToHold)'  
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
		--(KT01) - Start
      -- Send RequestString and Receive ResponseString  
      --EXEC [master].[dbo].[isp_GenericWebServiceClient]  
      --   @cIniFilePath,  
      --   @cWebRequestURL,  
      --   @cWebRequestMethod,  
      --   @cContentType,  
      --   @cWebRequestEncoding,  
      --   @cRequestString,  
      --   @cResponseString   OUTPUT,  
      --   @cVBErrMsg         OUTPUT  
  
		EXEC [master].[dbo].[isp_GenericWebServiceClient] @cIniFilePath
																		, @cWebRequestURL
																		, @cWebRequestMethod --@c_WebRequestMethod
																		, @cContentType --@c_ContentType
																		, @cWebRequestEncoding --@c_WebRequestEncoding
																		, @cRequestString --@c_FullRequestString
																		, @cResponseString OUTPUT
																		, @cVBErrMsg OUTPUT																 
																		, 10000 --@n_WebRequestTimeout -- Miliseconds
																		, '' --@c_NetworkCredentialUserName -- leave blank if no network credential
																		, '' --@c_NetworkCredentialPassword -- leave blank if no network credential
																		, 0 --@b_IsSoapRequest  -- 1 = Add SoapAction in HTTPRequestHeader
																		, '' --@c_RequestHeaderSoapAction -- HTTPRequestHeader SoapAction value
																		, '' --@c_HeaderAuthorization
																		, '0' --@c_ProxyByPass, 1 >> Set Ip & Port, 0 >> Set Nothing
		--(KT01) - End

      IF @@ERROR <> 0 OR ISNULL(@cVBErrMsg,'') <> ''  
      BEGIN  
         SET @cStatus = '5'  
         SET @bSuccess = 0  
        SET @nErr = 75665  
  
         -- SET @cErrmsg  
         IF ISNULL(@cVBErrMsg,'') <> ''  
         BEGIN  
            SET @cErrmsg = CAST(@cVBErrMsg AS NVARCHAR(250))  
         END  
         ELSE  
         BEGIN  
            SET @cErrmsg = 'Error executing [master].[dbo].[isp_GenericWebServiceClient]. (isp1155P_Agile_ShipmentToHold)'  
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
         SET @nErr = 75680  
  
         -- SET @cErrmsg  
         IF ISNULL(@cVBErrMsg,'') <> ''  
         BEGIN  
            SET @cErrmsg = CAST(@cVBErrMsg AS NVARCHAR(250))  
         END  
         ELSE  
         BEGIN  
            SET @cErrmsg = 'Error executing [master].[dbo].[isp_GenericWebServiceClient_Contingency]. (isp1155P_Agile_ShipmentToHold)'  
                          + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
         END  
      END  
   END -- IF @cWSClientContingency <> '1'  
  
   SET @dTimeOut = GETDATE()  
   SET @nTotalTime = DATEDIFF(ms, @dTimeIn, @dTimeOut)  
  
   UPDATE [CNDTSITFSKE].[dbo].[WebService_Log] WITH (ROWLOCK)  
   SET Status = @cStatus, ErrMsg = @cErrmsg, TimeIn = @dTimeIn --, [Try] = [Try] + 1  
   WHERE SeqNo = @nSeqNo  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @bSuccess = 0  
      SET @nErr = 75666  
      SET @cErrmsg = 'Error updating [CNDTSITFSKE].[dbo].[WebService_Log] Table. (isp1155P_Agile_ShipmentToHold)'  
                    + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
     GOTO Quit  
   END  
  
   -- UpdateDB for [master].[dbo].[isp_GenericWebServiceClient] error  
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
  
   -- Insert Response String into [CNDTSITFSKE].[dbo].[WebService_Log]  
   INSERT INTO [CNDTSITFSKE].[dbo].[WebService_Log](  
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
      'isp1155P_Agile_ShipmentToHold'  
   )  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @bSuccess = 0  
      SET @nErr = 75667  
      SET @cErrmsg = 'Error inserting into [CNDTSITFSKE].[dbo].[WebService_Log] Table. (isp1155P_Agile_ShipmentToHold)'  
                 + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
      GOTO Quit  
   END  
  
   -- Extract ResponseString Data  
   EXEC sp_xml_preparedocument @ndoc OUTPUT, @xReponseString  
  
   -- SELECT statement that uses the OPENXML rowset provider.  
   SELECT  
      @cTransactionIdentifier             =   TransactionIdentifier,  
      @nStatus_Code                       =   Status_Code,  
      @cStatus_Desc                       =   Status_Desc,  
      @cTrackingNumber                    =   WayBillNumber,                      -- PackDetail.UPC  
    --@cPackageID                         =   PackageID,  (Chee04)
      @cPackageID                         =   ShipmentID, 
      @cUPS_ServiceName                   =   UPS_ServiceName,                    -- Orders.C_Fax2  
      @cUPS_ServiceIcon                   =   UPS_ServiceIcon,                    -- Orders.C_Fax1  
      @cUPS_Maxicode                      =   UPS_Maxicode,                       -- Orders.B_Contact2  
      @cUPS_RoutingCode                   =   UPS_RoutingCode,  
      @cUPS_URCVersion                    =   UPS_URCVersion,  
      @cFEG_96Barcode                     =   FEG_96Barcode,                      -- CartonShipmentDetail.GroundBarcodeString  
      @cFEE_UrsaCode                      =   FEE_UrsaCode,                       -- CartonShipmentDetail.RoutingCode  
      @cFEE_FormCode                      =   FEE_FormCode,                       -- CartonShipmentDetail.FormCode  
      @cFEE_AstraBarCode                  =   FEE_AstraBarCode,                   -- CartonShipmentDetail.ASTRA_Barcode  
      @cFEE_PlannedServiceLevel           =   FEE_PlannedServiceLevel,            -- CartonShipmentDetail.PlannedServiceLevel  
      @cFEE_ProductName                   =   FEE_ProductName,                    -- CartonShipmentDetail.ServiceTypeDescription  
      @cFEE_SpecialHandlingAcronyms       =   FEE_SpecialHandlingAcronyms,        -- CartonShipmentDetail.SpecialHandlingIndicators  
      @cFEE_DestinationAirportIdentifier  =   FEE_DestinationAirportIdentifier    -- CartonShipmentDetail.DestinationAirportID  
   FROM OPENXML (@ndoc, '/PierbridgeShipResponse/Packages/Package', 2)  
   WITH(  
      TransactionIdentifier            NVARCHAR(20)   '../../TransactionIdentifier',  
      Status_Code                      INT           'Status/Code',  
      Status_Desc                      NVARCHAR(215)  'Status/Description',  
      WayBillNumber                    NVARCHAR(30),  
    --PackageID                        NVARCHAR(30), (Chee04)
      ShipmentID                       NVARCHAR(30)   '../../ShipmentID',
      UPS_ServiceName                  NVARCHAR(18),  
      UPS_ServiceIcon                  NVARCHAR(18),  
      UPS_Maxicode                     NVARCHAR(30),  
      UPS_RoutingCode                  NVARCHAR(20),  
      UPS_URCVersion                   NVARCHAR(30),  
      FEG_96Barcode                    NVARCHAR(30),  
      FEE_UrsaCode                     NVARCHAR(10),  
      FEE_FormCode                     NVARCHAR(10),  
      FEE_AstraBarCode                 NVARCHAR(45),  
      FEE_PlannedServiceLevel          NVARCHAR(30),  
      FEE_ProductName                  NVARCHAR(45),  
      FEE_SpecialHandlingAcronyms      NVARCHAR(30),  
      FEE_DestinationAirportIdentifier NVARCHAR(5)  
   )  
  
   EXEC sp_xml_removedocument @ndoc  
  
   IF @nDebug = 1  
   BEGIN  
   SELECT  
      @cTransactionIdentifier AS 'TransactionIdentifier',  
      @nStatus_Code AS 'Status_Code',  
      @cStatus_Desc AS 'Status_Desc',  
      @cTrackingNumber AS 'TrackingNumber',  
      @cPackageID AS 'PackageID',  
      @cUPS_ServiceName AS 'UPS_ServiceName',  
      @cUPS_ServiceIcon AS 'UPS_ServiceIcon',  
      @cUPS_Maxicode AS 'UPS_Maxicode',  
      @cUPS_RoutingCode AS 'UPS_RoutingCode',  
      @cUPS_URCVersion AS 'UPS_URCVersion',  
      @cFEG_96Barcode AS 'FEG_96Barcode',  
      @cFEE_UrsaCode AS 'FEE_UrsaCode',  
      @cFEE_FormCode AS 'FEE_FormCode',  
      @cFEE_AstraBarCode AS 'FEE_AstraBarCode',  
      @cFEE_PlannedServiceLevel AS 'FEE_PlannedServiceLevel',  
      @cFEE_ProductName AS 'FEE_ProductName',  
      @cFEE_SpecialHandlingAcronyms AS 'FEE_SpecialHandlingAcronyms',  
      @cFEE_DestinationAirportIdentifier AS 'FEE_DestinationAirportIdentifier'  
   END  
  
   -- Response Failed  
   IF @nStatus_Code = 0  
   BEGIN  
      SET @bSuccess = 0  
      SET @nErr = 75669  
      SET @cErrmsg = @cStatus_Desc + ' (isp1155P_Agile_ShipmentToHold)'  
                    + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
      GOTO UpdateDB  
   END  
   -- Response Success  
   ELSE IF @nStatus_Code = 1  
   BEGIN  
  
      IF @nDebug = 1  
      BEGIN  
         SELECT @cStatus_Desc AS 'Response Status Description'  
      END  
  
      IF @cTransactionIdentifier <> @cLabelNo  
      BEGIN  
         SET @bSuccess = 0  
         SET @nErr = 75668  
         SET @cErrmsg = 'Incorrect Transaction Identifier returned. (isp1155P_Agile_ShipmentToHold)'  
                      + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
         GOTO UpdateDB  
      END  
  
      IF ISNULL(@cTrackingNumber,'') = ''  
      BEGIN  
         SET @bSuccess = 0  
         SET @nErr = 75670  
         SET @cErrmsg = 'Tracking Number is empty. (isp1155P_Agile_ShipmentToHold)'  
                       + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
         GOTO UpdateDB  
      END  
  
   END -- IF @nStatus_Code = 1  
   ELSE  
   BEGIN  
      SET @bSuccess = 0  
      SET @nErr = 75674  
      SET @cErrmsg = 'Invalid Status Code. (isp1155P_Agile_ShipmentToHold)'  
                   + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
      GOTO UpdateDB  
   END -- IF @nStatus_Code = 0  
  
UpdateDB:  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
  
   --(ung02)  
   IF @cCartonType = 'MASTER'  
   BEGIN  
      DECLARE @cRefNo NVARCHAR(20)  
      SET @cRefNo = ''  
      SELECT @cRefNo = RefNo  
      FROM PackDetail WITH (ROWLOCK)  
      WHERE PickSlipNo = @cPickSlipNo  
        AND CartonNo   = @nCartonNo  
        AND LabelNo    = @cLabelNo  
  
      IF @cRefNo <> ''  
         UPDATE PackDetail WITH (ROWLOCK) SET  
            UPC = @cTrackingNumber  
         WHERE StorerKey = @cStorerKey  
           AND RefNo = @cRefNo  
   END  
   ELSE  
      UPDATE PackDetail WITH (ROWLOCK)  
      SET UPC = @cTrackingNumber  
      WHERE PickSlipNo = @cPickSlipNo  
        AND CartonNo   = @nCartonNo  
        AND LabelNo    = @cLabelNo  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @bSuccess = 0  
      SET @nErr = 75671  
      SET @cErrmsg = 'Error updating [dbo].[PackDetail] Table. (isp1155P_Agile_ShipmentToHold)'  
                + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
      GOTO RollbackTran  
   END  
  
   --INSERT INTO TraceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5, Col1, Col2) -- SOS# 264909  
   --SELECT 'isp1155P_Agile_ShipmentToHold', GetDate()  
   --       , OrderKey, @cUPS_ServiceName, @cUPS_ServiceIcon  
   --       , SUBSTRING(@cUPS_Maxicode, 1, 3)  
   --       , @cPickSlipNo, @nCartonNo, @cLabelNo  
   --FROM @tOrders  
  
   UPDATE Orders WITH (ROWLOCK)  
   SET C_Fax2 = @cUPS_ServiceName,  
       C_Fax1 = @cUPS_ServiceIcon,  
       B_Contact2 = SUBSTRING(@cUPS_Maxicode, 1, 3),   -- (james02)  
       TrafficCop = NULL  
   FROM ORDERS  
   JOIN @tOrders T ON T.OrderKey = ORDERS.OrderKey  
 --WHERE OrderKey = @cOrderKey  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @bSuccess = 0  
      SET @nErr = 75672  
      SET @cErrmsg = 'Error updating [dbo].[Orders] Table. (isp1155P_Agile_ShipmentToHold)'  
             + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
      GOTO RollbackTran  
   END  
  
   IF EXISTS (SELECT 1 FROM CartonShipmentDetail WITH (NOLOCK)  
              WHERE UCCLabelNo = @cLabelNo)  
   BEGIN  
      -- Insert/Update into Table  
      UPDATE CartonShipmentDetail WITH (ROWLOCK)  
      SET    FormCode                  = @cFEE_FormCode,  
             TrackingNumber            = @cTrackingNumber,  
             GroundBarcodeString       = @cFEG_96Barcode,  
             RoutingCode               = @cFEE_UrsaCode,  
             ASTRA_Barcode             = @cFEE_AstraBarCode,  
             PlannedServiceLevel       = @cFEE_PlannedServiceLevel,  
             ServiceTypeDescription    = @cFEE_ProductName,  
             SpecialHandlingIndicators = @cFEE_SpecialHandlingAcronyms,  
             DestinationAirportID      = @cFEE_DestinationAirportIdentifier,  
             PackageID                 = @cPackageID,  
             UPS_RoutingCode           = @cUPS_RoutingCode,  
             UPS_URCVersion            = @cUPS_URCVersion  
       WHERE  UCCLabelNo = @cLabelNo  
  
       IF @@ERROR <> 0  
       BEGIN  
          SET @bSuccess = 0  
          SET @nErr = 75675  
          SET @cErrmsg = 'Error updating [dbo].[CartonShipmentDetail] Table. (isp1155P_Agile_ShipmentToHold)'  
                       + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
          GOTO RollbackTran  
       END  
   END  
   ELSE  
   BEGIN  
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
         FormCode,  
         TrackingNumber,  
         GroundBarcodeString,  
         RoutingCode,  
         ASTRA_Barcode,  
         PlannedServiceLevel,  
         ServiceTypeDescription,  
         SpecialHandlingIndicators,  
         DestinationAirportID,  
         PackageID,  
         UPS_RoutingCode,  
         UPS_URCVersion  
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
         @cFEE_FormCode,  
         @cTrackingNumber,  
         @cFEG_96Barcode,  
         @cFEE_UrsaCode,  
         @cFEE_AstraBarCode,  
         @cFEE_PlannedServiceLevel,  
         @cFEE_ProductName,  
         @cFEE_SpecialHandlingAcronyms,  
         @cFEE_DestinationAirportIdentifier,  
         @cPackageID,  
         @cUPS_RoutingCode,  
         @cUPS_URCVersion  
      )  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @bSuccess = 0  
         SET @nErr = 75673  
         SET @cErrmsg = 'Error inserting into [dbo].[CartonShipmentDetail] Table. (isp1155P_Agile_ShipmentToHold)'  
                      + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
         GOTO RollbackTran  
      END  
   END -- IF EXISTS (SELECT 1 FROM CartonShipmentDetail WITH (NOLOCK) WHERE UCCLabelNo = @cLabelNo)  
  
   COMMIT TRAN  
   GOTO Quit  
  
RollbackTran:  
   ROLLBACK TRAN  
  
Quit:  
   WHILE @nTrancount > @@TRANCOUNT  
      COMMIT TRAN  
  
   -- Send Email Alert  
   IF NOT @bSuccess = 1  
   BEGIN  
      -- Get InterfaceLogID using [CNDTSITFSKE].[dbo].[WebService_Log]  
      EXECUTE [CNDTSITFSKE].[dbo].[nspg_getkey]  
       'InterfaceLogID'  
      , 10  
      , @nLogAttachmentID OUTPUT  
      , @bSuccess         OUTPUT  
      , @nErr  
      , @cErrmsg  
  
      IF NOT @bSuccess = 1  
      BEGIN  
         SET @bSuccess = 0  
         SET @nErr = 75676  
     SET @cErrmsg = 'Failed to obtain InterfaceLogID. (isp1155P_Agile_ShipmentToHold)'  
                    + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
         GOTO Outlog  
      END  
  
      -- Get File Key using [DCNDTSITF].[dbo].[WebService_Log]  
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
         SET @nErr = 75677  
         SET @cErrmsg = 'Failed to obtain FileKey. (isp1155P_Agile_ShipmentToHold)'  
                    + ' ( SQLSvr MESSAGE=' + CONVERT(CHAR(5),ISNULL(@nErr,0)) + ' )'  
         GOTO Outlog  
      END  
  
Outlog:  
      SET @cLineText = 'AGILE Web Service ShipToHold Failed. Error: ' + RTRIM(@cErrmsg)  
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
         INSERT INTO [CNDTSITFSKE].[dbo].[Out_log] (File_key, DataStream, [FileName], AttachmentID, LineText)  
         VALUES (@nLogFilekey, @cDataStream, @cFileName, @nLogAttachmentID, @cLineText)  
      END  
      SET @bSuccess = 0  
   END  
  
   /***********************************************/  
   /* Std - Send Email Alert (Start)              */  
   /***********************************************/  
  
   IF EXISTS (SELECT 1 FROM [CNDTSITFSKE].[dbo].[Out_log]  
           WHERE File_key = @nLogFilekey  
              AND DataStream = @cDataStream)  
   BEGIN  
      EXEC [CNDTSITFSKE].[dbo].[ispEmailAlert] @nLogAttachmentID, @cDataStream, 'I',  
                          'Error Log File for US AGILE ShipToHold' ,  
                          'Please refer to the attached file..',  
                  @bSuccess  OUTPUT  
   END  
   /***********************************************/  
   /* Std - Send Email Alert (End)                */  
   /***********************************************/  
  
END -- Procedure

GO