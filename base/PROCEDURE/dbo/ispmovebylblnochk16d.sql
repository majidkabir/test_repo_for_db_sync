SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispMoveByLblNoChk16d                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Decode Label No Scanned                                     */
/*          Copied from ispMoveByLabelNoChk but validate 16 digits label*/
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2014-04-03 1.0  James    SOS307345 Created                           */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispMoveByLblNoChk16d]
   @nMobile       INT, 
   @nFunc         INT, 
   @cLangCode     NVARCHAR(3),
   @cFromLabelNo  NVARCHAR(20),
   @cToLabelNo    NVARCHAR(20),
   @nErrNo        INT      OUTPUT, 
   @cErrMsg       NVARCHAR(20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Check if same type
   IF LEN( RTRIM( @cFromLabelNo)) <> LEN( RTRIM( @cToLabelNo)) OR 
      LEFT( @cFromLabelNo, 10) <> LEFT( @cToLabelNo, 10)
   BEGIN
      SET @nErrNo = 77751
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
   END
QUIT:
END -- End Procedure

GO