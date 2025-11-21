SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_ScanToTruck_ByLabelNo_GetStat                   */
/* Purpose: Get statistic                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2013-05-14 1.0  Ung        SOS278061. Created                        */
/* 2014-04-14 1.1  ChewKP     SOS#308292 - Add ConsoOrder for Type = 'M'*/
/*                            (ChewKP01)                                */
/* 2018-04-12 1.2  Ung        WMS-4476 Add GetStatSP                    */
/* 2020-11-24 3.2  James      WMS-15718 - Add Refno (james04)           */
/************************************************************************/

CREATE PROC [RDT].[rdt_ScanToTruck_ByLabelNo_GetStat] (
   @nMobile      INT,
   @nFunc        INT, 
   @cLangCode    NVARCHAR( 3), 
   @cStorerKey   NVARCHAR( 15), 
   @cType        NVARCHAR( 1),
   @cMBOLKey     NVARCHAR( 10),
   @cLoadKey     NVARCHAR( 10),
   @cOrderKey    NVARCHAR( 10), 
   @cDoor        NVARCHAR( 10), 
   @cRefNo       NVARCHAR( 40), 
   @cCheckPackDetailDropID INT, 
   @cCheckPickDetailDropID INT, 
   @nTotalCarton INT OUTPUT, 
   @nScanCarton  INT OUTPUT, 
   @nErrNo       INT           OUTPUT, 
   @cErrMsg      NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @cSQL           NVARCHAR(MAX)
DECLARE @cSQLParam      NVARCHAR(MAX)
DECLARE @cGetStatSP     NVARCHAR(20)

-- Get storer configure
SET @cGetStatSP = rdt.RDTGetConfig( @nFunc, 'GetStatSP', @cStorerKey)
IF @cGetStatSP = '0'
   SET @cGetStatSP = ''

/***********************************************************************************************
                                           Custom GetStat
***********************************************************************************************/
-- Custom logic
IF @cGetStatSP <> ''
BEGIN
   IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cGetStatSP AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cGetStatSP) +
         ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cDoor, @cRefNo, @cCheckPackDetailDropID, @cCheckPickDetailDropID, ' +
         ' @nTotalCarton OUTPUT, @nScanCarton OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

      SET @cSQLParam =
         ' @nMobile        INT,           ' + 
         ' @nFunc          INT,           ' + 
         ' @cLangCode      NVARCHAR( 3),  ' + 
         ' @cStorerKey     NVARCHAR( 15), ' +   
         ' @cType          NVARCHAR( 10), ' +
         ' @cMBOLKey       NVARCHAR( 10), ' +   
         ' @cLoadKey       NVARCHAR( 10), ' + 
         ' @cOrderKey      NVARCHAR( 10), ' + 
         ' @cDoor          NVARCHAR( 10), ' + 
         ' @cRefNo         NVARCHAR( 40), ' + 
         ' @cCheckPackDetailDropID INT,   ' +
         ' @cCheckPickDetailDropID INT,   ' +
         ' @nTotalCarton   INT           OUTPUT, ' +
         ' @nScanCarton    INT           OUTPUT, ' +
         ' @nErrNo         INT           OUTPUT, ' + 
         ' @cErrMsg        NVARCHAR(20)  OUTPUT  '
         
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @cStorerKey, @cType, @cMBOLKey, @cLoadKey, @cOrderKey, @cDoor, @cRefNo, @cCheckPackDetailDropID, @cCheckPickDetailDropID,
         @nTotalCarton OUTPUT, @nScanCarton OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

      GOTO Quit
   END
END

/***********************************************************************************************
                                          Standard GetStat
***********************************************************************************************/
-- MBOL
IF @cType = 'M' OR
   @cType = 'R'   -- REFNO
BEGIN
   -- PickDetail
   IF @cCheckPickDetailDropID = '1'
   BEGIN
      SELECT @nTotalCarton = COUNT( DISTINCT PD.DropID)  
      FROM dbo.MBOLDetail MD WITH (NOLOCK)  
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (MD.OrderKey = PD.OrderKey)
      WHERE MD.MbolKey = @cMBOLKey        
   END
   ELSE 
   BEGIN
      -- PackDetail
      IF @cCheckPackDetailDropID = '1'
         SELECT @nTotalCarton = COUNT( DISTINCT PD.DropID)  
         FROM dbo.MBOLDetail MD WITH (NOLOCK)  
            JOIN dbo.PackHeader PH WITH (NOLOCK) ON (MD.OrderKey = PH.OrderKey)
            JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
         WHERE MD.MbolKey = @cMBOLKey 
      ELSE
         
         SELECT @nTotalCarton = COUNT( DISTINCT PD.LabelNo)
         FROM dbo.MBOLDetail MD WITH (NOLOCK)
            JOIN dbo.PackHeader PH WITH (NOLOCK) ON (MD.OrderKey = PH.OrderKey)
            JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
         WHERE MD.MbolKey = @cMBOLKey   
         
         -- If Not Discrete Pickslip , Check by ExternOrderKey (ChewKP01)
         IF @nTotalCarton = 0 
         BEGIN
      
            SELECT @nTotalCarton = COUNT( DISTINCT PD.CaseID)
            FROM dbo.MBOLDetail MD WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = MD.OrderKey
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
               --JOIN dbo.PackHeader PH WITH (NOLOCK) ON (O.LoadKey = PH.LoadKey)
               --JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
            WHERE MD.MbolKey = @cMBOLKey  

 


         END
   END
   SELECT @nScanCarton = COUNT( 1) FROM rdt.rdtScanToTruck WITH (NOLOCK) WHERE MbolKey = @cMBOLKey 
END

-- Load
IF @cType = 'L'
BEGIN
   -- PickDetail
   IF @cCheckPickDetailDropID = '1'
   BEGIN
      SELECT @nTotalCarton = COUNT( DISTINCT PD.DropID)  
      FROM dbo.OrderDetail OD WITH (NOLOCK)  
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey)
      WHERE OD.LoadKey = @cLoadKey        
   END
   ELSE 
   BEGIN
      -- PackDetail
      IF @cCheckPackDetailDropID = '1'
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.PackHeader PH WITH (NOLOCK) WHERE PH.LoadKey = @cLoadKey) 
            SELECT @nTotalCarton = COUNT( DISTINCT PD.DropID)  
            FROM dbo.PackHeader PH WITH (NOLOCK)
               JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
            WHERE PH.LoadKey = @cLoadKey
         ELSE
            SELECT @nTotalCarton = COUNT( DISTINCT PD.DropID)  
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
               JOIN dbo.PackHeader PH WITH (NOLOCK) ON (LPD.OrderKey = PH.OrderKey)
               JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
            WHERE LPD.LoadKey = @cLoadKey
      END
      ELSE
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.PackHeader PH WITH (NOLOCK) WHERE PH.LoadKey = @cLoadKey) 
            SELECT @nTotalCarton = COUNT( DISTINCT PD.LabelNo)  
            FROM dbo.PackHeader PH WITH (NOLOCK)
               JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
            WHERE PH.LoadKey = @cLoadKey
         ELSE
            SELECT @nTotalCarton = COUNT( DISTINCT PD.LabelNo)  
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
               JOIN dbo.PackHeader PH WITH (NOLOCK) ON (LPD.OrderKey = PH.OrderKey)
               JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
            WHERE LPD.LoadKey = @cLoadKey
      END
   END
   SELECT @nScanCarton = COUNT( 1) FROM rdt.rdtScanToTruck WITH (NOLOCK) WHERE LoadKey = @cLoadKey 
END

-- Order
IF @cType = 'O'
BEGIN
   -- PickDetail
   IF @cCheckPickDetailDropID = '1'
   BEGIN
      SELECT @nTotalCarton = COUNT( DISTINCT PD.DropID)  
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.OrderKey = @cOrderKey        
   END
   ELSE 
   BEGIN
      -- PackDetail
      IF @cCheckPackDetailDropID = '1'
         SELECT @nTotalCarton = COUNT( DISTINCT PD.DropID)  
         FROM dbo.PackHeader PH WITH (NOLOCK)
            JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
         WHERE PH.OrderKey = @cOrderKey 
      ELSE
         SELECT @nTotalCarton = COUNT( DISTINCT PD.LabelNo)
         FROM dbo.PackHeader PH WITH (NOLOCK)
            JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
         WHERE PH.OrderKey = @cOrderKey 
   END
   SELECT @nScanCarton = COUNT( 1) FROM rdt.rdtScanToTruck WITH (NOLOCK) WHERE OrderKey = @cOrderKey 
END


Quit:
Fail:

GO