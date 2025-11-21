SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_StageLabel                                      */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Print GS1 label                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2012-03-13 1.0  Ung      SOS238302 Add generate label file           */
/* 2012-06-04 1.1  Ung      SOS244733 Expand DropID to 20 chars         */
/* 2012-06-14 1.2  Ung      SOS247522 Support pallet not yet in MBOL    */
/************************************************************************/

CREATE PROC [RDT].[rdt_StageLabel] (
   @nMobile    INT,
   @cLangCode  NVARCHAR( 3),
   @cUserName  NVARCHAR( 18), 
   @cPrinter   NVARCHAR(10),
   @cStorerKey NVARCHAR( 15), 
   @cFacility  NVARCHAR( 5),
   @cDropID    NVARCHAR( 20), 
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @b_success         INT
DECLARE @cTemplateFile     NVARCHAR( 120)
DECLARE @cGS1TemplatePath  NVARCHAR(120)
DECLARE @cCRLF             NVARCHAR( 2)
DECLARE @cB_ISOCntryCode   NVARCHAR( 10)
DECLARE @nChildIDCount     INT
DECLARE @cOrderKey         NVARCHAR( 10)
DECLARE @cLoadKey          NVARCHAR( 10)
DECLARE @cConsoOrderKey    NVARCHAR( 30)
DECLARE @dOrderDate        DATETIME
DECLARE @dDeliveryDate     DATETIME
DECLARE @cC_Company        NVARCHAR( 45)
DECLARE @nC_CompanyCount   INT
DECLARE @cConsigneeKey     NVARCHAR( 15)
DECLARE @cCarrierKey       NVARCHAR( 10)
DECLARE @cExternOrderKey   NVARCHAR( 30)
DECLARE @nExternOrderKeyCount INT
DECLARE @dUserDefine07     DATETIME
DECLARE @cLOC              NVARCHAR( 10)
DECLARE @cBookingReference NVARCHAR( 30)

SET @cCRLF = master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10)

-- Get GS1 template file
SET @cGS1TemplatePath = ''
SELECT @cGS1TemplatePath = NSQLDescrip FROM RDT.NSQLCONFIG WITH (NOLOCK) WHERE ConfigKey = 'GS1TemplatePath'
IF RIGHT( @cGS1TemplatePath, 1) <> '\' SET @cGS1TemplatePath = @cGS1TemplatePath + '\'
SET @cTemplateFile = @cGS1TemplatePath + 'PLTStagingLabel.btw'

-- PackHeader info
SELECT TOP 1
   @cOrderKey = ISNULL( OrderKey, ''), 
   @cLoadKey = ISNULL( LoadKey, ''), 
   @cConsoOrderKey = ISNULL( ConsoOrderKey, '')
FROM DropIDDetail DID WITH (NOLOCK) 
   INNER JOIN PackDetail PD WITH (NOLOCK) ON (DID.ChildID = PD.LabelNo)
   INNER JOIN PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
WHERE DID.DropID = @cDropID

-- Get order info
IF @cOrderKey <> ''
   SELECT
      @cOrderKey = MAX( O.OrderKey), -- Just to by pass SQL aggregrate checking
      @nC_CompanyCount = COUNT( DISTINCT O.C_Company), 
      @nExternOrderKeyCount = COUNT( DISTINCT O.ExternOrderKey), 
      @dOrderDate = MIN( O.OrderDate), 
      @dDeliveryDate = MAX( O.DeliveryDate)
   FROM DropIDDetail DID WITH (NOLOCK) 
      INNER JOIN PackDetail PD WITH (NOLOCK) ON (DID.ChildID = PD.LabelNo)
      INNER JOIN PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
      INNER JOIN Orders O WITH (NOLOCK) ON (PH.OrderKey = O.OrderKey)
   WHERE DID.DropID = @cDropID
ELSE 
   IF @cLoadKey <> ''
      SELECT
         @cOrderKey = MAX( O.OrderKey), -- Just to by pass SQL aggregrate checking
         @nC_CompanyCount = COUNT( DISTINCT O.C_Company), 
         @nExternOrderKeyCount = COUNT( DISTINCT O.ExternOrderKey), 
         @dOrderDate = MIN( O.OrderDate), 
         @dDeliveryDate = MAX( O.DeliveryDate)
      FROM DropIDDetail DID WITH (NOLOCK) 
         INNER JOIN PackDetail PD WITH (NOLOCK) ON (DID.ChildID = PD.LabelNo)
         INNER JOIN PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
         INNER JOIN Orders O WITH (NOLOCK) ON (PH.LoadKey = O.LoadKey)
      WHERE DID.DropID = @cDropID
   ELSE 
      IF @cConsoOrderKey <> ''
         SELECT
            @cOrderKey = MAX( O.OrderKey), -- Just to by pass SQL aggregrate checking
            @nC_CompanyCount = COUNT( DISTINCT O.C_Company), 
            @nExternOrderKeyCount = COUNT( DISTINCT O.ExternOrderKey), 
            @dOrderDate = MIN( O.OrderDate), 
            @dDeliveryDate = MAX( O.DeliveryDate)
         FROM DropIDDetail DID WITH (NOLOCK) 
            INNER JOIN PackDetail PD WITH (NOLOCK) ON (DID.ChildID = PD.LabelNo)
            INNER JOIN PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
            INNER JOIN OrderDetail OD WITH (NOLOCK) ON (PH.ConsoOrderKey = OD.ConsoOrderKey AND PH.ConsoOrderKey <> '')
            INNER JOIN Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
         WHERE DID.DropID = @cDropID

SELECT 
   @cLoadKey = O.LoadKey, 
   @cC_Company = O.C_Company,
   @cConsigneeKey = O.ConsigneeKey, 
   @cExternOrderKey = O.ExternOrderKey
FROM Orders O WITH (NOLOCK) 
WHERE O.OrderKey = @cOrderKey

IF EXISTS( SELECT 1 FROM dbo.MBOLDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey)
   SELECT 
      @cCarrierKey = M.CarrierKey, 
      @dUserDefine07 = M.UserDefine07, 
      @cBookingReference = M.BookingReference
   FROM MBOL M WITH (NOLOCK) 
      INNER JOIN MBOLDetail MD WITH (NOLOCK) ON (M.MBOLKey = MD.MBOLKey)
   WHERE MD.OrderKey = @cOrderKey
ELSE
   SELECT 
      @cCarrierKey = '', 
      @dUserDefine07 = 0, 
      @cBookingReference = ''

-- Stamp MULTI
IF @nC_CompanyCount > 1 SET @cC_Company = 'MULTI'
IF @nExternOrderKeyCount > 1 SET @cExternOrderKey = 'MULTI'

SELECT @cB_ISOCntryCode = B_ISOCntryCode FROM Storer WITH (NOLOCK) WHERE StorerKey = @cStorerKey 
SELECT @cLOC = LOC FROM LoadPlanLaneDetail WITH (NOLOCK) WHERE LoadKey = @cLoadKey 

SELECT @nChildIDCount = COUNT(1) 
FROM DropIDDetail WITH (NOLOCK) 
WHERE DropID = @cDropID


-- Output data string
DECLARE @cOutput NVARCHAR( MAX)
SET @cOutput = @cOutput + '%BTW% /AF="' + RTRIM( @cTemplateFile) + '" /PRN="' + RTRIM( @cPrinter) + '" /PrintJobName="' + RTRIM( @cDropID) + '" /R=3 /C=1 /P /D="%Trigger File Name%" ' + @cCRLF
SET @cOutput = @cOutput + '%END%' + @cCRLF
SET @cOutput = @cOutput + @cCRLF

SET @cOutput = @cOutput + '"' + RTRIM( @cStorerKey) + '",'                          --Storer.StorerKey
SET @cOutput = @cOutput + '"' + RTRIM( @cB_ISOCntryCode) + '",'                     --Storer.B_ISOCntryCode
SET @cOutput = @cOutput + '"' + RTRIM( @cLOC) + '",'                                --LoadPlanLaneDetail.LOC
SET @cOutput = @cOutput + '"' + RTRIM( @cLoadKey) + '",'                            --Orders.LoadKey
SET @cOutput = @cOutput + '"' + RTRIM( @cC_Company) + '",'                          --Orders.C_Company
SET @cOutput = @cOutput + '"' + RTRIM( @cConsigneeKey) + '",'                       --Orders.ConsigneeKey
SET @cOutput = @cOutput + '"' + CONVERT( NVARCHAR( 10), @dOrderDate, 101) + '",'     --MIN( Orders.OrderDate)    mm/dd/yyyy
SET @cOutput = @cOutput + '"' + CONVERT( NVARCHAR( 10), @dDeliveryDate, 101) + '",'  --MAX( Orders.DeliveryDate) mm/dd/yyyy
SET @cOutput = @cOutput + '"' + RTRIM( @cCarrierkey) + '",'                         --MBOL.Carrierkey
SET @cOutput = @cOutput + '"' + RTRIM( @cExternOrderKey) + '",'                     --Orders.ExternOrderKey
SET @cOutput = @cOutput + '"' + CASE WHEN @dUserDefine07 = 0 THEN '' ELSE
                                   CONVERT( NVARCHAR( 10), @dUserDefine07, 101) + ' ' + 
                                   CONVERT( NVARCHAR( 8),  @dUserDefine07, 8)
                                END + '",'                                          --MBOL.UserDefine07, mm/dd/yyyy hh:mm:ss
SET @cOutput = @cOutput + '"' + CONVERT( NVARCHAR( 10), GETDATE(), 101) + ' ' + 
                                CONVERT( NVARCHAR( 8),  GETDATE(), 8) + '",'         --GETDATE()
SET @cOutput = @cOutput + '"' + CAST( @nChildIDCount AS NVARCHAR( 5)) + '",'         --COUNT( DropIDDetail.ChildID)
SET @cOutput = @cOutput + '"' + RTRIM( @cDropID) + '",'                             --DropID.DropID
SET @cOutput = @cOutput + '"' + RTRIM( @cUserName) + '",'                           --RDT login name
SET @cOutput = @cOutput + '"' + RTRIM( @cBookingReference) + '"'                    --MBOL.BookingReference


-- Get destination path for the CSV file
DECLARE @cWorkFilePath NVARCHAR( 120)
DECLARE @cMoveFilePath NVARCHAR( 120)
SET @cWorkFilePath = ''
SET @cMoveFilePath = ''
SELECT @cMoveFilePath = ISNULL( UserDefine20, '') FROM dbo.Facility WITH (NOLOCK) WHERE Facility = @cFacility
IF RIGHT( @cMoveFilePath, 1) <> '\' SET @cMoveFilePath = @cMoveFilePath + '\'
SET @cWorkFilePath = @cMoveFilePath + 'Working\'

-- Get CSV file name
DECLARE @cFileName NVARCHAR( 215)
DECLARE @cDateTime NVARCHAR( 17) 
SELECT @cDateTime = CONVERT( NVARCHAR( 8), GETDATE(), 112) + REPLACE( CONVERT( NVARCHAR( 12), GETDATE(), 114), ':', '') -- yyyymmdd + hhmmssmmm
SET @cFilename = RTRIM( @cPrinter) + '_' + @cDateTime + '_' + RTRIM( @cDropID) + '.csv'

-- Write output to file
EXEC dbo.isp_WriteStringToFile
   @cOutput,
   @cWorkFilePath,
   @cFilename,
   2, -- IOMode 2 = ForWriting ,8 = ForAppending
   @b_success OUTPUT
IF @b_success <> 1
BEGIN
   SET @nErrNo = 66976
   SET @cErrMsg = rdt.rdtgetmessage( 66976, @cLangCode, 'DSP') --FileOpenFail
   GOTO Quit
END

-- Move the file
SET @cWorkFilePath = @cWorkFilePath + @cFileName
SET @cMoveFilePath = @cMoveFilePath + @cFileName

EXEC dbo.isp_MoveFile
   @cWorkFilePath OUTPUT,
   @cMoveFilePath OUTPUT,
   @b_success OUTPUT
IF @b_success <> 1
BEGIN
   SET @nErrNo = 66978
   SET @cErrMsg = rdt.rdtgetmessage( 66978, @cLangCode, 'DSP') --MoveFileFail
   GOTO Quit
END

Quit:

GO