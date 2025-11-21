SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_514ExtVal07                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: UA custom move check                                              */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2021-06-24  1.0  James    WMS-17322 Created                                */
/* 2023-01-20  1.1  Ung      WMS-21577 Add unlimited UCC to move              */ 
/******************************************************************************/

CREATE   PROC [RDT].[rdt_514ExtVal07] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15),
   @cToID          NVARCHAR( 18),
   @cToLoc         NVARCHAR( 10),
   @cFromLoc       NVARCHAR( 10),
   @cFromID        NVARCHAR( 18),
   @cUCC           NVARCHAR( 20),
   @cUCC1          NVARCHAR( 20),
   @cUCC2          NVARCHAR( 20),
   @cUCC3          NVARCHAR( 20),
   @cUCC4          NVARCHAR( 20),
   @cUCC5          NVARCHAR( 20),
   @cUCC6          NVARCHAR( 20),
   @cUCC7          NVARCHAR( 20),
   @cUCC8          NVARCHAR( 20),
   @cUCC9          NVARCHAR( 20),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nChkUCC_Qty    INT
   
   DECLARE @tUCC TABLE 
   (
      UCCNo NVARCHAR( 20) NOT NULL PRIMARY KEY CLUSTERED,
      Qty   INT NOT NULL
   )

   IF @nFunc = 514 -- Move by UCC
   BEGIN
      IF @nStep = 2 -- To Loc/To ID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            INSERT INTO @tUCC (UCCNo, Qty)
            SELECT UCC.UCCNo, ISNULL( SUM( UCC.QTY), 0)
            FROM rdt.rdtMoveUCCLog L WITH (NOLOCK)
               JOIN dbo.UCC WITH (NOLOCK) ON (L.UCCNo = UCC.UCCNo AND L.StorerKey = UCC.StorerKey AND L.AddWho = SUSER_SNAME())
            WHERE L.StorerKey = @cStorerKey
               AND L.AddWho = SUSER_SNAME()
            GROUP BY UCC.UCCNo

            SELECT TOP 1 @nChkUCC_Qty = Qty FROM @tUCC
            
            IF @@ROWCOUNT = 0
               GOTO Quit
                              
            IF EXISTS ( SELECT 1 FROM @tUCC WHERE Qty <> @nChkUCC_Qty)
            BEGIN
               SET @nErrNo = 169501
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Qty not match'
               GOTO Quit
            END

         END
      END
   END

Quit:

END

GO