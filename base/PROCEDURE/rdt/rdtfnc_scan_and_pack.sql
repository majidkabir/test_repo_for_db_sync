SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: RDT Scan And Pack SOS127598                                       */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2008-12-01 1.0  James      Created                                         */
/* 2009-06-25 1.1  James      Pack Confirmation to consider both Conso and    */
/*                            Discreate PickSlip (James01)                    */
/* 2009-06-25 1.2  Leong      SOS# 140526 - Bug Fix for GS1 path              */
/* 2009-06-05 1.3  Vicky      SOS#137790 - Insert TTLCTNS when creating       */
/*                            PackHeader and                                  */
/*                            Skip QTY screen if RDT StoreConfig "SkipQTYScn" */
/*                            is turned on and the UPC entered is             */
/*                            setup as UOM =ÆCSÆ in the UPC table             */
/*                            (Vicky01)                                       */
/* 2009-06-26 1.4  Vicky      SOS#140289 - Should include casecnt during      */
/*                            scanning (Vicky02)                              */
/* 2009-06-30 1.5  Vicky      Re-assign @cGS1TemplatePath when the template   */
/*                            is Generic.btw (Vicky03)                        */    
/* 2009-10-21 1.6  James      SOS151037 - Remove checking on orderkey         */
/*                            existence on mbol (james02)                     */   
/* 2009-10-30 1.7  James      Performance Tuning (james03)                    */    
/* 2010-01-13 1.8  James      SOS158437 - remove archivecop to enable update  */    
/*                            on mboldetail.TotalCartons (james04)            */
/* 2010-05-05 1.9  James      SOS169964 - Over/short pack issue (james05)     */
/* 2010-08-03 2.0  ChewKP     SOS183212 - Allow pack after scan in and before */
/*                            ship (ChewKP01)                                 */
/* 2011-06-21 2.1  James      SOS217551 - Cater for non bom (james06)         */
/* 2011-11-16 2.1  James      SOS230587 - Bug fix GS1 file template name too  */
/*                            long (james07)                                  */
/*2015-06-23  2.2  James      Turn off debug (james08)                        */
/*2016-09-30  2.3  Ung        Performance tuning                              */
/*2018-10-19  2.4  Gan        Performance tuning                              */
/******************************************************************************/
CREATE PROC [RDT].[rdtfnc_Scan_And_Pack] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE 
   @cOption     NVARCHAR( 1),
   @nCount      INT,
   @nRowCount   INT,
   @bDebug      INT,
   @cGS1BatchNo NVARCHAR(10) 


   SET @bDebug = 0   -- (james08)
   
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
   @cPrinter   NVARCHAR( 20),
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
   @nQty                INT,
   @cPickDetailKey      NVARCHAR( 18),
   @cStatus             NVARCHAR( 10),
   @cPickSlipNo         NVARCHAR( 10),
   @cLogicalLocation    NVARCHAR( 18),
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
   -- Vicky01 - (End)

   -- Vicky02 - (Start)
   @cUPC_Packkey        NVARCHAR(10),
   @nCaseCnt            INT,
   -- Vicky02 - (End)

   @cTemp_OrderKey      NVARCHAR( 10), -- James
   @nCheck              INT,        -- (james05)
   @nBOM_Qty            INT,        -- (james05)
   @cBOM_SKU            NVARCHAR( 20),  -- (james05)
   @cDisableAutoPickAfterPack NVARCHAR(1), -- (ChewKP01)
   @nSKUCaseCnt         INT,        -- (james06)
   @cPDSKU              NVARCHAR(20),   -- (james06)
   @cLongTemplateID     NVARCHAR( 30),  -- (james07)

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
   @cPickSlipNo = V_PickSlipNo,
   @cOrderKey   = V_OrderKey,
   @cLoadKey    = V_LoadKey,
   
   @nCartonNo   = V_Cartonno,
   
   @cCheckPickB4Pack    = V_Integer1,
   @cGSILBLITF          = V_Integer2,
   @cPrepackByBOM       = V_Integer3,
   @cAutoPackConfirm    = V_Integer4,
   @nCasePackDefaultQty = V_Integer5,
   @nPickDSKUQty        = V_Integer6,
   @nPackDSKUQty        = V_Integer7,
   @nPages              = V_Integer8,
   @nCaseCnt            = V_Integer9,

  -- @cCheckPickB4Pack    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String1,  5), 0) = 1 THEN LEFT( V_String1,  5) ELSE 0 END,
  -- @cGSILBLITF          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String2,  5), 0) = 1 THEN LEFT( V_String2,  5) ELSE 0 END,
  -- @cPrepackByBOM       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3,  5), 0) = 1 THEN LEFT( V_String3,  5) ELSE 0 END,
  -- @cAutoPackConfirm    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4,  5), 0) = 1 THEN LEFT( V_String4,  5) ELSE 0 END,
  -- @nCasePackDefaultQty = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5,  5), 0) = 1 THEN LEFT( V_String5,  5) ELSE 0 END,

   @cUPC_SKU            = V_String6,
   @cPickSlipType       = V_String7,
   @cMBOLKey            = V_String8,
   @cBuyerPO            = V_String9,
   @cTemplateID         = V_String10,
   @cFilePath1          = V_String11,
   @cFilePath2          = V_String12,
  -- @nCartonNo           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String13,  5), 0) = 1 THEN LEFT( V_String13,  5) ELSE 0 END,
   @cLabelNo            = V_String14,
   @cSKU1               = V_String15,
   @cSKU2               = V_String16,
   @cSKU_Descr1         = V_String17,
   @cSKU_Descr2         = V_String18,
   @cQtyAlloc1          = V_String19,
   @cQtyAlloc2          = V_String20,
   @cQtyScan1           = V_String21,
   @cQtyScan2           = V_String22,
  -- @nPickDSKUQty        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String23,  5), 0) = 1 THEN LEFT( V_String23,  5) ELSE 0 END,
  -- @nPackDSKUQty        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String24,  5), 0) = 1 THEN LEFT( V_String24,  5) ELSE 0 END,
  -- @nPages              = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String25,  5), 0) = 1 THEN LEFT( V_String25,  5) ELSE 0 END,
   @cPrinter            = V_String26,
   @cGS1TemplatePath1   = V_String27, -- (Vicky03)
  -- @nCaseCnt            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String28,  5), 0) = 1 THEN LEFT( V_String28,  5) ELSE 0 END, -- (Vicky02)
   @cGenTemplateID      = V_String29, -- (Vicky03)
   @cGS1TemplatePath2   = V_String30, -- (Vicky03)
   @cGS1TemplatePath3   = V_String31, -- (Vicky03)
   @cGS1TemplatePath4   = V_String32, -- (Vicky03)
   @cGS1TemplatePath5   = V_String33, -- (Vicky03)
   @cGS1TemplatePath6   = V_String34, -- (Vicky03)
   @cDiscrete_PickSlipNo= V_String35, -- (james03)

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

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 1750  -- Scan And Pack
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Scan And Pack
   IF @nStep = 1 GOTO Step_1   -- Scn = 1931. PRINTER ID, PS NO
   IF @nStep = 2 GOTO Step_2   -- Scn = 1932. PS NO, LOADKEY, ORDERKEY, LABELNO, CARTONNO, SKU/UPC
   IF @nStep = 3 GOTO Step_3   -- Scn = 1933. PS NO, LABEL NO, CARTON NO, SKU, QTY, QTY SCN/ALLOC, QTY REMAIN, OPTION
   IF @nStep = 4 GOTO Step_4   -- Scn = 1934. SKU, QTY ALLOC, QTY SCAN, OPTION
   IF @nStep = 5 GOTO Step_5   -- Scn = 1935. OPTION
   IF @nStep = 6 GOTO Step_6   -- Scn = 1936. OPTION
   IF @nStep = 7 GOTO Step_7   -- Scn = 1937. OPTION
   IF @nStep = 8 GOTO Step_8   -- Scn = 1938. MSG
   IF @nStep = 9 GOTO Step_9   -- Scn = 1939. MSG
END

--RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1750. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

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

   SET @cAutoPackConfirm = rdt.RDTGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)
   SET @nCasePackDefaultQty =  CAST(rdt.RDTGetConfig( @nFunc, 'CasePackDefaultQty', @cStorerKey) AS INT)


   SET @cLabelNo = ''

   -- Set the entry point
   SET @nScn = 1931
   SET @nStep = 1

   -- Initiate var
   SET @cPickSlipNo = ''
   SET @cPrinter = ''

   -- Init screen
   SET @cOutField01 = '' -- Printer
   SET @cOutField02 = '' -- PSNO
  
END
GOTO Quit

/********************************************************************************
Step 1. Scn = 1931. 
   PRINTER ID (field01, input)
   PSNO       (field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      --screen mapping
	   SET @cPrinter = @cInField01
	   SET @cPickSlipNo = @cInField02

      -- Check Printer ID
		IF ISNULL(@cPrinter, '') = ''
      BEGIN
         SET @nErrNo = 66266
         SET @cErrMsg = rdt.rdtgetmessage( 66266, @cLangCode, 'DSP') --Printer ID req
         SET @cOutField01 = ''
         SET @cOutField02 = @cPickSlipNo
         SET @cPrinter = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Validate blank
      IF ISNULL(@cPickSlipNo, '') = ''
      BEGIN
         SET @nErrNo = 66251
         SET @cErrMsg = rdt.rdtgetmessage( 66251, @cLangCode,'DSP') --PSNO requiured
   SET @cOutField01 = @cPrinter
         SET @cOutField02 = ''
         SET @cPickSlipNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      -- Validate pickslipno
      IF NOT EXISTS (SELECT 1 
         FROM dbo.PickHeader WITH (NOLOCK)
	      WHERE PickHeaderKey = @cPickSlipNo)
      BEGIN
	      SET @nErrNo = 66252
         SET @cErrMsg = rdt.rdtgetmessage( 66252, @cLangCode,'DSP') --Invalid PSNO
         SET @cOutField01 = @cPrinter
         SET @cOutField02 = ''
         SET @cPickSlipNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
	   END 

      -- Determine pickslip type, either Discrete/Consolidated
	   IF NOT EXISTS (SELECT O.StorerKey  
         FROM dbo.PickHeader PH WITH (NOLOCK)
	      LEFT OUTER JOIN dbo.ORDERS O WITH (NOLOCK) ON (O.OrderKey = PH.OrderKey)
	      WHERE PH.PickHeaderKey = @cPickSlipNo
         GROUP BY O.StorerKey
         HAVING COUNT(O.StorerKey) >= 1)
         SET @cPickSlipType = 'CONSO'
	   ELSE
		   SET @cPickSlipType = 'SINGLE'

      IF @cPickSlipType = 'CONSO'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            WHERE PH.PickHeaderKey = @cPickSlipNo
               AND L.Facility = @cFacility)
         BEGIN
            SET @nErrNo = 66293
            SET @cErrMsg = rdt.rdtgetmessage( 66293, @cLangCode, 'DSP') --Diff Facility
            SET @cOutField01 = @cPrinter
            SET @cOutField02 = ''
            SET @cPickSlipNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            WHERE PH.PickHeaderKey = @cPickSlipNo
               AND L.Facility = @cFacility)
         BEGIN
            SET @nErrNo = 66294
            SET @cErrMsg = rdt.rdtgetmessage( 66294, @cLangCode, 'DSP') --Diff Facility
            SET @cOutField01 = @cPrinter
            SET @cOutField02 = ''
            SET @cPickSlipNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END        
      END

		SET @cLoadKey = ''
      -- Check if the pick slip's storer is same with current RDT loginÆs storer
      IF @cPickSlipType = 'CONSO'
      BEGIN
         IF NOT EXISTS (SELECT 1 
			   FROM   dbo.PickHeader PH WITH (NOLOCK) 
			   JOIN   dbo.Orders O WITH (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
			   WHERE  PH.PickHeaderKey = @cPickSlipNo
			      AND O.StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 66253
            SET @cErrMsg = rdt.rdtgetmessage( 66253, @cLangCode, 'DSP') --Diff Storer
            SET @cOutField01 = @cPrinter
            SET @cOutField02 = ''
            SET @cPickSlipNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         -- Check If the Loadplan consists of multi-storer
         IF EXISTS( SELECT 1
		      FROM   dbo.PickHeader PH WITH (NOLOCK) 
		      JOIN   dbo.Orders O WITH (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
		      WHERE  PH.PickHeaderKey = @cPickSlipNo
		      GROUP BY O.LoadKey
            HAVING COUNT( DISTINCT O.StorerKey) > 1)
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '66254 PSNO more than'
            SET @cErrMsg2 = '1 Storer'
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
            GOTO Quit
         END

         SELECT TOP 1 @cLoadKey = O.LoadKey
		   FROM   dbo.PickHeader PH WITH (NOLOCK) 
		   JOIN   dbo.Orders O WITH (NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
		   WHERE  PH.PickHeaderKey = @cPickSlipNo

         IF EXISTS (SELECT 1 FROM dbo.Packdetail PD WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo
               AND ISNULL(Refno, '') = '')
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '66298 This PKSlip '
            SET @cErrMsg2 = 'already start with'
            SET @cErrMsg3 = 'discrete pack. Pls'
            SET @cErrMsg4 = 'use discrete PKSlip#'
            SET @cErrMsg5 = 'to scan'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
               SET @cErrMsg5 = ''
            END
            SET @cOutField01 = @cPrinter
            SET @cOutField02 = ''
            SET @cPickSlipNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END
      END
      ELSE
		BEGIN
         IF NOT EXISTS (SELECT 1
			   FROM   dbo.PickHeader PH WITH (NOLOCK) 
			   JOIN   dbo.Orders O WITH (NOLOCK) ON (PH.OrderKey = O.OrderKey)
			   WHERE  PH.PickHeaderKey = @cPickSlipNo
			      AND O.StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 66255
            SET @cErrMsg = rdt.rdtgetmessage( 66255, @cLangCode, 'DSP') --Diff Storer
            SET @cOutField01 = @cPrinter
            SET @cOutField02 = ''
            SET @cPickSlipNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         -- Check If the Loadplan consists of multi-storer
         IF EXISTS(SELECT 1
		      FROM   dbo.PickHeader PH WITH (NOLOCK) 
		      JOIN   dbo.Orders O WITH (NOLOCK) ON (PH.OrderKey = O.OrderKey)
		      WHERE  PH.PickHeaderKey = @cPickSlipNo
		      GROUP BY O.LoadKey
            HAVING COUNT( DISTINCT O.StorerKey) > 1)
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '66256 PSNO more than'
            SET @cErrMsg2 = '1 Storers'
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
            GOTO Quit
         END

         SELECT TOP 1 @cLoadKey = O.LoadKey
		   FROM   dbo.PickHeader PH WITH (NOLOCK) 
		   JOIN   dbo.Orders O WITH (NOLOCK) ON (PH.OrderKey = O.OrderKey)
		   WHERE  PH.PickHeaderKey = @cPickSlipNo

         -- Check if the pickslip scanned in is discrete which belong to conso pickslip
         IF EXISTS (SELECT 1 FROM dbo.PickHeader PIH WITH (NOLOCK) 
         WHERE PIH.ExternOrderKey = @cLoadKey
         GROUP BY PIH.ExternOrderKey
         HAVING COUNT(PIH.ExternOrderKey) > 1)
         BEGIN
            -- If the discrete pickslip scanned in is under conso and packing already start with conso pickslip
            -- then this is not allowed (difficultly in calculation qty to pack)
            -- note: we can choose to pack with discrete or conso or discrete which is under conso
				IF EXISTS (SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK)
               JOIN dbo.PickHeader PH WITH (NOLOCK) ON PD.Refno = PH.PickheaderKey
               WHERE PD.PickSlipNo = @cPickSlipNo)
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = '66292 This PKSlip '
               SET @cErrMsg2 = 'already start conso'
               SET @cErrMsg3 = 'pack. Pls use conso'
               SET @cErrMsg4 = 'PKSlip# to scan'
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                  @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
                  SET @cErrMsg2 = ''
                  SET @cErrMsg3 = ''
                  SET @cErrMsg4 = ''
               END
               SET @cOutField01 = @cPrinter
               SET @cOutField02 = ''
               SET @cPickSlipNo = ''
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO Quit
            END
         END
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) 
         Where PickslipNo = @cPickSlipNo)
      BEGIN
         SET @nErrNo = 66297
         SET @cErrMsg = rdt.rdtgetmessage( 66297, @cLangCode, 'DSP') --PS not Scan-in
         SET @cOutField01 = @cPrinter
         SET @cOutField02 = ''
         SET @cPickSlipNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      -- Check if the pick slip is scanned-in 
      IF @cPickSlipType = 'SINGLE'
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) 
            Where PickslipNo = @cPickSlipNo
               AND ScanInDate IS NULL)
         BEGIN
            SET @nErrNo = 66257
            SET @cErrMsg = rdt.rdtgetmessage( 66257, @cLangCode, 'DSP') --PS not Scan-in
            SET @cOutField01 = @cPrinter
            SET @cOutField02 = ''
            SET @cPickSlipNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) 
            Where PickslipNo = @cPickSlipNo
               AND ScanInDate IS NULL)
         BEGIN
            SET @nErrNo = 66295
            SET @cErrMsg = rdt.rdtgetmessage( 66295, @cLangCode, 'DSP') --PS not Scan-in
            SET @cOutField01 = @cPrinter
            SET @cOutField02 = ''
            SET @cPickSlipNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         IF EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) 
            Where PickslipNo IN 
               (SELECT PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) 
                  WHERE PickHeaderKey <> @cPickSlipNo
                     AND ExternOrderKey = @cLoadKey)
               AND ScanInDate IS NULL)
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '66296 Not all '
            SET @cErrMsg2 = 'PKSlip under'
            SET @cErrMsg3 = 'conso PKSlip.'
            SET @cErrMsg4 = 'scanned in'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
               SET @cErrMsg4 = ''
            END
            SET @cOutField01 = @cPrinter
            SET @cOutField02 = ''
            SET @cPickSlipNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END
      END

      -- Note: if configkey 'CheckPickB4Pack' turned on (SValue = '1')
      -- pickslip must be scanned out before can continue do packing
      -- else if configkey 'CheckPickB4Pack' turned off (SValue <> '1')
      -- pickslip cannot be scanned out before can continue do packing
--    IF @cCheckPickB4Pack = '1' 
--      BEGIN
--         IF EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) 
--            WHERE PickslipNo = @cPickSlipNo
--               AND ScanOutDate IS NULL)
--         BEGIN
--            SET @nErrNo = 0
--            SET @cErrMsg1 = '66258 Packing Cannot'
--            SET @cErrMsg2 = 'Be Done Without'
--            SET @cErrMsg3 = 'Scanning Out'
--            SET @cErrMsg4 = 'Pickslips'
--            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
--               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4 
--            IF @nErrNo = 1
--            BEGIN
--               SET @cErrMsg1 = ''
--               SET @cErrMsg2 = ''
--               SET @cErrMsg3 = ''
--               SET @cErrMsg4 = ''
--            END
--            SET @cOutField01 = @cPrinter
--            SET @cOutField02 = ''
--            SET @cPickSlipNo = ''
--            EXEC rdt.rdtSetFocusField @nMobile, 2
--            GOTO Quit
--         END
--      END
--      ELSE

      -- (ChewKP01) Start
      SET @cDisableAutoPickAfterPack = '0'
      
      SELECT @cDisableAutoPickAfterPack = SValue FROM dbo.StorerConfig WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND Configkey = 'DisableAutoPickAfterPack'
      -- (ChewKP01) End
         
      IF @cCheckPickB4Pack = '0' AND @cDisableAutoPickAfterPack = '0' -- (ChewKP01)
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) 
            Where PickslipNo = @cPickSlipNo
               AND ScanOutDate IS NOT NULL)
         BEGIN
            SET @nErrNo = 66259
            SET @cErrMsg = rdt.rdtgetmessage( 66259, @cLangCode, 'DSP') --PS scanned out
            SET @cOutField01 = @cPrinter
            SET @cOutField02 = ''
            SET @cPickSlipNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END
		END

      -- GS1 Label validation start
      IF @cGSILBLITF = '1'
      BEGIN
         SELECT @cFilePath = UserDefine20 FROM dbo.Facility WITH (NOLOCK) 
            WHERE Facility = @cFacility

         -- use 2 variables to store because facility.userdefine20 is NVARCHAR(30) while rdt v_string variable is NVARCHAR(20)
         SET @cFilePath1 = SUBSTRING(@cFilePath, 1, 20)
         SET @cFilePath2 = SUBSTRING(@cFilePath, 21, 20)

         IF ISNULL(@cFilePath1, '') = ''
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '66260 File Folder'
            SET @cErrMsg2 = 'Path has not been'
            SET @cErrMsg3 = 'setup!'
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
               @cErrMsg1, @cErrMsg2, @cErrMsg3 
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
            END
            SET @cOutField01 = @cPrinter
            SET @cOutField02 = ''
            SET @cPickSlipNo = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         SELECT @cGS1TemplatePath = NSQLDescrip
         FROM RDT.NSQLCONFIG WITH (NOLOCK)
         WHERE ConfigKey = 'GS1TemplatePath'

			IF ISNULL(@cGS1TemplatePath, '') = ''
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = '66261 Template File'
            SET @cErrMsg2 = 'Path not setup!'
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
            GOTO Quit
         END
      END
      -- GSI Label validation end

		IF @cPickSlipType = 'SINGLE' 
		BEGIN
--			SELECT TOP 1
--			   @cMBOLKey = MBOLD.MBOLKey, 
--			   @cBuyerPO = O.BuyerPO, 
--			   @cTemplateID = O.DischargePlace, 
--				@cOrderKey = O.OrderKey 
--    FROM dbo.ORDERS O WITH (NOLOCK) 
--         JOIN dbo.PICKHEADER PH WITH (NOLOCK) ON (O.OrderKey = PH.Orderkey)
--         JOIN dbo.MBOLDETAIL MBOLD WITH (NOLOCK) ON (O.MBOLKey = MBOLD.MBOLKey) 
--         WHERE PH.PickHeaderKey = @cPickslipNo
--         ORDER BY O.Priority, O.BuyerPO
--
--			IF ISNULL(@cMBOLKey, '') = ''
--         BEGIN
--            SET @nErrNo = 66262
--            SET @cErrMsg = rdt.rdtgetmessage( 66262, @cLangCode, 'DSP') --OrderNotInMBOL
--            SET @cOutField01 = @cPrinter
--            SET @cOutField02 = ''
--            SET @cPickSlipNo = ''
--            EXEC rdt.rdtSetFocusField @nMobile, 2
--            GOTO Quit
--			END

         --(james02)
			SELECT TOP 1 
			   @cBuyerPO = O.BuyerPO, 
			   @cTemplateID = O.DischargePlace, 
			   @cLongTemplateID = O.DischargePlace,   -- (james07)
				@cOrderKey = O.OrderKey 
         FROM dbo.ORDERS O WITH (NOLOCK) 
         JOIN dbo.PICKHEADER PH WITH (NOLOCK) ON (O.OrderKey = PH.Orderkey)
         WHERE PH.PickHeaderKey = @cPickslipNo
         ORDER BY O.Priority, O.BuyerPO
      END   -- IF @cPickSlipType = 'SINGLE'
         
		IF @cPickSlipType = 'CONSO'
	   BEGIN
--			SELECT 
--			   @cMbolKey = MBOLD.MBOLKEY, 
--			   @cOrderKey = MAX(MBOLD.OrderKey)
--     		FROM dbo.ORDERDETAIL OD WITH (NOLOCK) 
--         JOIN dbo.ORDERS O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
--     		JOIN dbo.LOADPLANDETAIL LPD WITH (NOLOCK) ON (OD.OrderKey = LPD.OrderKey) 
--			JOIN dbo.PICKHEADER PH WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)  
--	  		LEFT OUTER JOIN dbo.MBOLDetail MBOLD WITH (NOLOCK) ON (OD.OrderKey = MBOLD.OrderKey) 
--    		WHERE PH.PickHeaderKey = @cPickslipNo
--			GROUP BY MBOLD.MBOLKEY, O.Priority, O.BuyerPO
--         ORDER BY O.Priority, O.BuyerPO
--
--			IF ISNULL(@cMbolKey, '') = ''
--         BEGIN
--            SET @nErrNo = 66263
--            SET @cErrMsg = rdt.rdtgetmessage( 66263, @cLangCode, 'DSP') --OrderNotInMBOL
--            SET @cOutField01 = @cPrinter
--            SET @cOutField02 = ''
--            SET @cPickSlipNo = ''
--            EXEC rdt.rdtSetFocusField @nMobile, 2
--            GOTO Quit
--			END

         --(james02)
			SELECT @cOrderKey = MAX(O.OrderKey)
         FROM dbo.ORDERS O WITH (NOLOCK) 
     		JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey) 
     		JOIN dbo.LOADPLANDETAIL LPD WITH (NOLOCK) ON (OD.OrderKey = LPD.OrderKey) 
			JOIN dbo.PICKHEADER PH WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)  
    		WHERE PH.PickHeaderKey = @cPickslipNo
			GROUP BY O.Priority, O.BuyerPO
         ORDER BY O.Priority, O.BuyerPO

			SELECT TOP 1 
			   @cBuyerPO = O.BuyerPO, 
			   @cTemplateID = O.DischargePlace, 
			   @cLongTemplateID = O.DischargePlace    -- (james07)
			FROM dbo.LOADPLANDETAIL LPD (NOLOCK)
			JOIN dbo.ORDERS O (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
			JOIN dbo.PICKHEADER PH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)  
			WHERE PH.PickHeaderKey = @cPickslipNo
			   AND O.Orderkey = @cOrderKey 
      END   -- IF @cPickSlipType = 'CONSO'

      -- Set template id path

      SET @cGS1TemplatePath1 = ''
      SET @cGS1TemplatePath2 = ''
      SET @cGS1TemplatePath3 = ''
      SET @cGS1TemplatePath4 = ''
      SET @cGS1TemplatePath5 = ''
      SET @cGS1TemplatePath6 = ''

--      SET @cGS1TemplatePath = ISNULL(RTRIM(@cGS1TemplatePath), '') + '\' + ISNULL(LTRIM(@cTemplateID), '')   -- (james07)
      SET @cGS1TemplatePath = ISNULL(RTRIM(@cGS1TemplatePath), '') + '\' + ISNULL(LTRIM(@cLongTemplateID), '')

      SET @cGS1TemplatePath1 = LEFT(@cGS1TemplatePath, 20)
      SET @cGS1TemplatePath2 = SUBSTRING(@cGS1TemplatePath, 21, 20)
      SET @cGS1TemplatePath3 = SUBSTRING(@cGS1TemplatePath, 41, 20)
      SET @cGS1TemplatePath4 = SUBSTRING(@cGS1TemplatePath, 61, 20)
      SET @cGS1TemplatePath5 = SUBSTRING(@cGS1TemplatePath, 81, 20)
      SET @cGS1TemplatePath6 = SUBSTRING(@cGS1TemplatePath, 101, 20)

      SELECT @cLoadKey = LoadKey from dbo.Orders WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey

      -- Check if any outstanding qty to be packed
      IF @cPickSlipType = 'SINGLE'
   BEGIN
         SELECT @nPickDQty = ISNULL(SUM(PD.QTY), 0) 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.PickHeader PH WITH (NOLOCK) ON (PD.OrderKey = PH.OrderKey)
         WHERE PD.StorerKey = @cStorerKey
            AND PH.PickHeaderKey = @cPickslipNo

      	SELECT @nPackDQty = ISNULL(SUM(QTY), 0) FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND PickslipNo = @cPickslipNo
      END
      ELSE
      BEGIN
         SELECT @nPickDQty = ISNULL(SUM(PD.QTY), 0) 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         JOIN dbo.PickHeader PH WITH (NOLOCK) ON (O.LoadKey = PH.ExternOrderKey)
         WHERE PD.StorerKey = @cStorerKey
            AND PH.PickHeaderKey = @cPickslipNo

         SELECT @nPackDQty = ISNULL(SUM(QTY), 0) 
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE Refno = @cPickSlipNo
            AND StorerKey = @cStorerKey
      END

      -- If no more outstanding qty to be picked, goto no more task screen
      IF @nPickDQty = @nPackDQty
      BEGIN
         -- Go to next screen
         SET @nScn = @nScn + 8
         SET @nStep = @nStep + 8

         GOTO Quit
      END
      ELSE
      IF @nPickDQty > @nPackDQty
      BEGIN
         BEGIN TRAN

         -- Conso Pickslipno
         -- For conso, we only create packheader for discrete pickslip only??
         IF @cPickSlipType = 'CONSO'
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
            BEGIN
               INSERT INTO dbo.PackHeader 
               (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
	            SELECT DISTINCT ISNULL(LP.Route,''), '', '', LP.LoadKey, '', @cStorerKey, @cPickSlipNo
	            FROM  dbo.LOADPLANDETAIL LPD WITH (NOLOCK)
	            JOIN  dbo.LOADPLAN LP WITH (NOLOCK) ON (LP.LoadKey = LPD.LoadKey)
	            JOIN  dbo.ORDERS O WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
	            JOIN  dbo.PICKHEADER PH WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
	            WHERE PH.PickHeaderKey = @cPickSlipNo

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 66264
                  SET @cErrMsg = rdt.rdtgetmessage( 66264, @cLangCode, 'DSP') --'CreatePHdrFail'
                  ROLLBACK TRAN
                  SET @cOutField01 = @cPrinter
                  SET @cOutField02 = ''
                  SET @cPickSlipNo = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 2
                  GOTO Quit      
               END
            END

            DECLARE CUR_INSPKSLIP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT PickHeaderKey, PH.Orderkey FROM dbo.PickHeader PH WITH (NOLOCK) -- (Vicky01)
            JOIN dbo.Orders O WITH (NOLOCK) ON (PH.OrderKey = O.OrderKey)
            WHERE O.StorerKey = @cStorerKey
               AND O.LoadKey = @cLoadKey
            OPEN CUR_INSPKSLIP
            FETCH NEXT FROM CUR_INSPKSLIP INTO @cPickHeaderKey, @cInOrderKey -- (Vicky01)
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickHeaderKey)
               BEGIN
                  -- SOS#137790 - TTLCTNS Calculation (Vicky01 - Start)
                  SET @nTotalCtns = 0
                  SET @nPDQTY = 0
                  SET @nUPCCaseCnt = 0
                  SET @nTotalBOMQty = 0
                  SET @nLotCtns = 0
                  SET @cParentSKU = ''
                  SET @nSKUCaseCnt = 0

                  -- (james06)
                  IF @cPrepackByBOM = '1'
                  BEGIN
                     DECLARE CUR_PDLOT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
                     SELECT DISTINCT LOT FROM dbo.PickDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                       AND Orderkey = @cInOrderKey
                     OPEN CUR_PDLOT
       				   FETCH NEXT FROM CUR_PDLOT INTO @cPDLot
                     WHILE @@FETCH_STATUS <> -1
                     BEGIN
                           SELECT @nPDQTY = SUM(QTY) 
                           FROM dbo.PickDetail WITH (NOLOCK)
                           WHERE StorerKey = @cStorerKey
                           AND   Orderkey = @cInOrderKey
                           AND   LOT = @cPDLot

                           SELECT @cParentSKU = Lottable03 
                           FROM dbo.Lotattribute WITH (NOLOCK) 
                           WHERE StorerKey = @cStorerKey
                             AND LOT = @cPDLot
                        
                           SELECT @nUPCCaseCnt = PACK.CaseCNT
                           FROM dbo.UPC UPC WITH (NOLOCK)
                           JOIN dbo.PACK PACK WITH (NOLOCK) ON (UPC.PackKey = PACK.PackKey)
                           WHERE UPC.Storerkey = @cStorerKey
                           AND   UPC.SKU = @cParentSKU
                           AND   UPC.UOM = 'CS'
                           
                           IF @nUPCCaseCnt > 0
                           BEGIN
                               SELECT @nTotalBOMQty = SUM(BOM.QTY)
                               FROM dbo.BillOfMaterial BOM WITH (NOLOCK)
                               WHERE BOM.Storerkey = @cStorerKey
                               AND   BOM.SKU = @cParentSKU

                               SELECT @nLotCtns = @nPDQTY / (@nTotalBOMQty * @nUPCCaseCnt)
                           END
                           ELSE
                           BEGIN
                               SELECT @nLotCtns = 0
                           END

                           SELECT @nTotalCtns = @nTotalCtns + @nLotCtns                              

                       FETCH NEXT FROM CUR_PDLOT INTO @cPDLot
                     END
                     CLOSE CUR_PDLOT
                     DEALLOCATE CUR_PDLOT
                     -- SOS#137790 - TTLCTNS Calculation (Vicky01 - End)
                  END
                  ELSE
                  BEGIN
                     DECLARE CUR_PDSKU CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
                     SELECT DISTINCT SKU FROM dbo.PickDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                        AND Orderkey = @cInOrderKey
                     OPEN CUR_PDSKU
                     FETCH NEXT FROM CUR_PDSKU INTO @cPDSKU
                     WHILE @@FETCH_STATUS <> -1
                     BEGIN
                        SELECT @nPDQTY = ISNULL(SUM(QTY), 0)
                        FROM dbo.PickDetail WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                           AND Orderkey = @cInOrderKey
                           AND SKU = @cPDSKU

                        SELECT @nSKUCaseCnt = ISNULL(P.CaseCnt, 0) 
                        FROM dbo.Pack P WITH (NOLOCK)
                        JOIN dbo.SKU S WITH (NOLOCK) ON P.PackKey = S.PackKey
                        WHERE S.StorerKey = @cStorerKey
                           AND S.SKU = @cPDSKU

                        IF @nSKUCaseCnt > 0
                        BEGIN
                           SET @nTotalCtns = @nTotalCtns + (@nPDQTY / @nSKUCaseCnt)
                        END

                        FETCH NEXT FROM CUR_PDSKU INTO @cPDSKU
                     END
                     CLOSE CUR_PDSKU
                     DEALLOCATE CUR_PDSKU
                  END

                  INSERT INTO dbo.PackHeader 
                  (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, TTLCNTS) -- Vicky01
                  SELECT O.Route, O.OrderKey, SUBSTRING(O.ExternOrderKey, 1, 18), O.LoadKey, O.ConsigneeKey, O.Storerkey, @cPickHeaderKey,
                         @nTotalCtns -- (Vicky01)
                  FROM  dbo.PickHeader PH WITH (NOLOCK)
                  JOIN  dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)
	               WHERE PH.PickHeaderKey = @cPickHeaderKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 66264
                     SET @cErrMsg = rdt.rdtgetmessage( 66264, @cLangCode, 'DSP') --'CreatePHdrFail'
                     ROLLBACK TRAN
                     SET @cOutField01 = @cPrinter
                     SET @cOutField02 = ''
                     SET @cPickSlipNo = ''
                     EXEC rdt.rdtSetFocusField @nMobile, 2
                     GOTO Quit               
                  END
               END
               FETCH NEXT FROM CUR_INSPKSLIP INTO @cPickHeaderKey, @cInOrderKey
            END
            CLOSE CUR_INSPKSLIP
            DEALLOCATE CUR_INSPKSLIP
         END
         ELSE
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.PACKHEADER WITH (NOLOCK)
            WHERE Pickslipno = @cPickslipNo)
            BEGIN -- Packheader not exists (Start)

               -- SOS#137790 - TTLCTNS Calculation (Vicky01 - Start)
               SET @nTotalCtns = 0
               SET @nPDQTY = 0
               SET @nUPCCaseCnt = 0
               SET @nTotalBOMQty = 0
               SET @nLotCtns = 0
               SET @cParentSKU = ''
               SET @nSKUCaseCnt = 0

               SELECT @cInOrderKey = Orderkey
               FROM dbo.PickHeader WITH (NOLOCK)
               WHERE PickHeaderKey = @cPickslipNo   

               -- (james06)
               IF @cPrepackByBOM = '1'
               BEGIN
                  DECLARE CUR_PDLOT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   				   SELECT DISTINCT LOT FROM dbo.PickDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                    AND Orderkey = @cInOrderKey
                  OPEN CUR_PDLOT
                  FETCH NEXT FROM CUR_PDLOT INTO @cPDLot
                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
						   SELECT @nPDQTY = SUM(QTY) 
               	   FROM dbo.PickDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                  	   AND   Orderkey = @cInOrderKey
                  	   AND   LOT = @cPDLot

						   SELECT @cParentSKU = Lottable03 
						   FROM dbo.Lotattribute WITH (NOLOCK) 
						   WHERE StorerKey = @cStorerKey
							   AND LOT = @cPDLot
                       
						   SELECT @nUPCCaseCnt = PACK.CaseCNT
						   FROM dbo.UPC UPC WITH (NOLOCK)
						   JOIN dbo.PACK PACK WITH (NOLOCK) ON (UPC.PackKey = PACK.PackKey)
						   WHERE UPC.Storerkey = @cStorerKey
							   AND   UPC.SKU = @cParentSKU
							   AND   UPC.UOM = 'CS'

						   IF @nUPCCaseCnt > 0
						   BEGIN
						      SELECT @nTotalBOMQty = SUM(BOM.QTY)
						      FROM dbo.BillOfMaterial BOM WITH (NOLOCK)
						      WHERE BOM.Storerkey = @cStorerKey
						      AND   BOM.SKU = @cParentSKU
   						
						      SELECT @nLotCtns = @nPDQTY / (@nTotalBOMQty * @nUPCCaseCnt)
						   END
						   ELSE
						   BEGIN
						      SELECT @nLotCtns = 0
						   END
                      
						   SELECT @nTotalCtns = @nTotalCtns + @nLotCtns
                          
   						FETCH NEXT FROM CUR_PDLOT INTO @cPDLot
                  END
                  CLOSE CUR_PDLOT
                  DEALLOCATE CUR_PDLOT
                  -- SOS#137790 - TTLCTNS Calculation (Vicky01 - End)
               END
               ELSE
               BEGIN
                  DECLARE CUR_PDSKU CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
                  SELECT DISTINCT SKU FROM dbo.PickDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                     AND Orderkey = @cInOrderKey
                  OPEN CUR_PDSKU
                  FETCH NEXT FROM CUR_PDSKU INTO @cPDSKU
                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
                     SELECT @nPDQTY = ISNULL(SUM(QTY), 0)
                     FROM dbo.PickDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND Orderkey = @cInOrderKey
                        AND SKU = @cPDSKU

                     SELECT @nSKUCaseCnt = ISNULL(P.CaseCnt, 0) 
                     FROM dbo.Pack P WITH (NOLOCK)
                     JOIN dbo.SKU S WITH (NOLOCK) ON P.PackKey = S.PackKey
                     WHERE S.StorerKey = @cStorerKey
                        AND S.SKU = @cPDSKU

                     IF @nSKUCaseCnt > 0
                     BEGIN
                        SET @nTotalCtns = @nTotalCtns + (@nPDQTY / @nSKUCaseCnt)
                     END

                     FETCH NEXT FROM CUR_PDSKU INTO @cPDSKU
                  END
                  CLOSE CUR_PDSKU
                  DEALLOCATE CUR_PDSKU
               END

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
                  SET @cErrMsg = rdt.rdtgetmessage( 66265, @cLangCode, 'DSP') --'CreatePHdrFail'
                  ROLLBACK TRAN
                  SET @cOutField01 = @cPrinter
                  SET @cOutField02 = ''
                  SET @cPickSlipNo = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 2
                  GOTO Quit               
               END
            END
         END

         COMMIT TRAN
      END   -- IF @nPickDQty > @nPackDQty

      -- Check ORDERS.DischargePlace (Template ID) is not being setup, goto screen 5
      IF ISNULL(@cTemplateID, '') = ''
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = ''
         SET @cGenTemplateID = '' -- (Vicky03) 

         -- Go to next screen
         SET @nScn = @nScn + 4
         SET @nStep = @nStep + 4  

         GOTO Quit
      END

      SET @nCartonNo = 0
      SET @cLabelNo = ''

      -- Prepare next screen var
      SET @cOutField01 = @cPickSlipNo 
      SET @cOutField02 = @cLoadKey
      SET @cOutField03 = CASE WHEN @cPickSlipType = 'CONSO' THEN 'MULTI' ELSE @cOrderKey END
      SET @cOutField04 = ''
      SET @cOutField05 = ''   
      SET @cOutField06 = ''   -- SKU/UPC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 --ESC
   BEGIN
      --go to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 2. Scn = 1932. 
   PS NO        (field01)
   LOADKEY      (field02)
   ORDERKEY     (field03)
   LABELNO      (field04)
   CARTONNO     (field05)
   SKU/UPC      (field06, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      --screen mapping
      SET @cSKU = @cInField06
      SET @cUPC = @cInField06   -- for validation of prepackbom

      IF ISNULL(@cSKU, '') = ''
      BEGIN
         SET @nErrNo = 66267
         SET @cErrMsg = rdt.rdtgetmessage( 66267, @cLangCode,'DSP') --SKU/UPC needed
         GOTO Step_2_Fail  
      END

      EXEC RDT.rdt_GETSKUCNT 
         @cStorerKey  = @cStorerKey, 
         @cSKU        = @cSKU,    
         @nSKUCnt     = @nSKUCnt       OUTPUT, 
         @bSuccess    = @b_Success     OUTPUT, 
         @nErr        = @n_Err         OUTPUT, 
         @cErrMsg     = @c_ErrMsg      OUTPUT
        
      -- Validate SKU/UPC  
      IF @nSKUCnt = 0 
      BEGIN  
         SET @nErrNo = 66268
         SET @cErrMsg = rdt.rdtgetmessage( 66268, @cLangCode, 'DSP') --'Invalid SKU'  
         GOTO Step_2_Fail  
      END  
  
      -- Validate barcode return multiple SKU  
      IF @nSKUCnt > 1  
      BEGIN  
      SET @nErrNo = 66269  
         SET @cErrMsg = rdt.rdtgetmessage( 66269, @cLangCode, 'DSP') --'SameBarCodeSKU'  
         GOTO Step_2_Fail  
      END  

      -- Return actual SKU If barcode is scanned (SKU.AltSKU, SKU.RetailSKU, SKU.ManufacturerSKU OR UPC.UPC)
      EXEC [RDT].[rdt_GETSKU]  
         @cStorerKey  = @cStorerKey, 
         @cSKU        = @cSKU          OUTPUT,  
         @bSuccess    = @b_Success     OUTPUT, 
         @nErr        = @n_Err         OUTPUT, 
         @cErrMsg     = @c_ErrMsg      OUTPUT

      -- (Vicky03) - Start
      IF ISNULL(RTRIM(@cTemplateID ), '') = '' AND ISNULL(RTRIM(@cGenTemplateID), '') <> ''
      BEGIN

         SET @cGS1TemplatePath1 = ''
         SET @cGS1TemplatePath2 = ''
         SET @cGS1TemplatePath3 = ''
         SET @cGS1TemplatePath4 = ''
         SET @cGS1TemplatePath5 = ''
         SET @cGS1TemplatePath6 = ''

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
      END
      -- (Vicky03) - End


      IF @cPrepackByBOM = '1'
      BEGIN
         -- Check whether UPC.SKU exists in Billofmaterial
			IF NOT EXISTS (SELECT 1 FROM dbo.SKU SKU WITH (NOLOCK) 
            JOIN dbo.UPC UPC WITH (NOLOCK) ON (SKU.StorerKey = UPC.StorerKey AND SKU.SKU = UPC.SKU)
            WHERE SKU.StorerKey = @cStorerKey
               AND UPC.UPC = @cUPC)
         BEGIN
            SET @nErrNo = 66270
            SET @cErrMsg = rdt.rdtgetmessage( 66270, @cLangCode, 'DSP') --'BOM Not Setup'  
            GOTO Step_2_Fail  
         END

         SELECT 
            @cUPC_SKU = UPC.SKU, 
            @cDescr = SKU.Descr 
         FROM dbo.SKU SKU WITH (NOLOCK) 
         JOIN dbo.UPC UPC WITH (NOLOCK) ON (SKU.StorerKey = UPC.StorerKey AND SKU.SKU = UPC.SKU)
         WHERE SKU.StorerKey = @cStorerKey
            AND UPC.UPC = @cUPC
            AND UPC.UOM = 'CS'

         IF ISNULL(@cUPC_SKU, '') = ''
         BEGIN
            SET @nErrNo = 66271
            SET @cErrMsg = rdt.rdtgetmessage( 66271, @cLangCode, 'DSP') --'UPC not CS'  
            GOTO Step_2_Fail  
         END

         -- (Vicky02) - Start
			SELECT Top 1 @cUPC_Packkey = Packkey
         FROM dbo.UPC WITH (NOLOCK)
         WHERE Storerkey = @cStorerKey
         AND   UPC = @cUPC
           
         SELECT @nCaseCnt = CaseCnt
         FROM dbo.PACK WITH (NOLOCK)
         WHERE Packkey = @cUPC_Packkey
         -- (Vicky02) - End

         -- Check whether UPC.SKU exists in PD.ALTSKU of the related orders for the scanned UPC
         IF @cPickSlipType = 'CONSO'
         BEGIN
            IF NOT EXISTS (SELECT 1
               FROM dbo.PickHeader PH WITH (NOLOCK) 
               JOIN dbo.Orders O WITH (NOLOCK) ON (PH.OrderKey = O.OrderKey)
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
               JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (OD.SKU = BOM.ComponentSKU)
               JOIN dbo.UPC UPC WITH (NOLOCK) ON (BOM.SKU = UPC.SKU)
               WHERE O.LoadKey = @cLoadKey
                  AND O.StorerKey = @cStorerKey
                  AND UPC.UPC = @cUPC)
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = '66272 SKU not'
               SET @cErrMsg2 = 'found in Order'
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                  @cErrMsg1, @cErrMsg2
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
                  SET @cErrMsg2 = ''
               END
               GOTO Step_2_Fail
            END
         END
         ELSE  -- IF @cPickSlipType = 'DISCRETE'
         BEGIN
            IF NOT EXISTS (SELECT 1 
               FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON (PH.OrderKey = O.OrderKey)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (PD.SKU = BOM.ComponentSKU)
               JOIN dbo.UPC UPC WITH (NOLOCK) ON (BOM.SKU = UPC.SKU)
               WHERE PH.PickHeaderKey = @cPickSlipNo
                  AND O.StorerKey = @cStorerKey
                  AND UPC.UPC = @cUPC)
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = '66273 SKU not'
               SET @cErrMsg2 = 'found in Order'
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                  @cErrMsg1, @cErrMsg2
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
                  SET @cErrMsg2 = ''
               END
               GOTO Step_2_Fail
            END
         END

         -- Check if any outstanding qty to be packed for current scanned SKU/UPC
         IF @cPickSlipType = 'SINGLE'
         BEGIN
            SELECT @nPickDSKUQty = ISNULL(SUM(PD.QTY), 0) 
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.PickHeader PH WITH (NOLOCK) ON (PD.OrderKey = PH.OrderKey)
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            WHERE PD.StorerKey = @cStorerKey
               AND PD.SKU IN (SELECT ComponentSku FROM dbo.BillOfMaterial WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND SKU = @cUPC_SKU)
               AND PH.PickHeaderKey = @cPickslipNo
               AND L.Facility = @cFacility

            SELECT @nPackDSKUQty = ISNULL(SUM(QTY), 0) FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE PickslipNo = @cPickslipNo 
               AND StorerKey = @cStorerKey 
               AND SKU IN (SELECT ComponentSku FROM dbo.BillOfMaterial WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey 
                     AND SKU = @cUPC_SKU)
         END
         ELSE
         BEGIN
            SELECT @nPickDSKUQty = ISNULL(SUM(PD.QTY), 0) 
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
            JOIN dbo.PickHeader PH WITH (NOLOCK) ON (O.LoadKey = PH.ExternOrderKey)
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            WHERE PD.StorerKey = @cStorerKey
               AND PD.SKU IN (SELECT ComponentSku FROM dbo.BillOfMaterial WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND SKU = @cUPC_SKU)
               AND PH.PickHeaderKey = @cPickslipNo
               AND L.Facility = @cFacility

            SELECT @nPackDSKUQty = ISNULL(SUM(QTY), 0) FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE Refno = @cPickslipNo 
               AND StorerKey = @cStorerKey 
               AND SKU IN (SELECT ComponentSku FROM dbo.BillOfMaterial WITH (NOLOCK) 
     WHERE StorerKey = @cStorerKey 
                     AND SKU = @cUPC_SKU)
         END
      END   -- IF @cPrepackByBOM = '1'
      ELSE
      -- Check if any outstanding qty to be packed for current scanned SKU/UPC
      IF @cPickSlipType = 'SINGLE'
      BEGIN
         SELECT @nPickDSKUQty = ISNULL(SUM(PD.QTY), 0) 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.PickHeader PH WITH (NOLOCK) ON (PD.OrderKey = PH.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PH.PickHeaderKey = @cPickslipNo
            AND L.Facility = @cFacility

         SELECT @nPackDSKUQty = ISNULL(SUM(QTY), 0) FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickslipNo = @cPickslipNo 
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU

			SELECT @nCaseCnt = P.CaseCnt
         FROM dbo.PACK P WITH (NOLOCK)
         JOIN dbo.SKU S WITH (NOLOCK) ON P.PackKey = S.PackKey
         WHERE S.SKU = @cSKU
      END
      ELSE
      BEGIN
         SELECT @nPickDSKUQty = ISNULL(SUM(PD.QTY), 0) 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         JOIN dbo.PickHeader PH WITH (NOLOCK) ON (O.LoadKey = PH.ExternOrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PH.PickHeaderKey = @cPickslipNo
            AND L.Facility = @cFacility

         SELECT @nPackDSKUQty = ISNULL(SUM(QTY), 0) FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE Refno = @cPickslipNo 
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU

			SELECT @nCaseCnt = P.CaseCnt
         FROM dbo.PACK P WITH (NOLOCK)
         JOIN dbo.SKU S WITH (NOLOCK) ON P.PackKey = S.PackKey
         WHERE S.SKU = @cSKU
      END

      IF @nPickDSKUQty <= @nPackDSKUQty
      BEGIN
         SET @nErrNo = 66274
         SET @cErrMsg = rdt.rdtgetmessage( 66274, @cLangCode, 'DSP') --'SKUFullyPacked'  
         GOTO Step_2_Fail
      END

      -- (Vicky01)
      SET @cSkipQTYScn = rdt.RDTGetConfig( @nFunc, 'SkipQTYScn', @cStorerKey)

      -- Vicky01 - Start
      -- If @cSkipQTYScn = 1 and If UPC.UOM = CS, skip QTY screen 
		IF @cSkipQTYScn = '1'
      BEGIN
			IF EXISTS (SELECT 1 FROM dbo.UPC UPC WITH (NOLOCK) 
						  WHERE UPC.StorerKey = @cStorerKey
                       AND   UPC.UPC = @cUPC
                       AND   UPC.UOM = 'CS') 
         AND @cPrePackByBOM = '1'
			BEGIN
				SET @cQty = '1'

				SELECT @nComponentQty = ISNULL(SUM(QTY), 0) FROM dbo.BILLOFMATERIAL WITH (NOLOCK) 
				WHERE StorerKey = @cStorerKey
				AND   Sku = @cUPC_SKU

				SET @nComponentQty = @nComponentQty * CAST(@cQty AS INT) * @nCaseCnt -- (Vicky02)
				
				-- Check if qty entered > qty allocated
				IF @nComponentQty > @nPickDSKUQty
				BEGIN
					SET @cQty = ''
					SET @nErrNo = 66277
					SET @cErrMsg = rdt.rdtgetmessage( 66277, @cLangCode, 'DSP') --'Over Packed'
					SET @cOutField04 = CASE WHEN ISNULL(@nCasePackDefaultQty, 0) = 0 THEN '' ELSE @nCasePackDefaultQty END
					EXEC rdt.rdtSetFocusField @nMobile, 1
					GOTO Quit
				END

				-- Check if qty entered > qty remain
				IF @nComponentQty > (@nPickDSKUQty - @nPackDSKUQty)
				BEGIN
					SET @cQty = ''
					SET @nErrNo = 66278
					SET @cErrMsg = rdt.rdtgetmessage( 66278, @cLangCode, 'DSP') --'Over Packed'
					SET @cOutField04 = CASE WHEN ISNULL(@nCasePackDefaultQty, 0) = 0 THEN '' ELSE @nCasePackDefaultQty END
					EXEC rdt.rdtSetFocusField @nMobile, 1
					GOTO Quit
				END

				SET @nQty = CAST(@cQty AS INT)

   			SET @cSKUCode = @cUPC_SKU
 
            SET @cGS1BatchNo = ''
            EXEC isp_GetGS1BatchNo 5,  @cGS1BatchNo OUTPUT

				WHILE @nQty > 0
				BEGIN
					IF @cPickSlipType = 'CONSO'
					BEGIN
						DECLARE CUR_GETORDER CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
				      SELECT PH.OrderKey, PH.PickHeaderKey FROM dbo.PickHeader PH WITH (NOLOCK)
				      JOIN dbo.Orders O WITH (index(IX_ORDERS_LOADKEY), NOLOCK) ON (PH.OrderKey = O.OrderKey)
				      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
				      JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (OD.StorerKey = BOM.StorerKey AND OD.SKU = BOM.ComponentSKU)
				      WHERE O.StorerKey = @cStorerKey
				         AND O.LoadKey = @cLoadKey
				         AND BOM.SKU = @cSKUCode
						OPEN CUR_GETORDER
						FETCH NEXT FROM CUR_GETORDER INTO @cOrderKey, @cDiscrete_PickSlipNo
						WHILE @@FETCH_STATUS <> -1
						BEGIN
							--Perfomance tuning (james03)
							SELECT @nQtyPicked = ISNULL(SUM(PD.QTY), 0) 
							FROM dbo.PICKDETAIL PD WITH (NOLOCK) 
							JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (PD.StorerKey = BOM.StorerKey AND PD.SKU = BOM.ComponentSku)
							WHERE PD.StorerKey = @cStorerKey
								AND PD.OrderKey = @cOrderkey 
								AND BOM.SKU = @cSKUCode
							
							SELECT @nQtyPacked = ISNULL(SUM(PD.QTY), 0) 
							FROM dbo.PACKDETAIL PD WITH (NOLOCK) 
							JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (PD.StorerKey = BOM.StorerKey AND PD.SKU = BOM.ComponentSku)
							WHERE PD.StorerKey = @cStorerKey
								AND PD.Pickslipno = @cDiscrete_PickSlipNo 
								AND BOM.SKU = @cSKUCode

							-- (james05)
							SET @nCheck = 0
							DECLARE CUR_CHECKPACKQTY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
							SELECT BOM.ComponentSKU, BOM.Qty FROM dbo.BillOfMaterial BOM WITH (NOLOCK) 
							JOIN dbo.UPC UPC WITH (NOLOCK) ON (BOM.StorerKey = UPC.StorerKey AND BOM.SKU = UPC.SKU)
							WHERE BOM.StorerKey = @cStorerKey
								AND BOM.SKU = @cSKUCode
								AND UPC.UOM = 'CS'
							OPEN CUR_CHECKPACKQTY
							FETCH NEXT FROM CUR_CHECKPACKQTY INTO @cBOM_SKU, @nBOM_Qty
							WHILE @@FETCH_STATUS <> -1
							BEGIN
								-- 1 = 1 CASE, we pack 1 case at one time
								-- if qty to be packed + qty already packed <= qtyallocated + qtypicked 
								-- then can proceed else skup this discrete pickslip
								IF ((1 * @nCaseCnt * @nBOM_Qty) + @nQtyPacked) <= @nQtyPicked
								   SET @nCheck = 1
								
								FETCH NEXT FROM CUR_CHECKPACKQTY INTO @cBOM_SKU, @nBOM_Qty
                     END
                     CLOSE CUR_CHECKPACKQTY
                     DEALLOCATE CUR_CHECKPACKQTY

                     IF (@nQtyPicked > @nQtyPacked) AND @nCheck = 1
                        BREAK

							FETCH NEXT FROM CUR_GETORDER INTO @cOrderKey, @cDiscrete_PickSlipNo
						END
						CLOSE CUR_GETORDER
						DEALLOCATE CUR_GETORDER
					END
					ELSE
               BEGIN
						SELECT TOP 1 @cOrderKey = OrderKey, @cDiscrete_PickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK)
						WHERE PickHeaderKey = @cPickSlipNo

						--Perfomance tuning (james03)
						SELECT @nQtyPicked = ISNULL(SUM(PD.QTY), 0) 
						FROM dbo.PICKDETAIL PD WITH (NOLOCK) 
						JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (PD.StorerKey = BOM.StorerKey AND PD.SKU = BOM.ComponentSku)
						WHERE PD.StorerKey = @cStorerKey
							AND PD.OrderKey = @cOrderkey 
							AND BOM.SKU = @cSKUCode
					
						SELECT @nQtyPacked = ISNULL(SUM(PD.QTY), 0) 
						FROM dbo.PACKDETAIL PD WITH (NOLOCK) 
						JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (PD.StorerKey = BOM.StorerKey AND PD.SKU = BOM.ComponentSku)
						WHERE PD.StorerKey = @cStorerKey
							AND PD.Pickslipno = @cDiscrete_PickSlipNo 
							AND BOM.SKU = @cSKUCode

                  -- (james05)
                  SET @nCheck = 0
                  DECLARE CUR_CHECKPACKQTY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
                  SELECT BOM.ComponentSKU, BOM.Qty FROM dbo.BillOfMaterial BOM WITH (NOLOCK) 
                  JOIN dbo.UPC UPC WITH (NOLOCK) ON (BOM.StorerKey = UPC.StorerKey AND BOM.SKU = UPC.SKU)
                  WHERE BOM.StorerKey = @cStorerKey
                     AND BOM.SKU = @cSKUCode
                     AND UPC.UOM = 'CS'
                  OPEN CUR_CHECKPACKQTY
                  FETCH NEXT FROM CUR_CHECKPACKQTY INTO @cBOM_SKU, @nBOM_Qty
                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
                     -- 1 = 1 CASE, we pack 1 case at one time
                     -- if qty to be packed + qty already packed <= qtyallocated + qtypicked 
                     -- then can proceed else skup this discrete pickslip
                     IF ((1 * @nCaseCnt * @nBOM_Qty) + @nQtyPacked) <= @nQtyPicked
                        SET @nCheck = 1

                     FETCH NEXT FROM CUR_CHECKPACKQTY INTO @cBOM_SKU, @nBOM_Qty
                  END
						CLOSE CUR_CHECKPACKQTY
						DEALLOCATE CUR_CHECKPACKQTY
					END


					SET @cGS1TemplatePath_Final = RTRIM(@cGS1TemplatePath1) + RTRIM(@cGS1TemplatePath2) + RTRIM(@cGS1TemplatePath3) +
                                         RTRIM(@cGS1TemplatePath4) + RTRIM(@cGS1TemplatePath5) + RTRIM(@cGS1TemplatePath6)
                                               
					IF (@nQtyPicked > @nQtyPacked) AND @nCheck = 1 
					BEGIN
                  SET @cErrMsg = @cGS1BatchNo
						EXEC rdt.rdt_Scan_And_Pack_InsertPackDetail 
							@nMobile,
							@cFacility,
							@cStorerKey,
							@cMBOLKey,
							@cLoadKey,
							@cOrderKey,
							@cPickSlipType,
							@cPickSlipNo,
							@cDiscrete_PickSlipNo,
							@cBuyerPO,
							@cFilePath1,
							@cFilePath2,
							@cSKUCode,
							1, -- 1 case per time
							@cPrepackByBOM,
							@cUserName,   
							--@cTemplateID,
							@cGS1TemplatePath_Final, -- SOS# 140526 
							@cPrinter,
							@cLangCode,
							@nCaseCnt, -- (Vicky02)
							@nCartonNo     OUTPUT,
							@cLabelNo      OUTPUT,
							@nErrNo        OUTPUT, 
							@cErrMsg       OUTPUT  
	
						IF @nErrNo <> 0
						BEGIN
							SET @cQty = ''
							SET @cOutField04 = CASE WHEN ISNULL(@nCasePackDefaultQty, 0) = 0 THEN '' ELSE @nCasePackDefaultQty END
							EXEC rdt.rdtSetFocusField @nMobile, 1
							GOTO Quit
						END
					END
	
					SET @nQty = @nQty - 1
				END -- WHILE @nQty > 0

	        	-- Check if any outstanding qty to be packed for current pickslip
	        	IF @cPickSlipType = 'SINGLE'
				BEGIN
					SELECT @nPickDSKUQty = ISNULL(SUM(PD.QTY), 0) 
					FROM dbo.PickDetail PD WITH (NOLOCK) 
					JOIN dbo.PickHeader PH WITH (NOLOCK) ON (PD.OrderKey = PH.OrderKey)
					JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
					WHERE PD.StorerKey = @cStorerKey
						AND PH.PickHeaderKey = @cPickslipNo
						AND L.Facility = @cFacility
	
					SELECT @nPackDSKUQty = ISNULL(SUM(QTY), 0) 
					FROM dbo.PackDetail WITH (NOLOCK) 
					WHERE PickslipNo = @cPickslipNo 
						AND StorerKey = @cStorerKey
				END
				ELSE
				BEGIN
	           SELECT @nPickDSKUQty = ISNULL(SUM(PD.QTY), 0) 
	           FROM dbo.PickDetail PD WITH (NOLOCK) 
	           JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
	           JOIN dbo.PickHeader PH WITH (NOLOCK) ON (O.LoadKey = PH.ExternOrderKey)
	           JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
	           WHERE PD.StorerKey = @cStorerKey
	              AND PH.PickHeaderKey = @cPickslipNo
	           AND L.Facility = @cFacility
	
	           SELECT @nPackDSKUQty = ISNULL(SUM(QTY), 0) 
	           FROM dbo.PackDetail WITH (NOLOCK) 
	           WHERE Refno = @cPickslipNo 
	              AND StorerKey = @cStorerKey
				END

				IF (@nPickDSKUQty - @nPackDSKUQty) > 0
				BEGIN
					-- Prepare prev screen var
					SET @cOutField01 = @cPickSlipNo 
					SET @cOutField02 = @cLoadKey
					SET @cOutField03 = CASE WHEN @cPickSlipType = 'CONSO' THEN 'MULTI' ELSE @cOrderKey END
					SET @cOutField04 = @cLabelNo
					SET @cOutField05 = @nCartonNo
					SET @cOutField06 = ''   -- SKU/UPC
					
					-- Go to prev screen
					SET @nScn = @nScn 
					SET @nStep = @nStep
	
					GOTO Quit
				END
				ELSE
				IF (@nPickDSKUQty - @nPackDSKUQty) = 0
				BEGIN
					-- Go to screen 8
					SET @nScn = @nScn + 6
					SET @nStep = @nStep + 6
					
					GOTO Quit
				END
			END -- If CS
       	ELSE
       	BEGIN
				SET @cQty = '1'

				-- Check if qty entered > qty allocated
				IF CAST( @cQty AS INT) > @nPickDSKUQty
				BEGIN
					SET @cQty = ''
					SET @nErrNo = 66279
					SET @cErrMsg = rdt.rdtgetmessage( 66279, @cLangCode, 'DSP') --'Over Packed'
					SET @cOutField04 = CASE WHEN ISNULL(@nCasePackDefaultQty, 0) = 0 THEN '' ELSE @nCasePackDefaultQty END
					EXEC rdt.rdtSetFocusField @nMobile, 1
					GOTO Quit
				END

				-- Check if qty entered > qty remain
				IF CAST( @cQty AS INT) > (@nPickDSKUQty - @nPackDSKUQty)
				BEGIN
					SET @cQty = ''
					SET @nErrNo = 66280
					SET @cErrMsg = rdt.rdtgetmessage( 66280, @cLangCode, 'DSP') --'Over Packed'
					SET @cOutField04 = CASE WHEN ISNULL(@nCasePackDefaultQty, 0) = 0 THEN '' ELSE @nCasePackDefaultQty END
					EXEC rdt.rdtSetFocusField @nMobile, 1
					GOTO Quit
				END

				SET @nQty = CAST(@cQty AS INT)

				SET @cSKUCode = @cSKU

            SET @cGS1BatchNo = ''
            EXEC isp_GetGS1BatchNo 5,  @cGS1BatchNo OUTPUT
            
				WHILE @nQty > 0
				BEGIN
					IF @cPickSlipType = 'CONSO'
					BEGIN
						DECLARE CUR_GETORDER CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
						SELECT PH.OrderKey, PH.PickHeaderKey FROM dbo.PickHeader PH WITH (NOLOCK)
						JOIN dbo.Orders O WITH (index(IX_ORDERS_LOADKEY), NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
						JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
						WHERE O.StorerKey = @cStorerKey
							AND O.LoadKey = @cLoadKey
							AND OD.SKU = @cSKUCode
						OPEN CUR_GETORDER
						FETCH NEXT FROM CUR_GETORDER INTO @cOrderKey, @cDiscrete_PickSlipNo
						WHILE @@FETCH_STATUS <> -1
						BEGIN
							SELECT @nQtyPicked = ISNULL(SUM(QTY), 0) 
							FROM dbo.PICKDETAIL WITH (NOLOCK) 
							WHERE StorerKey = @cStorerKey
								AND OrderKey = @cOrderkey 
								AND SKU = @cSKUCode
							
							SELECT @nQtyPacked = ISNULL(SUM(QTY), 0) 
							FROM dbo.PACKDETAIL WITH (NOLOCK) 
							WHERE StorerKey = @cStorerKey
								AND Pickslipno = @cDiscrete_PickSlipNo 
								AND SKU = @cSKUCode
									
							-- 1 = 1 CASE, we pack 1 case at one time
							-- if qty to be packed + qty already packed <= qtyallocated + qtypicked 
							-- then can proceed else skup this discrete pickslip
							SET @nCheck = 0
							IF ((1 * @nCaseCnt) + @nQtyPacked) <= @nQtyPicked
							   SET @nCheck = 1

                     IF (@nQtyPicked > @nQtyPacked) AND @nCheck = 1
                        BREAK

							FETCH NEXT FROM CUR_GETORDER INTO @cOrderKey, @cDiscrete_PickSlipNo
						END
						CLOSE CUR_GETORDER
						DEALLOCATE CUR_GETORDER
					END
					ELSE
               BEGIN
						SELECT TOP 1 @cOrderKey = OrderKey, @cDiscrete_PickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK)
						WHERE PickHeaderKey = @cPickSlipNo

						SELECT @nQtyPicked = ISNULL(SUM(QTY), 0) 
						FROM dbo.PICKDETAIL WITH (NOLOCK) 
						WHERE StorerKey = @cStorerKey
							AND OrderKey = @cOrderkey 
							AND SKU = @cSKUCode
						
						SELECT @nQtyPacked = ISNULL(SUM(QTY), 0) 
						FROM dbo.PACKDETAIL WITH (NOLOCK) 
						WHERE StorerKey = @cStorerKey
							AND Pickslipno = @cDiscrete_PickSlipNo 
							AND SKU = @cSKUCode
								
						-- 1 = 1 CASE, we pack 1 case at one time
						-- if qty to be packed + qty already packed <= qtyallocated + qtypicked 
						-- then can proceed else skup this discrete pickslip
						SET @nCheck = 0
						IF ((1 * @nCaseCnt) + @nQtyPacked) <= @nQtyPicked
						   SET @nCheck = 1
					END   -- IF @cPrepackByBOM = '1'

					SET @cGS1TemplatePath_Final = RTRIM(@cGS1TemplatePath1) + RTRIM(@cGS1TemplatePath2) + RTRIM(@cGS1TemplatePath3) +
                                         RTRIM(@cGS1TemplatePath4) + RTRIM(@cGS1TemplatePath5) + RTRIM(@cGS1TemplatePath6)

                                              
					IF (@nQtyPicked > @nQtyPacked) AND @nCheck = 1 
					BEGIN
                  SET @cErrMsg = @cGS1BatchNo 
						EXEC rdt.rdt_Scan_And_Pack_InsertPackDetail 
							@nMobile,
							@cFacility,
							@cStorerKey,
							@cMBOLKey,
							@cLoadKey,
							@cOrderKey,
							@cPickSlipType,
							@cPickSlipNo,
							@cDiscrete_PickSlipNo,
							@cBuyerPO,
							@cFilePath1,
							@cFilePath2,
							@cSKUCode,
							1, -- 1 case per time
							@cPrepackByBOM,
							@cUserName,   
							--@cTemplateID,
							@cGS1TemplatePath_Final, -- SOS# 140526 
							@cPrinter,
							@cLangCode,
							@nCaseCnt, -- (Vicky02)
							@nCartonNo     OUTPUT,
							@cLabelNo      OUTPUT,
							@nErrNo        OUTPUT, 
							@cErrMsg       OUTPUT  
	
						IF @nErrNo <> 0
						BEGIN
							SET @cQty = ''
							SET @cOutField04 = CASE WHEN ISNULL(@nCasePackDefaultQty, 0) = 0 THEN '' ELSE @nCasePackDefaultQty END
							EXEC rdt.rdtSetFocusField @nMobile, 1
							GOTO Quit
						END
					END
	
					SET @nQty = @nQty - 1
				END -- WHILE @nQty > 0 

	        	-- Check if any outstanding qty to be packed for current pickslip
	        	IF @cPickSlipType = 'SINGLE'
				BEGIN
					SELECT @nPickDSKUQty = ISNULL(SUM(PD.QTY), 0) 
					FROM dbo.PickDetail PD WITH (NOLOCK) 
					JOIN dbo.PickHeader PH WITH (NOLOCK) ON (PD.OrderKey = PH.OrderKey)
					JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
					WHERE PD.StorerKey = @cStorerKey
						AND PH.PickHeaderKey = @cPickslipNo
						AND L.Facility = @cFacility
	
					SELECT @nPackDSKUQty = ISNULL(SUM(QTY), 0) 
					FROM dbo.PackDetail WITH (NOLOCK) 
					WHERE PickslipNo = @cPickslipNo 
						AND StorerKey = @cStorerKey
				END
				ELSE
				BEGIN
	           SELECT @nPickDSKUQty = ISNULL(SUM(PD.QTY), 0) 
	           FROM dbo.PickDetail PD WITH (NOLOCK) 
	           JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
	           JOIN dbo.PickHeader PH WITH (NOLOCK) ON (O.LoadKey = PH.ExternOrderKey)
	           JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
	           WHERE PD.StorerKey = @cStorerKey
	              AND PH.PickHeaderKey = @cPickslipNo
	           AND L.Facility = @cFacility
	
	           SELECT @nPackDSKUQty = ISNULL(SUM(QTY), 0) 
	           FROM dbo.PackDetail WITH (NOLOCK) 
	           WHERE Refno = @cPickslipNo 
	              AND StorerKey = @cStorerKey
				END

				IF (@nPickDSKUQty - @nPackDSKUQty) > 0
				BEGIN
					-- Prepare prev screen var
					SET @cOutField01 = @cPickSlipNo 
					SET @cOutField02 = @cLoadKey
					SET @cOutField03 = CASE WHEN @cPickSlipType = 'CONSO' THEN 'MULTI' ELSE @cOrderKey END
					SET @cOutField04 = @cLabelNo
					SET @cOutField05 = @nCartonNo
					SET @cOutField06 = ''   -- SKU/UPC
					
					-- Go to prev screen
					SET @nScn = @nScn 
					SET @nStep = @nStep
	
					GOTO Quit
				END
				ELSE
				IF (@nPickDSKUQty - @nPackDSKUQty) = 0
				BEGIN
					-- Go to screen 8
					SET @nScn = @nScn + 6
					SET @nStep = @nStep + 6
					
					GOTO Quit
				END
			END
      END -- @cSkipQTYScn = 1
      ELSE
      BEGIN
      	-- Vicky01 - END
			-- Prepare next screen var
			SET @cOutField01 = @cPickSlipNo  -- PSNO
			SET @cOutField02 = @cLabelNo    -- Label No
			SET @cOutField03 = CASE WHEN ISNULL(@nCartonNo, 0) = 0 THEN '' ELSE @nCartonNo END -- Carton No
			SET @cOutField04 = CASE WHEN ISNULL(@nCasePackDefaultQty, 0) = 0 THEN '' ELSE @nCasePackDefaultQty END   -- Qty
			SET @cOutField05 = CASE WHEN @cPrepackByBOM = '1' THEN @cUPC_SKU ELSE @cSKU END  -- UPC.SKU/SKU.SKU
			SET @cOutField06 = SUBSTRING(@cDescr, 1, 20)   -- Descr
			SET @cOutField07 = ISNULL(RTRIM(CAST(@nPackDSKUQty AS NVARCHAR(5))), '') + '/' + CAST(@nPickDSKUQty AS NVARCHAR(5))  -- Qty scn/Qty alloc
			SET @cOutField08 = ISNULL(RTRIM(CAST(@nPickDSKUQty - @nPackDSKUQty AS NVARCHAR(5))), '')   -- Qty remain
			SET @cOutField09 = ''   -- Option
			
			-- Go to next screen
			SET @nScn = @nScn + 1
			SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Check if any outstanding qty to be packed for current scanned Pickslip no
      IF @cPickSlipType = 'SINGLE'
      BEGIN
         SELECT @nPickDSKUQty = ISNULL(SUM(PD.QTY), 0) 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.PickHeader PH WITH (NOLOCK) ON (PD.OrderKey = PH.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE PD.StorerKey = @cStorerKey
            AND PH.PickHeaderKey = @cPickslipNo
            AND L.Facility = @cFacility

        SELECT @nPackDSKUQty = ISNULL(SUM(QTY), 0) FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND PickslipNo = @cPickslipNo
      END
      ELSE
      BEGIN
         SELECT @nPickDSKUQty = ISNULL(SUM(PD.QTY), 0) 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         JOIN dbo.PickHeader PH WITH (NOLOCK) ON (O.LoadKey = PH.ExternOrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE PD.StorerKey = @cStorerKey
            AND PH.PickHeaderKey = @cPickslipNo
            AND L.Facility = @cFacility

         SELECT @nPackDSKUQty = ISNULL(SUM(QTY), 0) FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND Refno = @cPickslipNo
      END

      --	If Total Scanned Qty is less than Total Allocated Qty, go to screen 6
      IF @nPackDSKUQty < @nPickDSKUQty
      BEGIN
         -- Prepare prev screen var
         SET @cOutField01 = ''

         -- Go to screen 6
         SET @nScn = @nScn + 4
         SET @nStep = @nStep + 4

         GOTO Quit
      END
         
      -- Prepare prev screen var
      SET @cOutField01 = ''  -- PSNO
      SET @cOutField02 = ''  -- Printer

      SET @cPickSlipNo = ''
      SET @cPrinter = ''

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
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
Step 3. Scn = 1933. 
   PSNO      (field01)
   LABELNO   (field02)
   CARTONNO  (field03)
   SKU       (field04)
   QTY       (field05, input)
   QTY SCN/QTY ALLOC
   QTY REMAIN
   OPTION
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE    @c_starttime    datetime,  
                 @c_endtime      datetime,  
                 @c_Step1        datetime,  
                 @c_Step2        datetime,  
                 @c_Step3        datetime,  
                 @c_Step4        datetime,  
                 @c_Step5        DATETIME,
                 @c_Col1         NVARCHAR(20),
                 @c_Col2         NVARCHAR(20),
                 @c_Col3         NVARCHAR(20),
                 @c_Col4         NVARCHAR(20),
                 @c_Col5         NVARCHAR(20),
                 @c_Step1_Start  datetime,  
                 @c_Step1_End    datetime,  
                 @c_Step2_Start  datetime,  
                 @c_Step2_End    datetime,  
                 @c_Step3_Start  datetime,  
                 @c_Step3_End    datetime,  
                 @c_Step4_Start  datetime,  
                 @c_Step4_End    datetime,
                 @n_Step1Ctn     INT,
                 @n_Step2Ctn     INT,
                 @n_Step3Ctn     INT,
                 @n_Step4Ctn     INT,
                 @n_Step5Ctn     INT
  
      SET @n_Step1Ctn = 0
      SET @n_Step2Ctn = 0
      SET @n_Step3Ctn = 0
      SET @n_Step4Ctn = 0
      SET @n_Step5Ctn = 0

      IF @bDebug = 3  
      BEGIN  
         SET @c_starttime = getdate()  
      END

      --screen mapping
      SET @cQty = @cInField04
      SET @cOption = @cInField09
			
      SET @c_Col1 = @cQty
      SET @c_Col2 = @cPickSlipNo
      SET @c_Col3 = @cLabelNo
      SET @c_Col4 = CASE WHEN ISNULL(@nCartonNo, 0) = 0 THEN '' ELSE @nCartonNo END
      SET @c_Col5 = SUSER_SNAME()                 


      IF ISNULL(@cOption, '') <> ''
         GOTO Check_SKU_In_Ord

      IF @cQty  = ''   SET @cQty  = '0' --'Blank taken as zero'

      IF @cQty = '0'
      BEGIN
         SET @cQty = ''
         SET @nErrNo = 66275
         SET @cErrMsg = rdt.rdtgetmessage( 66275, @cLangCode, 'DSP') --'QTY needed'
         SET @cOutField04 = CASE WHEN ISNULL(@nCasePackDefaultQty, 0) = 0 THEN '' ELSE @nCasePackDefaultQty END
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END
     
      IF RDT.rdtIsValidQTY( @cQty, 1) = 0
      BEGIN
         SET @cQty = ''
         SET @nErrNo = 66276
         SET @cErrMsg = rdt.rdtgetmessage( 66276, @cLangCode, 'DSP') --'Invalid QTY'
         SET @cOutField04 = CASE WHEN ISNULL(@nCasePackDefaultQty, 0) = 0 THEN '' ELSE @nCasePackDefaultQty END
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      IF @cPrePackByBOM = '1'
      BEGIN
         SELECT @nComponentQty = ISNULL(SUM(QTY), 0) FROM dbo.BILLOFMATERIAL WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND Sku = @cUPC_SKU

         SET @nComponentQty = @nComponentQty * CAST(@cQty AS INT) * @nCaseCnt -- (Vicky02)

         -- Check if qty entered > qty allocated
         IF @nComponentQty > @nPickDSKUQty
         BEGIN
            SET @cQty = ''
            SET @nErrNo = 66277
            SET @cErrMsg = rdt.rdtgetmessage( 66277, @cLangCode, 'DSP') --'Over Packed'
            SET @cOutField04 = CASE WHEN ISNULL(@nCasePackDefaultQty, 0) = 0 THEN '' ELSE @nCasePackDefaultQty END
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END

         -- Check if qty entered > qty remain
         IF @nComponentQty > (@nPickDSKUQty - @nPackDSKUQty)
         BEGIN
            SET @cQty = ''
            SET @nErrNo = 66278
            SET @cErrMsg = rdt.rdtgetmessage( 66278, @cLangCode, 'DSP') --'Over Packed'
            SET @cOutField04 = CASE WHEN ISNULL(@nCasePackDefaultQty, 0) = 0 THEN '' ELSE @nCasePackDefaultQty END
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         -- Check if qty entered > qty allocated
         IF (CAST( @cQty AS INT) * @nCaseCnt) > @nPickDSKUQty
         BEGIN
            SET @cQty = ''
            SET @nErrNo = 66279
            SET @cErrMsg = rdt.rdtgetmessage( 66279, @cLangCode, 'DSP') --'Over Packed'
            SET @cOutField04 = CASE WHEN ISNULL(@nCasePackDefaultQty, 0) = 0 THEN '' ELSE @nCasePackDefaultQty END
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END

         -- Check if qty entered > qty remain
         IF (CAST( @cQty AS INT) * @nCaseCnt) > (@nPickDSKUQty - @nPackDSKUQty)
         BEGIN
            SET @cQty = ''
            SET @nErrNo = 66280
            SET @cErrMsg = rdt.rdtgetmessage( 66280, @cLangCode, 'DSP') --'Over Packed'
            SET @cOutField04 = CASE WHEN ISNULL(@nCasePackDefaultQty, 0) = 0 THEN '' ELSE @nCasePackDefaultQty END
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END
      END

      SET @nQty = CAST(@cQty AS INT)

      IF @cPrePackByBOM = '1'
         SET @cSKUCode = @cUPC_SKU
      ELSE
         SET @cSKUCode = @cSKU

 
      IF @bDebug = 3  
      BEGIN  
         SET @c_step1 = GETDATE()   
      END 

      SET @cGS1BatchNo = ''
      EXEC isp_GetGS1BatchNo 5,  @cGS1BatchNo OUTPUT
      
      WHILE @nQty > 0
      BEGIN
         SET @n_Step1Ctn = @n_Step1Ctn + 1

         IF @c_Step2_Start IS NULL 
            SET @c_Step2_Start = GETDATE() 

         SET @n_Step2Ctn = @n_Step2Ctn + 1

         IF @cPickSlipType = 'CONSO'
         BEGIN
            --Perfomance tuning (james03)
            IF @cPrepackByBOM = '1'
            BEGIN
               DECLARE CUR_GETORDER CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
               SELECT PH.OrderKey, PH.PickHeaderKey FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.Orders O WITH (index(IX_ORDERS_LOADKEY), NOLOCK) ON (PH.OrderKey = O.OrderKey)
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
               JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (OD.StorerKey = BOM.StorerKey AND OD.SKU = BOM.ComponentSKU)
               WHERE O.StorerKey = @cStorerKey
                 AND O.LoadKey = @cLoadKey
                 AND BOM.SKU = @cSKUCode
            END 
            ELSE
            BEGIN
               DECLARE CUR_GETORDER CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
               SELECT PH.OrderKey, PH.PickHeaderKey FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.Orders O WITH (index(IX_ORDERS_LOADKEY), NOLOCK) ON (PH.ExternOrderKey = O.LoadKey)
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
               WHERE O.StorerKey = @cStorerKey
                 AND O.LoadKey = @cLoadKey
                 AND OD.SKU = @cSKUCode
            END

            OPEN CUR_GETORDER
            FETCH NEXT FROM CUR_GETORDER INTO @cOrderKey, @cDiscrete_PickSlipNo
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF @cPrepackByBOM = '1'
               BEGIN
                  --Perfomance tuning (james03)
                  SELECT @nQtyPicked = ISNULL(SUM(PD.QTY), 0) 
                  FROM dbo.PICKDETAIL PD WITH (NOLOCK) 
                  JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (PD.StorerKey = BOM.StorerKey AND PD.SKU = BOM.ComponentSku)
                  WHERE PD.StorerKey = @cStorerKey
                     AND PD.OrderKey = @cOrderkey 
                     AND BOM.SKU = @cSKUCode

                  SELECT @nQtyPacked = ISNULL(SUM(PD.QTY), 0) 
                  FROM dbo.PACKDETAIL PD WITH (NOLOCK) 
                  JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (PD.StorerKey = BOM.StorerKey AND PD.SKU = BOM.ComponentSku)
                  WHERE PD.StorerKey = @cStorerKey
                     AND PD.Pickslipno = @cDiscrete_PickSlipNo 
                     AND BOM.SKU = @cSKUCode

	               -- (james05)
	               SET @nCheck = 0
	               DECLARE CUR_CHECKPACKQTY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
	               SELECT BOM.ComponentSKU, BOM.Qty FROM dbo.BillOfMaterial BOM WITH (NOLOCK) 
	               JOIN dbo.UPC UPC WITH (NOLOCK) ON (BOM.StorerKey = UPC.StorerKey AND BOM.SKU = UPC.SKU)
	               WHERE BOM.StorerKey = @cStorerKey
	                  AND BOM.SKU = @cSKUCode
	                  AND UPC.UOM = 'CS'
	               OPEN CUR_CHECKPACKQTY
	               FETCH NEXT FROM CUR_CHECKPACKQTY INTO @cBOM_SKU, @nBOM_Qty
	               WHILE @@FETCH_STATUS <> -1
	               BEGIN
	                  -- 1 = 1 CASE, we pack 1 case at one time
	                  -- if qty to be packed + qty already packed <= qtyallocated + qtypicked 
	                  -- then can proceed else skup this discrete pickslip
	                  IF ((1 * @nCaseCnt * @nBOM_Qty) + @nQtyPacked) <= @nQtyPicked
	                     SET @nCheck = 1
	
	                  FETCH NEXT FROM CUR_CHECKPACKQTY INTO @cBOM_SKU, @nBOM_Qty
	               END
	               CLOSE CUR_CHECKPACKQTY
	               DEALLOCATE CUR_CHECKPACKQTY
               END
               ELSE
               BEGIN
                  SELECT @nQtyPicked = ISNULL(SUM(QTY), 0) 
                  FROM dbo.PICKDETAIL WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                     AND OrderKey = @cOrderkey 
                     AND SKU = @cSKUCode

                  SELECT @nQtyPacked = ISNULL(SUM(QTY), 0) 
                  FROM dbo.PACKDETAIL WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                     AND Pickslipno = @cDiscrete_PickSlipNo 
                     AND SKU = @cSKUCode

						-- 1 = 1 CASE, we pack 1 case at one time
						-- if qty to be packed + qty already packed <= qtyallocated + qtypicked 
						-- then can proceed else skup this discrete pickslip
						SET @nCheck = 0
						IF ((1 * @nCaseCnt) + @nQtyPacked) <= @nQtyPicked
						   SET @nCheck = 1
               END   -- IF @cPrepackByBOM = '1'



               IF (@nQtyPicked > @nQtyPacked) AND @nCheck = 1
                  BREAK

               FETCH NEXT FROM CUR_GETORDER INTO @cOrderKey, @cDiscrete_PickSlipNo
            END
            CLOSE CUR_GETORDER
            DEALLOCATE CUR_GETORDER
            
         END -- IF @cPickSlipType = 'CONSO'
         ELSE
         BEGIN
         	
            SELECT TOP 1 @cOrderKey = OrderKey, @cDiscrete_PickSlipNo = PickHeaderKey 
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo

            IF @cPrepackByBOM = '1'
            BEGIN
               --Perfomance tuning (james03)
               SELECT @nQtyPicked = ISNULL(SUM(PD.QTY), 0) 
               FROM dbo.PICKDETAIL PD WITH (NOLOCK) 
               JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (PD.StorerKey = BOM.StorerKey AND PD.SKU = BOM.ComponentSku)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.OrderKey = @cOrderkey 
                  AND BOM.SKU = @cSKUCode

               SELECT @nQtyPacked = ISNULL(SUM(PD.QTY), 0) 
               FROM dbo.PACKDETAIL PD WITH (NOLOCK) 
               JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON (PD.StorerKey = BOM.StorerKey AND PD.SKU = BOM.ComponentSku)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.Pickslipno = @cDiscrete_PickSlipNo 
                  AND BOM.SKU = @cSKUCode

               -- (james05)
               SET @nCheck = 0
               DECLARE CUR_CHECKPACKQTY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
               SELECT BOM.ComponentSKU, BOM.Qty FROM dbo.BillOfMaterial BOM WITH (NOLOCK) 
               JOIN dbo.UPC UPC WITH (NOLOCK) ON (BOM.StorerKey = UPC.StorerKey AND BOM.SKU = UPC.SKU)
               WHERE BOM.StorerKey = @cStorerKey
                  AND BOM.SKU = @cSKUCode
                  AND UPC.UOM = 'CS'
               OPEN CUR_CHECKPACKQTY
               FETCH NEXT FROM CUR_CHECKPACKQTY INTO @cBOM_SKU, @nBOM_Qty
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  -- 1 = 1 CASE, we pack 1 case at one time
                  -- if qty to be packed + qty already packed <= qtyallocated + qtypicked 
                  -- then can proceed else skup this discrete pickslip
                  IF ((1 * @nCaseCnt * @nBOM_Qty) + @nQtyPacked) <= @nQtyPicked
                     SET @nCheck = 1

                  FETCH NEXT FROM CUR_CHECKPACKQTY INTO @cBOM_SKU, @nBOM_Qty
               END
               CLOSE CUR_CHECKPACKQTY
               DEALLOCATE CUR_CHECKPACKQTY
            END
            ELSE
            BEGIN
               SELECT @nQtyPicked = ISNULL(SUM(QTY), 0) 
               FROM dbo.PICKDETAIL WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND OrderKey = @cOrderkey 
                  AND SKU = @cSKUCode

               SELECT @nQtyPacked = ISNULL(SUM(QTY), 0) 
               FROM dbo.PACKDETAIL WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND Pickslipno = @cDiscrete_PickSlipNo 
                  AND SKU = @cSKUCode

					-- 1 = 1 CASE, we pack 1 case at one time
					-- if qty to be packed + qty already packed <= qtyallocated + qtypicked 
					-- then can proceed else skup this discrete pickslip
					SET @nCheck = 0
					IF ((1 * @nCaseCnt) + @nQtyPacked) <= @nQtyPicked
					   SET @nCheck = 1
            END   -- IF @cPrepackByBOM = '1'
            
             
         END
         
         SET @c_Step2_End = GETDATE()
         
         SET @cGS1TemplatePath_Final = RTRIM(@cGS1TemplatePath1) + RTRIM(@cGS1TemplatePath2) + RTRIM(@cGS1TemplatePath3) +
                                       RTRIM(@cGS1TemplatePath4) + RTRIM(@cGS1TemplatePath5) + RTRIM(@cGS1TemplatePath6)


         IF (@nQtyPicked > @nQtyPacked) AND @nCheck = 1 
         BEGIN
         	IF @c_Step3_Start IS NULL
               SET @c_Step3_Start = GETDATE()   

            SET @n_Step3Ctn = @n_Step3Ctn + 1
            SET @cErrMsg = @cGS1BatchNo          	
            EXEC rdt.rdt_Scan_And_Pack_InsertPackDetail 
               @nMobile,
               @cFacility,
               @cStorerKey,
               @cMBOLKey,
               @cLoadKey,
               @cOrderKey,
               @cPickSlipType,
               @cPickSlipNo,
               @cDiscrete_PickSlipNo,
               @cBuyerPO,
               @cFilePath1,
               @cFilePath2,
               @cSKUCode,
               1, -- 1 case per time
               @cPrepackByBOM,
               @cUserName,   
               -- @cTemplateID,
               @cGS1TemplatePath_Final, -- SOS# 140526
               @cPrinter,
               @cLangCode,
               @nCaseCnt, -- (Vicky02)
               @nCartonNo     OUTPUT,
               @cLabelNo      OUTPUT,
               @nErrNo        OUTPUT, 
               @cErrMsg       OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cQty = ''
               SET @cOutField04 = CASE WHEN ISNULL(@nCasePackDefaultQty, 0) = 0 THEN '' ELSE @nCasePackDefaultQty END
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Quit
            END
            
            IF @bDebug = 3  
            BEGIN  
               SET @c_Step3_End = GETDATE() 
            END             
         END

         SET @nQty = @nQty - 1
      END -- WHILE @nQty > 0

      SET @c_step1 = GETDATE() - @c_step1
      
      SET @c_step4 = GETDATE() 
      
      -- Check if any outstanding qty to be packed for current pickslip
      IF @cPickSlipType = 'SINGLE'
      BEGIN
         SELECT @nPickDSKUQty = ISNULL(SUM(PD.QTY), 0) 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.PickHeader PH WITH (NOLOCK) ON (PD.OrderKey = PH.OrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE PD.StorerKey = @cStorerKey
            AND PH.PickHeaderKey = @cPickslipNo
           AND L.Facility = @cFacility

         SELECT @nPackDSKUQty = ISNULL(SUM(QTY), 0) 
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickslipNo = @cPickslipNo 
            AND StorerKey = @cStorerKey
      END
      ELSE
      BEGIN
         SELECT @nPickDSKUQty = ISNULL(SUM(PD.QTY), 0) 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
         JOIN dbo.PickHeader PH WITH (NOLOCK) ON (O.LoadKey = PH.ExternOrderKey)
         JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
         WHERE PD.StorerKey = @cStorerKey
            AND PH.PickHeaderKey = @cPickslipNo
            AND L.Facility = @cFacility

         SELECT @nPackDSKUQty = ISNULL(SUM(QTY), 0) 
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE Refno = @cPickslipNo 
            AND StorerKey = @cStorerKey
      END

      SET @c_step4 = GETDATE() - @c_step4  
  
      
      Check_SKU_In_Ord:
      IF @cOption NOT IN ('1', '')
      BEGIN
         SET @cOption = ''
         SET @nErrNo = 66284
         SET @cErrMsg = rdt.rdtgetmessage( 66284, @cLangCode, 'DSP') --'Invalid Option'
         SET @cOutField09 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      IF @cOption = '1'
      BEGIN
         SET @c_step5 = GETDATE() 
            	
         EXECUTE rdt.rdt_Scan_And_Pack_GetNext2SKU  
            @cStorerKey,
            @cPickSlipNo,
            @cPickSlipType,
            '',   -- SKU
            '1',  -- 1 = Next Rec; 0 = Prev Rec
	         @cLangCode,
            @nErrNo        OUTPUT, 
            @cErrMsg     	OUTPUT,
            @cSKU1         OUTPUT,
            @cSKU_Descr1   OUTPUT,
            @cQtyAlloc1    OUTPUT,
            @cQTYScan1     OUTPUT,
            @cSKU2         OUTPUT,
            @cSKU_Descr2   OUTPUT,
            @cQtyAlloc2    OUTPUT,
            @cQTYScan2     OUTPUT

         IF @nErrNo <> 0    
         BEGIN  
            GOTO Quit  
         END 


         -- Count no. of page
         SELECT @nCnt = COUNT (DISTINCT PD.SKU) 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
         WHERE O.StorerKey = @cStorerKey
            AND O.LoadKey = @cLoadKey

         IF @nCnt > 0
         BEGIN
            SET @nTotalPages = CEILING(@nCnt / 2)
            SET @nPages = 1
         END

         SET @cOutField01 = ' 1 of ' + CAST(@nTotalPages AS NVARCHAR( 2))
         SET @cOutField02 = @cSKU1
         SET @cOutField03 = SUBSTRING(@cSKU_Descr1, 1, 20)
         SET @cOutField04 = @cQtyAlloc1
         SET @cOutField05 = @cQTYScan1
         SET @cOutField06 = @cSKU2
         SET @cOutField07 = SUBSTRING(@cSKU_Descr2, 1, 20)
         SET @cOutField08 = @cQtyAlloc2
         SET @cOutField09 = @cQTYScan2
         SET @cOutField10 = ''

         SET @c_step5 = GETDATE() - @c_step5  
      
                        
         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Quit
      END

      IF @cOption = '' AND (@nPickDSKUQty - @nPackDSKUQty) > 0
      BEGIN
         -- Prepare prev screen var
         SET @cOutField01 = @cPickSlipNo 
         SET @cOutField02 = @cLoadKey
         SET @cOutField03 = CASE WHEN @cPickSlipType = 'CONSO' THEN 'MULTI' ELSE @cOrderKey END
         SET @cOutField04 = @cLabelNo
         SET @cOutField05 = @nCartonNo
         SET @cOutField06 = ''   -- SKU/UPC

         -- Go to prev screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1

         GOTO Quit
      END
      ELSE
      IF @cOption = '' AND (@nPickDSKUQty - @nPackDSKUQty) = 0
      BEGIN
         -- Go to screen 8
         SET @nScn = @nScn + 5
         SET @nStep = @nStep + 5

         GOTO Quit
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cPickSlipNo 
      SET @cOutField02 = @cLoadKey
      SET @cOutField03 = CASE WHEN @cPickSlipType = 'CONSO' THEN 'MULTI' ELSE @cOrderKey END
      SET @cOutField04 = @cLabelNo
      SET @cOutField05 = @nCartonNo
      SET @cOutField06 = ''   -- SKU/UPC

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
END
GOTO Quit

/********************************************************************************
Step 4. Scn = 1934. 
   99 of 99  (field01)
   SKU1      (field02)
   DESCR1    (field03)
   QTY ALLOC (field04)
   QTY SCAN  (Field05)

   SKU2      (Field06)
   DESCR2:   (Field07)
   QTY ALLOC (field08)
   QTY SCAN  (Field09)

   OPT       (field10)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
	   SET @cOption = @cInField10

      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 66285
         SET @cErrMsg = rdt.rdtgetmessage( 66285, @cLangCode,'DSP') --Invalid Oprion
         GOTO Step_4_Fail
      END
   END

   IF @cOption = '1' 
   BEGIN
      EXECUTE rdt.rdt_Scan_And_Pack_GetNext2SKU  
         @cStorerKey,
         @cPickSlipNo,
         @cPickSlipType,
         @cSKU2,
         '1',
         @cLangCode,
         @nErrNo        OUTPUT, 
         @cErrMsg     	OUTPUT,
         @cSKU1         OUTPUT,
         @cSKU_Descr1   OUTPUT,
         @cQtyAlloc1    OUTPUT,
         @cQTYScan1     OUTPUT,
         @cSKU2         OUTPUT,
         @cSKU_Descr2   OUTPUT,
         @cQtyAlloc2    OUTPUT,
         @cQTYScan2     OUTPUT

      IF @nErrNo <> 0    
      BEGIN  
         GOTO Quit  
      END      

      -- Count no. of page
      SELECT @nCnt = COUNT (DISTINCT PD.SKU) 
      FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
      WHERE O.StorerKey = @cStorerKey
         AND O.LoadKey = @cLoadKey

      IF @nCnt > 0
      BEGIN
         SET @nTotalPages = CEILING(@nCnt / 2)
      END

      SET @nPages = @nPages + 1  

      SET @cOutField01 = CAST(@nPages AS NVARCHAR( 2)) + ' of ' + CAST(@nTotalPages AS NVARCHAR( 2))
      SET @cOutField02 = @cSKU1
      SET @cOutField03 = SUBSTRING(@cSKU_Descr1, 1, 20)
      SET @cOutField04 = @cQtyAlloc1
      SET @cOutField05 = @cQTYScan1
      SET @cOutField06 = CASE WHEN @cSKU2 = 'ZZZZZZZZZZZZZZZZZZZZ' THEN '' ELSE @cSKU2 END
      SET @cOutField07 = SUBSTRING(@cSKU_Descr2, 1, 20)
      SET @cOutField08 = @cQtyAlloc2
      SET @cOutField09 = @cQTYScan2
      SET @cOutField10 = ''

      GOTO Quit
   END

   IF @cOption = '2'
   BEGIN
      EXECUTE rdt.rdt_Scan_And_Pack_GetNext2SKU  
         @cStorerKey,
         @cPickSlipNo,
         @cPickSlipType,
         @cSKU1,
         '0',
         @cLangCode,
         @nErrNo        OUTPUT, 
         @cErrMsg     	OUTPUT,
         @cSKU1         OUTPUT,
         @cSKU_Descr1   OUTPUT,
         @cQtyAlloc1    OUTPUT,
         @cQTYScan1     OUTPUT,
         @cSKU2         OUTPUT,
         @cSKU_Descr2   OUTPUT,
         @cQtyAlloc2    OUTPUT,
         @cQTYScan2     OUTPUT

      IF @nErrNo <> 0    
      BEGIN  
         GOTO Quit  
      END      

      -- Count no. of page
      SELECT @nCnt = COUNT (DISTINCT PD.SKU) 
      FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
      WHERE O.StorerKey = @cStorerKey
         AND O.LoadKey = @cLoadKey

      IF @nCnt > 0
      BEGIN
         SET @nTotalPages = CEILING(@nCnt / 2)
      END

      SET @nPages = @nPages - 1  

      SET @cOutField01 = CAST(@nPages AS NVARCHAR( 2)) + ' of ' + CAST(@nTotalPages AS NVARCHAR( 2))
      SET @cOutField02 = @cSKU1
      SET @cOutField03 = SUBSTRING(@cSKU_Descr1, 1, 20)
      SET @cOutField04 = @cQtyAlloc1
      SET @cOutField05 = @cQTYScan1
      SET @cOutField06 = CASE WHEN @cSKU2 = 'ZZZZZZZZZZZZZZZZZZZZ' THEN '' ELSE @cSKU2 END
      SET @cOutField07 = SUBSTRING(@cSKU_Descr2, 1, 20)
      SET @cOutField08 = @cQtyAlloc2
      SET @cOutField09 = @cQTYScan1
      SET @cOutField10 = ''
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare screen 2 var
      SET @cOutField01 = @cPickSlipNo 
      SET @cOutField02 = @cLoadKey
      SET @cOutField03 = CASE WHEN @cPickSlipType = 'CONSO' THEN 'MULTI' ELSE @cOrderKey END
      SET @cOutField04 = @cLabelNo
      SET @cOutField05 = @nCartonNo   
      SET @cOutField06 = ''   -- SKU/UPC

      -- Go to screen 2
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END
   GOTO Quit   
   
   Step_4_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 5. Scn = 1935. 
   OPTION     (field01, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 66286
         SET @cErrMsg = rdt.rdtgetmessage( 66286, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_5_Fail
      END
 
      -- If option = 1, template id will be defaulted to 'Generic.btw'
      IF @cOption = '1'
      BEGIN
--         SET @cTemplateID = 'Generic.btw'
         SET @cGenTemplateID = 'Generic.btw' -- (Vicky03)

         -- Prepare next screen var
         SET @cOutField01 = @cPickSlipNo 
         SET @cOutField02 = @cLoadKey
         SET @cOutField03 = CASE WHEN @cPickSlipType = 'CONSO' THEN 'MULTI' ELSE @cOrderKey END
         SET @cOutField04 = ''
         SET @cOutField05 = ''   
         SET @cOutField06 = ''   -- SKU/UPC

         -- Go to prev screen
         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3                
         GOTO Quit
      END

      -- If option = 2, prompt error and go back to screen 1
      IF @cOption = '2'
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '66287 Template ID'
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
         SET @nScn = @nScn - 4
         SET @nStep = @nStep - 4                
         GOTO Quit
      END
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cPrinter
      SET @cOutField02 = @cPickSlipNo
      EXEC rdt.rdtSetFocusField @nMobile, 2

      -- Go to prev screen
      SET @nScn = @nScn - 4
      SET @nStep = @nStep - 4
   END
   
   Step_5_Fail:

   GOTO Quit   
END
GOTO Quit

/********************************************************************************
Step 6. Scn = 1915. 
   Option
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 66288
         SET @cErrMsg = rdt.rdtgetmessage( 66288, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_6_Fail
      END

      IF @cOption = '1'
      BEGIN
         SET @cOutField01 = ''

         -- Go to prev screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
         GOTO Quit
      END

      IF @cOption = '2'
      BEGIN
         -- Prepare prec screen var
         SET @cOutField01 = @cPickSlipNo 
         SET @cOutField02 = @cLoadKey
         SET @cOutField03 = @cOrderKey
         SET @cOutField04 = @cLabelNo
         SET @cOutField05 = @nCartonNo   
         SET @cOutField06 = ''   -- SKU/UPC

         -- Go to prev screen
         SET @nScn = @nScn - 4
         SET @nStep = @nStep - 4
         GOTO Quit
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prec screen var
      SET @cOutField01 = @cPickSlipNo 
      SET @cOutField02 = @cLoadKey
      SET @cOutField03 = @cOrderKey
      SET @cOutField04 = @cLabelNo
      SET @cOutField05 = @nCartonNo   
      SET @cOutField06 = ''   -- SKU/UPC

      -- Go to prev screen
      SET @nScn = @nScn - 4
      SET @nStep = @nStep - 4
      GOTO Quit
   END
   
   Step_6_Fail:

   GOTO Quit   
END
GOTO Quit

/********************************************************************************
Step 7. Scn = 1937. 
   Option
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 66289
         SET @cErrMsg = rdt.rdtgetmessage( 66289, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_7_Fail
      END

      IF @cOption = '1'
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1

         -- Go to prev screen
         SET @nScn = @nScn - 6
        SET @nStep = @nStep - 6
         GOTO Quit
      END

      IF @cOption = '2'
      BEGIN
         -- Prepare prec screen var
         SET @cOutField01 = @cPickSlipNo 
         SET @cOutField02 = @cLoadKey
         SET @cOutField03 = @cOrderKey
         SET @cOutField04 = @cLabelNo
         SET @cOutField05 = @nCartonNo   
         SET @cOutField06 = ''   -- SKU/UPC

         -- Go to prev screen
         SET @nScn = @nScn - 5
         SET @nStep = @nStep - 5
         GOTO Quit
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prec screen var
      SET @cOutField01 = @cPickSlipNo 
      SET @cOutField02 = @cLoadKey
      SET @cOutField03 = @cOrderKey
      SET @cOutField04 = @cLabelNo
      SET @cOutField05 = @nCartonNo   
      SET @cOutField06 = ''   -- SKU/UPC

      -- Go to prev screen
      SET @nScn = @nScn - 5
      SET @nStep = @nStep - 5
   GOTO Quit
   END
   
Step_7_Fail:

   GOTO Quit   
END
GOTO Quit

/********************************************************************************
Step 8. Scn = 1938. 
   Option
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey IN (0, 1)
   BEGIN
      BEGIN TRAN

--      IF @cPickSlipType = 'SINGLE'
--      BEGIN
--         SELECT @nTotalCnt = ISNULL(MAX(CartonNo), 0) FROM dbo.PackDetail WITH (NOLOCK)
--         WHERE StorerKey = @cStorerKey
--            AND PickSlipNo = @cPickSlipNo
--
--         -- Update packheader.TTLCNTS = MAX(CartonNo) when total pickedqty = packedqty of the whole pickslip
--         UPDATE dbo.PackHeader WITH (ROWLOCK) SET 
--            TTLCNTS = @nTotalCnt
--         WHERE StorerKey = @cStorerKey
--            AND PickSlipNo = @cPickSlipNo
--
--         IF @@Error <> 0 
--         BEGIN
--            ROLLBACK TRAN
--            SET @nErrNo = 66290
--            SET @cErrMsg = rdt.rdtgetmessage( 66290, @cLangCode, 'DSP') --UPDPHeaderFail
--            GOTO Quit
--         END
--      END
--      ELSE
--      BEGIN
--         SELECT @nTotalCnt = ISNULL(COUNT(DISTINCT LabelNo), 0) FROM dbo.PackDetail WITH (NOLOCK)
--         WHERE StorerKey = @cStorerKey
--            AND Refno = @cPickSlipNo
--
--         -- Update packheader.TTLCNTS = no. of label (1 carton = 1 label) 
--         -- when total pickedqty = packedqty of the whole pickslip
--         UPDATE dbo.PackHeader WITH (ROWLOCK) SET 
--            TTLCNTS = @nTotalCnt
--         WHERE StorerKey = @cStorerKey
--            AND PickSlipNo = @cPickSlipNo
--
--         IF @@Error <> 0 
--         BEGIN
--            ROLLBACK TRAN
--            SET @nErrNo = 66290
--            SET @cErrMsg = rdt.rdtgetmessage( 66290, @cLangCode, 'DSP') --UPDPHeaderFail
--            GOTO Quit
--         END
--      END

      IF @cAutoPackConfirm = '1'
      BEGIN

--         UPDATE dbo.PackHeader WITH (ROWLOCK) SET 
--            Status = '9' 
--         WHERE PickSlipNo = @cPickSlipNo
--
--         IF @@Error <> 0 
--         BEGIN
--            ROLLBACK TRAN
--            SET @nErrNo = 66291
--            SET @cErrMsg = rdt.rdtgetmessage( 66291, @cLangCode, 'DSP') --PackConfFail
--            GOTO Quit
--         END
         -- James01 - Start
         IF @cPickSlipType = 'SINGLE'
         BEGIN
            UPDATE dbo.PackHeader WITH (ROWLOCK) SET 
               Status = '9' 
            WHERE PickSlipNo = @cPickSlipNo
   
            IF @@Error <> 0 
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 66291
               SET @cErrMsg = rdt.rdtgetmessage( 66291, @cLangCode, 'DSP') --PackConfFail
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            --Pack confirm for Discrete Pickslip first with ArchiveCop
            DECLARE CUR_CfmPack CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT OrderKey FROM dbo.ORDERS WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND LoadKey = @cLoadKey
            OPEN CUR_CfmPack
            FETCH NEXT FROM CUR_CfmPack INTO @cTemp_OrderKey
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               UPDATE dbo.PackHeader WITH (ROWLOCK) SET 
                  Status = '9'--, ArchiveCop = NULL   (james04)
              WHERE OrderKey = @cTemp_OrderKey
                  AND PickSlipNo <> @cPickSlipNo

               IF @@Error <> 0 
               BEGIN
                  ROLLBACK TRAN
                  SET @nErrNo = 66298
                  SET @cErrMsg = rdt.rdtgetmessage( 66298, @cLangCode, 'DSP') --PackConfFail
                  GOTO Quit
               END

               FETCH NEXT FROM CUR_CfmPack INTO @cTemp_OrderKey
            END
            CLOSE CUR_CfmPack
            DEALLOCATE CUR_CfmPack
            
            -- Pack confirm conso Pickslip
            UPDATE dbo.PackHeader WITH (ROWLOCK) SET 
               Status = '9' 
            WHERE PickSlipNo = @cPickSlipNo
   
            IF @@Error <> 0 
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 66299
               SET @cErrMsg = rdt.rdtgetmessage( 66299, @cLangCode, 'DSP') --PackConfFail
               GOTO Quit
            END
        END -- James01 - End
      END

      COMMIT TRAN

      SET @cOutField01 = ''
      SET @cOutField02 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to prev screen
      SET @nScn = @nScn - 7
      SET @nStep = @nStep - 7
      GOTO Quit
   END
END
GOTO Quit

/********************************************************************************
Step 9. Scn = 1939. 
   Msg
********************************************************************************/
Step_9:
BEGIN
   IF @nInputKey IN (0, 1)
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1

      SET @cPickSlipNo = ''
      SET @cPrinter = ''

      -- Go to prev screen
      SET @nScn = @nScn - 8
      SET @nStep = @nStep - 8
   END
END
GOTO Quit
/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   IF @bDebug = 3 AND @c_starttime IS NOT NULL 
   BEGIN  
   	
      SET @c_endtime = GETDATE()
      
      SET  @c_step2 = @c_Step2_End - @c_Step2_Start
      SET  @c_step3 = @c_Step3_End - @c_Step3_Start
      --SET  @c_step4 = @c_Step4_End - @c_Step4_Start

      INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5
                             ,Col1, Col2, Col3, Col4, Col5) VALUES  
       ('rdtfnc_Scan_And_Pack', @c_starttime, @c_endtime,  
        CONVERT(CHAR(12),@c_endtime-@c_starttime ,114),  
        LEFT(CONVERT( NVARCHAR( 12), @c_step1, 114),8) + '-' + CAST( @n_step1Ctn AS NVARCHAR( 3)),  
        LEFT(CONVERT( NVARCHAR( 12), @c_step2, 114),8) + '-' + CAST( @n_step2Ctn AS NVARCHAR( 3)),  
        LEFT(CONVERT( NVARCHAR( 12), @c_step3, 114),8) + '-' + CAST( @n_step3Ctn AS NVARCHAR( 3)),  
        LEFT(CONVERT( NVARCHAR( 12), @c_step4, 114),8) + '-' + CAST( @n_step4Ctn AS NVARCHAR( 3)), 
        '',  --LEFT(CONVERT( NVARCHAR( 12), @c_step5, 114),8) + '-' + CAST( @n_step5Ctn AS NVARCHAR( 3))  
        @c_Col1,
        @c_Col2,
        @c_Col3,
        @c_Col4,
        @c_Col5)  
   END 

	
   UPDATE RDTMOBREC WITH (ROWLOCK) SET 
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg, 
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility, 
--    Printer   = @cPrinter,    
      -- UserName  = @cUserName,

      V_UOM = @cPUOM,
      V_QTY = @nQTY,
      V_SKU = @cSKU,

      V_SKUDescr   = @cDescr,
      V_PickSlipNo = @cPickSlipNo,
      V_OrderKey   = @cOrderKey,
      V_LoadKey    = @cLoadKey,
      
      V_Cartonno   = @nCartonNo,
   
      V_Integer1 = @cCheckPickB4Pack,
      V_Integer2 = @cGSILBLITF,
      V_Integer3 = @cPrepackByBOM,
      V_Integer4 = @cAutoPackConfirm,
      V_Integer5 = @nCasePackDefaultQty,
      V_Integer6 = @nPickDSKUQty,
      V_Integer7 = @nPackDSKUQty,
      V_Integer8 = @nPages,
      V_Integer9 = @nCaseCnt,
      
      --V_String1  = @cCheckPickB4Pack,
      --V_String2  = @cGSILBLITF,
      --V_String3  = @cPrepackByBOM,
      --V_String4  = @cAutoPackConfirm,
      --V_String5  = @nCasePackDefaultQty,
      V_String6  = @cUPC_SKU,
      V_String7  = @cPickSlipType,
      V_String8  = @cMBOLKey,
      V_String9  = @cBuyerPO,         
      V_String10 = @cTemplateID,
      V_String11 = @cFilePath1,
      V_String12 = @cFilePath2, 
      --V_String13 = @nCartonNo,
      V_String14 = @cLabelNo, 
      V_String15 = @cSKU1,
      V_String16 = @cSKU2,
      V_String17 = @cSKU_Descr1,
      V_String18 = @cSKU_Descr2,
      V_String19 = @cQtyAlloc1,
      V_String20 = @cQtyAlloc2,
      V_String21 = @cQtyScan1,
      V_String22 = @cQtyScan2,
      --V_String23 = @nPickDSKUQty,
      --V_String24 = @nPackDSKUQty,
      --V_String25 = @nPages,
      V_String26 = @cPrinter,
      V_String27 = @cGS1TemplatePath1, -- (Vicky03)
      --V_String28 = @nCaseCnt, -- (Vicky02)
      V_String29 = @cGenTemplateID, -- (Vicky03)
      V_String30 = @cGS1TemplatePath2, -- (Vicky03)
      V_String31 = @cGS1TemplatePath3, -- (Vicky03)
      V_String32 = @cGS1TemplatePath4, -- (Vicky03)
      V_String33 = @cGS1TemplatePath5, -- (Vicky03)
      V_String34 = @cGS1TemplatePath6, -- (Vicky03)
      V_String35 = @cDiscrete_PickSlipNo, -- (james03)

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