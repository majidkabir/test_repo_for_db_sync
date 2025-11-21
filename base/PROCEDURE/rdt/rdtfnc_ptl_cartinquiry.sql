SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: IDSUK Put To Light Order Assignment SOS#269031                    */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2013-02-22 1.0  GTGOH      Created                                         */
/* 2014-06-23 1.1  James      SOS303322 - Support 20 positions (james01)      */
/*                            Add extended info (james02)                     */
/* 2014-09-22 1.2  Ung        SOS316713 Inquiry result sort by pos            */
/* 2016-09-30 1.3  Ung        Performance tuning                              */
/* 2018-11-08 1.4  TungGH     Performance                                     */  
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_PTL_CartInquiry] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @nCount        INT,
   @nRowCount     INT

-- RDT.RDTMobRec variable
DECLARE
   @nFunc         INT,
   @nScn          INT,
   @nStep         INT,
   @cLangCode     NVARCHAR( 3),
   @nInputKey     INT,
   @nMenu         INT,

   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cPrinter      NVARCHAR( 20),
   @cUserName     NVARCHAR( 18),

   @nError        INT,
   @b_success     INT,
   @n_err         INT,
   @c_errmsg      NVARCHAR( 250),
   @cPUOM         NVARCHAR( 10),
   @bSuccess      INT,

   @cCartID				NVARCHAR(10),
   @cToteID				NVARCHAR(20),
   @cOrderKey			NVARCHAR(10),
   @cDeviceProfile	NVARCHAR(10),
	@cEditWho			NVARCHAR(18),
   @nOrderCnt			INT,
	@cStatus				NVARCHAR(10),
	@nPOS					INT,
	@cDeviceProfileKey	NVARCHAR(10),
   @cDevicePosition  NVARCHAR(10),
   @cOrdStatus       NVARCHAR(10),
   @cExternOrderKey  NVARCHAR(30),
   @cLot04           NVARCHAR(16),
   @dLot04           DATETIME,
   @nSKUTot          INT,
   @nSKUP           INT,
   @nSKUPICK         INT,
   @nPickQty         INT,
   @nExpQty          INT,
   @nSKUCnt          INT,
   @nLot02Tot        INT,
   @nLot02Cnt        INT,
   @nPutQty          INT,
   @nPutTotQty       INT,
   @cLot02           NVARCHAR(18),
   @cLoc             NVARCHAR(18),
   @cSKU             NVARCHAR(20),
   @cOrdMsg          NVARCHAR(20),
   @cDeviceProfileLogKey   NVARCHAR(10),
   @cNextDevPos      NVARCHAR( 10), 
   @cExtendedInfo    NVARCHAR( 20),    -- (james02)
   @cExtendedInfoSP  NVARCHAR( 20),    -- (james02)
   @cSQL             NVARCHAR( MAX),   -- (james02)
   @cSQLParam        NVARCHAR( MAX),   -- (james02)

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
   @cPrinter   = Printer,
   @cUserName  = UserName,

   @cPUOM       = V_UOM,
 --@cOrderKey   = V_OrderKey,

	@cCartID     = V_String1,
	@cNextDevPos = V_String2,         -- (james01)
	@cDeviceProfileLogKey = V_String3,  -- (james01)

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

IF @nFunc = 813  -- PTL Cart Inquiry
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- PTL Cart Inquiry
   IF @nStep = 1 GOTO Step_1   -- Scn = 3480. Cart ID, Tote ID
	IF @nStep = 2 GOTO Step_2   -- Scn = 3481. Statistic
	IF @nStep = 3 GOTO Step_3   -- Scn = 3483. Position, OrderKey, Status
	IF @nStep = 4 GOTO Step_4   -- Scn = 3484.
	IF @nStep = 5 GOTO Step_5   -- Scn = 3485.
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 813. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get prefer UOM
	SET @cPUOM = ''
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   -- Initiate var
   
	-- EventLog
   EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign-in
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep

   -- Init screen
   SET @cOutField01 = ''

   -- Set the entry point
	SET @nScn = 3480
	SET @nStep = 1

END
GOTO Quit


/********************************************************************************
Step 1. Scn = 3480.
   CartID (Input , Field01)
   ToteID (Input , Field02)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
	   SET @nOrderCnt = 0
      SET @nPOS = 0
      SET @nSKUTot = 0
      SET @nSKUP = 0
      SET @nPickQty = 0
      SET @nExpQty = 0
      SET @cCartID = ISNULL(RTRIM(@cInField01),'')
      SET @cToteID = ISNULL(RTRIM(@cInField02),'')

      -- Validate blank
      IF ISNULL(RTRIM(@cCartID), '') = '' AND ISNULL(RTRIM(@cToteID), '') = ''
      BEGIN
         SET @nErrNo = 79701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartID req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      IF ISNULL(RTRIM(@cCartID), '') <> '' AND ISNULL(RTRIM(@cToteID), '') <> ''
      BEGIN
         SET @nErrNo = 79705
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartID req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      IF ISNULL(RTRIM(@cCartID), '') <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK) WHERE DeviceID = @cCartID )
         BEGIN
            SET @nErrNo = 79702
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid CartID
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END

         SET @cDeviceProfileLogKey = ''

         SELECT Top 1 @cDeviceProfileLogKey = RTRIM(ISNULL(DPL.DeviceProfileLogKey,''))
	      FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
         JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
         WHERE DP.DeviceID = @cCartID
         ORDER BY DPL.DeviceProfileLogKey DESC

         SELECT Top 1 --@cEditWho = DP.EditWho,
			      @cStatus = ISNULL(CLK.Short,'')
	      FROM dbo.DeviceProfile DP WITH (NOLOCK)
         JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK)
         ON DP.DeviceProfileKey = DPl.DeviceProfileKey
         JOIN CODELKUP CLK WITH (NOLOCK)
         ON CLK.ListName = 'DEVICESTS'
         AND CLK.Code = DPL.Status
	      WHERE DP.DeviceID = @cCartID
         AND DPl.DeviceProfileLogKey = @cDeviceProfileLogKey
	      ORDER BY DP.EditDate

	      SELECT  @cEditWho = DPL.EditWho
	      FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
         INNER JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
         WHERE DP.DeviceID = @cCartID
         AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey

	      SELECT  @nOrderCnt = COUNT(DISTINCT DPL.OrderKey)
	      FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
         INNER JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
         WHERE DP.DeviceID = @cCartID
         AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey

         -- Get stored proc name for extended info (james02)
         SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
         IF @cExtendedInfoSP = '0'
            SET @cExtendedInfoSP = ''

         -- Extended info
         IF @cExtendedInfoSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
            BEGIN
               SET @cExtendedInfo = ''

               SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nStep, @nInputKey, @cStorerKey, @cCartID, @cToteID, @cExtendedInfo OUTPUT '

               SET @cSQLParam =
                  '@nMobile         INT, ' +
                  '@nStep           INT, ' +
                  '@nInputKey       INT, ' +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cCartID         NVARCHAR( 10), ' +
                  '@cToteID         NVARCHAR( 20), ' +
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nStep, @nInputKey, @cStorerKey, @cCartID, @cToteID, @cExtendedInfo OUTPUT
            END
         END

         -- Prepare Next Screen Variable
         SET @cOutField01 = @cCartID
         SET @cOutField02 = @cStatus
         SET @cOutField03 = @cEditWho
         SET @cOutField04 = @nOrderCnt
--         SET @cOutField05 = @cDeviceProfileLogKey
         SET @cOutField05 = @cExtendedInfo         -- (james02)

         -- GOTO Next Screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK) WHERE DropID = @cToteID )
         BEGIN
            SET @nErrNo = 79703
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ToteID
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END

         SET @cDeviceProfileLogKey = ''
         SELECT Top 1 @cDeviceProfileLogKey = RTRIM(ISNULL(DPL.DeviceProfileLogKey,''))
	      FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
         JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
         ORDER BY DPL.DeviceProfileLogKey DESC

         IF RTRIM(ISNULL(@cDeviceProfileLogKey,'')) = ''
         BEGIN
            SET @nErrNo = 79704
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Not Pick
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END

         IF NOT EXISTS (SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)
            WHERE DropID = @cToteID AND DeviceProfileLogKey = @cDeviceProfileLogKey)
         BEGIN
            SET @nErrNo = 79706
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ToteID
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END


	      SELECT   @cDevicePosition = DP.DevicePosition,
	   		      @cOrdStatus = ISNULL(CLK.Short,''),
                  @cOrderKey = DPL.OrderKey,
                  @cExternOrderKey = OH.ExternOrderKey,
                  @cCartID = DP.DeviceID
--                  ,@nSKUTot = ISNULL(COUNT(DISTINCT PTL.SKU),0)
	      FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
         JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
         JOIN dbo.Orders OH WITH (NOLOCK) ON DPL.OrderKey = OH.OrderKey
         JOIN CODELKUP CLK WITH (NOLOCK) ON CLK.ListName = 'DEVICESTS' AND CLK.Code = DP.Status
	      LEFT JOIN dbo.PTLTran PTL WITH (NOLOCK) ON OH.OrderKey = PTL.OrderKey
	      AND DP.DeviceID = PTL.DeviceID AND DPL.DropID = PTL.DropID
         AND DPL.DeviceProfileLogKey = PTL.DeviceProfileLogKey
         WHERE DPL.DropID = @cToteID AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey
         GROUP BY DP.DevicePosition, ISNULL(CLK.Short,''),
         DPL.OrderKey, OH.ExternOrderKey, DP.DeviceID--, PTL.SKU

         SELECT @nSKUTot = ISNULL(COUNT(DISTINCT PD.SKU),0)
         FROM dbo.DeviceProfile D WITH (NOLOCK)
         INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = DL.OrderKey
         INNER JOIN dbo.PickDetail PD WITH(NOLOCK) ON PD.OrderKey = O.OrderKey
         WHERE DL.DropID = @cToteID AND DL.DeviceProfileLogKey = @cDeviceProfileLogKey

         SELECT   @nSKUP = ISNULL(COUNT(DISTINCT PTL.SKU),0)
	      FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
         JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
         JOIN dbo.Orders OH WITH (NOLOCK) ON DPL.OrderKey = OH.OrderKey
	      LEFT JOIN dbo.PTLTran PTL WITH (NOLOCK) ON OH.OrderKey = PTL.OrderKey
	      AND DP.DeviceID = PTL.DeviceID AND DPL.DropID = PTL.DropID
         AND DPL.DeviceProfileLogKey = PTL.DeviceProfileLogKey
         WHERE DPL.DropID = @cToteID AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey
         AND ISNULL(PTL.Qty,0) > 0
--         HAVING SUM(PTL.Qty) = 0

         SELECT   @nPickQty = ISNULL(SUM(PTL.Qty),0)
--                  ,@nExpQty = ISNULL(SUM(PTL.ExpectedQty),0)
	      FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
         JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
          JOIN dbo.Orders OH WITH (NOLOCK)
         ON DPL.OrderKey = OH.OrderKey
	      LEFT JOIN dbo.PTLTran PTL WITH (NOLOCK)
         ON OH.OrderKey = PTL.OrderKey AND DP.DeviceID = PTL.DeviceID
         AND DPL.DropID = PTL.DropID AND DPL.DeviceProfileLogKey = PTL.DeviceProfileLogKey
         WHERE DPL.DropID = @cToteID AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey

         SELECT   @nExpQty = ISNULL(SUM(PD.Qty),0)
	      FROM dbo.DeviceProfile D WITH (NOLOCK)
         INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = DL.OrderKey
         INNER JOIN dbo.PickDetail PD WITH(NOLOCK) ON PD.OrderKey = O.OrderKey
         WHERE DL.DropID = @cToteID AND DL.DeviceProfileLogKey = @cDeviceProfileLogKey

         SET @cOrdMsg = ''
         SELECT @cOrdMsg = '(SP)'
	      FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
         JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
          JOIN dbo.Orders OH WITH (NOLOCK)
         ON DPL.OrderKey = OH.OrderKey
	      JOIN dbo.PTLTran PTL WITH (NOLOCK)
         ON OH.OrderKey = PTL.OrderKey AND DP.DeviceID = PTL.DeviceID
         AND DPL.DropID = PTL.DropID AND DPL.DeviceProfileLogKey = PTL.DeviceProfileLogKey
         WHERE DPL.DropID = @cToteID AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey
         HAVING ISNULL(SUM(PTL.Qty),0) < ISNULL(SUM(PTL.ExpectedQty),0)

        -- Prepare Next Screen Variable
         SET @cOutField01 = @cCartID
         SET @cOutField02 = @cToteID
         SET @cOutField03 = @cOrderKey + ' ' + @cOrdMsg
         SET @cOutField04 = @cExternOrderKey
         SET @cOutField05 = @cOrdStatus
         SET @cOutField06 = @cDevicePosition
         SET @cOutField07 = CAST(@nSKUP AS VARCHAR(10)) + '/' + CAST(@nSKUTot AS VARCHAR(10))
         SET @cOutField08 = CAST(@nPickQty AS VARCHAR(10)) + '/' + CAST(@nExpQty AS VARCHAR(10))
         SET @cOutField09 = CAST(@nSKUP AS VARCHAR(10))

          -- GOTO Next Screen
         SET @nScn = @nScn + 3
         SET @nStep = @nStep + 3
	   END

      EXEC RDT.rdt_STD_EventLog
         @cActionType = '3', 
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @cDeviceID   = @cCartID,
         @cRefNo2     = @cDeviceProfile,
         @cOrderKey   = @cOrderKey,
         @cDropID     = @cToteID,
         @nStep       = @nStep
	END

	IF @nInputKey = 0
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-out
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep

      --go to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
	GOTO Quit

   STEP_1_FAIL:
   BEGIN
      SET @cOutField01 = ''
   END
END
GOTO QUIT

/********************************************************************************
Step 2. Scn = 3481.
   CartID         (field01)
   CartStatus     (field02)
   Cart Position  (field03)
   Tote ID        (field04)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      SET @cInField02 = @cOutField02
      SET @cInField03 = @cOutField03
      SET @cInField04 = @cOutField04
		SET @cStatus = ISNULL(RTRIM(@cInField02),'')
		SET @cEditWho = ISNULL(RTRIM(@cInField03),'')
		SET @nOrderCnt = ISNULL(RTRIM(@cInField04),'')

      SET @cNextDevPos = ''
      SET @nPOS = 1
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''

      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   		SELECT DPL.OrderKey, ISNULL(DP.DevicePosition,''), ISNULL(CLK.Short,'')
   		FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
      		JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON ( DP.DeviceProfileKey = DPL.DeviceProfileKey)
            JOIN CODELKUP CLK WITH (NOLOCK) ON ( CLK.ListName = 'DEVICESTS' AND CLK.Code = DPL.Status)
   		WHERE DP.DeviceID = @cCartID
            AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey
   		ORDER BY DP.DevicePosition
      OPEN CUR_LOOP
      FETCH NEXT FROM CUR_LOOP INTO @cOrderKey, @cDevicePosition, @cStatus
      WHILE @@FETCH_STATUS <> -1
      BEGIN
			IF @nPOS = 1 SET @cOutField02 = LEFT(@cDevicePosition + SPACE(6),6) + LEFT(@cOrderKey + SPACE(11),11) + @cStatus
			IF @nPOS = 2 SET @cOutField03 = LEFT(@cDevicePosition + SPACE(6),6) + LEFT(@cOrderKey + SPACE(11),11) + @cStatus
			IF @nPOS = 3 SET @cOutField04 = LEFT(@cDevicePosition + SPACE(6),6) + LEFT(@cOrderKey + SPACE(11),11) + @cStatus
			IF @nPOS = 4 SET @cOutField05 = LEFT(@cDevicePosition + SPACE(6),6) + LEFT(@cOrderKey + SPACE(11),11) + @cStatus
			IF @nPOS = 5 SET @cOutField06 = LEFT(@cDevicePosition + SPACE(6),6) + LEFT(@cOrderKey + SPACE(11),11) + @cStatus
			IF @nPOS = 6 SET @cOutField07 = LEFT(@cDevicePosition + SPACE(6),6) + LEFT(@cOrderKey + SPACE(11),11) + @cStatus
			IF @nPOS = 7 SET @cOutField08 = LEFT(@cDevicePosition + SPACE(6),6) + LEFT(@cOrderKey + SPACE(11),11) + @cStatus
			IF @nPOS = 8 SET @cOutField09 = LEFT(@cDevicePosition + SPACE(6),6) + LEFT(@cOrderKey + SPACE(11),11) + @cStatus
		   SET @cNextDevPos = @cDevicePosition

         IF @nPOS = 8
            BREAK

		   SET @nPOS = @nPOS + 1

         FETCH NEXT FROM CUR_LOOP INTO @cOrderKey, @cDevicePosition, @cStatus
	   END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

 		SET @nScn = @nScn + 1
	   SET @nStep = @nStep + 1

   	-- Prepare Next Screen Variable
      SET @cOutField01 = @cCartID
	END

   IF @nInputKey = 0
   BEGIN
      -- Prepare Previous Screen Variable
      SET @cOutField01 = ''
      SET @cOutField02 = ''

      -- GOTO Previous Screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
	GOTO Quit

   STEP_2_FAIL:
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
   END
END
GOTO QUIT


/********************************************************************************
Step 3. Scn = 3482.
   CartID   (field01)
   CartStatus      (field02, input)
   Cart Position   (field03, input)
   Tote ID         (field04, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      SET @nPOS = 1
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''

      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   		SELECT DPL.OrderKey, ISNULL(DP.DevicePosition,''), ISNULL(CLK.Short,'')
   		FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
      		JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON ( DP.DeviceProfileKey = DPL.DeviceProfileKey)
            JOIN CODELKUP CLK WITH (NOLOCK) ON ( CLK.ListName = 'DEVICESTS' AND CLK.Code = DPL.Status)
   		WHERE DP.DeviceID = @cCartID
            AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey
      		AND DP.DevicePosition > @cNextDevPos
   		ORDER BY DP.DevicePosition
      OPEN CUR_LOOP
      FETCH NEXT FROM CUR_LOOP INTO @cOrderKey, @cDevicePosition, @cStatus
      WHILE @@FETCH_STATUS <> -1
      BEGIN
			IF @nPOS = 1 SET @cOutField02 = LEFT(@cDevicePosition + SPACE(6),6) + LEFT(@cOrderKey + SPACE(11),11) + @cStatus
			IF @nPOS = 2 SET @cOutField03 = LEFT(@cDevicePosition + SPACE(6),6) + LEFT(@cOrderKey + SPACE(11),11) + @cStatus
			IF @nPOS = 3 SET @cOutField04 = LEFT(@cDevicePosition + SPACE(6),6) + LEFT(@cOrderKey + SPACE(11),11) + @cStatus
			IF @nPOS = 4 SET @cOutField05 = LEFT(@cDevicePosition + SPACE(6),6) + LEFT(@cOrderKey + SPACE(11),11) + @cStatus
			IF @nPOS = 5 SET @cOutField06 = LEFT(@cDevicePosition + SPACE(6),6) + LEFT(@cOrderKey + SPACE(11),11) + @cStatus
			IF @nPOS = 6 SET @cOutField07 = LEFT(@cDevicePosition + SPACE(6),6) + LEFT(@cOrderKey + SPACE(11),11) + @cStatus
			IF @nPOS = 7 SET @cOutField08 = LEFT(@cDevicePosition + SPACE(6),6) + LEFT(@cOrderKey + SPACE(11),11) + @cStatus
			IF @nPOS = 8 SET @cOutField09 = LEFT(@cDevicePosition + SPACE(6),6) + LEFT(@cOrderKey + SPACE(11),11) + @cStatus
		   SET @cNextDevPos = @cDevicePosition

         IF @nPOS = 8
            BREAK

		   SET @nPOS = @nPOS + 1

         FETCH NEXT FROM CUR_LOOP INTO @cOrderKey, @cDevicePosition, @cStatus
	   END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

      -- End of record, Quit
      IF ISNULL( @cOutField02, '') = ''
      BEGIN
         -- Prepare Previous Screen Variable
         SET @cOutField01 = ''
         SET @cOutField02 = ''

         -- GOTO Previous Screen
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2

         GOTO Quit
      END
	END

   IF @nInputKey = 0
   BEGIN
      -- Prepare Previous Screen Variable
      SET @cOutField01 = ''
      SET @cOutField02 = ''

      -- GOTO Previous Screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2	    
   END
	GOTO Quit

   STEP_3_FAIL:
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
    END
END
GOTO QUIT


/********************************************************************************
Step 4. Scn = 3483.
   CartID   (field01)
   CartStatus      (field02, input)
   Cart Position   (field03, input)
   Tote ID         (field04, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      SET @nSKUCnt = CAST(@cOutField09 AS INT)

      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''

      SET @nSKUPICK = ISNULL(@nSKUPICK,0)
      SET @cSKU = ISNULL(@cSKU,'')
      SET @nLot02Cnt = ISNULL(@nLot02Cnt,0)
      SET @nLot02Tot = ISNULL(@nLot02Tot,0)
      SET @nPutQty   = ISNULL(@nPutQty,0)
      SET @nPutTotQty   = ISNULL(@nPutTotQty,0)
      SET @cToteID = @cInField02

      SET @cDeviceProfileLogKey = ''
      SELECT Top 1 @cDeviceProfileLogKey = RTRIM(ISNULL(DeviceProfileLogKey,''))
      FROM dbo.DeviceProfileLog DPL WITH (NOLOCK) WHERE DPL.DropID = @cToteID
      ORDER BY DeviceProfileLogKey DESC

		IF @nSKUPICK < @nSKUCnt
		BEGIN
			SET @nSKUPICK = @nSKUPICK + 1

	      SELECT   Top 1 @cSKU = PTL.SKU
         FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
         JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
         JOIN dbo.Orders OH WITH (NOLOCK)
         ON DPL.OrderKey = OH.OrderKey
         JOIN dbo.PTLTran PTL WITH (NOLOCK)
         ON OH.OrderKey = PTL.OrderKey
         AND DP.DeviceID = PTL.DeviceID
         AND DPL.DropID = PTL.DropID
         AND DPL.DeviceProfileLogKey = PTL.DeviceProfileLogKey
         WHERE DPL.DropID = @cToteID AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey
         AND PTL.SKU > ISNULL(@cSKU,'')
         AND ISNULL(PTL.Qty,0) > 0
         ORDER BY PTL.SKU

         SELECT   @nPutQty = SUM(PTL.Qty),
                  @nPutTotQty = SUM(PTL.ExpectedQty)
	      FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
         JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
          JOIN dbo.Orders OH WITH (NOLOCK)
         ON DPL.OrderKey = OH.OrderKey
	      JOIN dbo.PTLTran PTL WITH (NOLOCK)
         ON OH.OrderKey = PTL.OrderKey
	      AND DP.DeviceID = PTL.DeviceID
         AND DPL.DropID = PTL.DropID AND DPL.DeviceProfileLogKey = PTL.DeviceProfileLogKey
         WHERE DPL.DropID = @cToteID AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey
         AND PTL.SKU = ISNULL(@cSKU,'')

         IF @nLot02Cnt = @nLot02Tot
         BEGIN
            SET @nLot02Cnt = 0

            SELECT  TOP 1 @cLot02 = LOT.Lottable02
	         FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
            JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
             JOIN dbo.Orders OH WITH (NOLOCK)
            ON DPL.OrderKey = OH.OrderKey
	         JOIN dbo.PTLTran PTL WITH (NOLOCK)
            ON OH.OrderKey = PTL.OrderKey
	         AND DP.DeviceID = PTL.DeviceID
            AND DPL.DropID = PTL.DropID
            AND DPL.DeviceProfileLogKey = PTL.DeviceProfileLogKey
            JOIN dbo.LOTATTRIBUTE LOT WITH (NOLOCK)
            ON PTL.LOT = LOT.LOT
            WHERE DPL.DropID = @cToteID AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey
            AND PTL.SKU = ISNULL(@cSKU,'')
            AND LOT.Lottable02 >= ISNULL(@cLot02,'')
            ORDER BY LOT.Lottable02

            SET @nLot02Tot = 0
            SELECT   @nLot02Tot = COUNT(DISTINCT LOT.Lottable02)
	         FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
            JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
             JOIN dbo.Orders OH WITH (NOLOCK)
            ON DPL.OrderKey = OH.OrderKey
	         JOIN dbo.PTLTran PTL WITH (NOLOCK)
            ON OH.OrderKey = PTL.OrderKey
	         AND DP.DeviceID = PTL.DeviceID
            AND DPL.DropID = PTL.DropID
            AND DPL.DeviceProfileLogKey = PTL.DeviceProfileLogKey
            JOIN dbo.LOTATTRIBUTE LOT WITH (NOLOCK)
            ON PTL.LOT = LOT.LOT
            WHERE DPL.DropID = @cToteID AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey
            AND PTL.SKU = ISNULL(@cSKU,'')
--            AND LOT.Lottable02 = ISNULL(@cLot02,'')
--            GROUP BY LOT.Lottable02

            IF @nLot02Tot > 0
            BEGIN
               SET @nLot02Cnt = @nLot02Cnt + 1
               SELECT  TOP 1  @dLot04 = LOT.Lottable04,
--                              @dLot04 = ISNULL(LOT.Lottable04,'0'),
                              @cLoc = ISNULL(PTL.LOC,'')
	            FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
               JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
                JOIN dbo.Orders OH WITH (NOLOCK)
               ON DPL.OrderKey = OH.OrderKey
	            JOIN dbo.PTLTran PTL WITH (NOLOCK)
               ON OH.OrderKey = PTL.OrderKey
	            AND DP.DeviceID = PTL.DeviceID
               AND DPL.DropID = PTL.DropID
               AND DPL.DeviceProfileLogKey = PTL.DeviceProfileLogKey
               JOIN dbo.LOTATTRIBUTE LOT WITH (NOLOCK)
               ON PTL.LOT = LOT.LOT
               WHERE DPL.DropID = @cToteID AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey
               AND PTL.SKU = ISNULL(@cSKU,'')
               AND LOT.Lottable02 = ISNULL(@cLot02,'')
               ORDER BY ISNULL(LOT.Lottable04,'')
            END
         END
         ELSE
         BEGIN
	         SET @nLot02Cnt = @nLot02Cnt + 1
            SELECT  TOP 1  @dLot04 = LOT.Lottable04,
--                            @dLot04 = ISNULL(LOT.Lottable04,'0'),
                           @cLoc = ISNULL(PTL.LOC,'')
	         FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
            JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
             JOIN dbo.Orders OH WITH (NOLOCK)
            ON DPL.OrderKey = OH.OrderKey
	         JOIN dbo.PTLTran PTL WITH (NOLOCK)
            ON OH.OrderKey = PTL.OrderKey
	         AND DP.DeviceID = PTL.DeviceID
            AND DPL.DropID = PTL.DropID
            AND DPL.DeviceProfileLogKey = PTL.DeviceProfileLogKey
            JOIN dbo.LOTATTRIBUTE LOT WITH (NOLOCK)
            ON PTL.LOT = LOT.LOT
            WHERE DPL.DropID = @cToteID AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey
            AND PTL.SKU = ISNULL(@cSKU,'')
            AND LOT.Lottable02 = ISNULL(@cLot02,'')
            AND LOT.Lottable04 > ISNULL(@dLot04,'0')
            ORDER BY ISNULL(LOT.Lottable04,'')
         END

         SET @cOutField09 = CAST(@nSKUPICK AS VARCHAR(10)) + '/' + CAST(@nSKUCnt AS VARCHAR(10))
	      SET @cOutField10 = CAST(@nLot02Cnt AS VARCHAR(10)) + '/' + CAST(@nLot02Tot AS VARCHAR(10))
         SET @cOutField11 = @cSKU
	      SET @cOutField12 = CAST(@nPutQty AS VARCHAR(10)) + '/' + CAST(@nPutTotQty AS VARCHAR(10))
	      SET @cOutField13 = @cLot02
	      SET @cOutField14 = RDT.RDTFormatDate(@dLot04)
	      SET @cOutField15 = @cLoc
      END

      IF @nSKUCnt = 0
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         
         -- GOTO Previous Screen
         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3
      END
      ELSE
		BEGIN
 	      SET @nScn = @nScn + 1
	      SET @nStep = @nStep + 1

   	   -- Prepare Next Screen Variable
         SET @cOutField01 = @cCartID
      END
	END

   IF @nInputKey = 0
   BEGIN
      -- Prepare Previous Screen Variable
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      
      -- GOTO Previous Screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END
	GOTO Quit

   STEP_4_FAIL:
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
   END
END
GOTO QUIT


/********************************************************************************
Step 5. Scn = 3484.
   CartID   (field01)
   CartStatus      (field02, input)
   Cart Position   (field03, input)
   Tote ID         (field04, input)
********************************************************************************/
Step_5:
BEGIN

   IF @nInputKey = 1 --ENTER
   BEGIN
      SET @cInField09 = @cOutField09
      SET @cInField10 = @cOutField10

      SET @nSKUPICK = CAST(ISNULL(LEFT(@cInField09,CHARINDEX('/',@cInField09)-1 ),0) AS INT)
      SET @nSKUCnt = CAST(ISNULL(RIGHT(@cInField09,LEN(@cInField09) - CHARINDEX('/',@cInField09)),0) AS INT)
      SET @cSKU = ISNULL(@cOutField11,'')
      SET @nLot02Cnt = CAST(ISNULL(LEFT(@cInField10,CHARINDEX('/',@cInField10)-1 ),0) AS INT)
      SET @nLot02Tot = CAST(ISNULL(RIGHT(@cInField10,LEN(@cInField10) - CHARINDEX('/',@cInField10)),0) AS INT)
      SET @nPutQty   = ISNULL(@nPutQty,0)
      SET @nPutTotQty   = ISNULL(@nPutTotQty,0)
      SET @cToteID = @cInField02
      SET @cLot02 = @cOutField13
      SET @dLot04 = @cOutField14

      SET @cDeviceProfileLogKey = ''
      SELECT Top 1 @cDeviceProfileLogKey = RTRIM(ISNULL(DeviceProfileLogKey,''))
      FROM dbo.DeviceProfileLog DPL WITH (NOLOCK) WHERE DPL.DropID = @cToteID
      ORDER BY DeviceProfileLogKey DESC

      IF @nSKUPICK < @nSKUCnt
		BEGIN
         IF @nLot02Cnt = @nLot02Tot AND @nLot02Tot <> 0
         BEGIN
			   SET @nSKUPICK = @nSKUPICK + 1
            SET @cLot02 = ''
            SET @nLot02Cnt = 0

	         SELECT   Top 1 @cSKU = PTL.SKU
            FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
            JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
             JOIN dbo.Orders OH WITH (NOLOCK)
            ON DPL.OrderKey = OH.OrderKey
            JOIN dbo.PTLTran PTL WITH (NOLOCK)
            ON OH.OrderKey = PTL.OrderKey
            AND DP.DeviceID = PTL.DeviceID
            AND DPL.DropID = PTL.DropID
            AND DPL.DeviceProfileLogKey = PTL.DeviceProfileLogKey
            WHERE DPL.DropID = @cToteID AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey
            AND PTL.SKU > ISNULL(@cSKU,'')
            ORDER BY PTL.SKU

            SELECT   @nPutQty = SUM(PTL.Qty),
                     @nPutTotQty = SUM(PTL.ExpectedQty)
	         FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
            JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
            JOIN dbo.Orders OH WITH (NOLOCK)
            ON DPL.OrderKey = OH.OrderKey
	         JOIN dbo.PTLTran PTL WITH (NOLOCK)
            ON OH.OrderKey = PTL.OrderKey
	         AND DP.DeviceID = PTL.DeviceID
            AND DPL.DropID = PTL.DropID
            AND DPL.DeviceProfileLogKey = PTL.DeviceProfileLogKey
            WHERE DPL.DropID = @cToteID AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey
            AND PTL.SKU = ISNULL(@cSKU,'')

            SELECT  TOP 1 @cLot02 = LOT.Lottable02
	         FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
            JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
            JOIN dbo.Orders OH WITH (NOLOCK)
            ON DPL.OrderKey = OH.OrderKey
	         JOIN dbo.PTLTran PTL WITH (NOLOCK)
            ON OH.OrderKey = PTL.OrderKey
	         AND DP.DeviceID = PTL.DeviceID
            AND DPL.DropID = PTL.DropID
            AND DPL.DeviceProfileLogKey = PTL.DeviceProfileLogKey
            JOIN dbo.LOTATTRIBUTE LOT WITH (NOLOCK)
            ON PTL.LOT = LOT.LOT
            WHERE DPL.DropID = @cToteID AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey
            AND PTL.SKU = ISNULL(@cSKU,'')
--            AND LOT.Lottable02 > ISNULL(@cLot02,'')
            ORDER BY LOT.Lottable02

            SET @nLot02Tot = 0
            SELECT   @nLot02Tot = COUNT(DISTINCT LOT.Lottable02)
	         FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
            JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
             JOIN dbo.Orders OH WITH (NOLOCK)
            ON DPL.OrderKey = OH.OrderKey
	         JOIN dbo.PTLTran PTL WITH (NOLOCK)
            ON OH.OrderKey = PTL.OrderKey
	         AND DP.DeviceID = PTL.DeviceID
            AND DPL.DropID = PTL.DropID
            AND DPL.DeviceProfileLogKey = PTL.DeviceProfileLogKey
            JOIN dbo.LOTATTRIBUTE LOT WITH (NOLOCK)
            ON PTL.LOT = LOT.LOT
            WHERE DPL.DropID = @cToteID AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey
            AND PTL.SKU = ISNULL(@cSKU,'')
--            AND LOT.Lottable02 = ISNULL(@cLot02,'')
--            GROUP BY LOT.Lottable02

            IF @nLot02Tot > 0
            BEGIN
               SET @nLot02Cnt = @nLot02Cnt + 1
               SELECT  TOP 1  @dLot04 = LOT.Lottable04,
                              @cLoc = ISNULL(PTL.LOC,'')
	            FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
               JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
                JOIN dbo.Orders OH WITH (NOLOCK)
               ON DPL.OrderKey = OH.OrderKey
	            JOIN dbo.PTLTran PTL WITH (NOLOCK)
               ON OH.OrderKey = PTL.OrderKey
	            AND DP.DeviceID = PTL.DeviceID
               AND DPL.DropID = PTL.DropID
               AND DPL.DeviceProfileLogKey = PTL.DeviceProfileLogKey
               JOIN dbo.LOTATTRIBUTE LOT WITH (NOLOCK)
               ON PTL.LOT = LOT.LOT
               WHERE DPL.DropID = @cToteID AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey
               AND PTL.SKU = ISNULL(@cSKU,'')
               AND LOT.Lottable02 = ISNULL(@cLot02,'')
--               AND LOT.Lottable04 > ISNULL(@dLot04,'')
               ORDER BY ISNULL(LOT.Lottable04,'')
            END
         END
         ELSE
         BEGIN
	         SET @nLot02Cnt = @nLot02Cnt + 1
            SELECT  TOP 1  @cLot02 = LOT.Lottable02,
                           @dLot04 = LOT.Lottable04,
                           @cLoc = ISNULL(PTL.LOC,'')
	         FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
            JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
             JOIN dbo.Orders OH WITH (NOLOCK)
            ON DPL.OrderKey = OH.OrderKey
	         JOIN dbo.PTLTran PTL WITH (NOLOCK)
            ON OH.OrderKey = PTL.OrderKey
	         AND DP.DeviceID = PTL.DeviceID
            AND DPL.DropID = PTL.DropID
            AND DPL.DeviceProfileLogKey = PTL.DeviceProfileLogKey
            JOIN dbo.LOTATTRIBUTE LOT WITH (NOLOCK)
            ON PTL.LOT = LOT.LOT
            WHERE DPL.DropID = @cToteID AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey
            AND PTL.SKU = ISNULL(@cSKU,'')
            AND LOT.Lottable02 >= ISNULL(@cLot02,'')
            AND LOT.Lottable04 > ISNULL(@dLot04,'0')
            ORDER BY ISNULL(LOT.Lottable02,''),ISNULL(LOT.Lottable04,'')

         END
      END
      ELSE IF @nLot02Cnt <> @nLot02Tot
      BEGIN
        SELECT   @nPutQty = SUM(PTL.Qty),
                  @nPutTotQty = SUM(PTL.ExpectedQty)
         FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
         JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
         JOIN dbo.Orders OH WITH (NOLOCK)
         ON DPL.OrderKey = OH.OrderKey
         JOIN dbo.PTLTran PTL WITH (NOLOCK)
         ON OH.OrderKey = PTL.OrderKey
         AND DP.DeviceID = PTL.DeviceID
         AND DPL.DropID = PTL.DropID
         AND DPL.DeviceProfileLogKey = PTL.DeviceProfileLogKey
         WHERE DPL.DropID = @cToteID AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey
         AND PTL.SKU = ISNULL(@cSKU,'')

         SET @nLot02Cnt = @nLot02Cnt + 1
         SELECT  TOP 1  @cLot02 = LOT.Lottable02,
                        @dLot04 = LOT.Lottable04,
                        @cLoc = ISNULL(PTL.LOC,'')
         FROM dbo.DeviceProfileLog DPL WITH (NOLOCK)
         JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
          JOIN dbo.Orders OH WITH (NOLOCK)
         ON DPL.OrderKey = OH.OrderKey
         JOIN dbo.PTLTran PTL WITH (NOLOCK)
         ON OH.OrderKey = PTL.OrderKey
         AND DP.DeviceID = PTL.DeviceID
         AND DPL.DropID = PTL.DropID
         AND DPL.DeviceProfileLogKey = PTL.DeviceProfileLogKey
         JOIN dbo.LOTATTRIBUTE LOT WITH (NOLOCK)
         ON PTL.LOT = LOT.LOT
         WHERE DPL.DropID = @cToteID AND DPL.DeviceProfileLogKey = @cDeviceProfileLogKey
         AND PTL.SKU = ISNULL(@cSKU,'')
         AND LOT.Lottable02 >= ISNULL(@cLot02,'')
         AND LOT.Lottable04 > ISNULL(@dLot04,'0')
         ORDER BY ISNULL(LOT.Lottable02,''),ISNULL(LOT.Lottable04,'')

      END
      ELSE
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @nScn = @nScn - 4
	      SET @nStep = @nStep - 4
      END

      SET @cOutField09 = CAST(@nSKUPICK AS VARCHAR(10)) + '/' + CAST(@nSKUCnt AS VARCHAR(10))
      SET @cOutField10 = CAST(@nLot02Cnt AS VARCHAR(10)) + '/' + CAST(@nLot02Tot AS VARCHAR(10))
      SET @cOutField11 = @cSKU
      SET @cOutField12 = CAST(@nPutQty AS VARCHAR(10)) + '/' + CAST(@nPutTotQty AS VARCHAR(10))
      SET @cOutField13 = @cLot02
      SET @cOutField14 = RDT.RDTFormatDate(@dLot04)
      SET @cOutField15 = @cLoc
	END  -- Inputkey = 1

   IF @nInputKey = 0
   BEGIN
      -- Prepare Previous Screen Variable
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      
      -- GOTO Previous Screen
      SET @nScn = @nScn - 4
      SET @nStep = @nStep - 4
   END
	GOTO Quit

   STEP_5_FAIL:
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
   END
END
GOTO QUIT


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
      -- UserName  = @cUserName,
	   InputKey  =	@nInputKey,

      V_UOM = @cPUOM,

      V_String1 = @cCartID,
	   V_String2 = @cNextDevPos, 
	   V_String3 = @cDeviceProfileLogKey,  -- (james01)

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