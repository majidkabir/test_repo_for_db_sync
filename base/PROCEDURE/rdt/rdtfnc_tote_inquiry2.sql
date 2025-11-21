SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/*****************************************************************************/
/* Store procedure: rdtfnc_Tote_Inquiry2                                     */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author     Purposes                                       */
/* 2020-08-28 1.0  Chermaine  WMS-14260                                      */
/* 2020-10-24 1.1  AwYoung    Filter out short pick lines. (AAY20201024)     */
/* 2021-11-30 1.2  Chermaine  Tuning (cc01)                                  */
/*****************************************************************************/
CREATE PROC [RDT].[rdtfnc_Tote_Inquiry2](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

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
   @cUserName           NVARCHAR(18),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cToteNo             NVARCHAR(18),
   @cWaveKey            NVARCHAR(20),
   @cOrderCount         NVARCHAR(3),
   @cPickedQty          NVARCHAR(3),
   @cBalanceQty         NVARCHAR(3),


   @nPIKNo              INT,
   @nToteNo             INT,

   @cErrMsg1            NVARCHAR( 20),
   @cErrMsg2            NVARCHAR( 20),
   @cErrMsg3            NVARCHAR( 20),
   @cErrMsg4            NVARCHAR( 20),


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
   
   @cToteNo          = V_String1,
   @cWaveKey         = V_String2,
   @cOrderCount      = V_String3,
   @cPickedQty       = V_String4,
   @cBalanceQty      = V_String5,
      
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
IF @nFunc = 1846
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1846
   IF @nStep = 1 GOTO Step_1   -- Scn = 5820   Tote#
   IF @nStep = 2 GOTO Step_2   -- Scn = 5821   Result
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1846)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 5820
   SET @nStep = 1

   -- initialise all variable
   SET @cToteNo = ''
   SET @cWaveKey = ''
   SET @cOrderCount = ''
   SET @cPickedQty = ''
   SET @cBalanceQty = ''

   -- Prep next screen var   
   SET @cOutField01 = '' 
   SET @cOutField02 = '' 
   SET @cOutField03 = '' 
   SET @cOutField04 = '' 
   SET @cOutField05 = '' 
END
GOTO Quit

/********************************************************************************
Step 1. screen = 5820
   TOTE # (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToteNo = @cInField01

      --When Tote# is blank
      IF @cToteNo = ''
      BEGIN
         SET @nErrNo = 157101
         SET @cErrMsg = rdt.rdtgetmessage( 68366, @cLangCode, 'DSP') --Tote# Req
         GOTO Step_1_Fail  
      END 
      
      --(cc01)
      DECLARE @tSortD TABLE  
      (  
         deviceID NVARCHAR( 18) NOT NULL
         PRIMARY KEY CLUSTERED       
       (      
        [deviceID]      
       )      
      ) 
      
      IF EXISTS (SELECT TOP 1 1 FROM deviceProfile (NOLOCK) WHERE deviceID  = @cToteNo AND storerKey = @cStorerKey)
      BEGIN
	      INSERT INTO @tSortD
	      SELECT DeviceID+devicePosition 
	      FROM deviceProfile (NOLOCK)
	      WHERE deviceID  = @cToteNo 
	      AND storerKey = @cStorerKey
      END
      ELSE
      BEGIN
	      INSERT INTO @tSortD
	      VALUES (@cToteNo)
      END

      -- Check if Tote# exists
      IF NOT EXISTS ( SELECT TOP 1 1 
         FROM PickDetail PD WITH (NOLOCK) 
         JOIN ORDERS O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
         LEFT JOIN PACKHEADER PKH (NOLOCK) ON (O.Orderkey = PKH.Orderkey)
         JOIN  @tSortD SD  ON (PD.DropID = SD.deviceID ) --(cc01)
      WHERE PD.StorerKey = @cStorerKey 
         --AND PD.dropID like @cToteNo+'%'
         AND O.Status <> '9'
         --AND PKH.Status <> '9')
         AND isnull(PKH.Status,'') <> '9' 
		 AND PD.Qty > 0 --(AAY20201024)
		 )
      BEGIN
         SET @nErrNo = 157102
         SET @cErrMsg = rdt.rdtgetmessage( 68367, @cLangCode, 'DSP') --Invalid Tote#  
         GOTO Step_1_Fail 
      END

      SELECT TOP 1 
         @cWaveKey = O.userdefine09
      FROM PickDetail PD WITH (NOLOCK) 
         JOIN ORDERS O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
         LEFT JOIN PACKHEADER PKH (NOLOCK) ON (O.Orderkey = PKH.Orderkey)
         JOIN  @tSortD SD  ON (PD.DropID = SD.deviceID ) --(cc01)
      WHERE PD.StorerKey = @cStorerKey 
--         AND PD.dropID like @cToteNo+'%'
         AND O.Status <> '9'
         --AND PKH.Status <> '9'
         AND isnull(PKH.Status,'') <> '9' 
 		 AND PD.Qty > 0 --(AAY20201024)
        
      SELECT 
         @cOrderCount = COUNT(DISTINCT O.OrderKey)
      FROM PickDetail PD WITH (NOLOCK) 
         JOIN ORDERS O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
         LEFT JOIN PACKHEADER PKH (NOLOCK) ON (O.Orderkey = PKH.Orderkey)
         JOIN  @tSortD SD  ON (PD.DropID = SD.deviceID ) --(cc01)
      WHERE PD.StorerKey = @cStorerKey 
--         AND PD.dropID like @cToteNo+'%'
         AND O.Status <> '9'
         AND isnull(PKH.Status,'') <> '9'  
 		 AND PD.Qty > 0 --(AAY20201024)
		          
      SELECT 
         @cPickedQty = ISNULL(SUM(PD.QTY),0)
      FROM PickDetail PD WITH (NOLOCK) 
         JOIN ORDERS O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
         LEFT JOIN PACKHEADER PKH (NOLOCK) ON (O.Orderkey = PKH.Orderkey)
         JOIN  @tSortD SD  ON (PD.DropID = SD.deviceID ) --(cc01)
      WHERE PD.StorerKey = @cStorerKey 
--        AND PD.dropID like @cToteNo+'%'
         AND PD.status = '5'
         AND isnull(PKH.Status,'') <> '9'  
		 AND PD.Qty > 0 --(AAY20201024)
         
       SELECT 
         @cBalanceQty = ISNULL(SUM(PD.QTY),0)
      FROM PickDetail PD WITH (NOLOCK) 
         JOIN ORDERS O WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
         LEFT JOIN PACKHEADER PKH (NOLOCK) ON (O.Orderkey = PKH.Orderkey)
         JOIN  @tSortD SD  ON (PD.DropID = SD.deviceID ) --(cc01)
      WHERE PD.StorerKey = @cStorerKey 
--         AND PD.dropID like @cToteNo+'%'
         AND PD.status < '5'
         AND isnull(PKH.Status,'') <> '9'  
  		 AND PD.Qty > 0 --(AAY20201024)
            
      --prepare next screen variable
      SET @cOutField01 = @cToteNo
      SET @cOutField02 = @cWaveKey
      SET @cOutField03 = @cOrderCount
      SET @cOutField04 = ISNULL(@cPickedQty,0)
      SET @cOutField05 = ISNULL(@cBalanceQty,0)
                        
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

      -- initialise all variable
      SET @cToteNo = ''
      SET @cWaveKey = ''
      SET @cOrderCount = ''
      SET @cPickedQty = ''
      SET @cBalanceQty = ''

      -- Prep next screen var   
      SET @cOutField01 = '' 
      SET @cOutField02 = '' 
      SET @cOutField03 = '' 
      SET @cOutField04 = '' 
      SET @cOutField05 = '' 
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cToteNo = ''
      SET @cOutField01 = ''
    END

END
GOTO Quit

/********************************************************************************
Step 2. (screen = 2181) 
   TOTE  #: (Field01)
   Store #: (Field02)
   Status : (Field03)
   Pick # : (Field04)
   Date   : (Field05)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 OR @nInputKey = 0 -- ENTER / ESC
   BEGIN
      --prepare next screen variable
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''

      SET @cToteNo = ''
      SET @cWaveKey = ''
      SET @cOrderCount = ''
      SET @cPickedQty = ''
      SET @cBalanceQty = ''
                        
      -- Go next screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
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

       V_String1     = @cToteNo,
       V_String2     = @cWaveKey,
       V_String3     = @cOrderCount,
       V_String4     = @cPickedQty,
       V_String5     = @cBalanceQty,

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