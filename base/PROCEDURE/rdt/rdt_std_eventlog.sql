SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_STD_EventLog                                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Standard Event Logging to Insert event into                 */
/*          RDT.RDT_STD_EventLog table                                  */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2009-Jun-29 1.0  Vicky       Created                                 */
/* 2010-May-04 1.1  Vicky       Fixes for TM that have Storerkey = ALL  */
/*                              when Sign in (Vicky01)                  */
/* 2010-Oct-23 1.2  TLTING      RowRef show 0 in first row              */
/* 2011-Aug-01 1.3  ChewKP      RDT EventLog Standardization (ChewKP01) */
/* 2012-Nov-19 1.4  James       Extend DropID length (james01)          */
/* 2014-May-16 1.5  Chee        Bug Fix - NULL value EventType (Chee01) */
/* 2015-JAN-23 1.6  CSCHONG     New lottable 06 to 15 (CS01)            */
/* 2018-Aug-30 1.7  ChewKP      WMS-6052- Add Column to RDT_STD_EventLog*/
/*                              (ChewKP02)                              */
/* 2018-Sep-12 1.8  Ung         WMS-6051 Add Status                     */
/* 2018-Sep-28 1.9  TungGH      Performance                             */
/* 2019-May-17 2.0  Ung         WMS-9003 Add EventNum OUTPUT            */
/* 2019-Oct-09 2.1  Chermaine   WMS-10777 Add Column (cc01)             */
/* 2019-Oct-22 2.2  Chermaine   WMS-10918 Add Column (cc02)             */
/* 2019-Nov-06 2.3  Chermaine   WMS-11031 Add Column (cc03)             */
/* 2020-Jan-17 2.4  Chermaine   WMS-11844 Add Column (cc04)             */
/* 2019-Oct-22 2.5  Ung         WMS-10638 Add CartonNo                  */
/* 2020-Dec-14 2.6  YeeKung     WMS-15895 Extend loc length (yeekung01) */
/* 2021-Aug-24 2.7  Ung         Use EventDateTime param                 */
/* 2023-Apr-14 2.8  Ung         WMS-22284 Add Cube                      */
/************************************************************************/

CREATE   PROC [RDT].[rdt_STD_EventLog] (
   @cActionType         NVARCHAR(30) = '',
   @dtEventDateTime     DATETIME = NULL,
   @cUserID             NVARCHAR(15) = '',
   @nMobileNo           INT,
   @nFunctionID         INT,
   @cFacility           NVARCHAR(5),
   @cStorerKey          NVARCHAR(15),
   @cLocation           NVARCHAR(30) = '', --(yeekung01)
   @cToLocation         NVARCHAR(10) = '',
   @cPutawayZone        NVARCHAR(10) = '',
   @cPickZone           NVARCHAR(10) = '',
   @cID                 NVARCHAR(18) = '',
   @cToID               NVARCHAR(18) = '',
   @cSKU                NVARCHAR(20) = '',
   @cComponentSKU       NVARCHAR(20) = '',
   @cUOM                NVARCHAR(10) = '',
   @nQTY                INT = 0,
   @cLot                NVARCHAR(10) = '',
   @cToLot              NVARCHAR(10) = '',
   @cLottable01         NVARCHAR(18) = '',
   @cLottable02         NVARCHAR(18) = '',
   @cLottable03         NVARCHAR(18) = '',
   @dLottable04         DATETIME = NULL,
   @dLottable05         DATETIME = NULL,
   @cLottable06         NVARCHAR(30) = '',      --(CS01)
   @cLottable07         NVARCHAR(30) = '',      --(CS01)
   @cLottable08         NVARCHAR(30) = '',      --(CS01)
   @cLottable09         NVARCHAR(30) = '',      --(CS01)
   @cLottable10         NVARCHAR(30) = '',      --(CS01)
   @cLottable11         NVARCHAR(30) = '',      --(CS01)
   @cLottable12         NVARCHAR(30) = '',      --(CS01)
   @dLottable13         DATETIME = NULL,        --(CS01)
   @dLottable14         DATETIME = NULL,        --(CS01)
   @dLottable15         DATETIME = NULL,        --(CS01)
   @cRefNo1             NVARCHAR(20) = '',
   @cRefNo2             NVARCHAR(20) = '',
   @cRefNo3             NVARCHAR(20) = '',
   @cRefNo4             NVARCHAR(20) = '',
   @cRefNo5             NVARCHAR(20) = '',
   @cReceiptKey         NVARCHAR(10) = '',    -- (ChewKP01)
   @cPOKey              NVARCHAR(10) = '',    -- (ChewKP01)
   @cLoadKey            NVARCHAR(10) = '',    -- (ChewKP01)
   @cOrderKey           NVARCHAR(10) = '',    -- (ChewKP01)
   @cPickSlipNo         NVARCHAR(10) = '',    -- (ChewKP01)
   @cDropID             NVARCHAR(20) = '',    -- (ChewKP01)/(james01)
   @cTaskDetailKey      NVARCHAR(10) = '',    -- (ChewKP01)
   @cCaseID             NVARCHAR(20) = '',    -- (ChewKP02)
   @cReasonKey          NVARCHAR(10) = '',    -- (ChewKP02)
   @cTaskType           NVARCHAR(10) = '',    -- (ChewKP02)
   @nExpectedQty        INT = 0,              -- (ChewKP02)
   @cOption             NVARCHAR(1)  = '',    -- (ChewKP02)
   @cSerialNo           NVARCHAR(50) = '',    -- (ChewKP02)
   @cPickMethod         NVARCHAR(10) = '',    -- (ChewKP02)
   @nStep               INT = 0,              -- (ChewKP02)
   @cStatus             NVARCHAR(10) = '',
   @cTrackingNo         NVARCHAR(30) = '',
   @cAreaKey            NVARCHAR(10) = '',
   @cTTMStrategyKey     NVARCHAR(10) = '',
   @cListKey            NVARCHAR(10) = '',
   @cUCC                NVARCHAR(20) = '',
   @cReplenishmentKey   NVARCHAR(10) = '',
   @cDeviceID           NVARCHAR(20) = '',
   @cDevicePosition     NVARCHAR(10) = '',
   @cToUCC              NVARCHAR(20) = '',
   @cSourceKey          NVARCHAR(20) = '',
   @cLabelNo            NVARCHAR(20) = '',
   @cCCKey              NVARCHAR(10) = '',
   @cSuggestedLOC       NVARCHAR(10) = '',
   @cWaveKey            NVARCHAR(10) = '',
   @cCartonType         NVARCHAR(10) = '',
   @fWeight             FLOAT = 0,
   @fCube               FLOAT = 0,
   @cPUOM_Desc          NVARCHAR( 5) = '',
   @cMUOM_Desc          NVARCHAR( 5) = '',
   @nPQTY               INT = 0,
   @cConsigneeKey       NVARCHAR(15) = '',
   @cCCSheetNo          NVARCHAR(10) = '',
   @cSealNo             NVARCHAR(20) = '',
   @cMBOLKey            NVARCHAR(10) = '',
   @cContainerNo        NVARCHAR(20) = '',
   @cLicenseNo          NVARCHAR(20) = '',
   @cTruckID            NVARCHAR(40) = '',
   @cRemark             NVARCHAR(20) = '',
   @cToLabelNo          NVARCHAR(20) = '',
   @cExternKitKey       NVARCHAR(20) = '',
   @cChildID            NVARCHAR(20) = '',
   @cLane               NVARCHAR(20) = '',
   @cSSCC               NVARCHAR(20) = '',
   @cSerialNoKey        NVARCHAR(10) = '',
   @nScn                INT = 0,
   @cReplenishmentGroup nvarchar(10) = '',   --(cc01)
   @fLength             FLOAT = 0,           --(cc01)
   @fWidth              FLOAT = 0,           --(cc01)
   @fHeight             FLOAT = 0,           --(cc01)
   @cOptionDefinition   NVARCHAR(50) = '',   --(cc01)
   @cTransType          NVARCHAR(128) = '',  --(cc01)
   @nCountNo            INT = 0,             --(cc02)
   @cCartonID           NVARCHAR(40) = '',   --(cc03)
   @cBarcode            NVARCHAR(100) = '',  --(cc03)
   @cContainerKey       NVARCHAR(20) = '',   --(cc04)
   @nCartonNo           INT = 0,
   @nEventNum           INT = 0 OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nEventType INT,
           @nLastEventNum INT,
           @nRowRef INT,
           @cLastRowRef INT,
           @cLastActionType NVARCHAR(30)

   SET @nEventType = 0 -- (Chee01)
   SELECT @nEventType = EventType
   FROM RDT.RDTMSG WITH (NOLOCK)
   WHERE Message_ID = @nFunctionID
   AND   Message_Type = 'FNC'

   IF ISNULL(@cUserID,'' ) = ''
   BEGIN
      SELECT @cUserID = UserName
      FROM rdt.rdtMobRec WITH (NOLOCK)
      WHERE Mobile = @nMobileNo
   END

  -- Search for EventNum to group
  SELECT TOP 1
    @cLastActionType = RTRIM(ActionType),
    @nLastEventNum = EventNum,
    @cLastRowRef = RowRef
  FROM RDT.rdtSTDEventLog WITH (NOLOCK)
  WHERE UserID = @cUserID
  AND MobileNo = @nMobileNo
  AND FunctionID = @nFunctionID
  AND StorerKey = @cStorerKey
  AND Facility = @cFacility
  AND EventType = @nEventType
  ORDER BY EventNum DESC

   IF (@cLastActionType = '1')
   BEGIN
      IF @cActionType > '1'
      BEGIN
         SELECT @nRowRef = @nLastEventNum
      END
      ELSE
      BEGIN
         SELECT @nRowRef = 0
      END
   END
   ELSE IF (@cLastActionType > '1' AND @cLastActionType < '9')
   BEGIN
      IF @cActionType > '1'
      BEGIN
         SELECT @nRowRef = @cLastRowRef
      END
      ELSE IF @cActionType = '1'
      BEGIN
         SELECT @nRowRef = 0
      END
   END
   ELSE IF (@cLastActionType = '9')
   BEGIN
      SELECT @nRowRef = 0
   END

   IF @dtEventDateTime IS NULL
      SET @dtEventDateTime = GETDATE()

   INSERT INTO RDT.rdtSTDEventLog (
      EventType,           ActionType,       EventDateTime,    UserID,           MobileNo,
      FunctionID,          Facility,         StorerKey,        Location,         ToLocation,
      PutawayZone,         PickZone,         ID,               ToID,             SKU,
      ComponentSKU,        UOM,              QTY,              Lot,              ToLot,
      Lottable01,          Lottable02,       Lottable03,       Lottable04,       Lottable05,
      Lottable06,          Lottable07,       Lottable08,       Lottable09,       Lottable10,
      Lottable11,          Lottable12,       Lottable13,       Lottable14,       Lottable15,
      RefNo1,              RefNo2,           RefNo3,           RefNo4,           RefNo5,
      ReceiptKey,          POKey,            LoadKey,          OrderKey,         PickSlipNo,
      DropID,              TaskDetailKey,
      CaseID,              ReasonKey,        Step,             TaskType,         ExpectedQty,
      RDTOption,           SerialNo,         PickMethod,       Status,           TrackingNo,
      AreaKey,             TTMStrategyKey,   ListKey,          UCC,
      ReplenishmentKey,    DeviceID,         DevicePosition,   ToUCC,
      SourceKey,           LabelNo,          CCKey,            SuggestedLOC,     WaveKey,
      PUOM_Desc,           MUOM_Desc,        PQTY,             ConsigneeKey,     CCSheetNo,
      SealNo,              MBOLKey,          ContainerNo,      LicenseNo,        TruckID,
      Remark,              ToLabelNo,        ExternKitKey,     ChildID,          Lane,
      SSCC,                SerialNoKey,      Scn,              CartonType,       Weight,
      RowRef,              Length,           Width,            Height,           ReplenishmentGroup,
      OptionDefinition,    TransType,        CountNo,          CartonID,         CartonNo,
      Barcode,             ContainerKey,     Cube)

   VALUES (
      @nEventType,         @cActionType,     @dtEventDateTime, @cUserID,         @nMobileNo,
      @nFunctionID,        @cFacility,       @cStorerKey,      @cLocation,       @cToLocation,
      @cPutawayZone,       @cPickZone,       @cID,             @cToID,           @cSKU,
      @cComponentSKU,      @cUOM,            @nQTY,            @cLot,            @cToLot,
      @cLottable01,        @cLottable02,     @cLottable03,     @dLottable04,     @dLottable05,
      @cLottable06,        @cLottable07,     @cLottable08,     @cLottable09,     @cLottable10,
      @cLottable11,        @cLottable12,     @dLottable13,     @dLottable14,     @dLottable15,
      @cRefNo1,            @cRefNo2,         @cRefNo3,         @cRefNo4,         @cRefNo5,
      @cReceiptKey,        @cPOKey,          @cLoadKey,        @cOrderKey,       @cPickSlipNo,
      @cDropID,            @cTaskDetailKey,
      @cCaseID,            @cReasonKey,      @nStep,           @cTaskType,       @nExpectedQty,
      @cOption,            @cSerialNo,       @cPickMethod,     @cStatus,         @cTrackingNo,
      @cAreaKey,           @cTTMStrategyKey, @cListKey,        @cUCC,
      @cReplenishmentKey,  @cDeviceID,       @cDevicePosition, @cToUCC,
      @cSourceKey,         @cLabelNo,        @cCCKey,          @cSuggestedLOC,   @cWaveKey,
      @cPUOM_Desc,         @cMUOM_Desc,      @nPQTY,           @cConsigneeKey,   @cCCSheetNo,
      @cSealNo,            @cMBOLKey,        @cContainerNo,    @cLicenseNo,      @cTruckID,
      @cRemark,            @cToLabelNo,      @cExternKitKey,   @cChildID,        @cLane,
      @cSSCC,              @cSerialNoKey,    @nScn,            @cCartonType,     @fWeight,
      @nRowRef,            @fLength,         @fWidth,          @fHeight,         @cReplenishmentGroup,
      @cOptionDefinition,  @cTransType,      @nCountNo,        @cCartonID,       @nCartonNo,
      @cBarcode,           @cContainerKey,   @fCube)

   SELECT @nEventNum = SCOPE_IDENTITY()
   IF ( @cActionType = '1' ) OR
      ( @cActionType not in ( '1', '9' ) AND ISNULL(@nRowRef, 0) = 0  )
   BEGIN
     UPDATE RDT.rdtSTDEventLog WITH (ROWLOCK)
       SET RowRef = @nEventNum
     WHERE EventNum = @nEventNum
   END

   IF @@ERROR <> 0
      GOTO Quit

Quit:

END

GO