SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: DropID Replenishment To SOS#218879                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2011-06-24 1.1  ChewKP     SOS#218879 IDSUS Sean John                */
/* 2011-09-14 1.2  James      Bug fix (james01)                         */
/* 2011-12-02 1.3  ChewKP     Changes for LCI (ChewKP01)                */
/* 2011-12-16 1.4  ChewKP     Bug Fixes (ChewKP02)                      */
/* 2011-12-22 1.5  ChewKP     Fix ReplenQty issues (ChewKP03)           */
/* 2011-12-23 1.6  ChewKP     Bug fix (james02)                         */
/* 2011-12-31 1.7  james      Bug fix (james03)                         */
/* 2012-01-01 1.8  Shong      Bug fix                                   */
/* 2012-01-07 1.9  James      Prevent duplicate UCC scan (james04)      */
/* 2012-01-12 1.10 SHONG001   Passing LOT and ID to Replen To SP        */
/* 2012-01-27 1.11 SHONG      Bug Fixing                                */
/* 2012-02-03 1.12 SHONG      Comment Confirmed = 'N' when Get Qty      */
/* 2012-02-13 1.13 ChewKP     Enable input of Qty (ChewKP04)            */
/* 2012-02-16 1.14 James      Bug fix on input of Qty (james05)         */
/* 2012-04-16 1.15 Shong      Change Picked Qty Screen                  */
/* 2012-05-02 1.16 Ung        SOS243385 Fix QTY SKU screen handling     */
/* 2012-05-03 1.17 James      Allow overwrite ToLOC (james06)           */
/* 2012-05-04 1.18 James      Add supervisor alert when overwite toloc  */
/*                            for residual PA (james07)                 */
/* 2016-09-30 1.19 Ung        Performance tuning                        */
/* 2018-11-01 1.20 Gan        Performance tuning                        */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_DropID_Replen_To] (
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
   @nRowCount   INT

-- RDT.RDTMobRec variable
DECLARE
   @nFunc      INT,
   @nScn       INT,
   @nCurScn    INT,  -- Current screen variable
   @nStep      INT,
   @nCurStep   INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5),
   @cPrinter   NVARCHAR( 10),
   @cUserName  NVARCHAR( 18),

   @cErrMsg1            NVARCHAR( 20),
   @cErrMsg2            NVARCHAR( 20),
   @cErrMsg3            NVARCHAR( 20),
   @cErrMsg4            NVARCHAR( 20),
   @cErrMsg5            NVARCHAR( 20),


   @cSKU                NVARCHAR( 20),
   @cUCCSKU             NVARCHAR( 20),
   @cDropID             NVARCHAR( 18),
   @cLOT                NVARCHAR( 10),
   @cFROMLOC            NVARCHAR( 10),
   @cID                 NVARCHAR( 18),
   @cReplenishmentKey   NVARCHAR( 10),

   @nQTY                INT,
   @cToLoc              NVARCHAR(10),

   @cSuggSKU            NVARCHAR(20),
   @cSuggToLoc          NVARCHAR(20),
   @cSKUDescr           NVARCHAR(60),
   @nReplenQty          INT,
   @cLoadKey            NVARCHAR(10),
   @b_Success           INT,
   @nPickQty            INT,
   @cInSKU              NVARCHAR(20),
   @cValidateUCC        NVARCHAR(1),
   @cLottable02         NVARCHAR(18),
   @nUCCQty             INT,
   @cUCC                NVARCHAR(20),
   @nOriginalQty        INT,
   @cReplenByOriginalQty NVARCHAR(1),
   @cReplenToByBatch     NVARCHAR(1), -- (ChewKP01)
   @nReplenBatchCount    INT, -- (ChewKP03)
   @cInQty              NVARCHAR(5),  -- (ChewKP04)
   @cSKU_Scanned        NVARCHAR(20),   -- (ChewKP04)
   @cTempReplenKey      NVARCHAR(10),   -- (james06)
   @cTempSKU            NVARCHAR(20),   -- (james06)

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
   
   DECLARE @c_NewLineChar       NVARCHAR(2),       -- (james07)
           @c_AlertMessage      NVARCHAR(512),  -- (james07)
           @c_OriginalFromLoc   NVARCHAR(10),   -- (james07)
           @n_Err               INT,           -- (james07)
           @c_ErrMsg            NVARCHAR(250)      -- (james07)
           
   SET @c_NewLineChar =  master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10) 

-- Load RDT.RDTMobRec
SELECT
   @nFunc      = Func,
   @nScn      = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cPrinter   = Printer,
   @cUserName  = UserName,

   @cLOT       = V_LOT,    -- SHONG001
   @cID        = V_ID,     -- SHONG001
   @cToLoc     = V_Loc,
   @cLoadKey   = V_Loadkey,
   @cSKU       = V_SKU,
   @cSKUDescr  = V_SKUDescr,
   
   @nReplenQty = V_Integer1,
   @nPickQty   = V_Integer2,

   @cDropID     = V_String1,
   @cReplenishmentKey = V_String2,
   @cSuggToLoc        = V_String3,
   @cSuggSKU    = V_String4,
  -- @nReplenQty  = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5, 5), 0) = 1 THEN LEFT( V_String5, 5) ELSE 0 END,
  -- @nPickQty    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6, 5), 0) = 1 THEN LEFT( V_String6, 5) ELSE 0 END,
   @cSKU_Scanned = V_String7,

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

IF @nFunc = 944  -- DropID Replenishment From
BEGIN
   Declare   @nScnNextLoc  INT
            ,@nStepNextLoc INT
            ,@nScnSkipSKU  INT
            ,@nStepSkipSKU INT
            ,@nScnDropID   INT
            ,@nStepDropID  INT
            ,@nScnToLoc    INT
            ,@nStepToLoc   INT
            ,@nScnSKU      INT
            ,@nStepSKU     INT
            ,@nScnNoTask   INT
            ,@nStepNoTask  INT

   SET @nScnDropID      = 2860
   SET @nStepDropID     = 1

   SET @nScnToLoc       = 2861
   SET @nStepToLoc      = 2

   SET @nScnSKU         = 2862
   SET @nStepSKU        = 3

   SET @nScnSkipSKU     = 2864
   SET @nStepSkipSKU    = 5

   SET @nScnNextLoc     = 2865
   SET @nStepNextLoc    = 6

   SET @nScnNoTask     = 2866
   SET @nStepNoTask = 7

   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- DropID Replenishment To
   IF @nStep = 1 GOTO Step_1   -- Scn = 2860. DropID
   IF @nStep = 2 GOTO Step_2   -- Scn = 2861. ToLoc
   IF @nStep = 3 GOTO Step_3   -- Scn = 2862. SKU
   IF @nStep = 4 GOTO Step_4   -- Scn = 2863. Replenishment Done
   IF @nStep = 5 GOTO Step_5   -- Scn = 2864. Skip SKU ?
   IF @nStep = 6 GOTO Step_6   -- Scn = 2865. No More SKU for LOC
   IF @nStep = 7 GOTO Step_7   -- Scn = 2866. No More Task
END

--RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 944. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 2860
   SET @nStep = 1

   -- Initiate var
   SET @cDropID = ''
   SET @cSKU = ''
   SET @nReplenQty = 0
   SET @nPickQty = 0
   -- Init screen
   SET @cOutField01 = '' -- DropID
END
GOTO Quit

/********************************************************************************
Step 1. Scn = 2680.
   DROP ID  (field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
      SET @cDropID = @cInField01

      -- Validate blank
      IF ISNULL(@cDropID, '') = ''
      BEGIN
         SET @nErrNo = 73401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --DROP ID Needed
         GOTO Step_1_Fail
      END

       DELETE FROM RDT.RDTPickLock WHERE AddWho = @cUserName AND Status < '9'

        -- Check if dropid exists
        IF NOT EXISTS (SELECT 1 FROM dbo.Replenishment WITH (NOLOCK)
           WHERE DropID = @cDropID)
        BEGIN
           SET @nErrNo = 73402
           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid DROPID
           GOTO Step_1_Fail
        END

        -- Check if any open task for this dropid
        IF EXISTS (SELECT 1 FROM dbo.Replenishment WITH (NOLOCK)
                   WHERE DropID = @cDropID
                   AND Confirmed = 'N')
        BEGIN
           SET @nErrNo = 73403
           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Open Task Exist
           GOTO Step_1_Fail
        END

        SELECT TOP 1
               @cSuggTOLOC = RPL.TOLOC
        FROM dbo.Replenishment RPL WITH (NOLOCK)
        JOIN dbo.SKU S WITH (NOLOCK) ON (RPL.StorerKey = S.StorerKey AND RPL.SKU = S.SKU)
        JOIN dbo.Loc LOC WITH (NOLOCK) ON (LOC.LOC = RPL.TOLOC)
        WHERE RPL.StorerKey = @cStorerKey
           AND RPL.DropID = @cDropID
           AND RPL.Confirmed = 'S'
           AND NOT EXISTS (  -- not being locked by other picker
                          SELECT 1 FROM RDT.RDTPickLock RL WITH (NOLOCK)
                             WHERE RPL.StorerKey = RL.StorerKey
                                AND RPL.FROMLOC = RL.LOC
                                AND RL.AddWho <> @cUserName
                                AND RPL.DropID = RL.DropID
                                AND Status < '9')
--        GROUP BY Loc.LogicalLocation,RPL.ReplenishmentKey, RPL.LOT, RPL.ID, RPL.TOLOC, RPL.SKU
--        ORDER BY Loc.LogicalLocation, RPL.SKU          GROUP BY RPL.Priority, RPL.TOLOC, RPL.EditDate
        ORDER BY RPL.Priority, RPL.EditDate DESC        -- Get the 1st carton that is stacking onto pallet -- (ChewKP01)
                                                        -- For example, replen from seq is case1, case2, case3
                        -- replen to is case3, case2, case1
        IF @@RowCount <> 0
        BEGIN
           BEGIN TRAN

           INSERT INTO RDT.RDTPickLock
           (WaveKey, StorerKey, LOC, LOT, ID, Status, AddWho, AddDate, PickdetailKey, SKU, Descr, PickQty, DropID,
            Loadkey,OrderKey, PutawayZone, PickZone, OrderLineNumber)
           SELECT
                  '',
                  @cStorerkey,
                  @cSuggToLoc,
                  RPL.LOT,
                  RPL.ID,
                  '1',
                  @cUserName,
                  GetDate(),
                  RPL.ReplenishmentKey,
                  RPL.SKU,
                  S.DESCR,
                  RPL.Qty,
                  RPL.DropID,
                  '', '','','',''
           FROM dbo.Replenishment RPL WITH (NOLOCK)
           JOIN dbo.SKU S WITH (NOLOCK) ON (RPL.StorerKey = S.StorerKey AND RPL.SKU = S.SKU)
           WHERE RPL.StorerKey  = @cStorerKey
              AND RPL.ToLoc     = @cSuggTOLOC
              AND RPL.Confirmed = 'S'
              AND RPL.DropID    = @cDropID
           ORDER BY RPL.SKU

           IF @@ERROR <> 0
           BEGIN
                 ROLLBACK TRAN

                 SET @nErrNo = 73404
                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Ins RPL Failed
                 GOTO Step_1_Fail
           END
           ELSE
           BEGIN
                 COMMIT TRAN
           END

           -- Update Task that Remark = 'SKIP'
           BEGIN TRAN

           UPDATE REPLENISHMENT
               SET Remark = '', ArchiveCop = NULL
           WHERE DropID          = @cDropID
               AND Confirmed     = 'S'
               AND Storerkey     = @cStorerkey

           IF @@Error <> 0
           BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 73420
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdateRPLFail'
               GOTO Step_1_Fail
           END
           ELSE
           BEGIN
              COMMIT TRAN
           END

        END
        ELSE
        BEGIN
           SET @nErrNo = 73405
           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --No Task
           GOTO Step_1_Fail
        END

      SET @cOutField01 = @cDropID
      SET @cOutField02 = @cSuggTOLOC
      SET @cOutField03 = ''

      --goto next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1

      GOTO Quit
   END

   IF @nInputKey = 0 --ESC
   BEGIN
     --go to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''

      GOTO Quit
   END

   Step_1_Fail:
   BEGIN
      SET @cDropID = ''
      SET @cOutField01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 2. Scn = 2861.

   DROP ID  (field01)
   TOLOC    (field02)
   TOLOC    (field03, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
      SET @cToLoc = @cInField03

      -- Validate blank
      IF ISNULL(@cToLoc, '') = ''
      BEGIN
         SET @nErrNo = 73406
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ToLoc Req
         GOTO Step_2_Fail
      END

      IF ISNULL(@cToLoc, '') <> ISNULL(@cSuggToLoc,'')
      BEGIN
         -- Have to allow overwrite toloc for the residual task because 
         -- someone might move the stock inside the same loc which residual task
         -- assigned to (james06)
         IF EXISTS (SELECT 1 FROM dbo.Replenishment WITH (NOLOCK) 
                    WHERE DropID = @cDropID 
                    AND Confirmed = 'S' 
                    AND ISNULL(ReplenNo, '') <> ''
                    AND ToLoc = @cSuggToLoc)
         BEGIN
            -- Check valid LOC
            IF EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                       WHERE LOC = @cToLoc 
                       AND Facility = @cFacility
                       AND LocationType = 'DYNPPICK'
                       AND LOC NOT IN (SELECT DISTINCT TOLOC FROM REPLENISHMENT (NOLOCK) WHERE Confirmed = 'S') )
            BEGIN
               SELECT @cTempReplenKey = ReplenishmentKey, 
                      @cTempSKU = SKU, 
                      @c_OriginalFromLoc = ToLOC  
               FROM dbo.Replenishment WITH (NOLOCK) 
               WHERE DropID = @cDropID 
               AND Confirmed = 'S' 
               AND ISNULL(ReplenNo, '') <> ''
               AND ToLoc = @cSuggToLoc

               -- LOC must be empty
               IF NOT EXISTS (SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK) 
                              WHERE StorerKey = @cStorerKey 
                              AND LOC = @cToLoc 
                              --AND SKU <> @cTempSKU
                              AND (QTY - QTYALLOCATED - QTYPICKED) > 0)
               BEGIN
                  UPDATE dbo.Replenishment WITH (ROWLOCK) SET 
                     --ToID = ToLOC, 
                     ToLOC = @cToLoc, 
                     ArchiveCop = NULL
                  WHERE ReplenishmentKey = @cTempReplenKey
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 73433
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UPD TOLOC Fail
                     GOTO Step_2_Fail
                  END
                  ELSE
                  BEGIN
                     -- Create Alert for Supervisor    
                     SET @c_AlertMessage = 'Replenishment To overwrite suggested To LOC: ' + @c_NewLineChar 
                     SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ReplenishmentKey: ' + @cTempReplenKey + @c_NewLineChar 
                     SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Suggested To LOC: ' + @c_OriginalFromLoc + @c_NewLineChar 
                     SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' New To LOC: ' + @cToLoc + @c_NewLineChar 
                     SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' By User: ' + @cUserName +  @c_NewLineChar 
                     SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' DateTime: ' + CONVERT(VARCHAR(20), GETDATE())  +  @c_NewLineChar 

                         
                     EXEC nspLogAlert    
                      @c_modulename   = 'rdtfnc_DropID_Replen_To',    
                      @c_AlertMessage = @c_AlertMessage,    
                      @n_Severity = 0,    
                      @b_success  = @b_Success OUTPUT,    
                      @n_err      = @n_Err    OUTPUT,    
                      @c_errmsg   = @c_ErrMsg OUTPUT    

                  END
               END
            END
            ELSE
            BEGIN
               SET @nErrNo = 73407
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid Loc
               GOTO Step_2_Fail
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 73407
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid Loc
            GOTO Step_2_Fail
         END
      END

      SET @cLOT = '' -- SHONG001
      SET @cID  = '' -- SHONG001
      SET @nReplenQty = 0   -- SHONG002
      SET @nOriginalQty = 0 -- SHONG002

      SELECT
          @cSuggSKU     = RPL.SKU
         ,@cSKUDescr    = S.Descr
         ,@nReplenQty   = SUM(RPL.Qty)
         ,@nOriginalQty = SUM(RPL.OriginalQty) -- (ChewKP01)
         ,@cLottable02  = LA.Lottable02 -- (ChewKP03)
         ,@cLot         = RPL.Lot -- (ChewKP03)
         ,@cID          = RPL.ID  -- (ChewKP03)
      FROM REPLENISHMENT RPL WITH (NOLOCK)
      JOIN dbo.SKU S WITH (NOLOCK) ON (RPL.StorerKey = S.StorerKey AND RPL.SKU = S.SKU)
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.Lot = RPL.Lot)   -- (james02)
      WHERE RPL.DropID         = @cDropID
          AND  RPL.Storerkey   = @cStorerkey
          AND  RPL.ToLoc       = @cToLoc
          AND  RPL.Confirmed   = 'S'
      GROUP BY RPL.SKU, S.Descr, RPL.ToLoc, RPL.Storerkey, RPL.DropID, RPL.Confirmed, LA.Lottable02, RPL.Lot, RPL.ID   -- (james02)
      Order By RPL.ToLoc, RPL.SKU

      IF @@RowCount = 0
      BEGIN
         SET @nErrNo = 73408
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NoReplenRec
         GOTO Step_2_Fail
      END

      IF ISNULL(RTRIM(@cLOT),'') = ''
      BEGIN
         SET @nErrNo = 73429
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --GetReplenFail
         GOTO Step_2_Fail
      END


      SET @nPickQty = 0

      SET @cOutField01 = @cDropID
      SET @cOutField02 = @cToLoc
      SET @cOutField03 = @cSuggSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
      SET @cOutField06 = ''

      SET @cReplenToByBatch = ''
      SET @cReplenToByBatch = rdt.RDTGetConfig( @nFunc, 'ReplenToByBatch', @cStorerKey)

      IF @cReplenToByBatch = '1'
      BEGIN
         -- (ChewKP03)
         SET @nReplenBatchCount = 0
         SET @nReplenQty = 0

         SELECT @nReplenBatchCount = Count(DISTINCT ReplenishmentKey)
         FROM dbo.Replenishment R WITH (NOLOCK)
         INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = R.ToLoc
         JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON LA.Lot = R.Lot
         WHERE R.StorerKey = @cStorerKey
         AND R.SKU = @cSuggSKU
         AND LA.Lottable02 = @cLottable02
         AND Loc.LocationType = 'DYNPICKP'
         AND R.Confirmed = 'S'
         AND R.ToLoc = @cToLoc
         AND R.Lot = @cLot
         AND R.ID  = @cID

         IF @nReplenBatchCount = 1  -- (james03)
         BEGIN
             SET @nReplenQty = @nOriginalQty
         END
         ELSE  -- @nReplenBatchCount > 1
         BEGIN
            SELECT @nReplenQty = SUM(RPL.OriginalQty)    -- take only the required replen qty (james03)
            FROM dbo.Replenishment RPL WITH (NOLOCK)
            INNER JOIN LotAttribute LA WITH (NOLOCK) ON (LA.Lot = RPL.Lot AND LA.StorerKey = RPL.StorerKey AND LA.SKU = RPL.SKU )
            Where RPL.StorerKey = @cStorerKey
            AND RPL.DropID      = @cDropID
            --AND RPL.Confirmed  IN ('N','S')
            AND RPL.Confirmed  = 'S'
            AND RPL.SKU        = @cSuggSKU
            AND RPL.TOLOC      = @cToLoc
            AND RPL.Lot        = @cLot
            AND RPL.ID         = @cID
         END
      END

      --SET @cOutField06 = CAST(@nPickQty AS NVARCHAR(5)) + '/' + CAST(@nReplenQty AS NVARCHAR(5))
      SET @cOutField06 = CAST(@nReplenQty AS NVARCHAR(5))
      SET @cOutField07 = ''
      SET @cOutField08 = ''  -- (ChewKP04)
      SET @cOutField10 = @nPickQty

      SET @cInQty = 0 -- (ChewKP04)
      SET @cSKU_Scanned = '' -- (ChewKP04)
      SET @cSKU  = @cSuggSKU  -- (ChewKP04)


      EXEC rdt.rdtSetFocusField @nMobile, 7

      --goto next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1

      GOTO Quit
   END

   IF @nInputKey = 0 --ESC
   BEGIN
      DELETE FROM RDT.RDTPickLock WHERE AddWho = @cUserName AND Status < '9'

      SET @cOutField01 = ''

      --goto prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1

      GOTO Quit
   END

   Step_2_Fail:
   BEGIN
      SET @cOutField01 = @cDropID
      SET @cOutField02 = @cSuggToLoc
      SET @cOutField03 = ''

   END
END
GOTO Quit

/********************************************************************************
Step 3. Scn = 2862.
   DROP ID  (field01)
   TOLOC    (field02)
   SKU      (field03)
   SKUDescr (field04)
   SKUDescr (field05)
   Qty      (field06)
   SKU      (field07, input)
   Qty      (field08, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      --screen mapping
      SET @cInSKU = @cInField07
      SET @cUCCSKU = ''
      SET @nUCCQty = 0

      -- (ChewKP04)
      SET @cInQty = @cInField08

      SET @cInField08 = @cInQty

      IF @cInQty = '0'
      BEGIN
         --SET @cActQty = ''
         SET @nErrNo = 73430
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY needed'
         EXEC rdt.rdtSetFocusField @nMobile, 8
         GOTO Step_3_Fail
      END

      IF @cInQty  = '' SET @cInQty = '0' --'Blank taken as zero'

      IF (RDT.rdtIsValidQTY( @cInQty, 0) = 0) OR  -- Zero not check
         (@cInQty = '0' AND @cSKU_Scanned <> '')  -- Zero and SKU not scanned once
      BEGIN
         --SET @cActQty = ''
         --SET @cOutField10 = CASE WHEN @nActQty > 0 THEN CAST( @nActQty AS NVARCHAR( 5)) ELSE '' END

         SET @nErrNo = 73430
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 8
         GOTO Step_3_Fail
      END



      -- Validate blank
      IF ISNULL(@cInSKU, '') = ''  AND  @cSKU_Scanned = '' -- (ChewKP04)
      BEGIN
         SET @nErrNo = 73409
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --SKU Req
         GOTO Step_3_Fail
      END

      -- Cater for UCC Input -- (Start) (ChewKP01)
      IF  EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                   WHERE UCCNo = @cInSKU
                   AND StorerKey = @cStorerKey)
      BEGIN
         SET @cUCC = @cInSKU
         SET @cUCCSKU = ''
         --SET @cLot = '' (SHONG001)
         SET @cLottable02 = ''

         IF NOT EXISTS (SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                    WHERE StorerKey = @cStorerKey
                    AND UCCNo = @cInSKU
                    AND Status = '4')
         BEGIN
            SET @nErrNo = 73427
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --INVALID UCC
            GOTO Step_3_Fail
         END

         SET  @nUCCQty = 0
         SET  @cUCCSKU = ''

         SELECT @cUCCSKU = UCC.SKU,
                --@cLot = UCC.Lot, (SHONG001)
                @nUCCQty = UCC.Qty
         FROM UCC WITH (NOLOCK)
         WHERE UCC.StorerKey = @cStorerKey
         AND UCC.UCCNo = @cUCC

         IF ISNULL(RTRIM(@cUCCSKU),'') = '' OR ISNULL(RTRIM(@cUCCSKU),'') <> @cSuggSKU
         BEGIN
            SET @nErrNo = 73424
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid UCC
            GOTO Step_3_Fail
         END

--         IF @cUCCStatus < '5'
--         BEGIN
--            SET @nErrNo = 73425                                          --12345678901234567890
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --73426^
--            GOTO Step_3_Fail
--         END

         IF ISNULL(RTRIM(@cLot),'') <> ''
         BEGIN
            SELECT @cLottable02 = LA.Lottable02
            FROM   LotAttribute LA WITH (NOLOCK)
            WHERE  LA.Lot = @cLot
         END
         ELSE
         BEGIN
          SET @cLottable02 = ''
         END

         IF ISNULL(RTRIM(@cLottable02),'') <> ''
         BEGIN
            SET @cValidateUCC = ''
            SELECT @cValidateUCC = SValue
            FROM dbo.StorerConfig WITH (NOLOCK)
            WHERE Configkey = 'GenDynLocReplenBySKUBatch'
            AND StorerKEy = @cStorerKey

            IF  @cValidateUCC = '1'
            BEGIN
               IF NOT EXISTS ( SELECT 1 FROM Replenishment RPL WITH (NOLOCK)
                               INNER JOIN LotAttribute LA WITH (NOLOCK) ON (LA.SKU = RPL.SKU AND LA.Lot = RPL.Lot)
                               WHERE RPL.StorerKey = @cStorerKey
                               AND RPL.SKU = @cUCCSKU
                               AND LA.Lottable02 = @cLottable02
                               )
               BEGIN
                   SET @nErrNo = 73421
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid UCC
                   GOTO Step_3_Fail
               END
            END
         END

/*
         IF @nPickQty + @nUCCQty > @nReplenQty
         BEGIN
            SET @nUCCQty = 0
            SET @nErrNo = 73425
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid Qty
            GOTO Step_3_Fail
         END
*/
         SET @nPickQTy = @nPickQTy + @nUCCQty

         IF @nPickQty >= @nReplenQty
         BEGIN
            BEGIN TRAN

            --- Update RDT Pick Lock to Status = '9'
            UPDATE RDT.RDTPICKLOCK WITH (ROWLOCK)
               SET Status = '9'
            WHERE Storerkey = @cStorerkey
             AND  DropID    = @cDropID
             AND  Loc       = @cToLoc
             AND  SKU       = @cUCCSKU

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 73422
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdateRPLFail
               GOTO Step_3_Fail
            END
            ELSE
            BEGIN
               COMMIT TRAN
            END

            INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3, COL4, COL5)
            VALUES ('rdt_DropID_Replen_To_B4_A', GETDATE(), @cLOT, @cToLoc, @cID, @cDropID, CAST(@nPickQty As NVARCHAR(5)))

            -- Confirm Replenishment By DropID , SKU
            EXEC [RDT].[rdt_DropID_Replen_To]
                 @nMobile
                ,@nFunc
                ,@cStorerKey
                ,@cUserName
                ,@cDropID
                ,@cUCCSKU
                ,@cToLoc         -- (james01)
                ,@cLangCode
                ,@nErrNo         OUTPUT
                ,@cErrMsg        OUTPUT
                ,@nPickQty
                ,@cLOT          -- SHONG001
                ,@cID           -- SHONG001


            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = '73423^UpdateRPLFail'
               --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdateRPLFail
               -- Deduct Pick Qty When Error -- (ChewKP02)
               IF  EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                            WHERE UCCNo = @cUCC
                            AND StorerKey = @cStorerKey)
               BEGIN
                  SET @nPickQTy = @nPickQTy - @nUCCQty
               END

               GOTO Step_3_Fail
            END


            INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3, COL4, COL5)
            SELECT TOP 1 'rdt_DropID_Replen_To_After', GETDATE(),
                   LOT, ToLOC, ID, DropID, CAST(SUM(OriginalQty) AS NVARCHAR(6))
            FROM REPLENISHMENT RPL WITH (NOLOCK)
            WHERE RPL.StorerKey = @cStorerKey
              AND RPL.DropID = @cDropID
              AND RPL.ToLoc  = @cToLoc
              AND RPL.Confirmed = 'S'
              AND RPL.LOT = @cLOT
              AND RPL.ID = @cID
            GROUP BY  LOT, ToLOC, ID, DropID


            GOTO GET_NEXTTASK
         END -- IF @nPickQty >= @nReplenQty
         ELSE
         BEGIN
            BEGIN TRAN
            -- Update UCC status to mark it as finished replen to (james04)
            UPDATE dbo.UCC WITH (ROWLOCK) SET
               Status = '6',
               EditWho = 'rdt.' + suser_sname(),
               EditDate = GETDATE()
            WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCC
            AND Status = '4'

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @nErrNo = 73428
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
               GOTO Step_3_Fail
            END
            ELSE
            BEGIN
               COMMIT TRAN
            END

            -- Display Same Screen with Outstanding Qty
            -- (ChewKP02)
            SELECT
               @cSKUDescr   = S.Descr
            FROM dbo.SKU S WITH (NOLOCK)
            WHERE   S.Storerkey   = @cStorerkey
            AND     S.SKU = @cUCCSKU

            SET @cOutField01 = @cDropID
            SET @cOutField02 = @cToLoc
            SET @cOutField03 = @cUCCSKU     -- (ChewKP02)
            SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
            SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
            SET @cOutField06 = CAST(@nReplenQty AS NVARCHAR(5))  -- (ChewKP04)
            SET @cOutField07 = ''
            SET @cOutField08 = @nPickQty  -- (ChewKP04)
            SET @cOutField10 = CAST( @nPickQty AS NVARCHAR( 5))

            EXEC rdt.rdtSetFocusField @nMobile, 7

            GOTO QUIT
         END
      END -- IF Exists in UCC table


      IF NOT EXISTS ( SELECT 1 FROM UCC WITH (NOLOCK) WHERE UCCNO = @cInSKU AND StorerKey = @cStorerKey)
      BEGIN
         IF (@cSKU_Scanned = '') OR (ISNULL(@cInSKU, '') <> ISNULL(@cSuggSKU,''))
         BEGIN

            IF ISNULL(@cInSKU, '') <> ISNULL(@cSuggSKU,'')
            BEGIN
               SET @nErrNo = 73410
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid SKU
               GOTO Step_3_Fail
            END

            EXEC [RDT].[rdt_GETSKU]
              @cStorerKey  = @cStorerkey,
              @cSKU        = @cInSKU        OUTPUT,
              @bSuccess    = @b_Success     OUTPUT,
              @nErr        = @nErrNo        OUTPUT,
              @cErrMsg     = @cErrMsg       OUTPUT

            IF @nErrNo <> 0
            BEGIN
              SET @nErrNo = 73412
              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU

              GOTO Step_3_Fail
            END
         END


         -- (ChewKP04)
         IF @cSKU  = @cInSKU
         BEGIN
            SET @cSKU  = @cInSKU

            IF @nPickQTy = CAST(@cInQty AS INT) -- Scan piece
               SET @nPickQTy = @nPickQTy + 1
            ELSE
               SET @nPickQty = CAST(@cInQty AS INT) --user key QTY  -- (james05)

            SET @cSKU_Scanned = @cInSKU -- make sure sku scanned at least once

            IF @nPickQty < @nReplenQty
            BEGIN
               -- (ChewKP02)
               SELECT
                  @cSKUDescr   = S.Descr
               FROM dbo.SKU S WITH (NOLOCK)
               WHERE   S.Storerkey   = @cStorerkey
               AND     S.SKU = @cSKU

               SET @cOutField01 = @cDropID
               SET @cOutField02 = @cToLoc
               SET @cOutField03 = @cSKU      -- (ChewKP02)
               SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
               SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
                --SET @cOutField06 = CAST(@nPickQty AS NVARCHAR(5)) + '/' + CAST(@nReplenQty AS NVARCHAR(5))
               SET @cOutField06 = CAST(@nReplenQty AS NVARCHAR(5))  -- (ChewKP04)
               SET @cOutField07 = ''
               SET @cOutField08 = @nPickQty  -- (ChewKP04)
               SET @cOutField10 = @nPickQty

               EXEC rdt.rdtSetFocusField @nMobile, 7

               GOTO QUIT
            END

         END


         IF ISNULL(@cSKU_Scanned, '') = ''
         BEGIN
            SET @nErrNo = 73432
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Min scan once'
            EXEC rdt.rdtSetFocusField @nMobile, 7
            GOTO Step_3_Fail
         END


--         SET @nPickQty = CAST(@cInQty AS INT) -- (james05)


         IF @nPickQty < @nReplenQty
         BEGIN
            -- (ChewKP02)
            SELECT
               @cSKUDescr   = S.Descr
            FROM dbo.SKU S WITH (NOLOCK)
            WHERE   S.Storerkey   = @cStorerkey
            AND     S.SKU = @cSKU

            SET @cOutField01 = @cDropID
            SET @cOutField02 = @cToLoc
            SET @cOutField03 = @cSKU      -- (ChewKP02)
            SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
            SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
            --SET @cOutField06 = CAST(@nPickQty AS NVARCHAR(5)) + '/' + CAST(@nReplenQty AS NVARCHAR(5))
            SET @cOutField06 = CAST(@nReplenQty AS NVARCHAR(5))  -- (ChewKP04)
            SET @cOutField07 = ''
            SET @cOutField08 = @nPickQty  -- (ChewKP04)
            SET @cOutField10 = @nPickQty
            EXEC rdt.rdtSetFocusField @nMobile, 7

            GOTO QUIT
         END
      END -- If Scan SKU

      BEGIN TRAN

      --- Update RDT Pick Lock to Status = '9'
      UPDATE RDT.RDTPICKLOCK WITH (ROWLOCK)
         SET Status = '9'
      WHERE Storerkey = @cStorerkey
       AND  DropID    = @cDropID
       AND  Loc       = @cToLoc
       AND  SKU       = @cSKU


      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         SET @nErrNo = 73411
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdateRPLFail
         GOTO Step_3_Fail
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END

      INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3, COL4, COL5)
      VALUES ('rdt_DropID_Replen_To_B4_B', GETDATE(), @cLOT, @cToLoc, @cID, @cDropID, CAST(@nPickQty As NVARCHAR(5)))

      -- Confirm Replenishment By DropID , SKU
      EXEC [RDT].[rdt_DropID_Replen_To]
           @nMobile
          ,@nFunc
          ,@cStorerKey
          ,@cUserName
          ,@cDropID
          ,@cSKU
          ,@cToLoc               -- (james01)
          ,@cLangCode
          ,@nErrNo         OUTPUT
          ,@cErrMsg        OUTPUT
          ,@nPickQty
          ,@cLOT          -- SHONG001
          ,@cID           -- SHONG001

      IF @nErrNo <> 0
      BEGIN
         --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdateRPLFail
         --SET @cErrMsg = '73423^UpdateRPLFail'
         -- Deduct Pick Qty When Error -- (ChewKP02)
         IF NOT EXISTS ( SELECT 1 FROM UCC WITH (NOLOCK) WHERE UCCNO = @cInSKU AND StorerKey = @cStorerKey)
         BEGIN
            SET @nPickQTy = CAST(@cInQty AS INT)
         END

         GOTO Step_3_Fail
      END
      ELSE
      BEGIN
         INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3, COL4, COL5)
         SELECT TOP 1 'rdt_DropID_Replen_To_After', GETDATE(),
                LOT, ToLOC, ID, DropID, CAST(SUM(OriginalQty) AS NVARCHAR(6))
         FROM REPLENISHMENT RPL WITH (NOLOCK)
         WHERE RPL.StorerKey = @cStorerKey
           AND RPL.DropID = @cDropID
           AND RPL.ToLoc  = @cToLoc
           AND RPL.Confirmed = 'S'
           AND RPL.LOT = @cLOT
           AND RPL.ID = @cID
         GROUP BY  LOT, ToLOC, ID, DropID

--         BEGIN TRAN
--         -- Update UCC status to mark it as finished replen to (james04)
--         UPDATE dbo.UCC WITH (ROWLOCK) SET
--            Status = '6',
--            EditWho = 'rdt.' + suser_sname(),
--            EditDate = GETDATE()
--         WHERE StorerKey = @cStorerKey
--         AND UCCNo = @cUCC
--         AND Status = '5'
--
--         IF @@ERROR <> 0
--         BEGIN
--            ROLLBACK TRAN
--            SET @nErrNo = 73428
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
--            GOTO Step_3_Fail
--         END
--         ELSE
--         BEGIN
--            COMMIT TRAN
--         END
      END
      -- Access By UCC
      GET_NEXTTASK:

      SET @cLOT = ''  -- (SHONG001)
      SET @cID  = ''  -- (SHONG001)

      -- Get Next SKU from Same Loc
      SELECT TOP 1
          @cSuggSKU    = RPL.SKU
         ,@cSKUDescr   = S.Descr
         ,@nReplenQty  = SUM(RPL.Qty)
         ,@nOriginalQty = SUM(RPL.OriginalQty) -- (ChewKP01)
         ,@cLottable02  = LA.Lottable02 -- (ChewKP03)
         ,@cLot         = RPL.Lot -- (ChewKP03)
         ,@cID          = RPL.ID  -- (ChewKP03)
      FROM dbo.Replenishment RPL WITH (NOLOCK)
      JOIN dbo.SKU S WITH (NOLOCK) ON (RPL.StorerKey = S.StorerKey AND RPL.SKU = S.SKU)
      JOIN dbo.Loc LOC WITH (NOLOCK) ON (LOC.LOC = RPL.TOLOC)
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.Lot = RPL.Lot)   -- (james02)
      WHERE RPL.StorerKey = @cStorerKey
        AND RPL.DropID = @cDropID
        AND RPL.ToLoc  = @cToLoc
        AND RPL.Confirmed = 'S'
        AND NOT EXISTS (  -- not being locked by other picker
                       SELECT 1 FROM RDT.RDTPickLock RL WITH (NOLOCK)
                          WHERE RPL.StorerKey = RL.StorerKey
                             AND RPL.FROMLOC = RL.LOC
                             AND RL.AddWho <> @cUserName
                             AND RPL.DropID = RL.DropID
                             AND Status < '9')
      GROUP BY Loc.LogicalLocation,RPL.LOT, RPL.TOLOC, RPL.SKU, S.Descr, LA.Lottable02, RPL.Lot, RPL.ID    -- (james02)
      ORDER BY Loc.LogicalLocation, RPL.SKU

      IF @@RowCount <> 0
      BEGIN
         SET @nPickQty = 0

         SET @cOutField01 = @cDropID
         SET @cOutField02 = @cToLoc
         SET @cOutField03 = @cSuggSKU
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
         SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2

         SET @cReplenToByBatch = ''
         SET @cReplenToByBatch = rdt.RDTGetConfig( @nFunc, 'ReplenToByBatch', @cStorerKey)

         IF @cReplenToByBatch = '1'
         BEGIN
               -- (ChewKP03)
            SET @nReplenBatchCount = 0
            SET @nReplenQty = 0

            SELECT @nReplenBatchCount = Count(DISTINCT ReplenishmentKey) FROM dbo.Replenishment R WITH (NOLOCK)
            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = R.ToLoc
                        JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON LA.Lot = R.Lot
                        WHERE R.StorerKey = @cStorerKey
                        AND R.SKU = @cSuggSKU
                        AND LA.Lottable02 = @cLottable02
                        AND Loc.LocationType = 'DYNPICKP'
                        AND R.Confirmed = 'S'
                        AND R.ToLoc = @cToLoc
                        AND R.ID = @cID
                        AND R.Lot = @cLot

            IF @nReplenBatchCount = 0
            BEGIN
                SET @nReplenQty = @nOriginalQty
            END
            ELSE
            BEGIN

               SELECT @nReplenQty = SUM(RPL.OriginalQTY)
               FROM dbo.Replenishment RPL WITH (NOLOCK)
               INNER JOIN LotAttribute LA WITH (NOLOCK) ON (LA.Lot = RPL.Lot AND LA.StorerKey = RPL.StorerKey AND LA.SKU = RPL.SKU )
               Where RPL.StorerKey   = @cStorerKey
               AND RPL.DropID     = @cDropID
               --AND RPL.Confirmed  IN ('N','S')
               AND RPL.Confirmed  = 'S'
               AND RPL.SKU        = @cSuggSKU
               AND RPL.TOLOC      = @cToLoc
               AND RPL.ID = @cID
               AND RPL.Lot = @cLot
            END

         END

--SET @cOutField06 = CAST(@nPickQty AS NVARCHAR(5)) + '/' + CAST(@nReplenQty AS NVARCHAR(5)) -- (ChewKP01)
         SET @cOutField06 = CAST(@nReplenQty AS NVARCHAR(5))  -- (ChewKP04)
         SET @cOutField07 = ''
         SET @cOutField08 = @nPickQty  -- (ChewKP04)
         SET @cOutField10 = @nPickQty

         EXEC rdt.rdtSetFocusField @nMobile, 7

         GOTO Quit
      END
      ELSE
      BEGIN
         SET @cLOT = ''  -- (SHONG001)
         SET @cID  = ''  -- (SHONG001)

         -- No More Task from Current Location , Get from Another Loc
         SELECT TOP 1
                @cSuggSKU    = RPL.SKU
               ,@cSKUDescr   = S.Descr
               ,@nReplenQty  = SUM(RPL.Qty)
               ,@nOriginalQty = SUM(RPL.OriginalQty) -- (ChewKP01)
               ,@cLottable02  = LA.Lottable02 -- (ChewKP03)
               ,@cLot         = RPL.Lot -- (ChewKP03)
               ,@cID          = RPL.ID  -- (ChewKP03)
         FROM dbo.Replenishment RPL WITH (NOLOCK)
         JOIN dbo.SKU S WITH (NOLOCK) ON (RPL.StorerKey = S.StorerKey AND RPL.SKU = S.SKU)
         JOIN dbo.Loc LOC WITH (NOLOCK) ON (LOC.LOC = RPL.TOLOC)
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.Lot = RPL.Lot)   -- (james02)
         WHERE RPL.StorerKey = @cStorerKey
           AND RPL.DropID = @cDropID
           AND RPL.Confirmed = 'S'
           AND NOT EXISTS (  -- not being locked by other picker
                          SELECT 1 FROM RDT.RDTPickLock RL WITH (NOLOCK)
                             WHERE RPL.StorerKey = RL.StorerKey
                                AND RPL.FROMLOC = RL.LOC
                                AND RL.AddWho <> @cUserName
                                AND RPL.DropID = RL.DropID
                                AND Status < '9')
         GROUP BY Loc.LogicalLocation, RPL.TOLOC, RPL.SKU, S.Descr, LA.Lottable02, RPL.Lot, RPL.ID
         ORDER BY Loc.LogicalLocation, RPL.SKU

         IF @@RowCount <> 0
         BEGIN
            SET @cOutField01 = @cDropID

            -- Goto Next Loc screen
            SET @nScn  = @nScnNextLoc
            SET @nStep = @nStepNextLoc

            GOTO Quit
         END
         ELSE
         BEGIN
            SET @nScn  =  @nScnNoTask
            SET @nStep =  @nStepNoTask

            GOTO QUIT
         END
      END
   END

   IF @nInputKey = 0 --ESC
   BEGIN
      -- (ChewKP02)
      SELECT
         @cSKUDescr   = S.Descr
      FROM dbo.SKU S WITH (NOLOCK)
      WHERE   S.Storerkey   = @cStorerkey
      AND     S.SKU = @cSuggSKU

      SET @cOutField01 = @cDropID
      SET @cOutField02 = @cToLoc
      SET @cOutField03 = @cSuggSKU  -- (ChewKP02)
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
      SET @cOutField06 = @nReplenQty
      SET @cOutField07 = ''
      SET @cOutField08 = ''  -- (ChewKP04)
      SET @cOutField10 = @nPickQty

      --goto prev screen
      SET @nScn  = @nScnSkipSKU
      SET @nStep = @nStepSkipSKU

      GOTO Quit
   END

   Step_3_Fail:
   BEGIN
      --SET @cLot =''
      --SET @cID  ='' -- (SHONG001)
      --SET @cLottable02 = ''
      --SET @nUCCQty = 0
      --SET @cSKU = ''
      SET @cOutField07 = ''
      --SET @cOutField08 = ''  -- (ChewKP04)

      SET @cOutField10 = @nPickQty
   END
END
GOTO Quit

/********************************************************************************
Step 4. Scn = 2683.
   DropID   (field01)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      --screen mapping

      SET @cOutField01 = ''

      --goto next screen
      SET @nScn  = @nScnDropID
      SET @nStep = @nStepDropID

   END
END
GOTO Quit


/********************************************************************************
Step 5. Scn = 2684.
   DROP ID  (field01)
   TOLOC    (field02)
   SKU      (field03)
   SKUDescr (field04)
   SKUDescr (field05)
   Qty      (field06)
   Option   (field07, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN

      SET @cOption = ISNULL(@cInField07,'')

      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 73413
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option needed'
         GOTO Step_5_Fail
      END

      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 73414
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'
         GOTO Step_5_Fail
      END

      IF @cOption = '1'
      BEGIN
         BEGIN TRAN

         UPDATE REPLENISHMENT
            SET Remark = 'SKIP'
         WHERE DropID        = @cDropID
            AND ToLoc         = @cToLoc
            AND Confirmed     = 'S'
            AND SKU           = @cSuggSKU
            AND Storerkey     = @cStorerkey

         IF @@Error <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 73419
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdateRPLFail'
            GOTO Step_5_Fail
         END
         ELSE
         BEGIN
            COMMIT TRAN
         END

         SELECT TOP 1
              @cSuggTOLOC = RPL.TOLOC
         FROM dbo.Replenishment RPL WITH (NOLOCK)
         JOIN dbo.SKU S WITH (NOLOCK) ON (RPL.StorerKey = S.StorerKey AND RPL.SKU = S.SKU)
         JOIN dbo.Loc LOC WITH (NOLOCK) ON (LOC.LOC = RPL.TOLOC)
         WHERE RPL.StorerKey = @cStorerKey
          AND RPL.DropID = @cDropID
          AND RPL.Confirmed = 'S'
          AND RPL.Remark <> 'SKIP'
          AND NOT EXISTS (  -- not being locked by other picker
                         SELECT 1 FROM RDT.RDTPickLock RL WITH (NOLOCK)
                            WHERE RPL.StorerKey = RL.StorerKey
                               AND RPL.FROMLOC = RL.LOC
                               AND RL.AddWho <> @cUserName
                               AND RPL.DropID = RL.DropID
               AND Status < '9')
         --               GROUP BY Loc.LogicalLocation,RPL.ReplenishmentKey, RPL.LOT, RPL.ID, RPL.TOLOC, RPL.SKU
         --               ORDER BY Loc.LogicalLocation, RPL.SKU
         GROUP BY RPL.Priority, RPL.TOLOC, RPL.EditDate
         ORDER BY RPL.Priority, RPL.EditDate DESC       -- Get the 1st carton that is stacking onto pallet -- (ChewKP01)
                                       -- For example, replen from seq is case1, case2, case3
                                       -- replen to is case3, case2, case1
         IF @@RowCount <> 0
         BEGIN
            BEGIN TRAN

            INSERT INTO RDT.RDTPickLock
            (WaveKey, StorerKey, LOC, LOT, ID,
            Status, AddWho, AddDate, PickdetailKey, SKU, Descr, PickQty, DropID,
            Loadkey,OrderKey, PutawayZone, PickZone, OrderLineNumber)
            SELECT
               '',
                 @cStorerkey,
                 @cSuggToLoc,
                 RPL.LOT,
                 RPL.ID,
                 '1',
                 @cUserName,
                 GetDate(),
                 RPL.ReplenishmentKey,
                 RPL.SKU,
                 S.DESCR,
                 ISNULL(SUM(RPL.Qty), 0), --,
                 RPL.DropID,
            --             @nOutstandingQTY = ISNULL(SUM(RPL.OriginalQty - RPL.QTY), 0)
              '', '','','',''
            FROM dbo.Replenishment RPL WITH (NOLOCK)
            JOIN dbo.SKU S WITH (NOLOCK) ON (RPL.StorerKey = S.StorerKey AND RPL.SKU = S.SKU)
            WHERE RPL.StorerKey  = @cStorerKey
               AND RPL.ToLoc     = @cSuggTOLOC
               AND RPL.Confirmed = 'S'
               AND RPL.DropID    = @cDropID
            GROUP BY RPL.ReplenishmentKey, RPL.LOT, RPL.ID,
                     RPL.SKU, S.DESCR, RPL.DropID
            ORDER BY RPL.SKU

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN

               SET @nErrNo = 73415
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Ins RPL Failed
               GOTO Step_5_Fail
            END
            ELSE
            BEGIN
               COMMIT TRAN
            END
         END
         ELSE
         BEGIN
            SET @nScn  =  @nScnNoTask
            SET @nStep =  @nStepNoTask

            GOTO QUIT
         END

         SET @cOutField01 = @cDropID
         SET @cOutField02 = @cSuggTOLOC
         SET @cOutField03 = ''

         --goto next screen
         SET @nScn  = @nScnToLoc
         SET @nStep = @nStepToLoc
      END

      IF @cOption = '2'
      BEGIN
         SET @cOutField01 = @cDropID
         SET @cOutField02 = @cToLoc
         SET @cOutField03 = @cSuggSKU
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
         SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
         --SET @cOutField06 = CAST(@nPickQty AS NVARCHAR(5)) + '/' + CAST(@nReplenQty AS NVARCHAR(5)) -- (ChewKP01)
         SET @cOutField06 = CAST(@nReplenQty AS NVARCHAR(5))  -- (ChewKP04)
         SET @cOutField07 = ''
         SET @cOutField08 = @nPickQty  -- (ChewKP04)
         SET @cOutField10 = @nPickQty
         EXEC rdt.rdtSetFocusField @nMobile, 7

         --goto prev screen
         SET @nScn  = @nScnSKU
         SET @nStep = @nStepSKU

         GOTO Quit
      END

   END

   IF @nInputKey = 0 --ESC
   BEGIN


      SET @cOutField01 = @cDropID
      SET @cOutField02 = @cToLoc
      SET @cOutField03 = @cSuggSKU
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)  -- SKU desc 1
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) -- SKU desc 2
      --SET @cOutField06 = CAST(@nPickQty AS NVARCHAR(5)) + '/' + CAST(@nReplenQty AS NVARCHAR(5)) -- (ChewKP01)
      SET @cOutField06 = CAST(@nReplenQty AS NVARCHAR(5))  -- (ChewKP04)
      SET @cOutField07 = ''
      SET @cOutField08 = ''  -- (ChewKP04)
      SET @cOutField10 = @nPickQty

      EXEC rdt.rdtSetFocusField @nMobile, 7

      --goto prev screen
      SET @nScn  = @nScnSKU
      SET @nStep = @nStepSKU

      GOTO Quit
   END

   Step_5_Fail:
   BEGIN

      SET @cOutField07 = ''
      SET @cOutField08 = ''  -- (ChewKP04)
      SET @cOutField10 = @nPickQty
   END

END
GOTO Quit

/********************************************************************************
Step 6. Scn = 2864.
   DropID   (field03)
   No More SKU in this LoC (field04)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      SELECT TOP 1
         @cSuggTOLOC = RPL.TOLOC
      FROM dbo.Replenishment RPL WITH (NOLOCK)
      JOIN dbo.SKU S WITH (NOLOCK) ON (RPL.StorerKey = S.StorerKey AND RPL.SKU = S.SKU)
      JOIN dbo.Loc LOC WITH (NOLOCK) ON (LOC.LOC = RPL.TOLOC)
      WHERE RPL.StorerKey = @cStorerKey
      AND RPL.DropID = @cDropID
      AND RPL.Confirmed = 'S'
      AND NOT EXISTS (  -- not being locked by other picker
                      SELECT 1 FROM RDT.RDTPickLock RL WITH (NOLOCK)
                      WHERE RPL.StorerKey = RL.StorerKey
                         AND RPL.FROMLOC = RL.LOC
                         AND RL.AddWho <> @cUserName
                         AND RPL.DropID = RL.DropID
                         AND Status < '9')
      --          GROUP BY Loc.LogicalLocation, RPL.ReplenishmentKey, RPL.LOT, RPL.ID, RPL.TOLOC, RPL.SKU
      --          ORDER BY Loc.LogicalLocation, RPL.SKU
      GROUP BY RPL.Priority, RPL.TOLOC, RPL.EditDate
      ORDER BY RPL.Priority, RPL.EditDate DESC       -- Get the 1st carton that is stacking onto pallet -- (ChewKP01)
                                       -- For example, replen from seq is case1, case2, case3
                                       -- replen to is case3, case2, case1

      IF @@RowCount <> 0
      BEGIN
         BEGIN TRAN

         INSERT INTO RDT.RDTPickLock
         (WaveKey, StorerKey, LOC, LOT, ID,
         Status, AddWho, AddDate, PickdetailKey, SKU, Descr, PickQty, DropID,
         Loadkey,OrderKey, PutawayZone, PickZone, OrderLineNumber)
         SELECT
         '',
         @cStorerkey,
         @cSuggToLoc,
         RPL.LOT,
         RPL.ID,
         '1',
         @cUserName,
         GetDate(),
         RPL.ReplenishmentKey,
         RPL.SKU,
         S.DESCR,
         ISNULL(SUM(RPL.Qty), 0), --,
         RPL.DropID,
         --      @nOutstandingQTY = ISNULL(SUM(RPL.OriginalQty - RPL.QTY), 0)
         '', '','','',''
         FROM dbo.Replenishment RPL WITH (NOLOCK)
         JOIN dbo.SKU S WITH (NOLOCK) ON (RPL.StorerKey = S.StorerKey AND RPL.SKU = S.SKU)
         WHERE RPL.StorerKey  = @cStorerKey
            AND RPL.ToLoc     = @cSuggTOLOC
            AND RPL.Confirmed = 'S'
            AND RPL.DropID    = @cDropID
         GROUP BY RPL.ReplenishmentKey, RPL.LOT, RPL.ID,
                  RPL.SKU, S.DESCR, RPL.DropID
         ORDER BY RPL.SKU

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN

            SET @nErrNo = 73417
       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Ins RPL Failed
            --GOTO Step_7_Fail
         END
         ELSE
         BEGIN
            COMMIT TRAN
         END
      END
      ELSE
      BEGIN
         SET @nErrNo = 73418
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --No Loc Found
         --GOTO Step__Fail
      END

      SET @cOutField01 = @cDropID
      SET @cOutField02 = @cSuggTOLOC
      SET @cOutField03 = ''

      --goto next screen
      SET @nScn  = @nScnToLoc
      SET @nStep = @nStepToLoc

      GOTO QUIT
   END

   IF @nInputKey = 0 --ESC
   BEGIN
      SET @cOutField01 = ''

      --goto prev screen
      SET @nScn  = @nScnDropID
      SET @nStep = @nStepDropID

      GOTO Quit
   END
END
GOTO Quit

/********************************************************************************
Step 7. Scn = 2866.
   No Task
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      -- Go to Screen 1
      SET @cOutField01 = ''
      SET @cOutField02 = ''

      SET @nScn  = @nScnDropID
      SET @nStep = @nStepDropID
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate     = GETDATE(), 
      ErrMsg       = @cErrMsg,
      Func         = @nFunc,
      Step         = @nStep,
      Scn          = @nScn,

      StorerKey    = @cStorerKey,
      Facility     = @cFacility,
      Printer      = @cPrinter,
      -- UserName     = @cUserName,

      V_LOT        = @cLOT,   -- SHONG001
      V_ID         = @cID,    -- SHONG001
      V_Loc        = @cToLoc,
      V_Loadkey    = @cLoadKey,
      V_SKU        = @cSKU,
      V_SKUDescr   = @cSKUDescr,
      
      V_Integer1   = @nReplenQty,
      V_Integer2   = @nPickQty,

      V_String1    = @cDropID          ,
      V_String2    = @cReplenishmentKey,
      V_String3    = @cSuggToLoc       ,

      V_String4    = @cSuggSKU,
      --V_String5    = @nReplenQty,
      --V_String6    = @nPickQty,
      V_String7    = @cSKU_Scanned,


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