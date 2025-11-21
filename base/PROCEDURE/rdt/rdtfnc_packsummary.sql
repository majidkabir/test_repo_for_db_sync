SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/********************************************************************************/
/* Store procedure: rdtfnc_PackSummary                                          */
/* Copyright      : IDS                                                         */
/*                                                                              */
/* Purpose: PackSummary                                                         */
/*                                                                              */
/* Modifications log:                                                           */
/*                                                                              */
/* Date        Rev    Author   Purposes                                         */
/* 2010-08-11  1.0    ChewKP   SOS# 184071 Created                              */
/* 2010-09-03  1.0    AQSKC    Update UPS Tracking Number & bug fix(Kc01)       */
/* 2010-09-15  1.0    AQSKC    Fix GS1Label filename length (Kc02)              */
/* 2010-09-17  1.0    AQSKC    Insert PackInfo on each carton scan (Kc03)       */
/* 2010-10-20  1.0    AQSKC    Fix issue with packinfo deletion (Kc04)          */
/* 2010-01-07  1.0    TLTING   Perfromance Tune (TLTING01)                      */
/* 2011-02-14  1.1    Leong    SOS# 205340 - Retrieve GS1 folder path based on  */
/*                                           Orders.Facility                    */
/* 2012-01-06  1.2    Ung      SOS231812 Standarize print GS1 to use Exceed's   */
/* 2016-09-30  1.3    Ung      Performance tuning                               */
/* 2018-10-19  1.4    Gan      Performance tuning                               */
/* 2021-03-10  1.5    YeeKung  RENAME packsummary_packcofirm to                 */
/*                             packsummary_packconfirm (yeekung01)              */
/********************************************************************************/

CREATE PROC [RDT].[rdtfnc_PackSummary](
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
   @nFunc                  INT,
   @nScn                   INT,
   @nStep                  INT,
   @cLangCode              NVARCHAR(3),
   @nMenu                  INT,
   @nInputKey              NVARCHAR(3),
   @cPrinter               NVARCHAR(10),
   @cUserName              NVARCHAR(18),

   @cStorerKey             NVARCHAR(15),
   @cFacility              NVARCHAR(5),
   @cOrdFacility           NVARCHAR(5), -- SOS# 205340

   @cPrinterID             NVARCHAR(20),
   @cPickSlipNo            NVARCHAR(10),
   @cCheckPickB4Pack       NVARCHAR(1),
   @nPickDetailQty         INT,
   @nPackQty               INT,
   @nCartonNo              INT,
   @nDispCartonNo          INT,
   @fWeight                Float,
   @cSKU                   NVARCHAR(20),
   @cOrderkey              NVARCHAR(10),
   @cRoute                 NVARCHAR(10),
   @cLoadkey               NVARCHAR(10),
   @cPickSlipType          NVARCHAR(10),
   @cLabelNo               NVARCHAR(20),
   @cLabelLine             NVARCHAR(5),
   @cOrderRefNo            NVARCHAR(30),
   @cConsigneeKey          NVARCHAR(15),
   @cOption                NVARCHAR(1),
   @cGSILBLITF             NVARCHAR(1),
   @cFilePath              NVARCHAR(30),
   @cGS1TemplatePath       NVARCHAR(120),
   @cInWeight              NVARCHAR(10),
   @nMaxCartonNo           INT,
   @nTTLCarton             INT,
   @cCartonDisp            NVARCHAR(15),
   @bSuccess               INT,              --(KC01)

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

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @cLangCode        = Lang_code,
   @nMenu            = Menu,

   @cFacility        = Facility,
   @cStorerKey       = StorerKey,
   @cPrinter         = Printer,
   @cUserName        = UserName,

   @cOrderKey        = V_Orderkey,
   @cConsigneekey    = V_ConsigneeKey,
   @cSKU             = V_SKU,
   --@cSKUDescr        = V_SKUDescr,
   --@cPackUOM03       = V_UOM,
   @cPickSlipNo      = V_String1,
   @cPrinterID       = V_String2,
   
   @nTTLCarton       = V_Integer1,
   
   @nCartonNo        = V_Cartonno,

  -- @nTTLCarton       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3, 5), 0) = 1 THEN LEFT( V_String3, 5) ELSE 0 END,
  -- @nCartonNo        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 5), 0) = 1 THEN LEFT( V_String4, 5) ELSE 0 END,
   --@nActQty          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9, 5), 0) = 1 THEN LEFT( V_String9, 5) ELSE 0 END,

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

FROM   RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 951
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 951
   IF @nStep = 1 GOTO Step_1   -- Scn = 2520  PrinterID, PSNO
   IF @nStep = 2 GOTO Step_2   -- Scn = 2521  WEIGHT
   IF @nStep = 3 GOTO Step_3   -- Scn = 2522  OPTION
   IF @nStep = 4 GOTO Step_4   -- Scn = 2523  PACK CONFIRM
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 951)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 2520
   SET @nStep = 1

    -- EventLog - Sign In Function
--    EXEC RDT.rdt_STD_EventLog
--     @cActionType = '1', -- Sign in function
--     @cUserID     = @cUserName,
--     @nMobileNo   = @nMobile,
--     @nFunctionID = @nFunc,
--     @cFacility   = @cFacility,
--     @cStorerKey  = @cStorerkey

   -- initialise all variable
   SET @cCheckPickB4Pack = ''
   SET @nPickDetailQty  = 0
   SET @nPackQty        = 0
   SET @nCartonNo       = 0
   SET @nDispCartonNo   = 0
   SET @cSKU            = ''
   SET @fWeight         = 0
   SET @cSKU            = ''
   SET @cOrderkey       = ''
   SET @cRoute          = ''
   SET @cLoadkey        = ''
   SET @cPickSlipType   = ''
   SET @cLabelNo        = ''
   SET @cLabelLine      = ''
   SET @cOrderRefNo     = ''
   SET @cConsigneeKey   = ''
   SET @cOption         = ''
   SET @cGSILBLITF            = ''
   SET @cFilePath             = ''
   SET @cGS1TemplatePath      = ''
   SET @nMaxCartonNo          = 0
   SET @cPickSlipNo           = ''
   SET @cOrdFacility          = '' -- SOS# 205340

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
   SET @cOutField12 = ''
   SET @cOutField13 = ''
   SET @cOutField14 = ''
   SET @cOutField15 = ''
END
GOTO Quit

/********************************************************************************
Step 1. screen = 2520
   PRINTER ID (Field01, input)
   PSNO (Field02, input)
   TTL Cartons (Field03, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPrinterID = ISNULL(@cInField01,'')
      SET @cPickSlipNo = ISNULL(@cInField02,'')
      SET @nTTLCarton = ISNULL(@cInField03,0)

      IF ISNULL(RTRIM(@cPrinterID), '') = ''
      BEGIN
         SET @nErrNo = 70866
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PrinterID Req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      IF ISNULL(RTRIM(@cPickSlipNo), '') = ''
      BEGIN
         SET @nErrNo = 70867
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PSNO Req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.PickHeader WITH (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo )
      BEGIN
         SET @nErrNo = 70868
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- SOS# 205340 (Start)
      SELECT TOP 1 @cOrdFacility = O.Facility
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK)
      ON (PD.OrderKey = O.OrderKey)
      WHERE PD.PickSlipNo = @cPickSlipNo

      IF ISNULL(RTRIM(@cFacility),'') <> ISNULL(RTRIM(@cOrdFacility),'')
      BEGIN
         SET @nErrNo = 70898
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Facility
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END
      -- SOS# 205340 (End)

      IF @nTTLCarton <= 0
      BEGIN
         SET @nErrNo = 70890
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonNo Req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      IF ISNUMERIC ( @nTTLCarton ) <> 1
      BEGIN
         SET @nErrNo = 70889
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv CartonNo
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      SELECT @cStorerkey = Storerkey FROM dbo.PickDetail WITH (NOLOCK)
      WHERE PickSlipNo  = @cPickSlipNo

--      IF NOT EXISTS ( SELECT 1 FROM dbo.PickHeader WITH (NOLOCK) WHERE  PickHeaderKey = @cPickSlipNo AND Storerkey = @cStorerkey )
--      BEGIN
--         SET @nErrNo = 70869
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Storer
--         EXEC rdt.rdtSetFocusField @nMobile, 1
--         GOTO Step_1_Fail
--      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND ScanInDate <> NULL )
      BEGIN
         SET @nErrNo = 70870
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS not scan in
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      SET @cCheckPickB4Pack = ''
      SET @cCheckPickB4Pack = rdt.RDTGetConfig( @nFunc, 'CheckPickB4Pack', @cStorerKey)

      IF @cCheckPickB4Pack = 1
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND ScanOutDate = NULL )
         BEGIN
            SET @nErrNo = 70871
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CheckPickB4Pack
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END
      END
      ELSE
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND ScanOutDate IS NOT NULL )
         BEGIN
            SET @nErrNo = 70872
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS scan out
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END
      END

     SET @nPickDetailQty = 0
     SELECT @nPickDetailQty = SUM(QTY) FROM dbo.PickDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Storerkey = @cStorerkey


     SET @nPackQty = 0
     SELECT @nPackQty = SUM(QTY) FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Storerkey = @cStorerkey


     IF @nPickDetailQty = @nPackQty
     BEGIN
          SET @nErrNo = 70873
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PS FullyPack
          EXEC rdt.rdtSetFocusField @nMobile, 1
          GOTO Step_1_Fail
     END

     --(Kc01) - do not allow to have more cartons than total pickqty - max  1 qty in 1 carton
     IF @nTTLCarton > @nPickDetailQty
     BEGIN
       SET @nErrNo = 70894
       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Ctns > Picks
       EXEC rdt.rdtSetFocusField @nMobile, 3
       GOTO Step_1_Fail
     END

     SET @nDispCartonNo = 0
     SELECT @nDispCartonNo = CartonNo FROM rdt.RDTPackLog WITH (NOLOCK)
     WHERE PickSlipNo = @cPickSlipNo
     AND Status = '0'

     SET @cCartonDisp = CAST((@nDispCartonNo + 1) AS NVARCHAR(5)) + ' / ' + CAST(@nTTLCarton AS NVARCHAR(5))

      --prepare next screen variable
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = RTRIM(@cCartonDisp)
      SET @cOutField03 = ''
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog - Sign Out Function
--      EXEC RDT.rdt_STD_EventLog
--       @cActionType = '9', -- Sign Out function
--       @cUserID     = @cUserName,
--       @nMobileNo   = @nMobile,
--       @nFunctionID = @nFunc,
--       @cFacility   = @cFacility,
--       @cStorerKey  = @cStorerkey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

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

      SET @cCheckPickB4Pack = ''
      SET @nPickDetailQty  = 0
      SET @nPackQty        = 0

   END
   GOTO Quit

   Step_1_Fail:
   BEGIN

      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 2521
   PSNO        (Field01)
   CARTON NO (Field02) / (Field04)
   WEIGHT      (Field03 , Input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cInWeight = @cInField03

      IF ISNULL(@cInWeight,'') = ''
      BEGIN
         SET @nErrNo = 70874
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WGT Required
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_2_Fail
      END


      IF ISNUMERIC(@cInWeight) <> 1
      BEGIN
         SET @nErrNo = 70875
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid WGT
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_2_Fail
      END

      SET @fWeight = CONVERT(Float, @cInWeight )

      IF  @fWeight  < 0
      BEGIN
         SET @nErrNo = 70876
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WGT < 0
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_2_Fail
      END

      IF (@nCartonNo + 1) > @nTTLCarton AND @fWeight <> 0         --(Kc01) - @nCartonNo = total carton packed excluding current
      BEGIN
         SET @nErrNo = 70892
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CTNNoNotMatch
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_2_Fail
      END

      -- Check PickSlip Type Conso / Discrete

      IF NOT EXISTS (SELECT O.StorerKey
            FROM dbo.PickHeader PH WITH (NOLOCK)
            LEFT OUTER JOIN dbo.ORDERS O WITH (NOLOCK) ON (O.OrderKey = PH.OrderKey)
            WHERE PH.PickHeaderKey = @cPickSlipNo
            GROUP BY O.StorerKey
            HAVING COUNT(O.StorerKey) >= 1)
      BEGIN
         SET @cPickSlipType = 'CONSO'
      END
      ELSE
      BEGIN
         SET @cPickSlipType = 'SINGLE'
      END

      IF @fWeight = 0
      BEGIN

         IF (@nCartonNo) <> @nTTLCarton
         BEGIN
            SET @nErrNo = 70891
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CTNNoNotMatch
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_2_Fail
         END

         -- Pack Confirmation Process --
         EXEC [RDT].[rdtfnc_PackSummary_PackConfirm] --(yeekung01)
               @nMobile          ,
               @cPickSlipNo      ,
               @cStorerkey       ,
               @cPickSlipType    ,
               '1',  -- 1 = Full Pack , 2 = Short Pack
               @cLangCode        ,
               @cUserName        ,
               @nErrNo           OUTPUT,
               @cErrMsg          OUTPUT  -- screen limitation, 20 char max

         IF @nErrNo <> 0
         BEGIN
            --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelRDTLogFail'
            SET @cErrMsg = @cErrMsg
            GOTO Step_2_Fail
         END

         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2

         GOTO QUIT
      END

--      SET @nCartonNo = 0
--      SELECT @nCartonNo = MAX(CartonNo) FROM RDT.RDTPACKLOG WITH (NOLOCK)
--      WHERE PickSlipNo = @cPickSlipNo
--      AND Status = '0'
--
--      IF @nCartonNo = 0
--      BEGIN
--         SET @nCartonNo = 1
--      END

      SET @nCartonNo = 0
      SELECT @nCartonNo = MAX(CartonNo) FROM RDT.RDTPACKLOG WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      AND Status = '0'

      IF @nCartonNo = 0 OR ISNULL(@nCartonNo,'') = ''
      BEGIN
         SET @nCartonNo = 1
      END
      ELSE
      BEGIN
         SET @nCartonNo = @nCartonNo + 1
      END

      SET @cSKU = ''
      -- (Kc01) - start
      /*
      SELECT @cSKU = SKU FROM dbo.PickDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      */

      SELECT TOP 1  @cSKU = ISNULL(SKU, '')
      FROM dbo.PickDetail PK WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      AND NOT EXISTS (SELECT 1 FROM rdt.RDTPACKLOG PKLOG WITH (NOLOCK)
      WHERE PKLOG.PickSlipNo = PK.PickslipNo AND PKLOG.Status = '0' AND PK.SKU = PKLOG.SKU)

      -- will happen this scenario if total carton packed > no. of distinct sku in pickdetail
      IF ISNULL(RTRIM(@cSKU),'') = ''
      BEGIN
         SELECT TOP 1 @cSKU = ISNULL(SKU,'')
         FROM dbo.PickDetail PK WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         GROUP BY SKU
         ORDER BY SUM(QTY) DESC
      END
      -- (Kc01) - end

      BEGIN TRAN

      INSERT INTO RDT.RDTPACKLOG (
         PickSlipNo,
         CartonNo,
         Weight,
         Status,
         SKU,
         Qty,
         Adddate,
         AddWho,
         EditDate,
         EditWho)
      VALUES(
         @cPickSlipNo,
         @nCartonNo,
         @fWeight,
         '0',
         @cSKU,
         1,
         GetDate(),
         @cUserName,
         GetDate(),
         @cUserName
      )

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 70877
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackLogFail
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_2_Fail
      END            ELSE
      BEGIN
         COMMIT TRAN
      END

      SET @cLabelLine = '00000'

      SET @cOrderkey = ''
      SET @cLoadkey = ''
      SET @cRoute = ''
      SET @cOrderRefNo  = ''
      SET @cConsigneeKey = ''

      IF @cPickSlipType = 'CONSO'
      BEGIN

         SELECT TOP 1 @cOrderkey = O.Orderkey,
                      @cLoadkey  = O.Loadkey,
                      @cRoute    = O.Route
         FROM dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON (O.Orderkey = PD.Orderkey AND O.Storerkey = PD.Storerkey)
         WHERE PD.PickSlipNo = @cPickSlipNo

         IF NOT EXISTS (SELECT 1 FROM dbo.PACKHEADER WITH (NOLOCK)
               WHERE Pickslipno = @cPickslipNo)
         BEGIN -- Packheader not exists (Start)
            BEGIN TRAN
            INSERT INTO dbo.PackHeader
                  (Route, OrderKey, Loadkey, StorerKey, PickSlipNo, Status, TTLCNTS)
            VALUES ( @cRoute, @cOrderkey, @cLoadkey, @cStorerkey, @cPickslipNo , 0 , @nTTLCarton)

            IF @@ERROR<>0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 70879
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --InstPKHdr Fail
               GOTO Step_2_Fail
            END
            ELSE
            BEGIN
               COMMIT TRAN
            END
         END
      END -- @cPickSlipType = 'CONSO'
     ELSE -- SINGLE
      BEGIN
         SELECT TOP 1 @cOrderkey       = O.Orderkey,
                       @cLoadkey        = O.Loadkey,
                       @cRoute          = O.Route,
                       @cOrderRefNo     = O.ExternOrderkey,
                       @cConsigneeKey   = O.ConsigneeKey,
                       @cStorerkey      = O.Storerkey
         FROM dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON (O.Orderkey = PD.Orderkey AND O.Storerkey = PD.Storerkey)
         WHERE PD.PickSlipNo = @cPickSlipNo

         IF NOT EXISTS (SELECT 1 FROM dbo.PACKHEADER WITH (NOLOCK)
                    WHERE Pickslipno = @cPickslipNo)
         BEGIN -- Packheader not exists (Start)

            BEGIN TRAN
            INSERT INTO dbo.PackHeader
                 (Route, OrderKey, Loadkey, StorerKey, PickSlipNo, Status, OrderRefNo, ConsigneeKey ,TTLCNTS)
            VALUES ( @cRoute, @cOrderkey, @cLoadkey, @cStorerkey, @cPickslipNo , 0, @cOrderRefNo, @cConsigneeKey, @nTTLCarton)

            IF @@ERROR<>0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 70881
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --InstPKHdr Fail
               GOTO Step_2_Fail
            END
            ELSE
            BEGIN
               COMMIT TRAN
            END
         END
      END -- @cPickSlipType = 'SINGLE'

      EXECUTE [RDT].[rdt_GenUCCLabelNo]
               @cStorerKey,
               @nMobile,
               @cLabelNo OUTPUT,
               @cLangCode,
               @nErrNo   OUTPUT,
               @cErrMsg  OUTPUT

      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 70880
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Gen LBLNo Fail'
         GOTO Step_2_Fail
      END

      BEGIN TRAN
      INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate)
      VALUES
            (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, 1,
            @cUserName, GETDATE(), @cUserName, GETDATE())

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 70878
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDFail'
         GOTO Step_2_Fail
      END

      --(Kc03) - start
      INSERT INTO dbo.PackInfo (PickSlipNo, CartonNo, Weight)
      VALUES (@cPickSlipNo, @nCartonNo, @fWeight)

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 70923
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackIFail'
         GOTO Step_2_Fail
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END
      --(Kc03) - end

      -- Print Label (Start) --
      IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK)
      WHERE Storerkey = @cStorerKey AND Configkey = 'GSILBLITF' AND SValue = '1')
         SET @cGSILBLITF = '1'
      ELSE
         SET @cGSILBLITF = '0'

      SET @cGS1TemplatePath = ''
      SELECT @cGS1TemplatePath = NSQLDescrip
      FROM RDT.NSQLCONFIG WITH (NOLOCK)
      WHERE ConfigKey = 'GS1TemplatePath'
      
      -- GS1 Label validation
      IF @cGSILBLITF = '1'
      BEGIN
         SET @cFilePath = ''

         SELECT TOP 1 @cFilePath = ISNULL(RTRIM(F.UserDefine20 ), '')
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK)
         ON (PD.OrderKey = O.OrderKey)
         JOIN dbo.Facility F WITH (NOLOCK)
         ON (O.Facility = F.Facility)
         WHERE PD.PickSlipNo = @cPickSlipNo
         -- SOS# 205340 (End)

         IF ISNULL(@cFilePath, '') = ''
         BEGIN
            SET @nErrNo = 70887
            SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --70887 No FilePath
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_2_Fail
         END

         IF ISNULL(@cGS1TemplatePath, '') = ''
         BEGIN
            SET @nErrNo = 70888
            SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --70888 No Template
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_2_Fail
         END
      END

      DECLARE @cGS1BatchNo NVARCHAR(10) 
      EXEC isp_GetGS1BatchNo 5,  @cGS1BatchNo OUTPUT 
      SET    @cErrMsg = @cGS1BatchNo

      -- Print GS1 label
      SET @b_success = 0  
      EXEC dbo.isp_PrintGS1Label
         @c_PrinterID = @cPrinterID,
         @c_BtwPath   = @cGS1TemplatePath,
         @b_Success   = @b_success OUTPUT,
         @n_Err       = @nErrNo    OUTPUT,
         @c_Errmsg    = @cErrMsg   OUTPUT, 
         @c_LabelNo   = @cLabelNo
      IF @nErrNo <> 0 OR @b_success = 0
         GOTO Step_2_Fail

      SET @cCartonDisp = CAST((@nCartonNo + 1) AS NVARCHAR(5)) + ' / ' + CAST(@nTTLCarton AS NVARCHAR(5))
      --prepare next screen variable
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @cCartonDisp
      SET @cOutField03 = ''

      SET @nScn = @nScn
      SET @nStep = @nStep

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
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


      SET @cOrderKey      = ''
      SET @cConsigneekey  = ''
      SET @cSKU           = ''

      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = ''


      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   GOTO Quit


   Step_2_Fail:
   BEGIN

      SET @cOutField01 = @cPickSlipNo
      SET @cOutField03 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 3. screen = 2522
 PSNO    (Field01)
 OPTION (Field02, Input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
       -- Screen mapping
      SET @cOption = @cInField02

      IF ISNULL(RTRIM(@cOption),'') = ''
      BEGIN
         SET @nErrNo = 70882
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option Req
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_3_Fail
      END

      --(Kc01) - requested to remove option 2
      IF ISNULL(RTRIM(@cOption),'') <> '1' --AND ISNULL(RTRIM(@cOption),'') <> '2'
      BEGIN
         SET @nErrNo = 70883
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_3_Fail
      END

      IF @cOption = '1' -- Abort Packing
      BEGIN
         --(Kc04) start
         IF EXISTS (SELECT 1 FROM dbo.PACKHEADER WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo AND Status = '9')
         BEGIN
            SET @nErrNo = 70896
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PSNO Packed
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_3_Fail
         END

         IF EXISTS (SELECT 1 FROM dbo.ORDERS ORDERS WITH (NOLOCK)
            JOIN dbo.PACKHEADER PACKHEADER WITH (NOLOCK) ON PACKHEADER.ORDERKEY = ORDERS.ORDERKEY
            WHERE PACKHEADER.PickSlipNo = @cPickSlipNo AND ORDERS.Status = '9')
         BEGIN
            SET @nErrNo = 70897
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ORDER SHIPPED
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_3_Fail
         END
         --(Kc04) end

         BEGIN TRAN

         --(Kc03) - start
         DELETE FROM dbo.PackInfo WITH (ROWLOCK)
         WHERE PickSlipNo = @cPickSlipNo

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 70895
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelPackIFail'
            GOTO Step_3_Fail
         END
         --(Kc03) - end

         DELETE FROM dbo.PackDetail WITH (ROWLOCK)
         WHERE PickSlipNo = @cPickSlipNo

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 70884
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelPackDFail'
            GOTO Step_3_Fail
         END

         DELETE FROM dbo.PackHeader WITH (ROWLOCK)
         WHERE PickSlipNo = @cPickSlipNo

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 70885
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelPackHFail'
            GOTO Step_3_Fail
         END

         DELETE FROM rdt.RDTPackLog WITH (ROWLOCK)
         WHERE PickSlipNo = @cPickSlipNo

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 70886
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelRDTLogFail'
            GOTO Step_3_Fail
         END

         COMMIT TRAN

          --prepare next screen variable
         SET @cOutField01 = @cPrinterID
         SET @cOutField02 = ''

         SET @nScn = 2520
         SET @nStep = 1

            -- initialise all variable
         SET @cCheckPickB4Pack = ''
         SET @nPickDetailQty  = 0
         SET @nPackQty        = 0
         SET @nCartonNo       = 0
         SET @nDispCartonNo   = 0
         SET @cSKU            = ''
         SET @fWeight         = 0
         SET @cSKU            = ''
         SET @cOrderkey       = ''
         SET @cRoute          = ''
         SET @cLoadkey        = ''
         SET @cPickSlipType   = ''
         SET @cLabelNo        = ''
         SET @cLabelLine      = ''
         SET @cOrderRefNo     = ''
         SET @cConsigneeKey   = ''
         SET @cOption         = ''
         SET @cGSILBLITF            = ''
         SET @cFilePath             = ''
         SET @cGS1TemplatePath      = ''
         SET @nMaxCartonNo          = 0
         SET @cPickSlipNo           = ''

      END

      --(Kc01) - requested to remove option 2
      /*
      IF @cOption = '2' -- Confirm Pack
      BEGIN

         EXEC [RDT].[rdtfnc_PackSummary_PackCofirm]
         @nMobile          ,
         @cPickSlipNo      ,
         @cStorerkey       ,
         @cPickSlipType    ,
         '2',  -- 1 = Full Pack , 2 = Short Pack
         @cLangCode        ,
         @cUserName        ,
         @nErrNo           OUTPUT,
         @cErrMsg          OUTPUT  -- screen limitation, 20 char max

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelRDTLogFail'
      GOTO Step_3_Fail
         END

         --prepare next screen variable
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = ''

         SET @nScn   = @nScn + 1
         SET @nStep  = @nStep + 1

      END
      */


   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nDispCartonNo = 0
      SELECT @nDispCartonNo = MAX(CartonNo) FROM RDT.RDTPACKLOG WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      AND Status = '0'

--      IF @nDispCartonNo = 0
--      BEGIN
--         SET @nDispCartonNo = 1
--      END

      --(Kc01)
      SET @cCartonDisp = CAST((@nDispCartonNo + 1) AS NVARCHAR(5)) + ' / ' + CAST(@nTTLCarton AS NVARCHAR(5))

      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = @cCartonDisp  --(Kc01)
      SET @cOutField03 = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOutField01 = @cPickSlipNo
      SET @cOutField02 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 4. screen = 2523
  PACK CONFIRM
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 OR @nInputKey = 0  -- ENTER / ESC
   BEGIN

      -- initialise all variable
      SET @cCheckPickB4Pack = ''
      SET @nPickDetailQty  = 0
      SET @nPackQty        = 0
      SET @nCartonNo       = 0
      SET @nDispCartonNo   = 0
      SET @cSKU            = ''
      SET @fWeight         = 0
      SET @cSKU            = ''
      SET @cOrderkey       = ''
      SET @cRoute          = ''
      SET @cLoadkey        = ''
      SET @cPickSlipType   = ''
      SET @cLabelNo        = ''
      SET @cLabelLine      = ''
      SET @cOrderRefNo     = ''
      SET @cConsigneeKey   = ''
      SET @cOption         = ''
      SET @cGSILBLITF            = ''
      SET @cFilePath             = ''
      SET @cGS1TemplatePath      = ''
      SET @nMaxCartonNo          = 0
      SET @cPickSlipNo           = ''

      --prepare next screen variable
      SET @cOutField01 = @cPrinterID
      SET @cOutField02 = ''

      SET @nScn = 2520
      SET @nStep = 1

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
       -- UserName      = @cUserName,

       V_Orderkey         = @cOrderKey,
       V_ConsigneeKey     = @cConsigneekey,
       V_SKU              = @cSKU,
       --V_SKUDescr         = @cSKUDescr,
       --V_UOM              = @cPackUOM03,
       V_String1          = @cPickSlipNo,
       V_String2          = @cPrinterID,

       --V_String3          = @nTTLCarton,
       --V_String4          = @nCartonNo,
       
       V_Integer1 = @nTTLCarton,
   
       V_Cartonno = @nCartonNo,

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