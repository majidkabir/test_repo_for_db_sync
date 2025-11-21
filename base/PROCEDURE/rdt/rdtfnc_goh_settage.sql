SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/
/* Store procedure: rdtfnc_GOH_Settage                                       */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: RDT GOH Settage - SOS#133219                                     */
/*          Related Module: RDT GOH Picking                                  */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2009-05-13 1.0  Vicky    Created                                          */
/* 2016-09-30 1.1  Ung      Performance tuning                               */
/*****************************************************************************/
CREATE PROC [RDT].[rdtfnc_GOH_Settage](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF
	 SET CONCAT_NULL_YIELDS_NULL OFF
-- Misc variable
DECLARE
   @b_success           INT,
   @nError              INT,
   @n_err               INT,     
   @c_errmsg            NVARCHAR( 250)
        
-- Define a variable
DECLARE  
   @nFunc               INT,
   @nScn                INT,
   @nCurScn             INT,  -- Current screen variable
   @nPrevScn            INT,  -- Previous screen variable
   @nStep               INT,
   @nCurStep            INT,
   @nPrevStep           INT,
   @cLangCode           NVARCHAR( 3),
   @nMenu               INT,
   @nInputKey           NVARCHAR( 3),
   @cPrinter            NVARCHAR(10),
   @cUserName           NVARCHAR(18),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR( 5),
   @cPUOM               NVARCHAR( 1),

   @cPickToID           NVARCHAR(18),
   @cSKU                NVARCHAR(20),
   @cDescr              NVARCHAR(20),
   @cQty                NVARCHAR( 5),
   @cPackUOM3           NVARCHAR( 5),
   @cURNNo1             NVARCHAR(20),
   @cURNNo2             NVARCHAR(20),
   @cScanURNNo1         NVARCHAR(20),
   @cScanURNNo2         NVARCHAR(20),
   @cOption             NVARCHAR( 1),
   @cTotalQtyCnt        NVARCHAR( 5),
   @cQtyCnt             NVARCHAR( 5),
   @cDefaultOption      NVARCHAR( 1),
   @cDefaultPackQty     NVARCHAR( 5),
   @cDataWindow         NVARCHAR(50), 
   @cTargetDB           NVARCHAR(10), 
   @cSHOWSHTPICKRSN     NVARCHAR( 1),
   @cAutoPackConfirm    NVARCHAR( 1),
   @cAutoScanInPS       NVARCHAR( 1),
   @cAutoScanOutPS      NVARCHAR( 1),
   @cReasonCode         NVARCHAR(10),
   @cPickDetailKey      NVARCHAR(10),
   @cOrderKey           NVARCHAR(10),
   @cLoadKey            NVARCHAR(10),
   @cPickUsername       NVARCHAR(18),
   @cPickSlipNo         NVARCHAR(10),
   @cCfm_PSNo           NVARCHAR(10),

   @cWaveKey            NVARCHAR(10),
   @cLOC                NVARCHAR(10),
   @cID                 NVARCHAR(18),

   -- Lottables
   @cLottable01         NVARCHAR(18), 
   @cLottable02         NVARCHAR(18), 
   @cLottable03         NVARCHAR(18),  
   @dLottable04         DATETIME, 
   @dLottable05         DATETIME,

   @cConsigneeKey       NVARCHAR(15),
   @cExternOrderKey     NVARCHAR(30),
   @cItemClass          NVARCHAR(10),
   @cBUSR5              NVARCHAR(30),
   @cBUSR3              NVARCHAR(30),
   @cInterModalVehicle  NVARCHAR(30),
   @cURNPackNo          NVARCHAR( 6),
   @cKeyname            NVARCHAR(30),
   @cModuleName         NVARCHAR(45),
   @cPickSlipType       NVARCHAR(10),
   @cLabelLine          NVARCHAR( 5),
   @nCartonNo           INT,

   @cPD_Key             NVARCHAR(10),
   @cPD_SKU             NVARCHAR(10),
   @nPD_Qty             INT,
   @nPD_RemainQty       INT,

   @nSKUCnt             INT,
   @nOriginalQty        INT,
   @nRemainQty          INT,
   @nFinalQty           INT,
   @nQtyPacked          INT,
   @nQtyAllocated       INT,
   @nQty                INT,

   @cErrMsg1            NVARCHAR(20),
   @cErrMsg2            NVARCHAR(20),
   @cErrMsg3            NVARCHAR(20),
   @cErrMsg4            NVARCHAR(20),

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

   @cPackUOM3        = V_UOM,
   @cQty             = V_QTY,
   @cSKU             = V_SKU,
   @cDescr           = V_SKUDescr,
   @cOrderKey        = V_OrderKey,
   @cLoadKey         = V_LoadKey,

   @cPickToID        = V_String1,
   @cOption          = V_String2,     
   @cTotalQtyCnt     = V_String3,
   @cQtyCnt          = V_String4,
   @cURNNo1          = V_String5,
   @cURNNo2          = V_String6,
   
   @cDefaultOption   = V_String7,
   @cDefaultPackQty  = V_String8,
   @cAutoScanOutPS   = V_String9,
   @cAutoPackConfirm = V_String10,
   @cSHOWSHTPICKRSN  = V_String11,

   @nCurScn          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String12,  5), 0) = 1 THEN LEFT( V_String12,  5) ELSE 0 END,
   @nCurStep         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String13,  5), 0) = 1 THEN LEFT( V_String13,  5) ELSE 0 END,


   @nPrevScn         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String14,  5), 0) = 1 THEN LEFT( V_String14,  5) ELSE 0 END,
   @nPrevStep        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String15,  5), 0) = 1 THEN LEFT( V_String15,  5) ELSE 0 END,

   @cURNPackNo       = V_String16,
   @cPickSlipType    = V_String17,
   @cPickSlipNo      = V_String18,

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
IF @nFunc = 1624
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1624
   IF @nStep = 1 GOTO Step_1   -- Scn = 1980   Pick TOID
   IF @nStep = 2 GOTO Step_2   -- Scn = 1981   SKU
   IF @nStep = 3 GOTO Step_3   -- Scn = 1982   Print Label
   IF @nStep = 4 GOTO Step_4   -- Scn = 1983   URN No
   IF @nStep = 5 GOTO Step_5   -- Scn = 1984   Msg
   IF @nStep = 6 GOTO Step_6   -- Scn = 1967   RSN CODE
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1624)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 1980
   SET @nStep = 1

   SET @cDefaultOption = rdt.RDTGetConfig( @nFunc, 'DefaultOption', @cStorerKey)
   SET @cDefaultPackQty = rdt.RDTGetConfig( @nFunc, 'DefaultPackQty', @cStorerKey)

   SET @cAutoScanOutPS = rdt.RDTGetConfig( @nFunc, 'AutoScanOutPS', @cStorerKey)
   SET @cAutoPackConfirm = rdt.RDTGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)
   SET @cSHOWSHTPICKRSN = rdt.RDTGetConfig( @nFunc, 'SHOWSHTPICKRSN', @cStorerKey)
   
   -- initialise all variable
   SET @cPickToID = ''
   SET @cQtyCnt = 0
   SET @cTotalQtyCnt = 0
   SET @cQty = 0
   SET @nPrevStep = 0
   SET @nPrevScn = 0


   -- Prep next screen var   
   SET @cOutField01 = ''  
END
GOTO Quit

/********************************************************************************
Step 1. screen = 1980
   Pick TOID (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPickToID = @cInField01

      --When ID is blank
      IF @cPickToID = ''
      BEGIN
         SET @nErrNo = 66601
         SET @cErrMsg = rdt.rdtgetmessage( 66601, @cLangCode, 'DSP') --Pick ToID req
         GOTO Step_1_Fail  
      END 

      -- Check if ID exists
      IF NOT EXISTS ( SELECT 1 
         FROM dbo.PICKDETAIL WITH (NOLOCK)
         WHERE DropID = @cPickToID
         AND   Storerkey = @cStorerKey)
      BEGIN
         SET @nErrNo = 66602
         SET @cErrMsg = rdt.rdtgetmessage( 66602, @cLangCode, 'DSP') --Invalid ID
         EXEC rdt.rdtSetFocusField @nMobile, 1 
         GOTO Step_1_Fail    
      END

      -- Check if ID has been picked
      IF EXISTS ( SELECT 1 
         FROM dbo.PICKDETAIL WITH (NOLOCK)
         WHERE DropID = @cPickToID
         AND   Storerkey = @cStorerKey
         AND   Status < '5')
      BEGIN
         SET @nErrNo = 66603
         SET @cErrMsg = rdt.rdtgetmessage( 66603, @cLangCode, 'DSP') --Pick not done
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail    
      END

      SELECT TOP 1 @cPickUsername = RTRIM(AddWho)
      FROM RDT.RdtGOHSettagelog WITH (NOLOCK)
      WHERE DropID = @cPickToID
      AND   Storerkey = @cStorerKey

      -- Check if ID being process by others
      IF (@cPickUsername <> @cUserName) AND ISNULL(@cPickUsername, '') <> ''
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '66604 ID'
         SET @cErrMsg2 = 'is being used'
         SET @cErrMsg3 = 'by ' + @cPickUsername
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2, @cErrMsg3
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
         END
         GOTO Step_1_Fail    
      END  

     SELECT TOP 1 @cOrderkey = Orderkey
     FROM dbo.PICKDETAIL WITH (NOLOCK)
     WHERE DropID = @cPickToID
     AND   Storerkey = @cStorerKey

     SELECT TOP 1 @cLoadkey = LoadKey
     FROM dbo.ORDERS WITH (NOLOCK)
     WHERE Orderkey = @cOrderkey
     AND   Storerkey = @cStorerKey

     SELECT @cPickSlipNo = ISNULL(PickHeaderKey, '')
     FROM dbo.PickHeader WITH (NOLOCK)
     WHERE Orderkey = @cOrderkey

     SET @cPickSlipType = 'SINGLE'

     IF @cPickSlipNo = ''
     BEGIN
        SELECT @cPickSlipNo = ISNULL(PickHeaderKey, '')
        FROM dbo.PickHeader WITH (NOLOCK)
        WHERE ExternOrderkey = @cLoadkey
        SET @cPickSlipType = 'CONSO'
     END
   
      -- To be Processed
      IF EXISTS (SELECT 1 FROM RDT.RdtGOHSettagelog WITH (NOLOCK)
                     WHERE LoadKey = @cLoadKey
                     AND   DropID = @cPickToID
                     AND   Status = '1'
                     AND   AddWho = '')
      BEGIN
          UPDATE RDT.RdtGOHSettagelog WITH (ROWLOCK)
             SET AddWho = @cUserName,
                 AddDate = GETDATE(),
                 EditWho = @cUserName,
                 EditDate = GETDATE()
            WHERE LoadKey = @cLoadKey
            AND   DropID = @cPickToID
            AND   Status = '1'
            AND   AddWho = ''                         
      END
      ELSE
      IF NOT EXISTS (SELECT 1 FROM RDT.RdtGOHSettagelog WITH (NOLOCK)
                     WHERE LoadKey = @cLoadKey
                     AND   DropID = @cPickToID
                     AND   AddWho = @cUserName
                     AND   Status = '1')
      BEGIN
          BEGIN TRAN
    
                INSERT INTO RDT.RdtGOHSettagelog
                (Storerkey, OrderKey, LoadKey, PickDetailKey, DropID, SKU, QTY, QtyScan, RemainQty, Status, AddWho, AddDate)
                SELECT Storerkey, Orderkey, @cLoadKey, PickDetailKey, DropID, SKU, QTY, 0, QTY, '1', @cUserName, GETDATE()          
                FROM dbo.PICKDETAIL WITH (NOLOCK)
                WHERE DropID = @cPickToID
                AND   Storerkey = @cStorerKey

           IF @@ERROR <> 0
           BEGIN
               SET @nErrNo = 66605
               SET @cErrMsg = rdt.rdtgetmessage( 66605, @cLangCode, 'DSP') --'LockInfoFail'
               ROLLBACK TRAN
               GOTO Step_1_Fail
            END

            COMMIT TRAN
      END

      SELECT @cTotalQtyCnt = CAST(SUM(QTY) AS CHAR)
      FROM  RDT.RdtGOHSettagelog WITH (NOLOCK)
      WHERE DropID = @cPickToID
      AND   Storerkey = @cStorerKey
      AND   AddWho = @cUserName
      GROUP BY DropID

      SELECT @cQtyCnt = CAST(SUM(QTY) - SUM(RemainQty) AS CHAR)
      FROM  RDT.RdtGOHSettagelog WITH (NOLOCK)
      WHERE DropID = @cPickToID
      AND   Storerkey = @cStorerKey
      AND   AddWho = @cUserName
      GROUP BY DropID

      SELECT TOP 1 @cSKU = SKU
      FROM  RDT.RdtGOHSettagelog WITH (NOLOCK)
      WHERE DropID = @cPickToID
      AND   Storerkey = @cStorerKey
      AND   AddWho = @cUserName
      AND   Status = '1'
      ORDER BY PickDetailKey

     SELECT @cPackUOM3 = P.PACKUOM3, 
            @cDescr = SKU.Descr
     FROM dbo.SKU SKU WITH (NOLOCK) 
     JOIN dbo.PACK P WITH (NOLOCK) ON (SKU.PackKey = P.PackKey)
     WHERE SKU.StorerKey = @cStorerKey  
     AND SKU.SKU = @cSKU  
            
      --prepare next screen variable
      SET @cOutField01 = ''--SUBSTRING(@cSKU, 1, 18)
      SET @cOutField02 = '' --SUBSTRING(@cDescr, 1, 18)
      SET @cOutField03 = @cDefaultPackQty
      SET @cOutField04 = @cPackUOM3
      SET @cOutField05 = ''
      SET @cOutField06 = RTRIM(@cQtyCnt) + '/' + RTRIM(@cTotalQtyCnt)
                        
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''

      SET @cQtyCnt = 0
      SET @cTotalQtyCnt = 0
      SET @nPrevStep = 0
      SET @nPrevScn = 0
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cOutField01 = ''
    END

END
GOTO Quit

/********************************************************************************
Step 2. (screen = 1981) SKU
   SKU: (Field01 input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField05
      
      IF ISNULL(@cSKU, '') = ''  
      BEGIN  
         SET @nErrNo = 0
         SET @cErrMsg1 = '66606 SKU/UPC'
         SET @cErrMsg2 = 'Required'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
         END  
         GOTO Step_2_Fail  
      END  
  
      EXEC [RDT].[rdt_GETSKUCNT]    
         @cStorerKey  = @cStorerKey,    
         @cSKU        = @cSKU,
         @nSKUCnt     = @nSKUCnt       OUTPUT,
         @bSuccess    = @b_Success     OUTPUT,
         @nErr        = @n_Err         OUTPUT,
         @cErrMsg     = @c_ErrMsg      OUTPUT
          
      -- Validate SKU/UPC    
      IF @nSKUCnt = 0    
      BEGIN    
         SET @nErrNo = 0
         SET @cErrMsg1 = '66607 '
         SET @cErrMsg2 = 'Invalid SKU'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
         END  
         GOTO Step_2_Fail  
      END    
    
      -- Validate barcode return multiple SKU    
      IF @nSKUCnt > 1    
      BEGIN    
         SET @nErrNo = 0
         SET @cErrMsg1 = '66628 Same'
         SET @cErrMsg2 = 'Barcode in SKU'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
         END
         GOTO Step_2_Fail      
      END    
  
      EXEC [RDT].[rdt_GETSKU]    
         @cStorerKey  = @cStorerKey,
         @cSKU        = @cSKU          OUTPUT,
         @bSuccess    = @b_Success     OUTPUT,
         @nErr        = @n_Err         OUTPUT,
         @cErrMsg     = @c_ErrMsg      OUTPUT


     IF NOT EXISTS (SELECT 1 FROM RDT.RdtGOHSettagelog WITH (NOLOCK)
                     WHERE LoadKey = @cLoadKey
                     AND   DropID = @cPickToID
                     AND   AddWho = @cUserName
                     AND   SKU = @cSKU)
--                     AND   Status = '1')
     BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '66608 SKU'
         SET @cErrMsg2 = 'not on Pick TOID'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
         END
         GOTO Step_2_Fail   
     END


     IF CAST(@cQtyCnt AS INT) + 1 > CAST(@cTotalQtyCnt AS INT)
     BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = '66609 '
         SET @cErrMsg2 = 'Over Scan'
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
         END
         GOTO Step_2_Fail   
     END

  --   SET @cQty = CAST(CAST(@cQty AS INT) + 1 AS CHAR)

     -- Get the record from log table to offset
--     DECLARE CUR_Log CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT TOP 1 @cPickDetailKey = PickDetailKey, 
                   @nOriginalQty = SUM(Qty), 
                   @nRemainQty = SUM(RemainQty)
      FROM RDT.RdtGOHSettagelog WITH (NOLOCK) 
      WHERE StorerKey = @cStorerkey
      AND DropID = @cPickToID
      AND SKU = @cSKU
      AND Status <> '9'
      AND AddWho = @cUsername
      GROUP BY PickdetailKey, SKU
      HAVING SUM(RemainQty) > 0
      ORDER BY PickdetailKey

--    OPEN CUR_Log
--    FETCH NEXT FROM CUR_Log INTO @cPickDetailKey, @nOriginalQty, @nRemainQty
--    WHILE @@FETCH_STATUS = 0
--    BEGIN
--       IF @nRemainQty + 1 =  @nOriginalQty
--       BEGIN
         UPDATE RDT.RdtGOHSettagelog WITH (ROWLOCK)
           SET Status = '3', 
               QtyScan = QtyScan + 1,
               RemainQty = RemainQty - 1
         WHERE Pickdetailkey = @cPickDetailKey
           AND AddWho = @cUsername
--       END       
--       ELSE
--       BEGIN
--          UPDATE RDT.RdtGOHSettagelog WITH (ROWLOCK)
--             SET QtyScan = QtyScan + 1,
--                 RemainQty = RemainQty - 1
--          WHERE Pickdetailkey = @cPickDetailKey
--            AND AddWho = @cUsername
--       END

--       FETCH NEXT FROM CUR_Log INTO @cPickDetailKey, @nOriginalQty, @nRemainQty
--    END
--    CLOSE CUR_Log       
--    DEALLOCATE CUR_Log   


      SELECT @cQtyCnt = CAST(SUM(QTY) - SUM(RemainQty) AS CHAR)--CAST(SUM(QTYScan) AS CHAR)
      FROM  RDT.RdtGOHSettagelog WITH (NOLOCK)
      WHERE DropID = @cPickToID
      AND   Storerkey = @cStorerKey
      AND   AddWho = @cUserName
      GROUP BY DropID
            
      --prepare next screen variable
      SET @cOutField01 = SUBSTRING(@cSKU, 1, 18)
      SET @cOutField02 = SUBSTRING(@cDescr, 1, 18)
      SET @cOutField03 = @cDefaultPackQty
      SET @cOutField04 = @cPackUOM3
      SET @cOutField05 = ''
      SET @cOutField06 = RTRIM(@cQtyCnt) + '/' + RTRIM(@cTotalQtyCnt)
                            
      -- Loop same screen
      SET @nScn = @nScn
      SET @nStep = @nStep
      
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
       SET @cOutField01 = @cDefaultOption
       SET @cOutField05 = ''
       EXEC rdt.rdtSetFocusField @nMobile, 1 

       SET @nPrevStep = 0
       SET @nPrevScn = 0
               
       -- Go to Label Screen
       SET @nScn = @nScn + 1
       SET @nStep = @nStep + 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cSKU = ''
      
      -- Reset this screen var
      SET @cOutField05 = ''  -- SKU
      SET @cOutField06 = RTRIM(@cQtyCnt) + '/' + RTRIM(@cTotalQtyCnt)
  END
END
GOTO Quit

/********************************************************************************
Step 3. (screen = 1982) Print Label OPTION
   OPTION: (Field01 input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 OR @nInputKey = 0 -- ENTER/ESC
   BEGIN
         -- Screen mapping
         SET @cOption = @cInField01
         
         -- Validate blank
         IF @cOption = '' OR @cOption IS NULL
         BEGIN
            SET @nErrNo = 66610
            SET @cErrMsg = rdt.rdtgetmessage( 66610, @cLangCode, 'DSP') --Option needed
            GOTO Step_3_Fail
         END
   
         -- Validate option
         IF (@cOption <> '1' AND @cOption <> '2' AND @cOption <> '9')
         BEGIN
            SET @nErrNo = 66611
            SET @cErrMsg = rdt.rdtgetmessage( 66611, @cLangCode, 'DSP') --Invalid option
            GOTO Step_3_Fail
         END
   
         -- Print Label
         IF @cOption = '1'
         BEGIN
          
            IF @nPrevStep = @nStep + 1
            BEGIN
               SET @nErrNo = 66612
               SET @cErrMsg = rdt.rdtgetmessage( 66612, @cLangCode, 'DSP') --Invalid option
               GOTO Step_3_Fail
            END

            SELECT TOP 1 @cConsigneeKey = RTRIM(ORDERS.Consigneekey), 
                         @cExternOrderKey = RTRIM(ORDERS.Externorderkey)
            FROM dbo.ORDERS ORDERS WITH (NOLOCK)
            JOIN dbo.ORDERDETAIL ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
            JOIN dbo.LOADPLANDETAIL LOADPLANDETAIL WITH (NOLOCK) ON  (ORDERS.Orderkey = LOADPLANDETAIL.Orderkey)
            WHERE LOADPLANDETAIL.Loadkey = @cLoadkey
            GROUP BY ORDERS.Consigneekey, ORDERS.Externorderkey
            ORDER BY ORDERS.Consigneekey, ORDERS.Externorderkey
   
            SELECT TOP 1 @cItemClass = RTRIM(SKU.Itemclass), 
                         @cBUSR5 = RTRIM(SKU.Busr5)
            FROM dbo.SKU SKU WITH (NOLOCK)
            JOIN RDT.RdtGOHSettagelog SL WITH (NOLOCK) ON (SL.Storerkey = SKU.Storerkey AND SL.SKU = SKU.SKU)
            WHERE SL.Status = '3'
            AND   SL.AddWho = @cUsername
   
         	SELECT TOP 1 @cInterModalVehicle = RTRIM(ORDERS.IntermodalVehicle)
    	      FROM dbo.ORDERS ORDERS (NOLOCK)
   	      JOIN dbo.ORDERDETAIL ORDERDETAIL (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
      	   JOIN dbo.SKU SKU (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku)
        		JOIN dbo.LOADPLANDETAIL LOADPLANDETAIL(NOLOCK) ON  (ORDERS.Orderkey = LOADPLANDETAIL.Orderkey)
        		WHERE LOADPLANDETAIL.Loadkey = @cLoadkey
        		AND ORDERS.Consigneekey = @cConsigneeKey
        		AND ORDERS.Externorderkey = @cExternOrderKey
        		AND SKU.Itemclass = @cItemClass
        		AND SKU.Busr5 = @cBUSR5
        		GROUP BY ORDERS.IntermodalVehicle
   
      
            SELECT @nFinalQty = SUM(QTYScan)
            FROM RDT.RdtGOHSettagelog WITH (NOLOCK) 
            WHERE StorerKey = @cStorerkey
            AND DropID = @cPickToID
            AND Status = '3'
            AND AddWho = @cUsername

   
            SELECT @cKeyname = 'URN_'+ @cInterModalVehicle
   
            BEGIN TRAN
   
   	      EXECUTE dbo.nspg_getkey
             @cKeyname
           , 6
    	     , @cURNPackNo OUTPUT
     		  , @b_success OUTPUT
     		  , @n_err OUTPUT
     		  , @c_errmsg OUTPUT
   
            IF @b_success <> 1
            BEGIN
               SET @nErrNo = 66613
               SET @cErrMsg = rdt.rdtgetmessage( 66613, @cLangCode, 'DSP') -- 'GetDetKeyFail'
               ROLLBACK TRAN
               GOTO Step_3_Fail
            END
   
           COMMIT TRAN
   
           
           SET @cURNNo1 = LEFT(@cConsigneeKey,4) + LEFT(@cInterModalVehicle,3) + LEFT(@cURNPackNo,6) +
                          ISNULL(LEFT(@cBUSR5,5),'') 
           SET @cURNNo2 = RIGHT('000'+RIGHT(ISNULL(RTRIM(@cItemClass),''),3),3) +
                          LEFT(@cExternOrderKey,6) + RIGHT('000'+RTRIM(CONVERT(char(3),@nFinalQty)),3) + '01'
             
           -- Print Label
           -- Validate printer setup
     		  IF ISNULL(@cPrinter, '') = ''
   		  BEGIN			
   	        SET @nErrNo = 66614
   	        SET @cErrMsg = rdt.rdtgetmessage( 66614, @cLangCode, 'DSP') --NoLoginPrinter
   	        GOTO Step_3_Fail
   		  END
       		       
           SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                  @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
           FROM RDT.RDTReport WITH (NOLOCK) 
           WHERE StorerKey = @cStorerKey
             AND ReportType = 'URNLABEL' 
                   	
          IF ISNULL(@cDataWindow, '') = ''
          BEGIN
             SET @nErrNo = 66615
             SET @cErrMsg = rdt.rdtgetmessage( 66615, @cLangCode, 'DSP') --DWNOTSetup
             GOTO Step_3_Fail
          END
   
          IF ISNULL(@cTargetDB, '') = ''
          BEGIN
             SET @nErrNo = 66616
             SET @cErrMsg = rdt.rdtgetmessage( 66616, @cLangCode, 'DSP') --TgetDB Not Set
             GOTO Step_3_Fail
          END
   
          BEGIN TRAN

          -- Call printing spooler
          INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Printer, NoOfCopy, Mobile, TargetDB)
          VALUES('PRINT_URNLABEL_S', 'URNLABEL', '0', @cDataWindow, 1, RTRIM(@cURNNo1), RTRIM(@cURNNo2), @cPrinter, 1, @nMobile, @cTargetDB) 
   
          IF @@ERROR <> 0
          BEGIN
             ROLLBACK TRAN
   
             SET @nErrNo = 66617
             SET @cErrMsg = rdt.rdtgetmessage( 66617, @cLangCode, 'DSP') --'InsertPRTFail'
             GOTO Step_3_Fail
          END
          COMMIT TRAN
   
          -- Reset this screen var
          SET @cOutField01 = '' 
   
          SET @nScn = @nScn + 1
          SET @nStep = @nStep + 1
       END -- Option = 1

       -- Reprint Label
       IF @cOption = '2'
       BEGIN 
            SET @nPrevStep = 0
            SET @nPrevScn = 0

            -- Validate printer setup
     		  IF ISNULL(@cPrinter, '') = ''
   		  BEGIN			
   	        SET @nErrNo = 66618
   	        SET @cErrMsg = rdt.rdtgetmessage( 66618, @cLangCode, 'DSP') --NoLoginPrinter
   	        GOTO Step_3_Fail
   		  END
       		       
           SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                  @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
           FROM RDT.RDTReport WITH (NOLOCK) 
           WHERE StorerKey = @cStorerKey
             AND ReportType = 'URNLABEL' 
                   	
          IF ISNULL(@cDataWindow, '') = ''
          BEGIN
             SET @nErrNo = 66619
             SET @cErrMsg = rdt.rdtgetmessage( 66619, @cLangCode, 'DSP') --DWNOTSetup
             GOTO Step_3_Fail
          END
   
          IF ISNULL(@cTargetDB, '') = ''
          BEGIN
             SET @nErrNo = 66620
             SET @cErrMsg = rdt.rdtgetmessage( 66620, @cLangCode, 'DSP') --TgetDB Not Set
             GOTO Step_3_Fail
          END
   
          BEGIN TRAN
   
          -- Call printing spooler
          INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Printer, NoOfCopy, Mobile, TargetDB)
          VALUES('REPRINT_URNLABEL_S', 'URNLABEL', '0', @cDataWindow, 1, RTRIM(@cURNNo1), RTRIM(@cURNNo2), @cPrinter, 1, @nMobile, @cTargetDB) 
   
          IF @@ERROR <> 0
          BEGIN
             ROLLBACK TRAN
   
             SET @nErrNo = 66621
             SET @cErrMsg = rdt.rdtgetmessage( 66621, @cLangCode, 'DSP') --'InsertPRTFail'
             GOTO Step_3_Fail
          END
          COMMIT TRAN
   
          -- Reset this screen var
          SET @cOutField01 = '' 
   
          SET @nScn = @nScn + 1
          SET @nStep = @nStep + 1
       END -- Option = 2
   
       -- ESC
       IF @cOption = '9'
       BEGIN
--           IF CAST(@cQtyCnt AS INT) = CAST(@cTotalQtyCnt AS INT)
--           BEGIN
--             SET @cOutField01 = ''
-- 
--             SET @cOutField05 = ''  -- SKU
--             SET @cOutField06 = RTRIM(@cQtyCnt) + '/' + RTRIM(@cTotalQtyCnt)
--    
--             SET @nScn = @nScn - 1
--             SET @nStep = @nStep - 1
--           END
            UPDATE RDT.RdtGOHSettagelog WITH (ROWLOCK)
              SET QTYScan = 0, 
                  RemainQty = RemainQty + QTYScan,
                  Status = '1', 
                  EditDate = GETDATE()
            WHERE Storerkey = @cStorerKey
              AND DropID = @cPickToID
              AND AddWho = @cUserName
              AND Status = '3'

            SELECT @cQtyCnt = CAST(SUM(QTY) - SUM(RemainQty) AS CHAR)
            FROM  RDT.RdtGOHSettagelog WITH (NOLOCK)
            WHERE DropID = @cPickToID
            AND   Storerkey = @cStorerKey
            AND   AddWho = @cUserName
            GROUP BY DropID

          IF CAST(@cQtyCnt AS INT) < CAST(@cTotalQtyCnt AS INT)
          BEGIN
              IF @cSHOWSHTPICKRSN = '1'
              BEGIN
               SET @cOutField01 = CAST(CAST(@cTotalQtyCnt AS INT) - CAST(@cQtyCnt AS INT) AS CHAR)
               SET @cOutField02 = @cPackUOM3
               SET @cOutField03 = ''
               SET @cOutField04 = ''
               SET @cOutField05 = ''
               
               -- Save current screen no
               SET @nCurScn = @nScn
               SET @nCurStep = @nStep
   
               -- Go to STD short pick screen
               SET @nScn = 2010
               SET @nStep = @nStep + 3
              END

           -- Reset uncompleted task for the same login
              UPDATE RDT.RdtGOHSettagelog WITH (ROWLOCK)
                 SET AddWho = '', 
                     Status = '1', 
                     QtyScan = '',
                     EditWho = ''
              WHERE StorerKey = @cStorerKey
                AND DropID = @cPickToID
                AND AddWho = @cUserName
                AND Status < '9'

               IF @@ERROR <> 0
               BEGIN
                  ROLLBACK TRAN
                  SET @nErrNo = 66626
                  SET @cErrMsg = rdt.rdtgetmessage( 66626, @cLangCode, 'DSP') --'SKUAlrdLock'
                  GOTO Quit
               END
      
               COMMIT TRAN

--                SET @cOutField01 = '' 
--                SET @cOutField05 = ''  -- SKU

--                SET @nScn = @nScn - 2
--                SET @nStep = @nStep - 2
          END
       END -- Option = 9
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOutField01 = @cDefaultOption -- Default Option

      SET @nScn = @nScn 
      SET @nStep = @nStep 
   END   
END
GOTO Quit

/********************************************************************************
Step 4. (screen = 1983) SET ID/URN NO
 URN No: (Field01 input)
********************************************************************************/
Step_4:
BEGIN
   IF  @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cScanURNNo1 = SUBSTRING(@cInField01,1,20)
      SET @cScanURNNo2 = RTRIM(SUBSTRING(@cInField01,21,20))

      --When URNNo is blank
      IF @cScanURNNo1 = ''
      BEGIN
         SET @nErrNo = 66622
         SET @cErrMsg = rdt.rdtgetmessage( 66622, @cLangCode, 'DSP') --URN# Req
         GOTO Step_4_Fail  
      END 

--       IF NOT EXISTS (SELECT 1 FROM dbo.PickHeader WITH (NOLOCK)
--                      WHERE ExternOrderkey = @cLoadkey
--                      AND   Orderkey = @cOrderkey)
--       BEGIN
--           SET @cPickSlipType = 'CONSO'
--       END
--       ELSE
--       BEGIN
--           SET @cPickSlipType = 'SINGLE'
--       END

      -- Check whether packheader exists
      IF NOT EXISTS (SELECT 1 FROM dbo.PACKHEADER WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
      BEGIN
         -- Conso Pickslipno
         IF @cPickSlipType = 'CONSO'
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
               SET @nErrNo = 66623
               SET @cErrMsg = rdt.rdtgetmessage( 66623, @cLangCode, 'DSP') --'InsPHdrFail'
               ROLLBACK TRAN
               GOTO Step_4_Fail               
            END
         END   -- @cPickSlipType = 'CONSO'
         ELSE
         BEGIN
            INSERT INTO dbo.PackHeader 
            (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
            SELECT O.Route, O.OrderKey, O.ExternOrderKey, O.LoadKey, O.ConsigneeKey, O.Storerkey, @cPickSlipNo 
            FROM  dbo.PickHeader PH WITH (NOLOCK)
            JOIN  dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)
            WHERE PH.PickHeaderKey = @cPickSlipNo

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 66624
               SET @cErrMsg = rdt.rdtgetmessage( 66624, @cLangCode, 'DSP') --'InsPHdrFail'
               ROLLBACK TRAN
               GOTO Step_4_Fail               
            END
         END   -- @cPickSlipType = 'SINGLE'
      END   -- Check whether packheader exists

      SELECT @nCartonNo = ISNULL(MAX(CartonNo), 0) + 1
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE Pickslipno = @cPickSlipNo

      DECLARE CUR_PACKDETAIL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT PickDetailKey, SKU, QTYScan, RemainQty
      FROM RDT.RdtGOHSettagelog WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND DropID = @cPickToID
         AND AddWho = @cUserName
         AND Status = '3'
      OPEN CUR_PACKDETAIL
      FETCH NEXT FROM CUR_PACKDETAIL INTO @cPD_Key, @cPD_SKU, @nPD_Qty, @nPD_RemainQty
      WHILE @@FETCH_STATUS <> -1
      BEGIN


         SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE Pickslipno = @cPickSlipNo
            AND CartonNo = @nCartonNo

         -- Insert PackDetail
         INSERT INTO dbo.PackDetail 
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, RefNo, AddWho, AddDate, EditWho, EditDate)
         VALUES 
            (@cPickSlipNo, @nCartonNo, @cURNPackNo, @cLabelLine, @cStorerKey, @cPD_SKU, @nPD_Qty, @cPD_Key, sUser_sName(), GETDATE(), sUser_sName(), GETDATE())

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 66625
            SET @cErrMsg = rdt.rdtgetmessage( 66625, @cLangCode, 'DSP') --'InsPackDtlFail'
            RollBack Tran 
            GOTO Step_4_Fail
         END

         IF @nPD_RemainQty > 0
         BEGIN
            UPDATE RDT.RdtGOHSettagelog WITH (ROWLOCK)
              SET QTYScan = 0, Status = '1', EditDate = GETDATE()
            WHERE PickDetailKey = @cPD_Key
              AND DropID = @cPickToID
              AND AddWho = @cUserName
              AND Status = '3'
         END
         ELSE IF @nPD_RemainQty = 0
         BEGIN
            UPDATE RDT.RdtGOHSettagelog WITH (ROWLOCK)
              SET QTYScan = 0, Status = '9', EditDate = GETDATE()
            WHERE PickDetailKey = @cPD_Key
              AND DropID = @cPickToID
              AND AddWho = @cUserName
              AND Status = '3'
         END 

         FETCH NEXT FROM CUR_PACKDETAIL INTO @cPD_Key, @cPD_SKU, @nPD_Qty, @nPD_RemainQty
      END
      CLOSE CUR_PACKDETAIL
      DEALLOCATE CUR_PACKDETAIL

      SELECT @cBUSR3 = RTRIM(BUSR3)
      FROM dbo.SKU WITH (NOLOCK)
      WHERE Storerkey = @cStorerKey
      AND   SKU in (SELECT MIN(SKU) FROM dbo.PackDetail WITH (NOLOCK)
                    WHERE Pickslipno = @cPickSlipNo
                    AND CartonNo = @nCartonNo)

      -- Insert PackInfo
      INSERT INTO dbo.PackInfo
        (PickSlipNo, CartonNo, AddWho, AddDate, EditWho, EditDate, CartonType, RefNo)
      VALUES 
        (@cPickSlipNo, @nCartonNo, sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), @cBUSR3, RTRIM(@cScanURNNo1) + RTRIM(@cScanURNNo2))


      -- Getting the QTY Packed
      SELECT @nQtyPacked = ISNULL(SUM(PAD.Qty), 0) 
      FROM dbo.PackDetail PAD WITH (NOLOCK) 
      JOIN dbo.PackHeader PAH WITH (NOLOCK) ON (PAD.PickSlipNo = PAH.PickSlipNo)
      JOIN dbo.PickHeader PIH WITH (NOLOCK) ON (PAH.PickSlipNo = PIH.PickHeaderKey)
      WHERE PIH.ExternOrderKey = @cLoadKey

      -- Getting the QTY Picked
      SELECT @nQtyAllocated = ISNULL(SUM(PD.Qty), 0) 
      FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON (PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey)
      WHERE O.StorerKey = @cStorerKey
        AND O.LoadKey = @cLoadKey

      
      IF @cAutoPackConfirm = '1' AND (@nQtyPacked = @nQtyAllocated)
      BEGIN

         DECLARE CUR_PACKCFM CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT PickSlipNo
         FROM dbo.PackHeader WITH (NOLOCK)
         WHERE Loadkey = @cLoadKey
           AND Status = '0'
         OPEN CUR_PACKCFM
         FETCH NEXT FROM CUR_PACKCFM INTO @cCfm_PSNo
         WHILE NOT @@FETCH_STATUS <> -1
         BEGIN

            BEGIN TRAN

            UPDATE dbo.PackHeader WITH (ROWLOCK) SET 
               Status = '9'
            WHERE PickSlipNo = @cCfm_PSNo

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = '99999 '
               SET @cErrMsg2 = 'PackHeader'
               SET @cErrMsg3 = 'confirm fail!'
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                  @cErrMsg1, @cErrMsg2, @cErrMsg3
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
                  SET @cErrMsg2 = ''
                  SET @cErrMsg3 = ''
               END
               ROLLBACK TRAN 
               GOTO Step_4_Fail
            END

         FETCH NEXT FROM CUR_PACKCFM INTO @cCfm_PSNo
        END
        CLOSE CUR_PACKCFM
        DEALLOCATE CUR_PACKCFM
       
           
        SET @cOutField01 = '' 
        SET @cOutField02 = ''
      
        SET @cPickToID = ''
        SET @cQtyCnt = 0
        SET @cTotalQtyCnt = 0
        SET @cQty = 0

        -- go to NEXT screen
        SET @nScn = @nScn + 1
        SET @nStep = @nStep + 1
     END   -- @cAutoPackConfirm
     ELSE IF CAST(@cQtyCnt AS INT) < CAST(@cTotalQtyCnt AS INT)
     BEGIN
     
          SET @cOutField05 = '' 
          SET @cOutField06 = RTRIM(@cQtyCnt) + '/' + RTRIM(@cTotalQtyCnt)

          -- go to previous screen
          SET @nScn = @nScn - 2
          SET @nStep = @nStep - 2
     END
     ELSE IF CAST(@cQtyCnt AS INT) = CAST(@cTotalQtyCnt AS INT)
     BEGIN
     
          SET @cOutField01 = '' 
          SET @cOutField05 = '' 
          SET @cOutField06 = ''

          SET @cPickToID = ''
          SET @cQtyCnt = 0
          SET @cTotalQtyCnt = 0
          SET @cQty = 0

          -- go to msg screen
          SET @nScn = @nScn + 1
          SET @nStep = @nStep + 1
     END     
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
          SET @cOutField01 = '2'--@cDefaultOption
          SET @cOutField05 = ''
          EXEC rdt.rdtSetFocusField @nMobile, 1 
                  
          SET @nPrevScn  = @nScn
          SET @nPrevStep = @nStep

          -- Go to Label Screen
          SET @nScn = @nScn - 1
          SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cOutField01 = '' 
      SET @cScanURNNo1 = ''
      SET @cScanURNNo2 = ''

      SET @nScn = @nScn 
      SET @nStep = @nStep 
   END   

END
GOTO Quit


/********************************************************************************
Step 5. (screen = 1984) No more Pick Task Msg
********************************************************************************/
Step_5:
BEGIN
   IF  @nInputKey = 1 OR @nInputKey = 0 -- ENTER/ESC
   BEGIN
          SET @cOutField01 = '' 

          SET @nPrevStep = 0
          SET @nPrevScn = 0

          -- go to previous screen
          SET @nScn = @nScn - 4
          SET @nStep = @nStep - 4
   END
   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 6. Scn = 2010. 
   RSN        (field01, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
      SET @cReasonCode = @cInField05  
  
      IF ISNULL(@cReasonCode, '') = ''
      BEGIN
         SET @nErrNo = 66627
         SET @cErrMsg = rdt.rdtgetmessage( 66627, @cLangCode, 'DSP') --'BAD Reason'
         GOTO Step_6_Fail
      END

      SELECT @cModuleName = StoredProcName FROM RDT.RDTMsg WITH (NOLOCK) WHERE Message_id = @nFunc

      SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
      FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
      WHERE M.Mobile = @nMobile

      SET @nQTY = CAST(@cTotalQtyCnt AS INT) - CAST(@cQtyCnt AS INT)

      EXEC rdt.rdt_STD_Short_Pick
         @nFunc, 
         @nMobile, 
         @cLangCode, 
         @nErrNo        OUTPUT, 
         @cErrMsg       OUTPUT, -- screen limitation, 20 char max
         @cStorerKey, 
         @cFacility, 
         @cPickSlipNo, 
         @cLoadKey, 
         @cWaveKey, 
         @cOrderKey, 
         @cLOC, 
         @cID, 
         @cSKU, 
         @cPUOM, 
         @nQTY,       -- In master unit
         @cLottable01, 
         @cLottable02, 
         @cLottable03, 
         @dLottable04, 
         @dLottable05,
         @cReasonCode, 
         @cUserName, 
         @cModuleName

      IF @nErrNo <> 0
      BEGIN
         GOTO Step_6_Fail
      END
      ELSE
      BEGIN
         -- Initiate var
         SET @cLoadKey = ''
         SET @cPickToID = ''
         SET @nPrevStep = 0
         SET @nPrevScn = 0


         -- Init screen
         SET @cOutField01 = '' -- LoadKey
         SET @cOutField02 = '' -- Zone
        -- SET @cOutField05 = ''
         --SET @cOutField06 = RTRIM(@cQtyCnt) + '/' + RTRIM(@cTotalQtyCnt)

         -- Go to screen 1
         SET @nScn = @nCurScn - 2
         SET @nStep = @nCurStep - 2
      END
   END

   IF @nInputKey = 0 --ESC
   BEGIN
      -- Go to prev screen
      SET @nScn = @nCurScn
      SET @nStep = @nCurStep

      SET @cOutField01 = @cDefaultOption   -- Option
   END
   GOTO Quit

   Step_6_Fail:
   BEGIN
      SET @cReasonCode = ''
      SET @cOutField05 = '' -- RSN
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

       V_UOM         = @cPackUOM3,
       V_QTY         = @cQty,
       V_SKU         = @cSKU,
       V_SKUDescr    = @cDescr,
       V_OrderKey    = @cOrderKey,
       V_LoadKey     = @cLoadKey,

       V_String1     = @cPickToID,
       V_String2     = @cOption,     
       V_String3     = @cTotalQtyCnt,
       V_String4     = @cQtyCnt,
       V_String5     = @cURNNo1,  
       V_String6     = @cURNNo2,
   
       V_String7     = @cDefaultOption,
       V_String8     = @cDefaultPackQty,
       V_String9     = @cAutoScanOutPS,
       V_String10    = @cAutoPackConfirm,
       V_String11    = @cSHOWSHTPICKRSN,

       V_String12   = @nCurScn,
       V_String13   = @nCurStep,

       V_String14   = @nPrevScn,
       V_String15   = @nPrevStep,

       V_String16   = @cURNPackNo,
       V_String17   = @cPickSlipType,
       V_String18   = @cPickSlipNo,

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