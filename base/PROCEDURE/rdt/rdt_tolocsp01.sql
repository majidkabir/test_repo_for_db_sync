SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_ToLocSP01                                       */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: UCC inbound Receive ToLocLookup StorerConfig                */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2015-04-28  1.0  ChewKP   SOS#339833 Created                         */
/* 2021-12-15  1.1  SYChua   JSM-40125 - Fix lack of parameter when used*/
/*                           in FN731 rdtfnc_SimpleCC (SY01)            */
/************************************************************************/

CREATE PROC [RDT].[rdt_ToLocSP01] (
    @cReceiptKey1   NVARCHAR( 10),
    @cReceiptKey2   NVARCHAR( 10),
    @cReceiptKey3   NVARCHAR( 10),
    @cReceiptKey4   NVARCHAR( 10),
    @cReceiptKey5   NVARCHAR( 10),
    @cReceiptKey6   NVARCHAR( 10),     --SY01
    @cLOC           NVARCHAR( 10) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUserDefine03  NVARCHAR(30)
          ,@cFacility      NVARCHAR( 5)

   SELECT @cFacility = Facility
   FROM dbo.Loc WITH (NOLOCK)
   WHERE Loc = @cLOC

   SELECT @cUserDefine03 = UserDefine03
   FROM dbo.Facility WITH (NOLOCK)
   WHERE Facility = @cFacility

   IF ISNULL(RTRIM(@cUserDefine03),'')  <> ''
   BEGIN
      SET @cLoc = ISNULL(RTRIM(@cUserDefine03),'') + @cLoc
   END


END

GO