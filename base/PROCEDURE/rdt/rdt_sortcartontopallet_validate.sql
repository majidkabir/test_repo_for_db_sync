SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_SortCartonToPallet_Validate                        */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Purpose: Save carton to pallet                                          */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date         Rev  Author   Purposes                                     */
/* 2023-07-18   1.0  Ung      WMS-22855 Created                            */
/* 2023-10-17   1.1  Ung      WMS-23818 Fix ValidateSP param               */
/*                            Reusable carton ID                           */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_SortCartonToPallet_Validate](
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cType         NVARCHAR( 20), -- CartonID/PalletID
   @cUpdateTable  NVARCHAR( 20),
   @cPalletID     NVARCHAR( 20),
   @cCartonID     NVARCHAR( 20) = '',
   @cSKU          NVARCHAR( 20) = '' OUTPUT,
   @nQTY          INT           = 0  OUTPUT, 
   @cCartonUDF01  NVARCHAR( 30) = '' OUTPUT, 
   @cCartonUDF02  NVARCHAR( 30) = '' OUTPUT, 
   @cCartonUDF03  NVARCHAR( 30) = '' OUTPUT, 
   @cCartonUDF04  NVARCHAR( 30) = '' OUTPUT , 
   @cCartonUDF05  NVARCHAR( 30) = '' OUTPUT , 
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL        NVARCHAR(MAX)
   DECLARE @cSQLParam   NVARCHAR(MAX)
   DECLARE @cValidateSP NVARCHAR(20) = ''

   SET @cValidateSP = rdt.rdtGetConfig( @nFunc, 'ValidateSP', @cStorerKey)
   IF @cValidateSP = '0'
      SET @cValidateSP = ''
      
   /***********************************************************************************************
                                              Custom logic
   ***********************************************************************************************/
   IF @cValidateSP <> '' 
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cValidateSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cValidateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cType, @cUpdateTable, @cPalletID, @cCartonID, @cSKU OUTPUT, @nQTY OUTPUT, ' +
            ' @cCartonUDF01 OUTPUT, @cCartonUDF02 OUTPUT, @cCartonUDF03 OUTPUT, @cCartonUDF04 OUTPUT, @cCartonUDF05 OUTPUT, ' + 
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            ' @nMobile        INT,           ' + 
            ' @nFunc          INT,           ' + 
            ' @cLangCode      NVARCHAR( 3),  ' + 
            ' @nStep          INT,           ' + 
            ' @nInputKey      INT,           ' + 
            ' @cFacility      NVARCHAR( 5),  ' + 
            ' @cStorerKey     NVARCHAR( 15), ' +   
            ' @cType          NVARCHAR( 20), ' + 
            ' @cUpdateTable   NVARCHAR( 20), ' + 
            ' @cPalletID      NVARCHAR( 20), ' + 
            ' @cCartonID      NVARCHAR( 20), ' + 
            ' @cSKU           NVARCHAR( 20) = '''' OUTPUT, ' + 
            ' @nQTY           INT           = 0    OUTPUT, ' + 
            ' @cCartonUDF01   NVARCHAR( 30) = '''' OUTPUT, ' + 
            ' @cCartonUDF02   NVARCHAR( 30) = '''' OUTPUT, ' + 
            ' @cCartonUDF03   NVARCHAR( 30) = '''' OUTPUT, ' + 
            ' @cCartonUDF04   NVARCHAR( 30) = '''' OUTPUT, ' + 
            ' @cCartonUDF05   NVARCHAR( 30) = '''' OUTPUT, ' + 
            ' @nErrNo         INT           OUTPUT, ' + 
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cType, @cUpdateTable, @cPalletID, @cCartonID, @cSKU OUTPUT, @nQTY OUTPUT, 
            @cCartonUDF01 OUTPUT, @cCartonUDF02 OUTPUT, @cCartonUDF03 OUTPUT, @cCartonUDF04 OUTPUT, @cCartonUDF05 OUTPUT, 
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         GOTO Quit
      END
   END

   /***********************************************************************************************
                                             Standard logic
   ***********************************************************************************************/
   DECLARE @cCartonIDSP       NVARCHAR( 20)
   DECLARE @cPalletCriteria   NVARCHAR( 20)
   
   -- Storer config
   SET @cCartonIDSP = rdt.RDTGetConfig( @nFunc, 'CartonIDSP', @cStorerKey)
   IF @cCartonIDSP NOT IN ('PickDetailDropID', 'PickDetailCaseID', 'PackDetailLabelNo', 'PackDetailDropID')
      SET @cCartonIDSP = 'PickDetailDropID'
   SET @cPalletCriteria = rdt.RDTGetConfig( @nFunc, 'PalletCriteria', @cStorerKey)
   IF @cPalletCriteria = '0'
      SET @cPalletCriteria = ''

   IF @cType = 'CartonID'
   BEGIN
      -- Check carton scanned
      IF @cUpdateTable = 'DROPID'
      BEGIN
         IF EXISTS( SELECT 1
            FROM dbo.DropID WITH (NOLOCK) 
               JOIN dbo.DropIDDetail WITH (NOLOCK) ON (DropID.DropID = DropIDDetail.DropID)
            WHERE DropIDType = CAST( @nFunc AS NVARCHAR( 4))
               AND ChildID = @cCartonID
               AND DropID.Status < '9')
         BEGIN
            SET @nErrNo = 204101
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Carton scanned
            GOTO Quit
         END
      END
      
      ELSE IF @cUpdateTable = 'PALLET'
      BEGIN
         IF EXISTS( SELECT 1
            FROM dbo.Pallet WITH (NOLOCK) 
               JOIN dbo.PalletDetail WITH (NOLOCK) ON (Pallet.PalletKey = PalletDetail.PalletKey)
            WHERE PalletType = CAST( @nFunc AS NVARCHAR( 4))
               AND CaseID = @cCartonID)
         BEGIN
            SET @nErrNo = 204102
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Carton scanned
            GOTO Quit
         END
      END

      -- Get pallet criteria setup
      DECLARE @cUDF01 NVARCHAR( 60) = ''
      DECLARE @cUDF02 NVARCHAR( 60) = ''
      DECLARE @cUDF03 NVARCHAR( 60) = ''
      DECLARE @cUDF04 NVARCHAR( 60) = ''
      DECLARE @cUDF05 NVARCHAR( 60) = ''
      DECLARE @cLongCriteria NVARCHAR( 250) = ''
      SELECT
         @cUDF01 = UDF01,
         @cUDF02 = UDF02,
         @cUDF03 = UDF03,
         @cUDF04 = UDF04,
         @cUDF05 = UDF05, 
         @cLongCriteria = ISNULL( Long, '')
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTBuildPL'
         AND Code = @cPalletCriteria
         AND StorerKey = @cStorerKey
      
      -- Check carton valid
      IF @cCartonIDSP IN ('PickDetailDropID', 'PickDetailCaseID')
      BEGIN
         DECLARE @nRowCount INT = 0
         SET @cSQL = 
            ' SELECT TOP 1 @nRowCount = 1' + 
               CASE WHEN @cUDF01 <> '' THEN ' ,@cCartonUDF01 = ' + @cUDF01 ELSE '' END + 
               CASE WHEN @cUDF02 <> '' THEN ' ,@cCartonUDF02 = ' + @cUDF02 ELSE '' END + 
               CASE WHEN @cUDF03 <> '' THEN ' ,@cCartonUDF03 = ' + @cUDF03 ELSE '' END + 
               CASE WHEN @cUDF04 <> '' THEN ' ,@cCartonUDF04 = ' + @cUDF04 ELSE '' END + 
               CASE WHEN @cUDF05 <> '' THEN ' ,@cCartonUDF05 = ' + @cUDF05 ELSE '' END + 
               CASE WHEN @cLongCriteria <> '' THEN ' ,' + @cLongCriteria   ELSE '' END + 
            ' FROM dbo.Orders O WITH (NOLOCK) ' + 
               ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' + 
            ' WHERE O.StorerKey = @cStorerKey ' + 
               ' AND PD.QTY > 0 ' + 
               ' AND PD.Status <> ''4'' ' + 
               CASE WHEN @cCartonIDSP = 'PickDetailDropID' THEN ' AND PD.DropID = @cCartonID ' 
                    WHEN @cCartonIDSP = 'PickDetailCaseID' THEN ' AND PD.CaseID = @cCartonID ' 
                    ELSE ''
               END
         SET @cSQLParam =
            ' @cStorerKey   NVARCHAR( 15), ' + 
            ' @cCartonID    NVARCHAR( 20), ' + 
            ' @nRowCount    INT           OUTPUT, ' + 
            ' @cCartonUDF01 NVARCHAR( 30) OUTPUT, ' +  
            ' @cCartonUDF02 NVARCHAR( 30) OUTPUT, ' + 
            ' @cCartonUDF03 NVARCHAR( 30) OUTPUT, ' + 
            ' @cCartonUDF04 NVARCHAR( 30) OUTPUT, ' + 
            ' @cCartonUDF05 NVARCHAR( 30) OUTPUT  ' 

         EXEC sp_executeSQL @cSQL, @cSQLParam, 
            @cStorerKey, 
            @cCartonID, 
            @nRowCount    OUTPUT, 
            @cCartonUDF01 OUTPUT, 
            @cCartonUDF02 OUTPUT,
            @cCartonUDF03 OUTPUT,
            @cCartonUDF04 OUTPUT,
            @cCartonUDF05 OUTPUT
         
         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 204103
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid carton
            GOTO Quit
         END
      END

      ELSE IF @cCartonIDSP IN ('PackDetailLabelNo', 'PackDetailDropID')
      BEGIN
         DECLARE @cPickSlipNo NVARCHAR( 10) = ''
         DECLARE @cOrderKey NVARCHAR( 10)
         DECLARE @cLoadKey  NVARCHAR( 10)
         
         IF @cCartonIDSP = 'PackDetailLabelNo'
            SELECT @cPickSlipNo = PickSlipNo FROM PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND LabelNo = @cCartonID
         IF @cCartonIDSP = 'PackDetailDropID'
            SELECT @cPickSlipNo = PickSlipNo FROM PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cCartonID
         SET @nRowCount = @@ROWCOUNT

         IF @cPickSlipNo = ''
         BEGIN
            SET @nErrNo = 204104
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid carton
            GOTO Quit
         END
                  
         -- Get PickSlip info
         SELECT 
            @cOrderKey = OrderKey,
            @cLoadKey  = LoadKey
         FROM PackHeader WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo
         
         SET @cSQL = 
            ' SELECT TOP 1 1 ' + 
               CASE WHEN @cUDF01 <> '' THEN ' ,@cCartonUDF01 = ' + @cUDF01 ELSE '' END + 
               CASE WHEN @cUDF02 <> '' THEN ' ,@cCartonUDF02 = ' + @cUDF02 ELSE '' END + 
               CASE WHEN @cUDF03 <> '' THEN ' ,@cCartonUDF03 = ' + @cUDF03 ELSE '' END + 
               CASE WHEN @cUDF04 <> '' THEN ' ,@cCartonUDF04 = ' + @cUDF04 ELSE '' END + 
               CASE WHEN @cUDF05 <> '' THEN ' ,@cCartonUDF05 = ' + @cUDF05 ELSE '' END + 
               CASE WHEN @cLongCriteria <> '' THEN ' ,' + @cLongCriteria   ELSE '' END + 
            ' FROM dbo.PackHeader PH WITH (NOLOCK) ' + 
               ' JOIN dbo.PackDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' + 
               CASE WHEN @cOrderKey <> '' THEN ' JOIN dbo.Orders O WITH (NOLOCK) ON (PH.OrderKey = O.OrderKey) ' 
                    WHEN @cLoadKey  <> '' THEN ' JOIN dbo.Orders O WITH (NOLOCK) ON (PH.LoadKey = O.LoadKey) ' 
                    ELSE ''
               END + 
            ' WHERE PH.PickSlipNo = @cPickSlipNo ' + 
               ' AND PD.QTY > 0 ' + 
               CASE WHEN @cCartonID = 'PackDetailLabelNo' THEN ' AND PD.LabelNo = @cCartonID ' 
                    WHEN @cCartonID = 'PackDetailDropID' THEN ' AND PD.DropID = @cCartonID ' 
                    ELSE ''
               END
         SET @cSQLParam =
            ' @cPickSlipNo  NVARCHAR( 10), ' + 
            ' @cCartonID    NVARCHAR( 20), ' + 
            ' @cCartonUDF01 NVARCHAR( 30) OUTPUT, ' +  
            ' @cCartonUDF02 NVARCHAR( 30) OUTPUT, ' + 
            ' @cCartonUDF03 NVARCHAR( 30) OUTPUT, ' + 
            ' @cCartonUDF04 NVARCHAR( 30) OUTPUT, ' + 
            ' @cCartonUDF05 NVARCHAR( 30) OUTPUT  ' 

         EXEC sp_executeSQL @cSQL, @cSQLParam, 
            @cPickSlipNo, 
            @cCartonID    OUTPUT, 
            @cCartonUDF01 OUTPUT, 
            @cCartonUDF02 OUTPUT,
            @cCartonUDF03 OUTPUT,
            @cCartonUDF04 OUTPUT,
            @cCartonUDF05 OUTPUT
      END
   
      -- Get SKU, QTY
      SET @cSKU = ''
      SET @nQTY = 0
      IF @cUpdateTable = 'PALLET'
      BEGIN
         IF @cCartonIDSP = 'PickDetailDropID'
            SELECT @cSKU = MIN( SKU), @nQTY = SUM( QTY) FROM PickDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cCartonID AND QTY > 0 AND Status <> '4'
         ELSE IF @cCartonIDSP = 'PickDetailCaseID'
            SELECT @cSKU = MIN( SKU), @nQTY = SUM( QTY) FROM PickDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND CaseID = @cCartonID AND QTY > 0 AND Status <> '4'
         IF @cCartonIDSP = 'PackDetailLabelNo'
            SELECT @cSKU = MIN( SKU), @nQTY = SUM( QTY) FROM PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND LabelNo = @cCartonID AND QTY > 0
         ELSE IF @cCartonIDSP = 'PackDetailDropID'
            SELECT @cSKU = MIN( SKU), @nQTY = SUM( QTY) FROM PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cCartonID AND QTY > 0
      END
   END
   
   IF @cType = 'PalletID'
   BEGIN
      DECLARE @cStatus      NVARCHAR( 10)
      DECLARE @cPalletUDF01 NVARCHAR( 30)
      DECLARE @cPalletUDF02 NVARCHAR( 30)
      DECLARE @cPalletUDF03 NVARCHAR( 30)
      DECLARE @cPalletUDF04 NVARCHAR( 30)
      DECLARE @cPalletUDF05 NVARCHAR( 30)

      -- Check pallet closed
      IF @cUpdateTable = 'DROPID'
      BEGIN
         -- Get pallet info
         SELECT @cStatus = Status
         FROM dbo.DropID WITH (NOLOCK)
         WHERE Dropid = @cPalletID 
         
         -- Check status
         IF @cStatus = '9'
         BEGIN
            SET @nErrNo = 204105
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet closed
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         -- Get pallet info
         SELECT @cStatus = Status
         FROM dbo.Pallet WITH (NOLOCK)
         WHERE PalletKey = @cPalletID 
         
         -- Check status
         IF @cStatus = '9'
         BEGIN
            SET @nErrNo = 204106
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet closed
            GOTO Quit
         END
      
      END
      
      -- Check carton criteria matched with pallet criteria
      IF @cCartonID <> ''
      BEGIN
         -- Get pallet criteria
         IF @cUpdateTable = 'DROPID'
            SELECT 
               @cPalletUDF01 = UDF01, 
               @cPalletUDF02 = UDF02, 
               @cPalletUDF03 = UDF03, 
               @cPalletUDF04 = UDF04, 
               @cPalletUDF05 = UDF05
            FROM dbo.DropID WITH (NOLOCK)
            WHERE DropID = @cPalletID
         ELSE
            SELECT 
               @cPalletUDF01 = UserDefine01, 
               @cPalletUDF02 = UserDefine02, 
               @cPalletUDF03 = UserDefine03, 
               @cPalletUDF04 = UserDefine04, 
               @cPalletUDF05 = UserDefine05
            FROM dbo.PalletDetail WITH (NOLOCK)
            WHERE PalletKey = @cPalletID
      
         -- Check carton criteria matched with pallet criteria
         IF @@ROWCOUNT = 1
         BEGIN
            /*
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', 
               @cCartonUDF01, @cCartonUDF02, @cCartonUDF03, @cCartonUDF04, @cCartonUDF05, 
               @cPalletUDF01, @cPalletUDF02, @cPalletUDF03, @cPalletUDF04, @cPalletUDF05 
            */
            IF @cCartonUDF01 <> @cPalletUDF01 OR 
               @cCartonUDF02 <> @cPalletUDF02 OR 
               @cCartonUDF03 <> @cPalletUDF03 OR 
               @cCartonUDF04 <> @cPalletUDF04 OR 
               @cCartonUDF05 <> @cPalletUDF05
            BEGIN
               SET @nErrNo = 204107
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff criteria
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO