SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/
/* Store procedure: rdt.rdtfnc_PTS_Store_Sort                                */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#175741 - PTS Store Sort                                      */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2010-06-16 1.0  KHLim    Created                                          */
/* 2010-07-20 1.1  James    Reset Variables and add error when Store not     */
/*                          found (james01)                                  */
/* 2010-07-21 1.2  James    Bug fix (james02)                                */
/* 2010-07-22 1.3  Vicky    To cater Paper Printer since printing both Label */
/*                          and Paper Report (Vicky01)                       */
/* 2010-07-24 1.4  Vicky    - Fix status and TargetDB field length           */
/*                          - Release PA task with Status = W (Vicky02)      */
/* 2010-07-26 1.5  James    Correction on OrderKey retrieval (james03)       */
/* 2010-07-29 1.6  James    Put in Qty for eventlog (james04)                */
/* 2010-08-06 1.7  James    Bug fix on print flag update (james05)           */
/* 2010-08-09 1.8  Vicky    Bug Fix - Should not process by Orderkey         */
/*                          (Vicky03)                                        */
/* 2010-08-10 1.9  Vicky    Remove Option default value (Vicky04)            */
/* 2010-08-13 2.0  Vicky    Add Validation on ToTote scan to prevent         */
/*                          scanning to other Store (Vicky05)                */
/* 2010-08-15 2.1  Shong    Add new screen for user to enter PutawayZone     */
/*                          (Shong01)                                        */
/* 2010-08-16 2.2  James    Add new screen to cater for Store Piece Pick     */
/*                          (james06)                                        */
/* 2010-08-16 2.2  Shong    Fixing Packdetail Insertion Issues (Shong02)     */
/* 2010-08-17 2.3  Vicky    Allow scanning to multi PTS Loc (Vicky06)        */
/* 2010-08-23 2.4  Shong    Fix Wrong PTS Location show in Step 10 (Shong03) */
/* 2010-08-23 2.5  Shong    Do not Stop the process if Just Printer Setup    */
/*                          in Close Tote Screen. Check Paper Printer at 1st */
/*                          Screen                                           */
/* 2010-08-27 2.6  James    Put in ConsigneeKey in event_log (james07)       */
/* 2010-08-28 2.7  James    Validate DropLoc cannot be null                  */
/*                          CaseID/ToteNo must be numeric (james08)          */
/* 2010-09-03 2.8  James    Release PA task when all picks in same caseid    */
/*                          have status > 3 (james09)                        */
/* 2010-09-04 2.9  James    PTS only cater for UPC/SKU onlu (james10)        */
/* 2010-09-05 3.0  James    To Tote no only accept numeric (james11)         */
/* 2010-09-12 3.1  James    Prevent PA task to be released too early(james12)*/
/* 2010-09-12 3.2  James    Check for tote closed (james13)                  */
/* 2010-09-15 3.3  James    Prevent ECOMM Tote to be scanned (james14)       */
/* 2010-09-16 3.4  ChewKP   Shall check if Tote is Short Pick or not         */
/*                          (ChewKP01)                                       */
/* 2010-09-21 3.5  James    Prompt CASE EMPTY msg when it is empty (james15) */
/* 2010-09-23 3.6  James    Release tote when it is shipped (james16)        */
/* 2010-09-25 3.7  James    Not allow 0 qty to be entered (james17)          */
/* 2010-10-08 3.8  James    Not allow to scan tote if is case pick (james18) */
/* 2010-10-14 3.9  Shong    Tote Closed Checking should filter by status < 9 */
/* 2010-10-21 4.0  James    Default action @ ToTote screen 'DefaultPTSAction'*/
/*                          Filter by putawayzone when getting task (james19)*/
/*                          Sort by LogicalLoc, Loc, ConsigneeKey            */
/* 2010-10-26 4.1  James    Allow to change printer at PZone screen (james20)*/
/*                          Restrict length of tote no using RDT configkey   */
/*                          'DefaultToteLength'                              */
/*                          Prompt warning screen if user try to open a new  */
/*                          tote while there exists open tote in same loc    */
/* 2010-10-28 4.2  James    Print tote label even if short pick (james21)    */
/* 2011-03-02 4.3  James    SOS206173 - Enhancement (james22)                */
/* 2011-06-22 4.4  James    SOS218836 - Bug fix on PTS loc display (james23) */
/* 2011-10-05 4.5  James    SOS215850 - Not to default PTS action (james24)  */
/* 2011-10-18 4.6  SPChin   SOS# 227916 - Add PickDet_Log for data logging   */
/* 2011-10-21 4.7  Leong    SOS# 228674 - Reset V_String32 & V_String34      */
/*                                        values to blank                    */
/* 2011-12-08 4.8  Shong    Revise Standard Event Log to Log Total Time Pack */
/*                          For Carton Include Open/Close Tote               */
/* 2012-03-16 4.9  ChewKP   Enable Event Log when ESC from Functions         */
/*                          (ChewKP02)                                       */
/* 2012-06-28 5.0  TLTING   Remove Pickdet_log logging (4.6)                 */
/* 2014-05-29 5.1  James    SOS312211 - Add to tote len validation (james25) */
/* 2014-06-24 5.2  James    SOS314028 - Close tote if all items have been    */
/*                          picked out of a tote (james25)                   */
/* 2014-07-21 5.3  James    SOS316219 - Extend the length of case id & Tote  */
/*                          no to 10 chars (james26)                         */
/* 2014-08-14 5.4  James    SOS316568 - Add extended printing (james27)      */
/* 2014-09-01 5.5  James    Add extended validation (james28)                */
/* 2014-09-16 5.6  James    Release tote after close tote (james29)          */
/* 2014-10-10 5.7  James    Update closed tote to release prev tote (james30)*/
/* 2015-07-08 5.8  James    SOS332896-Release PA task using config (james31) */
/* 2016-09-30 5.9  Ung      Performance tuning                               */
/* 2018-11-08 6.0  Gan      Performance tuning                               */
/* 2020-10-27 6.1  YeeKung  Change Alter to Create                           */
/*****************************************************************************/

CREATE PROC [RDT].[rdtfnc_PTS_Store_Sort](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @b_success           INT

-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),
   @cPrinter            NVARCHAR(10),
   @cPrinter_Paper      NVARCHAR(10), -- (Vicky01)
   @cUserName           NVARCHAR(18),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cConsigneekey       NVARCHAR(15),
   @cLOT                NVARCHAR(10),
   @cLOC                NVARCHAR(10),
   @cFromLOC            NVARCHAR(10),
   @cID                 NVARCHAR(18),
   @cLOCscan            NVARCHAR(10),
   @cOrderKey           NVARCHAR(10),
   @cCaseID             NVARCHAR(18),
   @cToteNo             NVARCHAR(18),
   @cToToteNo           NVARCHAR(18),
   @cSKU                NVARCHAR( 20),
   @cSKUDescr           NVARCHAR( 60),
   @cSKUscan            NVARCHAR( 20),
   @cParentSKU          NVARCHAR( 20),
   @cLabelNo            NVARCHAR( 20),
   @cSkuPackkey         NVARCHAR( 10),
   @cOrderKeyToPrint    NVARCHAR( 10),
   @cQTY                NVARCHAR( 5),
   @cUOM                NVARCHAR( 5),
   @cOption             NVARCHAR( 1),
   @cUPC                NVARCHAR( 20),
   @cPickSlipNo         NVARCHAR( 10),
   @cLabelLine          NVARCHAR( 5),
   @cReasonCode         NVARCHAR( 5),
   @cLoadKey            NVARCHAR( 10),
   @cWaveKey            NVARCHAR( 10),
   @cModuleName         NVARCHAR( 45),
   @cReportType         NVARCHAR( 10),
   @cPrintJobName       NVARCHAR( 50),
   @cDataWindow         NVARCHAR( 50),
   @cTargetDB           NVARCHAR( 20), -- (Vicky02)
   @cPickDetailKey      NVARCHAR( 10),
   @cPackkey            NVARCHAR( 10),
   @cTaksDetailKey      NVARCHAR( 10),
   @cWCSKey             NVARCHAR( 10),
   @cPOrderKey          NVARCHAR( 10),  --(james03)
   @cNewPickDetailKey   NVARCHAR( 10),  --(james03)
   @c_errmsg            NVARCHAR( 250),
   @cSuggestQTY         NVARCHAR( 5),
   @cPDOrderkey         NVARCHAR( 10), -- (Vicky01)
   @cPDPickSlipNo       NVARCHAR( 10), -- (Vicky01)
   @cPutawayZone        NVARCHAR(10), --(Shong01)
   @cPTS_LOC            NVARCHAR(10), --(james06)
   @cSuggPTSLoc         NVARCHAR(10), -- (Vicky06)
   @cNextPTSLoc         NVARCHAR(10), -- (Vicky06)
   @cDefaultPTSAction   NVARCHAR( 1), -- (james19)
   @cDefaultToteLength  NVARCHAR( 2), -- (james20)
   @cPZ_PaperPrinter    NVARCHAR( 10), -- (james20)
   @cPZ_LabelPrinter    NVARCHAR( 10), -- (james20)
   @cAlertMessage       NVARCHAR( 255),       -- (james22)

   @bSuccess            INT,              -- (james22)
   @nQTY                INT,
   @nQtySuggest         INT,
   @nTotal_QTY          INT,
   @nCase_QTY           INT,
   @nTote_QTY           INT,
   @nRemain_Qty         INT,
   @nCurScn             INT,
   @nCurStep            INT,
   @nSumBOMQTY          INT,
   @nSkuCaseCnt         INT,
   @nPickedQty          INT,
   @nSumPackQTY         INT,  --(james03)
   @nSumPickQTY         INT,  --(james03)
   @nQty2Moved          INT,  --(james03)
   @n_err               INT,
   @nCartonNo           INT,  -- (Shong02)
   @nCaseEmpty          INT,
   @nTotPick            INT,  -- (SHONGxx)
   @nTotPack            INT,  -- (SHONGxx)
   @cEscKey             NVARCHAR(1),  -- (ChewKP02)
   @cDropID2Close       NVARCHAR(20), -- (james25)
   @cDefaultToToteLength   NVARCHAR( 2),  -- (james25)
   @cExtendedPrintSP    NVARCHAR( 20),    -- (james27)
   @cSQL                NVARCHAR(MAX),    -- (james27)
   @cSQLParam           NVARCHAR(MAX),    -- (james27)
   @cExtendedUpdateSP   NVARCHAR( 20),    -- (james27)
   @cExtendedValidateSP NVARCHAR( 20),    -- (james28)
   @cCaseID_New         NVARCHAR( 20),    -- (james30)
   @nNextCaseIDSeqNo    INT,              -- (james30)



   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),

   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),
   @cFieldAttr15 NVARCHAR( 1),
   @cV_String32  NVARCHAR(20), @cV_String34  NVARCHAR(20) -- SOS# 228674

SET @cV_String32 = '' -- SOS# 228674
SET @cV_String34 = '' -- SOS# 228674

-- Getting Mobile information
SELECT
   @nFunc              = Func,
   @nScn               = Scn,
   @nStep              = Step,
   @nInputKey          = InputKey,
   @cLangCode          = Lang_code,
   @nMenu              = Menu,

   @cFacility          = Facility,
   @cStorerKey         = StorerKey,
   @cPrinter           = Printer,
   @cPrinter_Paper     = Printer_Paper, -- (Vicky01)
   @cUserName          = UserName,

   @nQTY               = V_Integer1,
   @nQtySuggest        = V_Integer2,
   @nSumBOMQTY         = V_Integer3,
   @nCurScn            = V_Integer4,
   @nCurStep           = V_Integer5,

   @cCaseID            = V_CaseID,
   @cConsigneekey      = V_ConsigneeKey,
   @cLOC               = V_Loc,
   @cOrderKey          = V_OrderKey,
   @cSKU               = V_SKU,
   @cSKUDescr          = V_SKUDescr,
  -- @nQTY               = CASE WHEN rdt.rdtIsValidQTY(LEFT(V_QTY, 5), 0) = 1 THEN LEFT(V_QTY, 5) ELSE 0 END,
   @cUOM               = V_UOM,
   @cOption            = V_String1,
   @cSKUscan           = V_String2,
  -- @nQtySuggest        = CASE WHEN rdt.rdtIsValidQTY(LEFT(V_String3, 5), 0) = 1 THEN LEFT(V_String3, 5) ELSE 0 END,
  -- @nSumBOMQTY         = CASE WHEN rdt.rdtIsValidQTY(LEFT(V_String4, 5), 0) = 1 THEN LEFT(V_String4, 5) ELSE 0 END,
   @cLOCscan           = V_String5,
   @cToteNo            = V_String6,
  -- @nCurScn            = CASE WHEN rdt.rdtIsValidQTY(LEFT(V_String7, 5), 0) = 1 THEN LEFT(V_String7, 5) ELSE 0 END,
  -- @nCurStep           = CASE WHEN rdt.rdtIsValidQTY(LEFT(V_String8, 5), 0) = 1 THEN LEFT(V_String8, 5) ELSE 0 END,
   @cToToteNo          = V_String9,
   @cPutawayZone       = V_Zone, -- (Shong01)
   @cSuggPTSLoc        = V_String10, -- (Vicky06)
   @cNextPTSLoc        = V_String11, -- (Vicky06)
   @cDefaultPTSAction  = V_String12, -- (james19)
   @cDefaultToteLength = V_String13, -- (james20)
   @cEscKey            = V_String14, -- (ChewKP02)

   @cV_String32        = V_String32, -- SOS# 228674
   @cV_String34        = V_String34, -- SOS# 228674

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,

   @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15

FROM   RDT.RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_Case      INT, @nScn_Case    INT,
   @nStep_Sku       INT, @nScn_Sku     INT,
   @nStep_Loc       INT, @nScn_Loc     INT,
   @nStep_Qty       INT, @nScn_Qty     INT,
   @nStep_ToTote    INT, @nScn_ToTote  INT,
   @nStep_CloseTote INT, @nScn_NewTote INT,
   @nStep_Print     INT, @nScn_Print   INT,
   @nStep_ShortPick INT, @nScn_ShortPick INT,
   @nStep_PTZone    INT, @nScn_PTZone  INT,
   @nStep_PPATOLOC  INT, @nScn_PPATOLOC INT,
   @nStep_OpenTote  INT, @nScn_OpenTote INT,
   @nStep_ConfirmTote  INT, @nScn_ConfirmTote INT

SELECT
   @nStep_Case      = 1, @nScn_Case    = 2390,
   @nStep_Sku       = 2, @nScn_Sku     = 2391,
   @nStep_Loc       = 3, @nScn_Loc     = 2392,
   @nStep_Qty       = 4, @nScn_Qty     = 2393,
   @nStep_ToTote    = 5, @nScn_ToTote  = 2394,
   @nStep_CloseTote = 6, @nScn_NewTote = 2395,
   @nStep_Print     = 7, @nScn_Print   = 2396,
   @nStep_ShortPick = 8, @nScn_ShortPick = 2010,
   @nStep_PTZone    = 9, @nScn_PTZone = 2397,
   @nStep_PPATOLOC  = 10, @nScn_PPATOLOC = 2398,
   @nStep_OpenTote  = 11, @nScn_OpenTote = 2399,
   @nStep_ConfirmTote  = 12, @nScn_ConfirmTote = 2700

-- Redirect to respective screen
IF @nFunc = 1711
BEGIN
   IF @nStep = 0 GOTO Step_Start   -- Menu. Func = 1711
   IF @nStep = 1 GOTO Step_Case    -- Scn = 2390  Case/Tote
   IF @nStep = 2 GOTO Step_Sku     -- Scn = 2391  Sku
   IF @nStep = 3 GOTO Step_Loc   -- Scn = 2392  Loc
   IF @nStep = 4 GOTO Step_Qty     -- Scn = 2393  Qty
   IF @nStep = 5 GOTO Step_ToTote  -- Scn = 2394  To Tote
   IF @nStep = 6 GOTO Step_CloseTote -- Scn = 2395  New Tote
   IF @nStep = 7 GOTO Step_Print   -- Scn = 2396  Print
   IF @nStep = 8 GOTO Step_ShortPick   -- Scn = 1890  STD Short Pick
   IF @nStep = 9 GOTO Step_PTZone  -- Scn = 2397  Putaway-Zone
   IF @nStep = 10 GOTO Step_PPATOLOC  -- Scn = 2398  PPA TO LOC
   IF @nStep = 11 GOTO Step_OpenTote  -- Scn = 2399  Open New Tote
   IF @nStep = 12 GOTO Step_ConfirmTote  -- Scn = 2700  Confirm Tote is correct
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1711)
********************************************************************************/
Step_Start:
BEGIN
   -- Set the entry point
   --SET @nScn  = @nScn_Case
   --SET @nStep = @nStep_Case
   SET @nScn  = @nScn_PTZone
   SET @nStep = @nStep_PTZone

   -- Get the default option in to tote screen
   SET @cDefaultPTSAction  = rdt.RDTGetConfig( @nFunc, 'DefaultPTSAction', @cStorerKey)
   IF ISNULL(@cDefaultPTSAction, '') NOT IN ('1', '9')
   BEGIN
      SET @cDefaultPTSAction = ''
   END

   -- Get the default length of tote no
   SET @cDefaultToteLength  = rdt.RDTGetConfig( @nFunc, 'DefaultToteLength', @cStorerKey)
   IF ISNULL(@cDefaultToteLength, '') = ''
   BEGIN
      SET @cDefaultToteLength = '8'  -- make it default to 8 digit if not setup
   END

   -- initialise all variable
   SET @cConsigneekey = ''
   SET @cCaseID       = ''
   SET @cToteNo       = ''
   SET @cLOC          = ''
   SET @cSKU          = ''
   SET @cQTY          = ''
   SET @cUOM      = ''
   SET @cOption       = ''

   -- (Vicky06) - Start
   SET @cSuggPTSLOC   = ''
   SET @cNextPTSLOC   = ''
   SET @cCaseID       = ''
   SET @cToteNo       = ''
   SET @cPutawayZone  = ''
   SET @cOrderKey     = ''
   SET @cSKUDescr     = ''
   SET @cSKUscan      = ''
   SET @cLOCscan      = ''
   SET @nCurScn       = 0
   SET @nCurStep      = 0
   SET @nQTY          = 0
   SET @nQtySuggest   = 0
   SET @nSumBOMQTY    = 0
   SET @cEscKey       = '0'
   -- (Vicky06) - End


   -- Init screen
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''
   SET @cOutField04 = ''
   SET @cOutField05 = ''
   SET @cOutField06 = ''
   SET @cOutField07 = ''
   SET @cOutField08 = ''
   SET @cOutField09 = ''
   SET @cOutField10 = ''
   SET @cOutField11 = ''
END
GOTO Quit

/********************************************************************************
Step 1. screen = 2390
   CASE ID (Field01, input)
   TOTE NO (Field02, input)
********************************************************************************/
Step_Case:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cCaseID = SUBSTRING(@cInField01, 1, 8)  -- Take the first 8 characters only
      SET @cToteNo = @cInField02

      -- Validate blank
      IF ISNULL(@cCaseID, '') = '' AND ISNULL(@cToteNo, '') = ''
      BEGIN
         SET @nErrNo = 69816
         SET @cErrMsg = rdt.rdtgetmessage( 69816, @cLangCode, 'DSP') --CASE/TOTE req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_Case_Fail
      END

      IF ISNULL(@cCaseID, '') <> '' AND ISNULL(@cToteNo, '') <> ''
      BEGIN
         SET @nErrNo = 69817
         SET @cErrMsg = rdt.rdtgetmessage( 69817, @cLangCode, 'DSP') --CASE/TOTE ONLY
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_Case_Fail
      END

      -- Case ID scanned
      IF ISNULL(@cCaseID, '') <> '' AND ISNULL(@cToteNo, '') = ''
      BEGIN
         -- (james08)
         IF ISNUMERIC(@cCaseID) = 0
         BEGIN
            SET @nErrNo = 70602
            SET @cErrMsg = rdt.rdtgetmessage( 70602, @cLangCode, 'DSP') --INVALID CASEID
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_Case_Fail
         END

         IF NOT EXISTS (SELECT 1 FROM dbo.DROPIDDETAIL  WITH (NOLOCK)
                        JOIN dbo.DROPID WITH (NOLOCK) ON DROPIDDETAIL.Dropid = DROPID.Dropid
                        WHERE ChildID = @cCaseID)-- AND Status = '5') (james19)
         BEGIN
            SET @nErrNo = 69818
            SET @cErrMsg = rdt.rdtgetmessage( 69818, @cLangCode, 'DSP') --INVALID CASEID
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_Case_Fail
         END

         IF NOT EXISTS (SELECT 1 FROM TaskDetail TD WITH (NOLOCK)
                        JOIN dbo.UCC UCC WITH (NOLOCK) ON TD.TaskDetailKey = UCC.SourceKey
                        WHERE TD.StorerKey = @cStorerKey
                           AND TD.Status NOT IN ('X')  -- SHONGxx
                           AND UCC.UCCNo = @cCaseID)
         BEGIN
            SET @nErrNo = 70604
            SET @cErrMsg = rdt.rdtgetmessage( 70604, @cLangCode, 'DSP') --INVALID CASEID
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_Case_Fail
         END
         IF( SELECT MAX(STATUS)
             FROM dbo.PICKDETAIL  WITH (NOLOCK)
             WHERE CaseID = @cCaseID
                AND StorerKey = @cStorerkey
             GROUP BY CaseID
             HAVING COUNT(DISTINCT [Status]) = 1) = '5'
         BEGIN
            SET @nErrNo = 70591
            SET @cErrMsg = rdt.rdtgetmessage( 70591, @cLangCode, 'DSP') --Order Picked
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_Case_Fail
         END

--         Comment out because the orders among the same case id can be shipped individually                --         IF EXISTS (SELECT 1 FROM dbo.PICKDETAIL  WITH (NOLOCK)
--                    WHERE CaseID = @cCaseID AND Status = '9' AND StorerKey = @cStorerkey)
--         BEGIN
--            SET @nErrNo = 69819
--            SET @cErrMsg = rdt.rdtgetmessage( 69819, @cLangCode, 'DSP') --Order Shipped
--            EXEC rdt.rdtSetFocusField @nMobile, 1
--            GOTO Step_Case_Fail
--         END

         -- Update WCSRouting table
         BEGIN TRAN

         UPDATE dbo.WCSRouting WITH (ROWLOCK) SET
            Status = '9'
         WHERE ToteNo = @cCaseID
            AND TaskType = 'PK'
            --AND Status > '0' -- Comment by (Vicky02)
            AND Status < '9'

         IF @@ERROR <> 0 --OR @@ROWCOUNT = 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 69820
            SET @cErrMsg = rdt.rdtgetmessage( 69820, @cLangCode, 'DSP') --UPD WCS FAIL
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_Case_Fail
         END

         UPDATE WCSRD WITH (ROWLOCK) SET
            WCSRD.Status = '9'
         FROM dbo.WCSRouting WCSR
         JOIN dbo.WCSRoutingDetail WCSRD ON (WCSR.WCSKey = WCSRD.WCSKey)
         WHERE WCSR.ToteNo = @cCaseID
            AND WCSR.TaskType = 'PK'
          -- AND WCSRD.Status > '0' -- Comment by (Vicky02)
            AND WCSRD.Status < '9'

         IF @@ERROR <> 0 --OR @@ROWCOUNT = 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 69821
            SET @cErrMsg = rdt.rdtgetmessage( 69821, @cLangCode, 'DSP') --UPDATE WCSDET FAIL
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_Case_Fail
         END

         COMMIT TRAN

         IF NOT EXISTS (SELECT 1 FROM dbo.UCC WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND UCCNo = @cCaseID)
         BEGIN
            SET @nErrNo = 70592
            SET @cErrMsg = rdt.rdtgetmessage( 70592, @cLangCode, 'DSP') --CaseNotExists
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_Case_Fail
         END

         IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                    JOIN dbo.LOC LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
                    WHERE PD.StorerKey = @cStorerKey
                    AND   PD.CASEID = @cCaseID
                    AND   LOC.Putawayzone = @cPutawayZone)
         BEGIN
            SET @nErrNo = 70613
            SET @cErrMsg = rdt.rdtgetmessage( 70613, @cLangCode, 'DSP') --Wrong PTS Zone
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_Case_Fail
         END


         SELECT TOP 1
                @cOrderKey  = PICKDETAIL.OrderKey,
                @cSKU       = PICKDETAIL.Sku,
                @cSKUDescr  = SKU.DESCR,
                @cLoc       = PICKDETAIL.Loc    -- (jamesxx)
         FROM dbo.PICKDETAIL WITH (NOLOCK)
         JOIN dbo.ORDERS WITH (NOLOCK) -- (james19)
              ON PICKDETAIL.StorerKey = ORDERS.StorerKey AND PICKDETAIL.OrderKey = ORDERS.OrderKey
         JOIN dbo.LOC WITH (NOLOCK) ON PICKDETAIL.LOC = LOC.LOC -- (james19)
         JOIN dbo.SKU WITH (NOLOCK)
              ON PICKDETAIL.StorerKey = SKU.StorerKey AND PICKDETAIL.Sku = SKU.Sku
         WHERE PICKDETAIL.CaseID = @cCaseID
            AND PICKDETAIL.Storerkey = @cStorerKey
            AND PICKDETAIL.Status = '3'
            AND LOC.PUTAWAYZONE = @cPutawayZone -- (james19)
         ORDER BY LOC.LogicalLocation, LOC.LOC, ORDERS.ConsigneeKey

         SELECT @nTotal_QTY = ISNULL(SUM(Qty), 0)
         FROM dbo.UCC WITH (NOLOCK)
         WHERE UCCNo = @cCaseID
            AND Storerkey = @cStorerKey
            AND SKU = @cSKU
         --   AND OrderKey = @cOrderKey   -- (Vicky03)

         IF @nTotal_QTY = 0
         BEGIN
            SET @nErrNo = 70523
            SET @cErrMsg = rdt.rdtgetmessage( 70523, @cLangCode, 'DSP') --Inv Case Qty
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_Case_Fail
         END

         SELECT @nRemain_Qty = ISNULL(SUM(Qty), 0)
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE CaseID = @cCaseID
            AND Storerkey = @cStorerKey
            AND Status = '3'

         IF @nRemain_Qty = 0
         BEGIN
            SET @nErrNo = 70524
            SET @cErrMsg = rdt.rdtgetmessage( 70524, @cLangCode, 'DSP') --No Qty To Sort
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_Case_Fail
 END

         SELECT @cUOM = PackUOM3
         FROM dbo.SKU SKU WITH (NOLOCK)
         JOIN dbo.Pack Pack WITH (NOLOCK) ON SKU.Packkey = Pack.Packkey
         WHERE StorerKey = @cStorerKey
           AND SKU = @cSKU

         -- (james12)
         -- Release task only when all task for this Case has beem completed
--         -- Release PA Task for this Case ID
--        IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) WHERE CaseID = @cCaseID
--                    AND TaskType = 'PA' AND Status = 'W')
--         BEGIN
--            BEGIN TRAN
--
--            UPDATE dbo.TaskDetail
--            Set Status = '0'
--            WHERE TaskType = 'PA'
--            AND   CaseID = @cCaseID
--            AND   Status = 'W'
--
--            IF @@ERROR <> 0
--            BEGIN
--               ROLLBACK TRAN
--               SET @nErrNo = 70520
--               SET @cErrMsg = rdt.rdtgetmessage( 70520, @cLangCode, 'DSP') --UpdTaskDetailFail
--               EXEC rdt.rdtSetFocusField @nMobile, 1
--               GOTO Step_Case_Fail
--            END
--            ELSE
--            BEGIN
--               COMMIT TRAN
--            END
--  END

         --prepare next screen variable
         SET @cOutField01 = @cCaseID
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING(@cSKUDescr, 1,20)
         SET @cOutField04 = SUBSTRING(@cSKUDescr,21,40)
         SET @cOutField05 = ''
         SET @cOutField06 = RTRIM(CAST(@nRemain_Qty AS NVARCHAR( 5))) + '/' + CAST(@nTotal_QTY AS NVARCHAR( 5)) + @cUOM
         SET @cOutField07 = @cLoc   -- (jamesxx)
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cOutField11 = ''

         SET @nScn = @nScn_Sku
         SET @nStep = @nStep_Sku
      END

      -- Tote no scanned
      IF ISNULL(@cToteNo, '') <> '' AND ISNULL(@cCaseID, '') = ''
      BEGIN
         -- (james08)
         IF ISNUMERIC(@cToteNo) = 0
         BEGIN
            SET @nErrNo = 70603
            SET @cErrMsg = rdt.rdtgetmessage( 70603, @cLangCode, 'DSP') --INVALID TOTENO
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_Case_Fail
         END

         SET @cDefaultToteLength  = rdt.RDTGetConfig( @nFunc, 'DefaultToteLength', @cStorerKey)
         -- Check the length of tote no (james20)
         IF LEN(RTRIM(@cToteNo)) <> @cDefaultToteLength
         BEGIN
            SET @nErrNo = 71694
            SET @cErrMsg = rdt.rdtgetmessage( 71694, @cLangCode, 'DSP') --INV TOTENO LEN
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_Case_Fail
         END

         -- Is DropID Status = 9 ???
         IF NOT EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK)
                        WHERE DropID = @cToteNo
                        -- AND   STATUS <> '9'
                        )
         BEGIN
            SET @nErrNo = 69822
            SET @cErrMsg = rdt.rdtgetmessage( 69822, @cLangCode, 'DSP') --TOTE NOT EXISTS
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_Tote_Fail
         END

         IF NOT EXISTS (
         SELECT 1
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.ORDERS o WITH (NOLOCK) ON o.OrderKey = PD.OrderKey
         JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey
         JOIN dbo.DropId DI WITH (NOLOCK) ON DI.DropID = PD.DropID AND DI.Loadkey = O.LoadKey  -- (SHONGxx)
         WHERE PD.StorerKey = @cStorerKey
           AND PD.DropID = @cToteNo
           AND PD.Status >= '5'
           AND PD.Status < '9'
           AND PD.Qty > 0
           AND TD.PickMethod = 'PIECE'                 AND TD.Status = '9'
           AND O.Status < '9' )
         BEGIN
            SET @nErrNo = 70614
            SET @cErrMsg = rdt.rdtgetmessage( 70614, @cLangCode, 'DSP') --Tote Cancel
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_Tote_Fail
         END

         -- Only Piece Pick TaskDetail have DropID (Tote#)
         IF NOT EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                           AND DropID = @cToteNo
                           AND Status = '9'
                           AND PickMethod='PIECE')
         BEGIN
            SET @nErrNo = 70605
            SET @cErrMsg = rdt.rdtgetmessage( 70605, @cLangCode, 'DSP') --INVALID TOTENO
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_Case_Fail
         END

         -- (james14)
         IF EXISTS (SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                    JOIN dbo.PickDetail PD WITH (NOLOCK) ON TD.TaskDetailKey = PD.TaskDetailKey
                    JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
                    WHERE TD.StorerKey = @cStorerKey
                       AND TD.DropID = @cToteNo
                       AND O.UserDefine01 <> ''
                       AND O.Status NOT IN ('9', 'CANC'))
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                       JOIN dbo.PickDetail PD WITH (NOLOCK) ON TD.TaskDetailKey = PD.TaskDetailKey
                       JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
                       WHERE TD.StorerKey = @cStorerKey
                          AND TD.DropID = @cToteNo
                          AND O.UserDefine01 = ''
                          AND O.Status NOT IN ('9', 'CANC'))
            BEGIN
               SET @nErrNo = 70609
               SET @cErrMsg = rdt.rdtgetmessage( 70609, @cLangCode, 'DSP') --ECOMM Tote
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Step_Case_Fail
            END
         END

         -- (james13)
         IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cToteNo AND ManifestPrinted = 'Y')
         BEGIN
            SET @nErrNo = 70532
            SET @cErrMsg = rdt.rdtgetmessage( 70532, @cLangCode, 'DSP') --Tote Closed
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_Tote_Fail
         END

         -- (james05)
         IF EXISTS(SELECT 1 FROM dbo.DROPID WITH (NOLOCK)
            WHERE DropID = @cToteNo
               AND LabelPrinted = 'Y'
               AND ManifestPrinted = 'Y')
         BEGIN
            SET @nErrNo = 70597
            SET @cErrMsg = rdt.rdtgetmessage( 70597, @cLangCode, 'DSP') --Label Printed
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_Tote_Fail
         END

         -- (ChewKP01)
--         IF EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
--                     INNER JOIN dbo.TaskDetail TD WITH (NOLOCK) ON (TD.TaskDetailkey = PD.TaskDetailkey)
--                     INNER JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
--                     WHERE TD.DropID = @cToteNo
--                     AND PD.Status IN ('0','4')
--                     AND O.Status NOT IN ('9', 'CANC'))
         IF EXISTS (SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)
                    JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey
                    WHERE PD.Storerkey = @cStorerkey
                    AND TD.DropID = @cToteno
                    AND PD.Status < '5'
                AND PD.Qty > 0
                    AND TD.PickMethod = 'PIECE'
                    AND TD.Status = '9')
         OR NOT EXISTS (SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)
                        WHERE Storerkey = @cStorerkey AND DropID = @cToteNo)
         BEGIN
            SET @nErrNo = 70610
            SET @cErrMsg = rdt.rdtgetmessage( 70610, @cLangCode, 'DSP') --ToteNotPicked
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_Tote_Fail
         END

         -- (james18)
         IF EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                    JOIN Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
                    WHERE O.StorerKey = @cStorerKey
                       AND O.Status NOT IN ('9', 'CANC')
                       AND PD.DropID = @cToteNo
                       AND ISNULL(CaseID, '') <> '')
         BEGIN
            SET @nErrNo = 70612
            SET @cErrMsg = rdt.rdtgetmessage( 70612, @cLangCode, 'DSP') --Invalid Tote
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_Tote_Fail
         END

         -- (SHONGxx) If Already Packed and the Packed Qty = Pickdetail Qty Then
         -- direct them to Print screen
         SET @nTotPick=0

         SELECT @nTotPick = ISNULL(SUM(P.QTY),0)
         FROM PICKDETAIL p (NOLOCK)
         JOIN ORDERS o (NOLOCK) ON o.OrderKey = p.OrderKey
         JOIN dbo.TaskDetail TD WITH (NOLOCK) ON P.TaskDetailKey = TD.TaskDetailKey
         JOIN dbo.DropID DI WITH (NOLOCK) ON DI.Loadkey = O.LoadKey AND DI.DropID = P.DropID
         WHERE o.status < '9'
         AND p.status='5'
         AND p.dropid = @cToteNo
         AND TD.PickMethod = 'PIECE'
         AND TD.Status = '9'


         SET @nTotPack=0
            SELECT @nTotPack = ISNULL(SUM(QTY),0)
         FROM PackDetail pd
         JOIN PackHeader p (NOLOCK) ON p.PickSlipNo = pd.PickSlipNo
         JOIN ORDERS o (NOLOCK) ON o.OrderKey = p.OrderKey
         JOIN DROPID D (NOLOCK) ON D.DropID = pd.dropid AND D.DropIDType = 'PIECE' AND D.LoadKey = P.Loadkey
         WHERE o.status < '9'
         AND   O.UserDefine01=''
         AND  pd.dropid  = @cToteNo

         IF @nTotPick = @nTotPack AND @nTotPick > 0 AND @nTotPack > 0
         BEGIN
            SET @nScn = @nScn_Print
            SET @nStep = @nStep_Print
            GOTO Quit
         END

--         -- EventLog - Sign In Function
--         EXEC RDT.rdt_STD_EventLog
--            @cActionType = '1', -- Sign in function
--            @cUserID     = @cUserName,
--            @nMobileNo   = @nMobile,
--            @nFunctionID = @nFunc,
--            @cFacility   = @cFacility,
--            @cStorerKey  = @cStorerkey,
--            @cRefNo1     = @cToteNo,
--            @cRefNo2     = 'TOTE'

         -- Insert Pack Detail Here....
         BEGIN TRAN

         DECLARE CUR_TOTE CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT PD.OrderKey, PD.SKU, SUM(PD.Qty)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.ORDERS o WITH (NOLOCK) ON o.OrderKey = PD.OrderKey
         JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey
         JOIN dbo.DropId DI WITH (NOLOCK) ON DI.DropID = PD.DropID AND DI.Loadkey = O.LoadKey  -- (SHONGxx)
         WHERE PD.StorerKey = @cStorerKey
           AND PD.DropID = @cToteNo
           AND PD.Status >= '5'
           AND PD.Status < '9'
           AND PD.Qty > 0
           AND TD.PickMethod = 'PIECE'
           AND TD.Status = '9'
           AND O.Status < '9'
--           AND (O.MBOLKEY = '' OR O.MBOLKEY IS NULL) -- 1 orders might be pick to different tote
         GROUP BY PD.OrderKey, PD.SKU

         OPEN CUR_TOTE
         FETCH NEXT FROM CUR_TOTE INTO @cOrderKey, @cSKU, @nTote_QTY
         WHILE @@FETCH_STATUS <> -1
         BEGIN

            SELECT @cPickSlipNo = PickHeaderKey
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey

            -- Check Duplicate (SHONGxx)
            SET @nTotPick=0
            SELECT @nTotPick = ISNULL(SUM(Qty),0)
            FROM   PickDetail WITH (NOLOCK)
            WHERE  OrderKey = @cOrderKey
            AND    SKU = @cSKU
            AND    STATUS = '5'

            SET @nTotPack=0
            SELECT @nTotPack = ISNULL(SUM(QTY),0)
            FROM   PackDetail pd WITH (NOLOCK)
            WHERE  PickSlipNo = @cPickSlipNo
            AND    SKU = @cSKU

            IF @nTotPick < @nTotPack + @nTote_QTY
            BEGIN
               ROLLBACK TRAN

               CLOSE CUR_TOTE
               DEALLOCATE CUR_TOTE
               SET @nErrNo = 66277
               SET @cErrMsg = rdt.rdtgetmessage( 66277, @cLangCode, 'DSP') --66277^Over Packed
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO Step_Tote_Fail
            END
            -- (SHONGxx) End

            SELECT @cConsigneeKey = ConsigneeKey
            FROM dbo.PackHeader WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo

            IF ISNULL(@cPickSlipNo, '') = ''
            BEGIN
               ROLLBACK TRAN

               CLOSE CUR_TOTE
               DEALLOCATE CUR_TOTE
               SET @nErrNo = 69823
               SET @cErrMsg = rdt.rdtgetmessage( 69823, @cLangCode, 'DSP') --PKSLIP REQ
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO Step_Tote_Fail
            END

            -- Create packheader if not exists
            IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo)
            BEGIN
               INSERT INTO dbo.PackHeader
               (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
               SELECT O.Route, O.OrderKey, SUBSTRING(O.ExternOrderKey, 1, 18), O.LoadKey, O.ConsigneeKey, O.Storerkey, @cPickSlipNo
               FROM  dbo.PickHeader PH WITH (NOLOCK)
               JOIN  dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)
               WHERE PH.PickHeaderKey = @cPickSlipNo

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN

                  CLOSE CUR_TOTE
                  DEALLOCATE CUR_TOTE
                  SET @nErrNo = 69824
                  SET @cErrMsg = rdt.rdtgetmessage( 69824, @cLangCode, 'DSP') --INS PAHDR FAIL
                  EXEC rdt.rdtSetFocusField @nMobile, 2
                  GOTO Step_Tote_Fail
               END
            END

            -- Create packdetail
            IF EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
                       WHERE PickSlipNo = @cPickSlipNo
                       AND StorerKey = @cStorerKey ) -- (Vicky01)
            BEGIN
               -- Not exists then new label no, hardcode label no to '00001'
               -- CartonNo and LabelLineNo will be inserted by trigger
               IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) -- (james05)
                              WHERE PickSlipNo = @cPickSlipNo
                              AND StorerKey = @cStorerKey
                              AND LabelNo = @cToteNo)
               BEGIN
                  INSERT INTO dbo.PackDetail
                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, DropID)
                  VALUES
                     (@cPickSlipNo, 0, @cToteNo, '00000', @cStorerKey, @cSKU, @nTote_QTY,
                      'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cToteNo)

                  -- insert to Eventlog
--                  EXEC RDT.rdt_STD_EventLog
--                     @cActionType   = '4',
--                     @cUserID       = @cUserName,
--                     @nMobileNo     = @nMobile,
--                     @nFunctionID   = @nFunc,
--                     @cFacility     = @cFacility,
--                     @cStorerKey    = @cStorerkey,
--                     @nQty          = @nTote_QTY,  -- (james04)
--                     @cRefNo1       = @cToteNo,
--                     @cRefNo2       = @cConsigneekey   -- (james07)
               END
               ELSE
               BEGIN
                  -- (shong02)
                  SET @nCartonNo = 0
                  SET @cLabelLine= ''
                  SELECT TOP 1
                         @nCartonNo = CartonNo,
                         @cLabelLine = LabelLine
                  FROM dbo.PackDetail WITH (NOLOCK) -- (james05)
                  WHERE PickSlipNo = @cPickSlipNo
                  AND   StorerKey = @cStorerKey
                  AND   DropID = @cToteNo
                  ORDER BY LabelLine DESC

                  SET @cLabelLine = RIGHT('0000' + CONVERT( NVARCHAR(5), CAST(@cLabelLine AS INT) + 1 ), 5)

                  IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) -- (james05)
                                 WHERE PickSlipNo = @cPickSlipNo
                                 AND StorerKey = @cStorerKey
                                 AND SKU = @cSKU
                                 AND LabelNo = @cToteNo )
                  BEGIN
                     INSERT INTO dbo.PackDetail
                        (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, DropID)
                     VALUES
                        (@cPickSlipNo, @nCartonNo, @cToteNo, @cLabelLine, @cStorerKey, @cSKU, @nTote_QTY,
                        'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cToteNo)

                     -- insert to Eventlog
--                     EXEC RDT.rdt_STD_EventLog
--                        @cActionType   = '4',
--                        @cUserID       = @cUserName,
--                        @nMobileNo     = @nMobile,
--                        @nFunctionID   = @nFunc,
--                        @cFacility     = @cFacility,
--                        @cStorerKey    = @cStorerkey,
--                        @nQty          = @nTote_QTY,  -- (james04)
--                        @cRefNo1       = @cToteNo,
--                        @cRefNo2       = @cConsigneekey   -- (james07)
                  END
               END
            END

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN

               CLOSE CUR_TOTE
               DEALLOCATE CUR_TOTE
               SET @nErrNo = 69825
               SET @cErrMsg = rdt.rdtgetmessage( 69825, @cLangCode, 'DSP') --INS PADET FAIL
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO Step_Tote_Fail
            END

            FETCH NEXT FROM CUR_TOTE INTO @cOrderKey, @cSKU, @nTote_QTY
         END
         CLOSE CUR_TOTE
         DEALLOCATE CUR_TOTE

         -- (Vicky03) - Pack Confirmation - Start
         DECLARE Cursor_PackConf CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT O.OrderKey
         FROM PackDetail PD WITH (NOLOCK)
         JOIN PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
         JOIN ORDERS o (NOLOCK) ON o.OrderKey = PH.OrderKey
         WHERE  O.StorerKey = @cStorerKey
            AND PD.DropID = @cToteNo
            AND PH.Status < '9'
            AND O.Status  < '9'

         OPEN Cursor_PackConf

         FETCH NEXT FROM Cursor_PackConf INTO @cPDOrderkey
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SELECT @cPDPickSlipNo = PickSlipNo
            FROM dbo.PackHeader WITH (NOLOCK)
            WHERE OrderKey = @cPOrderKey

            SELECT @nSumPackQTY = SUM(QTY)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPDPickSlipNo

            SELECT @nSumPickQTY = SUM(QTY)
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE Orderkey = @cPOrderKey
            AND   Status = '5'

            IF @nSumPackQTY = @nSumPickQTY
            BEGIN
               -- Confirm Packheader
               UPDATE dbo.PackHeader WITH (ROWLOCK) SET
                  STATUS = '9',
                  ArchiveCop = NULL
               WHERE PickSlipNo = @cPDPickSlipNo

               IF @nErrNo <> 0
               BEGIN
                  ROLLBACK TRAN

                  SET @nErrNo = 69863
                  SET @cErrMsg = rdt.rdtgetmessage( 69863, @cLangCode, 'DSP') --'Upd PaHdr Fail'
                  GOTO Step_Tote_Fail
               END
            END

            FETCH NEXT FROM Cursor_PackConf INTO @cPDOrderkey
         END
         CLOSE Cursor_PackConf
         DEALLOCATE Cursor_PackConf
         -- (Vicky03) - Pack Confirmation - End

         COMMIT TRAN

         --prepare next screen variable
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cOutField11 = ''

         -- Go to Print Tote
         -- (SHONGxx) If Already Packed and the Packed Qty = Pickdetail Qty Then
         -- direct them to Print screen
         SET @nTotPick=0

         SELECT @nTotPick = ISNULL(SUM(P.QTY),0)
         FROM PICKDETAIL p (NOLOCK)
         JOIN ORDERS o (NOLOCK) ON o.OrderKey = p.OrderKey
         JOIN dbo.TaskDetail TD WITH (NOLOCK) ON P.TaskDetailKey = TD.TaskDetailKey
         JOIN dbo.DropId DI WITH (NOLOCK) ON DI.DropID = P.DropID AND DI.Loadkey = O.LoadKey
         WHERE o.status < '9'
         AND p.status='5'
         AND p.dropid = @cToteNo
         AND TD.PickMethod = 'PIECE'
         AND TD.Status = '9'

         SET @nTotPack=0
            SELECT @nTotPack = ISNULL(SUM(QTY),0)
         FROM PackDetail pd
         JOIN PackHeader p (NOLOCK) ON p.PickSlipNo = pd.PickSlipNo
         JOIN ORDERS o (NOLOCK) ON o.OrderKey = p.OrderKey
         JOIN DROPID D (NOLOCK) ON D.DropID = pd.dropid AND D.DropIDType = 'PIECE' AND D.LoadKey = P.Loadkey
         WHERE o.status < '9'
         AND   O.UserDefine01=''
         AND  pd.dropid  = @cToteNo

         IF @nTotPick = @nTotPack AND @nTotPick > 0 AND @nTotPack > 0
         BEGIN
            SET @nScn = @nScn_Print
            SET @nStep = @nStep_Print
         END
         ELSE
         BEGIN
            SET @nErrNo = 69825
            SET @cErrMsg = rdt.rdtgetmessage( 69825, @cLangCode, 'DSP') --INS PADET FAIL
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_Tote_Fail
         END
      END -- IF ISNULL(@cToteNo, '') <> '' AND ISNULL(@cCaseID, '') = ''

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog - Sign Out Function
      -- Changed by Shong on 30-Nov-2011
      -- Operation want to know how long is one tote get sorted
      -- (ChewKP02)
--      EXEC RDT.rdt_STD_EventLog
--       @cActionType = '9', -- Sign Out function
--       @cUserID     = @cUserName,
--       @nMobileNo   = @nMobile,
--       @nFunctionID = @nFunc,
--       @cFacility   = @cFacility,
--       @cStorerKey  = @cStorerkey

      -- Back to PTZone
      SET @nScn  = @nScn_PTZone
      SET @nStep = @nStep_PTZone

      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''

      SET @cConsigneekey = ''
      SET @cCaseID       = ''
      SET @cToteNo       = ''
      SET @cLOC          = ''
      SET @cSKU          = ''
      SET @cQTY          = ''
      SET @cUOM          = ''
      SET @cOption       = ''
      SET @cOption       = ''
   END
   GOTO Quit

   Step_Case_Fail:
   BEGIN
      SET @cCaseID = ''
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
   END

   Step_Tote_Fail:
   BEGIN
      SET @cToteNo = ''
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 2391
   CASE ID  (Field01)
   SKU      (Field02, 03, 04)
   SKU      (Field05, input)
   SORT QTY (Field06, 07)
********************************************************************************/
Step_Sku:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKUscan = @cInField05

      IF ISNULL( @cSKU, '') = ''
         SET @cSKU = @cOutField02

      -- Validate blank
      IF ISNULL(@cSKUscan, '') = ''
      BEGIN
         SET @nErrNo = 69826
         SET @cErrMsg = rdt.rdtgetmessage( 69826, @cLangCode, 'DSP') --SKU req
         GOTO Step_SKU_Fail
      END

      -- only cater UPC/SKU (james10)
      -- If BOM SKU scanned
--      SELECT TOP 1 @cSKUscan = ComponentSKU FROM dbo.BillOfMaterial WITH (NOLOCK)
--         WHERE StorerKey = @cStorerKey
--            AND SKU = @cSKUscan

      IF ISNULL(@cSKUscan, '') <> ''
      BEGIN
         -- If not BOM SKU scanned, check for other posibilities
         EXEC [RDT].[rdt_GETSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKUscan     OUTPUT
         ,@bSuccess    = @b_Success    OUTPUT
         ,@nErr = @nErrNo       OUTPUT
         ,@cErrMsg     = @cErrMsg      OUTPUT
      END

      IF ISNULL(@cSKUscan, '') <> ISNULL(@cSKU, '')
      BEGIN
         SET @nErrNo = 69827
         SET @cErrMsg = rdt.rdtgetmessage( 69827, @cLangCode, 'DSP') --Invalid SKU
         GOTO Step_SKU_Fail
      END

      -- Reset variables      (james01)
      SET @cConsigneekey = ''
      SET @cLoc = ''

     -- Get the 1st Consignee + LOC
      SELECT TOP 1
             @cConsigneekey = ORDERS.ConsigneeKey,
             @cLoc          = PICKDETAIL.Loc
      FROM dbo.ORDERS WITH (NOLOCK)
      JOIN dbo.PICKDETAIL WITH (NOLOCK) ON ORDERS.OrderKey = PICKDETAIL.OrderKey
      JOIN dbo.LOC WITH (NOLOCK) ON LOC.Loc = PICKDETAIL.Loc
      WHERE PICKDETAIL.CaseID    = @cCaseID
        AND PICKDETAIL.Storerkey = @cStorerKey
        AND PICKDETAIL.SKU       = @cSKU
        AND PICKDETAIL.Status    = '3' -- (Shong01)
        AND LOC.PutawayZone      = @cPutawayZone -- (Shong01)
        AND EXISTS (SELECT 1 FROM dbo.StoreToLocDetail WITH (NOLOCK)
         WHERE ORDERS.ConsigneeKey = StoreToLocDetail.ConsigneeKey
            AND PICKDETAIL.LOC = StoreToLocDetail.LOC
            AND STATUS = '1')
      GROUP BY ORDERS.ConsigneeKey, PICKDETAIL.Loc, LOC.LogicalLocation -- (Vicky03)
      --ORDER BY ORDERS.ConsigneeKey, PICKDETAIL.Loc
      ORDER BY LOC.LogicalLocation, PICKDETAIL.Loc -- (SHONGxx)

      IF ISNULL(@cConsigneekey, '') = ''
      BEGIN
        SET @nErrNo = 70516
         SET @cErrMsg = rdt.rdtgetmessage( 70516, @cLangCode, 'DSP') --NO STORE FOUND
         GOTO Step_SKU_Fail
      END

      IF ISNULL(@cLoc, '') = ''
      BEGIN
         SET @nErrNo = 70517
         SET @cErrMsg = rdt.rdtgetmessage( 70517, @cLangCode, 'DSP') --NO LOC FOUND
         GOTO Step_SKU_Fail
      END

      -- (Vicky06) - Start
      -- If Suggested LOC in PickDetail is Full, then get the next available PTS LOC
      SET @cSuggPTSLoc = @cLOC

      -- Prepare Next Qty Screen
      IF EXISTS (SELECT 1 FROM dbo.StoreToLOCDetail WITH (NOLOCK)
                 WHERE LOC = @cLoc AND LocFull = 'Y')
      BEGIN
         SET @cNextPTSLoc=''
         SELECT TOP 1 @cNextPTSLoc = LOC
         FROM dbo.StoreToLOCDetail WITH (NOLOCK)
         WHERE ConsigneeKey = @cConsigneekey
         AND LocFull = 'N'

         IF ISNULL(RTRIM(@cNextPTSLoc), '') <> ''
         BEGIN
            SET @cLoc = @cNextPTSLoc
         END
      END

      SELECT @nQtySuggest = ISNULL(SUM(QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      WHERE O.ConsigneeKey = @cConsigneekey
         AND PD.CaseID = @cCaseID
         AND PD.Status = '3'
         AND PD.LOC = @cSuggPTSLoc -- (Vicky06)
         --AND PD.LOC = @cLOCscan -- (Vicky03)

   --prepare next screen variable
      SET @cOutField01 = @cConsigneekey
      SET @cOutField02 = @cLoc
      SET @cOutField03 = @cUOM
      SET @cOutField04 = @nQtySuggest
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''

      SET @nScn = @nScn_Qty
      SET @nStep = @nStep_Qty

      -- (Vicky06) - End

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- If the RDT config turn on then go back PTS Initial screen
      IF rdt.RDTGetConfig( @nFunc, 'PTS_INITIAL_SCN', @cStorerKey) = 1
      BEGIN
         SET @nRemain_Qty = 0
         SELECT @nRemain_Qty = ISNULL(SUM(PICKDETAIL.Qty), 0)
         FROM dbo.PickDetail WITH (NOLOCK)
         JOIN dbo.LOC WITH (NOLOCK) ON LOC.LOC = PICKDETAIL.LOC
         WHERE PICKDETAIL.CaseID = @cCaseID
            AND PICKDETAIL.Storerkey = @cStorerKey
            AND PICKDETAIL.Status = '3'

         IF @nRemain_Qty = 0
         BEGIN
--            UPDATE dbo.UCC WITH (ROWLOCK) SET
--               [Status] = '6'
--            WHERE UCCNo = @cCaseID
--            AND   [Status] <= '4'
--            AND   StorerKey = @cStorerKey
            IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cCaseID AND StorerKey = @cStorerKey AND [Status] <= '4')
            BEGIN
               SET @cCaseID_New = ''
               SELECT TOP 1
                  @cCaseID_New = UCCNo
               FROM UCC WITH (NOLOCK)
               WHERE UCCNo LIKE RTRIM(@cCaseID) + '[0-9][0-9][0-9][0-9]'
               ORDER BY UCCNo DESC

               IF ISNULL(RTRIM(@cCaseID_New),'') = ''
                  SET @cCaseID_New = RTRIM(@cCaseID) + '0001'
               ELSE
               BEGIN
                  SET @nNextCaseIDSeqNo = CAST( RIGHT(RTRIM(@cCaseID_New),4) AS INT ) + 1
                  SET @cCaseID_New = RTRIM(@cCaseID) + RIGHT('0000' + CONVERT(VARCHAR(4), @nNextCaseIDSeqNo), 4)
               END

               UPDATE dbo.UCC WITH (ROWLOCK) SET
                  UCCNo = @cCaseID_New,
                  [Status]  = '6'
               WHERE UCCNo = @cCaseID
               AND   [Status] <= '6'
               AND   StorerKey = @cStorerKey
            END
         END

         SET @cOutField01 = ''

         -- Goto Tote Screen
         SET @nFunc = 1811
         SET @nScn  = 3941
         SET @nStep = 2

         GOTO Quit
      END

      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''

      SET @cConsigneekey = ''
      SET @cLOC          = ''

    -- (Vicky06) - Start
      SET @cSuggPTSLOC   = ''
      SET @cNextPTSLOC   = ''
      SET @cCaseID       = ''
      SET @cToteNo       = ''
      SET @cOrderKey     = ''
      SET @cSKU          = ''
      SET @cSKUDescr     = ''
      SET @cOption       = ''
      SET @cSKUscan      = ''
      SET @cLOCscan      = ''
      SET @cQTY          = ''
      SET @nCurScn       = 0
      SET @nCurStep      = 0
      SET @nQTY          = 0
      SET @nQtySuggest   = 0
      SET @nSumBOMQTY    = 0
      -- (Vicky06) - End

      SET @nScn = @nScn_Case
      SET @nStep = @nStep_Case
   END
   GOTO Quit

   Step_SKU_Fail:
   BEGIN
      SET @cSKUscan = ''
      SET @cOutField05 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 3. screen = 2393
   STORE (Field01)
   LOC   (Field02)
   UOM   (Field03)
   QTY   (Field04, input)
********************************************************************************/
Step_Qty:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
     SET @cSuggestQTY = @cOutField04
      SET @cQTY = @cInField05

      -- Validate blank
      IF ISNULL(@cQTY, '') = ''
      OR RTRIM(@cQTY) = ''  -- (jamesxx)
      BEGIN
         SET @nErrNo = 69830
         SET @cErrMsg = rdt.rdtgetmessage( 69830, @cLangCode, 'DSP') --QTY req
         GOTO Step_QTY_Fail
      END

      -- Note: put 1 in rdt.rdtisvalidqty to not allow user to enter 0 qty
      -- use has to esc and push the case back to conveyor to QC
--      IF RDT.rdtIsValidQTY( @cQTY, 1) = 0  -- (james17)
      IF RDT.rdtIsValidQTY( @cQTY, 0) = 0  -- Qty 0 is now allow (jamesxx)
      BEGIN
         SET @nErrNo = 69831
         SET @cErrMsg = rdt.rdtgetmessage( 69831, @cLangCode, 'DSP') --Invalid number
         GOTO Step_QTY_Fail
      END

      IF CAST(@cSuggestQTY AS INT) < CAST(@cQTY AS INT)
      BEGIN
         SET @nErrNo = 70533
         SET @cErrMsg = rdt.rdtgetmessage( 70533, @cLangCode, 'DSP') --Invalid Qty
         GOTO Step_QTY_Fail
      END

      SET @nQty = CAST(@cQty AS INT)

      SET @cDefaultPTSAction  = rdt.RDTGetConfig( @nFunc, 'DefaultPTSAction', @cStorerKey)

      --prepare next screen variable
      SET @cOutField01 = @cConsigneekey
      SET @cOutField02 = @cLoc
      SET @cOutField03 = @cUOM
      SET @cOutField04 = @nQTY
      SET @cOutField05 = ''
      SET @cOutField06 = CASE WHEN @nQty < CAST(@cSuggestQTY AS INT) THEN ''
                              ELSE @cDefaultPTSAction END -- (james19) '' --'9'   -- (Vicky04)
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''

      SET @nScn  = @nScn_ToTote
      SET @nStep = @nStep_ToTote
      EXEC rdt.rdtSetFocusField @nMobile, 1

--      SET @cOutField01 = @cConsigneekey
--      SET @cOutField02 = @cLoc
--      SET @cOutField03 = ''
--      SET @cOutField04 = ''
--      SET @cOutField05 = ''
--      SET @cOutField06 = ''
--      SET @cOutField07 = ''
--      SET @cOutField08 = ''
--      SET @cOutField09 = ''
--      SET @cOutField10 = ''
--      SET @cOutField11 = ''

--      SET @nScn = @nScn_Loc
--      SET @nStep = @nStep_Loc
        -- (ChewKP02)
        IF @cEscKey <> '1'
        BEGIN

            EXEC RDT.rdt_STD_EventLog
               @cActionType = '1', -- Sign in function
               @cUserID     = @cUserName,
               @nMobileNo   = @nMobile,
               @nFunctionID = @nFunc,
               @cFacility   = @cFacility,
               @cStorerKey  = @cStorerkey,
               --@cToteNo     = @cToteNo,
               @cRefNo1     = @cToteNo,
               @cRefNo2     = '',
               @nStep       = @nStep

            SET @cEscKey = '0'
        END

        SET @cEscKey = '0' -- (ChewKP02)
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SELECT @nTotal_QTY = ISNULL(SUM(Qty), 0)
      FROM dbo.UCC WITH (NOLOCK)
      WHERE UCCNo = @cCaseID
         AND Storerkey = @cStorerKey
         AND SKU = @cSKU
       --  AND OrderKey = @cOrderKey  -- (Vicky03)

      SELECT @nRemain_Qty = ISNULL(SUM(Qty), 0)
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE CaseID = @cCaseID
         AND Storerkey = @cStorerKey
         AND Status = '3'

      SELECT @cUOM = PackUOM3 FROM dbo.SKU SKU WITH (NOLOCK)
      JOIN dbo.Pack Pack WITH (NOLOCK) ON SKU.Packkey = Pack.Packkey
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU


      --prepare next screen variable
      SET @cOutField01 = @cCaseID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING(@cSKUDescr, 1,20)
      SET @cOutField04 = SUBSTRING(@cSKUDescr,21,40)
      SET @cOutField05 = ''
      SET @cOutField06 = RTRIM(CAST(@nRemain_Qty AS NVARCHAR( 5))) + '/' + CAST(@nTotal_QTY AS NVARCHAR( 5)) + @cUOM
      SET @cOutField07 = @cLoc   -- (jamesxx)
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''

      SET @nScn = @nScn_Sku
      SET @nStep = @nStep_Sku

--      SET @cOutField01 = @cConsigneekey
--      SET @cOutField02 = @cLoc--@cSuggPTSLoc -- @cLoc (Vicky06)
--      SET @cOutField03 = ''
--      SET @cOutField04 = ''
--      SET @cOutField05 = ''
--      SET @cOutField06 = ''
--      SET @cOutField07 = ''
--      SET @cOutField08 = ''
--      SET @cOutField09 = ''
--      SET @cOutField10 = ''
--      SET @cOutField11 = ''
--
--      SET @nScn = @nScn_Loc
--      SET @nStep = @nStep_Loc
   END
   GOTO Quit

   Step_QTY_Fail:
   BEGIN
      SET @cQTY    = '0'
   END
END
GOTO Quit


/********************************************************************************
Step 4. screen = 2392
   STORE (Field01)
   LOC   (Field02, input)
********************************************************************************/
Step_Loc:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLOCscan = @cInField03

      --When LOC is blank
      IF ISNULL(@cLOCscan, '') = ''
      BEGIN
         SET @nErrNo = 69828
         SET @cErrMsg = rdt.rdtgetmessage( 69828, @cLangCode, 'DSP') --TO LOC req
         GOTO Step_LOC_Fail
      END

-- Commended By (Vicky06)
--      IF ISNULL(@cLOCscan, '') <> ISNULL(@cLoc, '')
--      BEGIN
--         SET @nErrNo = 69829
--         SET @cErrMsg = rdt.rdtgetmessage( 69829, @cLangCode, 'DSP') --Invalid TO LOC
--         GOTO Step_LOC_Fail
--      END

      -- (Vicky06) - Start
      IF ISNULL(@cLOCscan, '') <> ISNULL(@cLoc, '')
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.StoreToLocDetail WITH (NOLOCK)
                        WHERE LOC = @cLOCscan AND ConsigneeKey = @cConsigneekey)
         BEGIN
            SET @nErrNo = 69829
            SET @cErrMsg = rdt.rdtgetmessage( 69829, @cLangCode, 'DSP') --Invalid TO LOC
            GOTO Step_LOC_Fail
         END

         BEGIN TRAN

         UPDATE dbo.StoreToLocDetail WITH (ROWLOCK)
           SET LocFull = 'Y',
               EditDate = GETDATE(),
               EditWho = @cUserName
         WHERE LOC = @cLoc
         AND   ConsigneeKey = @cConsigneekey
         AND   LocFull = 'N'

         IF @@Error <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 70600
            SET @cErrMsg = rdt.rdtgetmessage( 70600, @cLangCode, 'DSP') --UpdStoretoLocFail
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_LOC_Fail
         END
         ELSE
         BEGIN
            COMMIT TRAN
         END

         SET @cLOC = @cLOCscan
      END
      -- (Vicky06) - End

      SET @cDefaultPTSAction  = rdt.RDTGetConfig( @nFunc, 'DefaultPTSAction', @cStorerKey)

      --prepare next screen variable
      SET @cOutField01 = @cConsigneekey
      SET @cOutField02 = @cLoc
      SET @cOutField03 = @cUOM
      SET @cOutField04 = @nQTY
      SET @cOutField05 = ''
      SET @cOutField06 = CASE WHEN @nQty < CAST(@cSuggestQTY AS INT) THEN ''
                              ELSE @cDefaultPTSAction END -- (james19) '' --'9'   -- (Vicky04)
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''

      SET @nScn  = @nScn_ToTote
      SET @nStep = @nStep_ToTote
      EXEC rdt.rdtSetFocusField @nMobile, 1


      -- (ChewKP02)
      EXEC RDT.rdt_STD_EventLog
             @cActionType = '1', -- Sign in function
             @cUserID     = @cUserName,
             @nMobileNo   = @nMobile,
             @nFunctionID = @nFunc,
             @cFacility   = @cFacility,
             @cStorerKey  = @cStorerkey,
             --@cToteNo     = @cToteNo,
             @cRefNo1     = @cToteNo,
             @cRefNo2     = '',
             @nStep       = @nStep

--      SELECT @nQtySuggest = ISNULL(SUM(QTY), 0)
--      FROM dbo.PickDetail PD WITH (NOLOCK)
--      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
--      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
--      WHERE O.ConsigneeKey = @cConsigneekey
--         AND PD.CaseID = @cCaseID
--         AND PD.Status = '3'
--         AND PD.LOC = @cSuggPTSLoc -- (Vicky06)
--         --AND PD.LOC = @cLOCscan -- (Vicky03)
--
--   --prepare next screen variable
--      SET @cOutField01 = @cConsigneekey
--      SET @cOutField02 = @cLoc
--      SET @cOutField03 = @cUOM
--      SET @cOutField04 = @nQtySuggest
--      SET @cOutField05 = ''
--      SET @cOutField06 = ''
--      SET @cOutField07 = ''
--      SET @cOutField08 = ''
--      SET @cOutField09 = ''
--      SET @cOutField10 = ''
--      SET @cOutField11 = ''
--
--      SET @nScn = @nScn_Qty
--      SET @nStep = @nStep_Qty
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = @cConsigneekey
      SET @cOutField02 = @cLoc
      SET @cOutField03 = @cUOM
      SET @cOutField04 = @nQtySuggest
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''

      SET @nScn = @nScn_Qty
      SET @nStep = @nStep_Qty

   END
   GOTO Quit

   Step_LOC_Fail:
   BEGIN
      SET @cLOCscan = ''
      SET @cOutField03 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 5. screen = 2394
   STORE (Field01)
   LOC   (Field02)
   UOM   (Field03)
   QTY   (Field04)
   TO TOTE (Field05, input)
   Option (Field06, input)
********************************************************************************/
Step_ToTote:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToToteNo = @cInField05
      SET @cOption = @cInField06

      -- Validate blank
      IF ISNULL(@cToToteNo, '') = '' AND ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 71700
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TOTE/OPT req
         EXEC rdt.rdtSetFocusField @nMobile, 5
         GOTO Quit
      END

      IF ISNULL(@cToToteNo, '') = '' AND ISNULL(@cOption, '') <> ''
      BEGIN
         IF EXISTS (SELECT 1 FROM RDT.RDTXML_Root WITH (NOLOCK)
                    WHERE Mobile = @nMobile
                    AND Focus = 'Field05')
         BEGIN
            SET @nErrNo = 69833
            SET @cErrMsg = rdt.rdtgetmessage( 69833, @cLangCode, 'DSP') --TOTE NO req
            SET @cOutField06 = @cOption
         END

         EXEC rdt.rdtSetFocusField @nMobile, 5
         GOTO Quit
      END

      -- Validate blank
      IF ISNUMERIC(@cToToteNo) = 0 OR CHARINDEX('.', @cToToteNo) > 0 --(james08)
      BEGIN
         SET @nErrNo = 70607
         SET @cErrMsg = rdt.rdtgetmessage( 70607, @cLangCode, 'DSP') --INVALID TOTENO
         EXEC rdt.rdtSetFocusField @nMobile, 5
         SET @cOutField06 = CASE WHEN ISNULL(@cOption, '') = '' THEN '' ELSE @cOption END
         SET @cToToteNo = ''
         SET @cOutField05 = ''
         GOTO Quit
      END

      -- (james25)
      -- Get the default length of tote no
      SET @cDefaultToToteLength  = rdt.RDTGetConfig( @nFunc, 'DefaultToToteLength', @cStorerKey)
      IF ISNULL(@cDefaultToToteLength, '') = ''
      BEGIN
         SET @cDefaultToToteLength = '8'  -- make it default to 8 digit if not setup
      END

      -- Check the length of tote no (james20)
      IF LEN(RTRIM(@cToToteNo)) <> @cDefaultToToteLength
      BEGIN
         SET @nErrNo = 71695
         SET @cErrMsg = rdt.rdtgetmessage( 71695, @cLangCode, 'DSP') --INV TOTENO LEN
         EXEC rdt.rdtSetFocusField @nMobile, 5
         SET @cOutField06 = CASE WHEN ISNULL(@cOption, '') = '' THEN '' ELSE @cOption END
         SET @cToToteNo = ''
         SET @cOutField05 = ''
         GOTO Quit
      END

      -- Make sure user not to scan the SKU Code as Tote# (james22)
      IF EXISTS (SELECT 1 FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cToToteNo)
      BEGIN
         SET @cOutField01 = @cToToteNo
         SET @cOutField02 = @cToToteNo
         SET @cOutField03 = ''

         -- Save current screen no
         SET @nCurScn = @nScn
         SET @nCurStep = @nStep

         SET @nScn = @nScn_ConfirmTote
         SET @nStep = @nStep_ConfirmTote

         GOTO QUIT
      END

      IF ISNULL(@cOption, '') = '' AND ISNULL(@cToToteNo, '') <> ''
      BEGIN
         IF EXISTS (SELECT 1 FROM RDT.RDTXML_Root WITH (NOLOCK)
                    WHERE Mobile = @nMobile
                    AND Focus = 'Field06')
         BEGIN
            SET @nErrNo = 69834
            SET @cErrMsg = rdt.rdtgetmessage( 69834, @cLangCode, 'DSP') --Option req
            SET @cOutField05 = @cToToteNo
         END

         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Quit
      END

      IF ISNULL(@cOption, '') <> '1' AND ISNULL(@cOption, '') <> '9'
      BEGIN
         SET @nErrNo = 69835
         SET @cErrMsg = rdt.rdtgetmessage( 69835, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 6
         SET @cOption = ''
         SET @cOutField05 = CASE WHEN ISNULL(@cToToteNo, '') = '' THEN '' ELSE @cToToteNo END
         SET @cOutField06 = ''
         GOTO Quit
      END

      Continue_Step_ToTote:

      -- (james16)
      IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cToToteNo AND Status = '9')
      BEGIN
         BEGIN TRAN

         DELETE FROM DropID WHERE DropID = @cToToteNo AND Status = '9'

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 70611
            SET @cErrMsg = rdt.rdtgetmessage( 70611, @cLangCode, 'DSP') --ReleasToteFail
            GOTO Step_ToTote_Fail
         END
         ELSE
         BEGIN
            COMMIT TRAN
         END

      END
      ELSE
      BEGIN
         -- (Vicky05) - Start
         IF EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK)
                    WHERE DropID = @cToToteNo
                    AND Status < '9'
                    AND DropLOC <> @cLOC)
         BEGIN
            SET @nErrNo = 70598
            SET @cErrMsg = rdt.rdtgetmessage( 70598, @cLangCode, 'DSP') --Tote4OtherStore
            EXEC rdt.rdtSetFocusField @nMobile, 5
            GOTO Step_ToTote_Fail
         END
         -- (Vicky05) - End

      END

      IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)
                 WHERE DropID = @cToToteNo
                 AND ManifestPrinted = 'Y'
                 AND STATUS < '9')
      BEGIN
         SET @nErrNo = 70608
         SET @cErrMsg = rdt.rdtgetmessage( 70608, @cLangCode, 'DSP') --Tote is Closed
         GOTO Step_ToTote_Fail
      END

      -- (james19)
      IF EXISTS (SELECT 1 FROM dbo.Orders O WITH (NOLOCK)
                 JOIN dbo.PackHeader PH WITH (NOLOCK) ON O.OrderKey = PH.OrderKey
                 JOIN dbo.PackDetail PD WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
                 WHERE O.StorerKey = @cStorerKey
                     AND O.Status < '9'
                     AND PD.DropID = @cToToteNo
                     AND O.ConsigneeKey <> @cConsigneeKey
                     AND O.Userdefine01 = '')
      BEGIN
         SET @nErrNo = 70606
         SET @cErrMsg = rdt.rdtgetmessage( 70606, @cLangCode, 'DSP') --ToteNotDespatch
         EXEC rdt.rdtSetFocusField @nMobile, 5
         GOTO Step_ToTote_Fail
      END

      SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''

      -- Extended update
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY, @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     +
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cCaseID         NVARCHAR( 18), ' +
               '@cLOC            NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@cConsigneekey   NVARCHAR( 15), ' +
               '@nQTY            INT,        '    +
               '@cToToteNo       NVARCHAR( 18), ' +
               '@cSuggPTSLOC     NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY, @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_CloseTote_Fail
         END
      END

      -- If dropid not exists in LOC with open status
      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)
                     WHERE DropID = @cToToteNo
                     AND   Droploc = @cLOC
                     AND   ManifestPrinted = 'N'
                     AND   Status < '9')
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)
                    WHERE DropID <> @cToToteNo
                    AND   Droploc = @cLOC
                    AND   ManifestPrinted = 'N'
                    AND   Status < '9')
         BEGIN
            -- Save current screen no
            SET @nCurScn = @nScn
            SET @nCurStep = @nStep

            SET @nScn = @nScn_OpenTote
            SET @nStep = @nStep_OpenTote
            SET @cOutField01=''
            SET @cOutField02=''


            GOTO Quit
         END
      END

      IF @cOption = '1'
      BEGIN
         SET @nScn = @nScn_NewTote
         SET @nStep = @nStep_CloseTote
         SET @cInField06 = ''
         SET @cOutField01=''

         -- insert to Eventlog
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '4',
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerkey,
            @nQty          = @nQTY,           -- (james04)
            @cRefNo1       = @cToToteNo,
            @cConsigneekey = @cConsigneekey,
            --@cRefNo2       = @cConsigneekey,   -- (james07)
            @nStep         = @nStep


          -- (ChewKP02)
          EXEC RDT.rdt_STD_EventLog
             @cActionType = '9', -- Sign Out function
             @cUserID     = @cUserName,
             @nMobileNo   = @nMobile,
             @nFunctionID = @nFunc,
             @cFacility   = @cFacility,
             @cStorerKey  = @cStorerkey,
             @cRefNo1     = @cToToteNo,
             @cRefNo2     = ''     ,
             @nStep       = @nStep

         GOTO Quit
      END

      IF @cOption = '9'
      BEGIN
         IF @nQty < @nQtySuggest
         BEGIN
            IF rdt.RDTGetConfig( @nFunc, 'SHOWSHTPICKRSN', @cStorerKey) = 1
            BEGIN
               -- Save current screen no
               SET @nCurScn = @nScn
               SET @nCurStep = @nStep

               -- Go to STD short pick screen
               SET @nScn = @nSCN_ShortPick
               SET @nStep = @nStep_ShortPick

               SELECT @cOutField01 = ISNULL(SUM(Qty), 0)
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND CaseID = @cCaseID
                  AND SKU = @cSKU
                  AND Status = '3'

               SELECT @cOutField02 = PackUOM3
               FROM dbo.Pack P WITH (NOLOCK)
               JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.PackKey = P.PackKey
               WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU

               SET @cOutField03 = ''
               SET @cOutField04 = ''
               SET @cOutField05 = ''

               GOTO Quit
            END
         END -- @nQty < @nQtySuggest
         ELSE
         BEGIN
            -- @nQty = @nQtySuggest  (Full Pick)
            -- Confirm Tote Here
            SET @b_Success = 1

            EXEC [RDT].[rdt_PTS_ConfirmTote]
                @nMobile         =@nMobile
               ,@cStorerKey      =@cStorerKey
               ,@cCaseID         =@cCaseID
               ,@cLOC            =@cLOC
               ,@cSKU            =@cSKU
               ,@cConsigneeKey   =@cConsigneekey
               ,@nQtyEnter       =@nQTY
               ,@cToToteNo       =@cToToteNo
               ,@cShortPick      ='N'
               ,@bSuccess        =@b_success OUTPUT
               ,@nErrNo          =@nErrNo    OUTPUT
               ,@cErrMsg         =@cErrMsg   OUTPUT
               ,@cSuggLOC        =@cSuggPTSLOC -- (Vicky06)


            IF @b_success <> 1
            BEGIN
               EXEC rdt.rdtSetFocusField @nMobile, 5
               GOTO Step_ToTote_Fail
            END

            SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
            IF @cExtendedUpdateSP = '0'
               SET @cExtendedUpdateSP = ''

            -- Extended update
            IF @cExtendedUpdateSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY, @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                  SET @cSQLParam =
                     '@nMobile         INT,       '     +
                     '@nFunc           INT,       '     +
                     '@cLangCode       NVARCHAR( 3),  ' +
                     '@nStep           INT,       '     +
                     '@nInputKey       INT,       '     +
                     '@cStorerKey      NVARCHAR( 15), ' +
                     '@cCaseID         NVARCHAR( 18), ' +
                     '@cLOC            NVARCHAR( 10), ' +
                     '@cSKU            NVARCHAR( 20), ' +
                     '@cConsigneekey   NVARCHAR( 15), ' +
                     '@nQTY            INT,        '    +
                     '@cToToteNo       NVARCHAR( 18), ' +
                     '@cSuggPTSLOC     NVARCHAR( 10), ' +
                     '@nErrNo          INT OUTPUT,    ' +
                     '@cErrMsg         NVARCHAR( 20) OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY, @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO Step_ToTote_Fail
               END
            END


--            IF NOT EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK) WHERE DropID = @cToToteNo
--                          AND LabelPrinted = 'Y')
--            BEGIN
--               -- Added by SHONG on 30-Nov-2011 (SHONGxx)
--               -- Insert to Event Log for when all qty had been dispatched to stores
--               EXEC RDT.rdt_STD_EventLog
--                @cActionType = '1', -- Sign Out function
--                @cUserID     = @cUserName,
--                @nMobileNo   = @nMobile,
--                @nFunctionID = @nFunc,
--                @cFacility   = @cFacility,
--                @cStorerKey  = @cStorerkey,
--                @cRefNo1     = @cToToteNo,
--                @cRefNo2     = 'OPEN TOTE'
--            END


            -- insert to Eventlog
            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '4',
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerkey,
               @nQty          = @nQTY,           -- (james04)
               @cRefNo1       = @cToToteNo,
               @cConsigneekey = @cConsigneekey,
               --@cRefNo2       = @cConsigneekey   -- (james07)
               @nStep         = @nStep


             -- (ChewKP02)
             EXEC RDT.rdt_STD_EventLog
                @cActionType = '9', -- Sign Out function
                @cUserID     = @cUserName,
                @nMobileNo   = @nMobile,
                @nFunctionID = @nFunc,
                @cFacility   = @cFacility,
                @cStorerKey  = @cStorerkey,
                @cRefNo1     = @cToToteNo,
                @cRefNo2     = '',
                @nStep       = @nStep

            -- If everything in this case is picked (james09)
            IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                           WHERE StorerKey = @cStorerKey
                              AND CASEID = @cCaseID
                              AND Status < '5')
            BEGIN
               -- If we have PA task for this case (residual from DPK) in 'W' status
               -- then release it (james09)
               IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                          WHERE StorerKey = @cStorerKey
                             AND TaskType = 'PA'
                             AND CaseID = @cCaseID
                             AND Status = 'W')
               BEGIN
                  BEGIN TRAN

                  UPDATE dbo.TaskDetail SET
                     Status = '0',
                     EditWho = @cUserName,
                     EditDate = GETDATE(),
                     TrafficCop = NULL
                  WHERE StorerKey = @cStorerKey
                     AND TaskType = 'PA'
                     AND CaseID = @cCaseID
                     AND Status = 'W'

                  IF @@ERROR <> 0
                  BEGIN
                     ROLLBACK TRAN
                     SET @nErrNo = 70606
                     SET @cErrMsg = rdt.rdtgetmessage( 70606, @cLangCode, 'DSP') --ReleasePAFail
                      EXEC rdt.rdtSetFocusField @nMobile, 5
                     GOTO Step_ToTote_Fail
                  END
                  ELSE
                  BEGIN
                     COMMIT TRAN
                  END
               END

            END

            IF NOT EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK) WHERE DropID = @cToToteNo
                          AND LabelPrinted = 'Y')
            BEGIN
               -- Printing process
               IF ISNULL(@cPrinter, '') = ''
               BEGIN
                  --SET @nErrNo = 69836
                  --SET @cErrMsg = rdt.rdtgetmessage( 69836, @cLangCode, 'DSP') --NoLoginPrinter
                  GOTO Step_ToTote_SkipReport
               END

               SET @cExtendedPrintSP = rdt.rdtGetConfig( @nFunc, 'ExtendedPrintSP', @cStorerKey)
               IF @cExtendedPrintSP = '0'
                  SET @cExtendedPrintSP = ''

               -- Extended update
               IF @cExtendedPrintSP <> ''
               BEGIN
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPrintSP AND type = 'P')
                  BEGIN
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPrintSP) +
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY,
                          @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                     SET @cSQLParam =
                        '@nMobile         INT, '            +
                        '@nFunc           INT, '            +
                        '@cLangCode       NVARCHAR( 3), '   +
                        '@nStep           INT, '            +
                        '@nInputKey       INT, '            +
                        '@cStorerKey      NVARCHAR( 15), '  +
                        '@cCaseID         NVARCHAR( 18), '  +
                        '@cLOC            NVARCHAR( 10), '  +
                        '@cSKU            NVARCHAR( 20), '  +
                        '@cConsigneekey   NVARCHAR( 15), '  +
                        '@nQTY            INT, '  +
                        '@cToToteNo       NVARCHAR( 18), '  +
                        '@cSuggPTSLOC     NVARCHAR( 10), '  +
                        '@nErrNo          INT   OUTPUT, '   +
                        '@cErrMsg         NVARCHAR( 20)  OUTPUT'

                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                        @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY,
                        @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

                     IF @nErrNo <> 0
                     BEGIN
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                        GOTO Step_ToTote_SkipReport
                     END
                  END
               END
               ELSE
               BEGIN
                  SET @cReportType = 'SORTLABEL'
                  SET @cPrintJobName = 'PRINT_SORTLABEL'

                  SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                         @cTargetDB = ISNULL(RTRIM(TargetDB), '')
                  FROM RDT.RDTReport WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   ReportType = @cReportType

                  IF ISNULL(@cDataWindow, '') = ''
                  BEGIN
                     --ROLLBACK TRAN
                     --SET @nErrNo = 69837
                     --SET @cErrMsg = rdt.rdtgetmessage( 69837, @cLangCode, 'DSP') --DWNOTSetup
                     --GOTO Step_ToTote_Fail
                     GOTO Step_ToTote_SkipReport
                  END

                  IF ISNULL(@cTargetDB, '') = ''
                  BEGIN
                     --ROLLBACK TRAN
                     --SET @nErrNo = 69838
                     --SET @cErrMsg = rdt.rdtgetmessage( 69838, @cLangCode, 'DSP') --TgetDB Not Set
                     --GOTO Step_ToTote_Fail
                     GOTO Step_ToTote_SkipReport
                  END

                  SET @nErrNo = 0
                  EXEC RDT.rdt_BuiltPrintJob
                     @nMobile,
                     @cStorerKey,
                     @cReportType,
                     @cPrintJobName,
                     @cDataWindow,
                     @cPrinter,
                     @cTargetDB,
                     @cLangCode,
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT,
                     @cStorerKey,
                     @cToToteNo

                  IF @nErrNo <> 0
                  BEGIN
                     --ROLLBACK TRAN
                  --SET @nErrNo = 69839
                     --SET @cErrMsg = rdt.rdtgetmessage( 69839, @cLangCode, 'DSP') --'InsertPRTFail'
                     --GOTO Step_ToTote_Fail
                     GOTO Step_ToTote_SkipReport
                  END
                  ELSE
                  BEGIN
                     UPDATE DROPID WITH (ROWLOCK)
                     SET LabelPrinted = 'Y'
                     WHERE Dropid = @cToToteNo
                     --IF @@ERROR <> 0
                     --BEGIN
                     --   SET @nErrNo = 70136
                     --   SET @cErrMsg = rdt.rdtgetmessage( 70136, @cLangCode, 'DSP') --'UpdDropIdFailed'
                     --   ROLLBACK TRAN
                     --   GOTO Step_ToTote_Fail
                     --END
                  END

               END  -- Print Tote Label
            END   -- end of Extended update

            Step_ToTote_SkipReport:

            GOTO Step_GetNextScreen
         END   -- @nQty = @nQtySuggest
      END      -- @cOption = '9'

      -- Prep next screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cEscKey = '1' -- (ChewKP02)

      SET @cOutField01 = @cConsigneekey
      SET @cOutField02 = @cLoc
      SET @cOutField03 = @cUOM
      SET @cOutField04 = @nQtySuggest
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''

      SET @nScn = @nScn_Qty
      SET @nStep = @nStep_Qty

      --SET @nScn = @nScn_Loc
      --SET @nStep = @nStep_Loc
   END
   GOTO Quit

   Step_ToTote_Fail:
   BEGIN
      SET @cToToteNo = ''
      SET @cOption = ''
      --SET @cQTY    = ''

      SET @cOutField05 = ''
      SET @cOutField06 = ''
   END

   Step_ToTote1_Fail:
   BEGIN
      --SET @cOption = ''
      SET @cOption    = ''

      SET @cOutField05 = @cToToteNo
      SET @cOutField06 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 6. screen = 2395
   CLOSE TOTE? (Field01, input)
   1 = YES
   9 = NO
********************************************************************************/
Step_CloseTote:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      IF @cOption = ''
      BEGIN
         SET @nErrNo = 70521
         SET @cErrMsg = rdt.rdtgetmessage( 70521, @cLangCode, 'DSP') --Option req
         GOTO Step_CloseTote_Fail
      END

      IF @cOption <> '1' AND @cOption <> '9'
      BEGIN
         SET @nErrNo = 70522
         SET @cErrMsg = rdt.rdtgetmessage( 70522, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_CloseTote_Fail
      END

      IF @cOption = '1'
      BEGIN
         -- Close Old Tote
         SET @b_Success = 1

            EXEC [RDT].[rdt_PTS_ConfirmTote]
             @nMobile         =@nMobile
            ,@cStorerKey      =@cStorerKey
            ,@cCaseID         =@cCaseID
            ,@cLOC            =@cLOC
            ,@cSKU            =@cSKU
            ,@cConsigneeKey   =@cConsigneekey
            ,@nQtyEnter       =@nQTY
            ,@cToToteNo       =@cToToteNo
            ,@cShortPick      ='N'
            ,@bSuccess        =@b_success OUTPUT
            ,@nErrNo          =@nErrNo    OUTPUT
            ,@cErrMsg         =@cErrMsg   OUTPUT
            ,@cSuggLOC       =@cSuggPTSLOC -- (Vicky06)

            IF @b_success = 0
            BEGIN
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Step_CloseTote_Fail
            END

            SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
            IF @cExtendedUpdateSP = '0'
               SET @cExtendedUpdateSP = ''

            -- Extended update
            IF @cExtendedUpdateSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY, @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                  SET @cSQLParam =
                     '@nMobile         INT,       '     +
                     '@nFunc           INT,       '     +
                     '@cLangCode       NVARCHAR( 3),  ' +
                     '@nStep           INT,       '     +
                     '@nInputKey       INT,       '     +
                     '@cStorerKey      NVARCHAR( 15), ' +
                     '@cCaseID         NVARCHAR( 18), ' +
                     '@cLOC            NVARCHAR( 10), ' +
                     '@cSKU            NVARCHAR( 20), ' +
                     '@cConsigneekey   NVARCHAR( 15), ' +
                     '@nQTY            INT,        '    +
                     '@cToToteNo       NVARCHAR( 18), ' +
                     '@cSuggPTSLOC     NVARCHAR( 10), ' +
                     '@nErrNo          INT OUTPUT,    ' +
                     '@cErrMsg         NVARCHAR( 20) OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY, @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO Step_CloseTote_Fail
               END
            END
--            IF NOT EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK) WHERE DropID = @cToToteNo
--                          AND LabelPrinted = 'Y')
--            BEGIN
--               -- Added by SHONG on 30-Nov-2011 (SHONGxx)
--               -- Insert to Event Log for when all qty had been dispatched to stores
--               EXEC RDT.rdt_STD_EventLog
--                @cActionType = '1', -- Sign Out function
--                @cUserID     = @cUserName,
--                @nMobileNo   = @nMobile,
--                @nFunctionID = @nFunc,
--                @cFacility   = @cFacility,
--                @cStorerKey  = @cStorerkey,
--                @cRefNo1     = @cToToteNo,
--                @cRefNo2     = 'OPEN TOTE'
--            END

            -- insert to Eventlog
--            EXEC RDT.rdt_STD_EventLog
--               @cActionType   = '4',
--               @cUserID       = @cUserName,
--               @nMobileNo     = @nMobile,
--               @nFunctionID   = @nFunc,
--               @cFacility     = @cFacility,
--               @cStorerKey    = @cStorerkey,
--               @nQty          = @nQTY,           -- (james04)
--               @cRefNo1       = @cToToteNo,
--               @cRefNo2       = @cConsigneekey   -- (james07)

            -- If everything in this case is picked (james09)
            IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                           WHERE StorerKey = @cStorerKey
                              AND CASEID = @cCaseID
                              AND Status < '5')
            BEGIN
               -- If we have PA task for this case (residual from DPK) in 'W' status
               -- then release it (james09)
               IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                          WHERE StorerKey = @cStorerKey
                             AND TaskType = 'PA'
                             AND CaseID = @cCaseID
                             AND Status = 'W')
               BEGIN
                  BEGIN TRAN

                  UPDATE dbo.TaskDetail SET
                     Status = '0',
                     EditWho = @cUserName,
                     EditDate = GETDATE(),
                     TrafficCop = NULL
                  WHERE StorerKey = @cStorerKey
                     AND TaskType = 'PA'
                     AND CaseID = @cCaseID
                     AND Status = 'W'

                  IF @@ERROR <> 0
                  BEGIN
                 ROLLBACK TRAN
                     SET @nErrNo = 70607
                     SET @cErrMsg = rdt.rdtgetmessage( 70607, @cLangCode, 'DSP') --ReleasePAFail
                     EXEC rdt.rdtSetFocusField @nMobile, 5
                     GOTO Step_CloseTote_Fail
                  END
                  ELSE
                  BEGIN
                     COMMIT TRAN
                  END
               END
            END

            -- Printing process
            IF ISNULL(@cPrinter, '') = ''
            BEGIN
               --SET @nErrNo = 69836
      --SET @cErrMsg = rdt.rdtgetmessage( 69836, @cLangCode, 'DSP') --NoLoginPrinter
               --GOTO Step_CloseTote_Fail
               GOTO Skip_SortLabel
            END

            IF NOT EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK) WHERE DropID = @cToToteNo
                          AND LabelPrinted = 'Y')
            BEGIN
               SET @cExtendedPrintSP = rdt.rdtGetConfig( @nFunc, 'ExtendedPrintSP', @cStorerKey)
               IF @cExtendedPrintSP = '0'
                  SET @cExtendedPrintSP = ''

               -- Extended update
               IF @cExtendedPrintSP <> ''
               BEGIN
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPrintSP AND type = 'P')
                  BEGIN
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPrintSP) +
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY,
                          @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                     SET @cSQLParam =
                        '@nMobile         INT, '            +
                        '@nFunc           INT, '            +
                        '@cLangCode       NVARCHAR( 3), '   +
                        '@nStep           INT, '            +
                        '@nInputKey       INT, '            +
                        '@cStorerKey      NVARCHAR( 15), '  +
                        '@cCaseID         NVARCHAR( 18), '  +
                        '@cLOC            NVARCHAR( 10), '  +
                        '@cSKU            NVARCHAR( 20), '  +
                        '@cConsigneekey   NVARCHAR( 15), '  +
                        '@nQTY            INT, '  +
                        '@cToToteNo       NVARCHAR( 18), '  +
                        '@cSuggPTSLOC     NVARCHAR( 10), '  +
                        '@nErrNo          INT   OUTPUT, '   +
                        '@cErrMsg         NVARCHAR( 20)  OUTPUT'

                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                        @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY,
                        @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

                     IF @nErrNo <> 0
                     BEGIN
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                        GOTO Skip_SortLabel
                     END
                  END
               END
               ELSE
               BEGIN
                  SET @cReportType = 'SORTLABEL'
                  SET @cPrintJobName = 'PRINT_SORTLABEL'
                  SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                         @cTargetDB = ISNULL(RTRIM(TargetDB), '')
                  FROM RDT.RDTReport WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   ReportType = @cReportType

                  IF ISNULL(@cDataWindow, '') = ''
                  BEGIN
                     --ROLLBACK TRAN
                     --SET @nErrNo = 69837
                     --SET @cErrMsg = rdt.rdtgetmessage( 69837, @cLangCode, 'DSP') --DWNOTSetup
                     GOTO Skip_SortLabel
                  END

                  IF ISNULL(@cTargetDB, '') = ''
                  BEGIN
                     --ROLLBACK TRAN
                     --SET @nErrNo = 69838
                     --SET @cErrMsg = rdt.rdtgetmessage( 69838, @cLangCode, 'DSP') --TgetDB Not Set
                     --GOTO Step_CloseTote_Fail
                     GOTO Skip_SortLabel
                  END

                  SET @nErrNo = 0
                  EXEC RDT.rdt_BuiltPrintJob
                     @nMobile,
                     @cStorerKey,
                     @cReportType,
                     @cPrintJobName,
                     @cDataWindow,
                     @cPrinter,
                     @cTargetDB,
                     @cLangCode,
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT,
                     @cStorerKey,
                     @cToToteNo
               END

               IF @nErrNo <> 0
               BEGIN
                  --ROLLBACK TRAN
                  --SET @nErrNo = 69839
                  --SET @cErrMsg = rdt.rdtgetmessage( 69839, @cLangCode, 'DSP') --'InsertPRTFail'
                  --GOTO Step_CloseTote_Fail
                  GOTO Skip_SortLabel
               END
               ELSE
               BEGIN
                  UPDATE DROPID WITH (ROWLOCK)
                  SET LabelPrinted = 'Y'
                  WHERE Dropid = @cToToteNo
                     --IF @@ERROR <> 0
                     --BEGIN
                     --SET @nErrNo = 70136
                     --SET @cErrMsg = rdt.rdtgetmessage( 70136, @cLangCode, 'DSP') --'UpdDropIdFailed'
                     --ROLLBACK TRAN
                     --GOTO Step_CloseTote_Fail
                     --END
               END

            END  -- Print Tote Label
            Skip_SortLabel:

            IF NOT EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK) WHERE DropID = @cToToteNo
                          AND ManifestPrinted = 'Y')
            BEGIN
               SET @cReportType = 'SORTMANFES'
               SET @cPrintJobName = 'PRINT_SORTMANFES'


               SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                     @cTargetDB = ISNULL(RTRIM(TargetDB), '')
               FROM RDT.RDTReport WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   ReportType = @cReportType

               IF ISNULL(@cDataWindow, '') = ''
               BEGIN
                  --ROLLBACK TRAN
                  --SET @nErrNo = 69840
                  --SET @cErrMsg = rdt.rdtgetmessage( 69840, @cLangCode, 'DSP') --DWNOTSetup
                  --GOTO Step_CloseTote_Fail
                  GOTO Skip_SortManfes
               END

               IF ISNULL(@cTargetDB, '') = ''
               BEGIN
                  --ROLLBACK TRAN
            --SET @nErrNo = 69841
                  --SET @cErrMsg = rdt.rdtgetmessage( 69841, @cLangCode, 'DSP') --TgetDB Not Set
                  --GOTO Step_CloseTote_Fail
                  GOTO Skip_SortManfes
               END

               SET @nErrNo = 0
               EXEC RDT.rdt_BuiltPrintJob
                  @nMobile,
                  @cStorerKey,
                  @cReportType,
                  @cPrintJobName,
                  @cDataWindow,
                  @cPrinter_Paper, -- (Vicky01)
                  @cTargetDB,
                  @cLangCode,
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT,
                  @cStorerKey,
                  @cToToteNo

               IF @nErrNo <> 0
               BEGIN
                  --ROLLBACK TRAN
                  --SET @nErrNo = 69842
                  --SET @cErrMsg = rdt.rdtgetmessage( 69842, @cLangCode, 'DSP') --'InsertPRTFail'
                  --GOTO Step_CloseTote_Fail
                  GOTO Skip_SortManfes
               END
               ELSE
               BEGIN
                  UPDATE DROPID WITH (ROWLOCK)
                  SET ManifestPrinted = 'Y'
                  WHERE Dropid = @cToToteNo
                  IF @@ERROR <> 0
                  BEGIN
                     --SET @nErrNo = 70136
                     --SET @cErrMsg = rdt.rdtgetmessage( 70136, @cLangCode, 'DSP') --'UpdDropIdFailed'
                     --ROLLBACK TRAN
                     --GOTO Step_CloseTote_Fail
                     GOTO Skip_SortManfes
                  END
               END


               -- Added by SHONG on 30-Nov-2011 (SHONGxx)
 -- Insert to Event Log for when all qty had been dispatched to stores
               -- EventLog - Sign Out Function

--               EXEC RDT.rdt_STD_EventLog
--                @cActionType = '9', -- Sign Out function
--                @cUserID     = @cUserName,
--                @nMobileNo   = @nMobile,
--                @nFunctionID = @nFunc,
--                @cFacility   = @cFacility,
--                @cStorerKey  = @cStorerkey,
--                @cRefNo1     = @cToToteNo,
--                @cRefNo2     = 'CLOSE TOTE'

          END -- Print Tote Manifest
          Skip_SortManfes:

          GOTO Step_GetNextScreen

          GOTO Quit
  END
  ELSE
  IF @cOption = '9'
      BEGIN
       SET @cDefaultPTSAction  = rdt.RDTGetConfig( @nFunc, 'DefaultPTSAction', @cStorerKey)
       --prepare next screen variable
       SET @cOutField01 = @cConsigneekey
       SET @cOutField02 = @cLoc
       SET @cOutField03 = @cUOM
       SET @cOutField04 = @nQTY
       SET @cOutField05 = ''
       SET @cOutField06 = @cDefaultPTSAction -- (james19) '' --'9'    -- (Vicky04)
       SET @cOutField07 = ''
       SET @cOutField08 = ''
       SET @cOutField09 = ''
       SET @cOutField10 = ''
       SET @cOutField11 = ''

       SET @nScn = @nScn_ToTote
       SET @nStep = @nStep_ToTote

       GOTO Quit
    END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SELECT @nQTY = ISNULL(SUM(QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      WHERE O.ConsigneeKey = @cConsigneekey
         AND PD.CaseID = @cCaseID
        -- AND PD.Status >= '3'
        -- AND PD.Status < '9'
         AND PD.Status = '3' -- (Vicky03)
      AND PD.LOC = @cSuggPTSLOC -- (Vicky06)
         --AND PD.LOC = @cLoc -- (Vicky03)

      SET @cDefaultPTSAction  = rdt.RDTGetConfig( @nFunc, 'DefaultPTSAction', @cStorerKey)

      --prepare next screen variable
      SET @cOutField01 = @cConsigneekey
      SET @cOutField02 = @cLoc
      SET @cOutField03 = @cUOM
      SET @cOutField04 = @nQTY
      SET @cOutField05 = ''
      SET @cOutField06 = CASE WHEN @nQty < @nQtySuggest THEN ''
                              ELSE @cDefaultPTSAction END -- (james19) ''--'9'   -- (Vicky04)
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''

      SET @nScn = @nScn_ToTote
      SET @nStep = @nStep_ToTote
   END
   GOTO Quit

   Step_CloseTote_Fail:
   BEGIN
      SET @cOption = ''

      SET @cOutField01 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 7. screen = 2396
   OPTION (Field01, input)
********************************************************************************/
Step_Print:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      IF @cOption = ''
      BEGIN
         SET @nErrNo = 69854
         SET @cErrMsg = rdt.rdtgetmessage( 69854, @cLangCode, 'DSP') --Option req
         GOTO Step_Print_Fail
      END

      IF @cOption <> '1' AND @cOption <> '9'
      BEGIN
         SET @nErrNo = 69855
         SET @cErrMsg = rdt.rdtgetmessage( 69855, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_Print_Fail
      END

      IF @cOption = '1'
      BEGIN
         -- Printing process
         IF ISNULL(@cPrinter, '') = ''
         BEGIN
            SET @nErrNo = 69856
            SET @cErrMsg = rdt.rdtgetmessage( 69856, @cLangCode, 'DSP') --NoLoginPrinter
            GOTO Step_Print_Fail
         END

         IF EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK)
                   WHERE DropID = @cToteNo
                   AND   LabelPrinted = 'Y')
         BEGIN
            SET @nErrNo = 70596
            SET @cErrMsg = rdt.rdtgetmessage( 70596, @cLangCode, 'DSP') --Label Printed
            GOTO Step_Print_Fail
         END

         SET @cExtendedPrintSP = rdt.rdtGetConfig( @nFunc, 'ExtendedPrintSP', @cStorerKey)
         IF @cExtendedPrintSP = '0'
         SET @cExtendedPrintSP = ''

         -- Extended update
         IF @cExtendedPrintSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPrintSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPrintSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY,
                  @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT, '            +
                  '@nFunc           INT, '            +
                  '@cLangCode       NVARCHAR( 3), '   +
                  '@nStep           INT, '            +
                  '@nInputKey       INT, '            +
                  '@cStorerKey      NVARCHAR( 15), '  +
                  '@cCaseID         NVARCHAR( 18), '  +
                  '@cLOC            NVARCHAR( 10), '  +
                  '@cSKU            NVARCHAR( 20), '  +
                  '@cConsigneekey   NVARCHAR( 15), '  +
                  '@nQTY            INT, '  +
                  '@cToToteNo       NVARCHAR( 18), '  +
                  '@cSuggPTSLOC     NVARCHAR( 10), '  +
                  '@nErrNo          INT   OUTPUT, '   +
                  '@cErrMsg         NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY,
                  @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO Step_Print_Fail
               END
            END
         END
         ELSE
         BEGIN
            -- (james02)
            SET @cReportType = 'SORTLABEL'
            SET @cPrintJobName = 'PRINT_SORTLABEL'

            SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                   @cTargetDB = ISNULL(RTRIM(TargetDB), '')
            FROM RDT.RDTReport WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   ReportType = @cReportType

            IF ISNULL(@cDataWindow, '') = ''
            BEGIN
               SET @nErrNo = 69857
               SET @cErrMsg = rdt.rdtgetmessage( 69857, @cLangCode, 'DSP') --DWNOTSetup
               GOTO Step_Print_Fail
            END

            IF ISNULL(@cTargetDB, '') = ''
            BEGIN
               SET @nErrNo = 69858
               SET @cErrMsg = rdt.rdtgetmessage( 69858, @cLangCode, 'DSP') --TgetDB Not Set
               GOTO Step_Print_Fail
            END

            -- (james06)
            SELECT TOP 1 @cConsigneeKey = O.ConsigneeKey, @cPTS_LOC = TD.TOLOC -- (james23)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.OrderS O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
            JOIN TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey
            JOIN Dropid d WITH (NOLOCK) ON D.Dropid = TD.DropID AND D.Loadkey = O.LoadKey AND D.DropIDType = 'PIECE'
            WHERE TD.StorerKey = @cStorerKey
              AND TD.DropID = @cToteNo
              AND PD.Status = '5'
              AND O.UserDefine01 = ''
              AND O.Status < '9'
              -- AND TD.PickMethod = 'PIECE'

            IF ISNULL(@cPTS_LOC  , '') = ''  -- (james23)
            BEGIN
               -- (Shong03)
               SELECT TOP 1
                     @cPTS_LOC = LOC
               FROM   StoreToLocDetail stld WITH (NOLOCK)
               WHERE  stld.ConsigneeKey = @cConsigneeKey
            END

            SET @nErrNo = 0
            EXEC RDT.rdt_BuiltPrintJob
               @nMobile,
               @cStorerKey,
               @cReportType,
               @cPrintJobName,
               @cDataWindow,
               @cPrinter,
               @cTargetDB,
               @cLangCode,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT,
               @cStorerKey,
               @cToteNo
         END

         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 69859
            SET @cErrMsg = rdt.rdtgetmessage( 69859, @cLangCode, 'DSP') --'InsertPRTFail'
            GOTO Step_Print_Fail
         END
         ELSE
         BEGIN
            UPDATE DROPID WITH (ROWLOCK)
            SET LabelPrinted = 'Y',
                DropLOC = ISNULL(@cPTS_LOC, '') -- (james06)
            WHERE Dropid = @cToteNo    -- (james05)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 70136
               SET @cErrMsg = rdt.rdtgetmessage( 70136, @cLangCode, 'DSP') --'UpdDropIdFailed'
               ROLLBACK TRAN
               GOTO Step_Print_Fail
            END
         END

         -- Added by SHONG on 30-Nov-2011 (SHONGxx)
--         EXEC RDT.rdt_STD_EventLog
--          @cActionType = '1', -- Sign Out function
--          @cUserID     = @cUserName,
--          @nMobileNo   = @nMobile,
--          @nFunctionID = @nFunc,
--          @cFacility   = @cFacility,
--          @cStorerKey  = @cStorerkey,
--          @cRefNo1     = @cToToteNo,
--          @cRefNo2     = 'OPEN TOTE'


         IF EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK)
                  WHERE DropID = @cToteNo
                    AND ManifestPrinted = 'Y')
        BEGIN
            SET @nErrNo = 70596
            SET @cErrMsg = rdt.rdtgetmessage( 70596, @cLangCode, 'DSP') --Label Printed
            GOTO Step_Print_Fail
        END


         SET @cReportType = 'SORTMANFES'
         SET @cPrintJobName = 'PRINT_SORTMANFES'

         -- (Vicky01) - Start
         IF ISNULL(@cPrinter_Paper, '') = ''
         BEGIN
            SET @nErrNo = 70519
            SET @cErrMsg = rdt.rdtgetmessage( 70519, @cLangCode, 'DSP') --NoPaperPrinter
             GOTO Step_Print_Fail
         END
         -- (Vicky01) - End

         SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                @cTargetDB = ISNULL(RTRIM(TargetDB), '')
         FROM RDT.RDTReport WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ReportType = @cReportType

         IF ISNULL(@cDataWindow, '') = ''
         BEGIN
            SET @nErrNo = 69860
            SET @cErrMsg = rdt.rdtgetmessage( 69860, @cLangCode, 'DSP') --DWNOTSetup
            GOTO Step_Print_Fail
         END

         IF ISNULL(@cTargetDB, '') = ''
         BEGIN
            SET @nErrNo = 69861
            SET @cErrMsg = rdt.rdtgetmessage( 69861, @cLangCode, 'DSP') --TgetDB Not Set
            GOTO Step_Print_Fail
         END

         SET @nErrNo = 0
         EXEC RDT.rdt_BuiltPrintJob
            @nMobile,
            @cStorerKey,
            @cReportType,
            @cPrintJobName,
            @cDataWindow,
            @cPrinter_Paper, -- (Vicky01)
            @cTargetDB,
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT,
            @cStorerKey,
            @cToteNo

         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 69862
            SET @cErrMsg = rdt.rdtgetmessage( 69862, @cLangCode, 'DSP') --'InsertPRTFail'
            GOTO Step_Print_Fail
         END
         ELSE
         BEGIN
            UPDATE DROPID WITH (ROWLOCK)
            SET ManifestPrinted = 'Y',
                DropLOC = ISNULL(@cPTS_LOC, '') -- (james06)
            WHERE Dropid = @cToteNo
             IF @@ERROR <> 0
             BEGIN
               SET @nErrNo = 70136
               SET @cErrMsg = rdt.rdtgetmessage( 70136, @cLangCode, 'DSP') --'UpdDropIdFailed'
               ROLLBACK TRAN
               GOTO Step_Print_Fail
             END
         END

         -- Added by SHONG on 30-Nov-2011 (SHONGxx)
--         EXEC RDT.rdt_STD_EventLog
--          @cActionType = '9', -- Sign Out function
--          @cUserID     = @cUserName,
--          @nMobileNo   = @nMobile,
--          @nFunctionID = @nFunc,
--          @cFacility   = @cFacility,
--          @cStorerKey  = @cStorerkey,
--          @cRefNo1     = @cToToteNo,
--          @cRefNo2     = 'CLOSE TOTE'

         -- Init screen
         SET @cOutField01 = @cConsigneeKey
         SET @cOutField02 = @cPTS_LOC

         SET @nScn = @nScn_PPATOLOC
         SET @nStep = @nStep_PPATOLOC
      END

      IF @cOption = '9'
      BEGIN
         -- (james06)
         SELECT TOP 1 @cConsigneeKey = O.ConsigneeKey, @cPTS_LOC = TD.TOLOC   -- (james23)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.OrderS O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
         JOIN TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey
         WHERE TD.StorerKey = @cStorerKey
           AND TD.DropID = @cToteNo
           AND PD.Status = '5'
           AND O.UserDefine01 = ''

         IF ISNULL(@cPTS_LOC, '') = '' -- (james23)
         BEGIN
           -- (Shong03)
           SELECT TOP 1
                  @cPTS_LOC = LOC
           FROM   StoreToLocDetail stld WITH (NOLOCK)
           WHERE  stld.ConsigneeKey = @cConsigneeKey
         END

         -- Init screen
         SET @cOutField01 = @cConsigneeKey
         SET @cOutField02 = @cPTS_LOC

         SET @nScn = @nScn_PPATOLOC
         SET @nStep = @nStep_PPATOLOC
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''

      -- (Vicky06) - Start
      SET @cConsigneekey = ''
      SET @cLOC          = ''
      SET @cSuggPTSLOC   = ''
      SET @cNextPTSLOC   = ''
      SET @cCaseID       = ''
      SET @cToteNo       = ''
      SET @cOrderKey     = ''
      SET @cSKU          = ''
      SET @cSKUDescr     = ''
      SET @cOption       = ''
      SET @cSKUscan      = ''
      SET @cLOCscan      = ''
      SET @cQTY      = ''
      SET @nCurScn       = 0
      SET @nCurStep      = 0
      SET @nQTY          = 0
      SET @nQtySuggest   = 0
      SET @nSumBOMQTY    = 0
      -- (Vicky06) - End

      SET @nScn = @nScn_Case
      SET @nStep = @nStep_Case
   END
   GOTO Quit

   Step_Print_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = ''
    END
END
GOTO Quit

/********************************************************************************
Step 8. Scn = 2010.
   RSN        (field01, input)
********************************************************************************/
Step_ShortPick:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
      SET @cReasonCode = @cInField05

      IF ISNULL(@cReasonCode, '') = ''
      BEGIN
         SET @nErrNo = 69865
         SET @cErrMsg = rdt.rdtgetmessage( 69865, @cLangCode, 'DSP') --'BAD Reason'
         GOTO Step_ShortPick_Fail
      END

      SELECT @cModuleName = StoredProcName FROM RDT.RDTMsg WITH (NOLOCK) WHERE Message_id = @nFunc

      EXEC rdt.rdt_STD_Short_Pick
         @nFunc,
         @nMobile,
         @cLangCode,
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT, -- screen limitation, 20 char max
         @cStorerKey,
         @cFacility,
         '',
         '',
         '',
         @cOrderKey,
         --@cLOC,
         @cSuggPTSLOC, -- (Vicky06)
         '',
         @cSKU,
         @cUOM,
         @nQTY,       -- In master unit
         '',
         '',
         '',
         '',
         '',
         @cReasonCode,
         @cUserName,
         @cModuleName

      IF @nErrNo <> 0
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_ShortPick_Fail
      END


      -- Short sort. Update pickdetail status to '4' and split line if necessary  \
      SET @b_Success = 1

      EXEC [RDT].[rdt_PTS_ConfirmTote]
          @nMobile         =@nMobile
         ,@cStorerKey      =@cStorerKey
         ,@cCaseID         =@cCaseID
         ,@cLOC            =@cLOC
         ,@cSKU            =@cSKU
         ,@cConsigneeKey   =@cConsigneekey
         ,@nQtyEnter       =@nQTY
         ,@cToToteNo       =@cToToteNo
         ,@cShortPick      ='Y'
         ,@bSuccess =@b_success OUTPUT
         ,@nErrNo          =@nErrNo    OUTPUT
         ,@cErrMsg         =@cErrMsg   OUTPUT
         ,@cSuggLOC        =@cSuggPTSLOC -- (Vicky06)

         IF @b_success <> 1
         BEGIN
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_ShortPick_Fail
         END

         SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
         IF @cExtendedUpdateSP = '0'
            SET @cExtendedUpdateSP = ''

         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY, @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT,       '     +
                  '@nFunc           INT,       '     +
                  '@cLangCode       NVARCHAR( 3),  ' +
                  '@nStep           INT,       '     +
                  '@nInputKey       INT,       '     +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cCaseID         NVARCHAR( 18), ' +
                  '@cLOC            NVARCHAR( 10), ' +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@cConsigneekey   NVARCHAR( 15), ' +
                  '@nQTY            INT,        '    +
                  '@cToToteNo       NVARCHAR( 18), ' +
                  '@cSuggPTSLOC     NVARCHAR( 10), ' +
                  '@nErrNo          INT OUTPUT,    ' +
                  '@cErrMsg         NVARCHAR( 20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY, @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Step_ShortPick_Fail
            END
         END

         -- insert to Eventlog -- (ChewKP02)
         EXEC RDT.rdt_STD_EventLog
             @cActionType   = '4',
             @cUserID       = @cUserName,
             @nMobileNo     = @nMobile,
             @nFunctionID   = @nFunc,
             @cFacility     = @cFacility,
             @cStorerKey    = @cStorerkey,
             @nQty          = @nQTY,           -- (james04)
             @cRefNo1       = @cToToteNo,
             @cConsigneekey = @cConsigneekey,
             --@cRefNo2       = @cConsigneekey   -- (james07)
             @nStep         = @nStep


         -- (ChewKP02)
         EXEC RDT.rdt_STD_EventLog
            @cActionType = '9', -- Sign Out function
            @cUserID     = @cUserName,
            @nMobileNo   = @nMobile,
            @nFunctionID = @nFunc,
            @cFacility   = @cFacility,
            @cStorerKey  = @cStorerkey,
            @cRefNo1     = @cToToteNo,
            @cRefNo2     = '',
            @nStep       = @nStep

--         IF NOT EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK) WHERE DropID = @cToToteNo
--                       AND LabelPrinted = 'Y')
--         BEGIN
--            -- Added by SHONG on 30-Nov-2011 (SHONGxx)
--            -- Insert to Event Log for when all qty had been dispatched to stores
----            EXEC RDT.rdt_STD_EventLog
----             @cActionType = '1', -- Sign Out function
----             @cUserID     = @cUserName,
----             @nMobileNo   = @nMobile,
----             @nFunctionID = @nFunc,
----   @cFacility   = @cFacility,
----             @cStorerKey  = @cStorerkey,
----             @cRefNo1     = @cToToteNo,
----             @cRefNo2     = 'OPEN TOTE'
--         END

         -- insert to Eventlog
--         EXEC RDT.rdt_STD_EventLog
--            @cActionType   = '4',
--            @cUserID       = @cUserName,
--            @nMobileNo     = @nMobile,
--            @nFunctionID   = @nFunc,
--            @cFacility     = @cFacility,
--            @cStorerKey    = @cStorerkey,
--            @nQty          = @nQty,  -- (james04)
--            @cRefNo1       = @cToToteNo,
--            @cRefNo2       = @cConsigneekey   -- (james07)

      -- If everything in this case is picked (james09)
      IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND CASEID = @cCaseID
                        AND Status < '5')
      BEGIN
         -- If we have PA task for this case (residual from DPK) in 'W' status
         -- then release it (james09)
         IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                    WHERE StorerKey = @cStorerKey
                       AND TaskType = 'PA'
                       AND CaseID = @cCaseID
                  AND Status = 'W')
         BEGIN
            BEGIN TRAN

            UPDATE dbo.TaskDetail SET
               Status = '0',
               EditWho = @cUserName,
               EditDate = GETDATE(),
               TrafficCop = NULL
            WHERE StorerKey = @cStorerKey
               AND TaskType = 'PA'
               AND CaseID = @cCaseID
               AND Status = 'W'

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 70608
               SET @cErrMsg = rdt.rdtgetmessage( 70608, @cLangCode, 'DSP') --ReleasePAFail
               EXEC rdt.rdtSetFocusField @nMobile, 5
               GOTO Step_ShortPick_Fail
            END
            ELSE
            BEGIN
               COMMIT TRAN
            END
         END

      END

      -- Print Tote Label (james21)
      IF NOT EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK) WHERE DropID = @cToToteNo
                    AND LabelPrinted = 'Y')
      BEGIN
         -- Printing process
         IF ISNULL(@cPrinter, '') = ''
         BEGIN
            GOTO Step_ShortPick_SkipReport
         END

         SET @cExtendedPrintSP = rdt.rdtGetConfig( @nFunc, 'ExtendedPrintSP', @cStorerKey)
         IF @cExtendedPrintSP = '0'
            SET @cExtendedPrintSP = ''

         -- Extended update
         IF @cExtendedPrintSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPrintSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPrintSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY,
                    @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT, '            +
                  '@nFunc           INT, '            +
                  '@cLangCode       NVARCHAR( 3), '   +
                  '@nStep           INT, '            +
                  '@nInputKey       INT, '            +
                  '@cStorerKey      NVARCHAR( 15), '  +
                  '@cCaseID         NVARCHAR( 18), '  +
                  '@cLOC            NVARCHAR( 10), '  +
                  '@cSKU            NVARCHAR( 20), '  +
                  '@cConsigneekey   NVARCHAR( 15), '  +
                  '@nQTY            INT, '  +
                  '@cToToteNo       NVARCHAR( 18), '  +
                  '@cSuggPTSLOC     NVARCHAR( 10), '  +
                  '@nErrNo          INT   OUTPUT, '   +
                  '@cErrMsg         NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY,
                  @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO Step_ShortPick_SkipReport
               END
            END
         END
         ELSE
         BEGIN
            SET @cReportType = 'SORTLABEL'
            SET @cPrintJobName = 'PRINT_SORTLABEL'

            SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                   @cTargetDB = ISNULL(RTRIM(TargetDB), '')
            FROM RDT.RDTReport WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   ReportType = @cReportType

            IF ISNULL(@cDataWindow, '') = ''
            BEGIN
               GOTO Step_ShortPick_SkipReport
            END

            IF ISNULL(@cTargetDB, '') = ''
            BEGIN
               GOTO Step_ShortPick_SkipReport
            END

            SET @nErrNo = 0
            EXEC RDT.rdt_BuiltPrintJob
               @nMobile,
               @cStorerKey,
               @cReportType,
               @cPrintJobName,
               @cDataWindow,
               @cPrinter,
               @cTargetDB,
               @cLangCode,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT,
               @cStorerKey,
               @cToToteNo
         END

         IF @nErrNo <> 0
         BEGIN
            GOTO Step_ShortPick_SkipReport
         END
         ELSE
         BEGIN
            UPDATE DROPID WITH (ROWLOCK)
            SET LabelPrinted = 'Y'
            WHERE Dropid = @cToToteNo
         END
      END  -- Print Tote Label

      Step_ShortPick_SkipReport:

      -- Check any remaining qty
      SELECT TOP 1
         @cConsigneeKey = O.ConsigneeKey,
         @cLOC = PD.LOC
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LOC l WITH (NOLOCK) ON l.LOC = PD.Loc
      WHERE PD.StorerKey = @cStorerKey
         AND PD.CaseID = @cCaseID
         AND PD.Status = '3'
         AND L.PutawayZone = @cPutawayZone -- (shong01)
      GROUP BY O.ConsigneeKey, PD.Loc

      -- If no more qty to sort for the particular consigneekey + loc
      IF @@ROWCOUNT = 0
      BEGIN
         -- Init screen
         SET @cOutField01 = ''
         SET @cOutField02 = ''

         -- initialise all variable
         SET @cCaseID       = ''
         SET @cToteNo       = ''

         -- (Vicky06) - Start
         SET @cConsigneekey = ''
         SET @cLOC          = ''
         SET @cSuggPTSLOC   = ''
         SET @cNextPTSLOC   = ''
         SET @cOrderKey     = ''
         SET @cSKU          = ''
         SET @cSKUDescr     = ''
         SET @cOption       = ''
         SET @cSKUscan      = ''
         SET @cLOCscan      = ''
         SET @cQTY          = ''
         SET @nCurScn       = 0
         SET @nCurStep      = 0
         SET @nQTY          = 0
         SET @nQtySuggest   = 0
         SET @nSumBOMQTY    = 0
         -- (Vicky06) - End

         -- Set the entry point
         SET @nScn  = @nScn_Case
         SET @nStep = @nStep_Case

         GOTO Quit
      END
      ELSE
      BEGIN
         -- (Vicky06) - Start
         -- If Suggested LOC in PickDetail is Full, then get the next available PTS LOC
         SET @cSuggPTSLoc = ''
         SET @cNextPTSLoc = ''

         SET @cSuggPTSLoc = @cLOC

         IF EXISTS (SELECT 1 FROM dbo.StoreToLOCDetail WITH (NOLOCK)
              WHERE LOC = @cLoc AND LocFull = 'Y')
         BEGIN
            SELECT TOP 1 @cNextPTSLoc = LOC
            FROM dbo.StoreToLOCDetail WITH (NOLOCK)
            WHERE ConsigneeKey = @cConsigneekey
            AND LocFull = 'N'

            IF ISNULL(RTRIM(@cNextPTSLoc), '') <> ''
            BEGIN
               SET @cLoc = @cNextPTSLoc
            END
         END
    -- (Vicky06) - End

         --prepare next screen variable
         SET @cOutField01 = @cConsigneekey
         SET @cOutField02 = @cLoc
         SET @cOutField03 = ''

         SET @nScn = @nScn_Loc
         SET @nStep = @nStep_Loc

         GOTO Quit
      END

      --prepare next screen variable
      SET @cOutField01 = @cCaseID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING(@cSKUDescr, 1,20)
      SET @cOutField04 = SUBSTRING(@cSKUDescr,21,40)
      SET @cOutField05 = ''
      SET @cOutField06 = RTRIM(CAST(@nRemain_Qty AS NVARCHAR( 5))) + '/' + CAST(@nTotal_QTY AS NVARCHAR( 5)) + @cUOM
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''

      SET @nScn = @nScn_Sku
      SET @nStep = @nStep_Sku

      GOTO Quit

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SELECT @nQtySuggest = ISNULL(SUM(QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      WHERE O.ConsigneeKey = @cConsigneekey
         AND PD.CaseID = @cCaseID
         AND PD.Status = '3'
         AND PD.LOC = @cSuggPTSLOC -- (Vicky06)
         --AND PD.LOC = @cLOC -- (Vicky03)

      --prepare next screen variable
      SET @cOutField01 = @cConsigneekey
      SET @cOutField02 = @cLoc
      SET @cOutField03 = @cUOM
      SET @cOutField04 = @nQtySuggest
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''

      SET @nScn = @nScn_Qty
      SET @nStep = @nStep_Qty

      SET @nScn = @nCurScn
      SET @nStep = @nCurStep
   END

   GOTO Quit

   Step_ShortPick_Fail:
   BEGIN
      SET @cReasonCode = ''
      SET @cOutField05 = '' -- RSN
   END

END
GOTO Quit

/********************************************************************************
Step 9. Scn = 2397.
   PTZONE (field01, input)
********************************************************************************/
Step_PTZone:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      SET @cPutawayZone = @cInField01
      SET @cPZ_LabelPrinter = @cInField02
      SET @cPZ_PaperPrinter = @cInField03

      IF ISNULL(RTRIM(@cPutawayZone),'') = ''
      BEGIN
         SET @nErrNo = 70599
         SET @cErrMsg = rdt.rdtgetmessage( 70599, @cLangCode, 'DSP') --'BAD PTZONE'
         GOTO Step_PTZone_Fail
      END

      IF NOT EXISTS(SELECT 1 FROM PutawayZone pz WITH (NOLOCK)
                    WHERE pz.PutawayZone = @cPutawayZone)
      BEGIN
       SET @nErrNo = 70599
         SET @cErrMsg = rdt.rdtgetmessage( 70599, @cLangCode, 'DSP') --'BAD PTZONE'
         GOTO Step_PTZone_Fail
      END

      -- If Paper printer scan in (james20)
      IF ISNULL(@cPZ_PaperPrinter, '') <> ''
      BEGIN
         -- Check if printer setup correctly
         IF NOT EXISTS(SELECT 1 FROM RDT.RDTPrinter (NOLOCK) WHERE PrinterID = RTRIM(@cPZ_PaperPrinter))
         BEGIN
            SET @nErrNo = 70615
            SET @cErrMsg = rdt.rdtgetmessage( 70615, @cLangCode, 'DSP') --'INV PAPER PRT'
            GOTO Step_PTZone_Fail
         END

         -- Overwrite existing printer with the one scanned in
         UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
            Printer_Paper = @cPZ_PaperPrinter
         WHERE MOBILE = @nMOBILE

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 71691
            SET @cErrMsg = rdt.rdtgetmessage( 71691, @cLangCode, 'DSP') --'UPD PRT FAIL'
            GOTO Step_PTZone_Fail
         END

         SET @cPrinter_Paper = @cPZ_PaperPrinter
      END

      -- If Paper printer scan in (james20)
      IF ISNULL(@cPZ_LabelPrinter, '') <> ''
      BEGIN
         -- Check if printer setup correctly
         IF NOT EXISTS(SELECT 1 FROM RDT.RDTPrinter (NOLOCK) WHERE PrinterID = RTRIM(@cPZ_LabelPrinter))
         BEGIN
            SET @nErrNo = 71692
            SET @cErrMsg = rdt.rdtgetmessage( 71692, @cLangCode, 'DSP') --'INV LABEL PRT'
            GOTO Step_PTZone_Fail
         END

         -- Overwrite existing printer with the one scanned in
         UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
            Printer = @cPZ_LabelPrinter
         WHERE MOBILE = @nMOBILE

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 71693
            SET @cErrMsg = rdt.rdtgetmessage( 71693, @cLangCode, 'DSP') --'UPD PRT FAIL'
            GOTO Step_PTZone_Fail
         END

         SET @cPrinter = @cPZ_LabelPrinter
      END

      -- (Vicky01) - Start
      IF ISNULL(@cPrinter_Paper, '') = ''
      BEGIN
         SET @nErrNo = 70518
         SET @cErrMsg = rdt.rdtgetmessage( 70518, @cLangCode, 'DSP') --NoPaperPrinter
         GOTO Step_PTZone_Fail
      END
      -- (Vicky01) - End

      -- Goto Tote Screen
      SET @nScn  = @nScn_Case
      SET @nStep = @nStep_Case

   END -- @nInputKey = 1
   IF @nInputKey = 0 --ESC
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cPutawayZone = ''
      SET @cOutField01  = '' -- PTZone
   END --ESC

   GOTO Quit

   Step_PTZone_Fail:
   BEGIN
      SET @cPutawayZone = ''
      SET @cOutField01 = '' -- PTZone
   END

END -- Step_PTZone
GOTO Quit

/********************************************************************************
Step 10. Scn = 2398.
   Store (field01)
   TOLOC (field02)
********************************************************************************/
Step_PPATOLOC:
BEGIN
   IF @nInputKey = 1 OR @nInputKey = 0--ENTER/ESC
   BEGIN
      -- initialise all variable
SET @cCaseID       = ''
      SET @cToteNo       = ''

      -- (Vicky06) - Start
      SET @cConsigneekey = ''
      SET @cLOC          = ''
      SET @cSuggPTSLOC   = ''
      SET @cNextPTSLOC   = ''
      SET @cOrderKey     = ''
      SET @cSKU          = ''
      SET @cSKUDescr     = ''
      SET @cOption       = ''
      SET @cSKUscan      = ''
      SET @cLOCscan      = ''
      SET @cQTY          = ''
      SET @nCurScn       = 0
      SET @nCurStep      = 0
      SET @nQTY          = 0
      SET @nQtySuggest   = 0
      SET @nSumBOMQTY    = 0
      -- (Vicky06) - End

      -- Init screen
      SET @cOutField01 = ''
      SET @cOutField02 = ''

      SET @nScn = @nScn_Case
      SET @nStep = @nStep_Case
      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
END
GOTO Quit

/********************************************************************************
 Step Get Next Screen..
********************************************************************************/
Step_GetNextScreen:
BEGIN
   SET @nQtySuggest = 0

   SELECT @nQtySuggest = ISNULL(SUM(QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK)
   JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
   JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
   WHERE O.ConsigneeKey = @cConsigneekey
      AND PD.CaseID = @cCaseID
      AND PD.Storerkey = @cStorerKey
      AND PD.SKU = @cSKU
      AND PD.Status = '3'
      AND PD.LOC = @cSuggPTSLOC -- (Vicky06)
      --AND PD.LOC = @cLOC

   IF @nQtySuggest > 0
   BEGIN
      --prepare next screen variable
      SET @cOutField01 = @cConsigneekey
      SET @cOutField02 = @cLoc
      SET @cOutField03 = @cUOM
      SET @cOutField04 = @nQtySuggest
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''

      SET @cESCKey = '0' -- (ChewKP02)

      SET @nScn  = @nScn_Qty
      SET @nStep = @nStep_Qty
      GOTO QUIT
   END
   ELSE
   BEGIN
      -- Get Next Consignee
      SET @cConsigneekey = ''
      SELECT TOP 1
             @cConsigneekey = ORDERS.ConsigneeKey,
             @cLoc          = PICKDETAIL.Loc,
             @nQtySuggest   = SUM(Qty)
      FROM dbo.ORDERS WITH (NOLOCK)
      JOIN dbo.PICKDETAIL WITH (NOLOCK) ON ORDERS.OrderKey = PICKDETAIL.OrderKey
      JOIN dbo.LOC WITH (NOLOCK) ON LOC.Loc = PICKDETAIL.Loc
      WHERE PICKDETAIL.CaseID    = @cCaseID
        AND PICKDETAIL.Storerkey = @cStorerKey
        AND PICKDETAIL.SKU       = @cSKU
        AND PICKDETAIL.[Status]  = '3'
        AND LOC.PutawayZone = @cPutawayZone
        AND EXISTS (SELECT 1 FROM dbo.StoreToLocDetail WITH (NOLOCK)
                   WHERE ORDERS.ConsigneeKey = StoreToLocDetail.ConsigneeKey
                     AND PICKDETAIL.LOC = StoreToLocDetail.LOC
                     AND STATUS = '1')
      GROUP BY LOC.LogicalLocation, PICKDETAIL.LOC, ORDERS.ConsigneeKey -- (james19)
      ORDER BY LOC.LogicalLocation, PICKDETAIL.LOC, ORDERS.ConsigneeKey -- (james19)

      IF ISNULL(RTRIM(@cConsigneekey),'') <> ''
      BEGIN

         -- (Vicky06) - Start
         -- If Suggested LOC in PickDetail is Full, then get the next available PTS LOC
         SET @cSuggPTSLoc = ''
         SET @cNextPTSLoc = ''

         SET @cSuggPTSLoc = @cLOC

         IF EXISTS (SELECT 1 FROM dbo.StoreToLOCDetail WITH (NOLOCK)
                    WHERE LOC = @cLoc AND LocFull = 'Y')
         BEGIN
            SELECT TOP 1 @cNextPTSLoc = LOC
            FROM dbo.StoreToLOCDetail WITH (NOLOCK)
            WHERE ConsigneeKey = @cConsigneekey
         AND LocFull = 'N'

            IF ISNULL(RTRIM(@cNextPTSLoc), '') <> ''
            BEGIN
               SET @cLoc = @cNextPTSLoc
            END
         END
         -- (Vicky06) - End

         --prepare next screen variable
         SET @cOutField01 = @cConsigneekey
         SET @cOutField02 = @cLoc
         SET @cOutField03 = @cUOM
         SET @cOutField04 = @nQtySuggest
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cOutField11 = ''

         SET @nScn = @nScn_Qty
         SET @nStep = @nStep_Qty

         SET @cESCKey = '0' -- (ChewKP02)


--         SET @cOutField01 = @cConsigneekey
--         SET @cOutField02 = @cLoc
--         SET @cOutField03 = ''
--         SET @cOutField04 = ''
--         SET @cOutField05 = ''
--         SET @cOutField06 = ''
--         SET @cOutField07 = ''
--         SET @cOutField08 = ''
--         SET @cOutField09 = ''
--         SET @cOutField10 = ''
--         SET @cOutField11 = ''
--
--         SET @nScn = @nScn_Loc
--         SET @nStep = @nStep_Loc

         GOTO QUIT
      END
      ELSE
      BEGIN
         SET @cSKU = ''
         SET @cConsigneekey=''
         SET @cLOC = ''

         SELECT TOP 1
               @cSKU       = PICKDETAIL.Sku,
                @cSKUDescr  = SKU.DESCR,
                @cConsigneekey = ORDERS.ConsigneeKey,
                @cLoc          = PICKDETAIL.Loc
         FROM dbo.PICKDETAIL WITH (NOLOCK)
         JOIN dbo.ORDERS WITH (NOLOCK) ON PICKDETAIL.OrderKey = ORDERS.OrderKey
         JOIN dbo.SKU WITH (NOLOCK) ON PICKDETAIL.StorerKey = SKU.StorerKey AND PICKDETAIL.Sku = SKU.Sku
         JOIN dbo.LOC WITH (NOLOCK) ON LOC.Loc = PICKDETAIL.Loc
         WHERE PICKDETAIL.CaseID    = @cCaseID
           AND PICKDETAIL.Storerkey = @cStorerKey
           AND PICKDETAIL.SKU       = @cSKU
           AND PICKDETAIL.[Status]  = '3'
           AND LOC.PutawayZone = @cPutawayZone
           AND EXISTS (SELECT 1 FROM dbo.StoreToLocDetail WITH (NOLOCK)
                       WHERE ORDERS.ConsigneeKey = StoreToLocDetail.ConsigneeKey
                        AND PICKDETAIL.LOC = StoreToLocDetail.LOC
                        AND STATUS = '1')
--         ORDER BY ORDERS.ConsigneeKey, PICKDETAIL.LOC
         ORDER BY LOC.LogicalLocation, LOC.LOC, ORDERS.ConsigneeKey  -- (james19)

         IF ISNULL(RTRIM(@cConsigneekey),'') <> '' AND ISNULL(RTRIM(@cSKU),'') <> ''
         BEGIN
            SET @cSuggPTSLoc = ''
            SET @cNextPTSLoc = ''

            SET @cSuggPTSLoc = @cLOC

            IF EXISTS (SELECT 1 FROM dbo.StoreToLOCDetail WITH (NOLOCK)
                       WHERE LOC = @cLoc AND LocFull = 'Y')
            BEGIN
               SELECT TOP 1 @cNextPTSLoc = LOC
               FROM dbo.StoreToLOCDetail WITH (NOLOCK)
               WHERE ConsigneeKey = @cConsigneekey
               AND LocFull = 'N'

               IF ISNULL(RTRIM(@cNextPTSLoc), '') <> ''
               BEGIN
                  SET @cLoc = @cNextPTSLoc
               END
            END

            SELECT @nTotal_QTY = ISNULL(SUM(Qty), 0)
            FROM dbo.UCC WITH (NOLOCK)
            WHERE UCCNo = @cCaseID
              AND Storerkey = @cStorerKey
              AND SKU = @cSKU

            SELECT @nRemain_Qty = ISNULL(SUM(PICKDETAIL.Qty), 0)
            FROM dbo.PickDetail WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON LOC.LOC = PICKDETAIL.LOC
            WHERE PICKDETAIL.CaseID = @cCaseID
               AND PICKDETAIL.Storerkey = @cStorerKey
               AND PICKDETAIL.SKU = @cSKU
               AND PICKDETAIL.Status = '3'
               AND LOC.PutawayZone = @cPutawayZone
               AND PICKDETAIL.LOC = @cSuggPTSLoc

            IF @nRemain_Qty > 0
            BEGIN
               --prepare next screen variable
               SET @cOutField01 = @cCaseID
               SET @cOutField02 = @cSKU
               SET @cOutField03 = SUBSTRING(@cSKUDescr, 1,20)
               SET @cOutField04 = SUBSTRING(@cSKUDescr,21,40)
               SET @cOutField05 = ''
               SET @cOutField06 = RTRIM(CAST(@nRemain_Qty AS NVARCHAR( 5))) + '/' + CAST(@nTotal_QTY AS NVARCHAR( 5)) + @cUOM
               SET @cOutField07 = ''
               SET @cOutField08 = ''
               SET @cOutField09 = ''
               SET @cOutField10 = ''
               SET @cOutField11 = ''

               SET @nScn = @nScn_Sku
               SET @nStep = @nStep_Sku
            END
         END  -- ISNULL(RTRIM(@cConsigneekey),'') <> '' AND ISNULL(RTRIM(@cSKU),'') <> ''
         ELSE
         BEGIN
            -- (james15)
            SELECT @nRemain_Qty = ISNULL(SUM(PICKDETAIL.Qty), 0)
            FROM dbo.PickDetail WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON LOC.LOC = PICKDETAIL.LOC
            WHERE PICKDETAIL.CaseID = @cCaseID
               AND PICKDETAIL.Storerkey = @cStorerKey
               AND PICKDETAIL.Status = '3'

            IF @nRemain_Qty = 0
            BEGIN
               IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                          WHERE StorerKey = @cStorerKey
                             AND TaskType = 'PA'
                             AND CaseID = @cCaseID
                             AND Status = '0')
               BEGIN
                  SET @nCaseEmpty = 0
               END
               ELSE
               BEGIN
                  SET @nCaseEmpty = 1
               END
            END
            ELSE
            BEGIN
               SET @nCaseEmpty = 0
            END

            -- (james25)
            IF @nRemain_Qty = 0
            BEGIN
               SET @cDropID2Close = ''
               SELECT @cDropID2Close = D.DropID
               FROM dbo.DropIDDetail DD WITH (NOLOCK)
               JOIN dbo.DropID D WITH (NOLOCK) ON DD.DropID = D.DropID
               WHERE DD.ChildID = @cCaseID
               AND   D.DropIDType = 'C'
               AND   D.Status = '5'

               IF ISNULL( @cDropID2Close, '') <> ''
               BEGIN
                  UPDATE DropID WITH (ROWLOCK) SET
                     [Status] = '9'
                  WHERE DropID = @cDropID2Close
                  AND   DropIDType = 'C'
                  AND   [Status] = '5'

                  -- (james31)
                  IF rdt.RDTGetConfig( @nFunc, 'PTSReleasePATask', @cStorerKey) = '1'
                     UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
                        Status = '0',
                        EditWho = @cUserName,
                        EditDate = GETDATE(),
                        TrafficCop = NULL
                     WHERE StorerKey = @cStorerKey
                        AND TaskType = 'PA'
                        AND CaseID = @cCaseID
                        AND Status = 'W'
                  ELSE
                     UPDATE dbo.TaskDetail WITH (ROWLOCK) SET
                        Status = '9',
                        EditWho = @cUserName,
                        EditDate = GETDATE(),
                        TrafficCop = NULL
                     WHERE StorerKey = @cStorerKey
                        AND TaskType = 'PA'
                        AND CaseID = @cCaseID
                        AND Status IN ('0', 'W')

                  UPDATE rdt.rdtdpklog_bak WITH (ROWLOCK) SET
                     CaseID = ''
                  WHERE  CaseID = @cCaseID
               END

               -- (james29)
               IF EXISTS ( SELECT 1 FROM dbo.DropIDDetail DD WITH (NOLOCK)
                           JOIN dbo.DropID D WITH (NOLOCK) ON DD.Dropid = D.DropID
                           WHERE ChildID = @cCaseID
                           AND   DropIDType = 'C'
                           AND   [Status] = '9')
               BEGIN
                  IF NOT EXISTS ( SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK)
                                  WHERE ChildID = SUBSTRING( (RTRIM( @cCaseID) + '_' + @cToToteNo), 1 , 20))
                  BEGIN
                     UPDATE DD WITH (ROWLOCK) SET
                        ChildID = SUBSTRING( (RTRIM( ChildID) + '_' + @cToToteNo), 1 , 20)
                     FROM dbo.DropIDDetail DD
                     JOIN dbo.DropID D ON DD.Dropid = D.DropID
                     WHERE ChildID = @cCaseID
                     AND   DropIDType = 'C'
                     AND   [Status] = '9'
                  END
               END
            END

            IF rdt.RDTGetConfig( @nFunc, 'PTS_INITIAL_SCN', @cStorerKey) = 1
            BEGIN
               SET @nRemain_Qty = 0
               SELECT @nRemain_Qty = ISNULL(SUM(PICKDETAIL.Qty), 0)
               FROM dbo.PickDetail WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON LOC.LOC = PICKDETAIL.LOC
               WHERE PICKDETAIL.CaseID = @cCaseID
                  AND PICKDETAIL.Storerkey = @cStorerKey
                  AND PICKDETAIL.Status = '3'

               IF @nRemain_Qty = 0
               BEGIN
--                  UPDATE dbo.UCC WITH (ROWLOCK) SET
--                     [Status] = '6'
--                  WHERE UCCNo = @cCaseID
--                  AND   [Status] <= '4'
--                  AND   StorerKey = @cStorerKey

                  SET @cCaseID_New = ''
                  SELECT TOP 1
                     @cCaseID_New = UCCNo
                  FROM UCC WITH (NOLOCK)
                  WHERE UCCNo LIKE RTRIM(@cCaseID) + '[0-9][0-9][0-9][0-9]'
                  ORDER BY UCCNo DESC

                  IF ISNULL(RTRIM(@cCaseID_New),'') = ''
                     SET @cCaseID_New = RTRIM(@cCaseID) + '0001'
                  ELSE
                  BEGIN
                     SET @nNextCaseIDSeqNo = CAST( RIGHT(RTRIM(@cCaseID_New),4) AS INT ) + 1
                     SET @cCaseID_New = RTRIM(@cCaseID) + RIGHT('0000' + CONVERT(VARCHAR(4), @nNextCaseIDSeqNo), 4)
                  END

                  UPDATE dbo.UCC WITH (ROWLOCK) SET
                     UCCNo = @cCaseID_New,
                     [Status]  = '6'
                  WHERE UCCNo = @cCaseID
                  AND   [Status] <= '6'
                  AND   StorerKey = @cStorerKey
               END

               SET @cOutField01 = ''

               -- Goto Tote Screen
               SET @nFunc = 1811
               SET @nScn  = 3941
               SET @nStep = 2

               GOTO Quit
            END

            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = CASE WHEN @nCaseEmpty = 0
                               THEN 'PUT CASE TO CONVEYOR'
                               ELSE 'CASE IS EMPTY'
                               END
--            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = ''
            SET @cOutField06 = ''
            SET @cOutField07 = ''
            SET @cOutField08 = ''
            SET @cOutField09 = ''
            SET @cOutField10 = ''
            SET @cOutField11 = ''

            SET @cConsigneekey = ''
            SET @cLOC          = ''

            -- (Vicky06) - Start
            SET @cSuggPTSLOC   = ''
            SET @cNextPTSLOC   = ''
            SET @cCaseID       = ''
            SET @cToteNo       = ''
            SET @cOrderKey     = ''
            SET @cSKU          = ''
            SET @cSKUDescr     = ''
            SET @cOption       = ''
            SET @cSKUscan      = ''
            SET @cLOCscan      = ''
            SET @cQTY          = ''
            SET @nCurScn       = 0
            SET @nCurStep      = 0
            SET @nQTY          = 0
            SET @nQtySuggest   = 0
            SET @nSumBOMQTY    = 0
            -- (Vicky06) - End

            SET @nScn = @nScn_Case
            SET @nStep = @nStep_Case

            -- (ChewKP02) -- SignOut when there is nothing left
--            EXEC RDT.rdt_STD_EventLog
--             @cActionType = '9', -- Sign Out function
--             @cUserID     = @cUserName,
--             @nMobileNo   = @nMobile,
--             @nFunctionID = @nFunc,
--             @cFacility   = @cFacility,
--             @cStorerKey  = @cStorerkey

         END
      END
 END
END
GOTO Quit

/********************************************************************************
Step 6. screen = 2399
   TOTE OPEN IN LOC (Field01, input)
   1 = YES
   9 = NO
********************************************************************************/
Step_OpenTote:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      IF @cOption = ''
      BEGIN
         SET @nErrNo = 71696
         SET @cErrMsg = rdt.rdtgetmessage( 71696, @cLangCode, 'DSP') --Option req
         GOTO Step_OpenTote_Fail
      END

      IF @cOption <> '1' AND @cOption <> '9'
      BEGIN
         SET @nErrNo = 71697
         SET @cErrMsg = rdt.rdtgetmessage( 71697, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_OpenTote_Fail
      END

      IF @cOption = '1'
      BEGIN
         IF @nQty < @nQtySuggest
         BEGIN
            IF rdt.RDTGetConfig( @nFunc, 'SHOWSHTPICKRSN', @cStorerKey) = 1
            BEGIN
               -- Save current screen no
               SET @nCurScn = @nScn
               SET @nCurStep = @nStep

               -- Go to STD short pick screen
               SET @nScn = @nSCN_ShortPick
               SET @nStep = @nStep_ShortPick

               SELECT @cOutField01 = ISNULL(SUM(Qty), 0)
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND CaseID = @cCaseID
                  AND SKU = @cSKU
                  AND Status = '3'

               SELECT @cOutField02 = PackUOM3
               FROM dbo.Pack P WITH (NOLOCK)
               JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.PackKey = P.PackKey
               WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU

               SET @cOutField03 = ''
               SET @cOutField04 = ''
               SET @cOutField05 = ''

               GOTO Quit
            END
         END -- @nQty < @nQtySuggest
         ELSE
         BEGIN
            -- @nQty = @nQtySuggest  (Full Pick)
            -- Confirm Tote Here
            SET @b_Success = 1

            EXEC [RDT].[rdt_PTS_ConfirmTote]
                @nMobile         =@nMobile
               ,@cStorerKey      =@cStorerKey
               ,@cCaseID         =@cCaseID
               ,@cLOC            =@cLOC
               ,@cSKU            =@cSKU
               ,@cConsigneeKey   =@cConsigneekey
               ,@nQtyEnter       =@nQTY
               ,@cToToteNo       =@cToToteNo
               ,@cShortPick      ='N'
               ,@bSuccess        =@b_success OUTPUT
               ,@nErrNo          =@nErrNo    OUTPUT
               ,@cErrMsg         =@cErrMsg   OUTPUT
               ,@cSuggLOC        =@cSuggPTSLOC -- (Vicky06)


            IF @b_success <> 1
            BEGIN
               EXEC rdt.rdtSetFocusField @nMobile, 5
               GOTO Step_OpenTote_Fail
            END

            SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
            IF @cExtendedUpdateSP = '0'
               SET @cExtendedUpdateSP = ''

            -- Extended update
            IF @cExtendedUpdateSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY, @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                  SET @cSQLParam =
                     '@nMobile         INT,       '     +
                     '@nFunc           INT,       '     +
                     '@cLangCode       NVARCHAR( 3),  ' +
                     '@nStep           INT,       '     +
                     '@nInputKey       INT,       '     +
                     '@cStorerKey      NVARCHAR( 15), ' +
                     '@cCaseID         NVARCHAR( 18), ' +
                     '@cLOC            NVARCHAR( 10), ' +
                     '@cSKU            NVARCHAR( 20), ' +
                     '@cConsigneekey   NVARCHAR( 15), ' +
                     '@nQTY            INT,        '    +
                     '@cToToteNo       NVARCHAR( 18), ' +
                     '@cSuggPTSLOC     NVARCHAR( 10), ' +
                     '@nErrNo          INT OUTPUT,    ' +
                     '@cErrMsg         NVARCHAR( 20) OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY, @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO Step_OpenTote_Fail
               END
            END

            -- insert to Eventlog
            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '4',
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerkey,
               @nQty          = @nQTY,           -- (james04)
               @cRefNo1       = @cToToteNo,
               @cConsigneekey = @cConsigneekey,
               --@cRefNo2       = @cConsigneekey   -- (james07)
               @nStep         = @nStep


             -- (ChewKP02)
             EXEC RDT.rdt_STD_EventLog
                @cActionType = '9', -- Sign Out function
                @cUserID     = @cUserName,
                @nMobileNo   = @nMobile,
                @nFunctionID = @nFunc,
                @cFacility   = @cFacility,
                @cStorerKey  = @cStorerkey,
                @cRefNo1     = @cToToteNo,
                @cRefNo2     = '',
                @nStep       = @nStep




--            IF NOT EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK) WHERE DropID = @cToToteNo
--                          AND LabelPrinted = 'Y')
--            BEGIN
--               -- Added by SHONG on 30-Nov-2011 (SHONGxx)
--               -- Insert to Event Log for when all qty had been dispatched to stores
--               EXEC RDT.rdt_STD_EventLog
--                @cActionType = '1', -- Sign Out function
--                @cUserID     = @cUserName,
--                @nMobileNo   = @nMobile,
--                @nFunctionID = @nFunc,
--                @cFacility   = @cFacility,
--                @cStorerKey  = @cStorerkey,
--                @cRefNo1     = @cToToteNo,
--                @cRefNo2     = 'OPEN TOTE'
--            END

            -- insert to Eventlog
--            EXEC RDT.rdt_STD_EventLog
--               @cActionType   = '4',
--               @cUserID       = @cUserName,
--               @nMobileNo     = @nMobile,
--               @nFunctionID   = @nFunc,
--               @cFacility     = @cFacility,
--               @cStorerKey    = @cStorerkey,
--               @nQty          = @nQTY,           -- (james04)
--               @cRefNo1       = @cToToteNo,
--               @cRefNo2       = @cConsigneekey   -- (james07)

            -- If everything in this case is picked (james09)
            IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                           WHERE StorerKey = @cStorerKey
                              AND CASEID = @cCaseID
                              AND Status < '5')
            BEGIN
               -- If we have PA task for this case (residual from DPK) in 'W' status
               -- then release it (james09)
               IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                          WHERE StorerKey = @cStorerKey
                             AND TaskType = 'PA'
                             AND CaseID = @cCaseID
                             AND Status = 'W')
               BEGIN
                  BEGIN TRAN

                  UPDATE dbo.TaskDetail SET
                     Status = '0',
                     EditWho = @cUserName,
                     EditDate = GETDATE(),
                   TrafficCop = NULL
                  WHERE StorerKey = @cStorerKey
                     AND TaskType = 'PA'
                     AND CaseID = @cCaseID
                     AND Status = 'W'

                  IF @@ERROR <> 0
                  BEGIN
                     ROLLBACK TRAN
                     SET @nErrNo = 70606
                     SET @cErrMsg = rdt.rdtgetmessage( 70606, @cLangCode, 'DSP') --ReleasePAFail
                      EXEC rdt.rdtSetFocusField @nMobile, 5
                     GOTO Step_OpenTote_Fail
                  END
                  ELSE
                  BEGIN
                     COMMIT TRAN
                  END
               END
            END
         END

         IF NOT EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK) WHERE DropID = @cToToteNo
                       AND LabelPrinted = 'Y')
         BEGIN
            -- Printing process
            IF ISNULL(@cPrinter, '') = ''
            BEGIN
               GOTO Step_OpenTote_SkipReport
            END

            SET @cExtendedPrintSP = rdt.rdtGetConfig( @nFunc, 'ExtendedPrintSP', @cStorerKey)
            IF @cExtendedPrintSP = '0'
               SET @cExtendedPrintSP = ''

            -- Extended update
            IF @cExtendedPrintSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPrintSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPrintSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY,
                       @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                  SET @cSQLParam =
                     '@nMobile         INT, '            +
                     '@nFunc           INT, '            +
                     '@cLangCode       NVARCHAR( 3), '   +
                     '@nStep           INT, '            +
                     '@nInputKey       INT, '            +
                     '@cStorerKey      NVARCHAR( 15), '  +
                     '@cCaseID         NVARCHAR( 18), '  +
                     '@cLOC            NVARCHAR( 10), '  +
                     '@cSKU            NVARCHAR( 20), '  +
                     '@cConsigneekey   NVARCHAR( 15), '  +
                     '@nQTY            INT, '  +
                     '@cToToteNo       NVARCHAR( 18), '  +
                     '@cSuggPTSLOC     NVARCHAR( 10), '  +
                     '@nErrNo          INT   OUTPUT, '   +
                     '@cErrMsg         NVARCHAR( 20)  OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY,
                     @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     GOTO Step_OpenTote_SkipReport
                  END
               END
            END
            ELSE
            BEGIN
               SET @cReportType = 'SORTLABEL'
               SET @cPrintJobName = 'PRINT_SORTLABEL'

               SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                      @cTargetDB = ISNULL(RTRIM(TargetDB), '')
               FROM RDT.RDTReport WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   ReportType = @cReportType

               IF ISNULL(@cDataWindow, '') = ''
               BEGIN
                  GOTO Step_OpenTote_SkipReport
               END

               IF ISNULL(@cTargetDB, '') = ''
               BEGIN
                  GOTO Step_OpenTote_SkipReport
               END

               SET @nErrNo = 0
               EXEC RDT.rdt_BuiltPrintJob
                  @nMobile,
                  @cStorerKey,
                  @cReportType,
                  @cPrintJobName,
                  @cDataWindow,
                  @cPrinter,
                  @cTargetDB,
                  @cLangCode,
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT,
                  @cStorerKey,
                  @cToToteNo
            END

            IF @nErrNo <> 0
            BEGIN
               GOTO Step_OpenTote_SkipReport
            END
            ELSE
            BEGIN
               UPDATE DROPID WITH (ROWLOCK)
               SET LabelPrinted = 'Y'
               WHERE Dropid = @cToToteNo
            END
         END  -- Print Tote Label
         Step_OpenTote_SkipReport:

         GOTO Step_GetNextScreen
      END
      ELSE
      BEGIN
         SET @cDefaultPTSAction  = rdt.RDTGetConfig( @nFunc, 'DefaultPTSAction', @cStorerKey)

         --prepare next screen variable
         SET @cOutField01 = @cConsigneekey
         SET @cOutField02 = @cLoc
         SET @cOutField03 = @cUOM
         SET @cOutField04 = @nQTY
         SET @cOutField05 = ''
         SET @cOutField06 = CASE WHEN @nQty < CAST(@cSuggestQTY AS INT) THEN ''
                                 ELSE @cDefaultPTSAction END -- (james19) '' --'9'   -- (Vicky04)
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cOutField11 = ''

         SET @nScn = @nCurScn
         SET @nStep = @nCurStep
         EXEC rdt.rdtSetFocusField @nMobile, 1

         GOTO Quit
      END
   END

   Step_OpenTote_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = ''

      GOTO Quit
   END
END
GOTO QUIT

/********************************************************************************
Step 12. screen = 2700
   TOTE NO  (Field01)
   SKU      (Field02)
   OPTION   (Field03, input)
********************************************************************************/
Step_ConfirmTote:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField03

      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 71698
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req
         GOTO Step_ConfirmTote_Fail
      END

      -- Validate blank
      IF @cOption NOT IN ('1', '9')
      BEGIN
         SET @nErrNo = 71699
       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_ConfirmTote_Fail
      END

      IF @cOption = '1'
      BEGIN
         SET @nScn = @nCurScn
         SET @nStep = @nCurStep

         SELECT @cModuleName = Message_Text FROM RDT.RDTMSG WITH (NOLOCK) WHERE Message_ID = @nFunc
         SET @cAlertMessage = 'Confirm Tote ' + LTRIM(RTRIM(@cToToTeNo)) + ' Same As SKU by ' + LTRIM(RTRIM(@cUserName)) + '.'

         -- Insert LOG Alert
         SELECT @bSuccess = 1
         EXECUTE dbo.nspLogAlert
          @c_ModuleName   = @cModuleName,
          @c_AlertMessage = @cAlertMessage,
          @n_Severity     = 0,
          @b_success      = @bSuccess OUTPUT,
          @n_err          = @nErrNo OUTPUT,
          @c_errmsg       = @cErrmsg OUTPUT

         IF NOT @bSuccess = 1
         BEGIN
            GOTO Step_ConfirmTote_Fail
         END

         GOTO Continue_Step_ToTote
      END
      ELSE
      BEGIN
         SET @cDefaultPTSAction  = rdt.RDTGetConfig( @nFunc, 'DefaultPTSAction', @cStorerKey)

         --prepare next screen variable
         SET @cOutField01 = @cConsigneekey
         SET @cOutField02 = @cLoc
         SET @cOutField03 = @cUOM
         SET @cOutField04 = @nQTY
         SET @cOutField05 = ''
         SET @cOutField06 = CASE WHEN @nQty < CAST(@cSuggestQTY AS INT) THEN ''
                                 ELSE @cDefaultPTSAction END -- (james19) '' --'9'   -- (Vicky04)
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         SET @cOutField11 = ''

         SET @nScn  = @nScn_ToTote
         SET @nStep = @nStep_ToTote
         EXEC rdt.rdtSetFocusField @nMobile, 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cDefaultPTSAction  = rdt.RDTGetConfig( @nFunc, 'DefaultPTSAction', @cStorerKey)

      --prepare next screen variable
      SET @cOutField01 = @cConsigneekey
      SET @cOutField02 = @cLoc
      SET @cOutField03 = @cUOM
      SET @cOutField04 = @nQTY
      SET @cOutField05 = ''
      SET @cOutField06 = CASE WHEN @nQty < CAST(@cSuggestQTY AS INT) THEN ''
                              ELSE @cDefaultPTSAction END -- (james19) '' --'9'   -- (Vicky04)
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''
      SET @cOutField11 = ''

      SET @nScn  = @nScn_ToTote
      SET @nStep = @nStep_ToTote
      EXEC rdt.rdtSetFocusField @nMobile, 1
   END
   GOTO Quit

   Step_ConfirmTote_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField03 = ''
   END
END
GOTO Quit
/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate      = GETDATE(),
      ErrMsg        = @cErrMsg,
      Func          = @nFunc,
      Step          = @nStep,
      Scn           = @nScn,

      StorerKey     = @cStorerKey,
      Facility      = @cFacility,
      Printer       = @cPrinter,
      Printer_Paper = @cPrinter_Paper,   -- (Vicky01)
      -- UserName      = @cUserName,

      V_Integer1     = @nQTY,
      V_Integer2     = @nQtySuggest,
      V_Integer3     = @nSumBOMQTY,
      V_Integer4     = @nCurScn,
      V_Integer5     = @nCurStep,

      V_ConsigneeKey = @cConsigneekey,
      V_Loc          = @cLOC,
      V_OrderKey     = @cOrderKey,
      V_CaseID       = @cCaseID,
      V_SKU          = @cSKU,
      V_SKUDescr   = @cSKUDescr,
      --V_QTY          = @nQTY,
      V_UOM          = @cUOM,
      V_String1      = @cOption,
      V_String2      = @cSKUscan,
      --V_String3      = @nQtySuggest,
      --V_String4      = @nSumBOMQTY,
      V_String5      = @cLOCscan,
      V_String6      = @cToteNo,
      --V_String7      = @nCurScn,
      --V_String8      = @nCurStep,
      V_String9      = @cToToteNo,
      V_Zone         = @cPutawayZone,
      V_String10     = @cSuggPTSLoc, -- (Vicky06)
      V_String11     = @cNextPTSLoc, -- (Vicky06)
      V_String12     = @cDefaultPTSAction,   -- (james19)
      V_String13     = @cDefaultToteLength,  -- (james20)
      V_String14     = @cEscKey, -- (ChewKP02)

      V_String32     = @cV_String32, -- SOS# 228674
      V_String34     = @cV_String34, -- SOS# 228674

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,

      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,
      FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile

END

GO