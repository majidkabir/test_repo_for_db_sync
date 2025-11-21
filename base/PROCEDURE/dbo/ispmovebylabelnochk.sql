SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispMoveByLabelNoChk                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Decode Label No Scanned                                     */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2012-10-02 1.0  Ung      SOS257627 Created                           */
/* 2012-12-06 1.1  James    SOS261923 Additional checking (james01)     */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispMoveByLabelNoChk]
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
   IF LEN( RTRIM( @cFromLabelNo)) <> LEN( RTRIM( @cToLabelNo)) OR -- (james01)
      LEFT( @cFromLabelNo, 10) <> LEFT( @cToLabelNo, 10)
   BEGIN
      SET @nErrNo = 77751
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff LabelType
   END
QUIT:
END -- End Procedure

GO