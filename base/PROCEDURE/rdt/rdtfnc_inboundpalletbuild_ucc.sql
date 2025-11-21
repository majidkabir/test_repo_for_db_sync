SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtfnc_InboundPalletBuild_UCC                             */
/* Copyright      : LF Logistics                                              */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 25-08-2021 1.0  Chermaine  WMS-17724 Created                               */
/******************************************************************************/
CREATE PROC [RDT].[rdtfnc_InboundPalletBuild_UCC] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @bSuccess         INT,
   @nCSKU            INT,
   @nPSKU            INT,
   @nCQTY            INT,
   @nPQTY            INT, 
   @nRowCount        INT, 
   @cOption          NVARCHAR(1)
   
-- rdt.rdtMobRec variable
DECLARE
   @nFunc            INT,
   @nScn             INT,
   @nStep            INT,
   @nMenu            INT,
   @cLangCode        NVARCHAR( 3),
   @nInputKey        INT,

   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @cUserName        NVARCHAR( 18),
   @cPrinter         NVARCHAR( 10),
   
   @cPalletID        NVARCHAR( 10),
   @cUCCNo           NVARCHAR( 20),
   @cUCCLog          NVARCHAR( 20),
   @cUCCLOC          NVARCHAR( 10),
   @cUCCID           NVARCHAR( 18),
   @cSKU             NVARCHAR( 20),
   
   @nQty             INT,
   @nRowRef          INT,

   @cInField01 NVARCHAR( 60),  @cOutField01 NVARCHAR( 60),
   @cInField02 NVARCHAR( 60),  @cOutField02 NVARCHAR( 60),
   @cInField03 NVARCHAR( 60),  @cOutField03 NVARCHAR( 60),
   @cInField04 NVARCHAR( 60),  @cOutField04 NVARCHAR( 60),
   @cInField05 NVARCHAR( 60),  @cOutField05 NVARCHAR( 60),
   @cInField06 NVARCHAR( 60),  @cOutField06 NVARCHAR( 60),
   @cInField07 NVARCHAR( 60),  @cOutField07 NVARCHAR( 60),
   @cInField08 NVARCHAR( 60),  @cOutField08 NVARCHAR( 60),
   @cInField09 NVARCHAR( 60),  @cOutField09 NVARCHAR( 60),
   @cInField10 NVARCHAR( 60),  @cOutField10 NVARCHAR( 60),
   @cInField11 NVARCHAR( 60),  @cOutField11 NVARCHAR( 60),
   @cInField12 NVARCHAR( 60),  @cOutField12 NVARCHAR( 60),
   @cInField13 NVARCHAR( 60),  @cOutField13 NVARCHAR( 60),
   @cInField14 NVARCHAR( 60),  @cOutField14 NVARCHAR( 60),
   @cInField15 NVARCHAR( 60),  @cOutField15 NVARCHAR( 60),

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
   @nMenu            = Menu,
   @cLangCode        = Lang_code,
   @nInputKey        = InputKey,

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cPrinter         = Printer,
   @cUserName        = UserName,
   @cUCCNo           = V_UCC, 

   @cPalletID        = V_String1,
   @cUCCNo           = V_String2,
      
   @nQty             = V_Integer1, 
   
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

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc in (1858)
BEGIN
   IF @nStep = 0 GOTO Step_0  -- Menu. Func = 1858
   IF @nStep = 1 GOTO Step_1  -- Scn = 5970. PalletID
   IF @nStep = 2 GOTO Step_2  -- Scn = 5971. UCCNo
   --IF @nStep = 3 GOTO Step_3  -- Scn = 5972. ClosePallet?
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Func = 1858
********************************************************************************/
Step_0:
BEGIN
   -- Init var

   -- Go to next screen
   SET @nScn = 5970
   SET @nStep = 1
   
   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 5970. PalletID screen
   Pallet ID       (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN      
      -- Screen mapping
      SET @cPalletID = @cInField01 

      -- Check blank
      IF @cPalletID = '' 
      BEGIN
         SET @nErrNo = 174201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Need PalletID
         GOTO Step_1_Fail
      END
      
      -- Check barcode format    
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'Palletkey', @cPalletID) = 0    
      BEGIN    
         SET @nErrNo = 174211    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidFormat    
         GOTO Step_1_Fail    
      END    
      
      IF EXISTS (SELECT TOP 1 1 FROM UCC WITH (NOLOCK) WHERE ID = @cPalletID AND Storerkey = @cStorerKey)
      BEGIN
      	IF EXISTS (SELECT TOP 1 1 FROM UCC WITH (NOLOCK) WHERE ID = @cPalletID AND Storerkey = @cStorerKey AND (LOC <> 'TRISTAGE' OR STATUS <> '1'))
      	BEGIN
      		SET @nErrNo = 174202
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- ID Exists
            GOTO Step_1_Fail
      	END
      END
            
      -- Prepare next screen var
      SET @cOutField01 = @cPalletID -- PalletID
      SET @cOutField02 = '' -- uccNo
      SET @cOutField03 = '' -- Qty
   
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1   
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
   	-- EventLog - Sign In Function
      EXEC RDT.rdt_STD_EventLog
      @cActionType = '9', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep
        
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- PalletID
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 5971. UCC screen
   Pallet ID   (field01)
   UCC No      (field02, input)
   Qty         (field03)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
   	-- Screen mapping
      SET @cUCCNo = @cInField02 
      
      -- Check blank
      IF @cUCCNo = '' 
      BEGIN
         SET @nErrNo = 174203
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Need UccNo
         GOTO Step_2_Fail
      END
      
      IF NOT EXISTS (SELECT 1 FROM UCC WITH (NOLOCK) WHERE UCCNo = @cUCCNo AND Storerkey = @cStorerKey)
      BEGIN
         SET @nErrNo = 174204
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid UCCNo
         GOTO Step_2_Fail
      END
      
      IF EXISTS (SELECT TOP 1 1 FROM UCC WITH (NOLOCK) WHERE UCCNo = @cUCCNo AND Storerkey = @cStorerKey AND STATUS <> '1')
      BEGIN
         SET @nErrNo = 174205
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InvalidStatus
         GOTO Step_2_Fail
      END
      
      IF EXISTS (SELECT TOP 1 1 FROM rdt.PalletBuildLog WITH (NOLOCK) WHERE UCCNo = @cUCCNo AND Storerkey = @cStorerKey )
      BEGIN
         SET @nErrNo = 174206
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Duplicate UCC
         GOTO Step_2_Fail
      END
      
      IF EXISTS (SELECT TOP 1 1 FROM UCC WITH (NOLOCK) WHERE UCCNo = @cUCCNo AND Storerkey = @cStorerKey AND ID = @cPalletID )
      BEGIN
         SET @nErrNo = 174214
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Duplicate UCC  
         GOTO Step_2_Fail
      END
      
      IF EXISTS (SELECT TOP 1 1 FROM UCC WITH (NOLOCK) WHERE UCCNo = @cUCCNo AND Storerkey = @cStorerKey AND ID <> '' )
      BEGIN
         SET @nErrNo = 174212
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UCC Exists   
         GOTO Step_2_Fail
      END
      
      --INSERT INTO rdt.PalletBuildLog (storerKey, PalletID, UCCNo, status)
      --VALUES (@cStorerKey, @cPalletID, @cUCCNo, '1')
      
      -- Get FromLOC, FromLot  
      SELECT   
         @cUCCLOC = LOC,   
         @cUCCID = ID,
         @cSKU = SKU  
      FROM dbo.UCC (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
         AND UCCNo = @cUCCNo  
         AND Status = '1' -- Received  
  
     
      --UPDATE UCC WITH (ROWLOCK) SET
      --   ID = @cPalletID,
      --   EditWho = SUSER_SNAME(), 
      --   EditDate = GETDATE()
      --   --TrafficCop = NULL
      --WHERE UccNo = @cUCCNo
      --AND storerKey = @cStorerKey
      --AND ID = ''
      --AND STATUS = '1'
            
      --IF @@ERROR <> 0  
      --BEGIN  
      --   SET @nErrNo = 174209  
      --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD UCC Fail 
      --   --ROLLBACK TRAN rdtfnc_InboundPalletBuild_UCC
      --   --WHILE @@TRANCOUNT > @nTranCount
      --   --   COMMIT TRAN
      --   GOTO Step_2_Fail
      --END  
      
      --UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) SET
      --   ID = @cPalletID,
      --   EditWho = SUSER_SNAME(), 
      --   EditDate = GETDATE()
      --   --TrafficCop = NULL
      --WHERE storerKey = @cStorerKey
      --AND Loc = @cUCCLOC
      --AND LOT = @cUCCLOT
      
      EXEC RDT.rdt_Move  
               @nMobile     = @nMobile,  
               @cLangCode   = @cLangCode,   
               @nErrNo      = @nErrNo  OUTPUT,  
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max  
               @cSourceType = 'rdtfnc_InboundPalletBuild_UCC',   
               @cStorerKey  = @cStorerKey,  
               @cFacility   = @cFacility,   
               @cFromLOC    = @cUCCLOC,   
               @cToLOC      = @cUCCLOC,   
               @cFromID     = '',  
               @cToID       = @cPalletID,       -- NULL means not changing ID. Blank consider a valid ID  
               @cSKU        = NULL,   
               @cUCC        = @cUCCNo,  
               @nFunc       = @nFunc   
            
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 174213  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD LLI Fail 
         --ROLLBACK TRAN rdtfnc_InboundPalletBuild_UCC
         --WHILE @@TRANCOUNT > @nTranCount
         --   COMMIT TRAN
         GOTO Step_2_Fail
      END  

      
      SELECT 
         @nQty = COUNT (1) 
      FROM Ucc WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND ID = @cPalletID
      AND STATUS = '1'
      
      -- Prepare next screen var
      SET @cOutField01 = @cPalletID 
      SET @cOutField02 = '' -- UCCNo
      SET @cOutField03 = @nQty -- SKU Desc1

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- Option
         
      -- Go to palletID screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
   
   Step_2_Fail:
   BEGIN
   	SELECT 
         @nQty = COUNT (1) 
      FROM Ucc WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND ID = @cPalletID
      AND STATUS = '1'
      
      -- Reset this screen var
      SET @cOutField01 = @cPalletID 
      SET @cOutField02 = '' -- UCCNo
      SET @cOutField03 = @nQty -- SKU Desc1
   END
END
GOTO Quit


--/********************************************************************************
--Step 3. Scn = 5972. Close Pallet?
--   Option    (field01, input)
--********************************************************************************/
--Step_3:
--BEGIN
--   IF @nInputKey = 1 -- ENTER
--   BEGIN
--      -- Screen mapping
--      SET @cOption = @cInField01

--      -- Check blank
--      IF @cOption = ''
--      BEGIN
--         SET @nErrNo = 174207
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Option Req
--         GOTO Step_3_Fail
--      END

--      -- Check option valid
--      IF @cOption NOT IN ('1', '2')
--	   BEGIN
--	      SET @nErrNo = 174208
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidOption
--         GOTO Step_3_Fail
--      END

--      -- Close Pallet
--      IF @cOption = '1'
--      BEGIN
--      	DECLARE @nTranCount INT  
--      	SET @nTranCount = @@TRANCOUNT  
--      	BEGIN TRAN  -- Begin our own transaction  
--         SAVE TRAN rdtfnc_InboundPalletBuild_UCC
                  
--         DECLARE CUR_Log CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         
--            SELECT RowRef, UccNo
--            FROM rdt.PalletBuildLog WITH (NOLOCK)  
--            WHERE PalletID = @cPalletID  
--               AND StorerKey = @cStorerKey  
--               AND STATUS = '1'
--            ORDER BY RowRef
--         OPEN CUR_Log 
--         FETCH NEXT FROM CUR_Log INTO @nRowRef, @cUCCLog
--         WHILE @@FETCH_STATUS = 0  
--         BEGIN
--         	UPDATE UCC WITH (ROWLOCK) SET
--         	   ID = @cPalletID,
--         	   EditWho = SUSER_SNAME(), 
--               EditDate = GETDATE()
--               --TrafficCop = NULL
--            WHERE UccNo = @cUCCLog
--            AND storerKey = @cStorerKey
--            AND ID = ''
--            AND STATUS = '1'
            
--            IF @@ERROR <> 0  
--            BEGIN  
--               SET @nErrNo = 174209  
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD UCC Fail 
--               ROLLBACK TRAN rdtfnc_InboundPalletBuild_UCC
--               WHILE @@TRANCOUNT > @nTranCount
--                  COMMIT TRAN
--               GOTO Step_3_Fail
--            END  
            
--            UPDATE rdt.PalletBuildLog WITH (ROWLOCK) SET
--         	   status = '9'
--            WHERE UccNo = @cUCCLog
--            AND storerKey = @cStorerKey
--            AND palletID = @cPalletID
            
--            IF @@ERROR <> 0  
--            BEGIN  
--               SET @nErrNo = 174210  
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Log Fail  
--               ROLLBACK TRAN rdtfnc_InboundPalletBuild_UCC
--               WHILE @@TRANCOUNT > @nTranCount
--                  COMMIT TRAN
--               GOTO Step_3_Fail  
--            END  

--         	FETCH NEXT FROM CUR_Log INTO @nRowRef, @cUCCLog
--         END
--         CLOSE CUR_Log  
--         DEALLOCATE CUR_Log  
         
--         COMMIT TRAN rdtfnc_InboundPalletBuild_UCC
--            WHILE @@TRANCOUNT > @nTranCount
--               COMMIT TRAN
         
         
--      END      
      
--      -- Go PalletID screen
--      SET @cOutField01 = '' --PalletID

--      -- Go to UCC screen
--      SET @nScn = @nScn - 2
--      SET @nStep = @nStep - 2
         
--      GOTO Quit

--   END
   
--   IF @nInputKey = 0 -- ESC
--   BEGIN      
--      -- Go Ucc screen
--      SET @cOutField01 = @cPalletID 
--      SET @cOutField01 = '' -- ucc
--      SET @cOutField01 = '' -- Qty

--      SET @nScn = @nScn - 1
--      SET @nStep = @nStep - 1
--   END
--   GOTO Quit
   
--   Step_3_Fail:
--   BEGIN
--      SET @cOutField01 = '' --option
--   END
--END
--GOTO Quit

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
      V_UCC     = @cUCCNo, 

      V_String1 = @cPalletID,
      
      V_Integer1 = @nQty,
      
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