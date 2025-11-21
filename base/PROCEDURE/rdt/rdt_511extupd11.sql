SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_511ExtUpd11                                     */
/* Purpose: Validate UCC                                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-01-11 1.0  yeekung  WMS-21514. Created                          */
/************************************************************************/

CREATE   PROC [RDT].[rdt_511ExtUpd11] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cFromID        NVARCHAR( 18),
   @cFromLOC       NVARCHAR( 10),
   @cToLOC         NVARCHAR( 10),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cLocationType     NVARCHAR( 10)
   DECLARE @cLocationCategory NVARCHAR( 10)
   DECLARE @bSuccess          INT

   IF @nFunc = 511 -- Move by ID
   BEGIN
      IF @nStep = 3 -- ToLOC
      BEGIN
         --ops move the pallet to AGV stage in_loc
         SELECT @cLocationType = LocationType,
                @cLocationCategory = LocationCategory
         FROM dbo.LOC WITH (NOLOCK)
         WHERE Loc = @cToLOC
         AND   Facility = @cFacility

         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                     WHERE LISTNAME = 'AGVSTG'
                     AND   Code = @cLocationType
                     AND   Storerkey = @cStorerKey) --AND
         BEGIN

            DECLARE @cPalletID NVARCHAR(20)

            SET @cPalletID =right(@cFromID,10)

            -- Insert transmitlog2 here  
            EXECUTE ispGenTransmitLog2   
               @c_TableName      = 'WSRECAGVLOG',   
               @c_Key1           = @cPalletID,   
               @c_Key2           = @cFromID,   
               @c_Key3           = @cStorerkey,   
               @c_TransmitBatch  = '',   
               @b_Success        = @bSuccess   OUTPUT,      
               @n_err            = @nErrNo     OUTPUT,      
               @c_errmsg         = @cErrMsg    OUTPUT      
  
            IF @bSuccess <> 1    
               goto quit

         END
      END
   END

Quit:

END

GO