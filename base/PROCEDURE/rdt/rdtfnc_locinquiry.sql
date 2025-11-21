SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_LOCInquiry                                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: SOS#89712 - To search for Locations information             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2007-11-15   1.0  Vicky      Created                                 */
/* 2011-04-19   1.1  James      Add database parameter                  */
/* 2016-09-30   1.2  Ung        Performance tuning                      */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_LOCInquiry] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- Misc variables
DECLARE
   @b_success      INT,
   @n_err          INT,
   @c_errmsg       NVARCHAR( 250),
   @i              INT,
   @nTask          INT,
   @cParentScn     NVARCHAR( 3),
   @cOption        NVARCHAR( 1),
   @cXML           NVARCHAR( 4000) -- To allow double byte data for e.g. SKU desc

-- RDT.RDTMobRec variables
DECLARE
   @nFunc          INT,
   @nScn           INT,
   @nStep          INT,
   @cLangCode      NVARCHAR( 3),
   @nInputKey      INT,
   @nMenu          INT,

   @nPrevScn       INT,
   @nPrevStep      INT,

   @cStorerKey     NVARCHAR( 15),
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cPrinter       NVARCHAR( 10),

   @cPutawayZone   NVARCHAR( 10),
   @cPickZone      NVARCHAR( 10),
   @cAisle         NVARCHAR( 10),
   @cLevel         NVARCHAR( 4),
   @cStartLoc      NVARCHAR( 10),
   @cEmpty         NVARCHAR( 1), -- 1 = YES, 2 = NO
   @cHold          NVARCHAR( 1), -- 1 = YES, 2 = NO
   @cLocType       NVARCHAR( 1), -- 1 = BULK, 2 = PICK

   @cLOC           NVARCHAR( 10),
   @cNoOfID        NVARCHAR( 3),
   @cMaxPallet     NVARCHAR( 2),
   @cMoreInfoOp    NVARCHAR( 2),

   @cLogicalLoc    NVARCHAR( 10),
   @cCCLogicalLoc  NVARCHAR( 10),
   @cLocationType  NVARCHAR( 10),
   @cLocationFlag  NVARCHAR( 10),
   @cLocHandling   NVARCHAR( 10),
   @cLocStatus     NVARCHAR( 10),

   @cLoseID        NVARCHAR( 1),
   @cABC           NVARCHAR( 1),
   @cComSKU        NVARCHAR( 1),
   @cComLOT        NVARCHAR( 1),

   @cDPutawayZone   NVARCHAR( 10),
   @cDPickZone      NVARCHAR( 10),

   @cLOC1          NVARCHAR( 10),
   @cIDCnt1        NVARCHAR( 3),
   @cMaxPallet1    NVARCHAR( 2),
   @cLOC2          NVARCHAR( 10),
   @cIDCnt2        NVARCHAR( 3),
   @cMaxPallet2    NVARCHAR( 2),
   @cLOC3          NVARCHAR( 10),
   @cIDCnt3        NVARCHAR( 3),
   @cMaxPallet3    NVARCHAR( 2),
   @cLOC4          NVARCHAR( 10),
   @cIDCnt4        NVARCHAR( 3),
   @cMaxPallet4    NVARCHAR( 2),
   @cLOC5          NVARCHAR( 10),
   @cIDCnt5        NVARCHAR( 3),
   @cMaxPallet5    NVARCHAR( 2),
   @cLOC6          NVARCHAR( 10),
   @cIDCnt6        NVARCHAR( 3),
   @cMaxPallet6    NVARCHAR( 2),
   @cLOC7          NVARCHAR( 10),
   @cIDCnt7        NVARCHAR( 3),
   @cMaxPallet7    NVARCHAR( 2),
   @cLOC8          NVARCHAR( 10),
   @cIDCnt8        NVARCHAR( 3),
   @cMaxPallet8    NVARCHAR( 2),
   @cLOC9          NVARCHAR( 10),
   @cIDCnt9        NVARCHAR( 3),
   @cMaxPallet9    NVARCHAR( 2),
   @cLOC10         NVARCHAR( 10),
   @cIDCnt10       NVARCHAR( 3),
   @cMaxPallet10   NVARCHAR( 2),

   @cMoreRec       NVARCHAR( 1),

   @cRec1          NVARCHAR( 4),
   @cRec2          NVARCHAR( 4),
   @cRec3          NVARCHAR( 4),
   @cRec4          NVARCHAR( 4),
   @cRec5          NVARCHAR( 4),
   @cRec6          NVARCHAR( 4),
   @cRec7          NVARCHAR( 4),
   @cRec8          NVARCHAR( 4),
   @cRec9          NVARCHAR( 4),
   @cRec10         NVARCHAR( 4),

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

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cPrinter         = Printer,

   @cPutawayZone     = V_String1,
   @cPickZone        = V_String2,
   @cAisle           = V_String3,
   @cLevel           = V_String4,
   @cStartLoc        = V_String5,
   @cEmpty           = V_String6,
   @cHold            = V_String7,
   @cLocType         = V_String8,

--    @cLOC             = V_String9,
--    @cNoOfID          = V_String10,
--    @cMaxPallet       = V_String11,
   @cMoreInfoOp      = V_String9,

   @cLogicalLoc      = V_String10,
   @cCCLogicalLoc    = V_String11,
   @cLocationType    = V_String12,
   @cLocationFlag    = V_String13,
   @cLocHandling     = V_String14,
   @cLocStatus       = V_String15,

   @cLoseID          = V_String16,
   @cABC             = V_String17,
   @cComSKU          = V_String18,
   @cComLOT          = V_String19,

   @cLOC1            = V_String20,
   @cLOC2            = V_String21,
   @cLOC3            = V_String22,
   @cLOC4            = V_String23,
   @cLOC5            = V_String24,
   @cLOC6            = V_String25,
   @cLOC7            = V_String26,
   @cLOC8            = V_String27,
   @cLOC9            = V_String28,
   @cLOC10           = V_String29,

   @cMoreRec         = V_String30,

   @cRec1            = V_String31,
   @cRec2            = V_String32,
   @cRec3            = V_String33,
   @cRec4            = V_String34,
   @cRec5            = V_String35,
   @cRec6            = V_String36,
   @cRec7            = V_String37,
   @cRec8            = V_String38,
   @cRec9            = V_String39,
   @cRec10           = V_String40,

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

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 558 -- LOC Inquiry
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = LOC Inquiry
   IF @nStep = 1 GOTO Step_1   -- Scn = 1630. PWAYZONE, PICKZONE, AISLE...
   IF @nStep = 2 GOTO Step_2   -- Scn = 1631. NO, LOC, ID/MAX
   IF @nStep = 3 GOTO Step_3   -- Scn = 1632. INF Display
END


RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_0. Func = 558
********************************************************************************/
Step_0:
BEGIN

   IF ISNULL(@cPrinter , '') = ''
   BEGIN
     SELECT @cPrinter = U.DefaultPrinter
     FROM RDT.rdtMobRec M (NOLOCK)
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)
     WHERE M.Mobile = @nMobile
   END

   SET @cPutawayZone = ''
   SET @cPickZone = ''
   SET @cAisle = ''
   SET @cLevel = ''
   SET @cStartLoc = ''
   SET @cEmpty = ''
   SET @cHold =  ''
   SET @cLocType = ''

   SET @cLOC = ''
   SET @cNoOfID = '0'
   SET @cMaxPallet = '0'
   SET @cMoreInfoOp = ''

   SET @cLogicalLoc = ''
   SET @cCCLogicalLoc = ''
   SET @cLocationType = ''
   SET @cLocationFlag = ''
   SET @cLocHandling = ''
   SET @cLocStatus = ''

   SET @cLoseID = ''
   SET @cABC = ''
   SET @cComSKU = ''
   SET @cComLOT = ''

   SET @cLOC1 = ''
   SET @cLOC2 = ''
   SET @cLOC3 = ''
   SET @cLOC4 = ''
   SET @cLOC5 = ''
   SET @cLOC6 = ''
   SET @cLOC7 = ''
   SET @cLOC8 = ''
   SET @cLOC9 = ''
   SET @cLOC10 = ''

   SET @cRec1 = ''
   SET @cRec2 = ''
   SET @cRec3 = ''
   SET @cRec4 = ''
   SET @cRec5 = ''
   SET @cRec6 = ''
   SET @cRec7 = ''
   SET @cRec8 = ''
   SET @cRec9 = ''
   SET @cRec10 = ''

   -- Prepare screen var
   SET @cOutField01 = '' -- PWAYZONE
   SET @cOutField02 = '' -- PICKZONE
   SET @cOutField03 = '' -- AISLE
   SET @cOutField04 = '' -- LEVEL
   SET @cOutField05 = '' -- START LOC
   SET @cOutField06 = '1' -- EMPTY
   SET @cOutField07 = '2' -- HOLD
   SET @cOutField08 = '1' -- LOC TYPE

   -- Set the entry point
   SET @nScn = 1630
   SET @nStep = 1

   GOTO QUIT

   Step_Fail:
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
	   SET @cOutField01 = '' -- PWAYZONE
	   SET @cOutField02 = '' -- PICKZONE
	   SET @cOutField03 = '' -- AISLE
	   SET @cOutField04 = '' -- LEVEL
	   SET @cOutField05 = '' -- START LOC
	   SET @cOutField06 = '' -- EMPTY
	   SET @cOutField07 = '' -- HOLD
	   SET @cOutField08 = '' -- LOC TYPE
   END
END
GOTO Quit


/************************************************************************************
Scn = 1630. PWAYZONE, PICKZONE...
   PWAYZONE   (field01, optional input)
   PICKZONE   (field02, optional input)
   AISLE      (field03, optional input)
   LEVEL      (field04, optional input)
   START LOC  (field05, optional input)
   EMPTY      (field06, input)
   HOLD       (field07, input)
   LOC TYPE   (field03, input)
************************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPutawayZone = @cInField01
      SET @cPickZone    = @cInField02
      SET @cAisle       = @cInField03
      SET @cLevel       = @cInField04
      SET @cStartLoc    = @cInField05
      SET @cEmpty       = @cInField06
      SET @cHold        = @cInField07
      SET @cLocType     = @cInField08

      -- Validate Putawayzone (if entered)
      IF @cPutawayZone <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.LOC LOC WITH (NOLOCK)
                        WHERE LOC.Putawayzone = @cPutawayZone
                        AND   LOC.Facility = @cFacility)
         BEGIN
            SET @nErrNo = 63751
            SET @cErrMsg = rdt.rdtgetmessage( 63751, @cLangCode, 'DSP') --Bad PWAYZONE
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- PWAYZONE
            SET @cPutawayZone = ''
            GOTO Step_1_Fail
         END
      END

      -- Validate Pickzone (if entered)
      IF @cPickZone <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.LOC LOC WITH (NOLOCK)
                        WHERE LOC.Pickzone = @cPickZone
                        AND   LOC.Facility = @cFacility)
         BEGIN
            SET @nErrNo = 63752
            SET @cErrMsg = rdt.rdtgetmessage( 63752, @cLangCode, 'DSP') --Bad PICKZONE
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- PICKZONE
            SET @cPickZone = ''
            GOTO Step_1_Fail
         END
      END

      -- Validate Aisle (if entered)
      IF @cAisle <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.LOC LOC WITH (NOLOCK)
                        WHERE LOC.LocAisle = @cAisle
                        AND   LOC.Facility = @cFacility)
         BEGIN
            SET @nErrNo = 63753
            SET @cErrMsg = rdt.rdtgetmessage( 63753, @cLangCode, 'DSP') --Invalid AISLE
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- Aisle
            SET @cAisle = ''
            GOTO Step_1_Fail
         END
      END

      -- Validate Level (if entered)
      IF @cLevel <> ''
      BEGIN
         IF RDT.rdtIsValidQTY( @cLevel, 0) = 0
	      BEGIN
	         SET @nErrNo = 63774
	         SET @cErrMsg = rdt.rdtgetmessage( 63774, @cLangCode, 'DSP') --Invalid LEVEL
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- Level
            SET @cLevel = ''
	         GOTO Step_1_Fail
	      END

         IF NOT EXISTS (SELECT 1 FROM dbo.LOC LOC WITH (NOLOCK)
                        WHERE LOC.LocLevel = @cLevel
                        AND   LOC.Facility = @cFacility)
         BEGIN
            SET @nErrNo = 63754
            SET @cErrMsg = rdt.rdtgetmessage( 63754, @cLangCode, 'DSP') --Invalid LEVEL
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- Level
            SET @cLevel = ''
            GOTO Step_1_Fail
         END
      END

      -- Validate Start LOC (if entered)
      IF @cStartLoc <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.LOC LOC WITH (NOLOCK)
                        WHERE LOC.LOC = @cStartLoc
                        AND   LOC.Facility = @cFacility)
         BEGIN
            SET @nErrNo = 63755
            SET @cErrMsg = rdt.rdtgetmessage( 63755, @cLangCode, 'DSP') --Invalid LOC
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- StartLOC
            SET @cStartLoc = ''
            GOTO Step_1_Fail
         END

	      DECLARE @cChkFacility NVARCHAR( 5)
	      SELECT @cChkFacility = Facility
	      FROM dbo.LOC (NOLOCK)
	      WHERE LOC = @cStartLoc

	      IF @cChkFacility <> @cFacility
	      BEGIN
	         SET @nErrNo = 63756
	         SET @cErrMsg = rdt.rdtgetmessage( 63756, @cLangCode, 'DSP') --Diff Facility
	         EXEC rdt.rdtSetFocusField @nMobile, 5 -- StartLOC
            SET @cStartLoc = ''
	         GOTO Step_1_Fail
	      END
      END

      -- Validate Empty field (if entered)
      IF @cEmpty <> '1' AND @cEmpty <> '2' AND @cEmpty <> ''
      BEGIN
         SET @nErrNo = 63757
         SET @cErrMsg = rdt.rdtgetmessage( 63757, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- Empty
         SET @cEmpty = ''
         GOTO Step_1_Fail
      END

      -- Validate Hold field (if entered)
      IF @cHold <> '1' AND @cHold <> '2' AND @cHold <> ''
      BEGIN
         SET @nErrNo = 63758
         SET @cErrMsg = rdt.rdtgetmessage( 63758, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 7 -- Hold
         SET @cHold = ''
         GOTO Step_1_Fail
      END

      -- Validate LOC Type field (if entered)
      IF @cLocType <> '1' AND @cLocType <> '2'
      BEGIN
         SET @nErrNo = 63759
         SET @cErrMsg = rdt.rdtgetmessage( 63759, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- LocType
         SET @cLocType = ''
         GOTO Step_1_Fail
      END

      -- Start Retrive according to Criterias
		EXECUTE rdt.rdt_LOCInquiry_CriteriaRetrieval
				   @cPutawayZone,  @cPickZone,       @cAisle,       @cLevel,  @cStartLoc,
				   @cEmpty, 	    @cHold,	          @cLocType,     'Y',      @cFacility,
				   @cLOC1 OUTPUT,  @cIDCnt1 OUTPUT,  @cMaxPallet1 OUTPUT,
				   @cLOC2 OUTPUT,  @cIDCnt2 OUTPUT,  @cMaxPallet2 OUTPUT,
				   @cLOC3 OUTPUT,  @cIDCnt3 OUTPUT,  @cMaxPallet3 OUTPUT,
				   @cLOC4 OUTPUT,  @cIDCnt4 OUTPUT,  @cMaxPallet4 OUTPUT,
				   @cLOC5 OUTPUT,  @cIDCnt5 OUTPUT,  @cMaxPallet5 OUTPUT,
				   @cLOC6 OUTPUT,  @cIDCnt6 OUTPUT,  @cMaxPallet6 OUTPUT,
				   @cLOC7 OUTPUT,  @cIDCnt7 OUTPUT,  @cMaxPallet7 OUTPUT,
				   @cLOC8 OUTPUT,  @cIDCnt8 OUTPUT,  @cMaxPallet8 OUTPUT,
				   @cLOC9 OUTPUT,  @cIDCnt9 OUTPUT,  @cMaxPallet9 OUTPUT,
				   @cLOC10 OUTPUT, @cIDCnt10 OUTPUT, @cMaxPallet10 OUTPUT,
               @cMoreRec OUTPUT

     -- Concatenate IDCnt + MaxPallet
     SET @cRec1 = CONVERT(CHAR(2), @cIDCnt1) + CONVERT(CHAR(2), @cMaxPallet1)
     SET @cRec2 = CONVERT(CHAR(2), @cIDCnt2) + CONVERT(CHAR(2), @cMaxPallet2)
     SET @cRec3 = CONVERT(CHAR(2), @cIDCnt3) + CONVERT(CHAR(2), @cMaxPallet3)
     SET @cRec4 = CONVERT(CHAR(2), @cIDCnt4) + CONVERT(CHAR(2), @cMaxPallet4)
     SET @cRec5 = CONVERT(CHAR(2), @cIDCnt5) + CONVERT(CHAR(2), @cMaxPallet5)
     SET @cRec6 = CONVERT(CHAR(2), @cIDCnt6) + CONVERT(CHAR(2), @cMaxPallet6)
     SET @cRec7 = CONVERT(CHAR(2), @cIDCnt7) + CONVERT(CHAR(2), @cMaxPallet7)
     SET @cRec8 = CONVERT(CHAR(2), @cIDCnt8) + CONVERT(CHAR(2), @cMaxPallet8)
     SET @cRec9 = CONVERT(CHAR(2), @cIDCnt9) + CONVERT(CHAR(2), @cMaxPallet9)
     SET @cRec10 = CONVERT(CHAR(2), @cIDCnt10) + CONVERT(CHAR(2), @cMaxPallet10)

      -- Prepare Next screen var
      SET @cOutField01 = CONVERT(CHAR(11), @cLOC1) +
                         RIGHT(RTRIM(REPLICATE(' ', 2) + @cIDCnt1), 2) +
                         --CONVERT(CHAR(2), RTRIM(@cIDCnt1)) +
                         CASE WHEN @cLOC1 <> '' THEN '/' ELSE '' END +
                         --CONVERT(CHAR(2), RTRIM(@cMaxPallet1))
                         RIGHT(RTRIM(REPLICATE('', 2) + @cMaxPallet1), 2)
      SET @cOutField02 = CONVERT(CHAR(11), @cLOC2) +
                         RIGHT(RTRIM(REPLICATE(' ', 2) + @cIDCnt2), 2) +
                         --CONVERT(CHAR(2), @cIDCnt2) +
                         CASE WHEN @cLOC2 <> '' THEN '/' ELSE '' END +
                         --CONVERT(CHAR(2), @cMaxPallet2)
                         RIGHT(RTRIM(REPLICATE('', 2) + @cMaxPallet2), 2)
      SET @cOutField03 = CONVERT(CHAR(11), @cLOC3) +
                         RIGHT(RTRIM(REPLICATE(' ', 2) + @cIDCnt3), 2) +
                         --CONVERT(CHAR(2), @cIDCnt3) +
                         CASE WHEN @cLOC3 <> '' THEN '/' ELSE '' END +
                         --CONVERT(CHAR(2), @cMaxPallet3)
                         RIGHT(RTRIM(REPLICATE('', 2) + @cMaxPallet3), 2)
      SET @cOutField04 = CONVERT(CHAR(11), @cLOC4) +
                         RIGHT(RTRIM(REPLICATE(' ', 2) + @cIDCnt4), 2) +
                         --CONVERT(CHAR(2), @cIDCnt4) +
                         CASE WHEN @cLOC4 <> '' THEN '/' ELSE '' END +
                         --CONVERT(CHAR(2), @cMaxPallet4)
                         RIGHT(RTRIM(REPLICATE('', 2) + @cMaxPallet4), 2)
      SET @cOutField05 = CONVERT(CHAR(11), @cLOC5) +
                         RIGHT(RTRIM(REPLICATE(' ', 2) + @cIDCnt5), 2) +
                         --CONVERT(CHAR(2), @cIDCnt5) +
                         CASE WHEN @cLOC5 <> '' THEN '/' ELSE '' END +
                         --CONVERT(CHAR(2), @cMaxPallet5)
                         RIGHT(RTRIM(REPLICATE('', 2) + @cMaxPallet5), 2)
      SET @cOutField06 = CONVERT(CHAR(11), @cLOC6) +
                         RIGHT(RTRIM(REPLICATE(' ', 2) + @cIDCnt6), 2) +
                         --CONVERT(CHAR(2), @cIDCnt6) +
                         CASE WHEN @cLOC6 <> '' THEN '/' ELSE '' END +
                         --CONVERT(CHAR(2), @cMaxPallet6)
                         RIGHT(RTRIM(REPLICATE('', 2) + @cMaxPallet6), 2)
      SET @cOutField07 = CONVERT(CHAR(11), @cLOC7) +
                         RIGHT(RTRIM(REPLICATE(' ', 2) + @cIDCnt7), 2) +
                         --CONVERT(CHAR(2), @cIDCnt7) +
                         CASE WHEN @cLOC7 <> '' THEN '/' ELSE '' END +
                         --CONVERT(CHAR(2), @cMaxPallet7)
                         RIGHT(RTRIM(REPLICATE('', 2) + @cMaxPallet7), 2)
      SET @cOutField08 = CONVERT(CHAR(11), @cLOC8) +
                         RIGHT(RTRIM(REPLICATE(' ', 2) + @cIDCnt8), 2) +
                         --CONVERT(CHAR(2), @cIDCnt8) +
                         CASE WHEN @cLOC8 <> '' THEN '/' ELSE '' END +
                         --CONVERT(CHAR(2), @cMaxPallet8)
                         RIGHT(RTRIM(REPLICATE('', 2) + @cMaxPallet8), 2)
      SET @cOutField09 = CONVERT(CHAR(11), @cLOC9) +
                         RIGHT(RTRIM(REPLICATE(' ', 2) + @cIDCnt9), 2) +
                         --CONVERT(CHAR(2), @cIDCnt9) +
                         CASE WHEN @cLOC9 <> '' THEN '/' ELSE '' END +
                         --CONVERT(CHAR(2), @cMaxPallet9)
                         RIGHT(RTRIM(REPLICATE('', 2) + @cMaxPallet9), 2)
      SET @cOutField10 = CONVERT(CHAR(11), @cLOC10) +
                         RIGHT(RTRIM(REPLICATE(' ', 2) + @cIDCnt10), 2) +
                         --CONVERT(CHAR(2), @cIDCnt10) +
                         CASE WHEN @cLOC10 <> '' THEN '/' ELSE '' END +
                         --CONVERT(CHAR(2), @cMaxPallet10)
                         RIGHT(RTRIM(REPLICATE('', 2) + @cMaxPallet10), 2)
      SET @cOutField11 = '' -- INF

      IF @cLOC1 = ''
      BEGIN
         SET @nErrNo = 63760
         SET @cErrMsg = rdt.rdtgetmessage( 63760, @cLangCode, 'DSP') --No Record

		   SET @cOutField01 = @cPutawayZone -- PWAYZONE
		   SET @cOutField02 = @cPickZone -- PICKZONE
		   SET @cOutField03 = @cAisle -- AISLE
		   SET @cOutField04 = @cLevel -- LEVEL
		   SET @cOutField05 = @cStartLoc -- START LOC
		   SET @cOutField06 = @cEmpty -- EMPTY
		   SET @cOutField07 = @cHold -- HOLD
		   SET @cOutField08 = @cLocType -- LOC TYPE

	      -- Stay at current screen
		   SET @nScn = @nScn
		   SET @nStep = @nStep

	      GOTO QUIT
      END

      -- Go to Next screen
	   SET @nScn = @nScn + 1
	   SET @nStep = @nStep + 1

      GOTO QUIT
	END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

	   SET @cPutawayZone = ''
	   SET @cPickZone = ''
	   SET @cAisle = ''
	   SET @cLevel = ''
	   SET @cStartLoc = ''
	   SET @cEmpty = ''
	   SET @cHold =  ''
	   SET @cLocType = ''

	   SET @cLOC = ''
	   SET @cNoOfID = '0'
	   SET @cMaxPallet = '0'
	   SET @cMoreInfoOp = ''

	   SET @cLogicalLoc = ''
	   SET @cCCLogicalLoc = ''
	   SET @cLocationType = ''
	   SET @cLocationFlag = ''
	   SET @cLocHandling = ''
	   SET @cLocStatus = ''

	   SET @cLoseID = ''
	   SET @cABC = ''
	   SET @cComSKU = ''
	   SET @cComLOT = ''

      SET @cLOC1 = ''
      SET @cLOC2 = ''
      SET @cLOC3 = ''
      SET @cLOC4 = ''
      SET @cLOC5 = ''
      SET @cLOC6 = ''
      SET @cLOC7 = ''
      SET @cLOC8 = ''
      SET @cLOC9 = ''
      SET @cLOC10 = ''

      SET @cRec1 = ''
      SET @cRec2 = ''
      SET @cRec3 = ''
      SET @cRec4 = ''
      SET @cRec5 = ''
      SET @cRec6 = ''
      SET @cRec7 = ''
      SET @cRec8 = ''
      SET @cRec9 = ''
      SET @cRec10 = ''

	   SET @cOutField01 = '' -- PWAYZONE
	   SET @cOutField02 = '' -- PICKZONE
	   SET @cOutField03 = '' -- AISLE
	   SET @cOutField04 = '' -- LEVEL
	   SET @cOutField05 = '' -- START LOC
	   SET @cOutField06 = '' -- EMPTY
	   SET @cOutField07 = '' -- HOLD
	   SET @cOutField08 = '' -- LOC TYPE
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
-- 	   SET @cPutawayZone = ''
-- 	   SET @cPickZone = ''
-- 	   SET @cAisle = ''
-- 	   SET @cLevel = ''
-- 	   SET @cStartLoc = ''
-- 	   SET @cEmpty = ''
-- 	   SET @cHold =  ''
-- 	   SET @cLocType = ''

	   SET @cLOC = ''
	   SET @cNoOfID = '0'
	   SET @cMaxPallet = '0'
	   SET @cMoreInfoOp = ''

	   SET @cLogicalLoc = ''
	   SET @cCCLogicalLoc = ''
	   SET @cLocationType = ''
	   SET @cLocationFlag = ''
	   SET @cLocHandling = ''
	   SET @cLocStatus = ''

	   SET @cLoseID = ''
	   SET @cABC = ''
	   SET @cComSKU = ''
	   SET @cComLOT = ''

      SET @cLOC1 = ''
      SET @cLOC2 = ''
      SET @cLOC3 = ''
      SET @cLOC4 = ''
      SET @cLOC5 = ''
      SET @cLOC6 = ''
      SET @cLOC7 = ''
      SET @cLOC8 = ''
      SET @cLOC9 = ''
      SET @cLOC10 = ''

      SET @cRec1 = ''
      SET @cRec2 = ''
      SET @cRec3 = ''
      SET @cRec4 = ''
      SET @cRec5 = ''
      SET @cRec6 = ''
      SET @cRec7 = ''
      SET @cRec8 = ''
      SET @cRec9 = ''
      SET @cRec10 = ''

	   -- Prepare screen var
-- 	   SET @cOutField01 = '' -- PWAYZONE
-- 	   SET @cOutField02 = '' -- PICKZONE
-- 	   SET @cOutField03 = '' -- AISLE
-- 	   SET @cOutField04 = '' -- LEVEL
-- 	   SET @cOutField05 = '' -- START LOC
-- 	   SET @cOutField06 = '1' -- EMPTY
-- 	   SET @cOutField07 = '2' -- HOLD
-- 	   SET @cOutField08 = '1' -- LOC TYPE
	   SET @cOutField01 = @cPutawayZone -- PWAYZONE
	   SET @cOutField02 = @cPickZone -- PICKZONE
	   SET @cOutField03 = @cAisle -- AISLE
	   SET @cOutField04 = @cLevel -- LEVEL
	   SET @cOutField05 = @cStartLoc -- START LOC
	   SET @cOutField06 = @cEmpty -- EMPTY
	   SET @cOutField07 = @cHold -- HOLD
	   SET @cOutField08 = @cLocType -- LOC TYPE
   END
END
GOTO Quit


/***********************************************************************************
Scn = 1631. NO, LOC, ID/MAX screen
   NO
   LOC      (field01)
   ID/MAX   (field02, field03)
***********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN

      SET @cMoreInfoOp =  @cInField11

      IF @cMoreInfoOp <> ''
      BEGIN
         IF rdt.rdtIsValidQTY( @cMoreInfoOp, 1) = 0
         BEGIN
	         SET @nErrNo = 63775
	         SET @cErrMsg = rdt.rdtgetmessage( 63775, @cLangCode, 'DSP') -- Invalid LOC#
	         EXEC rdt.rdtSetFocusField @nMobile, 31 -- INF
--	         GOTO Step_2_Fail
		      SET @nScn = @nScn
		      SET @nStep = @nStep
	         GOTO QUIT
         END

--          IF ISNUMERIC(@cMoreInfoOp) = 0
--          BEGIN
-- 	         SET @nErrNo = 63776
-- 	         SET @cErrMsg = rdt.rdtgetmessage( 63776, @cLangCode, 'DSP') -- Invalid LOC#
-- 	         EXEC rdt.rdtSetFocusField @nMobile, 31 -- INF
-- 	         GOTO Step_2_Fail
--          END

	      IF ( CAST(@cMoreInfoOp AS INT) < 1 ) OR ( CAST(@cMoreInfoOp AS INT) > 10 )
	      BEGIN
	         SET @nErrNo = 63761
	         SET @cErrMsg = rdt.rdtgetmessage( 63761, @cLangCode, 'DSP') -- Invalid LOC#
	         EXEC rdt.rdtSetFocusField @nMobile, 31 -- INF
--	         GOTO Step_2_Fail
		      SET @nScn = @nScn
		      SET @nStep = @nStep
	         GOTO QUIT
	      END
      END

      IF CAST(@cMoreInfoOp AS INT) = 1 AND @cLOC1 = ''
      BEGIN
         SET @nErrNo = 63762
         SET @cErrMsg = rdt.rdtgetmessage( 63762, @cLangCode, 'DSP') -- Invalid LOC#
         EXEC rdt.rdtSetFocusField @nMobile, 31 -- INF
         --GOTO Step_2_Fail
	      SET @nScn = @nScn
	      SET @nStep = @nStep
         GOTO QUIT
      END

      IF CAST(@cMoreInfoOp AS INT) = 2 AND @cLOC2 = ''
      BEGIN
         SET @nErrNo = 63763
         SET @cErrMsg = rdt.rdtgetmessage( 63763, @cLangCode, 'DSP') -- Invalid LOC#
         EXEC rdt.rdtSetFocusField @nMobile, 31 -- INF
--         GOTO Step_2_Fail
	      SET @nScn = @nScn
	      SET @nStep = @nStep
         GOTO QUIT
      END

      IF CAST(@cMoreInfoOp AS INT) = 3 AND @cLOC3 = ''
      BEGIN
         SET @nErrNo = 63764
         SET @cErrMsg = rdt.rdtgetmessage( 63764, @cLangCode, 'DSP') -- Invalid LOC#
         EXEC rdt.rdtSetFocusField @nMobile, 31 -- INF
--    GOTO Step_2_Fail
	      SET @nScn = @nScn
	      SET @nStep = @nStep
         GOTO QUIT
      END

      IF CAST(@cMoreInfoOp AS INT) = 4 AND @cLOC4 = ''
      BEGIN
         SET @nErrNo = 63765
         SET @cErrMsg = rdt.rdtgetmessage( 63765, @cLangCode, 'DSP') -- Invalid LOC#
         EXEC rdt.rdtSetFocusField @nMobile, 31 -- INF
--         GOTO Step_2_Fail
	      SET @nScn = @nScn
	      SET @nStep = @nStep
         GOTO QUIT
      END

      IF CAST(@cMoreInfoOp AS INT) = 5 AND @cLOC5 = ''
      BEGIN
         SET @nErrNo = 63766
         SET @cErrMsg = rdt.rdtgetmessage( 63766, @cLangCode, 'DSP') -- Invalid LOC#
         EXEC rdt.rdtSetFocusField @nMobile, 31 -- INF
--         GOTO Step_2_Fail
	      SET @nScn = @nScn
	      SET @nStep = @nStep
         GOTO QUIT
      END

      IF CAST(@cMoreInfoOp AS INT) = 6 AND @cLOC6 = ''
      BEGIN
         SET @nErrNo = 63767
         SET @cErrMsg = rdt.rdtgetmessage( 63767, @cLangCode, 'DSP') -- Invalid LOC#
         EXEC rdt.rdtSetFocusField @nMobile, 31 -- INF
--         GOTO Step_2_Fail
	      SET @nScn = @nScn
	      SET @nStep = @nStep
         GOTO QUIT
      END

      IF CAST(@cMoreInfoOp AS INT) = 7 AND @cLOC7 = ''
      BEGIN
         SET @nErrNo = 63768
         SET @cErrMsg = rdt.rdtgetmessage( 63768, @cLangCode, 'DSP') -- Invalid LOC#
         EXEC rdt.rdtSetFocusField @nMobile, 31 -- INF
--         GOTO Step_2_Fail
	      SET @nScn = @nScn
	      SET @nStep = @nStep
         GOTO QUIT
      END

      IF CAST(@cMoreInfoOp AS INT) = 8 AND @cLOC8 = ''
      BEGIN
         SET @nErrNo = 63769
         SET @cErrMsg = rdt.rdtgetmessage( 63769, @cLangCode, 'DSP') -- Invalid LOC#
         EXEC rdt.rdtSetFocusField @nMobile, 31 -- INF
--         GOTO Step_2_Fail
	      SET @nScn = @nScn
	      SET @nStep = @nStep
         GOTO QUIT
      END

      IF CAST(@cMoreInfoOp AS INT) = 9 AND @cLOC9 = ''
      BEGIN
         SET @nErrNo = 63770
         SET @cErrMsg = rdt.rdtgetmessage( 63770, @cLangCode, 'DSP') -- Invalid LOC#
         EXEC rdt.rdtSetFocusField @nMobile, 31 -- INF
--         GOTO Step_2_Fail
	      SET @nScn = @nScn
	      SET @nStep = @nStep
         GOTO QUIT
      END

      IF CAST(@cMoreInfoOp AS INT) = 10 AND @cLOC10 = ''
      BEGIN
         SET @nErrNo = 63771
         SET @cErrMsg = rdt.rdtgetmessage( 63771, @cLangCode, 'DSP') -- Invalid LOC#
         EXEC rdt.rdtSetFocusField @nMobile, 31 -- INF
--         GOTO Step_2_Fail
	      SET @nScn = @nScn
	      SET @nStep = @nStep
         GOTO QUIT
      END

      IF @cMoreInfoOp = ''
      BEGIN

          DECLARE @cDummyLoc1 NVARCHAR(10), @cDummyLoc2 NVARCHAR(10),
                  @cDummyLoc3 NVARCHAR(10), @cDummyLoc4 NVARCHAR(10),
                  @cDummyLoc5 NVARCHAR(10), @cDummyLoc6 NVARCHAR(10),
                  @cDummyLoc7 NVARCHAR(10), @cDummyLoc8 NVARCHAR(10),
                  @cDummyLoc9 NVARCHAR(10), @cDummyLoc10 NVARCHAR(10),
                  @cDummyLoc NVARCHAR(1)


          IF @cMoreRec = 'Y'
          BEGIN
            SET @cDummyLoc1 = @cLOC1
            SET @cDummyLoc2 = @cLOC2
            SET @cDummyLoc3 = @cLOC3
            SET @cDummyLoc4 = @cLOC4
            SET @cDummyLoc5 = @cLOC5
            SET @cDummyLoc6 = @cLOC6
            SET @cDummyLoc7 = @cLOC7
            SET @cDummyLoc8 = @cLOC8
            SET @cDummyLoc9 = @cLOC9
            SET @cDummyLoc10 = @cLOC10
          END

-- 	         SET @cErrMsg = @cDummyLoc1
-- 	         GOTO Step_2_Fail

	       -- Retrieve next 10 Records if first Record returned 10 lines
	       IF @cLOC10 <> '' AND @cMoreRec = 'Y'
	       BEGIN
		      -- Start Retrive Next 10 Records
				EXECUTE rdt.rdt_LOCInquiry_CriteriaRetrieval
					   @cPutawayZone,  @cPickZone,       @cAisle,     @cLevel,   @cLOC10, -- Use LOC10 as StartLoc
					   @cEmpty, 	    @cHold,	          @cLocType,   'N',       @cFacility,
					   @cLOC1 OUTPUT,  @cIDCnt1 OUTPUT,  @cMaxPallet1 OUTPUT,
					   @cLOC2 OUTPUT,  @cIDCnt2 OUTPUT,  @cMaxPallet2 OUTPUT,
					   @cLOC3 OUTPUT,  @cIDCnt3 OUTPUT,  @cMaxPallet3 OUTPUT,
					   @cLOC4 OUTPUT,  @cIDCnt4 OUTPUT,  @cMaxPallet4 OUTPUT,
					   @cLOC5 OUTPUT,  @cIDCnt5 OUTPUT,  @cMaxPallet5 OUTPUT,
					   @cLOC6 OUTPUT,  @cIDCnt6 OUTPUT,  @cMaxPallet6 OUTPUT,
					   @cLOC7 OUTPUT,  @cIDCnt7 OUTPUT,  @cMaxPallet7 OUTPUT,
					   @cLOC8 OUTPUT,  @cIDCnt8 OUTPUT,  @cMaxPallet8 OUTPUT,
					   @cLOC9 OUTPUT,  @cIDCnt9 OUTPUT,  @cMaxPallet9 OUTPUT,
					   @cLOC10 OUTPUT, @cIDCnt10 OUTPUT, @cMaxPallet10 OUTPUT,
	               @cMoreRec OUTPUT
	      END
	      ELSE IF (@cLOC10 = '' AND @cMoreRec = 'Y') OR (@cLOC10 <> '' AND @cMoreRec = 'N')-- Message if not more records to return
	      BEGIN
	         SET @nErrNo = 63772
	         SET @cErrMsg = rdt.rdtgetmessage( 63772, @cLangCode, 'DSP') -- No more record
	         EXEC rdt.rdtSetFocusField @nMobile, 31 -- INF
--	         GOTO Step_2_Fail
            SET @cLOC1 = Substring(@cOutField01,1, 10)
            SET @cLOC2 = Substring(@cOutField02,1, 10)
            SET @cLOC3 = Substring(@cOutField03,1, 10)
            SET @cLOC4 = Substring(@cOutField04,1, 10)
            SET @cLOC5 = Substring(@cOutField05,1, 10)
            SET @cLOC6 = Substring(@cOutField06,1, 10)
            SET @cLOC7 = Substring(@cOutField07,1, 10)
            SET @cLOC8 = Substring(@cOutField08,1, 10)
            SET @cLOC9 = Substring(@cOutField09,1, 10)
            SET @cLOC10 = Substring(@cOutField10,1, 10)

	         SET @nScn = @nScn
	         SET @nStep = @nStep
            GOTO QUIT
	      END


         --IF (@cLOC10 = '') OR (@cLOC10 <> '' AND @cMoreRec = 'N')-- Message if not more records to return
         IF @cMoreRec = 'N'
	      BEGIN
	         SET @nErrNo = 63773
	         SET @cErrMsg = rdt.rdtgetmessage( 63773, @cLangCode, 'DSP') -- No more record
	         EXEC rdt.rdtSetFocusField @nMobile, 31 -- INF

            SET @cLOC1 = Substring(@cOutField01,1, 10)
            SET @cLOC2 = Substring(@cOutField02,1, 10)
            SET @cLOC3 = Substring(@cOutField03,1, 10)
            SET @cLOC4 = Substring(@cOutField04,1, 10)
            SET @cLOC5 = Substring(@cOutField05,1, 10)
            SET @cLOC6 = Substring(@cOutField06,1, 10)
            SET @cLOC7 = Substring(@cOutField07,1, 10)
            SET @cLOC8 = Substring(@cOutField08,1, 10)
            SET @cLOC9 = Substring(@cOutField09,1, 10)
            SET @cLOC10 = Substring(@cOutField10,1, 10)

	         SET @nScn = @nScn
	         SET @nStep = @nStep

	         --GOTO Step_MoreRecN_Fail

           GOTO QUIT
	      END

	      -- Concatenate IDCnt + MaxPallet
	      SET @cRec1 = CONVERT(CHAR(2), @cIDCnt1) + CONVERT(CHAR(2), @cMaxPallet1)
	      SET @cRec2 = CONVERT(CHAR(2), @cIDCnt2) + CONVERT(CHAR(2), @cMaxPallet2)
	      SET @cRec3 = CONVERT(CHAR(2), @cIDCnt3) + CONVERT(CHAR(2), @cMaxPallet3)
	      SET @cRec4 = CONVERT(CHAR(2), @cIDCnt4) + CONVERT(CHAR(2), @cMaxPallet4)
	      SET @cRec5 = CONVERT(CHAR(2), @cIDCnt5) + CONVERT(CHAR(2), @cMaxPallet5)
	      SET @cRec6 = CONVERT(CHAR(2), @cIDCnt6) + CONVERT(CHAR(2), @cMaxPallet6)
	      SET @cRec7 = CONVERT(CHAR(2), @cIDCnt7) + CONVERT(CHAR(2), @cMaxPallet7)
	      SET @cRec8 = CONVERT(CHAR(2), @cIDCnt8) + CONVERT(CHAR(2), @cMaxPallet8)
	      SET @cRec9 = CONVERT(CHAR(2), @cIDCnt9) + CONVERT(CHAR(2), @cMaxPallet9)
	      SET @cRec10 = CONVERT(CHAR(2), @cIDCnt10) + CONVERT(CHAR(2), @cMaxPallet10)

         -- Loop Next 10 Records
	      SET @cOutField01 = CONVERT(CHAR(11), @cLOC1) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + @cIDCnt1), 2) +
	                         --CONVERT(CHAR(2), RTRIM(@cIDCnt1)) +
	                         CASE WHEN @cLOC1 <> '' THEN '/' ELSE '' END +
	                         --CONVERT(CHAR(2), RTRIM(@cMaxPallet1))
	                         RIGHT(RTRIM(REPLICATE('', 2) + @cMaxPallet1), 2)
	      SET @cOutField02 = CONVERT(CHAR(11), @cLOC2) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + @cIDCnt2), 2) +
	                         --CONVERT(CHAR(2), @cIDCnt2) +
	                         CASE WHEN @cLOC2 <> '' THEN '/' ELSE '' END +
	                         --CONVERT(CHAR(2), @cMaxPallet2)
	                         RIGHT(RTRIM(REPLICATE('', 2) + @cMaxPallet2), 2)
	      SET @cOutField03 = CONVERT(CHAR(11), @cLOC3) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + @cIDCnt3), 2) +
	                         --CONVERT(CHAR(2), @cIDCnt3) +
	                         CASE WHEN @cLOC3 <> '' THEN '/' ELSE '' END +
	                         --CONVERT(CHAR(2), @cMaxPallet3)
	                         RIGHT(RTRIM(REPLICATE('', 2) + @cMaxPallet3), 2)
	      SET @cOutField04 = CONVERT(CHAR(11), @cLOC4) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + @cIDCnt4), 2) +
	                         --CONVERT(CHAR(2), @cIDCnt4) +
	                         CASE WHEN @cLOC4 <> '' THEN '/' ELSE '' END +
	                         --CONVERT(CHAR(2), @cMaxPallet4)
	                         RIGHT(RTRIM(REPLICATE('', 2) + @cMaxPallet4), 2)
	      SET @cOutField05 = CONVERT(CHAR(11), @cLOC5) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + @cIDCnt5), 2) +
	                         --CONVERT(CHAR(2), @cIDCnt5) +
	                         CASE WHEN @cLOC5 <> '' THEN '/' ELSE '' END +
	                         --CONVERT(CHAR(2), @cMaxPallet5)
	                         RIGHT(RTRIM(REPLICATE('', 2) + @cMaxPallet5), 2)
	      SET @cOutField06 = CONVERT(CHAR(11), @cLOC6) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + @cIDCnt6), 2) +
	                         --CONVERT(CHAR(2), @cIDCnt6) +
	                         CASE WHEN @cLOC6 <> '' THEN '/' ELSE '' END +
	                         --CONVERT(CHAR(2), @cMaxPallet6)
	                         RIGHT(RTRIM(REPLICATE('', 2) + @cMaxPallet6), 2)
	      SET @cOutField07 = CONVERT(CHAR(11), @cLOC7) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + @cIDCnt7), 2) +
	                         --CONVERT(CHAR(2), @cIDCnt7) +
	                         CASE WHEN @cLOC7 <> '' THEN '/' ELSE '' END +
	                         --CONVERT(CHAR(2), @cMaxPallet7)
	                         RIGHT(RTRIM(REPLICATE('', 2) + @cMaxPallet7), 2)
	      SET @cOutField08 = CONVERT(CHAR(11), @cLOC8) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + @cIDCnt8), 2) +
	                         --CONVERT(CHAR(2), @cIDCnt8) +
	                         CASE WHEN @cLOC8 <> '' THEN '/' ELSE '' END +
	                         --CONVERT(CHAR(2), @cMaxPallet8)
	                         RIGHT(RTRIM(REPLICATE('', 2) + @cMaxPallet8), 2)
	      SET @cOutField09 = CONVERT(CHAR(11), @cLOC9) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + @cIDCnt9), 2) +
	                         --CONVERT(CHAR(2), @cIDCnt9) +
	                         CASE WHEN @cLOC9 <> '' THEN '/' ELSE '' END +
	                         --CONVERT(CHAR(2), @cMaxPallet9)
	                         RIGHT(RTRIM(REPLICATE('', 2) + @cMaxPallet9), 2)
	      SET @cOutField10 = CONVERT(CHAR(11), @cLOC10) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + @cIDCnt10), 2) +
	                         --CONVERT(CHAR(2), @cIDCnt10) +
	                         CASE WHEN @cLOC10 <> '' THEN '/' ELSE '' END +
	                         --CONVERT(CHAR(2), @cMaxPallet10)
	                         RIGHT(RTRIM(REPLICATE('', 2) + @cMaxPallet10), 2)
         SET @cOutField11 = '' -- INF


         SET @nScn = @nScn
         SET @nStep = @nStep

         GOTO QUIT
     END
     ELSE
     BEGIN -- @cMoreInfoOp <> ''
         SET @cLOC = CASE WHEN CAST(@cMoreInfoOp AS INT) = 1 THEN @cLOC1
        WHEN CAST(@cMoreInfoOp AS INT) = 2 THEN @cLOC2
                          WHEN CAST(@cMoreInfoOp AS INT) = 3 THEN @cLOC3
                          WHEN CAST(@cMoreInfoOp AS INT) = 4 THEN @cLOC4
                          WHEN CAST(@cMoreInfoOp AS INT) = 5 THEN @cLOC5
                          WHEN CAST(@cMoreInfoOp AS INT) = 6 THEN @cLOC6
                          WHEN CAST(@cMoreInfoOp AS INT) = 7 THEN @cLOC7
                          WHEN CAST(@cMoreInfoOp AS INT) = 8 THEN @cLOC8
                          WHEN CAST(@cMoreInfoOp AS INT) = 9 THEN @cLOC9
                          WHEN CAST(@cMoreInfoOp AS INT) = 10 THEN @cLOC10
                      END

          EXECUTE rdt.rdt_LOCInquiry_InfoRetrieval
				   @cLOC,  @cFacility,
				   @cDPutawayZone OUTPUT, @cDPickZone    OUTPUT,
	            @cLogicalLoc   OUTPUT, @cCCLogicalLoc OUTPUT,
				   @cLocationType OUTPUT, @cLocationFlag OUTPUT,
				   @cLocHandling  OUTPUT, @cLocStatus    OUTPUT,
				   @cLoseID       OUTPUT, @cABC          OUTPUT,
				   @cComSKU       OUTPUT, @cComLOT       OUTPUT


         -- Prepare Next Screeen
	      SET @cOutField01 = @cDPutawayZone
	      SET @cOutField02 = @cDPickZone
	      SET @cOutField03 = @cLogicalLoc
	      SET @cOutField04 = @cCCLogicalLoc
	      SET @cOutField05 = @cLocationType
	      SET @cOutField06 = @cLocationFlag
	      SET @cOutField07 = @cLocHandling
	      SET @cOutField08 = @cLocStatus
	      SET @cOutField09 = @cLoseID
	      SET @cOutField10 = @cABC
	      SET @cOutField11 = @cComSKU
	      SET @cOutField12 = @cComLOT


	   	SET @nScn = @nScn + 1
			SET @nStep = @nStep + 1

         GOTO QUIT
     END -- If @cMoreInfoOp <> ''

   END -- InputKey = 1

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @cPutawayZone = ''
	   SET @cPickZone = ''
	   SET @cAisle = ''
	   SET @cLevel = ''
	   SET @cStartLoc = ''
	   SET @cEmpty = ''
	   SET @cHold =  ''
	   SET @cLocType = ''

	   SET @cLOC = ''
	   SET @cNoOfID = '0'
	   SET @cMaxPallet = '0'
	   SET @cMoreInfoOp = ''

	   SET @cLogicalLoc = ''
	   SET @cCCLogicalLoc = ''
	   SET @cLocationType = ''
	   SET @cLocationFlag = ''
	   SET @cLocHandling = ''
	   SET @cLocStatus = ''

	   SET @cLoseID = ''
	   SET @cABC = ''
	   SET @cComSKU = ''
	   SET @cComLOT = ''

      SET @cLOC1 = ''
      SET @cLOC2 = ''
      SET @cLOC3 = ''
      SET @cLOC4 = ''
      SET @cLOC5 = ''
      SET @cLOC6 = ''
      SET @cLOC7 = ''
      SET @cLOC8 = ''
      SET @cLOC9 = ''
      SET @cLOC10 = ''

	   SET @cRec1 = ''
	   SET @cRec2 = ''
	   SET @cRec3 = ''
	   SET @cRec4 = ''
	   SET @cRec5 = ''
	   SET @cRec6 = ''
	   SET @cRec7 = ''
	   SET @cRec8 = ''
      SET @cRec9 = ''
	   SET @cRec10 = ''

	   -- Prepare Prev screen var
	   SET @cOutField01 = '' -- PWAYZONE
	   SET @cOutField02 = '' -- PICKZONE
	   SET @cOutField03 = '' -- AISLE
	   SET @cOutField04 = '' -- LEVEL
	   SET @cOutField05 = '' -- START LOC
	   SET @cOutField06 = '1' -- EMPTY
	   SET @cOutField07 = '2' -- HOLD
	   SET @cOutField08 = '1' -- LOC TYPE

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- INF

   	SET @nScn = @nScn - 1
		SET @nStep = @nStep - 1
   END
   GOTO QUIT

   Step_2_Fail:
   BEGIN

      IF @cMoreRec <> 'Y'
      BEGIN
	      SET @cOutField01 = CONVERT(CHAR(11), @cDummyLoc1) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec1, 1, 2)), 2) +
	                         --CONVERT(CHAR(2), SubString(@cRec1, 1, 2)) +
	                         CASE WHEN @cDummyLoc1 <> '' THEN '/' ELSE '' END +
	                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec1, 3, 2)), 2)
	                         --CONVERT(CHAR(2), SubString(@cRec1, 3, 2))
	      SET @cOutField02 = CONVERT(CHAR(11), @cDummyLoc2) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec2, 1, 2)), 2) +
	                         --CONVERT(CHAR(2), SubString(@cRec2, 1, 2)) +
	                         CASE WHEN @cDummyLoc2 <> '' THEN '/' ELSE '' END +
	                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec2, 3, 2)), 2)
	                         --CONVERT(CHAR(2), SubString(@cRec2, 3, 2))
	      SET @cOutField03 = CONVERT(CHAR(11), @cDummyLoc3) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec3, 1, 2)), 2) +
	                         --CONVERT(CHAR(2), SubString(@cRec3, 1, 2)) +
	                         CASE WHEN @cDummyLoc3 <> '' THEN '/' ELSE '' END +
	                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec3, 3, 2)), 2)
	                         --CONVERT(CHAR(2), SubString(@cRec3, 3, 2))
	      SET @cOutField04 = CONVERT(CHAR(11), @cDummyLoc4) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec4, 1, 2)), 2) +
	                         --CONVERT(CHAR(2), SubString(@cRec4, 1, 2)) +
	                         CASE WHEN @cDummyLoc4 <> '' THEN '/' ELSE '' END +
	                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec4, 3, 2)), 2)
	                         --CONVERT(CHAR(2), SubString(@cRec4, 3, 2))
	      SET @cOutField05 = CONVERT(CHAR(11), @cDummyLoc5) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec5, 1, 2)), 2) +
	                         --CONVERT(CHAR(2), SubString(@cRec5, 1, 2)) +
	                         CASE WHEN @cDummyLoc5 <> '' THEN '/' ELSE '' END +
	                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec5, 3, 2)), 2)
	                         --CONVERT(CHAR(2), SubString(@cRec5, 3, 2))
	      SET @cOutField06 = CONVERT(CHAR(11), @cDummyLoc6) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec6, 1, 2)), 2) +
	                         --CONVERT(CHAR(2), SubString(@cRec6, 1, 2)) +
	                         CASE WHEN @cDummyLoc6 <> '' THEN '/' ELSE '' END +
	                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec6, 3, 2)), 2)
	                         --CONVERT(CHAR(2), SubString(@cRec6, 3, 2))
	      SET @cOutField07 = CONVERT(CHAR(11), @cDummyLoc7) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec7, 1, 2)), 2) +
	                         --CONVERT(CHAR(2), SubString(@cRec7, 1, 2)) +
	                         CASE WHEN @cDummyLoc7 <> '' THEN '/' ELSE '' END +
	                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec7, 3, 2)), 2)
	                         --CONVERT(CHAR(2), SubString(@cRec7, 3, 2))
	      SET @cOutField08 = CONVERT(CHAR(11), @cDummyLoc8) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec8, 1, 2)), 2) +
	                         --CONVERT(CHAR(2), SubString(@cRec8, 1, 2)) +
	                         CASE WHEN @cDummyLoc8 <> '' THEN '/' ELSE '' END +
	                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec8, 3, 2)), 2)
	                         --CONVERT(CHAR(2), SubString(@cRec8, 3, 2))
	      SET @cOutField09 = CONVERT(CHAR(11), @cDummyLoc9) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec9, 1, 2)), 2) +
	                         --CONVERT(CHAR(2), SubString(@cRec9, 1, 2)) +
	                         CASE WHEN @cDummyLoc9 <> '' THEN '/' ELSE '' END +
	                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec9, 3, 2)), 2)
	                         --CONVERT(CHAR(2), SubString(@cRec9, 3, 2))
	      SET @cOutField10 = CONVERT(CHAR(11), @cDummyLoc10) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec10, 1, 2)), 2) +
	                         --CONVERT(CHAR(2), SubString(@cRec10, 1, 2)) +
	                         CASE WHEN @cDummyLoc10 <> '' THEN '/' ELSE '' END +
	                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec10, 3, 2)), 2)
	                         --CONVERT(CHAR(2), SubString(@cRec10, 3, 2))
      END
      ELSE
      BEGIN
	      SET @cOutField01 = CONVERT(CHAR(11), @cLoc1) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec1, 1, 2)), 2) +
	                         --CONVERT(CHAR(2), SubString(@cRec1, 1, 2)) +
	                         CASE WHEN @cLOC1 <> '' THEN '/' ELSE '' END +
	                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec1, 3, 2)), 2)
	                         --CONVERT(CHAR(2), SubString(@cRec1, 3, 2))
	      SET @cOutField02 = CONVERT(CHAR(11), @cLOC2) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec2, 1, 2)), 2) +
	                         --CONVERT(CHAR(2), SubString(@cRec2, 1, 2)) +
	                         CASE WHEN @cLOC2 <> '' THEN '/' ELSE '' END +
	                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec2, 3, 2)), 2)
	                         --CONVERT(CHAR(2), SubString(@cRec2, 3, 2))
	      SET @cOutField03 = CONVERT(CHAR(11), @cLOC3) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec3, 1, 2)), 2) +
	                         --CONVERT(CHAR(2), SubString(@cRec3, 1, 2)) +
	                         CASE WHEN @cLOC3 <> '' THEN '/' ELSE '' END +
	                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec3, 3, 2)), 2)
	                         --CONVERT(CHAR(2), SubString(@cRec3, 3, 2))
	      SET @cOutField04 = CONVERT(CHAR(11), @cLOC4) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec4, 1, 2)), 2) +
	                         --CONVERT(CHAR(2), SubString(@cRec4, 1, 2)) +
	                         CASE WHEN @cLOC4 <> '' THEN '/' ELSE '' END +
	                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec4, 3, 2)), 2)
	                         --CONVERT(CHAR(2), SubString(@cRec4, 3, 2))
	      SET @cOutField05 = CONVERT(CHAR(11), @cLOC5) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec5, 1, 2)), 2) +
	                         --CONVERT(CHAR(2), SubString(@cRec5, 1, 2)) +
	                         CASE WHEN @cLOC5 <> '' THEN '/' ELSE '' END +
	                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec5, 3, 2)), 2)
	                         --CONVERT(CHAR(2), SubString(@cRec5, 3, 2))
	      SET @cOutField06 = CONVERT(CHAR(11), @cLOC6) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec6, 1, 2)), 2) +
	                         --CONVERT(CHAR(2), SubString(@cRec6, 1, 2)) +
	                         CASE WHEN @cLOC6 <> '' THEN '/' ELSE '' END +
	                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec6, 3, 2)), 2)
	                         --CONVERT(CHAR(2), SubString(@cRec6, 3, 2))
	      SET @cOutField07 = CONVERT(CHAR(11), @cLOC7) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec7, 1, 2)), 2) +
	                         --CONVERT(CHAR(2), SubString(@cRec7, 1, 2)) +
	                         CASE WHEN @cLOC7 <> '' THEN '/' ELSE '' END +
	                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec7, 3, 2)), 2)
	                         --CONVERT(CHAR(2), SubString(@cRec7, 3, 2))
	      SET @cOutField08 = CONVERT(CHAR(11), @cLOC8) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec8, 1, 2)), 2) +
	                         --CONVERT(CHAR(2), SubString(@cRec8, 1, 2)) +
	                         CASE WHEN @cLOC8 <> '' THEN '/' ELSE '' END +
	                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec8, 3, 2)), 2)
	                         --CONVERT(CHAR(2), SubString(@cRec8, 3, 2))
	      SET @cOutField09 = CONVERT(CHAR(11), @cLOC9) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec9, 1, 2)), 2) +
	                         --CONVERT(CHAR(2), SubString(@cRec9, 1, 2)) +
	                         CASE WHEN @cLOC9 <> '' THEN '/' ELSE '' END +
	      RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec9, 3, 2)), 2)
	                         --CONVERT(CHAR(2), SubString(@cRec9, 3, 2))
	      SET @cOutField10 = CONVERT(CHAR(11), @cLOC10) +
	                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec10, 1, 2)), 2) +
	                         --CONVERT(CHAR(2), SubString(@cRec10, 1, 2)) +
	                         CASE WHEN @cLOC10 <> '' THEN '/' ELSE '' END +
	                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec10, 3, 2)), 2)
	                         --CONVERT(CHAR(2), SubString(@cRec10, 3, 2))

      END

      SET @cOutField11 = '' -- INF

      GOTO Quit
   END

END
GOTO Quit


/********************************************************************************
Scn = 1632. INF screen
   PWAYZONE     (field01)
   PICKZONE     (field02)
   LOG. LOC     (field03)
   CCLOGLOC     (field04)
   TYPE         (field05)
   FLAG         (field06)
   HANDLING     (field07)
   STATUS       (field08)
   LOSEID       (field09)
   ABC          (field10)
   COMMINGLESKU (field11)
   COMMINGLELOT (field12)
********************************************************************************/
Step_3:
BEGIN
    -- 1 = Yes or Send , 0 = ESC
   IF (@nInputKey = 1) OR (@nInputKey = 0)
   BEGIN
      -- Go back to Previous Screen
      -- Prep Prev screen var
      SET @cOutField01 = CONVERT(CHAR(11), @cLOC1) +
                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec1, 1, 2)), 2) +
                         --CONVERT(CHAR(2), SubString(@cRec1, 1, 2)) +
                         CASE WHEN @cLOC1 <> '' THEN '/' ELSE '' END +
                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec1, 3, 2)), 2)
                         --CONVERT(CHAR(2), SubString(@cRec1, 3, 2))
      SET @cOutField02 = CONVERT(CHAR(11), @cLOC2) +
                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec2, 1, 2)), 2) +
                         --CONVERT(CHAR(2), SubString(@cRec2, 1, 2)) +
                         CASE WHEN @cLOC2 <> '' THEN '/' ELSE '' END +
                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec2, 3, 2)), 2)
                         --CONVERT(CHAR(2), SubString(@cRec2, 3, 2))
      SET @cOutField03 = CONVERT(CHAR(11), @cLOC3) +
                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec3, 1, 2)), 2) +
                         --CONVERT(CHAR(2), SubString(@cRec3, 1, 2)) +
                         CASE WHEN @cLOC3 <> '' THEN '/' ELSE '' END +
                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec3, 3, 2)), 2)
                         --CONVERT(CHAR(2), SubString(@cRec3, 3, 2))
      SET @cOutField04 = CONVERT(CHAR(11), @cLOC4) +
                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec4, 1, 2)), 2) +
                         --CONVERT(CHAR(2), SubString(@cRec4, 1, 2)) +
                         CASE WHEN @cLOC4 <> '' THEN '/' ELSE '' END +
                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec4, 3, 2)), 2)
                         --CONVERT(CHAR(2), SubString(@cRec4, 3, 2))
      SET @cOutField05 = CONVERT(CHAR(11), @cLOC5) +
                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec5, 1, 2)), 2) +
                         --CONVERT(CHAR(2), SubString(@cRec5, 1, 2)) +
                         CASE WHEN @cLOC5 <> '' THEN '/' ELSE '' END +
                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec5, 3, 2)), 2)
                         --CONVERT(CHAR(2), SubString(@cRec5, 3, 2))
      SET @cOutField06 = CONVERT(CHAR(11), @cLOC6) +
                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec6, 1, 2)), 2) +
                         --CONVERT(CHAR(2), SubString(@cRec6, 1, 2)) +
                         CASE WHEN @cLOC6 <> '' THEN '/' ELSE '' END +
                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec6, 3, 2)), 2)
                         --CONVERT(CHAR(2), SubString(@cRec6, 3, 2))
      SET @cOutField07 = CONVERT(CHAR(11), @cLOC7) +
                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec7, 1, 2)), 2) +
                         --CONVERT(CHAR(2), SubString(@cRec7, 1, 2)) +
                         CASE WHEN @cLOC7 <> '' THEN '/' ELSE '' END +
                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec7, 3, 2)), 2)
                         --CONVERT(CHAR(2), SubString(@cRec7, 3, 2))
      SET @cOutField08 = CONVERT(CHAR(11), @cLOC8) +
                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec8, 1, 2)), 2) +
                         --CONVERT(CHAR(2), SubString(@cRec8, 1, 2)) +
                         CASE WHEN @cLOC8 <> '' THEN '/' ELSE '' END +
                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec8, 3, 2)), 2)
                         --CONVERT(CHAR(2), SubString(@cRec8, 3, 2))
      SET @cOutField09 = CONVERT(CHAR(11), @cLOC9) +
                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec9, 1, 2)), 2) +
                         --CONVERT(CHAR(2), SubString(@cRec9, 1, 2)) +
                         CASE WHEN @cLOC9 <> '' THEN '/' ELSE '' END +
                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec9, 3, 2)), 2)
                         --CONVERT(CHAR(2), SubString(@cRec9, 3, 2))
      SET @cOutField10 = CONVERT(CHAR(11), @cLOC10) +
                         RIGHT(RTRIM(REPLICATE(' ', 2) + SubString(@cRec10, 1, 2)), 2) +
                         --CONVERT(CHAR(2), SubString(@cRec10, 1, 2)) +
                         CASE WHEN @cLOC10 <> '' THEN '/' ELSE '' END +
                         RIGHT(RTRIM(REPLICATE('', 2) + SubString(@cRec10, 3, 2)), 2)
                         --CONVERT(CHAR(2), SubString(@cRec10, 3, 2))
      SET @cOutField11 = '' -- INF

	   SET @cMoreInfoOp = ''

   	SET @nScn = @nScn - 1
		SET @nStep = @nStep - 1

      GOTO QUIT

   END

   GOTO Quit

   Step_3_Fail:

END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey    = @cStorerKey,
      Facility     = @cFacility,
      -- UserName     = @cUserName,
      Printer      = @cPrinter,

	   V_String1    = @cPutawayZone,
      V_String2    = @cPickZone,
	   V_String3    = @cAisle,
	   V_String4    = @cLevel,
	   V_String5    = @cStartLoc,
	   V_String6    = @cEmpty,
	   V_String7    = @cHold,
	   V_String8    = @cLocType,

-- 	   V_String9    = @cLOC,
-- 	   V_String10   = @cNoOfID,
-- 	   V_String11   = @cMaxPallet,
	   V_String9    = @cMoreInfoOp,

	   V_String10   = @cLogicalLoc,
	   V_String11   = @cCCLogicalLoc,
	   V_String12   = @cLocationType,
	   V_String13   = @cLocationFlag,
	   V_String14   = @cLocHandling,
	   V_String15   = @cLocStatus,

	   V_String16   = @cLoseID,
	   V_String17   = @cABC,
	   V_String18   = @cComSKU,
	   V_String19   = @cComLOT,

	   V_String20   = @cLOC1,
	   V_String21   = @cLOC2,
	   V_String22   = @cLOC3,
	   V_String23   = @cLOC4,
	   V_String24   = @cLOC5,
	   V_String25   = @cLOC6,
	   V_String26   = @cLOC7,
	   V_String27   = @cLOC8,
	   V_String28   = @cLOC9,
	   V_String29   = @cLOC10,

      V_String30   = @cMoreRec,

      V_String31   = @cRec1,
      V_String32   = @cRec2,
      V_String33   = @cRec3,
      V_String34   = @cRec4,
      V_String35   = @cRec5,
      V_String36   = @cRec6,
      V_String37   = @cRec7,
      V_String38   = @cRec8,
      V_String39   = @cRec9,
      V_String40   = @cRec10,

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