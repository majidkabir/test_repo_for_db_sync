SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_DropID_Consolidation                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: DropID consolidation                                        */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 26-Aug-2022 1.0  yeekung  WMS-20381 - Created                        */
/* 14-Mar-2023 1.1  yeekung  JSM-135615 Fix dropid  (yeekung01)         */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_DropID_Consolidation] (
   @nMobile    INT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE
   @b_success       INT,
   @n_err           INT,
   @c_errmsg        NVARCHAR(250),
   @nSKUCnt         INT

DECLARE
   @cSQL          NVARCHAR(1000),     
   @cSQLParam     NVARCHAR(1000)    
   
-- RDT.RDTMobRec variables
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nInputKey           INT,
   @nMenu               INT,

   @cStorerKey          NVARCHAR( 15),
   @cUserName           NVARCHAR( 18),
   @cFacility           NVARCHAR( 5),
   @cLOC                NVARCHAR( 10),
   @cDropID             NVARCHAR( 20),
   @cOrderKey           NVARCHAR( 20),

   @cPickZone           NVARCHAR( 10),
   @cPrinter            NVARCHAR( 10),
   @cPrinter_Paper      NVARCHAR( 10), 
   @nPickZone_Cnt       INT, 
   @nTranCount          INT, 
   @cPickSlipNo         NVARCHAR( 10),
   @cLoadKey            NVARCHAR( 10),
   @cWaveKey            NVARCHAR( 10),
   @cExtendedInfoSP     NVARCHAR( 20),     
   @cExtendedInfo       NVARCHAR( 20),     


   @cInField01 NVARCHAR(60),   @cOutField01 NVARCHAR(60),
   @cInField02 NVARCHAR(60),   @cOutField02 NVARCHAR(60),
   @cInField03 NVARCHAR(60),   @cOutField03 NVARCHAR(60),
   @cInField04 NVARCHAR(60),   @cOutField04 NVARCHAR(60),
   @cInField05 NVARCHAR(60),   @cOutField05 NVARCHAR(60),
   @cInField06 NVARCHAR(60),   @cOutField06 NVARCHAR(60),
   @cInField07 NVARCHAR(60),   @cOutField07 NVARCHAR(60),
   @cInField08 NVARCHAR(60),   @cOutField08 NVARCHAR(60),
   @cInField09 NVARCHAR(60),   @cOutField09 NVARCHAR(60),
   @cInField10 NVARCHAR(60),   @cOutField10 NVARCHAR(60),
   @cInField11 NVARCHAR(60),   @cOutField11 NVARCHAR(60),
   @cInField12 NVARCHAR(60),   @cOutField12 NVARCHAR(60),
   @cInField13 NVARCHAR(60),   @cOutField13 NVARCHAR(60),
   @cInField14 NVARCHAR(60),   @cOutField14 NVARCHAR(60),
   @cInField15 NVARCHAR(60),   @cOutField15 NVARCHAR(60),

   -- (Vicky02) - Start
   @cFieldAttr01 NVARCHAR(1), @cFieldAttr02 NVARCHAR(1),
   @cFieldAttr03 NVARCHAR(1), @cFieldAttr04 NVARCHAR(1),
   @cFieldAttr05 NVARCHAR(1), @cFieldAttr06 NVARCHAR(1),
   @cFieldAttr07 NVARCHAR(1), @cFieldAttr08 NVARCHAR(1),
   @cFieldAttr09 NVARCHAR(1), @cFieldAttr10 NVARCHAR(1),
   @cFieldAttr11 NVARCHAR(1), @cFieldAttr12 NVARCHAR(1),
   @cFieldAttr13 NVARCHAR(1), @cFieldAttr14 NVARCHAR(1),
   @cFieldAttr15 NVARCHAR(1)
   -- (Vicky02) - End

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,
   @cPrinter         = Printer,
   @cPrinter_Paper   = Printer_Paper, 

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cOrderKey        = V_OrderKey, 
   @cLOC             = V_LOC, 

   @cPickZone        = V_String1, 
   @cDropID          = V_String2,

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

   -- (Vicky02) - Start
   @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15
   -- (Vicky02) - End

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 992	
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0    -- Menu. Func = 992	
   IF @nStep = 1  GOTO Step_1    -- Scn = 6110. DropID, PICKZONE,LOC
   IF @nStep = 2  GOTO Step_2    -- Scn = 6111. DropID, PICKZONE,LOC
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 544. Screen 0.
********************************************************************************/
Step_0:
BEGIN
   -- (Vicky02) - Start
   SET @cFieldAttr01 = ''
   SET @cFieldAttr02 = ''
   SET @cFieldAttr03 = ''
   SET @cFieldAttr04 = ''
   SET @cFieldAttr05 = ''
   SET @cFieldAttr06 = ''
   SET @cFieldAttr07 = ''
   SET @cFieldAttr08 = ''
   SET @cFieldAttr09 = ''
   SET @cFieldAttr10 = ''
   SET @cFieldAttr11 = ''
   SET @cFieldAttr12 = ''
   SET @cFieldAttr13 = ''
   SET @cFieldAttr14 = ''
   SET @cFieldAttr15 = ''
   -- (Vicky02) - End

   -- Prev next screen var
   SET @cDropID = ''
   SET @cPickZone = ''
   SET @cLOC = ''

   SET @cOutField01 = ''
   SET @cOutField02 = ''

   SET @nScn = 6110
   SET @nStep = 1

   EXEC rdt.rdtSetFocusField @nMobile, 1  -- 
END
GOTO Quit

/************************************************************************************
Step_1. Scn = 6110. Screen 1.
   DropID   (field01)   - Input field
   Pick Zone   (field02)   - Input field
   Loc  (field03)   - Input field
************************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cDropID = @cInField01   
      SET @cPickZone = @cInField02   
      SET @cLOC = @cInField03

      -- Validate blank
      IF ISNULL(@cDropID, '') = ''
      BEGIN
         SET @nErrNo = 85901
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDNeed
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_DropID_Fail
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.pickdetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                     AND   dropid = @cDropID
                     AND status <'9')
      BEGIN
         SET @nErrNo = 190452
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidDropID
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_DropID_Fail
      END

      SELECT TOP 1 @cPickSlipNo = pickslipno 
      FROM dbo.pickdetail PH WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND   dropid = @cDropID
         AND status <'9'

      -- Validate blank
      IF ISNULL(@cPickZone, '') = ''
      BEGIN
         SELECT  TOP 1 @cPickZone=pickzone,
                @cLOC = DP.LOC
         FROM rdt.rdtPickConsoLog DP (nolock)
         JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey=DP.Orderkey 
         WHERE  PD.pickslipno = @cPickslipNo
            AND PD.storerkey = @cStorerkey
            and pd.status < '5'
         order by DP.adddate desc; --(yeekung01)

         IF ISNULL(@cPickZone, '') = ''
         BEGIN
            SET @nErrNo = 190453
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PICKZONE REQ
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_1_PickZone_Fail
         END
      END

      -- Validate blank
      IF ISNULL(@cLOC, '') = ''
      BEGIN
         SET @nErrNo = 190454
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Loc Needed
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_Loc_Fail
      END

      IF NOT EXISTS(SELECT 1
                     FROM dbo.LOC LOC WITH (NOLOCK) 
                     WHERE LOC.Facility = @cFacility
                     AND   LOC.LocationCategory = 'SORTING'
                     AND   Loc = @cLOC)
      BEGIN
         SET @nErrNo = 190455
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PICKZONE REQ
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_Loc_Fail
      END

      IF EXISTS (SELECT 1
               FROM rdt.rdtPickConsoLog PCL (nolock)
               JOIN PICKDETAIL PD ON PD.orderkey=pcl.orderkey and pcl.sku=pd.sku and pcl.dropid=pd.dropid
               WHERE pd.pickslipno <> @cPickslipno 
               AND   PCL.status <'9'
               AND   PCL.Loc = @cLOC
               AND   storerkey=@cStorerkey)
      BEGIN
         SET @nErrNo = 190458
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LocisSorted
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_Loc_Fail
      END

      
      SET @nTranCount = @@TRANCOUNT  
         
      BEGIN TRAN  
      SAVE TRAN rdtPickConsoLog_Insert  

      IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPickConsoLog dp WITH (NOLOCK) 
                       WHERE EXISTS( SELECT 1
                           FROM PICKDETAIL PD(NOLOCK)
                           where pickslipno=@cpickslipno
                              AND storerkey=@cstorerkey
                              AND status <'9'
                              AND pd.dropid=@cDropID
                              AND pd.orderkey=dp.orderkey)
                           AND dp.dropid=@cDropID
                        )
                        
      BEGIN
         INSERT INTO rdt.rdtPickConsoLog (Orderkey, PickZone, SKU, LOC, [Status], AddWho, AddDate, Mobile,DropID) 
         Select orderkey,@cPickZone,sku,@cLOC,'1',sUser_sName(), GETDATE(), @nMobile,@cDropID
         FROM dbo.pickdetail PH WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND   dropid = @cDropID
            AND status <'9'

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN rdtPickConsoLog_Insert
            WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
               COMMIT TRAN rdtPickConsoLog_Insert  

            SET @nErrNo = 190456 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PLOG FAIL 
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_1_Fail
         END
      END

      IF NOT EXISTS ( SELECT DISTINCT 1
            FROM PICKDETAIL (NOLOCK)
            where pickslipno= @cPickslipno
            AND storerkey=@cStorerkey
            And dropid NOT in (SELECT distinct(pcl.dropid)
                        FROM rdt.rdtPickConsoLog PCL (nolock)
                        JOIN PICKDETAIL PD ON PD.orderkey=pcl.orderkey and pcl.sku=pd.sku and pcl.dropid=pd.dropid
                        WHERE pd.pickslipno=@cPickslipno 
                        AND storerkey=@cStorerkey)
           AND ISNULL(dropid,'') <>'')
      BEGIN
         UPDATE rdtPickConsoLog WITH (ROWLOCK)
         set  status='9'
         where loc=@cLOC
         and pickzone=@cPickZone

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN rdtPickConsoLog_Insert
            WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
               COMMIT TRAN rdtPickConsoLog_Insert  

            SET @nErrNo = 190459 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PLOG FAIL 
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_1_Fail
         END

         SET @cOutField04 =  rdt.rdtgetmessage( 190457, @cLangCode, 'DSP') --Loc Needed
      END


      WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
         COMMIT TRAN rdtPickConsoLog_Insert  

      SET @cOutField01 =   @cDropID
      SET @cOutField02 =   @cPickZone
      SET @cOutField03 =   @cLOC

      SET @nStep=@nStep+1
      SET @nScn = @nScn+1
      GOTO QUit

   END

      
   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Delete all temp record which not confirm
      DELETE FROM rdt.rdtPickConsoLog 
      WHERE dropid=@cDropid
      AND   [Status] < '5'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 190460 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DeletePCLFail 
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO QUIT
      END

      -- Reset this screen var
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cDropid = ''
      SET @cPickZone = ''
      SET @cLOC = ''

      -- (Vicky02) - Start
      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr05 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr07 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr10 = ''
      SET @cFieldAttr11 = ''
      SET @cFieldAttr12 = ''
      SET @cFieldAttr13 = ''
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = ''
      -- (Vicky02) - End
   END
   GOTO Quit

   Step_1_Dropid_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      SET @cDropID = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1   -- OrderKey
   END
   GOTO Quit

   Step_1_PickZone_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = @cDropID
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      SET @cPickZone = ''
      EXEC rdt.rdtSetFocusField @nMobile, 2   -- OrderKey
   END
   GOTO Quit

   Step_1_Loc_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = @cDropID
      SET @cOutField02 = @cPickZone
      SET @cOutField03 = ' '
      SET @cInField03  = ' '

      SET @cLOC = ' '
      EXEC rdt.rdtSetFocusField @nMobile, 3   -- OrderKey
   END
   GOTO Quit
   
   
   Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = @cDropID
      SET @cOutField02 = @cPickZone
      SET @cOutField03 = @cLOC

      EXEC rdt.rdtSetFocusField @nMobile, 3   -- OrderKey
   END
   GOTO Quit
END
GOTO Quit

/************************************************************************************
Step_2. Scn = 6111. Screen 1.
   DropID   (field01)   - Out field
   Pick Zone   (field02)   - Out field
   Loc  (field03)   - Out field
************************************************************************************/
Step_2:
BEGIN
   IF @nInputKey in('1','0')
   BEGIN
      -- Screen mapping
      SET @cDropID = ''   
      SET @cPickZone = ''   
      SET @cLOC = ''
      SET @cOutField01 = '' -- Clean up for menu option
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1   -- OrderKey

      SET @nStep=@nStep-1
      SET @nScn = @nScn-1
      GOTO QUit
   END
END
GOTO Quit

/********************************************************************************
Quit. UPDATE back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate       = GETDATE(), 
      ErrMsg         = @cErrMsg,
      Func           = @nFunc,
      Step           = @nStep,
      Scn            = @nScn,

      StorerKey      = @cStorerKey,
      Facility       = @cFacility,
      -- UserName       = @cUserName,
      Printer        = @cPrinter,
      Printer_Paper  = @cPrinter_Paper,
      
      V_OrderKey     = @cOrderKey, 
      V_LOC          = @cLOC, 

      V_String1      = @cPickZone,
      V_String2      = @cDropID,
      
      I_Field01 =  @cInField01,  O_Field01 = @cOutField01,
      I_Field02 =  @cInField02,  O_Field02 = @cOutField02,
      I_Field03 =  @cInField03,  O_Field03 = @cOutField03,
      I_Field04 =  @cInField04,  O_Field04 = @cOutField04,
      I_Field05 =  @cInField05,  O_Field05 = @cOutField05,
      I_Field06 =  @cInField06,  O_Field06 = @cOutField06,
      I_Field07 =  @cInField07,  O_Field07 = @cOutField07,
      I_Field08 =  @cInField08,  O_Field08 = @cOutField08,
      I_Field09 =  @cInField09,  O_Field09 = @cOutField09,
      I_Field10 =  @cInField10,  O_Field10 = @cOutField10,
      I_Field11 =  @cInField11,  O_Field11 = @cOutField11,
      I_Field12 =  @cInField12,  O_Field12 = @cOutField12,
      I_Field13 =  @cInField13,  O_Field13 = @cOutField13,
      I_Field14 =  @cInField14,  O_Field14 = @cOutField14,
      I_Field15 =  @cInField15,  O_Field15 = @cOutField15,

      -- (Vicky02) - Start
      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,
      FieldAttr15  = @cFieldAttr15
      -- (Vicky02) - End

   WHERE Mobile = @nMobile
END

GO