SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/
/* Store procedure: rdtfnc_PTLPiece_Inquiry                                   */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author     Purposes                                       */
/* 2022-08-23 1.0  YeeKung    WMS-20569 Created                              */
/*****************************************************************************/
CREATE PROC [RDT].[rdtfnc_PTLPiece_Inquiry](
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

   @cLoc                NVARCHAR(28),
   @cWaveKey            NVARCHAR(20),
   @cOrderKey           NVARCHAR(20),
   @cOrderCount         NVARCHAR(3),
   @cSortedQty          NVARCHAR(3),
   @cTotalQty           NVARCHAR(3),
   @cStation            NVARCHAR(10),
   @cSKU                NVARCHAR(20),


   @cCounter            INT,
   @cTotalCount         INT,
   @cCurPTLPieceSKU     cursor,


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

   @cWaveKey         = V_String1,
   @cTotalCount      = V_String2,
   @cSortedQty       = V_String3,
   @cTotalQty        = V_String4,
   @cStation         = V_String5,
   @cOrderCount      = V_String6,
   @cOrderkey        = V_String7,

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
IF @nFunc = 806
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 806
   IF @nStep = 1 GOTO Step_1   -- Scn = 5820   station
   IF @nStep = 2 GOTO Step_2   -- Scn = 5821   Result
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1846)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 6100
   SET @nStep = 1

   -- initialise all variable
   SET @cStation = ''
   SET @cWaveKey = ''
   SET @cOrderCount = ''
   SET @cSortedQty = ''
   SET @cTotalQty = ''

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
      SET @cStation = @cInField01

      IF @cStation = ''
      BEGIN
         SET @nErrNo = 190251  
         SET @cErrMsg = rdt.rdtgetmessage( 68366, @cLangCode, 'DSP') --StationNotNull
         GOTO Step_1_Fail
      END

      IF NOT EXISTS ( SELECT 1 FROM DEVICEPROFILE (NOLOCK)
                     WHERE deviceid=@cStation
                     AND storerkey=@cstorerkey
		               )
      BEGIN
         SET @nErrNo = 190252
         SET @cErrMsg = rdt.rdtgetmessage( 68367, @cLangCode, 'DSP') --DeviceIDNotExists
         GOTO Step_1_Fail
      END

      IF EXISTS (SELECT 1
               FROM rdt.rdtptlpiecelog PTL WITH (NOLOCK)
               JOIN Pickdetail PD (nolock) ON PTL.orderkey=PD.orderkey and PTL.storerkey=PTL.storerkey
               WHERE PD.StorerKey = @cStorerKey
                  AND PTL.station=@cStation
                  AND PD.Status=0
                  AND PD.caseid<>'Sorted')
      BEGIN
         SET @nErrNo = 190253
         SET @cErrMsg = rdt.rdtgetmessage( 68367, @cLangCode, 'DSP') --NoRecord
         GOTO Step_1_Fail
      END

      SELECT top 1
         @cWaveKey = PTL.wavekey,
         @cOrderkey = PTL.Orderkey,
         @cLoc      = DP.Loc
      FROM rdt.rdtptlpiecelog PTL WITH (NOLOCK)
      JOIN deviceprofile DP (nolock) on PTL.position=Dp.deviceposition and PTL.station=DP.deviceid
      JOIN Pickdetail PD (nolock) ON PTL.orderkey=PD.orderkey and PTL.storerkey=PTL.storerkey
      WHERE PD.StorerKey = @cStorerKey
         AND PTL.station=@cStation
         AND PD.Status=3
         AND PD.caseid<>'Sorted'
      GROUP BY PTL.wavekey,PTL.Orderkey,DP.Loc


      SELECT @cTotalCount = Count(distinct PTL.Orderkey)
      FROM rdt.rdtptlpiecelog PTL WITH (NOLOCK)
      JOIN Pickdetail PD (nolock) ON PTL.orderkey=PD.orderkey and PTL.storerkey=PTL.storerkey
      WHERE PD.StorerKey = @cStorerKey
         AND PTL.station=@cStation
         AND PD.Status=3
         AND PD.caseid<>'Sorted'
      GROUP BY PTL.wavekey,PTL.Loc


      SET @cCounter = 1

      SET @cCurPTLPieceSKU = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT SKU
      FROM Pickdetail PD WITH (NOLOCK)
      where orderkey=@cOrderkey
      AND storerkey=@cstorerkey
      AND PD.caseid<>'Sorted'
      AND PD.Status=3

      OPEN @cCurPTLPieceSKU
      FETCH NEXT FROM @cCurPTLPieceSKU INTO  @cSKU
      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         SELECT @cSortedQty = SUM(PD.QTY)
         FROM Pickdetail PD WITH (NOLOCK)
         where orderkey=@cOrderkey
         AND storerkey=@cstorerkey
         AND sku = @cSKU
         AND status='3'
         AND caseid='Sorted'

         SELECT @cTotalQty = SUM(PD.QTY)
         FROM Pickdetail PD WITH (NOLOCK)
         where orderkey=@cOrderkey
         AND storerkey=@cstorerkey
         AND sku = @cSKU

         set @cSortedQty= case when ISNULL(@cSortedQty,'') ='' THEN 0  ELSE @cSortedQty END

         IF @cCounter = 1
         BEGIN
            SET @cOutField04 = @cSKU
            SET @cOutField05 = @cSortedQty + '/' +  CAST (@cTotalQty AS NVARCHAR(5))
         END
         ELSE IF @cCounter = 2
         BEGIN
            SET @cOutField06 = @cSKU
            SET @cOutField07 = @cSortedQty + '/' + CAST (@cTotalQty AS NVARCHAR(5))
         END
         ELSE IF @cCounter = 3
         BEGIN
            SET @cOutField08 = @cSKU
            SET @cOutField09 = @cSortedQty + '/' +   CAST (@cTotalQty AS NVARCHAR(5))
         END
         ELSE IF @cCounter = 4
         BEGIN
            SET @cOutField10 = @cSKU
            SET @cOutField11 = @cSortedQty + '/' +  CAST (@cTotalQty AS NVARCHAR(5))
         END

         SET @cCounter = @cCounter+1
         

         FETCH NEXT FROM @cCurPTLPieceSKU INTO  @cSKU
      END
         
      SET @cOrderCount =1
         
      --prepare next screen variable
      SET @cOutField01 = @cWaveKey
      SET @cOutField02 = @cOrderkey
      SET @cOutField03 = @cLoc
      SET @cOutField13 = @cOrderCount +'/' +  CAST (@cTotalCount AS NVARCHAR(5))

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
      SET @cWaveKey = ''
      SET @cOrderCount = ''
      SET @cSortedQty = ''
      SET @cTotalQty = ''

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
      SET @cStation = ''
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
   IF @nInputKey = 1 -- ENTER / ESC
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
      SET @cCounter = 1

      IF @cOrderCount =@cTotalCount
      BEGIN
         SELECT top 1
            @cWaveKey = PTL.wavekey,
            @cOrderkey = PTL.Orderkey,
            @cLoc      = DP.Loc
         FROM rdt.rdtptlpiecelog PTL WITH (NOLOCK)
         JOIN deviceprofile DP (nolock) on PTL.position=Dp.deviceposition and PTL.station=DP.deviceid
         JOIN Pickdetail PD (nolock) ON PTL.orderkey=PD.orderkey and PTL.storerkey=PTL.storerkey
         WHERE PD.StorerKey = @cStorerKey
            AND PTL.station=@cStation
            AND PD.Status=3
            AND PD.caseid<>'Sorted'
         GROUP BY PTL.wavekey,PTL.Orderkey,DP.Loc
         ORDER BY PTL.Orderkey

         SELECT @cTotalCount = Count(distinct PTL.Orderkey)
         FROM rdt.rdtptlpiecelog PTL WITH (NOLOCK)
         JOIN Pickdetail PD (nolock) ON PTL.orderkey=PD.orderkey and PTL.storerkey=PTL.storerkey
         WHERE PD.StorerKey = @cStorerKey
            AND PTL.station=@cStation
            AND PD.Status=3
            AND PD.caseid<>'Sorted'
         GROUP BY PTL.wavekey,PTL.Loc

         SET @cCurPTLPieceSKU = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT SKU
         FROM Pickdetail PD WITH (NOLOCK)
         where orderkey=@cOrderkey
         AND storerkey=@cstorerkey
         AND PD.caseid<>'Sorted'
         AND PD.Status=3

         OPEN @cCurPTLPieceSKU
         FETCH NEXT FROM @cCurPTLPieceSKU INTO  @cSKU
         WHILE (@@FETCH_STATUS <> -1)
         BEGIN
            SELECT @cSortedQty = SUM(PD.QTY)
            FROM Pickdetail PD WITH (NOLOCK)
            where orderkey=@cOrderkey
            AND storerkey=@cstorerkey
            AND sku = @cSKU
            AND status='3'
            AND caseid='Sorted'

            SELECT @cTotalQty = SUM(PD.QTY)
            FROM Pickdetail PD WITH (NOLOCK)
            where orderkey=@cOrderkey
            AND storerkey=@cstorerkey
            AND sku = @cSKU

            set @cSortedQty= case when ISNULL(@cSortedQty,'') ='' THEN 0  ELSE @cSortedQty END

            IF @cCounter = 1
            BEGIN
               SET @cOutField04 = @cSKU
               SET @cOutField05 = @cSortedQty + '/' +  CAST (@cTotalQty AS NVARCHAR(5))
            END
            ELSE IF @cCounter = 2
            BEGIN
               SET @cOutField06 = @cSKU
               SET @cOutField07 = @cSortedQty + '/' + CAST (@cTotalQty AS NVARCHAR(5))
            END
            ELSE IF @cCounter = 3
            BEGIN
               SET @cOutField08 = @cSKU
               SET @cOutField09 = @cSortedQty + '/' +   CAST (@cTotalQty AS NVARCHAR(5))
            END
            ELSE IF @cCounter = 4
            BEGIN
               SET @cOutField10 = @cSKU
               SET @cOutField11 = @cSortedQty + '/' +  CAST (@cTotalQty AS NVARCHAR(5))
            END

            SET @cCounter = @cCounter+1
         

            FETCH NEXT FROM @cCurPTLPieceSKU INTO  @cSKU

            SET @cOrderCount =1 
         END
      END
      ELSE
      BEGIN


          SELECT top 1
            @cWaveKey = PTL.wavekey,
            @cOrderkey = PTL.Orderkey,
            @cLoc      = DP.Loc
         FROM rdt.rdtptlpiecelog PTL WITH (NOLOCK)
            JOIN deviceprofile DP (nolock) on PTL.position=Dp.deviceposition and PTL.station=DP.deviceid
         JOIN Pickdetail PD (nolock) ON PTL.orderkey=PD.orderkey and PTL.storerkey=PTL.storerkey
         WHERE PD.StorerKey = @cStorerKey
            AND PTL.station=@cStation
            AND PD.Status=3
            AND PD.caseid<>'Sorted'
            AND PTL.orderkey >@cOrderkey
         GROUP BY PTL.wavekey,PTL.Orderkey,DP.Loc
         order by ptl.orderkey

         SET @cCurPTLPieceSKU = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT SKU
         FROM Pickdetail PD WITH (NOLOCK)
         where orderkey=@cOrderkey
         AND storerkey=@cstorerkey
         AND PD.Status=3
         AND PD.caseid<>'Sorted'

         OPEN @cCurPTLPieceSKU
         FETCH NEXT FROM @cCurPTLPieceSKU INTO  @cSKU
         WHILE (@@FETCH_STATUS <> -1)
         BEGIN
            SELECT @cSortedQty = SUM(PD.QTY)
            FROM Pickdetail PD WITH (NOLOCK)
            where orderkey=@cOrderkey
            AND storerkey=@cstorerkey
            AND sku = @cSKU
            AND PD.Status=3
             AND caseid='Sorted'

            SELECT @cTotalQty = SUM(PD.QTY)
            FROM Pickdetail PD WITH (NOLOCK)
            where orderkey=@cOrderkey
            AND storerkey=@cstorerkey
            AND sku = @cSKU

            set @cSortedQty= case when ISNULL(@cSortedQty,'') ='' THEN 0  ELSE @cSortedQty END

            IF @cCounter = 1
            BEGIN
               SET @cOutField04 = @cSKU
               SET @cOutField05 = @cSortedQty + '/' +  CAST (@cTotalQty AS NVARCHAR(5))
            END
            ELSE IF @cCounter = 2
            BEGIN
               SET @cOutField06 = @cSKU
               SET @cOutField07 = @cSortedQty + '/' + CAST (@cTotalQty AS NVARCHAR(5))
            END
            ELSE IF @cCounter = 3
            BEGIN
               SET @cOutField08 = @cSKU
               SET @cOutField09 = @cSortedQty + '/' +   CAST (@cTotalQty AS NVARCHAR(5))
            END
            ELSE IF @cCounter = 4
            BEGIN
               SET @cOutField10 = @cSKU
               SET @cOutField11 = @cSortedQty + '/' +  CAST (@cTotalQty AS NVARCHAR(5))
            END


            SET @cCounter = @cCounter+1

            FETCH NEXT FROM @cCurPTLPieceSKU INTO  @cSKU
         END
         SET @cOrderCount =@cOrderCount+1
      END
         
      --prepare next screen variable
      SET @cOutField01 = @cWaveKey
      SET @cOutField02 = @cOrderkey
      SET @cOutField03 = @cLoc
      SET @cOutField13 = @cOrderCount +'/' +  CAST (@cTotalCount AS NVARCHAR(5))
   END
   IF @nInputKey = 0 -- ENTER / ESC
   BEGIN
      --prepare next screen variable
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''

      SET @cStation = ''
      SET @cWaveKey = ''
      SET @cOrderCount = ''
      SET @cSortedQty = ''
      SET @cTotalQty = ''

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

       V_String1     = @cWaveKey,
       V_String2     = @cTotalCount,
       V_String3     = @cSortedQty,
       V_String4     = @cTotalQty,
       V_String5     = @cStation,
       V_String6     = @cOrderCount,
       V_String7     = @cOrderkey,

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