SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: RDT Generate GS1 Label By DropID 159898                           */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 20-01-2010 1.0  ChewKP     Created                                         */
/* 27-02-2010 1.1  Vicky      Bug Fixes (Vicky01)                             */
/* 01-03-2010 1.1  ChewKP     PackConfirm join by DROPID (ChewKP01)           */
/* 01-03-2010 1.1  ChewKP     Rework PackConfirm  (ChewKP02)                  */
/* 01-03-2010 1.2  Vicky      Only Pack Confirm and Scan Out when             */
/*                            PackQty = PickQty (Vicky02)                     */
/* 05-03-2010 1.3  Vicky      LoadplanLaneDetail should check by Loadkey only */
/*                            (Vicky03)                                       */
/* 11-03-2010 1.4  Vicky      @cTemplateID should be in the loop of Orderkey  */
/*                            (Vicky04)                                       */
/* 11-03-2010 1.4  Vicky      PrinterID should be 20 char (Vicky05)           */
/* 11-03-2010 1.5  ChewKP     Fix error when PrinterID > 10 Char (ChewKP03)   */
/* 12-03-2010 1.6  Vicky      Retain PrinterID when printing DropID (Vicky06) */
/* 12-03-2010 1.7  Vicky      Variables should be reset (Vicky07)             */
/* 16-03-2010 1.8  ChewKP     Fix PackHeader Carton Calculation double up     */
/*                            issues (ChewKP04)                               */
/* 17-03-2010 1.9  Vicky      Add in validation on DropID.Status. Can only    */
/*                            print when Status = '3' (Vicky08)               */
/* 19-03-2010 2.0  Vicky      Update Pickdetail.PickSlipno when creating P/S  */
/*                            from here (Vicky09)                             */
/* 30-04-2010 2.1  Vicky      Add validation to check the matching of         */
/*                            PackDetail QTY and PickDetail QTY (Vicky10)     */
/* 28-07-2010 2.2  Leong      SOS# 183480 - Performance Trace                 */
/* 03-08-2010 2.3  Vicky      Revamp Error Message (Vicky11)                  */
/* 22-06-2011 2.4  ChewKP     SOS#219051 - Carter for Non BOM (ChewKP05)      */
/* 08-10-2011 2.5  James      Temp disable auto scan out. (jamesxx)           */
/* 10-02-2012 2.6  Shong01    Performance Tuning                              */
/* 16-04-2012 2.7  ChewKP     SOS#238872-AllowMultiStorer/LoadPLan (ChewKP06) */
/* 03-06-2014 2.8  SPChin     SOS305919 - Bug Fixed                           */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_Print_GS1_Carton_Label] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_WARNINGS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @cOption     NVARCHAR( 1),
   @nCount      INT,
   @nRowCount   INT

-- RDT.RDTMobRec variable
DECLARE
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5),
   @cPrinter   NVARCHAR( 20), -- (Vicky05)
   @cUserName  NVARCHAR( 18),

   @nError     INT,
   @b_success  INT,
   @n_err      INT,
   @c_errmsg   NVARCHAR( 250),

   @cOrderKey     NVARCHAR( 10),
   @cLoadKey      NVARCHAR( 10),

   @cUPC                NVARCHAR( 30),
   @cUPC_SKU            NVARCHAR( 20),
   @cSKUCode            NVARCHAR( 20),
   @cSKU                NVARCHAR( 20),
   @cSKU1               NVARCHAR( 20),
   @cSKU2               NVARCHAR( 20),
   @cSuggestedSKU       NVARCHAR( 20),
   @cDescr              NVARCHAR( 60),
   @cSKU_Descr1         NVARCHAR( 60),
   @cSKU_Descr2         NVARCHAR( 60),
   @nQty              INT,
   @cPickDetailKey      NVARCHAR( 18),
   @cStatus             NVARCHAR( 10),
   @cPickSlipNo         NVARCHAR( 10),
   @cDropID             NVARCHAR( 18),
   @cLogicalLocation  NVARCHAR( 18),
   @cFilePath           NVARCHAR( 30),
   @cFilePath1          NVARCHAR( 20),
   @cFilePath2          NVARCHAR( 20),
   @cGS1TemplatePath    NVARCHAR( 120),
   @cGS1TemplatePath1   NVARCHAR( 20), -- (Vicky03)
   @cGS1TemplatePath2   NVARCHAR( 20), -- (Vicky03)
   @cGS1TemplatePath3   NVARCHAR( 20), -- (Vicky03)
   @cGS1TemplatePath4   NVARCHAR( 20), -- (Vicky03)
   @cGS1TemplatePath5   NVARCHAR( 20), -- (Vicky03)
   @cGS1TemplatePath6   NVARCHAR( 20), -- (Vicky03)
   @cGS1TemplatePath_Gen   NVARCHAR( 120), -- (Vicky03)
   @cGS1TemplatePath_Final NVARCHAR( 120), -- (Vicky03)

   @cPickSlipType       NVARCHAR( 10),
   @cPickHeaderKey      NVARCHAR( 10),
   @cMBOLKey            NVARCHAR( 10),
   @cBuyerPO            NVARCHAR( 20),
   @cTemplateID         NVARCHAR( 20),
   @cGenTemplateID      NVARCHAR( 20), -- (Vicky03)
   @nCartonNo           INT,
   @nPrevCartonNo       INT,
   @cLabelNo            NVARCHAR( 20),
   @cQty                NVARCHAR( 5),
   @cComponentSku       NVARCHAR( 20),
   @cQtyAlloc1          NVARCHAR( 5),
   @cQtyAlloc2          NVARCHAR( 5),
   @cQtyScan1           NVARCHAR( 5),
   @cQtyScan2           NVARCHAR( 5),
   @cFileName           NVARCHAR( 215),
   @cPriority           NVARCHAR( 10),
   @cDiscrete_PickSlipNo NVARCHAR( 10),

   @nPickDSKUQty        INT,
   @nPackDSKUQty        INT,
   @nTotalLoc           INT,
   @nPickedLoc          INT,
   @cSuggestedLoc       NVARCHAR( 10),
   @cNewSuggestedLoc    NVARCHAR( 10),
   @nRemainingTask      INT,
   @nSKUCnt             INT,
   @cPUOM               NVARCHAR( 1),
   @nPackDQty           INT,
   @nPickDQty           INT,
   @cCheckPickB4Pack    NVARCHAR( 1),
   @cGSILBLITF          NVARCHAR( 1),
   @cPrepackByBOM       NVARCHAR( 1),
   @cAutoPackConfirm    NVARCHAR( 1),
   @nCasePackDefaultQty INT,
   @nComponentQTY       INT,
   @nPages              INT,
   @nTotalPages         INT,
   @nCnt                FLOAT,   -- change to float coz wanna use ceiling
   @nTotalCnt           INT,
   @nDummyQty           INT,
   @nqtypicked          INT,
   @nqtypacked          INT,

   @cErrMsg1            NVARCHAR( 20),
   @cErrMsg2            NVARCHAR( 20),
   @cErrMsg3            NVARCHAR( 20),
   @cErrMsg4            NVARCHAR( 20),
   @cErrMsg5            NVARCHAR( 20),

   -- Vicky01 - (Start)
   @cInOrderKey         NVARCHAR(10),
   @cPDLot              NVARCHAR(10),
   @cParentSKU          NVARCHAR(20),
   @cSkipQTYScn         NVARCHAR( 1),
   @nPDQTY              INT,
   @nUPCCaseCnt         INT,
   @nTotalBOMQty        INT,
   @nLotCtns            INT,
   @nTotalCtns          INT,
   @nTotalCtnsALL       INT,
   -- Vicky01 - (End)

   -- Vicky02 - (Start)
   @cUPC_Packkey        NVARCHAR(10),
   @nCaseCnt            INT,
   -- Vicky02 - (End)

   @cTemp_OrderKey      NVARCHAR( 10), -- James
   @n_TotalCnts         INT,
   @cTaskDetailKey      NVARCHAR( 10),
   @c_LoosePick         NVARCHAR( 1),
   @n_TotalLoop         INT,
   @cPDSKU              NVARCHAR( 20),
   @cPDPackkey          NVARCHAR( 10),
   @n_CaseCnt           INT,
   @n_PrePack           INT,
   @c_ALTSKU            NVARCHAR( 20),
   @cDischargePlace     NVARCHAR( 20),
   @cPalletID           NVARCHAR( 10),
   @cLLLoadkey          NVARCHAR( 10),
   @cLLExternOrderkey   NVARCHAR( 20),
   @cLLConsigneeKey     NVARCHAR( 15),
   @cLLLP_LaneNumber    NVARCHAR( 5),
   @cLLLOC              NVARCHAR( 10),
   @cLLLLocCat  NVARCHAR( 10),
   @cPackCheck          NVARCHAR(  1),
   @nTranCount          INT,
   @nSetTemplate        INT,
   @cMyError            NVARCHAR( 20),
   @cWCSFilePath1       NVARCHAR( 50),
   @nESCCheck           INT,

   -- (Vicky10) - Start
   @nPackDetailQTY      INT,
   @nPickDetailQTY      INT,
   -- (Vicky10) - End

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
   @cFieldAttr15 NVARCHAR( 1)

-- Load RDT.RDTMobRec
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
-- @cPrinter   = Printer,
   @cUserName  = UserName,

   @cPUOM       = V_UOM,
   @nQTY        = V_QTY,
   @cSKU        = V_SKU,
   @cDescr      = V_SKUDescr,
   --@cPickSlipNo = V_PickSlipNo,
   @cOrderKey   = V_OrderKey,
   @cLoadKey    = V_LoadKey,

   @cCheckPickB4Pack    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String1,  5), 0) = 1 THEN LEFT( V_String1,  5) ELSE 0 END,
   @cGSILBLITF          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String2,  5), 0) = 1 THEN LEFT( V_String2,  5) ELSE 0 END,
   @cPrepackByBOM       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3,  5), 0) = 1 THEN LEFT( V_String3,  5) ELSE 0 END,
   @cAutoPackConfirm    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4,  5), 0) = 1 THEN LEFT( V_String4,  5) ELSE 0 END,
   @nCasePackDefaultQty = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5,  5), 0) = 1 THEN LEFT( V_String5,  5) ELSE 0 END,

   @cUPC_SKU            = V_String6,
   @cPickSlipType       = V_String7,
   @cMBOLKey            = V_String8,
   @cBuyerPO            = V_String9,
   @cTemplateID         = V_String10,
   @cFilePath1          = V_String11,
   @cFilePath2          = V_String12,
   @nCartonNo           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String13,  5), 0) = 1 THEN LEFT( V_String13,  5) ELSE 0 END,
   @cLabelNo            = V_String14,
   @cSKU1               = V_String15,
   @cSKU2               = V_String16,
   @cSKU_Descr1         = V_String17,
   @cSKU_Descr2         = V_String18,
   @cQtyAlloc1          = V_String19,
   @cQtyAlloc2          = V_String20,
   @cQtyScan1           = V_String21,
   @cQtyScan2           = V_String22,
   @nPickDSKUQty        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String23,  5), 0) = 1 THEN LEFT( V_String23,  5) ELSE 0 END,
   @nPackDSKUQty        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String24,  5), 0) = 1 THEN LEFT( V_String24,  5) ELSE 0 END,
   @nPages              = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String25,  5), 0) = 1 THEN LEFT( V_String25,  5) ELSE 0 END,
   @cPrinter            = V_String26,
   @cGS1TemplatePath1   = V_String27, -- (Vicky03)
   @nCaseCnt            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String28,  5), 0) = 1 THEN LEFT( V_String28,  5) ELSE 0 END, -- (Vicky02)
   @cGenTemplateID      = V_String29, -- (Vicky03)
   @cGS1TemplatePath2   = V_String30, -- (Vicky03)
   @cGS1TemplatePath3   = V_String31, -- (Vicky03)
   @cGS1TemplatePath4   = V_String32, -- (Vicky03)
   @cGS1TemplatePath5   = V_String33, -- (Vicky03)
   @cGS1TemplatePath6   = V_String34, -- (Vicky03)
   @cDropID             = V_String35,
   @c_LoosePick         = V_String36,
   @nTotalCtnsALL       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String37,  5), 0) = 1 THEN LEFT( V_String37,  5) ELSE 0 END,	--SOS305919
   @nESCCheck           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String38,  5), 0) = 1 THEN LEFT( V_String38,  5) ELSE 0 END,	--SOS305919

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
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04  = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

Declare @n_debug INT

SET @n_debug = 1

--IF @n_debug = 1
   BEGIN
      DECLARE  @d_starttime    datetime,
               @d_endtime      datetime,
               @d_step1        datetime,
               @d_step2        datetime,
               @d_step3        datetime,
               @d_step4        datetime,
               @d_step5        datetime,
               @c_col1         NVARCHAR(20),
               @c_col2         NVARCHAR(20),
               @c_col3         NVARCHAR(20),
               @c_col4         NVARCHAR(20),
               @c_col5         NVARCHAR(20),
               @c_TraceName    NVARCHAR(80)

      DECLARE
          @d_date       DATETIME
         ,@d_total      DATETIME, @n_total  INT
                                , @n_step1  INT
                                , @n_step2  INT
                                , @n_step3  INT
                                , @n_step4  INT
                                , @n_step5  INT
         ,@d_step6      DATETIME, @n_step6  INT
         ,@d_step7      DATETIME, @n_step7  INT
         ,@d_step8      DATETIME, @n_step8  INT
         ,@d_step9      DATETIME, @n_step9  INT
         ,@d_step10     DATETIME, @n_step10 INT


      SET @d_starttime = GETDATE()
      SELECT @d_total     = 0, @n_total  = 0
      SELECT @d_step1     = 0, @n_step1  = 0
      SELECT @d_step2     = 0, @n_step2  = 0
      SELECT @d_step3     = 0, @n_step3  = 0
      SELECT @d_step4     = 0, @n_step4  = 0
      SELECT @d_step5     = 0, @n_step5  = 0
      SELECT @d_step6     = 0, @n_step6  = 0
      SELECT @d_step7     = 0, @n_step7  = 0
      SELECT @d_step8     = 0, @n_step8  = 0
      SELECT @d_step9     = 0, @n_step9  = 0
      SELECT @d_step10    = 0, @n_step10 = 0

   END

IF @nFunc = 1752  -- Print Carton Label
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Print Carton Label
   IF @nStep = 1 GOTO Step_1   -- Scn = 2220. PRINTER ID, DROP ID
   IF @nStep = 2 GOTO Step_2   -- Scn = 2221. DROPID, Carton Count
   IF @nStep = 3 GOTO Step_3   -- Scn = 2222. OPTION
END

--IF @nStep = 3
--BEGIN
-- SET @cErrMsg = 'STEP 3'
-- GOTO QUIT
--END


--RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1752. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get prefer UOM
   SET @cPUOM = ''
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   --SET @cAutoPackConfirm = rdt.RDTGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)
   --SET @nCasePackDefaultQty =  CAST(rdt.RDTGetConfig( @nFunc, 'CasePackDefaultQty', @cStorerKey) AS INT)

   -- Initiate var
   SET @cPickSlipNo = ''
   SET @cPrinter = ''
   SET @cLabelNo = ''
   SET @cGenTemplateID = '' -- (Vicky07)
   SET @cTemplateID = ''  -- (Vicky07)
   SET @cDropID = ''  -- (Vicky07)

   -- Init screen
   SET @cOutField01 = '' -- Printer
   SET @cOutField02 = '' -- DropID

   -- Set the entry point
   SET @nScn = 2220
   SET @nStep = 1

END
GOTO Quit

/********************************************************************************
Step 1. Scn = 2220.
   PRINTER ID (field01, input)
   DROPID (field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
------Step1

SET @d_step1 = GETDATE()

       SET @nCartonNo = 0
       SET @cLabelNo = ''

       --screen mapping
       SET @cPrinter = @cInField01
       SET @cDropID = @cInField02

       SET @n_PrePack = 0
       SET @nSetTemplate = 0
       SET @nESCCheck = 1
       SET @nPickDetailQTY = 0 -- (Vicky10)
       SET @nPackDetailQTY = 0 -- (Vicky10)
       SET @cStorerkey = ''
       SET @cLoadkey = ''

       SELECT TOP 1 @cStorerkey = PD.Storerkey,
                    @cLoadkey = LD.Loadkey
       FROM dbo.PICKDETAIL PD WITH (NOLOCK, INDEX (IDX_PICKDETAIL_DropID))
       INNER JOIN dbo.Orderdetail OD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey AND OD.OrderlineNumber = PD.OrderLineNumber)
       INNER JOIN dbo.Orders O WITH (NOLOCK) ON (O.Orderkey = OD.Orderkey)
       INNER JOIN dbo.LoadPlanDetail LD WITH (NOLOCK) ON (LD.Orderkey = O.Orderkey)
       WHERE PD.DropID = @cDropID

       IF ISNULL(@cLoadKey,'') = ''
       BEGIN
         SET @nErrNo = 68746
         SET @cErrMSG = rdt.rdtgetmessage( 68746, @cLangCode,'DSP') --No LoadKey
--           SET @cOutField02 = ''
--           SET @cPickSlipNo = ''
--           EXEC rdt.rdtSetFocusField @nMobile, 2
         SET @nESCCheck = 0
         GOTO QUIT
       END

       IF ISNULL(@cStorerkey,'') = ''
       BEGIN
           SET @nErrNo = 68719
           SET @cErrMSG = rdt.rdtgetmessage( 68719, @cLangCode,'DSP') --No Storerkey
--           SET @cOutField02 = ''
--           SET @cPickSlipNo = ''
--           EXEC rdt.rdtSetFocusField @nMobile, 2
           SET @nESCCheck = 0
           GOTO QUIT
       END

       -- Check Printer ID
       IF ISNULL(@cPrinter, '') = ''
       BEGIN
         SET @nErrNo = 68715
         SET @cErrMsg = rdt.rdtgetmessage( 68715, @cLangCode, 'DSP') --Printer ID req
         SET @cOutField01 = ''
         SET @cOutField02 = @cDropID
         SET @cPrinter = ''
         SET @nESCCheck = 0
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO QUIT
      END

      -- Validate blank
      IF ISNULL(@cDropID, '') = ''
      BEGIN
         SET @nErrNo = 68716
         SET @cErrMsg = rdt.rdtgetmessage( 68716, @cLangCode,'DSP') --DROPID require
         SET @cOutField01 = @cPrinter
         SET @cOutField02 = ''
         SET @cPickSlipNo = ''
         SET @nESCCheck = 0
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO QUIT
      END

      -- Validate pickslipno
      IF NOT EXISTS (SELECT 1
         FROM dbo.PickDetail WITH (NOLOCK, INDEX (IDX_PICKDETAIL_DropID))
         WHERE DropID = @cDropID AND Storerkey = @cStorerkey)
      BEGIN
         SET @nErrNo = 68717
         SET @cErrMsg = rdt.rdtgetmessage( 68717, @cLangCode,'DSP') --Invalid DROPID
         SET @cOutField01 = @cPrinter
         SET @cOutField02 = ''
         SET @cPickSlipNo = ''
         SET @nESCCheck = 0
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO QUIT
      END

      IF NOT EXISTS (SELECT 1
         FROM dbo.DropID WITH (NOLOCK)
         WHERE DropID = @cDropID )
      BEGIN
         SET @nErrNo = 68718
         SET @cErrMsg = rdt.rdtgetmessage( 68718, @cLangCode,'DSP') --Invalid DROPID
         SET @cOutField01 = @cPrinter
         SET @cOutField02 = ''
         SET @cPickSlipNo = ''
         SET @nESCCheck = 0
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO QUIT
      END

      IF EXISTS (SELECT 1
         FROM dbo.DropID WITH (NOLOCK)
         WHERE DropID = @cDropID
         AND LabelPrinted = 'Y')
      BEGIN
         SET @nErrNo = 68753
         SET @cErrMsg = rdt.rdtgetmessage( 68753, @cLangCode,'DSP') --LabelPrinted
         SET @cOutField01 = @cPrinter
         SET @cOutField02 = ''
         SET @cPickSlipNo = ''
         SET @nESCCheck = 0
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO QUIT
      END

      IF EXISTS (SELECT 1
         FROM dbo.PickDetail WITH (NOLOCK, INDEX(IDX_PICKDETAIL_DropID))
         WHERE DropID = @cDropID
         AND status <> '5' AND Storerkey = @cStorerkey)
      BEGIN
         SET @nErrNo = 68757
         SET @cErrMsg = rdt.rdtgetmessage( 68757, @cLangCode,'DSP') --ID Not Picked
         SET @cOutField01 = @cPrinter
         SET @cOutField02 = ''
         SET @cPickSlipNo = ''
         SET @nESCCheck = 0
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO QUIT
      END

      -- (Vicky08) - Start
      IF EXISTS (SELECT 1
         FROM dbo.DropID WITH (NOLOCK)
         WHERE DropID = @cDropID
         AND status < '3')
      BEGIN
         SET @nErrNo = 68759
         SET @cErrMsg = rdt.rdtgetmessage( 68759, @cLangCode,'DSP') --ID Not Moved
         SET @cOutField01 = @cPrinter
         SET @cOutField02 = ''
         SET @cPickSlipNo = ''
         SET @nESCCheck = 0
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO QUIT
      END
      -- (Vicky08) - End

      -- (Vicky10) - Start
      SELECT @nPickDetailQTY = SUM(QTY)
      FROM dbo.PICKDETAIL WITH (NOLOCK, INDEX (IDX_PICKDETAIL_DropID))
      WHERE DropID = @cDropID

      SELECT @nPackDetailQTY = SUM(QTY)
      FROM dbo.PACKDETAIL WITH (NOLOCK)
      WHERE StorerKey = @cStorerkey -- SHONG01
      AND   RefNo = @cDropID

      IF @nPickDetailQTY + @nPackDetailQTY > @nPickDetailQTY
      BEGIN
         SET @nErrNo = 68761
         SET @cErrMsg = rdt.rdtgetmessage( 68761, @cLangCode,'DSP') --Over Pack
         SET @cOutField01 = @cPrinter
         SET @cOutField02 = ''
         SET @cPickSlipNo = ''
         SET @nESCCheck = 0
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO QUIT
      END
      -- (Vicky10) - End


      SET  @cWCSFilePath1 = ''
      SELECT @cWCSFilePath1 = UserDefine18 FROM dbo.FACILITY WITH (NOLOCK)
      WHERE FACILITY = @cFacility

      IF ISNULL(@cWCSFilePath1,'') = ''
      BEGIN
         SET @nErrNo = 68758
         SET @cErrMSG = rdt.rdtgetmessage( 68758, @cLangCode, 'DSP') --'68758 No WCS Path'
         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cOutField01 OUTPUT,
         --     @cOutField11, @cOutField12
         SET @cOutField01 = @cPrinter
         SET @cOutField02 = ''
         SET @cPickSlipNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         SET @nESCCheck = 0
         GOTO QUIT
      END

SELECT @d_step1 = GETDATE() - @d_step1, @n_step1 = @n_step1 + 1
------Step2
SET @d_step2 = GETDATE()

      DECLARE CUR_ADDPICKHEADER CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT DISTINCT PD.Orderkey FROM dbo.PICKDETAIL PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_DropID))
      INNER JOIN dbo.Orderdetail OD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey AND OD.OrderlineNumber = PD.OrderLineNumber)
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON (O.Orderkey = OD.Orderkey)
      INNER JOIN dbo.LoadPlanDetail LD WITH (NOLOCK) ON (LD.Orderkey = O.Orderkey)
      WHERE PD.DROPID = @cDropID
      AND   LD.Loadkey = @cLoadkey
      ORDER BY PD.Orderkey --SOS# 183480

      OPEN CUR_ADDPICKHEADER
      FETCH NEXT FROM CUR_ADDPICKHEADER INTO @cOrderkey
      WHILE @@FETCH_STATUS <> - 1
      BEGIN

         --SOS# 183480
         INSERT INTO dbo.GS1LOG
         ( MobileNo, UserName, FuncId, TraceName
         , PickSlipNo, LoadKey, OrderKey, DropId
         , StorerKey, Facility, Col10 )
         VALUES(@nMobile, @cUserName, @nFunc, 'GS1MainSP'
               , @cPickSlipNo, @cLoadkey, @cOrderkey, @cDropID
               , @cStorerkey, @cFacility, '*')

        IF NOT EXISTS (SELECT 1 FROM dbo.PICKHEADER WITH (NOLOCK)
                       WHERE EXTERNORDERKEY = @cLoadkey AND Orderkey = @cOrderkey)
        BEGIN

           EXECUTE dbo.nspg_GetKey
           'PICKSLIP',
           9 ,
           @cPickSlipNo       OUTPUT,
           @b_success         OUTPUT,
           @n_err             OUTPUT,
           @c_errmsg          OUTPUT

           IF @b_success <> 1
           BEGIN
              SET @nErrNo = 68733
              SET @cErrMSG = rdt.rdtgetmessage( 68733, @cLangCode, 'DSP') -- 'GetPSLipFail'
              GOTO QUIT
           END

           SELECT @cPickSlipNo = 'P' + @cPickSlipNo

           BEGIN TRAN
           INSERT INTO dbo.PICKHEADER
              (PickHeaderKey, Orderkey,  ExternOrderKey, Zone, TrafficCop)
              VALUES
              (@cPickSlipNo, @cOrderkey , @cLoadKey, '7', '')

           IF @@ERROR <> 0
           BEGIN
              SET @nErrNo = 68732
              SET @cErrMSG = rdt.rdtgetmessage( 68732, @cLangCode, 'DSP') --'InsPiHdrFail'
              SET @nESCCheck = 0
              ROLLBACK TRAN
              GOTO QUIT
           END
           ELSE
           BEGIN
              COMMIT TRAN
           END

           BEGIN TRAN
           INSERT INTO dbo.PickingInfo
           (PickSlipNo, ScanInDate, PickerID, ScanOutDate, AddWho)
           VALUES
           (@cPickSlipNo, GETDATE(), sUser_sName(), NULL, sUser_sName())

           IF @@ERROR <> 0
           BEGIN
           SET @nErrNo = 68734
              SET @cErrMSG = rdt.rdtgetmessage( 68734, @cLangCode, 'DSP') --'PSScanInFail'
              SET @nESCCheck = 0
              ROLLBACK TRAN
              GOTO QUIT
           END
           ELSE
           BEGIN
               COMMIT TRAN
           END

           -- (Vicky09) - Start
           BEGIN TRAN
           UPDATE dbo.PICKDETAIL
               SET PickSlipNo = @cPickSlipNo, TrafficCop = NULL
           WHERE OrderKey = @cOrderkey

           IF @@ERROR <> 0
           BEGIN
              SET @nErrNo = 68760
              SET @cErrMSG = rdt.rdtgetmessage( 68760, @cLangCode, 'DSP') --'UpdPickDetFail
              SET @nESCCheck = 0
              ROLLBACK TRAN
              GOTO QUIT
           END
           ELSE
           BEGIN
               COMMIT TRAN
           END
           -- (Vicky09) - End
         END -- if Not exists
         ELSE
         BEGIN
              SET @cPickSlipNo = ''
              SELECT @cPickSlipNo = PickHeaderKey
              FROM dbo.PickHeader WITH (NOLOCK)
              WHERE ExternOrderkey = @cLoadkey
              AND Orderkey = @cOrderkey

              -- Check if the pickslip already scan in
              IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
              BEGIN
                    BEGIN TRAN
                    INSERT INTO dbo.PickingInfo
                    (PickSlipNo, ScanInDate, PickerID, ScanOutDate, AddWho)
                    VALUES
                    (@cPickSlipNo, GETDATE(), sUser_sName(), NULL, sUser_sName())

                    IF @@ERROR <> 0
                    BEGIN
                    SET @nErrNo = 68734
                       SET @cErrMSG = rdt.rdtgetmessage( 68734, @cLangCode, 'DSP') --'PSScanInFail'
                       SET @nESCCheck = 0
                       ROLLBACK TRAN
                       GOTO QUIT
                    END
                    ELSE
                    BEGIN
                     COMMIT TRAN
                    END
              END
         END
SELECT @n_step2 = @n_step2 + 1
      FETCH NEXT FROM CUR_ADDPICKHEADER INTO @cOrderkey
      END -- END WHILE
      CLOSE CUR_ADDPICKHEADER
      DEALLOCATE CUR_ADDPICKHEADER

SELECT @d_step2 = GETDATE() - @d_step2
------Step3
SET @d_step3 = GETDATE()

      SET @cPickSlipType = 'SINGLE'

      IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND Configkey = 'CheckPickB4Pack'
            AND SValue = '1')
         SET @cCheckPickB4Pack = '1'
      ELSE
         SET @cCheckPickB4Pack = '0'

      IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK)
         WHERE Storerkey = @cStorerKey
            AND Configkey = 'GSILBLITF'
            AND SValue = '1')
         SET @cGSILBLITF = '1'
      ELSE
         SET @cGSILBLITF = '0'

      IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK)
         WHERE Storerkey = @cStorerKey
            AND Configkey = 'PrepackByBOM'
            AND SValue = '1')
         SET @cPrepackByBOM = '1'
      ELSE
         SET @cPrepackByBOM = '0'

      IF @cPickSlipType = 'SINGLE'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.PickHeader PH WITH (NOLOCK)
                        INNER JOIN dbo.Orders O WITH (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
                        INNER JOIN dbo.PickDetail PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_DropID)) ON (O.OrderKey = PD.OrderKey)
                        INNER JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
                        WHERE PD.DropID = @cDropID
                        AND   L.Facility = @cFacility
                        AND   O.Storerkey = @cStorerkey)
         BEGIN
            SET @nErrNo = 68722
            SET @cErrMSG = rdt.rdtgetmessage( 68722, @cLangCode, 'DSP') --Diff Storer
            SET @cOutField01 = @cPrinter
            SET @cOutField02 = ''
            SET @cPickSlipNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
       GOTO QUIT
         END

         IF NOT EXISTS (SELECT 1 FROM dbo.PickHeader PH WITH (NOLOCK)
                        INNER JOIN dbo.Orders O WITH (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
                        INNER JOIN dbo.PickDetail PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_DropID)) ON (O.OrderKey = PD.OrderKey)
                        INNER JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
                        WHERE PD.DropID = @cDropID
                        AND   L.Facility = @cFacility
                        AND   PH.ExternOrderkey = @cLoadkey)
         BEGIN
            SET @nErrNo = 68721
            SET @cErrMSG = rdt.rdtgetmessage( 68721, @cLangCode, 'DSP') --Diff Facility
            SET @cOutField01 = @cPrinter
            SET @cOutField02 = ''
            SET @cPickSlipNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO QUIT
         END

--         -- (ChewKP06)
--         -- Check If the Loadplan consists of multi-storer
--         IF EXISTS(SELECT 1
--                   FROM   dbo.PickHeader PH WITH (NOLOCK)
--                   JOIN   dbo.Orders O WITH (NOLOCK) ON (PH.OrderKey = O.OrderKey)
--                   WHERE  PH.ExternOrderkey = @cLoadkey
--                   GROUP BY O.LoadKey
--                   HAVING COUNT( DISTINCT O.StorerKey) > 1)
--         BEGIN
--            SET @nErrNo = 68723
--            SET @cErrMSG = rdt.rdtgetmessage( 68723, @cLangCode, 'DSP') --68723 PSNO>1 Storer
--            SET @cOutField01 = @cPrinter
--            SET @cOutField02 = ''
--            SET @cPickSlipNo = ''
--            EXEC rdt.rdtSetFocusField @nMobile, 2
--            GOTO QUIT
--         END
      END -- 'SINGLE'

       -- GS1 Label validation start
       IF @cGSILBLITF = '1'
       BEGIN
         SET @cFilePath = ''
         SELECT @cFilePath = ISNULL(RTRIM(UserDefine20 ), '')
         FROM dbo.Facility WITH (NOLOCK)
         WHERE Facility = @cFacility

       -- use 2 variables to store because facility.userdefine20 is NVARCHAR(30) while rdt v_string variable is NVARCHAR(20)
         SET @cFilePath1 = SUBSTRING(@cFilePath, 1, 20)
         SET @cFilePath2 = SUBSTRING(@cFilePath, 21, 20)

         IF ISNULL(@cFilePath1, '') = ''
         BEGIN
            SET @nErrNo = 68729
            SET @cErrMSG = rdt.rdtgetmessage( 68728, @cLangCode, 'DSP') --68729 No FilePath
--             EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cOutField01 OUTPUT,
--                @cOutField11, @cOutField12, @cOutField13
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cPickSlipNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO QUIT
         END

         SET @cGS1TemplatePath = ''
         SELECT @cGS1TemplatePath = NSQLDescrip
         FROM RDT.NSQLCONFIG WITH (NOLOCK)
         WHERE ConfigKey = 'GS1TemplatePath'

         IF ISNULL(@cGS1TemplatePath, '') = ''
         BEGIN
            SET @nErrNo = 68730
            --SET @cOutField01 = '68730 No Template'
            SET @cErrMSG = rdt.rdtgetmessage( 68730, @cLangCode, 'DSP') --68730 No Template
--             EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cOutField01 OUTPUT,
--                @cOutField11, @cOutField12

            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cPickSlipNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO QUIT
         END
      END
      -- GSI Label validation end

SELECT @d_step3 = GETDATE() - @d_step3, @n_step3 = @n_step3 + 1
------Step4
SET @d_date = GETDATE()

    -- Loop of SKU for Packing and GS1 Label generation (START) --
    IF @cPickSlipType = 'SINGLE'
    BEGIN
         SET @n_PrePack = 1
         SET @c_LoosePick = '0'
         -- SOS#137790 - TTLCTNS Calculation (Vicky01 - Start)
         SET @nTotalCtns = 0
         SET @nPDQTY = 0
         SET @nUPCCaseCnt = 0
         SET @nTotalBOMQty = 0
         SET @nLotCtns = 0
         SET @cParentSKU = ''
         SET @cPackCheck = '0'
         SET @nTotalCtnsALL = 0

       --SOS# 183480
      INSERT INTO dbo.GS1LOG
      ( MobileNo, UserName, FuncId, TraceName
      , PickSlipNo, LoadKey, OrderKey, DropId
      , StorerKey, Facility, Col10 )
      VALUES(@nMobile, @cUserName, @nFunc, 'GS1MainSP'
            , @cPickSlipNo, @cLoadkey, @cOrderkey, @cDropID
            , @cStorerkey, @cFacility, '*1*')

       DECLARE CUR_ORDER CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
       SELECT DISTINCT PD.Orderkey, PH.PickHeaderkey, O.DischargePlace, O.BuyerPO FROM dbo.PICKDETAIL PD WITH (NOLOCK)
       INNER JOIN dbo.PICKHEADER PH WITH (NOLOCK) ON ( PH.ORDERKEY = PD.ORDERKEY )
       INNER JOIN dbo.Orders O WITH (NOLOCK) ON ( O.ORDERKEY = PD.ORDERKEY )
       WHERE PD.StorerKey = @cStorerkey
       AND   PH.ExternOrderKey = @cLoadkey
       AND   PD.DROPID = @cDropID
       ORDER BY PH.PickHeaderkey, PD.Orderkey --SOS# 183480

       OPEN CUR_ORDER
       FETCH NEXT FROM CUR_ORDER INTO @cOrderKey , @cPickSlipNo, @cDischargePlace, @cBuyerPO
       WHILE @@FETCH_STATUS <> -1
       BEGIN

         --SOS# 183480
         INSERT INTO dbo.GS1LOG
         ( MobileNo, UserName, FuncId, TraceName
         , PickSlipNo, LoadKey, OrderKey, DropId
         , StorerKey, Facility, Col8, Col9, Col10 )
         VALUES(@nMobile, @cUserName, @nFunc, 'GS1MainSP'
               , @cPickSlipNo, @cLoadkey, @cOrderkey, @cDropID
               , @cStorerkey, @cFacility, @cDischargePlace, @cBuyerPO, '**')

          -- (Vicky04) - Start
          SET @cTemplateID = ''
          SET @cGenTemplateID = ''

          IF ISNULL(@cGenTemplateID, '') = '' AND ISNULL(@cTemplateID , '') = ''
          BEGIN
             SET @cTemplateID = ISNULL(RTRIM(@cDischargePlace), '')
          END

          IF ISNULL(@cTemplateID, '') = '' AND ISNULL(@cGenTemplateID , '') = ''
          BEGIN
               -- Prepare next screen var
               SET @cOutField01 = ''
               SET @cGenTemplateID = ''

               CLOSE CUR_ORDER
               DEALLOCATE CUR_ORDER

               -- Go to next screen
               SET @nScn = @nScn + 2
               SET @nStep = @nStep + 2

               GOTO QUIT
          END

          --IF ISNULL(@cTemplateID , '') = '' AND ISNULL(@cGenTemplateID,'') <> ''
          --BEGIN
          --  SET @cTemplateID = @cGenTemplateID
          --END

          IF ISNULL(@cTemplateID , '') <> '' AND ISNULL(@cGenTemplateID,'') = ''
          BEGIN
            SET @cGenTemplateID = @cTemplateID
          END
          -- (Vicky04) - End

          IF ISNULL(RTRIM(@cTemplateID ), '') <> '' AND ISNULL(RTRIM(@cGenTemplateID), '') <> ''
          BEGIN

             SET @cGS1TemplatePath1 = ''
             SET @cGS1TemplatePath2 = ''
             SET @cGS1TemplatePath3 = ''
             SET @cGS1TemplatePath4 = ''
             SET @cGS1TemplatePath5 = ''
             SET @cGS1TemplatePath6 = ''

             SET @cGS1TemplatePath_Gen = ''
             SELECT @cGS1TemplatePath_Gen = NSQLDescrip
             FROM RDT.NSQLCONFIG WITH (NOLOCK)
             WHERE ConfigKey = 'GS1TemplatePath'

             SET @cGS1TemplatePath_Gen = ISNULL(RTRIM(@cGS1TemplatePath_Gen), '') + '\' + ISNULL(RTRIM(@cGenTemplateID), '')

             SET @cGS1TemplatePath1 = LEFT(@cGS1TemplatePath_Gen, 20)
             SET @cGS1TemplatePath2 = SUBSTRING(@cGS1TemplatePath_Gen, 21, 20)
             SET @cGS1TemplatePath3 = SUBSTRING(@cGS1TemplatePath_Gen, 41, 20)
             SET @cGS1TemplatePath4 = SUBSTRING(@cGS1TemplatePath_Gen, 61, 20)
             SET @cGS1TemplatePath5 = SUBSTRING(@cGS1TemplatePath_Gen, 81, 20)
             SET @cGS1TemplatePath6 = SUBSTRING(@cGS1TemplatePath_Gen, 101, 20)

             SET @cGS1TemplatePath_Final = RTRIM(@cGS1TemplatePath1) + RTRIM(@cGS1TemplatePath2) + RTRIM(@cGS1TemplatePath3) +
                                           RTRIM(@cGS1TemplatePath4) + RTRIM(@cGS1TemplatePath5) + RTRIM(@cGS1TemplatePath6)
          END

              -- PackHeader Creation and Ctn Counts (START) -- (ChewKP04)
              SET @c_LoosePick = '0'
              SET @cPackCheck = '0'
              SET @nTotalCtns  ='0'

SELECT @d_step4 = @d_step4 + (GETDATE() - @d_date), @n_step4 = @n_step4 + 1
-- Step5 start --------------------------------------------------------------------------------------------------------------------------------------------------------
SET @d_date = GETDATE()
              IF @cPrePackByBOM = '1' -- (ChewKP05)
              BEGIN

                 DECLARE CUR_PDLOT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                 SELECT DISTINCT LA.Lottable03 FROM dbo.PickDetail PD WITH (NOLOCK)
                 INNER JOIN dbo.LOTATTRIBUTE LA (NOLOCK) ON (LA.Storerkey = PD.Storerkey AND LA.SKU = PD.SKU AND
                                                                   LA.LOT = PD.LOT)
                 WHERE PD.StorerKey = @cStorerkey
                 AND   PD.Orderkey = @cOrderkey
                 AND   PD.DropID = @cDropID
                 OPEN CUR_PDLOT
                 FETCH NEXT FROM CUR_PDLOT INTO @c_ALTSKU
                 WHILE @@FETCH_STATUS <> -1
                 BEGIN

                    SET @nUPCCaseCnt = ''
                    SELECT @nUPCCaseCnt = ISNULL(PACK.CaseCnt, 0)
                    FROM dbo.PACK PACK WITH (NOLOCK)
                    JOIN dbo.UPC UPC WITH (NOLOCK) ON (UPC.Packkey = PACK.Packkey)
                    WHERE UPC.SKU = @c_ALTSKU
                    AND   UPC.Storerkey = @cStorerkey
                    AND   UPC.UOM = 'CS'

                    SET @nPDQTY = 0
                    SELECT @nPDQTY = SUM(PD.QTY)
                    FROM dbo.PickDetail PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_DropID))
                    JOIN dbo.Lotattribute LA WITH (NOLOCK) ON (PD.Storerkey = LA.Storerkey and PD.SKU = LA.SKU AND
                                                                     PD.LOT = LA.Lot)
                    WHERE PD.DropID = @cDropID
                    AND   LA.Lottable03 = @c_ALTSKU
                    AND   PD.Storerkey = @cStorerkey
                    AND   PD.Orderkey = @cOrderkey

                   IF @nUPCCaseCnt > 0
                   BEGIN
                       SET @nTotalBOMQty = 0
                       SELECT @nTotalBOMQty = SUM(BOM.QTY)
                       FROM dbo.BillOfMaterial BOM WITH (NOLOCK)
                       WHERE BOM.Storerkey = @cStorerKey
                       AND   BOM.SKU = @c_ALTSKU

                       SELECT @nLotCtns = CEILING(@nPDQTY / (@nTotalBOMQty * @nUPCCaseCnt))

                       IF (@nPDQTY % (@nTotalBOMQty * @nUPCCaseCnt)) > 0
                       BEGIN
                          SET @c_LoosePick = '1'
                          SET @cOutField03 = 'Loose pieces'
                          SET @cOutField04 = 'found'
                       END
                       ELSE -- (ChewKP05)
                       BEGIN
                          SET @cOutField03 = ''
SET @cOutField04 = ''
                       END
      END
                    ELSE
                    BEGIN
                       SELECT @nLotCtns = 0
                    END

                    SELECT @nTotalCtns = @nTotalCtns + @nLotCtns

                   FETCH NEXT FROM CUR_PDLOT INTO @c_ALTSKU
                 END
                 CLOSE CUR_PDLOT
                 DEALLOCATE CUR_PDLOT

              END
              ELSE IF @cPrePackByBOM = '0'
              BEGIN
                 DECLARE CUR_PDLOT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                 SELECT DISTINCT PD.SKU FROM dbo.PickDetail PD WITH (NOLOCK)
                 WHERE PD.StorerKey = @cStorerkey
                 AND   PD.Orderkey = @cOrderkey
                 AND   PD.DropID = @cDropID
                 OPEN CUR_PDLOT
                 FETCH NEXT FROM CUR_PDLOT INTO @c_ALTSKU
                 WHILE @@FETCH_STATUS <> -1
                 BEGIN

                    SET @nUPCCaseCnt = ''
                    SELECT @nUPCCaseCnt = ISNULL(PACK.CaseCnt, 0)
                    FROM dbo.PACK PACK WITH (NOLOCK)
                    JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
                    WHERE SKU.SKU = @c_ALTSKU
                    AND   SKU.Storerkey = @cStorerkey


                    SET @nPDQTY = 0
                    SELECT @nPDQTY = SUM(PD.QTY)
                    FROM dbo.PickDetail PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_DropID))
                    JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.SKU = PD.SKU AND SKU.Storerkey = PD.Storerkey)
                    WHERE PD.DropID = @cDropID
                    AND   SKU.SKU = @c_ALTSKU
                    AND   PD.Storerkey = @cStorerkey
                    AND   PD.Orderkey = @cOrderkey

                   IF @nUPCCaseCnt > 0
                   BEGIN


                       SELECT @nLotCtns = CEILING(@nPDQTY / @nUPCCaseCnt)

                       IF (@nPDQTY % @nUPCCaseCnt) > 0
                       BEGIN
                          SET @c_LoosePick = '1'
                          SET @cOutField03 = 'Loose pieces'
                          SET @cOutField04 = 'found'
                       END
                       ELSE -- (ChewKP05)
                       BEGIN
                          SET @cOutField03 = ''
                          SET @cOutField04 = ''
                       END
                    END
                    ELSE
                    BEGIN
                       SELECT @nLotCtns = 0
                    END

                    SELECT @nTotalCtns = @nTotalCtns + @nLotCtns

                     FETCH NEXT FROM CUR_PDLOT INTO @c_ALTSKU
                 END
                 CLOSE CUR_PDLOT
                 DEALLOCATE CUR_PDLOT

              END
SELECT @d_step5 = @d_step5 + (GETDATE() - @d_date), @n_step5 = @n_step5 + 1
-- Step6 start. Step5 end --------------------------------------------------------------------------------------------------------------------------------------------------------
SET @d_date = GETDATE()


              SET @nTotalCtnsALL = @nTotalCtnsALL + @nTotalCtns

              IF @nLotCtns > 0
              BEGIN
                IF NOT EXISTS (SELECT 1 FROM dbo.PACKHEADER WITH (NOLOCK)
                               WHERE Pickslipno = @cPickslipNo)
                BEGIN -- Packheader not exists (Start)

                   BEGIN TRAN
                   INSERT INTO dbo.PackHeader
                   (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, TTLCNTS) -- (Vicky01)
                   SELECT O.Route, O.OrderKey, SUBSTRING(O.ExternOrderKey, 1, 18), O.LoadKey, O.ConsigneeKey, O.Storerkey, @cPickSlipNo,
                          @nTotalCtns -- (Vicky01)
                   FROM  dbo.PickHeader PH WITH (NOLOCK)
                   JOIN  dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)
                   WHERE PH.PickHeaderKey = @cPickSlipNo

                   IF @@ERROR <> 0
                   BEGIN
                      SET @nErrNo = 66265
                      SET @cErrMSG = rdt.rdtgetmessage( 66265, @cLangCode, 'DSP') --'CreatePHdrFail'

                      SET @cOutField01 = @cPrinter
                      SET @cOutField02 = ''
                      SET @cPickSlipNo = ''
                      EXEC rdt.rdtSetFocusField @nMobile, 2
                      SET @nESCCheck = 0
                      ROLLBACK TRAN
                      GOTO QUIT
                   END
                   ELSE
                   BEGIN
                      COMMIT TRAN
                   END
                END -- IF NOT EXIST
                ELSE
                BEGIN
                   BEGIN TRAN
                   UPDATE dbo.PACKHEADER  WITH (ROWLOCK)
                   SET TTLCNTS = (TTLCNTS + @nTotalCtns), Archivecop = NULL
                   WHERE PickSlipNo = @cPickSlipNo
                   AND Storerkey = @cStorerKey

                   IF @@ERROR <> 0
                   BEGIN
                      SET @nErrNo = 68751
                      SET @cErrMSG = rdt.rdtgetmessage( 68751, @cLangCode, 'DSP') --'UPD PHdrFail'

                      SET @cOutField01 = @cPrinter
                      SET @cOutField02 = ''
                      SET @cPickSlipNo = ''
                      EXEC rdt.rdtSetFocusField @nMobile, 2
                      SET @nESCCheck = 0
                      ROLLBACK TRAN
                      GOTO QUIT
                   END
                   ELSE
                   BEGIN
                      COMMIT TRAN
                   END
               END
              END -- @nLotCtns <> 0
          -- PackHeader Creation and Ctn Counts (END) -- (ChewKP04)

         --SOS# 183480
         INSERT INTO dbo.GS1LOG
         ( MobileNo, UserName, FuncId, TraceName
         , PickSlipNo, LoadKey, OrderKey, DropId
         , StorerKey, Facility, Col1, Col2, Col3, Col10 )
         VALUES(@nMobile, @cUserName, @nFunc, 'GS1MainSP'
               , @cPickSlipNo, @cLoadkey, @cOrderkey, @cDropID
               , @cStorerkey, @cFacility, @cPickSlipType, @n_PrePack, @nErrNo, '***A')

SELECT @d_step6 = @d_step6 + (GETDATE() - @d_date), @n_step6 = @n_step6 + 1
-- Step6 end. Step7 start
SET @d_date = GETDATE()

          EXEC rdt.rdt_Print_GS1_Carton_Label_InsertPackDetail
                  @nMobile,
                  @cFacility,
                  @cStorerKey,
                  @cDropID,
                  @cOrderKey,
                  @cPickSlipType,
                  @cPickSlipNo,
                  @cBuyerPO,
                  @cFilePath1,
                  @cFilePath2,
                  @n_PrePack,
                  @cUserName,
                  --@cTemplateID,
                  @cGS1TemplatePath_Final, -- SOS# 140526
                  @cPrinter,
                  @cLangCode,
                  @nErrNo        OUTPUT,
                  @cOutField01   OUTPUT

           -- (Vicky11) - Start
           IF @nErrNo <> 0
           BEGIN
               SET @cQty = ''
               SET @cOutField04 = CASE WHEN ISNULL(@nCasePackDefaultQty, 0) = 0 THEN '' ELSE @nCasePackDefaultQty END
               SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               EXEC rdt.rdtSetFocusField @nMobile, 1
               SET @cOutField01 = '' -- (ChewKP06)
               GOTO QUIT
           END

SELECT @d_step7 = @d_step7 + (GETDATE() - @d_date), @n_step7 = @n_step7 + 1
-- Step7 end
           -- (Vicky11) -- End


            --SOS# 183480
            INSERT INTO dbo.GS1LOG
            ( MobileNo, UserName, FuncId, TraceName
            , PickSlipNo, LoadKey, OrderKey, DropId
            , StorerKey, Facility, Col1, Col2, Col3, Col10 )
            VALUES(@nMobile, @cUserName, @nFunc, 'GS1MainSP'
                  , @cPickSlipNo, @cLoadkey, @cOrderkey, @cDropID
                  , @cStorerkey, @cFacility, @cPickSlipType, @n_PrePack, @nErrNo, '***B')

               IF @nErrNo <> 0
               BEGIN
                  SET @cQty = ''
                  SET @cOutField04 = CASE WHEN ISNULL(@nCasePackDefaultQty, 0) = 0 THEN '' ELSE @nCasePackDefaultQty END
                  SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- (Vicky11)                    EXEC rdt.rdtSetFocusField @nMobile, 1
                  GOTO QUIT
               END
         FETCH NEXT FROM CUR_ORDER INTO @cOrderKey , @cPickSlipNo, @cDischargePlace, @cBuyerPO

       END
      CLOSE CUR_ORDER
      DEALLOCATE CUR_ORDER
      -- Loop of SKU for Packing and GS1 Label generation (END) --
   END  -- Single

   /***************************************************************/
   -- Update DropID Table Status = '5' After Label Printed (START) --

   BEGIN TRAN
   UPDATE dbo.DROPID WITH (ROWLOCK)
   SET LABELPRINTED = 'Y' , STATUS = '5', ArchiveCop = 'd' --SOS# 183480
   WHERE DROPID = @cDropID

   IF @@ERROR <> 0
   BEGIN
        SET @nErrNo = 68741
        SET @cErrMSG = rdt.rdtgetmessage( 68741, @cLangCode, 'DSP') --'UPD ID FAILED'

        SET @cOutField01 = @cPrinter
        SET @cOutField02 = ''
        SET @cPickSlipNo = ''
        EXEC rdt.rdtSetFocusField @nMobile, 2
        SET @nESCCheck = 0
        ROLLBACK TRAN
        GOTO QUIT
    END
    ELSE
    BEGIN
        COMMIT TRAN
    END
 -- Update DropID Table Status = '5' After Label Printed (END) --
 /***************************************************************/
-- Step8 start --------------------------------------------------------------------------------------------------------------------------------------------------------
SET @d_step8 = GETDATE()
       /* -- Pack Confirmation (Start) (ChewKP02) --*/
       DECLARE CUR_ORDER CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
       SELECT DISTINCT PD.Orderkey, PH.PickHeaderkey FROM dbo.PICKDETAIL PD WITH (NOLOCK)
       INNER JOIN dbo.PICKHEADER PH WITH (NOLOCK) ON ( PH.ORDERKEY = PD.ORDERKEY )
       INNER JOIN dbo.Orders O WITH (NOLOCK) ON ( O.ORDERKEY = PD.ORDERKEY )
       WHERE PD.StorerKey = @cStorerkey
       AND   PH.ExternOrderKey = @cLoadkey
       AND   PD.DROPID = @cDropID
       ORDER BY PH.PickHeaderkey

       OPEN CUR_ORDER
       FETCH NEXT FROM CUR_ORDER INTO @cOrderKey , @cPickSlipNo
       WHILE @@FETCH_STATUS <> -1
       BEGIN

          -- (Vicky01) - Start
          DECLARE @nCntTotal INT, @nCntPrinted INT

          SET @nCntTotal = 0
          SET @nCntPrinted = 0

          -- (Vicky03) - Start
          SELECT @nCntTotal = SUM(PD.QTY) FROM dbo.PICKDETAIL PD WITH (NOLOCK)
          INNER JOIN dbo.Orders O WITH (NOLOCK) ON ( O.ORDERKEY = PD.ORDERKEY )
          INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( O.ORDERKEY = OD.ORDERKEY AND
                                                                       OD.OrderLineNumber = PD.OrderLinenUmber)
          WHERE PD.StorerKey = @cStorerKey
          AND O.ORDERKEY = @cOrderKey

          SELECT @nCntPrinted = SUM(PCD.QTY) FROM dbo.PACKDETAIL PCD WITH (NOLOCK)
          INNER JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON ( PH.PickSlipNo = PCD.PickSlipNo )
          INNER JOIN dbo.Orders O WITH (NOLOCK) ON ( O.ORDERKEY = PH.ORDERKEY )
          WHERE O.StorerKey = @cStorerKey
          AND O.ORDERKEY = @cOrderKey
          -- (Vicky03) - End

          IF @nCntTotal = @nCntPrinted
          BEGIN/*
            BEGIN TRAN  -- (jamesxx)
            INSERT INTO dbo.TEMP_SCANOUT (DROPID, ORDERKEY, PICKSLIPNO)
            VALUES
            (@cDropID, @cOrderKey, @cPickslipNo)
            IF @@ERROR <> 0
             BEGIN
                SET @nErrNo = 68742
                SET @cErrMSG = rdt.rdtgetmessage( 68742, @cLangCode, 'DSP') --'UPD PH FAILED'

                SET @cOutField01 = @cPrinter
                SET @cOutField02 = ''
                SET @cPickSlipNo = ''
                EXEC rdt.rdtSetFocusField @nMobile, 2
                SET @nESCCheck = 0
                ROLLBACK TRAN
                GOTO QUIT
             END
             ELSE
             BEGIN
                COMMIT TRAN
             END*/

          -- (Vicky01) - End
             BEGIN TRAN
             UPDATE dbo.PACKHEADER WITH (ROWLOCK)
             SET STATUS = '9'
             WHERE PICKSLIPNO = @cPickslipNo
             AND ORDERKEY = @cOrderKey

             IF @@ERROR <> 0
             BEGIN
                SET @nErrNo = 68742
                SET @cErrMSG = rdt.rdtgetmessage( 68742, @cLangCode, 'DSP') --'UPD PH FAILED'

                SET @cOutField01 = @cPrinter
                SET @cOutField02 = ''
                SET @cPickSlipNo = ''
                EXEC rdt.rdtSetFocusField @nMobile, 2
                SET @nESCCheck = 0
                ROLLBACK TRAN
                GOTO QUIT
             END
             ELSE
             BEGIN
                COMMIT TRAN
             END

             BEGIN TRAN
             UPDATE dbo.PICKINGINFO WITH (ROWLOCK)
             SET SCANOUTDATE = GETDATE()
             WHERE PickslipNo = @cPickslipNo

             IF @@ERROR <> 0
             BEGIN
                SET @nErrNo = 68743
                SET @cErrMSG = rdt.rdtgetmessage( 68743, @cLangCode, 'DSP') --'SCAN OUT FAIL'

                SET @cOutField01 = @cPrinter
                SET @cOutField02 = ''
                SET @cPickSlipNo = ''
                EXEC rdt.rdtSetFocusField @nMobile, 2
                SET @nESCCheck = 0
                ROLLBACK TRAN
                GOTO QUIT
             END
             ELSE
             BEGIN
                COMMIT TRAN
             END
          END --END IF
select @n_step8 = @n_step8 + 1
         FETCH NEXT FROM CUR_ORDER INTO @cOrderKey , @cPickSlipNo
       END
      CLOSE CUR_ORDER
      DEALLOCATE CUR_ORDER
      /* -- Pack Confirmation (END) (ChewKP02) --*/

SELECT @d_step8 = GETDATE() - @d_step8
-- Step8 end --------------------------------------------------------------------------------------------------------------------------------------------------------
 /***************************************************************/
 -- GEN GS1 to WCS (START) --
-- Step9 start --------------------------------------------------------------------------------------------------------------------------------------------------------
SET @d_step9 = GETDATE()
   EXEC rdt.rdt_Print_GS1_Carton_Label_GS1Info2WCS
        @nMobile,
        @cFacility,
        @cStorerKey,
        @cDropID,
        @cMBOLKey,
        @cLoadKey,
        @cWCSFilePath1,
        @cPrepackByBOM,
        @cUserName,
        --@cTemplateID,
        @cPrinter,
        @cLangCode,
        @nCaseCnt, -- (Vicky02)
        @nErrNo        OUTPUT,
        @cOutField01   OUTPUT


     IF @nErrNo <> 0
     BEGIN
        SET @cQty = ''
        SET @cOutField04 = CASE WHEN ISNULL(@nCasePackDefaultQty, 0) = 0 THEN '' ELSE @nCasePackDefaultQty END
        SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- (Vicky11)
        EXEC rdt.rdtSetFocusField @nMobile, 1
        GOTO QUIT
     END

SELECT @d_step9 = GETDATE() - @d_step9, @n_step9 = @n_step9 + 1
-- Step9 end --------------------------------------------------------------------------------------------------------------------------------------------------------
 -- GEN GS1 to WCS (END) --
 /***************************************************************/


 /***************************************************************/
 -- LANE Release Handling (START) --
-- Step10 start --------------------------------------------------------------------------------------------------------------------------------------------------------
SET @d_step10 = GETDATE()

   DECLARE CUR_TASK CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   --SELECT LL.Loadkey, LL.LP_LaneNumber , ExternOrderkey , ConsigneeKey , Loc , LocationCategory
   SELECT LL.Loadkey, LL.LP_LaneNumber ,  Loc , LocationCategory -- (Vicky03)
   FROM dbo.LOADPLANLANEDETAIL LL WITH (NOLOCK)
   WHERE LL.Loadkey = @cLoadkey
   AND LocationCategory <> 'STAGING'

   OPEN CUR_TASK
-- FETCH NEXT FROM CUR_TASK INTO @cLLLoadkey,   @cLLLP_LaneNumber ,  @cLLExternOrderkey, @cLLConsigneeKey, @cLLLOC, @cLLLLocCat
   FETCH NEXT FROM CUR_TASK INTO @cLLLoadkey,   @cLLLP_LaneNumber ,  @cLLLOC, @cLLLLocCat -- (Vicky03)
   WHILE @@FETCH_STATUS <> -1
   BEGIN

       IF  NOT EXISTS (SELECT 1 FROM dbo.TASKDETAIL TD WITH (NOLOCK)
                      INNER JOIN dbo.LoadPlanLaneDetail LL WITH (NOLOCK) ON (LL.Loadkey = TD.Loadkey) AND (LL.LOC = TD.TOLOC)
                      INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = TD.TOLOC)
                      WHERE TD.Loadkey = @cLoadkey
                      AND   TD.STATUS <> '9'
                      AND   TD.TaskType = 'NMV'
                      AND   LL.LocationCategory = @cLLLLocCat)
        BEGIN
           BEGIN TRAN
           UPDATE dbo.LOADPLANLANEDETAIL WITH (ROWLOCK)
             SET STATUS = '9'
           WHERE Loadkey = @cLLLoadkey
-- Comment by (Vicky03)
--         AND LP_LaneNumber = @cLLLP_LaneNumber
--         AND EXTERNORDERKEY = @cLLExternOrderkey
--         AND ConsigneeKey = @cLLConsigneeKey
           AND LOC = @cLLLOC
           AND LocationCategory = @cLLLLocCat


           IF @@ERROR <> 0
           BEGIN
               SET @nErrNo = 68745
               SET @cErrMSG = rdt.rdtgetmessage( 68745, @cLangCode, 'DSP') --'UPD TASK FAIL'

               SET @cOutField01 = @cPrinter
               SET @cOutField02 = ''
               SET @cPickSlipNo = ''
               EXEC rdt.rdtSetFocusField @nMobile, 2
               SET @nESCCheck = 0
               ROLLBACK TRAN
               GOTO QUIT
           END
           ELSE
           BEGIN
               COMMIT TRAN
           END
       END

-- FETCH NEXT FROM CUR_TASK INTO @cLLLoadkey,   @cLLLP_LaneNumber ,  @cLLExternOrderkey, @cLLConsigneeKey, @cLLLOC, @cLLLLocCat

select @n_step10 = @n_step10 + 1
   FETCH NEXT FROM CUR_TASK INTO @cLLLoadkey,   @cLLLP_LaneNumber , @cLLLOC, @cLLLLocCat -- (Vicky03)
   END

   CLOSE CUR_TASK
   DEALLOCATE CUR_TASK

SELECT @d_step10 = GETDATE() - @d_step10
-- Step10 end -----------------------------------------------------------------------------------------------------------------------------------------------------------
 -- LANE Release Handling (END) --
 /***************************************************************/


--   IF @nSetTemplate <> 1
--          BEGIN
         -- Prepare next screen var
   SET @cOutField01 = @cDropID
   SET @cOutField02 = @nTotalCtnsALL
   SET @nScn = @nScn + 1
   SET @nStep = @nStep + 1
   SET @nESCCheck = 0
--          END
 END -- input = 1

 IF @nInputKey = 0 AND @nESCCheck = 0--ESC
 BEGIN
      --go to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
 END
 GOTO QUIT

END
GOTO Quit

/********************************************************************************
Step 2. Scn = 2221.
   LABELLING
   DROP ID           (field01)
   CARTON PRINTED NO (field02)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
          -- Prepare next screen var
          SET @cOutField01 = @cPrinter
          SET @cOutField02 = ''  -- DropID

          SET @cOutField03 = ''
          SET @cOutField04 = ''
          SET @cOutField05 = ''
          SET @cOutField06 = ''
          SET @cOutField07 = ''
          SET @cOutField08 = ''
          SET @cOutField09 = ''   -- Option
          SET @cOutField10 = ''
          SET @c_LoosePick = ''

          EXEC rdt.rdtSetFocusField @nMobile, 2 -- (Vicky06)
            --GOTO Quit

          -- Go to first screen

          SET @cStorerkey = 'ALL'
          SET @cPickSlipNo = ''
          SET @cDropID = ''

          SET @cGenTemplateID = '' -- (Vicky07)
          SET @cTemplateID = ''  -- (Vicky07)


          SET @nScn = @nScn - 1
          SET @nStep = @nStep - 1

   END

--   IF @nInputKey = 0 -- ESC
--   BEGIN
--
--      -- Prepare prev screen var
--      SET @cOutField01 = ''  -- Printer
--      SET @cOutField02 = ''  -- DropID
--
--      SET @cPickSlipNo = ''
--      SET @cDropID = ''
--      SET @cPrinter = ''
--
--    -- Go to prev screen
--      SET @nScn = @nScn - 1
--      SET @nStep = @nStep - 1
--   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cOutField06 = ''
      SET @cSKU = '' -- SKU
      SET @cUPC_SKU = '' -- SKU
   END

END
GOTO Quit

/********************************************************************************
Step 3. Scn = 2222.
   OPTION     (field01, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 68744
         SET @cErrMsg = rdt.rdtgetmessage( 68744, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_3_Fail
      END

      -- If option = 1, template id will be defaulted to 'Generic.btw'
      IF @cOption = '1'
      BEGIN
--         SET @cTemplateID = 'Generic.btw'
         SET @cGenTemplateID = 'Generic.btw'

         -- Prepare next screen var
         SET @cOutField01 = @cPrinter
         SET @cOutField02 = @cDropID
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''   -- SKU/UPC

         -- Go to prev screen
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2

  --       GOTO Quit
      END

      -- If option = 2, prompt error and go back to screen 1
      IF @cOption = '2'
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '68745 Template ID'
         SET @cErrMsg2 = 'not setup'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
            @cErrMsg1, @cErrMsg2
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
         END
         SET @cOutField01 = @cPrinter
         SET @cOutField02 = ''
         SET @cPickSlipNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2

         -- Go to prev screen
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
        -- GOTO Quit
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cPrinter
      SET @cOutField02 = @cDropID
      EXEC rdt.rdtSetFocusField @nMobile, 2

      -- Go to prev screen
      SET @nScn = @nScn - 2
     SET @nStep = @nStep - 2
   END
   GOTO QUIT

   Step_3_Fail:
   BEGIN
      SET @cOption = ''

      -- Reset this screen var
      SET @cOutField01 = ''
   -- GOTO Quit
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
   SET @n_total = @n_step1 + @n_step2 + @n_step3 + @n_step4 + @n_step5 + @n_step6 + @n_step7 + @n_step8 + @n_step9 + @n_step10
   IF @n_debug = 1 and @n_total > 0
   BEGIN
      SET @c_TraceName = LEFT(
         'rdtfnc_Print_GS1_Carton_Label' +
         ' DropID=' + RTRIM( @cDropID), 80)

      SET @d_endtime = GETDATE()
      SET @d_total = @d_endtime - @d_starttime

      INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)
      VALUES ( @c_TraceName ,@d_starttime, @d_endtime,
         LEFT(CONVERT( NVARCHAR( 12), @d_total, 114),8) + '-' + CAST( @n_total AS NVARCHAR( 3)),
         LEFT(CONVERT( NVARCHAR( 12), @d_step1, 114),8) + '-' + CAST( @n_step1 AS NVARCHAR( 3)),
         LEFT(CONVERT( NVARCHAR( 12), @d_step2, 114),8) + '-' + CAST( @n_step2 AS NVARCHAR( 3)),
         LEFT(CONVERT( NVARCHAR( 12), @d_step3, 114),8) + '-' + CAST( @n_step3 AS NVARCHAR( 3)),
         LEFT(CONVERT( NVARCHAR( 12), @d_step4, 114),8) + '-' + CAST( @n_step4 AS NVARCHAR( 3)),
         LEFT(CONVERT( NVARCHAR( 12), @d_step5, 114),8) + '-' + CAST( @n_step5 AS NVARCHAR( 3)),
         LEFT(CONVERT( NVARCHAR( 12), @d_step6, 114),8) + '-' + CAST( @n_step6 AS NVARCHAR( 3)),
         LEFT(CONVERT( NVARCHAR( 12), @d_step7, 114),8) + '-' + CAST( @n_step7 AS NVARCHAR( 3)),
         LEFT(CONVERT( NVARCHAR( 12), @d_step8, 114),8) + '-' + CAST( @n_step8 AS NVARCHAR( 3)),
         LEFT(CONVERT( NVARCHAR( 12), @d_step9, 114),8) + '-' + CAST( @n_step9 AS NVARCHAR( 3)),
         LEFT(CONVERT( NVARCHAR( 12), @d_step10,114),8) + '-' + CAST( @n_step10 AS NVARCHAR( 3)))
   END

BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      --Printer   = @cPrinter, -- (ChewKP03)
      UserName  = @cUserName,
      InputKey  = @nInputKey,


      V_UOM = @cPUOM,
      V_QTY = @nQTY,
      V_SKU = @cSKU,

      V_SKUDescr   = @cDescr,
      V_PickSlipNo = @cPickSlipNo,
      V_OrderKey   = @cOrderKey,
      V_LoadKey    = @cLoadKey,

      V_String1  = @cCheckPickB4Pack,
      V_String2  = @cGSILBLITF,
      V_String3  = @cPrepackByBOM,
      V_String4  = @cAutoPackConfirm,
      V_String5  = @nCasePackDefaultQty,
      V_String6  = @cUPC_SKU,
      V_String7  = @cPickSlipType,
      V_String8  = @cMBOLKey,
      V_String9  = @cBuyerPO,
      V_String10 = @cTemplateID,
      V_String11 = @cFilePath1,
      V_String12 = @cFilePath2,
      V_String13 = @nCartonNo,
      V_String14 = @cLabelNo,
      V_String15 = @cSKU1,
      V_String16 = @cSKU2,
      V_String17 = @cSKU_Descr1,
      V_String18 = @cSKU_Descr2,
      V_String19 = @cQtyAlloc1,
      V_String20 = @cQtyAlloc2,
      V_String21 = @cQtyScan1,
      V_String22 = @cQtyScan2,
      V_String23 = @nPickDSKUQty,
      V_String24 = @nPackDSKUQty,
      V_String25 = @nPages,
      V_String26 = @cPrinter,
      V_String27 = @cGS1TemplatePath1, -- (Vicky03)
      V_String28 = @nCaseCnt, -- (Vicky02)
      V_String29 = @cGenTemplateID, -- (Vicky03)
      V_String30 = @cGS1TemplatePath2, -- (Vicky03)
      V_String31 = @cGS1TemplatePath3, -- (Vicky03)
      V_String32 = @cGS1TemplatePath4, -- (Vicky03)
      V_String33 = @cGS1TemplatePath5, -- (Vicky03)
      V_String34 = @cGS1TemplatePath6, -- (Vicky03)
      V_String35 = @cDropID,
      V_String36 = @c_LoosePick,
      V_String37 = @nTotalCtnsALL,
      V_String38 = @nESCCheck,

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