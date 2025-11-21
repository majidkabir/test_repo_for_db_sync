SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1641ExtValidSP02                                      */
/* Purpose: Validate Pallet DropID                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2014-11-25 1.0  Ung      SOS325485 Created                                 */
/* 2015-10-26 1.1  Ung      SOS354305                                         */
/*                          Add CheckPackDetailDropID                         */
/*                          Add CheckPickDetailDropID                         */
/* 2017-01-24 1.2  Ung      Fix recompile due to date format different        */
/* 2017-12-12 1.3  Ung      WMS-3620 Add conso pack                           */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1641ExtValidSP02] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR(3),
   @nStep        INT,
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR(15),
   @cDropID      NVARCHAR(20),
   @cUCCNo       NVARCHAR(20),
   @cPrevLoadKey NVARCHAR(10),
   @cParam1      NVARCHAR(20),
   @cParam2      NVARCHAR(20),
   @cParam3      NVARCHAR(20),
   @cParam4      NVARCHAR(20),
   @cParam5      NVARCHAR(20),
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR(20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

IF @nFunc = 1641
BEGIN
   DECLARE @cRoute          NVARCHAR(10)
   DECLARE @cOptRoute       NVARCHAR(10)
   DECLARE @cDischargePlace NVARCHAR(20)
   DECLARE @cDeliveryDate   NVARCHAR(10)

   DECLARE @cParamLabel1    NVARCHAR(20)
   DECLARE @cParamLabel2    NVARCHAR(20)
   DECLARE @cParamLabel3    NVARCHAR(20)
   DECLARE @cParamLabel4    NVARCHAR(20)
   DECLARE @cParamLabel5    NVARCHAR(20)
   DECLARE @cPalletCriteria NVARCHAR(20)

   DECLARE @cUDF01          NVARCHAR(60)
   DECLARE @cUDF02          NVARCHAR(60)
   DECLARE @cUDF03          NVARCHAR(60)
   DECLARE @cUDF04          NVARCHAR(60)
   DECLARE @cUDF05          NVARCHAR(60)
   
   -- Parameter mapping
   SET @cRoute = @cParam1           -- compulsory
   SET @cOptRoute = @cParam2        -- optional
   SET @cDischargePlace = @cParam3  -- can be blank
   SET @cDeliveryDate = @cParam4    -- optional
   
   IF @nStep = 1 -- Drop ID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Get DropID info
         SELECT
            @cUDF01 = LEFT( ISNULL( UDF01, ''), 20), 
            @cUDF02 = LEFT( ISNULL( UDF02, ''), 20), 
            @cUDF03 = LEFT( ISNULL( UDF03, ''), 20), 
            @cUDF04 = LEFT( ISNULL( UDF04, ''), 20), 
            @cUDF05 = LEFT( ISNULL( UDF05, ''), 20)
         FROM DropID WITH (NOLOCK) 
         WHERE DropID = @cDropID
         
         IF @@ROWCOUNT = 1
         BEGIN
            -- Check pallet criteria different
            IF @cParam1 <> @cUDF01 OR 
               @cParam2 <> @cUDF02 OR 
               @cParam3 <> @cUDF03 OR 
               @cParam4 <> @cUDF04 OR 
               @cParam5 <> @cUDF05
            BEGIN
               -- Get storer config
               SET @cPalletCriteria = rdt.RDTGetConfig( @nFunc, 'PalletCriteria', @cStorerKey)
               IF @cPalletCriteria = '0'
                  SET @cPalletCriteria = ''
      
               -- Get pallet criteria label
               SELECT
                  @cParamLabel1 = UDF01,
                  @cParamLabel2 = UDF02,
                  @cParamLabel3 = UDF03,
                  @cParamLabel4 = UDF04,
                  @cParamLabel5 = UDF05
              FROM dbo.CodeLKUP WITH (NOLOCK)
               WHERE ListName = 'RDTBuildPL'
                  AND Code = @cPalletCriteria
                  AND StorerKey = @cStorerKey
   
               -- Prompt alert
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                  'WARNING:            ', 
                  'DIFFERENT CRITERIA: ',
                  @cParamLabel1, 
                  @cUDF01, 
                  @cParamLabel2, 
                  @cUDF02, 
                  @cParamLabel3, 
                  @cUDF03, 
                  @cParamLabel4, 
                  @cUDF04 
               SET @nErrNo = 0
            END
         END
      END
   END
   
   IF @nStep = 3 -- UCC
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         DECLARE @cPickSlipNo NVARCHAR(10)
         DECLARE @cOrderKey   NVARCHAR(10)
         DECLARE @cLoadKey    NVARCHAR(10)
         DECLARE @cOrderRoute NVARCHAR(10)
         DECLARE @cOrderDischargePlace NVARCHAR(20)
         DECLARE @dOrderDeliveryDate   DATETIME
         
         SET @cPickSlipNo = ''
         SET @cOrderKey = ''
         SET @cLoadKey = ''
         
         -- Get PickSlipNo 
         IF rdt.RDTGetConfig( @nFunc, 'CheckPackDetailDropID', @cStorerKey) = '1'
            SELECT @cPickSlipNo = PickSlipNo FROM dbo.PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cUCCNo
         ELSE 
            IF rdt.RDTGetConfig( @nFunc, 'CheckPickDetailDropID', @cStorerKey) = '1'
               SELECT @cOrderKey = OrderKey FROM dbo.PickDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cUCCNo
            ELSE
               SELECT @cPickSlipNo = PickSlipNo FROM PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND LabelNo = @cUCCNo
         
         -- Get OrderKey
         IF @cPickSlipNo <> '' 
         BEGIN
            -- Get PackHeader info
            SELECT 
               @cLoadKey = LoadKey, 
               @cOrderKey = OrderKey 
            FROM dbo.PackHeader WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo
            
            -- Conso pack
            IF @cOrderKey = ''
               -- Get random order
               SELECT TOP 1 @cOrderKey = OrderKey FROM LoadPlanDetail WITH (NOLOCK) WHERE LoadKey = @cLoadKey
         END
         
         -- Get order info
         SELECT 
            @cOrderRoute = Route,   
            @cOrderDischargePlace = LEFT( ISNULL( DischargePlace, ''), 20), 
            @dOrderDeliveryDate = DeliveryDate
         FROM Orders WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey
         
         IF @cOrderKey <> ''
         BEGIN
            DECLARE @nRouteMatch INT
            SET @nRouteMatch = 0 -- No
         
            -- Compulsory route
            IF PATINDEX( @cRoute + '%', @cOrderRoute) <> 0
               SET @nRouteMatch = 1 -- Yes

            -- Optional route
            IF @cOptRoute <> '' 
               IF PATINDEX( @cOptRoute + '%', @cOrderRoute) <> 0
                  SET @nRouteMatch = 1 -- Yes

            IF @nRouteMatch = 0 -- No
            BEGIN
               SET @nErrNo = 92151
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- RouteNotMatch
               GOTO Quit 
            END

            -- DischargePlace
            IF @cOrderDischargePlace <> @cDischargePlace
            BEGIN
               SET @nErrNo = 92152
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff Discharge
               GOTO Quit 
            END

            -- Optional delivery date 
            IF @cDeliveryDate <> ''
            BEGIN
               -- Trim the time portion
               SET @dOrderDeliveryDate = DATEADD(dd, DATEDIFF(dd, 0, @dOrderDeliveryDate), 0)

               IF @dOrderDeliveryDate <> rdt.rdtConvertToDate( @cDeliveryDate)
               BEGIN
                  SET @nErrNo = 92153
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff Delivery
                  GOTO Quit 
               END
            END
         END
      END
   END

   IF @nStep = 5 -- Pallet criteria
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Check route
         IF @cRoute = ''
         BEGIN
            SET @nErrNo = 92154
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need Route
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Route
            GOTO Quit 
         END

         -- Check DeliveryDate
         IF @cDeliveryDate <> ''
            IF rdt.rdtIsValidDate( @cDeliveryDate) = 0
            BEGIN
               SET @nErrNo = 92155
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid date
               EXEC rdt.rdtSetFocusField @nMobile, 8 -- DeliveryDate
               GOTO Quit 
            END
      END
   END
END

QUIT:



GO