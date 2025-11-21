SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_MoveByDropID_UpdatePickDetail                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Update PickDetail                                           */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 03-Mar-2008 1.0  James       Created                                 */
/*                                                                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_MoveByDropID_UpdatePickDetail] (
   @cFromDropID       NVARCHAR( 20),
   @cToDropID         NVARCHAR( 20),
   @cStorerKey        NVARCHAR( 15),
   @cPickDetailKey    NVARCHAR( 10),
   @cLangCode         VARCHAR (3),
   @nErrNo            INT          OUTPUT, 
   @cErrMsg           NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE 
      @b_success         INT,
      @n_err             INT,
      @c_errmsg          NVARCHAR( 255)

   SET @b_success = 0
    
   BEGIN TRAN

   UPDATE dbo.PickDetail WITH (ROWLOCK) SET
   DropID = @cToDropID,
   CartonGroup = 'M',
   TrafficCop = NULL
   WHERE StorerKey = @cStorerKey
     AND DropID = @cFromDropID
     AND PickDetailKey = @cPickDetailKey

   IF @@ERROR = 0
      COMMIT TRAN
   ELSE
   BEGIN
      ROLLBACK TRAN
      SET @nErrNo = 63879
      SET @cErrMsg = rdt.rdtgetmessage( 63879, @cLangCode, 'DSP') -- Upd PDtl Fail
      GOTO Fail
   END
   
   Fail:

END

GO