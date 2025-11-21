SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtInfo03                                   */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Display final location                                      */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-08-28 1.0  Chermaine  WMS-14921 Created                         */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1819ExtInfo03] (
   @nMobile         INT,          
   @nFunc           INT,          
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT,          
   @nAfterStep      INT, 
   @nInputKey       INT,          
   @cFromID         NVARCHAR( 18),
   @cSuggLOC        NVARCHAR( 10),
   @cPickAndDropLOC NVARCHAR( 10),
   @cToLOC          NVARCHAR( 10),
   @cExtendedInfo   NVARCHAR( 20) OUTPUT,
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nStep = 1 -- ID#
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
      	DECLARE @cTotalUCC NVARCHAR(2)
            SELECT @cTotalUCC = count(distinct UCCNo) from UCC WITH (NOLOCK) where ID = @cFromID and [status]=1 
            SET @cExtendedInfo = 'CTN QTY: ' + @cTotalUCC
      END
   END

GO