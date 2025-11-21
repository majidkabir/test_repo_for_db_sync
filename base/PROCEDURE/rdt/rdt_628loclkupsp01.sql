SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_628LocLkUPSP01                                 */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2023-10-26 1.0  yeekung WMS-23936 Created                            */
/************************************************************************/

CREATE   PROC [RDT].[rdt_628LocLkUPSP01]
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nInputKey      INT,          
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 10),
   @cInquiry_LOC   NVARCHAR( 30) OUTPUT,
   @nErrNo         INT OUTPUT, 
   @cErrMsg        NVARCHAR(MAX) OUTPUT 
 
   
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF NOT EXISTS (SELECT 1
                  FROM LOC (NOLOCK) 
                  WHERE LOC = @cInquiry_LOC
                     AND Facility = @cFacility)
   BEGIN
      SELECT @cInquiry_LOC =LOC 
      FROM LOC (NOLOCK) 
      WHERE DESCR = @cInquiry_LOC
         AND Facility = @cFacility
   END
END

GO