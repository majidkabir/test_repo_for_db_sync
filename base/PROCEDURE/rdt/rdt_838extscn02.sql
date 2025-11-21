SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* Store procedure: rdt_838ExtScn02                                     */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2024-06-27 1.0  JACKC      FCR-392. Created                          */
/* 2024-10-24 1.1  JACKC      FCR-392 Enhancement Handel Extar 0s before*/ 
/*                               cartonID                               */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_838ExtScn02] (
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
   @cErrMsg            NVARCHAR( 20)  OUTPUT,
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
      --rdtmobrec
      @cUserName              NVARCHAR( 18),
      @nMenu                  INT,
      @bDebugFlag             BINARY = 0,
      @nMOBRECStep            INT,
      @nMOBRECScn             INT,
      
      --config variable
      @nRowCount              INT,
      @cExtendedUpdateSP      NVARCHAR( 20),
      @cExtendedValidateSP    NVARCHAR( 20),
      @cExtendedInfoSP        NVARCHAR( 20),

      --838 step1 required    riable
      @cLabelNo               NVARCHAR( 20),
      @cLoadKey               NVARCHAR( 10),
      @cOrderKey              NVARCHAR( 10),
      @cFlowThruScreen        NVARCHAR( 1),
      @cDefaultOption         NVARCHAR( 1),

      --variables saved to mobrec
      @cPickSlipNo            NVARCHAR( 10),
      @cPackDtlDropID         NVARCHAR( 20) = '',
      @cFromDropID            NVARCHAR( 20) = '',
      @cAutoScanIn            NVARCHAR( 1),
      @nCartonNo              INT,
      @nCartonSKU             INT,
      @nCartonQTY             INT,
      @nTotalCarton           INT,
      @nTotalPick             INT,
      @nTotalPack             INT,
      @nTotalShort            INT,
      @nPackedQTY             INT,
      @cCustomNo              NVARCHAR( 5),
      @cCustomID              NVARCHAR( 20),


      -- ExtScn required variable
      @cCartTrkLabelNo        NVARCHAR( 20),
  


      @cSKU                  NVARCHAR( 20),
      @cTaskDetailKey        NVARCHAR( 20),
      @cPreviousSKU          NVARCHAR( 20),
      @cPPAStatus            NVARCHAR( 1),
      @cReasonCode           NVARCHAR( 20),
      @cDisableQTYField      NVARCHAR( 1),
      @cPPADefaultQTY        NVARCHAR( 1),
      @cTaskDefaultQty       NVARCHAR( 1),
      @cTaskQty              NVARCHAR( 5),
      @cSQL                  NVARCHAR( MAX),
      @cSQLParam             NVARCHAR( MAX), 
      @nQTY                  INT,
      @nTotalCQty            INT,
      @nTotalPQty            INT,

      @cStatus               NVARCHAR( 1),
      @cPPADefaultPQTY       NVARCHAR( 1)
      

   DECLARE @tReturnData TABLE
   (
      Variable	   NVARCHAR(30),
      Value       NVARCHAR(100)
   )

   
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
 

   SELECT @nMOBRECStep     = Step,
      @nMOBRECScn          = Scn,
      @nMenu               = Menu,
      @cUserName           = UserName,
      @cFlowThruScreen     = V_String14,
      @cAutoScanIn         = V_String31,
      @cDefaultOption      = V_String32
   FROM rdt.RDTMOBREC WITH(NOLOCK)
   WHERE Mobile = @nMobile

   IF @nFunc = 838
   BEGIN
      --Generic ESC handling
      -- redirect to 1st new screen
      IF @nScn = 4650 AND @nStep = 1 AND @nAction = 0
      BEGIN
         SET @cOutField01 = ''
         SET @nAfterScn = 6385
         SET @nAfterStep = 99 
         GOTO Quit
      END-- generic esc handling
      IF @nMOBRECStep = 0
      BEGIN
         IF @nAction = 0 -- new screen
         BEGIN
            IF @nInputKey = 1 --Enter
            BEGIN
               SET @cOutField01 = '' -- CartNo
               EXEC rdt.rdtSetFocusField @nMobile, 1 --CartNo
               SET @nAfterScn = 6385
               SET @nAfterStep = 99
               GOTO Quit
            END
            ELSE IF @nInputKey = 0 --ESC
            BEGIN
               --Back to Menu
               -- EventLog
               EXEC RDT.rdt_STD_EventLog
                  @cActionType = '9', -- Sign-out
                  @cUserID     = @cUserName,
                  @nMobileNo   = @nMobile,
                  @nFunctionID = @nFunc,
                  @cFacility   = @cFacility,
                  @cStorerKey  = @cStorerKey,
                  @nStep       = @nStep

               -- Back to menu
               SET @nFunc = @nMenu
               SET @nScn  = @nMenu
               SET @nStep = 0
               SET @cOutField01 = '' -- Option


               GOTO Quit
            END --inputkey 0
         END -- action 0

         GOTO Quit
      END -- step 0
      ELSE IF @nMOBRECStep = 99
      BEGIN
         IF @nMOBRECScn = 6385 -- 1st step in 838 for LVSUSA
         /************************************************************************************
         Scn = 6385. Carton screen
            CartonNo    (field01, input)
         ************************************************************************************/
         BEGIN
            IF @nInputKey = 0
            BEGIN
               --Back to Menu
               -- EventLog
               EXEC RDT.rdt_STD_EventLog
                  @cActionType = '9', -- Sign-out
                  @cUserID     = @cUserName,
                  @nMobileNo   = @nMobile,
                  @nFunctionID = @nFunc,
                  @cFacility   = @cFacility,
                  @cStorerKey  = @cStorerKey,
                  @nStep       = @nStep

               -- Back to menu
               SET @nAfterScn  = @nMenu
               SET @nAfterStep = 0
               SET @cOutField01 = '' -- CartonNo
            END
            ELSE IF @nInputKey = 1 -- 
            BEGIN
               -- Screen mapping
               SET @cLabelNo = ''
               SET @cPickSlipNo = ''
               SET @nCartonNo = 0

               --V1.1 start
               --SET @cLabelNo = STUFF(@cInField01, 1, 2, '')
               SELECT @cLabelNo = CASE WHEN LEN(@cInField01) = 20 AND @cInField01 LIKE '00%'
                                    THEN STUFF(@cInField01,1,2,'')
                                    ELSE @cInField01
                                  END
               --V1.1 End
               
               -- Check blank
               IF @cLabelNo = ''
               BEGIN
                  SET @nErrNo = 217751
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedCarton
                  GOTO Quit
               END

               IF NOT EXISTS (SELECT 1 FROM PackDetail WITH (NOLOCK)
                           WHERE StorerKey = @cStorerKey
                              AND LabelNo = @cLabelNo
                           )
               BEGIN
                  -- Check if user scan the tracking no
                  SELECT  TOP 1 @cCartTrkLabelNo = LabelNo 
                  FROM CartonTrack WITH (NOLOCK)
                  WHERE TrackingNo = @cLabelNo
                     AND KeyName = @cStorerKey       

                  IF NOT EXISTS (SELECT 1 FROM PackDetail WITH (NOLOCK)
                                 WHERE StorerKey = @cStorerKey
                                    AND LabelNo = @cCartTrkLabelNo)             
                  BEGIN

                     SET @nErrNo = 217752
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartNotExist
                     GOTO Quit

                  END -- end not in CartonTrack
                  ELSE
                     SET @cLabelNo = @cCartTrkLabelNo -- retrieve label 
               END

               --Get and Validate Carton No
               SELECT @nCartonNo = CartonNo
               FROM PackDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND LabelNo = @cLabelNo

               IF @nCartonNo = 0
               BEGIN
                  SET @nErrNo = 217758
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartNotIs0
                  GOTO Quit
               END

               -- Get Labele info
               SET @cOrderKey = ''
               SELECT TOP 1
                  @cOrderKey = OrderKey
               FROM PickDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND CaseID = @cLabelNo
                  AND Status <= '5'

               -- Check LabelNo valid
               IF @@ROWCOUNT = 0
               BEGIN
                  SET @nErrNo = 217753
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidCart
                  GOTO Quit
               END

               -- Auto retrieve PickSlipNo
               IF @cPickSlipNo = ''
               BEGIN
                  -- Get discrete pick slip
                  SELECT @cPickSlipNo = PickHeaderKey
                  FROM PickHeader WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey

                  -- Get conso pick slip
                  IF @cPickSlipNo = ''
                  BEGIN
                     SET @cLoadKey = ''
                     SELECT @cLoadKey = LoadKey FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey

                     IF @cLoadKey <> ''
                        SELECT @cPickSlipNo = PickHeaderKey
                        FROM PickHeader WITH (NOLOCK)
                        WHERE ExternOrderKey = @cLoadKey
                           AND OrderKey = ''
                  END

                  -- Check PickHeader
                  IF @cPickSlipNo = ''
                  BEGIN
                     SET @nErrNo = 217754
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPSNo
                     GOTO Quit
                  END

                  SET @cOutField01 = @cPickSlipNo

               END

               -- Check PickSlipNo
               EXEC rdt.rdt_Pack_Validate @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'PICKSLIPNO'
                  ,@cPickSlipNo
                  ,'' --@cFromDropID
                  ,'' --@cPackDtlDropID
                  ,'' --@cSKU
                  ,0  --@nQTY
                  ,0  --@nCartonNo
                  ,@nErrNo  OUTPUT
                  ,@cErrMsg OUTPUT
               IF @nErrNo <> 0
               BEGIN
                  EXEC rdt.rdtSetFocusField @nMobile, 1  -- PickSlipNo
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPSNo
                  GOTO Quit
               END
               SET @cOutField01 = @cPickSlipNo

               --Since PickHeader is closed before packing, needs to reopen PackHeader
               UPDATE PackHeader SET Status = 0 WHERE PickSlipNo = @cPickSlipNo
               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 211759
                  EXEC rdt.rdtSetFocusField @nMobile, 1  -- PickSlipNo
                  SET @cOutField01 = ''
                  GOTO Quit
               END

               -- Get PickingInfo info
               DECLARE @dScanInDate DATETIME
               SELECT @dScanInDate = ScanInDate FROM PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo

               -- Check scan-in
               IF @dScanInDate IS NULL
               BEGIN
                  -- Auto scan-in
                  IF @cAutoScanIn = '1'
                  BEGIN
                     IF NOT EXISTS( SELECT 1 FROM PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
                     BEGIN
                        INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID)
                        VALUES (@cPickSlipNo, GETDATE(), @cUserName)
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 217755
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan-In Fail
                           GOTO Quit
                        END
                     END
                     ELSE
                     BEGIN
                        UPDATE dbo.PickingInfo SET
                           ScanInDate = GETDATE(),
                           PickerID = SUSER_SNAME(),
                           EditWho = SUSER_SNAME()
                        WHERE PickSlipNo = @cPickSlipNo
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 217756
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan-In Fail
                           GOTO Quit
                        END
                     END
                  END
                  ELSE
                  BEGIN
                     SET @nErrNo = 217757
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not Scan-In
                     GOTO Quit
                  END
               END

               --Pass LabelNo, CartonNo to screen 2
               --SET @nCartonNo    = 0
               --SET @cLabelNo     = ''
               SET @cCustomNo    = ''
               SET @cCustomID    = ''
               SET @nCartonSKU   = 0
               SET @nCartonQTY   = 0
               SET @nTotalCarton = 0
               SET @nTotalPick   = 0
               SET @nTotalPack   = 0
               SET @nTotalShort  = 0

               -- Get task
               EXEC rdt.rdt_Pack_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'CURRENT'
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
               SET @cOutField09 = @cDefaultOption

               /*IF EXISTS( SELECT 1 FROM STRING_SPLIT( @cFlowThruScreen, ',') WHERE TRIM( value) = '2') -- Statistic screen 
               BEGIN
                  SET @cInField09 = '1' -- Option
                  SET @nScn = @nScn + 1
                  SET @nStep = @nStep + 1
                  GOTO Step_2
               END*/

               -- Go to 838 2nd step
               SET @nAfterScn = 4651
               SET @nAfterStep = 2

               --Return values to 838 main process
               SET @cUDF01 =  @cPickslipNo
               SET @cUDF02 =  @cFromDropID     
               SET @cUDF03 =  @cPackDtlDropID
               SET @cUDF04 =  CAST(@nCartonNo AS NVARCHAR(10))  
               SET @cUDF05 =  @cLabelNo  
               SET @cUDF06 =  @cCustomNo   
               SET @cUDF07 =  @cCustomID   
               SET @cUDF08 =  CAST(@nCartonSKU AS NVARCHAR(10)) 
               SET @cUDF09 =  CAST(@nCartonQTY AS NVARCHAR(10))  
               SET @cUDF10 =  CAST(@nTotalCarton AS NVARCHAR(10))
               SET @cUDF11 =  CAST(@nTotalPick AS NVARCHAR(10))  
               SET @cUDF12 =  CAST(@nTotalPack AS NVARCHAR(10))  
               SET @cUDF13 =  CAST(@nTotalShort AS NVARCHAR(10))     

            END -- Inputkey 1

            GOTO Quit
         END -- SCN 6385
      END -- STEP 99
   END -- 838

   GOTO Quit

Quit:
   
END

GO