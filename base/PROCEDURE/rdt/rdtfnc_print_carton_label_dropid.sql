SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: RDT Generate GS1 Label By DropID 216119                           */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 20-05-2011 1.0  ChewKP     Created                                         */
/* 11-08-2011 1.1  James      Skip no. of carton screen (james01)             */
/* 06-01-2012 1.2  Ung        SOS231812 Standarize print GS1 to use Exceed's  */
/*                            Clean up source                                 */
/* 30-09-2016 1.3  Ung        Performance tuning                              */
/* 19-10-2018 1.4  TungGH     Performance                                     */  
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_Print_Carton_Label_DropID] (
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
   @b_success        INT,
   @cOption          NVARCHAR( 1), 
   @cOrderKey        NVARCHAR( 10),
   @cBuyerPO         NVARCHAR( 20),
   @cLabelNo         NVARCHAR( 20),
   @nPackDQty        INT,
   @nPickDQty        INT,
   @nPackDetailQTY   INT,
   @nPickDetailQTY   INT,
   @cDischargePlace  NVARCHAR( 20),
   @cErrMsg1         NVARCHAR(20),
   @cErrMsg2         NVARCHAR(20),
   @nTotalCtns       INT,
   @cAutoPackConfirm NVARCHAR( 1),
   @cPickSlipNo      NVARCHAR(20),
   @nCntPrinted      INT,
   @nCntTotal        INT,
   @cFilePath        NVARCHAR( 30),
   @cGS1TemplatePath NVARCHAR( 120)
   
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
   @cUserName  NVARCHAR( 18),

   @cPrinter            NVARCHAR( 20),
   @cDropID             NVARCHAR( 18),
   @cTemplateID         NVARCHAR( 20),
   @cGenTemplateID      NVARCHAR( 20),

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
   @cUserName  = UserName,

   @cOrderKey  = V_OrderKey,

   @cDropID        = V_String1,
   @cPrinter       = V_String2,
   @cTemplateID    = V_String3,
   @cGenTemplateID = V_String4,

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

   @cFieldAttr01 =  FieldAttr01,    @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15
FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 913  -- Print Carton Label
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Print Carton Label
   IF @nStep = 1 GOTO Step_1   -- Scn = 2820. PRINTER ID, DROP ID
   IF @nStep = 2 GOTO Step_2   -- Scn = 2822. OPTION
END
RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1752. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Initiate var
   SET @cPrinter = ''
   SET @cLabelNo = ''
   SET @cGenTemplateID = ''
   SET @cTemplateID = ''
   SET @cDropID = ''

   -- Init screen
   SET @cOutField01 = '' -- Printer
   SET @cOutField02 = '' -- DropID
   SET @cOutField03 = '' -- (james01)
   SET @cOutField04 = '' -- (james01)
   SET @cOutField05 = '' -- (james01)
   SET @cOutField06 = '' -- (james01)

   -- Set the entry point
   SET @nScn = 2820
   SET @nStep = 1

END
GOTO Quit

/********************************************************************************
Step 1. Scn = 2820.
   PRINTER ID (field01, input)
   DROPID     (field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      SET @cLabelNo = ''

      --screen mapping
      SET @cPrinter = @cInField01
      SET @cDropID = @cInField02

      IF ISNULL(@cPrinter, '') = ''
      BEGIN
         SET @nErrNo = 73141
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PrinterID Req'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      IF ISNULL(@cDropID, '') = ''
      BEGIN
         SET @nErrNo = 73142
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropID Req'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_Fail
      END


      IF NOT EXISTS ( SELECT 1 FROM dbo.PACKDETAIL PD WITH (NOLOCK)
                      WHERE PD.DropID = @cDropID
                      AND Storerkey = @cStorerkey )
      BEGIN
         SET @nErrNo = 73143
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid DropID'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_Fail
      END

      IF EXISTS ( SELECT 1 FROM dbo.DropID
                  WHERE DropID = @cDropID
                  AND LabelPrinted = 'Y')
      BEGIN
         SET @nErrNo = 73153
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Label Printed'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_Fail
      END

      SELECT @nPickDetailQTY = SUM(QTY)
      FROM dbo.PICKDETAIL WITH (NOLOCK)
      WHERE DropID = @cDropID
      AND Storerkey = @cStorerkey

      SELECT @nPackDetailQTY = SUM(QTY)
      FROM dbo.PACKDETAIL WITH (NOLOCK)
      WHERE DropID = @cDropID
      AND Storerkey = @cStorerkey

      IF @nPackDetailQTY > @nPickDetailQTY
      BEGIN
         SET @nErrNo = 73144
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Over Packed'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_Fail
      END

      -- Confirm PackIng With ConfigKey
      SET @cAutoPackConfirm = ''
      SET @cAutoPackConfirm = rdt.RDTGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)

      DECLARE @cGSILBLITF NVARCHAR( 1)
      IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK)
      WHERE Storerkey = @cStorerKey
      AND Configkey = 'GSILBLITF'
      AND SValue = '1')
         SET @cGSILBLITF = '1'
      ELSE
         SET @cGSILBLITF = '0'

      SET @cGS1TemplatePath = ''
      SELECT @cGS1TemplatePath = NSQLDescrip
      FROM RDT.NSQLCONFIG WITH (NOLOCK)
      WHERE ConfigKey = 'GS1TemplatePath'

      -- GS1 Label validation start
      IF @cGSILBLITF = '1'
      BEGIN
         SET @cFilePath = ''
         SELECT @cFilePath = ISNULL(RTRIM(UserDefine20 ), '')
         FROM dbo.Facility WITH (NOLOCK)
         WHERE Facility = @cFacility

         IF ISNULL(@cFilePath, '') = ''
         BEGIN
            SET @nErrNo = 73146
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No FilePath'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_1_Fail
         END

         IF ISNULL(@cGS1TemplatePath, '') = ''
         BEGIN
            SET @nErrNo = 73147
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No Template'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_1_Fail
         END
      END
      -- GSI Label validation end

      DECLARE @cGS1BatchNo NVARCHAR(10) 
      EXEC isp_GetGS1BatchNo 5,  @cGS1BatchNo OUTPUT 

      DECLARE CUR_ORDER CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT DISTINCT O.Orderkey, O.DischargePlace, O.BuyerPO, PackD.LabelNo, PH.PickSlipNo FROM dbo.PackDetail PackD WITH (NOLOCK)
      INNER JOIN PackHeader PH WITH (NOLOCK) ON ( PH.PickSlipNo = PackD.PickSlipNo)
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON ( O.ORDERKEY = PH.ORDERKEY  )
      WHERE PackD.DropID = @cDropID
      AND PackD.Storerkey = @cStorerkey
      ORDER BY O.Orderkey

      OPEN CUR_ORDER
      FETCH NEXT FROM CUR_ORDER INTO @cOrderKey , @cDischargePlace, @cBuyerPO, @cLabelNo, @cPickSlipNo
      WHILE @@FETCH_STATUS <> -1
      BEGIN
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
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1

            GOTO QUIT
         END

         -- Print GS1 label
         SET @cErrMsg = @cGS1BatchNo
         SET @b_success = 0  
         EXEC dbo.isp_PrintGS1Label
            @c_PrinterID = @cPrinter,
            @c_BtwPath   = @cGS1TemplatePath,
            @b_Success   = @b_success OUTPUT,
            @n_Err       = @nErrNo    OUTPUT,
            @c_Errmsg    = @cErrMsg   OUTPUT, 
            @c_LabelNo   = @cLabelNo
         IF @nErrNo <> 0 OR @b_success = 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_1_Fail
         END

         IF @cAutoPackConfirm = '1'
         BEGIN
            SELECT @nCntTotal = SUM(PD.QTY) FROM dbo.PICKDETAIL PD WITH (NOLOCK)
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON ( O.ORDERKEY = PD.ORDERKEY )
            INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( O.ORDERKEY = OD.ORDERKEY AND
            OD.OrderLineNumber = PD.OrderLinenUmber)
            WHERE PD.StorerKey = @cStorerKey
            AND O.ORDERKEY = @cOrderKey
            AND PD.Status = '5'

            SELECT @nCntPrinted = SUM(PCD.QTY) FROM dbo.PACKDETAIL PCD WITH (NOLOCK)
            INNER JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON ( PH.PickSlipNo = PCD.PickSlipNo )
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON ( O.ORDERKEY = PH.ORDERKEY )
            WHERE O.StorerKey = @cStorerKey
            AND O.ORDERKEY = @cOrderKey

            IF @nCntTotal = @nCntPrinted
            BEGIN
               BEGIN TRAN

               UPDATE dbo.PACKHEADER WITH (ROWLOCK) SET
                  STATUS = '9'
               ,  TTLCNTS = @nCntPrinted
               WHERE PICKSLIPNO = @cPickslipNo
               AND ORDERKEY = @cOrderKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 73151
                  SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PH FAILED'

                  SET @cOutField01 = @cPrinter
                  SET @cOutField02 = ''
                  SET @cPickSlipNo = ''
                  EXEC rdt.rdtSetFocusField @nMobile, 2
                  ROLLBACK TRAN
                  GOTO Step_1_Fail
               END
               ELSE
               BEGIN
                  COMMIT TRAN
               END
            END
         END

         FETCH NEXT FROM CUR_ORDER INTO @cOrderKey , @cDischargePlace, @cBuyerPO, @cLabelNo, @cPickSlipNo
      END
      CLOSE CUR_ORDER
      DEALLOCATE CUR_ORDER

      BEGIN TRAN

      UPDATE dbo.DropID
      SET LabelPrinted = 'Y' ,Status = '5'
      WHERE DropID = @cDropID

      IF @@Error <> 0
      BEGIN
         SET @nErrNo = 73152
         SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD DropID FAILED'

         SET @cOutField01 = @cPrinter
         SET @cOutField02 = ''
         SET @cPickSlipNo = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         ROLLBACK TRAN
         GOTO Step_1_Fail
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END

      SET @nTotalCtns = 0
      SELECT @nTotalCtns = Count(Distinct CartonNo)
      FROM dbo.PACKDETAIL WITH (NOLOCK)
      WHERE DropID = @cDropID
      AND Storerkey = @cStorerkey

      -- 1 Drop ID = 1 Carton = 1 Label (james01)
      SET @cLabelNo = ''
      SELECT TOP 1 @cLabelNo = LabelNo
      FROM dbo.PACKDETAIL WITH (NOLOCK)
      WHERE DropID = @cDropID
      AND Storerkey = @cStorerkey

       -- (james01)
      SET @cOutField01 = @cPrinter
      SET @cOutField02 = ''
      SET @cOutField03 = 'UCC#:'
      SET @cOutField04 = @cLabelNo
      SET @cOutField05 = '# OF CTN PRINT: ' + CAST(@nTotalCtns AS NVARCHAR( 5))
      SET @cOutField06 = @cDropID

      EXEC rdt.rdtSetFocusField @nMobile, 2

      SET @cDropID = ''
      SET @cGenTemplateID = ''
      SET @cTemplateID = ''
   END -- input = 1

   IF @nInputKey = 0
   BEGIN
      --go to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
   END
   GOTO QUIT

   Step_1_Fail:
   BEGIN
      SET @cDropID = ''
      SET @cPrinter = ''
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1
   END

END
GOTO Quit

/********************************************************************************
Step 2. Scn = 2821.
   OPTION     (field01, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 73148
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_2_Fail
      END

      -- If option = 1, template id will be defaulted to 'Generic.btw'
      IF @cOption = '1'
      BEGIN
         SET @cGenTemplateID = 'Generic.btw'

         -- Prepare next screen var
         SET @cOutField01 = @cPrinter
         SET @cOutField02 = @cDropID
         SET @cOutField03 = ''      -- (james01)
         SET @cOutField04 = ''      -- (james01)
         SET @cOutField05 = ''      -- (james01)
         SET @cOutField06 = ''      -- (james01)

         -- Go to prev screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END

      -- If option = 2, prompt error and go back to screen 1
      IF @cOption = '2'
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '73149 Template ID'
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
         SET @cOutField03 = ''      -- (james01)
         SET @cOutField04 = ''      -- (james01)
         SET @cOutField05 = ''      -- (james01)
         SET @cOutField06 = ''      -- (james01)

         EXEC rdt.rdtSetFocusField @nMobile, 2

         -- Go to prev screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
        -- GOTO Quit
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cPrinter
      SET @cOutField02 = @cDropID
      SET @cOutField03 = ''      -- (james01)
      SET @cOutField04 = ''      -- (james01)
      SET @cOutField05 = ''      -- (james01)
      SET @cOutField06 = ''      -- (james01)

      EXEC rdt.rdtSetFocusField @nMobile, 2

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO QUIT

   Step_2_Fail:
   BEGIN
      SET @cOption = ''

      -- Reset this screen var
      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:

BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      -- UserName  = @cUserName,
      InputKey  = @nInputKey,

      V_OrderKey = @cOrderKey,

      V_String1 = @cDropID,
      V_String2 = @cPrinter,
      V_String3 = @cTemplateID,
      V_String4 = @cGenTemplateID,

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