SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store procedure: [rdt_513ExtUpdVLT]                                  */
/* Copyright: Maersk                                                    */
/*                                                                      */
/*                                                                      */
/* Date       VER    Author   Purpose                                   */
/* 15/07/24   1.0    PPA374	  Clearing outstanding pending moves        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_513ExtUpdVLT] (
@nMobile    INT,
@nFunc      INT,
@cLangCode  NVARCHAR( 3),
@nStep      INT,
@nInputKey  INT,
@cStorerKey NVARCHAR( 15),
@cFacility  NVARCHAR(  5),
@cFromLOC   NVARCHAR( 10),
@cFromID    NVARCHAR( 18),
@cSKU       NVARCHAR( 20),
@nQTY       INT,
@cToID      NVARCHAR( 18),
@cToLOC     NVARCHAR( 10),
@nErrNo     INT OUTPUT,
@cErrMsg    NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   IF @nStep = 6 -- To Loc
   -- Clearing outstanding pending moves, as since ID is moved, it is not required anymore.
   BEGIN
      update LOTxLOCxID
      set PendingMoveIN = 0
      where id = @cFromID and StorerKey = @cStorerKey and Sku = @cSKU
      and loc not in (select loc from loc (NOLOCK) where LocationType in ('PICK','CASE') and Facility = @cFacility)
   END
END

GO