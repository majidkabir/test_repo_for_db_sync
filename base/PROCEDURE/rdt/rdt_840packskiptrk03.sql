SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_840PackSkipTrk03                                   */
/* Purpose: Check if rdt pack by track no module need to scan track no.    */
/*          By default it is set to skip track no screen                   */
/*                                                                         */
/* Called from: rdtfnc_PackByTrackNo                                       */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date        Rev  Author     Purposes                                    */
/* 2015-10-08  1.0  James      SOS368195 - Created                         */
/* 2020-07-03  1.1  James      WMS-13965 Remove step (james01)             */
/***************************************************************************/

CREATE PROC [RDT].[rdt_840PackSkipTrk03] (
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nAfterStep       INT, 
   @nInputKey        INT, 
   @cStorerkey       NVARCHAR( 15), 
   @cOrderKey        NVARCHAR( 10), 
   @cPackSkipTrackNo NVARCHAR( 1)  OUTPUT,    
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT 
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cFragileChk    NVARCHAR( 1), 
           @cIsFragile     NVARCHAR( 1),
           @cHazmatChk     NVARCHAR( 1), 
           @cIsHazmat      NVARCHAR( 1), 
           @cErrMsg1       NVARCHAR( 20), 
           @cErrMsg2       NVARCHAR( 20), 
           @cErrMsg3       NVARCHAR( 20), 
           @cShort         NVARCHAR( 10), 
           @cLong          NVARCHAR( 250)

   SET @cPackSkipTrackNo = '1'

   IF ISNULL( @cOrderKey, '') = ''
      GOTO Quit

   SELECT @cShort = C.Short, @cLong = Long
   FROM dbo.CODELKUP C WITH (NOLOCK)
   JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)
   WHERE C.ListName = 'HMORDTYPE'
   AND   O.OrderKey = @cOrderkey
   AND   O.StorerKey = @cStorerKey

   -- Move type orders does not have tracking no
   -- then need set to value other than 2 to bypass 
   -- the checking if storer has 'PACKSKIPTRACKNO' turned on
   IF @cShort = 'M' AND @cLong IN ('R', 'S')
      SET @cPackSkipTrackNo = '2'
   ELSE
      SET @cPackSkipTrackNo = '1'


QUIT:

GO