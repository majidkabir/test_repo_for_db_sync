SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* Store procedure: rdt_838ExtScn05                                     */
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2024-06-27 1.0  CYU027    FCR-2495. Created                          */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_838ExtScn05] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep INT,           
   @nScn  INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15), 

   @tExtScnData   VariableTable READONLY,

   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,  @cLottable01 NVARCHAR( 18) OUTPUT,  
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,  @cLottable02 NVARCHAR( 18) OUTPUT,  
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,  @cLottable03 NVARCHAR( 18) OUTPUT,  
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,  @dLottable04 DATETIME      OUTPUT,  
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,  @dLottable05 DATETIME      OUTPUT,  
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,  @cLottable06 NVARCHAR( 30) OUTPUT, 
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  @cLottable07 NVARCHAR( 30) OUTPUT, 
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  @cLottable08 NVARCHAR( 30) OUTPUT, 
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  @cLottable09 NVARCHAR( 30) OUTPUT, 
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  @cLottable10 NVARCHAR( 30) OUTPUT, 
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,  @cLottable11 NVARCHAR( 30) OUTPUT,
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,  @cLottable12 NVARCHAR( 30) OUTPUT,
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,  @dLottable13 DATETIME      OUTPUT,
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,  @dLottable14 DATETIME      OUTPUT,
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,  @dLottable15 DATETIME      OUTPUT,
   @nAction      INT, --0 Jump Screen, 2. Prepare output fields, Step = 99 is a new screen
   @nAfterScn    INT OUTPUT, @nAfterStep    INT OUTPUT, 
   @nErrNo             INT            OUTPUT, 
   @cErrMsg            NVARCHAR( 1024)  OUTPUT,
   @cUDF01  NVARCHAR( 250) OUTPUT, @cUDF02 NVARCHAR( 250) OUTPUT, @cUDF03 NVARCHAR( 250) OUTPUT,
   @cUDF04  NVARCHAR( 250) OUTPUT, @cUDF05 NVARCHAR( 250) OUTPUT, @cUDF06 NVARCHAR( 250) OUTPUT,
   @cUDF07  NVARCHAR( 250) OUTPUT, @cUDF08 NVARCHAR( 250) OUTPUT, @cUDF09 NVARCHAR( 250) OUTPUT,
   @cUDF10  NVARCHAR( 250) OUTPUT, @cUDF11 NVARCHAR( 250) OUTPUT, @cUDF12 NVARCHAR( 250) OUTPUT,
   @cUDF13  NVARCHAR( 250) OUTPUT, @cUDF14 NVARCHAR( 250) OUTPUT, @cUDF15 NVARCHAR( 250) OUTPUT,
   @cUDF16  NVARCHAR( 250) OUTPUT, @cUDF17 NVARCHAR( 250) OUTPUT, @cUDF18 NVARCHAR( 250) OUTPUT,
   @cUDF19  NVARCHAR( 250) OUTPUT, @cUDF20 NVARCHAR( 250) OUTPUT, @cUDF21 NVARCHAR( 250) OUTPUT,
   @cUDF22  NVARCHAR( 250) OUTPUT, @cUDF23 NVARCHAR( 250) OUTPUT, @cUDF24 NVARCHAR( 250) OUTPUT,
   @cUDF25  NVARCHAR( 250) OUTPUT, @cUDF26 NVARCHAR( 250) OUTPUT, @cUDF27 NVARCHAR( 250) OUTPUT,
   @cUDF28  NVARCHAR( 250) OUTPUT, @cUDF29 NVARCHAR( 250) OUTPUT, @cUDF30 NVARCHAR( 250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE

      @cID                    NVARCHAR(18),
      @cStatus                NVARCHAR( 20),
      @cBatchNo               NVARCHAR( 20),
      @cUOM                   NVARCHAR( 20),
      @cQty                   NVARCHAR( 5),
      @nCaseQty               INT,
      @cPaperPrinter          NVARCHAR( 10),
      @cLabelPrinter          NVARCHAR( 10),
      --config variable
      @cExtendedUpdateSP      NVARCHAR( 20),
      @cExtendedValidateSP    NVARCHAR( 20),
      @cExtendedInfoSP        NVARCHAR( 20),
      @cPickDetailKey         NVARCHAR(18),


      @cLabelNo               NVARCHAR( 20),
      @cDefaultOption         NVARCHAR( 1),

      --variables saved to mobrec
      @cPickSlipNo            NVARCHAR( 10),
      @cPackDtlDropID         NVARCHAR( 20) = '',
      @cFromDropID            NVARCHAR( 20) = '',
      @nCartonNo              INT,

      @cOption                NVARCHAR( 2),
      @cUCCNo                 NVARCHAR( 20),
      @cCartonType            NVARCHAR( 10),
      @cSerialNo              NVARCHAR( 30) = '',
      @cCube                  NVARCHAR( 10),
      @cWeight                NVARCHAR( 10),
      @cRefNo                 NVARCHAR( 20),
      @nSerialQTY             INT,
      @cPackDtlRefNo          NVARCHAR( 20),
      @cPackDtlRefNo2         NVARCHAR( 20),
      @cPackDtlUPC            NVARCHAR( 30),
      @cPackData1             NVARCHAR( 30),
      @cPackData2             NVARCHAR( 30),
      @cPackData3             NVARCHAR( 30),
      @cPUOM                  NVARCHAR( 1),
      @cExtendedInfo          NVARCHAR( 20),
      @cShowPickSlipNo        NVARCHAR( 1),
      @cParam1Label           NVARCHAR( 20),
      @cParam2Label           NVARCHAR( 20),
      @cParam3Label           NVARCHAR( 20),
      @cParam4Label           NVARCHAR( 20),
      @cParam5Label           NVARCHAR( 20),
      @cScreenTitle           NVARCHAR( 20),
      @cShipLabel             NVARCHAR( 10),
      @cCstLabelSP            NVARCHAR(30),
      @cSKU                   NVARCHAR( 20),
      @nSum_PickDQty          INT,
      @nSum_PackDQty          INT,
      @cTaskDetailKey         NVARCHAR( 20),
      @cDisableQTYField       NVARCHAR( 1),
      @cSQL                   NVARCHAR( MAX),
      @cSQLParam              NVARCHAR( MAX),
      @nQTY                   INT,
      @nTranCount             INT,
      @bSuccess               INT,
      @tShipLabel             VariableTable

   
   SET @nErrNo = 0
   SET @cErrMsg = ''
   SET @cTaskDetailKey = ''

   --SELECT @cDropID = Value FROM @tExtScnData WHERE Variable = '@cDropID'

   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerkey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerkey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerkey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''



   SELECT

      @cPaperPrinter    = Printer_Paper,
      @cLabelPrinter    = Printer,
      @cPickSlipNo      = V_PickSlipNo,
      @nQTY             = V_QTY,
      -- @cCustomID        = V_CaseID,
      @cPUOM            = V_UOM,

      @cPackDtlRefNo       = V_String1,
      @cPackDtlRefNo2      = V_String2,
      @cLabelNo            = V_String3,
      @cCartonType         = V_String4,
      @cCube               = V_String5,
      @cWeight             = V_String6,
      @cRefNo              = V_String7,
      @cPackDtlDropID      = V_String9,

      @nCartonNo           = V_CartonNo,
      @cShowPickSlipNo     = V_String15,
      @cFromDropID         = V_String20,
      @cExtendedValidateSP = V_String21,
      @cExtendedUpdateSP   = V_String22,
      @cExtendedInfoSP     = V_String23,
      @cExtendedInfo       = V_String24,
      @cDisableQTYField    = V_String26,
      @cShipLabel          = V_String36,
      @cPackDtlUPC         = V_String41,
      @cPackData1          = V_String44,
      @cPackData2          = V_String45,
      @cPackData3          = V_String46


   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT

   IF @nFunc = 838
   BEGIN

      IF @nScn = 4651 AND @nStep = 2
      BEGIN
         SET @cOutField01 = ''
         SET @nAfterScn = 6521
         SET @nAfterStep = 99 
         GOTO Quit
      END

      IF @nStep = 99
      BEGIN
         IF @nScn = 6521
         /************************************************************************************
         Scn = 6521. Statistic Screen, Added option 5=PTL
              OPTION    (field09, input)
         ************************************************************************************/
         BEGIN -- Copy from step 2
            IF @nInputKey = 1 -- Only ENTER and OPTION = 5
            BEGIN
               -- Screen mapping
               SET @cOption = @cInField09

               IF @cOption <> '5'
               BEGIN
                  SET @nErrNo = 100205
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
                  SET @cOutField08 = '' -- Option
                  GOTO Quit
               END
               -- Check Pack confirmed
               IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status = '9')
               BEGIN
                  SET @nErrNo = 100203
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pack confirmed
                  GOTO Quit
               END

               -- Extended validate
               IF @cExtendedValidateSP <> ''
               BEGIN
                  IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
                  BEGIN
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
                                 ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
                                 ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
                                 ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
                                 ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
                     SET @cSQLParam =
                             '@nMobile         INT,           ' +
                             '@nFunc           INT,           ' +
                             '@cLangCode       NVARCHAR( 3),  ' +
                             '@nStep           INT,           ' +
                             '@nInputKey       INT,           ' +
                             '@cFacility       NVARCHAR( 5),  ' +
                             '@cStorerKey      NVARCHAR( 15), ' +
                             '@cPickSlipNo     NVARCHAR( 10), ' +
                             '@cFromDropID     NVARCHAR( 20), ' +
                             '@nCartonNo       INT,           ' +
                             '@cLabelNo        NVARCHAR( 20), ' +
                             '@cSKU            NVARCHAR( 20), ' +
                             '@nQTY            INT,           ' +
                             '@cUCCNo          NVARCHAR( 20), ' +
                             '@cCartonType     NVARCHAR( 10), ' +
                             '@cCube           NVARCHAR( 10), ' +
                             '@cWeight         NVARCHAR( 10), ' +
                             '@cRefNo          NVARCHAR( 20), ' +
                             '@cSerialNo       NVARCHAR( 30), ' +
                             '@nSerialQTY      INT,    ' +
                             '@cOption         NVARCHAR( 1),  ' +
                             '@cPackDtlRefNo   NVARCHAR( 20), ' +
                             '@cPackDtlRefNo2  NVARCHAR( 20), ' +
                             '@cPackDtlUPC     NVARCHAR( 30), ' +
                             '@cPackDtlDropID  NVARCHAR( 20), ' +
                             '@cPackData1      NVARCHAR( 30), ' +
                             '@cPackData2      NVARCHAR( 30), ' +
                             '@cPackData3      NVARCHAR( 30), ' +
                             '@nErrNo          INT            OUTPUT, ' +
                             '@cErrMsg         NVARCHAR( 20)  OUTPUT'

                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                          @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
                          @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
                          @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
                          @nErrNo OUTPUT, @cErrMsg OUTPUT

                     IF @nErrNo <> 0
                        GOTO Quit
                  END
               END

               -- Extended update
               IF @cExtendedUpdateSP <> ''
               BEGIN
                  IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
                  BEGIN
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                                 ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
                                 ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
                                 ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
                                 ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
                     SET @cSQLParam =
                             '@nMobile         INT,           ' +
                             '@nFunc           INT,           ' +
                             '@cLangCode       NVARCHAR( 3),  ' +
                             '@nStep           INT,           ' +
                             '@nInputKey       INT,           ' +
                             '@cFacility       NVARCHAR( 5),  ' +
                             '@cStorerKey      NVARCHAR( 15), ' +
                             '@cPickSlipNo     NVARCHAR( 10), ' +
                             '@cFromDropID     NVARCHAR( 20), ' +
                             '@nCartonNo       INT,           ' +
                             '@cLabelNo        NVARCHAR( 20), ' +
                             '@cSKU            NVARCHAR( 20), ' +
                             '@nQTY            INT,           ' +
                             '@cUCCNo          NVARCHAR( 20), ' +
                             '@cCartonType     NVARCHAR( 10), ' +
                             '@cCube           NVARCHAR( 10), ' +
                             '@cWeight         NVARCHAR( 10), ' +
                             '@cRefNo          NVARCHAR( 20), ' +
                             '@cSerialNo       NVARCHAR( 30), ' +
                             '@nSerialQTY      INT,           ' +
                             '@cOption         NVARCHAR( 1),  ' +
                             '@cPackDtlRefNo   NVARCHAR( 20), ' +
                             '@cPackDtlRefNo2  NVARCHAR( 20), ' +
                             '@cPackDtlUPC     NVARCHAR( 30), ' +
                             '@cPackDtlDropID  NVARCHAR( 20), ' +
                             '@cPackData1      NVARCHAR( 30), ' +
                             '@cPackData2      NVARCHAR( 30), ' +
                             '@cPackData3      NVARCHAR( 30), ' +
                             '@nErrNo          INT            OUTPUT, ' +
                             '@cErrMsg         NVARCHAR( 20)  OUTPUT'

                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                          @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
                          @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
                          @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
                          @nErrNo OUTPUT, @cErrMsg OUTPUT

                  END
               END

               -- Get report info
               SELECT
                  @cScreenTitle= LEFT( RTRIM(Description), 20),
                  @cParam1Label = UDF01,
                  @cParam2Label = UDF02,
                  @cParam3Label = UDF03,
                  @cParam4Label = UDF04,
                  @cParam5Label = UDF05
               FROM dbo.CodeLKUP WITH (NOLOCK)
               WHERE ListName = 'RDTCUSPACK'
                 AND StorerKey = @cStorerKey

               -- Check report param setup
               IF @cParam1Label = '' AND
                  @cParam2Label = '' AND
                  @cParam3Label = '' AND
                  @cParam4Label = '' AND
                  @cParam5Label = ''
               BEGIN
                  SET @nErrNo = 234151
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CodeLkUp not found
                  GOTO Quit
               END

               -- Enable / disable field
               SET @cFieldAttr02 = CASE WHEN @cParam1Label = '' THEN 'O' ELSE '' END
               SET @cFieldAttr04 = CASE WHEN @cParam2Label = '' THEN 'O' ELSE '' END
               SET @cFieldAttr06 = CASE WHEN @cParam3Label = '' THEN 'O' ELSE '' END
               SET @cFieldAttr08 = CASE WHEN @cParam4Label = '' THEN 'O' ELSE '' END
               SET @cFieldAttr10 = CASE WHEN @cParam5Label = '' THEN 'O' ELSE '' END

               -- Clear optional in field
               SET @cInField02 = ''
               SET @cInField04 = ''
               SET @cInField06 = ''
               SET @cInField08 = ''
               SET @cInField10 = ''

               -- Prepare next screen var
               SET @cOutField01 = @cParam1Label
               SET @cOutField02 = ''
               SET @cOutField03 = @cParam2Label
               SET @cOutField04 = ''
               SET @cOutField05 = @cParam3Label
               SET @cOutField06 = ''
               SET @cOutField07 = @cParam4Label
               SET @cOutField08 = ''
               SET @cOutField09 = @cParam5Label
               SET @cOutField10 = ''
               SET @cOutField11 = @cScreenTitle

               -- Go to next screen
               SET @nAfterScn = 6522
               SET @nAfterStep = 99

               -- Set the focus on first enabled field
               IF @cFieldAttr02 = '' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE
               IF @cFieldAttr04 = '' EXEC rdt.rdtSetFocusField @nMobile, 4 ELSE
               IF @cFieldAttr06 = '' EXEC rdt.rdtSetFocusField @nMobile, 6 ELSE
               IF @cFieldAttr07 = '' EXEC rdt.rdtSetFocusField @nMobile, 8 ELSE
               IF @cFieldAttr10 = '' EXEC rdt.rdtSetFocusField @nMobile, 10

            END
            GOTO Quit
         END


         IF @nScn = 6522
         BEGIN
            IF @nInputKey = 1
            BEGIN
               /***********************************************************************************
                  Scn = 6522. Parameter screen
                     Param1 label (field01)
                     Param1 value (field02, input) --ID
                     Param2 label (field03)
                     Param2 value (field04, input) --SKU
                     Param3 label (field05)
                     Param3 value (field06, input) -- Batch
                     Param4 label (field07)
                     Param4 value (field08, input) -- CS QTY
                     Param5 label (field09)
                     Param5 value (field10, input)
                  ***********************************************************************************/

               --Mapping values
               SET @cID       = @cInField02
               SET @cSKU      = @cInField04
               SET @cBatchNo  = @cInField06
               SET @cQty      = @cInField08

               IF (@cID = '' AND @cSKU = '')
               BEGIN
                  SET @nErrNo = 234152
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedIDOrSKU
                  GOTO Quit
               END

               BEGIN TRAN  -- Begin our own transaction
               SAVE TRAN rdt_838ExtScn05

               IF @cID <> '' AND @cSKU <> ''
               BEGIN
                  SET @nErrNo = 234157
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Only input either Pallet ID or SKU, not both
                  GOTO Quit
               END

               ELSE IF @cID <> '' --Full Pallet
               BEGIN

                  IF EXISTS(
                     SELECT 1
                     FROM PickDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND ID = @cID
                        AND PickSlipNo = @cPickSlipNo
                        AND Status <= '5'
                     GROUP BY SKU, LOT
                     HAVING COUNT(DISTINCT SKU) > 1 OR COUNT(DISTINCT LOT) > 1 )
                  BEGIN
                     SET @nErrNo = 234153
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUOrLOT
                     GOTO Quit
                  END

                  SELECT TOP 1
                         @cUOM = UOM
                  FROM PickDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                    AND ID = @cID
                    AND PickSlipNo = @cPickSlipNo
                  GROUP BY SKU, UOM
                  ORDER BY UOM DESC

                  IF @@rowcount < 1
                  BEGIN
                     SET @nErrNo = 234154
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet does not exist for the scanned PS No
                     GOTO Quit
                  END

                  IF @cUOM <> '1'
                  BEGIN
                     SET @nErrNo = 234155
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NOT Full Pallet
                     GOTO Quit
                  END

                  SELECT TOP 1
                     @cStatus = Status
                  FROM PickDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                    AND ID = @cID
                    AND PickSlipNo = @cPickSlipNo
                    AND status <> '5'
                  IF @@rowcount > 0
                  BEGIN
                     SET @nErrNo = 234156
                     SET @cErrMsg = REPLACE (rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP'),'{}',@cStatus) --Pallet in {} status
                     GOTO Quit
                  END


                  SELECT @nSum_PickDQty = ISNULL( SUM( Qty), 0)
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE ID = @CID
                    AND   Status <> '4'
                    AND   StorerKey  = @cStorerKey

                  SELECT @nSum_PackDQty = ISNULL( SUM( PD.Qty), 0)
                  FROM dbo.PackDetail PD WITH (NOLOCK)
                           JOIN dbo.PICKDETAIL PICKD WITH (NOLOCK) ON (
                              PICKD.PickSlipNo = PD.PickSlipNo
                              AND PICKD.caseid = PD.labelNo
                              AND PICKD.StorerKey = PD.StorerKey)
                  WHERE PD.StorerKey = @cStorerKey
                    AND  PICKD.ID = @cID
                    AND  PICKD.PickSlipNo = @cPickSlipNo

                  IF ( @nSum_PickDQty <= @nSum_PackDQty) AND @nSum_PackDQty > 0
                  BEGIN
                     SET @nErrNo = 234158
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Fully Packed'
                     GOTO Quit
                  END

                  --CHECK packed end

                  SELECT @cSKU = SKU,
                         @cPickDetailKey = PickDetailKey,
                         @nQty= QTY
                  FROM PickDetail (NOLOCK )
                  WHERE ID = @cID
                    AND   Status = '5' -- Only 5
                    AND   QTY > 0
                    AND   StorerKey  = @cStorerKey
                  ORDER BY PickDetailKey

                  IF @@ROWCOUNT <> 1
                  BEGIN
                     SET @nErrNo = 234164
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     GOTO Quit
                  END

                  EXEC RDT.rdt_Pack_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
                     ,@cPickSlipNo    = @cPickSlipNo
                     ,@cFromDropID    = @cID
                     ,@cSKU           = @cSKU
                     ,@nQTY           = @nQTY
                     ,@cUCCNo         = ''
                     ,@cSerialNo      = '' -- @cSerialNo
                     ,@nSerialQTY     = 0  -- @nSerialQTY
                     ,@cPackDtlRefNo  = ''
                     ,@cPackDtlRefNo2 = ''
                     ,@cPackDtlUPC    = ''
                     ,@cPackDtlDropID = ''
                     ,@nCartonNo      = @nCartonNo    OUTPUT
                     ,@cLabelNo       = @cLabelNo     OUTPUT
                     ,@nErrNo         = @nErrNo       OUTPUT
                     ,@cErrMsg        = @cErrMsg      OUTPUT
                     ,@nBulkSNO       = 0
                     ,@nBulkSNOQTY    = 0
                     ,@cPackData1     = ''
                     ,@cPackData2     = ''
                     ,@cPackData3     = ''
                  IF @nErrNo <> 0
                  BEGIN
                     --ROLLBACK
                     GOTO Quit
                  END

                  UPDATE PICKDETAIL WITH (ROWLOCK) SET CaseID = @cLabelNo
                  WHERE pickdetailkey= @cPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 234159
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Update Pickdetail Failed'
                     GOTO RollBackTran
                  END

                  --DO PRINT
                  IF @cShipLabel <> ''
                  BEGIN
                     IF @cShipLabel = 'CstLabelSP'
                     BEGIN
                        SET @cCstLabelSP = rdt.RDTGetConfig( @nFunc, 'CstLabelSP', @cStorerKey)
                        IF @cCstLabelSP = '0'
                           SET @cCstLabelSP = ''
                        IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cCstLabelSP AND type = 'P')  --Customize Print Label
                        BEGIN
                           SET @cSQL = 'EXEC rdt.' + RTRIM( @cCstLabelSP) +
                                       ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
                                       ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
                                       ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
                                       ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
                           SET @cSQLParam =
                                   '@nMobile         INT,           ' +
                                   '@nFunc           INT,           ' +
                                   '@cLangCode       NVARCHAR( 3),  ' +
                                   '@nStep           INT,           ' +
                                   '@nInputKey       INT,           ' +
                                   '@cFacility       NVARCHAR( 5),  ' +
                                   '@cStorerKey      NVARCHAR( 15), ' +
                                   '@cPickSlipNo     NVARCHAR( 10), ' +
                                   '@cFromDropID     NVARCHAR( 20), ' +
                                   '@nCartonNo       INT,           ' +
                                   '@cLabelNo        NVARCHAR( 20), ' +
                                   '@cSKU            NVARCHAR( 20), ' +
                                   '@nQTY            INT,           ' +
                                   '@cUCCNo          NVARCHAR( 20), ' +
                                   '@cCartonType     NVARCHAR( 10), ' +
                                   '@cCube           NVARCHAR( 10), ' +
                                   '@cWeight         NVARCHAR( 10), ' +
                                   '@cRefNo          NVARCHAR( 20), ' +
                                   '@cSerialNo       NVARCHAR( 30), ' +
                                   '@nSerialQTY      INT,           ' +
                                   '@cOption         NVARCHAR( 1),  ' +
                                   '@cPackDtlRefNo   NVARCHAR( 20), ' +
                                   '@cPackDtlRefNo2  NVARCHAR( 20), ' +
                                   '@cPackDtlUPC     NVARCHAR( 30), ' +
                                   '@cPackDtlDropID  NVARCHAR( 20), ' +
                                   '@cPackData1      NVARCHAR( 30), ' +
                                   '@cPackData2      NVARCHAR( 30), ' +
                                   '@cPackData3      NVARCHAR( 30), ' +
                                   '@nErrNo          INT            OUTPUT, ' +
                                   '@cErrMsg         NVARCHAR( 20)  OUTPUT'

                           EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                                @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
                                @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
                                @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
                                @nErrNo OUTPUT, @cErrMsg OUTPUT

                           IF @nErrNo <> 0
                              GOTO Quit
                        END
                     END
                     ELSE
                     BEGIN  --Standard Print
                        DELETE FROM @tShipLabel
                        INSERT INTO @tShipLabel (Variable, Value) VALUES
                              ( '@cStorerKey',     @cStorerKey),
                              ( '@cPickSlipNo',    @cPickSlipNo),
                              ( '@cFromDropID',    @cFromDropID),
                              ( '@cPackDtlDropID', @cPackDtlDropID),
                              ( '@cLabelNo',       @cLabelNo),
                              ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))

                        -- Print label
                        EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
                             @cShipLabel, -- Report type
                             @tShipLabel, -- Report params
                             'rdtfnc_Pack',
                             @nErrNo  OUTPUT,
                             @cErrMsg OUTPUT
                        IF @nErrNo <> 0
                           GOTO Quit
                     END
                  END --PRINT END


               END --FullPallet END
               ELSE IF @cSKU <> '' --PACK SKU
               BEGIN
                  IF ISNUMERIC(@cQty) = 0 OR @cQty < 1
                  BEGIN
                     SET @nErrNo = 234160
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --PleaseEnterQty
                     GOTO Quit
                  END

                  IF NOT EXISTS(
                     SELECT 1
                     FROM PickDetail PD WITH (NOLOCK)
                        JOIN LotAttribute LA(NOLOCK) ON (PD.LOT = LA.LOT)
                     WHERE PD.StorerKey = @cStorerKey
                       AND PD.SKU = @cSKU
                       AND ISNULL(LA.Lottable01,'') = @cBatchNo
                       AND PD.PickSlipNo = @cPickSlipNo
                  )
                  BEGIN
                     SET @nErrNo = 234161
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU/Batch does not exist in the scanned PS No
                     GOTO Quit
                  END

                  SELECT top 1 @cStatus = PD.status
                  FROM PickDetail PD WITH (NOLOCK)
                     JOIN LotAttribute LA(NOLOCK) ON (PD.LOT = LA.LOT)
                  WHERE PD.StorerKey = @cStorerKey
                     AND PD.SKU = @cSKU
                     AND ISNULL(LA.Lottable01,'') = @cBatchNo
                     AND PD.PickSlipNo = @cPickSlipNo
                     AND ISNULL(PD.caseid,'') = ''
                     AND PD.UOM = '2'
                     AND PD.qty > 0

                  IF @@ROWCOUNT < 1
                  BEGIN
                     SET @nErrNo = 234162
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Cases of SKU
                     GOTO Quit
                  END
                  IF @cStatus <> '5'
                  BEGIN
                     SET @nErrNo = 234163
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Case not in picked status
                     GOTO Quit
                  END

                  SELECT @nSum_PickDQty = SUM(PD.qty)
                  FROM PickDetail PD WITH (NOLOCK)
                          JOIN LotAttribute LA(NOLOCK) ON (PD.LOT = LA.LOT)
                  WHERE PD.StorerKey = @cStorerKey
                    AND PD.SKU = @cSKU
                    AND ISNULL(LA.Lottable01,'') = @cBatchNo
                    AND PD.PickSlipNo = @cPickSlipNo
                    AND PD.qty > 0

                  --CHECK Over Pick
                  SELECT @nSum_PackDQty = SUM(Packd.qty)
                  FROM PackDetail PackD
                     JOIN PICKDETAIL PD ON (
                        PD.CaseID = PACKD.LabelNo
                        AND PD.PickSlipNo = PackD.PickSlipNo
                        AND PD.SKU = PackD.SKU
                        AND PD.Storerkey = PackD.Storerkey
                     )
                     JOIN LotAttribute LA(NOLOCK) ON (PD.LOT = LA.LOT)
                  WHERE PD.StorerKey = @cStorerKey
                    AND PD.SKU = @cSKU
                    AND LA.Lottable01 = @cBatchNo
                    AND PD.PickSlipNo = @cPickSlipNo
                    AND PD.qty > 0
                  GROUP BY Packd.labelNO

                  SELECT @nCaseQty = Pack.CaseCNT
                  FROM dbo.SKU SKU WITH (NOLOCK)
                     INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
                  WHERE SKU.StorerKey = @cStorerKey
                     AND SKU.SKU = @cSKU

                  --Compare Qty
                  IF (@nSum_PickDQty - @nSum_PackDQty) < ( @nCaseQty* @cQty )
                  BEGIN
                     SET @nErrNo = 234164
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')--Case Qty is more than Picked
                     GOTO Quit
                  END
                  --CHECK Over Pick end

                  --Loop CNT, everytime split 1 case -> 1 line pickdetail -> 1 line packdetail
                  DECLARE @CurrentRow INT = 1
                  DECLARE @nQtyBalance INT

                  WHILE @CurrentRow <= @cQTY
                  BEGIN
                     --Each time confirm one case, qty = (1 * @nCaseQty)
                     SELECT top 1
                        @cPickDetailKey = PD.PickDetailKey,
                        @cFromDropID   = PD.DropID,
                        @nQtyBalance   = PD.qty
                     FROM PickDetail PD WITH (NOLOCK)
                             JOIN LotAttribute LA(NOLOCK) ON (PD.LOT = LA.LOT)
                     WHERE PD.StorerKey = @cStorerKey
                       AND PD.SKU = @cSKU
                       AND ISNULL(LA.Lottable01,'') = @cBatchNo
                       AND PD.PickSlipNo = @cPickSlipNo
                       AND ISNULL(PD.caseid,'') = ''    -- Not Packed
                       AND PD.UOM = '2'
                       AND PD.status = 5
                       AND PD.qty > 0
                     Order by PD.qty DESC

                     SET @nCartonNo = ''
                     SET @cLabelNo = ''
                     EXEC RDT.rdt_Pack_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
                        ,@cPickSlipNo    = @cPickSlipNo
                        ,@cFromDropID    = @cFromDropID
                        ,@cSKU           = @cSKU
                        ,@nQTY           = @nCaseQty
                        ,@cUCCNo         = ''
                        ,@cSerialNo      = '' -- @cSerialNo
                        ,@nSerialQTY     = 0  -- @nSerialQTY
                        ,@cPackDtlRefNo  = ''
                        ,@cPackDtlRefNo2 = ''
                        ,@cPackDtlUPC    = ''
                        ,@cPackDtlDropID = @cFromDropID
                        ,@nCartonNo      = @nCartonNo    OUTPUT
                        ,@cLabelNo       = @cLabelNo     OUTPUT
                        ,@nErrNo         = @nErrNo       OUTPUT
                        ,@cErrMsg        = @cErrMsg      OUTPUT
                        ,@nBulkSNO       = 0
                        ,@nBulkSNOQTY    = 0
                        ,@cPackData1     = ''
                        ,@cPackData2     = ''
                        ,@cPackData3     = ''
                     IF @nErrNo <> 0
                     BEGIN
                        --ROLLBACK
                        GOTO RollBackTran
                     END
                     --SPLIT PICK
                     DECLARE  @n_splitqty                INT = 0,
                              @c_newpickdetailkey        NVARCHAR(10)

                     SET @n_splitqty = @nQtyBalance - @nCaseQty

                     IF @n_splitqty > 0
                     BEGIN
                        EXECUTE nspg_GetKey
                                'PICKDETAILKEY',
                                10,
                                @c_newpickdetailkey OUTPUT,
                                @bSuccess OUTPUT,
                                @nErrNo OUTPUT,
                                @cErrMsg OUTPUT
                        IF NOT @bSuccess = 1
                        BEGIN
                           GOTO RollBackTran
                        END

                        INSERT PICKDETAIL
                        (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                         Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
                         DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                         ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                         WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, Channel_ID, TaskDetailKey
                        )
                        SELECT @c_newpickdetailkey,PICKDETAIL.CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                         Storerkey, Sku, AltSku, UOM,
                         (@n_splitqty / @nCaseQty), -- 1 case, uomqty = 1
                         @n_splitqty, QtyMoved, Status,
                         PICKDETAIL.DropId, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                         ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                         WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo, Channel_ID
                          , TaskDetailKey
                        FROM PICKDETAIL (NOLOCK)
                        WHERE PickdetailKey = @cPickDetailKey

                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 234165
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                           GOTO RollBackTran
                        END
                     END

                     UPDATE PICKDETAIL WITH (ROWLOCK)
                     SET PICKDETAIL.CaseID = @cLabelNo
                       ,Qty = @nCaseQty
                       ,UOMQTY = 1
                       ,TrafficCop = NULL
                     WHERE Pickdetailkey = @cPickDetailKey

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 234166
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                        GOTO RollBackTran
                     END

                     --DO PRINT
                     IF @cShipLabel <> ''
                     BEGIN
                        IF @cShipLabel = 'CstLabelSP'
                        BEGIN
                           SET @cCstLabelSP = rdt.RDTGetConfig( @nFunc, 'CstLabelSP', @cStorerKey)
                           IF @cCstLabelSP = '0'
                              SET @cCstLabelSP = ''
                           IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cCstLabelSP AND type = 'P')  --Customize Print Label
                           BEGIN
                              SET @cSQL = 'EXEC rdt.' + RTRIM( @cCstLabelSP) +
                                          ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, ' +
                                          ' @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption, ' +
                                          ' @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3, ' +
                                          ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
                              SET @cSQLParam =
                                      '@nMobile         INT,           ' +
                                      '@nFunc           INT,           ' +
                                      '@cLangCode       NVARCHAR( 3),  ' +
                                      '@nStep           INT,           ' +
                                      '@nInputKey       INT,           ' +
                                      '@cFacility       NVARCHAR( 5),  ' +
                                      '@cStorerKey      NVARCHAR( 15), ' +
                                      '@cPickSlipNo     NVARCHAR( 10), ' +
                                      '@cFromDropID     NVARCHAR( 20), ' +
                                      '@nCartonNo       INT,           ' +
                                      '@cLabelNo        NVARCHAR( 20), ' +
                                      '@cSKU            NVARCHAR( 20), ' +
                                      '@nQTY            INT,           ' +
                                      '@cUCCNo          NVARCHAR( 20), ' +
                                      '@cCartonType     NVARCHAR( 10), ' +
                                      '@cCube           NVARCHAR( 10), ' +
                                      '@cWeight         NVARCHAR( 10), ' +
                                      '@cRefNo          NVARCHAR( 20), ' +
                                      '@cSerialNo       NVARCHAR( 30), ' +
                                      '@nSerialQTY      INT,           ' +
                                      '@cOption         NVARCHAR( 1),  ' +
                                      '@cPackDtlRefNo   NVARCHAR( 20), ' +
                                      '@cPackDtlRefNo2  NVARCHAR( 20), ' +
                                      '@cPackDtlUPC     NVARCHAR( 30), ' +
                                      '@cPackDtlDropID  NVARCHAR( 20), ' +
                                      '@cPackData1      NVARCHAR( 30), ' +
                                      '@cPackData2      NVARCHAR( 30), ' +
                                      '@cPackData3      NVARCHAR( 30), ' +
                                      '@nErrNo          INT            OUTPUT, ' +
                                      '@cErrMsg         NVARCHAR( 20)  OUTPUT'

                              EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                                   @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID,
                                   @nCartonNo, @cLabelNo, @cSKU, @nQTY, @cUCCNo, @cCartonType, @cCube, @cWeight, @cRefNo, @cSerialNo, @nSerialQTY, @cOption,
                                   @cPackDtlRefNo, @cPackDtlRefNo2, @cPackDtlUPC, @cPackDtlDropID, @cPackData1, @cPackData2, @cPackData3,
                                   @nErrNo OUTPUT, @cErrMsg OUTPUT

                              IF @nErrNo <> 0
                                 GOTO RollBackTran
                           END
                        END
                        ELSE
                        BEGIN  --Standard Print
                           -- Common params
                           DELETE FROM @tShipLabel
                           INSERT INTO @tShipLabel (Variable, Value) VALUES
                              ( '@cStorerKey',     @cStorerKey),
                              ( '@cPickSlipNo',    @cPickSlipNo),
                              ( '@cFromDropID',    @cFromDropID),
                              ( '@cPackDtlDropID', @cPackDtlDropID),
                              ( '@cLabelNo',       @cLabelNo),
                              ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))

                           -- Print label
                           EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
                                @cShipLabel, -- Report type
                                @tShipLabel, -- Report params
                                'rdtfnc_Pack',
                                @nErrNo  OUTPUT,
                                @cErrMsg OUTPUT
                           IF @nErrNo <> 0
                              GOTO RollBackTran
                        END
                     END

                     SET @CurrentRow +=1
                  END
               END

               DECLARE @ckey2 Nvarchar(30)
               DECLARE @ckey3 Nvarchar(20)

               SET @ckey2 = LEFT(@cSKU + '+' + @cBatchNo,30)
               SET @ckey3 = IIF (@cID = '', @cQty, @cID)

               EXEC ispGenTransmitLog2
                    @c_TableName      = 'HILLSPLTPACK',
                    @c_Key1           = @cPickSlipNo,
                    @c_Key2           = @ckey2,
                    @c_Key3           = @ckey3,
                    @c_TransmitBatch  = '',
                    @b_Success        = @bSuccess    OUTPUT,
                    @n_err            = @nErrNo      OUTPUT,
                    @c_errmsg         = @cErrMsg     OUTPUT

               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 234167
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO RollBackTran
               END


               COMMIT TRAN rdt_838ExtScn05

               --GOTO confirm scn
               SET @nAfterStep = 99
               SET @nAfterScn = 6523

               GOTO Quit

            END

            IF @nInputKey = '0'
            BEGIN
               DECLARE  @cCustomNo           NVARCHAR( 5),
                        @cCustomID           NVARCHAR( 20),
                        @nCartonSKU          INT,
                        @nCartonQTY          INT,
                        @nTotalCarton        INT,
                        @nTotalPick          INT,
                        @nTotalPack          INT,
                        @nTotalShort         INT


               EXEC rdt.rdt_Pack_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEXT'
                  ,@cPickSlipNo
                  ,@cFromDropID
                  ,@cPackDtlDropID
                  ,@nCartonNo    OUTPUT
                  ,@cLabelNo     OUTPUT
                  ,@cCustomNo    OUTPUT
                  ,@cCustomID    OUTPUT
                  ,@nCartonSKU   OUTPUT
                  ,@nCartonQTY   OUTPUT
                  ,@nTotalCarton OUTPUT
                  ,@nTotalPick   OUTPUT
                  ,@nTotalPack   OUTPUT
                  ,@nTotalShort  OUTPUT
                  ,@nErrNo       OUTPUT
                  ,@cErrMsg      OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit

               -- Prepare next screen var
               SET @cOutField01 = @cPickSlipNo
               SET @cOutField02 = CAST( @nTotalPick AS NVARCHAR(8))  -- ZG02
               SET @cOutField03 = CAST( @nTotalPack AS NVARCHAR(8))  -- ZG02
               SET @cOutField04 = CAST( @nTotalShort AS NVARCHAR(8))  -- ZG02
               SET @cOutField05 = RTRIM( @cCustomNo) + '/' + CAST( @nTotalCarton AS NVARCHAR(5))
               SET @cOutField06 = @cCustomID
               SET @cOutField07 = CAST( @nCartonSKU AS NVARCHAR(5))
               SET @cOutField08 = CAST( @nCartonQTY AS NVARCHAR(5))
               SET @cOutField09 = @cDefaultOption -- Option

               -- Go to statistic screen
               SET @nAfterStep = 99
               SET @nAfterScn = 6521

            END

         End -- Scn6522 END

         IF @nScn = 6523
         BEGIN
            /********************************************************************************
            Step 99. scn = 6523. Message screen
               Message
            ********************************************************************************/

            SELECT
               @cScreenTitle= LEFT( RTRIM(Description), 20),
               @cParam1Label = UDF01,
               @cParam2Label = UDF02,
               @cParam3Label = UDF03,
               @cParam4Label = UDF04,
               @cParam5Label = UDF05
            FROM dbo.CodeLKUP WITH (NOLOCK)
            WHERE ListName = 'RDTCUSPACK'
              AND StorerKey = @cStorerKey

            -- Check report param setup
            IF @cParam1Label = '' AND
               @cParam2Label = '' AND
               @cParam3Label = '' AND
               @cParam4Label = '' AND
               @cParam5Label = ''
               BEGIN
                  SET @nErrNo = 234151
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CodeLkUp not found
                  GOTO Quit
               END

            -- Enable / disable field
            SET @cFieldAttr02 = CASE WHEN @cParam1Label = '' THEN 'O' ELSE '' END
            SET @cFieldAttr04 = CASE WHEN @cParam2Label = '' THEN 'O' ELSE '' END
            SET @cFieldAttr06 = CASE WHEN @cParam3Label = '' THEN 'O' ELSE '' END
            SET @cFieldAttr08 = CASE WHEN @cParam4Label = '' THEN 'O' ELSE '' END
            SET @cFieldAttr10 = CASE WHEN @cParam5Label = '' THEN 'O' ELSE '' END

            -- Clear optional in field
            SET @cInField02 = ''
            SET @cInField04 = ''
            SET @cInField06 = ''
            SET @cInField08 = ''
            SET @cInField10 = ''

            -- Prepare next screen var
            SET @cOutField01 = @cParam1Label
            SET @cOutField02 = ''
            SET @cOutField03 = @cParam2Label
            SET @cOutField04 = ''
            SET @cOutField05 = @cParam3Label
            SET @cOutField06 = ''
            SET @cOutField07 = @cParam4Label
            SET @cOutField08 = ''
            SET @cOutField09 = @cParam5Label
            SET @cOutField10 = ''
            SET @cOutField11 = @cScreenTitle

            -- Go to next screen
            SET @nAfterScn = 6522
            SET @nAfterStep = 99

            -- Set the focus on first enabled field
            IF @cFieldAttr02 = '' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE
            IF @cFieldAttr04 = '' EXEC rdt.rdtSetFocusField @nMobile, 4 ELSE
            IF @cFieldAttr06 = '' EXEC rdt.rdtSetFocusField @nMobile, 6 ELSE
            IF @cFieldAttr07 = '' EXEC rdt.rdtSetFocusField @nMobile, 8 ELSE
            IF @cFieldAttr10 = '' EXEC rdt.rdtSetFocusField @nMobile, 10

            GOTO Quit

         END

      END -- STEP 99
   END -- 838

   GOTO Quit

END

RollBackTran:
ROLLBACK TRAN rdt_838ExtScn05 -- Only rollback change made here
Quit:
WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
   COMMIT TRAN
   


GO