SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: LoadPlan FCP (Dynamic Pick)                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2007-10-16 1.0  FKLIM      Created                                   */
/* 2008-08-07 1.1  James      Remove checking on confirmed = 'L'        */
/*                            Now checking on Confirmed = 'Y',          */
/*                            DropID = 'L' for uncompleted LP task      */
/* 2008-09-18 1.2  Shong      Performance Tuning                        */
/* 2010-07-07 1.3  TLTING     Update Replenish edit date (tlting01)     */
/* 2016-09-30 1.4  Ung        Performance tuning                        */
/* 2018-11-02 1.5  TungGH     Performance                               */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_LoadPlan_FCP] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

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
   @cPrinter   NVARCHAR( 10),

   @nKeyCount  INT,
   @nError     INT,
   @i          INT,
   @b_success  INT,
   @n_err      INT,
   @c_errmsg   NVARCHAR( 250),

   @cLOC          NVARCHAR( 10),
   @cUCC          NVARCHAR( 20),
   @cConsigneeKey NVARCHAR( 15),
   @cC_Company    NVARCHAR( 20),
   @cOrderKey     NVARCHAR( 10),
   @cCartonNo     NVARCHAR( 5),

   @cSku                NVARCHAR( 20),
   @cUCCSKU             NVARCHAR( 20),
   @nQty                INT,
   @nUCCQty             INT,
   @cLottable01         NVARCHAR( 18),
   @cLottable02         NVARCHAR( 18),
   @cLottable03         NVARCHAR( 18),
   @dLottable04         DATETIME,
   @cUCCLoc             NVARCHAR( 10),
   @cUCCLOT             NVARCHAR( 10),
   @cID                 NVARCHAR( 18),
   @cPickDetailKey      NVARCHAR( 18),
   @cNewUCC             NVARCHAR( 20),
   @cStatus             NVARCHAR( 10),
   @cReplenishmentKey   NVARCHAR( 10),
   @cToLoc              NVARCHAR( 10),
   @nCartonNo           INT,
   @cPickSlipNo         NVARCHAR( 10),
   @cCartonGroup        NVARCHAR( 8),
   @cDataWindow         NVARCHAR( 50),
   @cTargetDB           NVARCHAR( 10),
   @cLoadKey            NVARCHAR( 10),
   @cLoadLoc            NVARCHAR( 10),
   @cLoadLot            NVARCHAR( 10),
   @nSUM_PDQty          INT,
   @nSUM_RPLQty         INT,
   @cUOM                NVARCHAR( 10),
   @cPackkey            NVARCHAR( 10),
   @cLabelNo            NVARCHAR( 10),
   @cReplenGroup        NVARCHAR( 10),
   @cScan               VARCHAR (5),
   @nCaseCnt            INT,
   @cLOT                NVARCHAR( 10),
   
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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60)

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
   @cPrinter   = Printer,

   @cLoadKey      = V_String1,
   @cLOC          = V_String2,
   @cUCC          = V_String3,
   @cConsigneeKey = V_String4,
   @cC_Company    = V_String5,
   @cOrderKey     = V_String6,
   @cCartonNo     = V_String7,
   @cReplenGroup  = V_String9,
   
   @cScan         = V_Integer1,
   
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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 980  -- UCC Replenishment From (Dynamic Pick)
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- LoadPlan FCP (Dynamic Pick)
   IF @nStep = 1 GOTO Step_1   -- Scn = 1760. LoadKey
   IF @nStep = 2 GOTO Step_2   -- Scn = 1761. LoadKey, From Loc
   IF @nStep = 3 GOTO Step_3   -- Scn = 1762. From Loc, UCC, Consignee, Company, OrderKey, CartonNo
END

--RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 980. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 1760
   SET @nStep = 1

   -- Initiate var
   SET @cLoadKey = ''
   SET @cScan = '0'

   -- Init screen
   SET @cOutField01 = '' -- Replen Group
   SET @cOutField02 = '' -- LoacKey

END
GOTO Quit

/********************************************************************************
Step 1. Scn = 1760. Replen Group
   LOADKEY      (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
      SET @cLoadKey = @cInField01

      -- Validate blank
      IF ISNULL(@cLoadKey, '') = ''
      BEGIN
         SET @nErrNo = 65401
         SET @cErrMsg = rdt.rdtgetmessage( 65401, @cLangCode,'DSP') --Need LoadKey
         GOTO Step_1_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.LOADPLAN WITH (NOLOCK)
         WHERE LOADKEY = @CLoadKey)
      BEGIN
        SET @nErrNo = 65402
        SET @cErrMsg = rdt.rdtgetmessage( 65402, @cLangCode,'DSP') --Bad LOADKEY
        GOTO Step_1_Fail
      END

      IF EXISTS (SELECT 1 FROM dbo.LOADPLAN WITH (NOLOCK)
         WHERE LOADKEY = @cLoadKey
            AND Status = '9')
      BEGIN
        SET @nErrNo = 65403
        SET @cErrMsg = rdt.rdtgetmessage( 65403, @cLangCode,'DSP') --LOADKEY closed
        GOTO Step_1_Fail
      END

      -- Get ReplenishmentGroup
      SELECT TOP 1 
           @cReplenGroup = ReplenishmentGroup
      FROM dbo.Replenishment WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LoadKey  = @cLoadKey
         AND ToLOC    = 'PICK'
         
      -- Prepare next screen var
      SET @cLOC = ''
      SET @cOutField01 = CASE WHEN ISNULL(@cLoadKey, '') <> ''THEN @cLoadKey ELSE '' END
      SET @cOutField02 = ''--LOC


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

   Step_1_Fail:
   BEGIN
      SET @cLoadKey = ''
      SET @cOutField01 = '' -- LoadKey
   END

END
GOTO Quit

/********************************************************************************
Step 2. Scn = 1761. Replen Group, LOC
   LOADKEY        (field01)
   FROM LOC       (filed02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      --screen mapping
      SET @cLOC = @cInField02

      IF @cLOC <> '' AND @cLOC IS NOT NULL
      BEGIN
         --validate LOC
         IF NOT EXISTS (SELECT 1
            FROM dbo.Loc WITH (NOLOCK)
            WHERE LOC = @cLOC)
         BEGIN
            SET @nErrNo = 65404
            SET @cErrMsg = rdt.rdtgetmessage( 65404, @cLangCode,'DSP') --Invalid LOC
            GOTO Step_2_Fail
         END

         --Validate if LOC in same facility
         IF NOT EXISTS (SELECT 1
            FROM dbo.Loc WITH (NOLOCK)
            WHERE Loc = @cLOC
               AND Facility = @cFacility)
         BEGIN
            SET @nErrNo = 65405
            SET @cErrMsg = rdt.rdtgetmessage( 65405, @cLangCode,'DSP') --Diff facility
            GOTO Step_2_Fail
         END
      END

      -- Prepare next screen var
      SET @cOutField01 = @cLOC
      SET @cUCC = ''
      SET @cOutField02 = '' --ucc
      SET @cTOLOC = ''
      SET @cOutField03 = '' --TOLOC
      SET @cPickSlipNo = ''
      SET @cOutField04 = '' --PKSLIPNO
      SET @cOrderKey = ''
      SET @cOutField05 = '' --OrderKey
      SET @cCartonNo = ''
      SET @cOutField06 = '' --CartonNo
      SET @cConsigneeKey = ''
      SET @cOutField07 = '' --consigneeKey
      SET @cC_Company = ''
      SET @cOutField08 = '' --C_Company

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cLoadKey = ''
      SET @cOutField01 = ''  -- LoadKey

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cLOC = '' -- LOC
      SET @cOutField01 = @cLoadKey
      SET @cOutField02 = ''
   END

END
GOTO Quit

/********************************************************************************
Step 3. Scn = 1762. From Loc, UCC, Consignee, Company, OrderKey, CartonNo
   FROM LOC       (field01)
   UCC            (field02, input)
   ConsigneeKey   (field03)
   C_Company      (field04)
   OrderKey       (field05)
   CartonNo       (field06)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      --screen mapping
      SET @cUCC = @cInField02

      IF @cUCC = '' OR @cUCC IS NULL
      BEGIN
         SET @nErrNo = 65406
         SET @cErrMsg = rdt.rdtgetmessage( 65406, @cLangCode,'DSP') --Need UCC
         GOTO Step_3_Fail
      END

      -- Get UCC Information
      SELECT 
         @cUCCSKU       = UCC.Sku,
         @nUCCQty       = UCC.Qty,
         @cLOT          = UCC.LOT,
         @cUCCLoc       = UCC.Loc,
         @cID           = UCC.ID
      FROM dbo.UCC UCC WITH (NOLOCK)
      JOIN dbo.Lotattribute LOT WITH (NOLOCK)
         ON UCC.Lot = LOT.Lot AND UCC.StorerKey = LOT.StorerKey
      WHERE UCC.UCCNo = @cUCC
        AND UCC.StorerKey = @cStorerKey

      -- Check if scanned UCC info exists in LP
      IF NOT EXISTS (SELECT TOP 1 1 
         FROM dbo.Replenishment RP WITH (NOLOCK)
         WHERE  RP.LOT     = @cLOT
            AND RP.FromLOC = @cUCCLoc
            AND RP.ID = @cID
            AND RP.StorerKey = @cStorerKey 
            AND RP.SKU = @cUCCSKU
            AND RP.LoadKey = @cLoadKey
            AND RP.Confirmed = 'Y' 
            AND RP.DropID = 'L'
            AND RP.QTY = @nUCCQty
            )
      BEGIN
         SET @nErrNo = 65416
         SET @cErrMsg = rdt.rdtgetmessage( 65416, @cLangCode,'DSP') --Invalid UCC
         GOTO Step_3_Fail  
      END
                    
      SELECT @cUCCSKU = '', @nUCCQTY = 0, @nCaseCnt = 0
      SELECT 
         @cUCCSKU = SKU,
         @nUCCQTY = QTY
      FROM dbo.UCC WITH (NOLOCK) 
      WHERE UCCNo = @cUCC
        AND StorerKey = @cStorerKey

      SELECT 
         @nCaseCnt = Pack.CaseCnt
      FROM dbo.SKU SKU WITH (NOLOCK)
      JOIN dbo.PACK PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey
      WHERE StorerKey = @cStorerKey
         AND SKU = @cUCCSKU

      IF @nUCCQTY <> @nCaseCnt
      BEGIN
         SET @nErrNo = 65413
         SET @cErrMsg = rdt.rdtgetmessage( 65413, @cLangCode,'DSP') --Qty<>CaseCnt
         GOTO Step_3_Fail
      END
      SELECT @cUCCSKU = '', @nUCCQTY = 0, @nCaseCnt = 0
      
      SET @nCount = 0
      IF @cLOC IS NOT NULL AND @cLOC <> ''
      BEGIN
         SELECT @nCount = COUNT(1)
         FROM dbo.Replenishment WITH (NOLOCK)
         WHERE  LoadKey = @cLoadKey
            AND FromLoc = @cLOC
            AND RefNo = @cUCC
            AND StorerKey = @cStorerKey
            AND Confirmed = 'Y'
            AND DropID = 'L'
      END
      ELSE
      BEGIN
         SELECT @nCount = COUNT(1)
         FROM dbo.Replenishment WITH (NOLOCK)
         WHERE  LoadKey = @cLoadKey
            AND RefNo = @cUCC
            AND StorerKey = @cStorerKey
            AND Confirmed = 'Y'
            AND DropID = 'L'
      END

      IF @nCount = 0
      BEGIN
         --check if storerConfig 'DynamicPickSwapUCC' turn on
         IF NOT EXISTS(SELECT 1
            FROM rdt.StorerConfig WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND ConfigKey = 'DynamicPickSwapUCC'
               AND SValue = '1')
         BEGIN
            SET @nErrNo = 65407
            SET @cErrMsg = rdt.rdtgetmessage( 65407, @cLangCode,'DSP') --UCCNotOnReplen
            GOTO Step_3_Fail
         END
         ELSE --if turn on, do the following
         BEGIN
            EXEC rdt.rdt_ReplenishFromSwapUCC
               @nFunc       = @nFunc,
               @nMobile     = @nMobile,
               @cLangCode   = @cLangCode,
               @nErrNo      = @nErrNo OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
               @cUCC        = @cUCC,
               @cStorerKey  = @cStorerKey,
               @cReplenGroup = @cReplenGroup,
               @cNewUCC     = @cNewUCC OUTPUT

            IF @nErrNo <> 0
            BEGIN
               GOTO Step_3_Fail
            END
         END
      END   --End for IF @nCount = 0

      --get ReplenishmentKey
      SELECT @cReplenishmentKey = ''
      IF @cLOC IS NOT NULL AND @cLOC <> ''
      BEGIN
         SELECT @cReplenishmentKey = ReplenishmentKey
         FROM dbo.Replenishment WITH (NOLOCK)
         WHERE LoadKey = @cLoadKey
            AND FromLoc = @cLOC
            AND RefNo = @cUCC 
            AND StorerKey = @cStorerKey
            AND Confirmed = 'Y'
            AND DropID = 'L'
      END
      ELSE
      BEGIN
         SELECT @cReplenishmentKey = ReplenishmentKey
         FROM dbo.Replenishment WITH (NOLOCK)
         WHERE LoadKey = @cLoadKey
            AND RefNo = @cUCC 
            AND StorerKey = @cStorerKey
            AND Confirmed = 'Y'
            AND DropID = 'L'
      END

      IF ISNULL(@cReplenishmentKey , '') = ''
      BEGIN
         SET @nErrNo = 65414
         SET @cErrMsg = rdt.rdtgetmessage( 65414, @cLangCode,'DSP') --NoReplenKey
         GOTO Step_3_Fail 
      END
            
      BEGIN TRAN

      -- Confirm Replenishment
      Update dbo.Replenishment WITH (ROWLOCK) SET
         DropID = 'Y'
         ,ArchiveCop = NULL
         ,EditDate   = GetDate()    -- tlting01
         ,EditWho    = SUser_SName()         
      WHERE ReplenishmentKey = @cReplenishmentKey
         
      IF @@ERROR <> 0 
      BEGIN
         SET @nErrNo = 65415
         SET @cErrMsg = rdt.rdtgetmessage( 65415, @cLangCode,'DSP') --UpdRepConffail
         ROLLBACK TRAN
         GOTO Step_3_Fail 
      END

      -- Update UCC's Status
      UPDATE dbo.UCC SET
         Status = '4',
         EditDate = GETDATE(),
         EditWho = sUSER_sNAME()
      WHERE StorerKey = @cStorerkey
         AND UCCNo = @cUCC

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 65412
         SET @cErrMsg = rdt.rdtgetmessage( 65412, @cLangCode,'DSP') --UPD UCC Fail
         ROLLBACK TRAN
         GOTO Step_3_Fail
      END

      COMMIT TRAN

      --get pickSlipNo, CartonNo, OrderKey, C_Company, ConsigneeKey
      SELECT @cPickSlipNo = '', @nCartonNo = 0, @cOrderKey = '', @cC_Company = '', @cConsigneeKey = ''

      SELECT TOP 1
         @cOrderKey   = PD.OrderKey,
         @cPickSlipNo = PD.PickSlipNo
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.StorerKey = @cStorerKey
         AND EXISTS (SELECT 1 FROM dbo.Orders O WITH (NOLOCK)
            WHERE PD.ORDERKEY = O.ORDERKEY AND O.LoadKey = @cLoadKey)

      SELECT @cConsigneeKey = ConsigneeKey,
             @cC_Company    = C_Company
      FROM dbo.Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey
         AND StorerKey = @cStorerKey

      -- Add one to counter
      SET @cScan = @cScan + 1

      --prepare next screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = '' --ucc
      SET @cOutField03 = 'PICK' --TOLOC
      SET @cOutField04 = @cPickSlipNo --PKSLIPNO
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = SUBSTRING(@cConsigneeKey, 1, 15) --consigneeKey
      SET @cOutField08 = SUBSTRING(@cC_Company,1, 20) --C_Company
      SET @cOutField09 = @cScan
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cLoadKey
      SET @cOutField02 = ''
      SET @cLOC = ''

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cUCC = ''
      SET @cOutField02 = '' --UCC
      SET @cOutField03 = '' --TOLOC
      SET @cOutField04 = '' --PKSLIPNO
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = '' --consigneeKey
      SET @cOutField08 = '' --C_Company      
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
      Printer   = @cPrinter,

      V_String1 = @cLoadKey,
      V_String2 = @cLOC,
      V_String3 = @cUCC,
      V_String4 = @cConsigneeKey,
      V_String5 = @cC_Company,
      V_String6 = @cOrderKey,
      V_String7 = @cCartonNo,
      V_String9 = @cReplenGroup,
      
      V_Integer1 = @cScan,
      
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
      I_Field15 = @cInField15,  O_Field15 = @cOutField15

   WHERE Mobile = @nMobile
END


GO